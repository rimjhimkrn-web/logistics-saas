# Customer booking and quote lifecycle — read-only revalidation

**Date:** 2026-11-17  
**Status:** Production function and trigger inspection only. No business data or schema changed.

## 1. Booking creation: confirmed blocker

Live `public.krim_create_global_shipment(bigint,bigint,bigint,text,numeric)` inserts into `public.krim_shipments` without setting `requested_transport_mode`.

The live table has a BEFORE INSERT trigger:
`krim_enforce_corridor_compliance_before_shipment_write`
which fires on INSERT and UPDATE OF origin, destination and requested_transport_mode and invokes `private.krim_enforce_corridor_compliance_on_shipment_write()`.

Therefore the current create RPC is inconsistent with the live trigger's required mode-at-insert contract. The legacy wrapper that calls the old function and sets mode afterward cannot repair a rejected INSERT. A mode-aware proposal already exists at `docs/remediation-pending/2026-11-16-mode-aware-shipment-creation-rpc.sql`; it remains NOT A MIGRATION and must not be deployed before migration reconciliation, exact live definition/ACL review and staging tests.

Other live BEFORE/AFTER triggers enforce market activation, corridor compliance, initial shipment-leg creation, shipment audit, readiness, dispatch capacity and multi-leg dispatch constraints. These must remain authoritative; do not bypass or disable them to make booking succeed.

## 2. Quote acceptance: positive controls and unresolved risks

The inspected `krim_accept_global_quote(bigint)`:
- locks quote and shipment;
- requires customer organization access and `shipment.update`;
- expires an overdue quote;
- requires shipment status `quoted`;
- requires a matching accepted partner quote and accepted partner assignment for the same shipment;
- checks partner active/verified/current capability;
- transitions shipment to confirmed and finalizes the partner assignment.

However:
- Partner assignment selection uses `ORDER BY created_at DESC LIMIT 1` rather than requiring exactly one matching accepted assignment. Ambiguous duplicates should fail closed.
- The accepted-quote idempotent branch chooses the latest matching assignment and calls finalization; it does not prove uniqueness.
- The partner eligibility check relies on a stored partner compliance status allow-list plus capability/corridor helper; current compliance must be revalidated through the canonical current-compliance helper at the exact acceptance boundary.
- The quote-to-assignment equality is shipment and partner quote based, but exact leg binding and physical reservation remain separate blockers already documented in dispatch/capacity specifications.

## 3. Partner quote submission: controls and gap

The inspected `krim_submit_partner_quote(bigint,numeric,text,timestamptz,text)` requires authentication, exactly one eligible registered-business partner organization, quote.create permission, active currency, open opportunity, positive bounded amount, non-self bidding, and current capability/corridor coverage. It blocks shipment-wide quoting when an active multi-leg plan exists.

The function updates an existing submitted/under-review/shortlisted quote or inserts a new quote. The existing-row update path should be tested for concurrency and whether the selected quote is uniquely constrained per opportunity/partner. The current query uses latest-row selection; schema uniqueness and concurrent submissions must be reconciled before calling this safe.

## 4. Quote-to-checkout / customer award path

The inspected `krim_award_partner_quote_for_checkout` requires customer organization access, quote.update and shipment.update permissions; checks opportunity/shipment ownership, deadlines, partner quote status/validity, positive amount and quote validity; blocks shipment-wide award for multi-leg plans; then creates an assignment and customer quote/version/event.

It explicitly records that tax is not separately calculated and payment is arranged directly with provider after final quote acceptance. This is consistent with the intended non-custodial pilot model only if the UI and contracts also make clear that KRIM is not collecting partner freight charges.

The older `accept_shipment_quote(bigint)` operates on legacy `shipment_requests` and only changes quote_status based on customer_id. It is a parallel legacy lifecycle and must not be mistaken for canonical `krim_shipments/krim_quotes` execution. It should be retired or isolated after caller inventory and migration reconciliation.

## 5. Required remediation and staging tests

1. Resolve the mode-at-insert mismatch with a canonical mode-aware create RPC; keep corridor and market triggers enabled.
2. Make customer quote acceptance require exactly one matching accepted partner assignment; fail on zero or multiple rows.
3. Revalidate current partner compliance, capability, route/corridor, quote currency/amount and validity at the acceptance transaction boundary.
4. Require exact shipment-leg linkage and confirmed physical capacity reservation before final assignment/confirmation; no abstract shipment-only commitment is enough for dispatch readiness.
5. Inventory and restrict legacy `shipment_requests` quote functions and all callers; do not allow two parallel booking/quote state machines to represent the same journey.
6. Audit all function owners, effective ACLs (including PUBLIC and inherited grants), SECURITY DEFINER search_path, triggers and service-role callers.
7. Staging tests: valid and invalid mode; inactive market/corridor; wrong tenant; missing permissions; zero/multiple partner assignments; expired quotes; changed compliance; duplicate/concurrent partner quote submissions; exact-leg and capacity mismatch; legacy endpoint isolation; rollback and idempotency.

## Release decision

**NO-GO for customer self-service live booking/quote acceptance** until mode-aware booking creation is reconciled and staged, exact partner assignment selection is unambiguous, current compliance and exact-leg capacity are enforced, and legacy lifecycle callers are isolated. No production DDL, grants or customer/partner business records were changed during this review.
