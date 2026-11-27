# KRIM Workflow Test-Fixture Access Gate — 2026-11-27

## Environment and scope
Read-only inspection of Staging Supabase project `qrpcivhdxobiaofppbkl`. Production was not accessed. No SQL DDL/DML, worker invocation, event creation, invitation, email or operational transaction was performed.

## 1. Actual table privileges (verified)
For the following ten workflow tables, catalog privilege checks returned:
- `anon`: SELECT and INSERT false.
- `authenticated`: SELECT, INSERT, UPDATE and DELETE false.
- `service_role`: SELECT, INSERT and UPDATE true.

Tables checked:
- `krim_events`
- `krim_workflows`
- `krim_workflow_triggers`
- `krim_workflow_steps`
- `krim_workflow_runs`
- `krim_workflow_run_steps`
- `krim_workflow_action_executions`
- `krim_event_workflow_dispatches`
- `krim_workflow_dead_letters`
- `krim_workflow_dead_letter_replays`

This means the previously observed authenticated SELECT RLS policies are currently not directly usable through table SELECT because the authenticated role has no table SELECT grant. RLS policies do not themselves grant table privileges. Do not grant authenticated access merely to make the test plan work; any owner-facing read path must be reviewed as a separately scoped RPC/view with AAL2/platform-admin checks and minimal fields.

## 2. Internal function execution privileges
Fourteen internal workflow functions were checked with `has_function_privilege`. Every checked function returned:
- anon EXECUTE: false
- authenticated EXECUTE: false
- service_role EXECUTE: true

The checked set includes event dispatch, action claim/execute, dispatch materialization, batch processing, retry/recovery, dead-letter replay/quarantine, and run reconciliation. This is a positive direct-RPC boundary. It is a catalog privilege check, not a live JWT API denial test.

## 3. Fixture readiness decision: BLOCKED
The existing Phase 00 identity/organization fixture provisioners can create four test identities and tenant organizations, but do not configure workflow registry rows or event/action fixtures. The workflow tables have no direct client write grants. Therefore no approved workflow-fixture creation path was established in this checkpoint.

Do not:
- grant broad table write privileges to authenticated;
- insert arbitrary workflow records through an owner console;
- create real shipment, quote, partner, dispatch, capacity, notification or payment records as test shortcuts;
- invoke the scheduled production-like worker against unreviewed records.

## 4. Safe next implementation design
Create a dedicated, staging-only workflow-fixture provisioner with:
1. Exact Staging project URL/ID guard.
2. Owner-only JWT, AAL2 and trusted platform-superadmin assignment check, matching the existing Phase 00 fixture pattern.
3. A unique run UUID and idempotent fixture ledger.
4. A fixed allowlist of three currently supported action types only: `record_workflow_checkpoint`, `create_exception_case`, and `evaluate_delay_risk`.
5. Synthetic event payloads with no shipment/quote/payment identifiers and no external side effects.
6. A dedicated isolated test organization and workflow namespace.
7. No notification action, provider call, email, push, freight transaction or real business entity.
8. Cleanup limited to fixture-owned rows, with immutable audit evidence and no cascading deletion of operational data.
9. Explicit per-run enablement/disablement so the scheduled worker cannot accidentally process fixture records before approval.
10. A separate test runner that captures event, dispatch, action, retry, lease and dead-letter outcomes without exposing service-role secrets to browser clients.

## 5. Required tests before implementation approval
- Verify staging URL/project guard rejects Production.
- Verify non-owner, wrong AAL, inactive role, and wrong role fail.
- Verify repeated run UUID is idempotent and mismatched identity payload is rejected.
- Verify only allowlisted actions can be created.
- Verify fixture event cannot reference or mutate real shipment/quote/payment IDs.
- Verify scheduled worker cannot claim fixtures until explicit test-run enablement.
- Verify no notification provider or external network action is reachable.
- Verify cleanup cannot delete non-fixture rows.
- Verify direct anon/authenticated table writes and internal function calls remain denied.

## 6. Exit decision
No test fixtures provisioned. Current workflow table grants are service-role-only for the inspected tables; internal worker functions are service-role-only for the inspected function set. Existing RLS policies do not override missing table grants. Build the isolated provisioner and test harness before running workflow E2E.

No migration or code changes made. Production untouched. Phase 00 remains OPEN — NOT APPROVED; Phase 01 is not authorized.
