# Capacity RPC ACL isolated-test harness — 2026-11-24

## Harness added
- `tests/sql/partner-capacity-rpc-acl-fixture.sql` creates only disposable test roles and a SECURITY DEFINER fixture with the exact overload and source-shape markers required by the migration preflight.
- `.github/workflows/partner-capacity-rpc-acl-fixture.yml` provisions PostgreSQL 16 as an ephemeral GitHub Actions service, loads the fixture, executes the proposed ACL migration, and runs the final ACL assertions.
- The workflow supports push, pull_request path filters, and manual `workflow_dispatch`.
- The test uses no KRIM credentials, no staging/production connection strings, no user or partner records, and no real evidence objects.

## What the test is intended to prove
1. The exact overloaded function signature resolves.
2. Migration preflight rejects a function that lacks the SECURITY DEFINER flag, explicit search_path, or required source markers.
3. PUBLIC and anon do not retain EXECUTE.
4. authenticated receives EXECUTE.
5. service_role retains EXECUTE.
6. The final assertion script confirms the intended privileges and hardening flags.

## Execution status
The current assistant execution environment has no `psql`, PostgreSQL server, Docker, or Podman binary, so the fixture was executed in GitHub Actions instead. Workflow run **45458184675** completed successfully. All steps passed: disposable PostgreSQL startup, fixture/role creation, proposed migration execution, and final ACL/hardening assertions. This is a successful isolated fixture test only; it does not prove the live staging migration ledger is reconciled or authorize a live deployment.

## Live safety
The proposed migration remains unapplied. Production and staging ACLs were only queried read-only; no live privileges were changed. PR #245 remains draft.
