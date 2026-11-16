# KRIM POD Authorization and Delivery State Transition Review — 2026-11-16

## Scope
Read-only source and effective privilege review of internal POD submission, verification and delivery authorization helpers, the authenticated admin review wrapper, and custody-transfer response/next-leg guard. No RPCs were invoked and no production data or schema was changed.

## CI status
For preceding commit `c3dd514d6b0104ccc33df43cb79ea04508579585`:
- Production smoke checks: success (`43800536488`)
- Static link audit: in progress at last check (`43800536543`)
- Pages deployment: waiting at last check (`43800536071`)

## Internal POD helper exposure
- `krim_internal_submit_delivery_pod`, `krim_internal_verify_delivery_pod`, and `krim_internal_authorize_delivery` are SECURITY DEFINER with empty search_path.
- Effective EXECUTE privilege checks show neither `anon` nor `authenticated` can execute these internal helpers directly.
- The exposed admin review wrapper requires authenticated user, AAL2 and platform-admin permission before invoking verification and delivery authorization.
- Driver submission wrapper binds the caller to the driver assignment, requires active driver membership, in-transit state, accepted commercial assignment and at least one registered private evidence object owned by that driver.
- This materially reduces the risk of callers supplying an arbitrary verifier UUID to the internal helper: the helpers are not directly executable by app roles, and the public wrapper supplies the authenticated reviewer identity.

## Delivery authorization state transitions observed
- POD must already be verified.
- POD assignment, shipment, leg and partner linkage are reloaded and locked and must match.
- The exact shipment leg and assignment must remain eligible.
- Single-leg and multi-leg branches are handled separately: a multi-leg route validates the active route plan and exact plan-item linkage; the non-multi-leg path requires shipment status `in_transit`.
- The verified leg is marked completed for multi-leg or delivered for single-leg; partner assignment is marked completed.
- Multi-leg shipment is marked delivered only when all plan items are materialized and all legs are completed/delivered.
- Single-leg shipment is marked delivered only when no other nonterminal leg remains.
- Delivery tracking, partner execution and audit events are written in the same transaction.
- Repeat authorization for an already-delivered shipment/leg returns idempotently.

## Custody transition guard
- A leg cannot transition into `in_transit` when it is a subsequent leg in an active multi-leg plan unless an accepted custody transfer exists from the immediately preceding leg.
- Transfer acceptance rechecks receiving partner permission, leg/partner linkage, accepted receiving assignment and confirmed capacity.
- Transfer offer and response operations lock transfer/leg rows and use idempotency/state checks.

## Residual risks / required staging tests
1. **POD evidence quality is not independently established by file existence.** The reviewed path checks ownership, bucket, registered evidence and metadata constraints, but the code review does not prove that the image/document depicts the named recipient, actual cargo or delivery location. Add an explicit evidence review checklist and keep verification as an accountable human decision; do not market POD as tamper-proof or independently authenticated.
2. **Verifier identity is a trusted parameter inside private helpers.** Current exposure is blocked by effective grants and wrappers, but future grants or new wrappers must preserve that trust boundary. Add a privilege regression test asserting no anon/authenticated EXECUTE on internal helpers and only the MFA-gated wrapper can authorize delivery.
3. Test rejected POD resubmission, immutable verified POD, repeated review, driver evidence deletion after submission, storage object deletion, stale assignment, changed route plan, cancelled/revoked capacity and multi-leg final-leg delivery.
4. Verify whether any operational admin or service-role process can change a verified POD or its evidence metadata outside this wrapper; table RLS alone does not constrain service-role or owner operations.
5. Verify that the next-leg custody trigger, dispatch authorization and any status transition RPC all enforce the same accepted-transfer invariant.

## Conclusion
The reviewed internal POD helpers are not directly executable by anon/authenticated roles, and the public admin review path is AAL2/platform-admin gated. The delivery state machine contains explicit single-leg/multi-leg handling and transactionally writes delivery/audit events. Remaining work is principally evidence-quality assurance, regression tests around helper grants, and end-to-end revocation/route-plan scenarios. No direct bypass was demonstrated.

## Operational caution
This is a source-level review, not a staging or real-world delivery test. KRIM still lacks verified operational partners and confirmed capacity-backed bookings. Keep customer booking and delivery claims gated until partner evidence and end-to-end tests exist. Production schema changes remain blocked pending migration-history reconciliation.
