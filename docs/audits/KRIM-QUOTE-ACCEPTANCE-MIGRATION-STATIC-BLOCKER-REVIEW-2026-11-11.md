# Review of Existing Global Quote Acceptance Migration — Blockers
Date: 2026-11-11
Branch: `audit/workspace-rls-review-2026-11-11`
Status: STATIC REVIEW ONLY — NO SQL EXECUTED

## File reviewed
`supabase/migrations/20261111120000_secure_global_quote_acceptance_partner_assignment.sql`

## Decision
Do not apply this migration as-is. It is a useful narrow hardening attempt, but it does not implement the coordinated booking contract and it leaves material authorization, lifecycle and capacity gaps.

## Findings

### P0 — Customer acceptance still confirms shipment without capacity reservation
The function checks for an accepted assignment, but it does not require:
- a committed shipment-level capacity commitment;
- a confirmed capacity-leg binding;
- a confirmed physical resource reservation;
- the binding/reservation to match the assignment, partner, shipment and leg.

Production already has a two-stage capacity model. Partner acceptance creates the shipment-level commitment; partner scheduling reserves a physical resource and confirms the leg binding. The migration checks only `assignment.status='accepted'`. Customer acceptance can therefore proceed before the physical reservation gate.

### P0 — Function still transitions shipment to confirmed
The migration calls `krim_transition_shipment(...,'confirmed',...)` immediately after customer quote acceptance. Production readiness logic requires verified payment evidence for states beyond `draft/requested`; the readiness trigger may reject this transition when no payment exists. Even if a particular path passes, the migration does not itself verify provider payment evidence or coordinate order/verification/webhook state. This remains an overloaded and unsafe boundary.

### P1 — Missing explicit null-authentication guard
The migration calls `auth.uid()` through helper checks but does not explicitly reject a null identity at the start. Helper behavior should be confirmed, and explicit fail-closed authentication is clearer and safer. Add an explicit null-user guard and stable SQLSTATE errors.

### P1 — Partner quote state accepts non-accepted commercial offers
The lookup allows partner quote statuses `submitted`, `under_review`, `shortlisted` or `accepted`. The later assignment check does require an accepted assignment linked to that quote, which narrows exposure, but the partner quote and assignment states should be mutually consistent. Require partner quote status accepted once the partner has accepted, and verify opportunity award fields and partner organization linkage.

### P1 — Missing quote-version acceptance and audit/event coordination
The migration updates `krim_quotes.status` only. It does not accept the current presented quote version, write a dedicated acceptance event/audit record, or verify version amount/currency/validity/pricing snapshot consistency. It may leave quote and version state divergent.

### P1 — Idempotency is not implemented
A repeated call after the first acceptance fails because it requires quote status `sent`. A safe retry should return the already accepted quote only if the same authorized customer, shipment, partner assignment, quote version and payment state still match. Contradictory retries must fail.

### P1 — Lock order is incomplete
It locks customer quote, shipment, and partner quote, but reads assignment through EXISTS without locking it and does not lock opportunity/capacity rows. Concurrent rejection, expiry, replacement or reservation changes can race. A single documented lock order must be used by all lifecycle RPCs.

### P2 — Error and expiry semantics are inconsistent
An expired quote is updated to `expired` and returned rather than raising a distinct expiry outcome. No quote-version expiry or event is recorded. The function does not close related pending offer state.

### P2 — Permission and ownership assumptions need exact helper review
The function uses public helper names `public.krim_has_organization_access` and `public.krim_has_permission`, while production's current award and assignment functions use `private.krim_has_organization_access` and `private.krim_has_permission`. Confirm these public wrappers are equivalent, current and safe; do not assume.

## Required disposition
- Keep this migration review-only; do not merge or apply it.
- Replace it with the coordinated, versioned lifecycle implementation only after schema/caller/consumer inventory is complete.
- Preserve existing payment and capacity fail-closed checks.
- Update tests to prove no customer acceptance before partner acceptance AND confirmed capacity reservation/binding.
- Include quote version, event, audit, retry and race behavior in the same transaction.
- Verify function EXECUTE grants and all old callers before cutover.

## Non-actions
No database query executed this review; no function, grant, trigger, table, data, payment or deployment was changed. Staging remains blank and has no migrations.
