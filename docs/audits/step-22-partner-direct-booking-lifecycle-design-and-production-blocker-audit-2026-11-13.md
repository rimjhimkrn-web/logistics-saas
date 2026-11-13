# Step 22 — Partner-direct booking lifecycle design and production blocker audit

Date: 2026-11-13
Branch: website/global-launch-readiness
PR: #65 (draft; unmerged; undeployed)

## Scope
Read-only inspection of the production booking/assignment/readiness functions and the proposed branch migrations. No database writes, migration application, provider calls, test shipments, deployment, merge, or changes to customer/payment records.

## Confirmed production findings

1. Production `public.krim_accept_global_quote(bigint)` is still the older implementation. It:
   - locks the quote and shipment;
   - checks customer organization access and `shipment.update`;
   - accepts a sent, unexpired quote;
   - immediately calls `krim_transition_shipment(..., 'confirmed', ...)`;
   - does not bind the customer quote to a partner quote, verify partner eligibility, or require an accepted partner assignment.

2. Production shipment status trigger `krim_shipment_readiness_enforcement` calls `krim_internal_evaluate_shipment_readiness` for transitions to `confirmed`, `assigned`, or `dispatched`.

3. Production readiness evaluator `krim_internal_evaluate_shipment_readiness(bigint)` treats payment as:
   - `not_required` only for `draft` and `requested`;
   - otherwise requires a paid legacy `payments` record or a completed company-owned Razorpay credit in `krim_financial_transactions`;
   - missing payment adds `verified_payment_missing` and blocks readiness.

   Therefore, simply changing quote acceptance to call the current `quoted → confirmed` transition will still fail for partner-direct shipments without KRIM freight payment. The current evaluator conflates booking confirmation with dispatch/financial readiness.

4. Production readiness evaluator treats partner assignment as `not_required` for `draft`, `requested`, `quoted`, and `confirmed`. Accepted/active assignments are required only later. This means partner assignment and capacity checks are not presently a complete confirmation gate.

5. Production dispatch-capacity trigger separately blocks `dispatched` unless accepted assignments have confirmed capacity bindings and reservations. This is useful as a dispatch safeguard, but it does not solve booking confirmation.

6. Production transition RPC uses the configured `krim_shipment_status_transitions` matrix and permission/reason checks. Any replacement must preserve those checks, row locking, audit/history side effects, compliance/document gates, and existing historical payment records.

## Branch migration review

The branch contains proposals for:
- partner-linked quote and assignment validation in `20261111120000_secure_global_quote_acceptance_partner_assignment.sql`;
- AAL2 partner-review governance in `20261113120000_harden_partner_review_mfa_and_approved_lifecycle.sql`;
- rechecking active organization, registered-business mode, verification, compliance, and shipment-covering capability at quote acceptance in `20261113130000_revalidate_partner_eligibility_on_customer_quote_acceptance.sql`.

These are source proposals only. They are not sufficient by themselves to establish a safe partner-direct lifecycle:
- they still call the existing `krim_transition_shipment(..., 'confirmed', ...)`, which invokes the payment-dependent readiness evaluator;
- the quote acceptance proposal requires an already accepted assignment, while the desired UX sequence and earlier architecture require customer selection/offer followed by the partner's acceptance of that exact assignment; the state ordering and retry/rejection/expiry behavior must be designed consistently;
- capacity binding must be checked at the correct lifecycle boundary, not assumed from a partner quote;
- production migration-history reconciliation and populated staging validation have not been completed.

## Required target lifecycle (design only)

1. Customer submits an idempotent shipment enquiry.
2. Only currently verified, compliant registered-business partners with active, evidence-backed capabilities covering the shipment may submit an offer.
3. KRIM creates a customer-facing quote bound to one immutable partner quote snapshot (amount, currency, validity, service/route scope).
4. Customer accepts that exact quote. In one database transaction, lock and revalidate shipment, quote, partner quote, partner organization, capability, and customer authorization; create/activate one exact partner assignment in an awaiting-partner state. Shipment remains unconfirmed.
5. Partner accepts that exact assignment. In one database transaction, lock and revalidate the assignment, shipment, quote, partner organization, capability, service scope, validity, and capacity reservation/binding; mark assignment accepted, customer quote accepted, and shipment confirmed; append audit/status history. If the partner rejects, expires, loses eligibility, or cannot bind capacity, leave shipment unconfirmed and provide a controlled re-quote/reassignment path.
6. Booking confirmation must not require KRIM freight payment. Customer and partner arrange freight payment directly. Dispatch readiness remains a separate gate and must still require all applicable operational, compliance, document, customs, driver/vehicle, and confirmed-capacity conditions. Historical KRIM payment records remain read-only/reconcilable and must not be reinterpreted as partner-direct payments.

## Required implementation and validation before production

- Design explicit state transitions and a single transactional RPC for each customer-selection and partner-response boundary, with stable idempotency keys and race-condition protection.
- Separate booking-confirmation eligibility from dispatch readiness/payment evidence. Do not globally remove payment checks from historical financial reconciliation or from unrelated legacy workflows.
- Validate the configured status matrix, trigger ordering, quote/assignment uniqueness, capacity reservation semantics, cancellation/rejection/expiry behavior, audit events, permissions, RLS/function ACLs, and concurrency.
- Reconcile production migration history before preparing any new migration.
- Populate a safe staging environment with synthetic fixtures only, then test positive, negative, retry, duplicate, concurrency, partner suspension/capability withdrawal, expired quote, rejection, capacity conflict, compliance/document failure, and legacy payment regression cases.
- Production currently has no safe populated staging equivalent established in this audit. No production migration is authorized or recommended yet.

## Result
Step 22 is a design and blocker audit, not an implementation or launch approval. The central blocker is confirmed: production booking confirmation remains coupled to KRIM payment-dependent readiness, and the branch quote-acceptance proposal still calls that same transition. Do not merge/deploy or apply the proposed migrations until the booking-vs-dispatch separation is designed, staged, and verified.
