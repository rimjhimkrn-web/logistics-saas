# KRIM P0 Financial Security Remediation Plan — Razorpay Webhook Kill Switch and Revenue Allocation Authorization — 2026-11-16

## Status and boundaries
**Plan only. No code, deployment, database grant, policy, schema, migration, payment, refund or ledger changes are made in this commit.**

Baseline commit reviewed: `28168610ad780b7c4e8df3c577a380961210473a`. Its production smoke, static-link and Pages deployment workflows completed successfully. That CI success verifies repository checks and Pages deployment only; it does not deploy or verify Supabase Edge Function source parity and does not certify financial security.

The production/repository migration-history mismatch remains a hard blocker for all production DDL/policy/grant changes. The production schema-manifest workflow has not yet been run by the user. Do not apply, replay, baseline, squash or invent migrations to work around that mismatch.

## 1. P0 — Razorpay webhook freight-collection kill-switch bypass

### Evidence
- `supabase/functions/create-global-razorpay-order/index.ts` checks both `KRIM_FREIGHT_COLLECTION_ENABLED=true` and `KRIM_FREIGHT_COLLECTION_APPROVAL_VERSION=2026-11-15-v1` before creating a new Razorpay order.
- The canonical `razorpay-webhook` verifies the Razorpay HMAC signature and event ID, stores the webhook event, then processes `payment.captured` / `order.paid` by transitioning a matching local `payment_orders` row to `paid` and invoking `krim_internal_reconcile_razorpay_captured_payment`.
- The webhook source does not check either freight-collection approval variable before the paid-state transition or company-owned financial posting.
- The internal reconciliation RPC validates shipment/quote/partner-quote/assignment/capacity and amount/currency, but these operational checks do not establish that KRIM is legally approved to receive partner freight funds.
- Existing production evidence includes five `created` payment orders, one `paid` payment order, two unprocessed `payment.captured` events and two unprocessed `order.paid` events. Do not assume these are test-only or safe to replay. Provider and bank state remain unverified.

### Target behaviour
1. Keep signature verification, strict payload validation and event-ID idempotency active regardless of collection mode.
2. Keep new freight checkout disabled by default.
3. While collection approval is absent, **no new captured/order-paid event may transition a payment order to paid or create/update a company-owned freight receipt**.
4. Do not silently discard valid provider events. Persist them in a durable, auditable deferred/quarantine state, with provider event ID/type, provider order/payment IDs, amount/currency, received timestamp, and reason. Never persist secrets.
5. Acknowledge a deferred event to the provider only after durable quarantine and alert/outbox creation have succeeded; a transient failure to persist/alert must return a retryable non-2xx response. This prevents untracked captures while avoiding endless provider retries after a durable handoff.
6. An independent operator reconciliation process must classify each quarantined event as test, duplicate, failed, legacy paid, actual captured payment or conflict. It must compare the provider statement and bank settlement evidence before any accounting correction.
7. Historical captured payments must use a separate, narrowly scoped, operator-authorised recovery process with exact order/payment/amount/currency binding, maker-checker approval and immutable audit. Do not let the historical recovery path become a general way to turn freight collection back on.
8. Keep `payment.failed` and `payment.authorized` informational handling separate from captured/paid settlement. They must never create a completed payment credit.
9. Preserve the independently approved historical refund-outcome path only for an existing, previously approved KRIM refund request and exact original provider payment. Refund webhooks report provider outcomes; they must not initiate a refund. Do not block legitimate historical refund reconciliation merely because new freight checkout is disabled.
10. New collection may only be enabled after explicit user approval, legal/tax/bank/merchant/partner-contract readiness, and a new versioned approval control. This is not authorised by this plan.

### Implementation design
- Add a shared server-only collection-mode decision helper used by order creation, payment verification and captured-payment webhook processing. The webhook must not have a weaker or separately hard-coded interpretation.
- Resolve the exact payment order and event correlation before any paid-state mutation. Reject unknown/mismatched provider order IDs, payment IDs, amount, currency or capture state.
- Use an atomic database operation for event claim + order state transition + financial transaction insertion, with a stable provider-event/payment idempotency key and full-payload conflict detection. Avoid separate non-transactional REST updates that can leave paid state without a ledger record or vice versa.
- If collection is disabled, store a durable deferred event without mutating the payment order, canonical financial transaction, shipment financials or revenue ledger.
- A previously paid order with the same provider payment ID must not be treated as permission for automatic company-owned freight posting. Verify its existing financial transaction exactly; if it is absent or inconsistent, quarantine for controlled recovery.
- A different payment ID for an already-paid order is always a conflict requiring manual review.
- Add operator alerting, retry ownership, age/SLA monitoring and a dead-letter state for events that cannot be safely correlated.
- Restrict logs to identifiers and safe diagnostic codes; never log webhook secrets, full payment credentials or unnecessary personal data.
- Keep provider webhook endpoint authentication based on exact raw-body HMAC signature verification. Validate signature encoding/length and reject malformed hex before comparison.

### Important state-machine detail
The current webhook table has a boolean `processed` flag. A durable quarantine lifecycle may need explicit `processing_status` / `deferred_reason` / `reviewed_by` / `reviewed_at` / `resolution_reference` fields or a separate restricted reconciliation queue. **Do not add these fields or create a new table until schema-manifest reconciliation is complete and a reviewed migration is authorised.** Do not set `processed=true` merely to suppress retries unless a durable quarantine record and operational alert have been committed atomically.

## 2. P1 — Revenue allocation tables have organisation-member DML exposure

### Evidence
Live catalog review found RLS enabled on:
- `krim_revenue_allocation_rules`
- `krim_revenue_allocation_runs`
- `krim_revenue_allocations`

Each table has an `org_isolation_all` policy for `authenticated`, using `private.krim_has_organization_access(auth.uid(), organization_id)` for both `USING` and `WITH CHECK`. Authenticated has direct INSERT, UPDATE and DELETE table privileges on all three tables. Authenticated SELECT privilege is not granted on these tables, and the current RLS policy is `ALL`; direct INSERT is therefore the clearest confirmed exposure. UPDATE/DELETE effective behaviour must be tested in an isolated staging project because Postgres UPDATE/DELETE may also require row visibility/SELECT access.

All three tables were empty at the audit snapshot. Empty tables do not make the authorisation design safe.

### Target access model
- Ordinary organisation membership alone must never authorise financial rule creation, allocation planning, mutation or deletion.
- Rule administration requires a specific finance/platform permission, AAL2, active membership, exact organisation scope and independent maker-checker approval for material changes.
- Allocation runs and allocation rows should be append-only operational/accounting records. Corrections use linked reversal/supersession events, not UPDATE/DELETE.
- Internal allocation functions should be callable only by trusted server-side orchestration and must independently validate source transaction, organisation, shipment, revenue scope, currency, effective rule version and ownership model.
- The current partner-direct model must not allocate partner freight GMV as KRIM revenue. Only KRIM's own separately contracted service fee can be recognised as KRIM revenue after tax/legal readiness.
- Avoid granting client SELECT merely to make UPDATE work. If finance users need read access, provide tenant-scoped read policies/views with an explicit finance permission and security-invoker semantics where applicable.

### Implementation design
1. First determine which application pages and RPCs depend on direct table writes.
2. Replace direct DML with narrow RPCs or trusted service-side operations that verify finance permission, AAL2, active org membership and maker-checker rules.
3. Revoke authenticated INSERT/UPDATE/DELETE from all three tables, then grant only the minimum required privileges to the trusted execution role/function path. Preserve service-role access only where necessary.
4. Replace `org_isolation_all` with purpose-specific read policies only if the UI requires reads; do not create broad tenant-member write policies.
5. Add immutable audit events for rule approval, run creation, allocation posting, reversal and supersession.
6. Add database constraints and idempotency fingerprints for the full allocation payload, not only a unique reference.
7. Verify SECURITY DEFINER function ownership, fixed safe search_path, explicit auth/permission checks, EXECUTE grants and function dependency chain. Do not use SECURITY DEFINER as a shortcut around missing authorization.

**No grant or policy change is included in this plan.**

## 3. Required staging acceptance matrix

### Webhook and payment safety
- A signed `payment.captured` event while collection is disabled is durably quarantined and cannot update payment order, shipment financials, revenue ledger or financial transactions.
- A signed `order.paid` event while collection is disabled has identical no-posting behaviour.
- A valid deferred event is acknowledged only after durable quarantine and alert creation; failed persistence returns retryable error.
- Repeated delivery of the same event ID creates one quarantine record and one alert reference.
- Same provider order/payment/amount/currency duplicate is idempotent; conflicting payment ID or amount/currency is quarantined as conflict.
- A local order in `created` state cannot be paid through webhook while collection is disabled.
- An already-paid historical order does not trigger automatic new posting while disabled; exact historical recovery requires explicit independent approval.
- `payment.authorized` never posts a completed receipt.
- `payment.failed` never downgrades a paid order or posts a receipt.
- Historical refund outcome events are reconciled only against an exact pre-existing approved refund request and original payment; no refund is initiated.
- No endpoint can enable collection by client-supplied body, header or query parameter.
- Secret/approval version absent, malformed or wrong version fails closed.
- Provider settlement and bank evidence must match before historical financial classification.

### Revenue allocation permissions and integrity
- Ordinary authenticated organisation member cannot INSERT a rule, run or allocation.
- Ordinary authenticated organisation member cannot UPDATE/DELETE any existing rule/run/allocation.
- Finance user without AAL2 is denied material write/approval.
- Finance user with wrong organisation membership is denied.
- Finance user cannot approve own material rule or allocation change.
- Platform admin action is audited with actor, permission, AAL, organisation, prior/new state and reason.
- Allocation rows are immutable; correction creates linked reversal/supersession.
- Reusing an idempotency/reference key with a changed amount, currency, source, shipment, rule or beneficiary is rejected as a conflict.
- Allocation cannot treat partner freight GMV as KRIM revenue under partner-direct model.
- Concurrent duplicate run creation produces exactly one canonical run and allocation set.
- Failed posting rolls back all related allocation and audit writes atomically.

All tests above are prospective. They have not been executed.

## 4. Safe rollout sequence
1. **Containment decision:** keep checkout disabled; identify and reconcile the five open provider orders, one paid order and four unprocessed capture/order-paid webhook events. Do not replay them.
2. **Evidence recovery:** complete the sanitized production schema manifest workflow and migration crosswalk. Confirm exact live definitions and repository migration history.
3. **Staging baseline:** create isolated staging fixtures with synthetic provider events and test identities. Never use production business RPCs to simulate the tests.
4. **Code change:** implement the shared collection-mode helper, durable deferred event handling and atomic reconciliation path in source control.
5. **Database change design:** draft reviewed migration(s) for deferred-event state and revenue-allocation permissions only after canonical schema reconciliation. Review migration history, grants, policy dependencies, RPC callers and rollback strategy.
6. **Security review:** inspect Edge Function deployment configuration, JWT settings, webhook signature handling, service-role usage, function search_path/EXECUTE grants and RLS. Run Supabase security advisors.
7. **Staging tests:** execute the full matrix, including concurrent duplicate deliveries and cross-tenant denial. Record request IDs, result codes and before/after state snapshots.
8. **Deployment gate:** require explicit user approval for any production change, verified backups/restore plan, known provider order state and controlled deployment window.
9. **Post-deployment verification:** verify deployed function source/version matches the reviewed commit, kill switch rejects capture mutations, no unexpected financial writes occurred, and event quarantine/alerts operate.
10. **Separate financial activation:** do not enable live freight collection as part of this remediation. That requires separate legal, tax, merchant, bank, partner-contract, settlement and explicit user approval.

## 5. CI and repository status
- Baseline main commit: `28168610ad780b7c4e8df3c577a380961210473a`.
- Production smoke checks: passed.
- Static link audit: passed.
- Pages build/deployment: passed.
- These workflows do not prove Supabase Edge Function deployment parity, database migration reconciliation or financial staging acceptance.

## 6. Supabase platform change note
The current Supabase changelog lists the November 4, 2026 CLI v3 change: CLI v3 is local-by-default and explicitly confirms hosted changes. Any future CLI runbook must pin/verify the installed CLI version and never assume a CLI v3 command changes the hosted project implicitly. The October 30, 2026 PostgreSQL 15.19/17.11 minor-release note mentions possible reindexing/legacy pgcrypto cipher considerations; no extension or encryption change is proposed here. No platform upgrade is required by this remediation plan.

## 7. Explicit non-actions
- No production Edge Function deployed or changed.
- No environment secret read, created or changed.
- No database grant, policy, function, table, trigger, schema or migration changed.
- No webhook replay or provider API call.
- No payment, refund, payout, invoice, revenue allocation or ledger posting initiated.
- No partner/customer communications.
- No financial collection enablement.
