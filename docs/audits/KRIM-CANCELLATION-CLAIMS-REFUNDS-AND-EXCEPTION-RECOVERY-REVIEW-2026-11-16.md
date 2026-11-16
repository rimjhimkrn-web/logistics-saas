# KRIM Shipment Cancellation, Claims, Refund and Exception Recovery Review — 2026-11-16

## Scope and method
Read-only review of live shipment transition rules, claim submission/review/evidence helpers, refund request/review/execution-claim helpers and operational exception resolution. No production RPCs or financial operations were invoked. No production data/schema changed.

## CI status for prior audit commit
For `f9a3342e097c91bb371643a61d6af58b4539b157`:
- Production smoke checks: success (`43800597509`)
- Static link audit: success (`43800597468`)
- Pages deployment: in progress at last check (`43800596789`)

## 1. Shipment cancellation
The configured shipment transition table allows cancellation from:
- draft
- quoted
- confirmed
- assigned
- dispatched

All five require `shipment.cancel`. None currently requires a reason.

The generic `krim_transition_shipment` function locks the shipment, checks the configured transition, checks the required permission and checks a reason only when the transition table says it is required.

### Risk / gap
The transition matrix permits `dispatched -> cancelled` without requiring a reason. The reviewed generic transition path does not itself demonstrate coordinated cancellation of dispatch authorizations, driver assignments, capacity reservations, warehouse allocations, custody transfers, customer/partner notifications or financial records. This does not prove those controls are absent elsewhere, but they must be verified before relying on generic cancellation for a live dispatched shipment.

### Required staging acceptance tests
- Cancellation of a draft/quoted shipment.
- Confirmed/assigned cancellation with all dependent reservations released exactly once.
- Dispatched shipment cancellation blocked or routed to controlled exception/recovery unless an authorized operations workflow confirms physical stop/return.
- Cancellation after any leg is in transit blocked from generic cancellation and handled through disruption/return workflow.
- Require a meaningful reason, actor, timestamp and customer/partner notification outcome.
- Verify no cancellation reverses paid money or writes refund/settlement records automatically.

## 2. Claims workflow
Observed safeguards:
- Claim submission requires authenticated active customer-organisation membership and `shipment.update`.
- Only confirmed or closed shipments belonging to that customer organisation can be claimed.
- Claim type and active currency are validated; description has a minimum length.
- Claim evidence is restricted to PDF/JPEG/PNG, max 10 MB, uploader-owned private storage object and claimant-organisation/user-specific path.
- Evidence is inserted as pending verification and an event is recorded.
- Claim review requires AAL2, active platform/operations organisation and `admin.platform`, a meaningful note and an approved amount between zero and the claimed amount.
- Review state changes are limited to submitted/under_review/evidence_required.

### Important data-linkage gap
Claim submission selects the latest accepted/completed partner assignment for the shipment, without an explicit shipment-leg selector or a deterministic relationship to the exception/claim type. On a multi-leg shipment, this can attribute the claim to the wrong partner/leg. If no accepted/completed assignment exists, the current function can still insert the claim with a null respondent/assignment.

### Evidence storage concern
Claim evidence is checked in bucket `krim-partner-verification` using a `claim-evidence/<claim>/<org>/<user>/...` path. Confirm that the bucket policies, retention and customer/partner/admin read access are intentionally configured for claim evidence rather than inherited from partner-verification workflows. Do not loosen policies without a role-specific access map.

## 3. Refund workflow
Observed safeguards:
- Customer refund request requires authentication, positive amount, reason and idempotency key.
- Only paid payment orders are eligible.
- Partial refunds are explicitly disabled; request amount must equal the full payment order amount.
- Only one refund request is allowed per payment order; same customer/idempotency retry returns the existing request.
- Review requires AAL2, active finance/platform/operations membership, finance.manage or admin.platform, a meaningful note and separation between requester and reviewer.
- Execution claim requires AAL2, same approving reviewer, finance permission, paid INR Razorpay order, matching amount and no existing provider refund ID.
- Execution claim transitions to `execution_pending` and returns the provider payment ID, amount and idempotency key for the external execution worker. This helper does not itself prove that Razorpay executed or settled a refund; provider webhook/reconciliation is required.

### Required controls/tests
- Keep full-refund-only behaviour until cumulative partial-refund accounting is independently tested.
- Confirm the external execution worker is idempotent and only submits a provider refund once, even after timeout/retry.
- Confirm provider webhook signature verification, duplicate handling, amount/currency/payment-ID matching and terminal-state reconciliation.
- Confirm customer refund request does not promise a refund before provider confirmation.
- Verify refund events, payment ledger and customer notification reconcile exactly once.

## 4. Operational exception recovery
The reviewed exception resolver:
- Requires authenticated user and `compliance.manage` for the exception's organisation.
- Requires a meaningful resolution note.
- Rejects already closed exceptions.
- Resolves open escalations, cancels pending/triggered timers and actions, cancels queued/running/waiting escalation runs and writes an audit event.

This is a useful recovery cascade. Staging tests should confirm that child actions are safely cancelled and that any external action already in flight is reconciled rather than assumed cancelled.

## 5. Data state
Live snapshot returned zero claim rows and zero refund request rows in the queried result. This means no live sample workflow was available for validation; it does not establish that the workflows are production-tested.

## Priorities
1. Resolve the multi-leg claim-to-partner/leg attribution gap before enabling claims for multi-leg shipments.
2. Require a reason for cancellation and add a dedicated controlled post-dispatch/physical-movement cancellation workflow.
3. Verify claim-evidence storage policies and retention.
4. Verify external Razorpay refund worker and webhook end-to-end; no automatic refund promise.
5. Stage-test exception cascade and all cancellation/refund retry races.

## Conclusion
Several strong controls exist in claims, refunds and exception recovery. Two material workflow gaps remain: cancellation from `dispatched` is configured without a reason and is not shown to orchestrate dependent operational resources in the reviewed generic function; claim submission binds to the latest shipment assignment rather than an explicitly relevant leg/exception assignment. No live test transactions were run and no production change was made.

Migration-history reconciliation remains a hard prerequisite for production schema/function changes.
