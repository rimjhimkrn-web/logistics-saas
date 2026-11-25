# Phase 00 — Warehouse, customs, operations handover and custody-chain audit
Date: 2026-11-25
Branch: qa/phase-00-baseline-2026-11-25
Scope: read-only Production/Staging catalog, exact row counts, RLS policies, selected RPC source and execute privileges.

## Safety
No database writes, function invocations, Storage uploads, auth changes, provider calls, shipment movements, customs submissions or warehouse actions were performed. This is static/database-catalog evidence, not runtime journey verification.

## Exact data counts

| Canonical table | Production | Staging |
|---|---:|---:|
| krim_warehouse_facilities | 0 | 0 |
| krim_warehouse_tasks | 0 | 0 |
| krim_warehouse_inventory | 0 | 0 |
| krim_warehouse_receipts | 0 | 0 |
| krim_warehouse_evidence | 0 | 0 |
| krim_customs_broker_assignments | 0 | 0 |
| krim_customs_document_submissions | 0 | 0 |
| krim_shipment_customs | 0 | 0 |
| krim_shipment_leg_custody_transfers | 0 | 0 |
| krim_shipment_leg_dispatch_authorizations | 0 | 0 |
| krim_shipment_legs | 1 | 0 |

No meaningful warehouse receipt-to-stock-to-pick/pack-to-handover, customs clearance, or multi-partner custody transfer can be exercised using existing records in either environment.

## Security and permissions findings

1. Custody transfer tables `krim_shipment_leg_custody_transfers`, `krim_shipment_leg_custody_transfer_events` and `krim_shipment_leg_dispatch_authorizations` have RLS enabled but zero table policies in both environments. They are not FORCE RLS. This blocks ordinary policy-based direct access for authenticated users; it does not prove exposure. Their intended access appears to be through SECURITY DEFINER RPCs. Review grants and function authorization as the supported interface; do not add broad table policies.
2. Customs document submissions have a scoped SELECT policy in both environments: owning customer shipment permission, accepted customs broker assignment with compliance.view, or platform admin with AAL2. Warehouse task SELECT requires active membership, active approved facility and warehouse eligibility.
3. `krim_create_leg_custody_transfer` is executable by authenticated in both environments and not anon. Source requires adjacent legs of same shipment and active plan, distinct releasing/receiving partners, completed releasing leg with actual arrival, valid releasing and receiving partner assignments, confirmed receiving capacity reservation, cargo manifest reconciliation, evidence path and idempotency key. Releasing partner needs partner.manage.
4. `krim_respond_to_leg_custody_transfer` is executable by authenticated in both environments and not anon. Source restricts response to receiving organization partner.manage, rechecks receiving leg/partner and accepted assignment plus confirmed capacity on acceptance, records accepted/rejected event and handles same-result replay.
5. `krim_warehouse_transition_task` and `krim_warehouse_review_transfer_quality` are authenticated-executable in Production but not Staging. This is material permission drift: Staging authenticated warehouse operators cannot call these public RPC entry points. Do not blindly grant; inspect wrapper/private function grants and intended deployment model before a least-privilege migration.
6. Customs broker/document RPC wrappers (case creation, broker assign/respond/close/license submit/review, document submit/review and case transition) are authenticated-executable and not anon in Production. This report did not verify each private implementation end-to-end or fully compare all customs RPC ACLs in Staging; treat those workflows as source-review pending, not passed.

## Workflow integrity signals from source

- Warehouse task transition uses row locking, organization/facility operator checks, a transition idempotency key, allowed state graph and terminal-state protection. Completing inbound receiving expects a matching shipment-linked receipt; goods receipt records an inventory movement; putaway checks the full lot; picking/packing records a negative movement; dispatch handover requires completed picking for the same shipment and leg.
- Warehouse transfer quality review requires a distinct reviewer from dispatcher and receiver, private reviewer-owned evidence in `krim-warehouse-evidence`, a held destination inventory balance, idempotency and audit event. This aligns with separation-of-duties intent.
- Warehouse inventory quality release source requires each contributing receipt to have a completed goods-receipt task, independent reviewer and valid private inspection report before release.
- Custody transfer requires physical evidence and a manifest matching shipment cargo; receiving partner acceptance revalidates capacity. Source-level controls only; evidence path ownership/storage policy and actual concurrency/replay behavior still require runtime tests.
- Customs RPCs delegate to private schema functions. Public wrapper signatures and EXECUTE grants alone do not prove correct broker authorization, document validity, expiry, country/jurisdiction rules, clearance state transitions or audit completeness.

## Findings / launch gates

1. **Critical — no operational data:** both environments have zero warehouse facilities/tasks/inventory/receipts/evidence, zero customs cases/broker assignments/document submissions, zero custody transfers/dispatch authorizations, and no Staging shipment legs.
2. **High — Staging warehouse RPC ACL mismatch:** two critical warehouse workflow functions are executable by authenticated in Production but not Staging. Establish intended caller path and reconcile least privilege.
3. **High — custody data intentionally has no direct table policies:** verify all intended CRUD occurs only through secure RPCs and that no page relies on direct table writes. Do not “fix” by granting broad table access.
4. **High — customs implementation parity not fully evidenced:** private function bodies, ACLs, Storage authorization, and Staging parity require a dedicated follow-up.
5. **High — no event-to-notification runtime proof:** even where audit/event records are written, the prior notification audit found generic routing/provider/outbox configuration empty. Do not represent warehouse/customs/custody events as reliably notifying affected users.
6. **High — no cross-role isolation tests:** use separate customer, warehouse operator, customs broker, partner, operations and admin JWTs; test wrong organization, wrong shipment, wrong facility, unaccepted broker, unauthorized reviewer and revoked assignment denial.
7. **High — no runtime or evidence chain:** no browser trace, upload proof, inventory reconciliation, customs clearance evidence, custody handover replay, dispatch authorization or event-to-inbox delivery has been demonstrated.

## Required next work
- Review Staging private function definitions and grants for warehouse transition and transfer-quality RPCs, then prepare (not apply) a least-privilege reconciliation proposal.
- Audit complete customs private function bodies and Staging parity, including broker license verification, jurisdiction requirements, document upload ownership/MIME/size/expiry, independent review, rejection/resubmission and clearance transitions.
- Map warehouse/customs/custody pages to their exact RPCs and confirm no local-preview or mock path is mistaken for persisted Staging state.
- Establish isolated test sink, test organizations/users and safe Storage buckets before any synthetic writes/uploads.
- Execute end-to-end warehouse receipt → inspection → independent QC → inventory release → putaway → pick/pack → dispatch handover; customs broker assignment → acceptance → document submit/review → clearance; adjacent-leg custody request → receiving acceptance/rejection → dispatch authorization.
- Verify audit history, idempotency, retries, state conflicts, cross-org denials and mandatory user notifications with external sends disabled.

## Decision
Warehouse, customs, operations handover and custody-chain workflows are **NOT VERIFIED for real onboarding**. Strong source-level controls exist in parts of the system, but data is absent, Staging warehouse RPC permissions differ, customs parity is incomplete, and the notification delivery chain remains unconfigured. No Production or Staging data/configuration was changed.
