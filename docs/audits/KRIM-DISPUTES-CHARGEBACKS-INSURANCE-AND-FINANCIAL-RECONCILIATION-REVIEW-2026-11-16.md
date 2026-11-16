# KRIM Disputes, Chargebacks, Insurance Boundaries and Financial Reconciliation Security Review — 2026-11-16

## Scope and method
Read-only inspection of live production dispute and reconciliation tables, RLS policies, table privileges, relevant internal finance function exposure and record counts. No RPCs, payment calls, financial postings or production mutations were performed.

## CI for preceding commit
All three checks passed for `760d48b8d9805a8613ec5ad425ef64f70b14ba56`:
- Static link audit: success (`43800728771`)
- Production smoke checks: success (`43800728712`)
- Pages deployment: success (`43800728271`)

These checks do not validate financial correctness or live transaction workflows.

## 1. Dispute framework
Live schema includes:
- `krim_disputes`
- `krim_dispute_cases`
- `krim_dispute_appeals`
- `krim_dispute_decisions`
- `krim_dispute_investigations`
- `krim_dispute_evidence_links`

All inspected dispute tables have RLS enabled and forced. Authenticated access is SELECT-only at the table level; no direct authenticated INSERT or UPDATE was granted. Policies scope reads to the dispute's owning, claimant or respondent organisation (with the legacy `krim_disputes` table limited to its `organization_id`).

### Important gap
The live database function inventory did not reveal corresponding public/private dispute lifecycle RPCs for opening, assigning, investigating, deciding, appealing or closing these dispute cases. The table design exists, but the end-to-end workflow cannot be considered operationally verified from the live database. No dispute records exist in the inspected tables.

### Chargebacks
No dedicated chargeback table or chargeback-named workflow function was found in the inspected public/private schema. This does not establish that provider-side chargebacks cannot occur; it means KRIM's own evidence, response-deadline, representment and outcome workflow is not demonstrated by this schema inventory. Build provider-specific handling only after confirming Razorpay's current dispute/chargeback product and webhook contract.

## 2. Insurance boundary
No dedicated insurance policy, coverage, insurer, premium, claim-notification or insurance-broker table/function was found by the schema-name and function-name inventory. KRIM should not represent shipments as insured, promise coverage or sell/arrange insurance based on the current inspected schema. If insurance is later offered, use a licensed insurer/intermediary and clearly separate partner-provided cover from KRIM platform services; obtain legal/regulatory review first.

## 3. Financial reconciliation framework
Tables exist for:
- reconciliation runs and reconciliation exceptions
- financial posting events and dead-letter queue
- partner payables and settlements
- financial transactions and refund requests

Internal functions exist for reconciliation runs, customer receivable and partner payout reconciliation, Razorpay captured-payment reconciliation, posting recovery/retry/quarantine and partner settlement authorisation. Effective EXECUTE checks showed the inspected internal functions are not executable by `anon` or `authenticated`.

### Data snapshot
- Dispute cases: 0
- Disputes: 0
- Appeals: 0
- Reconciliation runs: 0
- Reconciliation exceptions: 0
- Financial posting events: 0
- Financial posting DLQ: 0
- Partner payables: 0
- Settlements: 0
- Refund requests: 0
- Financial transactions: 1

No reconciliation or dispute workflow has live sample records to validate.

## 4. High-priority access-control finding: posting event and DLQ tables
Both `krim_financial_posting_events` and `krim_financial_posting_dlq` have:
- RLS enabled;
- an authenticated `ALL` policy whose row predicate is only `private.krim_has_organization_access(auth.uid(), organization_id)`;
- direct authenticated INSERT, UPDATE and DELETE table privileges.

This means any authenticated user with membership/access to the relevant organisation may satisfy the row policy and directly mutate or delete financial posting workflow records, subject to the row predicate. The policy does not visibly require `finance.manage`, a designated worker identity or an internal-only execution path. This is a material integrity risk for the posting pipeline and its recovery queue.

No test write was attempted. The tables were empty in the inspected snapshot, but emptiness does not reduce the structural risk once events are created.

### Required correction design (not applied)
- Revoke direct authenticated INSERT/UPDATE/DELETE on both tables.
- Replace broad `ALL` policy with least-privilege finance read-only access where needed.
- Route state changes through non-exposed internal functions or a tightly authenticated finance-admin workflow with AAL2 and explicit permission.
- Restrict DLQ replay/quarantine/recovery to a trusted worker or separately authorised finance operations process.
- Add regression tests proving ordinary org members cannot insert, alter or delete posting/DLQ rows; authorised worker can process an event once; retries and replay are idempotent; immutable audit evidence remains.

Because migration history is inconsistent, do not apply these corrections directly to production yet.

## 5. Settlement and non-custodial business-model boundary
Internal settlement authorisation and partner-payable ledger functions exist, but KRIM's approved initial operating model is non-custodial: customers contract with and pay logistics partners directly; KRIM charges a separately agreed fee for its own genuine referral/coordination service. Do not enable partner-fund custody, payout execution, freight collection, escrow, settlement or split-payment flows for this initial model. Keep legacy financial triggers and payout paths gated until migration reconciliation, legal review and a deliberately scoped replacement design are complete.

## 6. Required next actions
1. Treat direct authenticated mutation of posting events and DLQ as a priority security blocker; prepare a reviewed migration and staging regression suite after migration crosswalk completion.
2. Implement and test dispute lifecycle RPCs, assignment, evidence chain, independent decision, appeal and SLA deadlines.
3. Define provider chargeback webhook/evidence/deadline handling only after verifying provider contract.
4. Keep insurance out of scope until a licensed provider/intermediary and legal model are approved.
5. Run reconciliation against real sandbox/provider statement fixtures in staging; verify amount, currency, provider reference, idempotency, duplicate webhooks, missing events and variance resolution.
6. Keep customer-facing claims conservative: no claim of chargeback protection, insurance cover, audited settlement or reconciled finance until evidenced.

## Conclusion
The dispute and reconciliation schema is partly scaffolded, but no dispute/reconciliation cases or posting events were present in the snapshot. No chargeback or insurance workflow was identified by the inspected schema inventory. A material access-control issue exists: authenticated organisation members can directly insert/update/delete posting-event and DLQ rows under broad organisation-access RLS policies. This requires a carefully staged least-privilege correction before financial posting automation is trusted.

No production changes or financial operations were performed. Migration-history reconciliation remains a hard prerequisite for production schema/function changes.
