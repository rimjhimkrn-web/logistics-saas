# KRIM warehouse browser RPC ACL remediation — 2026-11-24

## Confirmed mismatch
A read-only comparison of effective privileges found 14 warehouse RPC overloads directly called by current warehouse HTML pages. Production grants EXECUTE to authenticated and denies anon; staging denies authenticated and anon while retaining service_role. This is an environment mismatch that blocks direct browser RPC calls in staging.

## Source call-site inventory
The following browser pages call these RPCs directly using the publishable Supabase client:
- Facility management: register facility.
- Warehouse dashboard/performance/inventory ledger: dashboard.
- Damage exceptions, goods receipt, inbound receiving, dispatch handover, picking/packing, putaway/storage, warehouse evidence and notifications: task list, task transitions and relevant create/evidence functions.
- Warehouse access audit: event list.
- Quality control: independent inventory quality review.
- Shipment-linked receipt/inbound/handover/pick pages: assigned shipment-leg list and specific linked-task creation.

Exact 14 RPC signatures are listed in the proposed SQL file. No service_role credential is used in browser code.

## Security review of function bodies
Staging definitions inspected for the user-facing calls:
- All selected functions are SECURITY DEFINER with empty search_path and explicit schema qualification.
- Actor identity is derived from auth.uid(); no caller-supplied user ID parameter is accepted.
- Task, event and evidence listing filters every row by private.krim_warehouse_is_operator(user, organization_id, facility_id).
- Facility registration checks active organization membership, registered-business verification/lifecycle/compliance, warehouse eligibility and partner.manage; new facility remains inactive/pending review.
- Task create/transition and linked shipment operations validate the same operator/facility, task/leg/org binding and idempotency; inventory release is gated.
- Evidence registration validates task scope and a private object owned by the authenticated uploader under org/user/file path, allowed MIME and 10 MB limit.
- Quality review requires completed task, same facility/org, different reviewer from creator/completer, and a private inspection report uploaded by another user.

These are static source checks. Dynamic positive and cross-tenant negative tests are still required before release.

## Proposed remediation
The SQL grants authenticated EXECUTE only on the 14 exact overloads directly invoked by current browser pages. It explicitly revokes PUBLIC and anon, and preserves service_role. It does not grant on internal movement helpers or every warehouse function.

## Verification
An isolated PostgreSQL 16 CI workflow builds an intentionally over-permissive fixture, applies the proposed ACL migration and asserts authenticated allowed / anon denied / service_role retained on all 14 exact signatures.

## Environment and rollout decision
- Production remains unchanged.
- Staging remains unchanged because its migration history is unreconciled; adding an untracked direct ACL change would worsen drift.
- Once the migration ledger is reconciled, apply the migration to staging through the normal reviewed migration path, then run dynamic allowed/foreign-tenant tests against synthetic identities and facilities.
- Keep PR #245 draft until dynamic warehouse regression, migration reconciliation, and remaining release gates pass.


## Cross-environment function-definition parity
A direct read-only hash comparison of `pg_get_functiondef` for all 14 exact overloads returned identical hashes in production and staging. The discrepancy is therefore isolated to effective EXECUTE ACLs for these selected functions, not their function bodies. This supports a narrow privilege correction, but does not substitute for the dynamic authorized/foreign-tenant workflow tests.
