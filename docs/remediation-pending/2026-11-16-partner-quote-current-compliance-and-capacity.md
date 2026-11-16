# Partner quote submission — current compliance and physical capacity remediation

**Status:** read-only production inspection and remediation specification. Not a migration; not applied.
**Production impact:** none. No partner quote, opportunity, assignment, commitment, reservation or capacity row was created or changed.

## Live RPC inspected
`public.krim_submit_partner_quote(bigint,numeric,text,timestamptz,text)`

The SECURITY DEFINER function currently:
- resolves one active registered-business partner organization for the caller;
- requires active membership, active organization, verified/approved partner verification and lifecycle status;
- requires at least one active, verified, effective partner capability;
- accepts stored `partner_compliance_status` values including `not_required` and `not_applicable`;
- checks partner `quote.create` permission and active currency;
- locks an open, non-expired opportunity;
- blocks shipment-wide quotes for active multi-leg plans;
- calls `private.krim_partner_capability_covers_shipment(...)`;
- creates or updates a submitted partner quote.

## Confirmed gaps
1. **Stored compliance status can be stale.** The quote RPC does not independently require a current, approved partner compliance review for every applicable jurisdiction/check, nor does it re-evaluate evidence expiry, suspension or revocation at submission time. Stored values such as `not_required` / `not_applicable` are not sufficient proof without an explicit rules-based determination.
2. **No live physical capacity check.** The quote RPC does not query available resources, lane/mode-specific availability windows, existing reservations, commitments, utilization or conflicting bookings before accepting the bid. A quote is therefore a commercial offer, not proof of reserved capacity.
3. **Capability coverage is not full route authorization.** Capability coverage does not replace exact approved corridor dossier, current mandatory controls, approved service-area coverage or cargo-specific handling/equipment/insurance constraints.
4. **No guarantee of future fulfilment.** Even after quote submission, assignment acceptance and physical capacity reservation remain distinct controls. The UI must not imply confirmed vehicle or capacity availability merely because a bid is submitted.

## Required server-side correction
- Create one canonical `krim_partner_operational_eligibility(partner_org, shipment, service_window)` evaluator used by opportunity matching, quote submission, award and assignment acceptance.
- Re-evaluate compliance from current evidence/reviews and applicable jurisdictions; fail closed on absent, expired, suspended, revoked, ambiguous or stale reviews. A partner must not self-declare a check as not required.
- Require exact active service-area coverage and approved corridor dossier/mode/cargo controls.
- Validate cargo class, weight, dimensions/chargeable weight, temperature, equipment, handling restrictions and insurance thresholds against independently verified partner capability.
- If quote submission is intended to be a capacity-backed offer, atomically lock the relevant availability/resource rows and calculate uncommitted capacity after active holds, reservations, bookings, commitments and utilization. Prevent concurrent overbooking.
- If capacity is not reserved at quote time, explicitly label the quote “subject to capacity confirmation”; then revalidate and atomically reserve capacity before customer acceptance or assignment finalization.
- Separate a submitted commercial quote from a verified capacity promise in data model, API response and UI.
- Compare canonical payload on idempotent retries; do not silently mutate an existing submitted quote when amount, currency, validity or service terms conflict.

## Production evidence / release state
- Earlier operational snapshot found zero active capacity resources/reservations and zero accepted assignments.
- Current live function definition confirms no call to the current partner-compliance review evaluator and no query to capacity availability/reservation/commitment tables.
- Existing audit found matcher also relies on stored compliance and omits current capacity.
- No actual partner capacity or eligibility is currently verified; do not advertise a real-time load guarantee.

## Staging acceptance tests
1. Current compliant partner with expired insurance/evidence is denied.
2. Partner with stored `compliant` status but missing/expired current review is denied.
3. `not_required` without a current rules-engine decision and reviewer evidence is denied.
4. Correct capability but no approved service-area/corridor/mode/cargo controls is denied.
5. Capacity fully consumed by reservations/commitments is denied or marked subject to confirmation, according to the selected product contract.
6. Two concurrent bids for the final capacity unit cannot both obtain a capacity-backed confirmation.
7. Capacity window mismatch, resource inactive, equipment mismatch or cargo restriction is denied.
8. Quote submission replay with identical canonical payload returns the same quote; conflicting payload requires an explicit amendment/version.
9. Quote submission alone never creates an assignment, dispatch authorization or physical reservation unless that explicit atomic contract is implemented.
10. Verify ACL, function owner, `search_path`, lock ordering, transaction rollback, audit events and cross-tenant isolation.

## Deployment blocker
Do not replace the RPC or introduce a new eligibility function until production migration history is reconciled, the sanitized schema manifest is available, canonical current review/capacity function definitions are compared, and staging tests pass. The schema export workflow still requires manual launch from GitHub Actions; see the operator guide in `docs/audits/`.
