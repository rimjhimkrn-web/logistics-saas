# KRIM Partner Marketplace, Quote and Assignment Authorization Audit — 2026-11-16

## Scope
Read-only inspection of the live partner opportunity register, quote submission page, assignment/job page, and live Supabase definitions for `krim_submit_partner_quote`, `krim_award_leg_partner_quote`, and `krim_respond_to_partner_assignment`. Targeted browser-side safeguards were updated. No quote, award, assignment response, shipment, capacity, or finance action was executed. No production SQL/function/policy was changed.

## Changes made
1. `public/partner/available-loads.html`: marketplace now requires exactly one active partner organization. It scopes subsequent quote history and opportunity display to that organization, requires registered-business mode, verified identity, lifecycle exactly `active`, and compliance exactly `compliant`. Ambiguous multi-organization accounts are paused instead of aggregating access.
2. `public/partner/submit-quote.html`: quote form's organization gate now explicitly requires registered-business mode, verified identity, lifecycle `active`, and compliance `compliant`. Organization query now fetches the account-mode field needed for that decision.
3. `public/partner/accepted-loads.html`: assignment/job page now requires exactly one active partner organization and the same strict organization-level status gate before showing assignment actions. Multiple active partner organizations cause a fail-closed stop.

## Backend strengths confirmed
- `krim_submit_partner_quote` is SECURITY DEFINER with an empty search_path; it requires authentication, one eligible registered-business partner organization, quote.create permission, an active currency, open/unexpired opportunity, shipment capability coverage, and prevents self-bidding and shipment-wide bids on active multi-leg plans. It writes a quote audit event.
- `krim_award_leg_partner_quote` is SECURITY DEFINER with an empty search_path; it binds quote, opportunity, shipment and exact leg, checks customer quote/shipment permissions, opportunity/quote validity, current partner compliance helper and exact-leg capability, active plan linkage, and prevents duplicate active/completed leg assignment.
- `krim_respond_to_partner_assignment` is SECURITY DEFINER with an empty search_path; it checks organization access and shipment.update permission, quote/assignment binding, expiry, capability coverage and current partner compliance helper before acceptance. Provider acceptance is distinct from customer quote acceptance and final shipment assignment.

## Critical backend gap — do not treat browser changes as a security fix
`krim_submit_partner_quote` currently checks organization status fields and the existence of at least one active verified capability, then calls `private.krim_partner_capability_covers_shipment`. It does **not** call `private.krim_partner_compliance_is_current` before inserting/updating a quote. Its organization status allowlist also accepts `clear`, `approved`, `verified`, `not_required`, and `not_applicable`, rather than requiring the explicit `compliant` state. Therefore a stale/expired/revoked compliance review may not be blocked at quote submission solely by this RPC's visible checks. The later award and assignment-acceptance functions do call the current-compliance helper, but that is too late to prevent an ineligible partner from submitting a commercial offer.

**Required P0 correction after migration reconciliation:** make quote submission fail closed unless the organization is registered-business, active, verified, lifecycle active, explicitly compliant, and `private.krim_partner_compliance_is_current(...)` passes at the time of submission. Also verify the exact service capability and applicable market/corridor/shipment compliance controls at quote time. Add tests for expired compliance, revoked capability, suspended partner, non-compliant aliases, wrong organization, expired opportunity, self-bid, and stale quote retries.

## Other open integrity concerns
- `krim_award_leg_partner_quote` currently checks partner organization status using a permissive compliance-status allowlist but then calls the current-compliance helper; retain the helper as authoritative and simplify the status gate to explicit compliant state.
- `krim_respond_to_partner_assignment` similarly uses a permissive organization status allowlist but calls the current-compliance helper. Keep both checks aligned and fail closed on status mismatch.
- The browser marketplace may display open opportunities after organization approval, while exact capability and corridor eligibility remain authoritative only in backend functions. A marketplace visibility policy should be defined: only expose an opportunity after it has a safe, eligible partner audience, and avoid leaking customer/shipment information to broadly authenticated users.
- `krim_partner_opportunities` query visibility and RLS were not fully enumerated in this pass. Need a dedicated policy audit for cross-organization opportunity/quote/shipment metadata disclosure.
- Quote acceptance/assignment award flow has multiple legacy and leg-scoped paths. Do not use the legacy shipment-wide quote acceptance path for multi-leg plans.
- Migration history remains unreconciled (production 558 rows vs 363 repository SQL files, 348 unique timestamps). No production DDL or RPC replacement is safe until a full schema/migration crosswalk is complete.

## Verification
- Changed files were written to GitHub and should be re-fetched for final verification.
- Latest CI runs were not yet confirmed successful when this report was prepared.
- No live bids, awards, assignment acceptances, capacity reservations, dispatches, payment, settlement or payout were created.

## Next priority
1. Reconcile the production migration history and sanitized schema manifest.
2. In a reviewed migration, harden `krim_submit_partner_quote` with current compliance and corridor/shipment gates.
3. Audit RLS and direct-link disclosure for partner opportunities, quote history and shipment details.
4. Run negative/positive lifecycle tests in staging before enabling live tendering.