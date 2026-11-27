# KRIM Test Runtime Storage Security Gate — 2026-11-27

## Scope and safety
Read-only inspection of Staging project `qrpcivhdxobiaofppbkl`. No DDL/DML, no test records, no workflow execution, no provider calls, and no Production access.

## Catalog findings
- `krim_internal` schema exists, owned by postgres. Its observed ACL grants USAGE to service_role only (plus owner privileges).
- `private` schema exists, owned by postgres. Its observed ACL grants USAGE to both service_role and authenticated. Do not put a privileged test-run registry or test queue there without first correcting and verifying its access model.
- No `tests` schema was returned by the schema catalog query.
- `pgtap` was not present in the inspected extension result. `pgcrypto` and `uuid-ossp` were present.
- The catalog query for foreign-key constraints on `public.krim_workflow%` tables returned no rows. Therefore parent-child lineage is not currently enforced by FKs across the inspected workflow tables. This increases the risk of partial or orphaned lineage when adding shared lane columns.

## Security implications
1. Do not assume the existing `private` schema is private to end users: authenticated has schema USAGE.
2. Prefer a dedicated, non-exposed schema with explicit ACLs for the test registry/queue; revoke schema/table/function privileges from PUBLIC, anon and authenticated, and grant only the intended trusted server role.
3. Keep all test queue tables inaccessible through the Data API. RLS is defense-in-depth, not a substitute for schema/table grants.
4. Use SECURITY INVOKER where possible. If a SECURITY DEFINER ingress/claim function is necessary, keep it in the non-exposed schema, pin an empty search_path, schema-qualify every object, revoke default PUBLIC EXECUTE, and validate the trusted run record and caller context in the function body.
5. Because existing workflow tables lack FK constraints, a shared-table lane migration must define and test its own integrity constraints and all child lineage paths. Do not add only a few nullable columns and call the system isolated.

## Recommended next implementation sequence
A. Finish scheduler/worker/webhook caller inventory and confirm no alternate caller can reach a new test queue.
B. Draft a dedicated test schema with:
   - owner-only test-run registry (UUID, enabled/disabled state, created/expiry metadata, immutable fixture identity references);
   - test event inbox with strict event-type allowlist and FK to the run registry;
   - test-only dispatch/action/attempt/audit tables with FK lineage to the run and parent rows;
   - no notification/outbox tables and no outbound integrations.
C. Implement narrow service-only ingress and exact-run claim functions; never reuse production workflow executors until they are proven side-effect-free and lineage-aware.
D. Add database tests (pgTAP only after an approved Staging extension/setup decision, otherwise deterministic SQL assertions in a rollback-only test harness) for grants, RLS, disabled run, malformed input, cross-run claims, and zero writes to operational notification tables.
E. Apply to Staging only after source review and test plan approval; then verify grants, function ACLs, schema exposure and catalog state.

## Gate result
- Schema ownership/ACL inventory: PASS.
- Existing `private` schema suitable for test registry as-is: FAIL.
- pgTAP availability: NOT INSTALLED / NOT CONFIRMED.
- Workflow FK lineage: FAIL (no matching FK constraints returned).
- New test registry/queue: NOT IMPLEMENTED.
- Test ingress and runner: NOT IMPLEMENTED.
- Test execution: BLOCKED.
- Production: untouched.

## Important limitation
This is a point-in-time catalog inspection. It does not prove absence of external schedulers, unlisted service-role callers, or deployment drift. Continue the caller inventory before any migration or runtime execution.
