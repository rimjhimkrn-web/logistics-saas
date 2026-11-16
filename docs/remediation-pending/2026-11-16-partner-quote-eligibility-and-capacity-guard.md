# Partner quote eligibility and capacity guard — remediation specification

**Date:** 2026-11-16  
**Status:** Prepared from read-only production inspection; NOT applied.  
**Risk:** P0/P1 commercial integrity.  
**Production writes:** None. No quote, opportunity, assignment, capacity or shipment records were created or changed.

## Verified live RPCs

The production database contains both:

- `public.krim_submit_partner_quote(bigint,numeric,text,timestamp with time zone,text)`
- `public.krim_submit_leg_partner_quote(bigint,numeric,text,timestamp with time zone,text)`

The leg-scoped quote RPC already calls `private.krim_partner_compliance_is_current(partner_id)` and `private.krim_partner_capability_covers_shipment_leg(partner_id, leg_id)`, and rejects non-empty unreviewed special cargo requirements.

The legacy shipment-wide quote RPC checks stored organization compliance labels and active verified capability rows, then calls `private.krim_partner_capability_covers_shipment`. It does **not** call the current compliance helper. It also remains a separate quote path and must not be assumed to inherit leg-scoped protections.

Award RPCs also exist in two forms:

- `public.krim_award_partner_quote(bigint)`
- `public.krim_award_leg_partner_quote(bigint)`

The leg award path calls the current compliance helper and exact-leg capability helper. The shipment-wide award path checks stored compliance labels and capability coverage but does not independently recheck current compliance evidence.

## Capacity schema confirmed

Production has these relevant tables and columns:

- `krim_partner_capacity_availability`: organization, resource, lane, transport mode, availability window, capacity value/unit, status, source type.
- `krim_partner_capacity_commitments`: organization, lane, mode, commitment period, committed/reserved/utilized capacity, status.
- `krim_capacity_reservations`: organization, availability/commitment, shipment/leg, requested capacity/unit, status, hold expiry, idempotency key.
- `krim_capacity_leg_bindings`: shipment/leg, reservation, availability/commitment, booking, requested/bound capacity, status.
- `krim_partner_shipment_capacity_commitments`: assignment, partner, committed quantity/unit, status, validity.

These tables are distinct concepts. A registered capability or an aggregate network-capacity row is not proof of a live, unconsumed, time-compatible physical reservation for a specific shipment leg.

## Required remediation before enabling commercial quoting

1. **Current compliance at every commercial boundary**
   - Call the canonical current-compliance evaluator at quote submission, quote award, assignment acceptance and capacity binding.
   - Re-read current evidence and effective/expiry dates; never rely solely on cached `partner_compliance_status`.
   - Fail closed on missing, stale, expired, rejected, pending or indeterminate evidence.
   - Keep explicit exemptions narrow, sourced from a reviewed rule, and auditable. A stored `not_required` label alone must not bypass evidence evaluation.

2. **Exact operating authority**
   - Require a currently effective approved partner service-area record for the exact origin/destination and mode.
   - Require active market activation plus an approved corridor dossier and current mandatory corridor controls for the exact leg.
   - Do not infer corridor approval from country, market, location, capability or network-corridor catalogue membership.
   - Reject stale source evidence, out-of-window dossier/controls, unsupported mode and special cargo without a reviewed requirement-to-capability evaluator.

3. **Capacity must be evidence, not a label**
   - At quote submission, distinguish a non-binding price indication from a capacity-backed offer. Do not represent either as guaranteed availability unless the platform has a valid reservation.
   - Before award/acceptance or any promise of service, atomically bind a time-compatible availability/resource record to the exact shipment leg.
   - Validate organization, mode, lane, unit, capacity quantity, schedule overlap, resource status, and remaining capacity after active reservations, bookings, commitments and utilization.
   - Lock the canonical capacity row(s) in deterministic order; serialize concurrent requests; reject overbooking unless a separately authorized, reasoned exception is explicitly supported.
   - Bind one exact reservation to one exact shipment leg. Retries must compare canonical payload and schedule; never reuse a reservation for a changed leg, amount, unit or time window.
   - Release/cancel capacity only through an audited, idempotent lifecycle transition. Expired holds must not count as available until safely reconciled.

4. **Legacy paths**
   - Either bring shipment-wide quote/award RPCs up to the same current-compliance, market/corridor, exact service-area and capacity standard, or retire/revoke their execution grants after dependency review.
   - Do not rely on UI hiding to secure callable database functions.
   - Preserve existing customer/partner permission checks and add explicit tenant/organization binding at each boundary.

## Required staging test matrix

- Current, expired, pending, rejected and missing partner compliance evidence.
- Stored organization label says compliant while canonical evidence is expired/revoked.
- Partner service area missing, pending, expired or wrong mode.
- Market active but activation control blocked.
- Corridor draft, missing dossier, expired source, pending/unknown mandatory control.
- Special cargo requirements absent, empty, non-empty reviewed and non-empty unreviewed.
- No capacity; insufficient capacity; wrong unit; wrong mode/lane; out-of-window availability; inactive resource.
- Existing reservation/booking/commitment/utilization reduces available capacity below requested quantity.
- Two concurrent quote/award requests competing for final capacity; exactly one may succeed.
- Same idempotency key and identical payload; same key with changed quantity, schedule, unit or leg.
- Cancellation/expiry releases capacity exactly once and does not release consumed/committed capacity.
- Direct invocation of every legacy RPC, not just UI workflows.
- Tenant isolation, permission denial, AAL requirements where applicable, audit event correctness and transaction rollback.

## Release gate

Do not enable commercial quote submission or award until:

- repository migration history is reconciled with the live database;
- canonical function definitions, grants, ownership, search_path and dependencies are reviewed;
- a reviewed migration is tested against a production-like staging database;
- concurrency tests prove no overbooking or stale-compliance award;
- all legacy entry points are either corrected or safely retired;
- approved partner, service-area, market, corridor and capacity evidence actually exists.

**Current production context:** Earlier read-only operational audits found zero approved partner service-area rows, zero approved corridor dossiers/controls and no accepted assignments or capacity reservations. Therefore this remediation must not manufacture availability or turn catalogue metadata into operational approval.
