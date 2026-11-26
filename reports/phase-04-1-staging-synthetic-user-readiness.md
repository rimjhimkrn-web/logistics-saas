# KRIM Phase 04.1 — Staging Synthetic-User Readiness Audit

Date: 2026-11-26
Scope: Read-only inspection of the isolated Staging Supabase project, repository authentication entrypoints, provisioning RPCs, and existing CI test assets.
Repository: rimjhimkrn-web/logistics-saas
Branch: remediation/phase-03dw-isolation-2026-11-26

## Decision

**NOT READY — synthetic-user creation is blocked.** No users, organizations, role assignments, migrations, grants, Edge Functions, secrets, or deployments were changed by this audit.

## Environment snapshot

- Production project `ebltviniygljwwseplph`: ACTIVE_HEALTHY (read-only status check).
- Staging project `qrpcivhdxobiaofppbkl`: ACTIVE_HEALTHY (read-only status check).
- Staging migration ledger: 34 entries.
- Staging `auth.users`: 1 row.
- Staging `krim_organizations`: 0 rows.
- Staging `krim_user_role_assignments`: 1 row.
- Staging Edge Functions: `owner-testing-authorize` v5 (verify_jwt=true), `global-admin-control` v2 (verify_jwt=true), `krim-resend-email-worker` v1 (verify_jwt=false).
- `krim-auth-workspace-route` is absent from the current Staging Edge Function inventory.
- Production and Staging migration history discrepancy remains unresolved (Production previously inventoried at 561 entries; Staging currently 34). Do not reset Staging or copy Production rows.

## Confirmed blockers

### P0 — Provisioning RPCs are not callable by authenticated users in Staging

Read-only `pg_proc.proacl` inspection found:

| RPC | Production authenticated EXECUTE | Staging authenticated EXECUTE |
|---|---:|---:|
| `krim_provision_customer_organization(text)` | Yes | No |
| `krim_provision_partner_organization(text)` | Yes | No |
| `krim_provision_driver_organization()` | Yes | No |

The functions exist in both projects and are SECURITY DEFINER. Their Staging ACLs list postgres and service_role only. The website signup pages call these RPCs after Supabase Auth signup/sign-in. Consequently, customer/partner/driver self-service organization provisioning is not ready in Staging. Do not solve this by blanket grants; inspect function source, policies, and least-privilege authorization first.

### P0 — Workspace-routing function missing from Staging

The login page invokes `krim-auth-workspace-route` after authentication. The current Staging function inventory does not contain it. A matching source implementation exists only on the isolated repository remediation branch and has not been deployed. Login/workspace routing must not be certified until caller/response contract, CORS, authorization, deployment, and runtime denial/allow tests are verified.

### P1 — Staging has no organization records

The current zero organization count means no realistic organization-scoped ecosystem journey can be executed. The single existing Auth user and role assignment are not sufficient evidence of a fully provisioned owner-testing environment.

### P1 — Existing testing assets are incomplete

- Repository contains Playwright package files under committed `node_modules`, but no root `package.json` or `playwright.config.*` was found in the root inventory.
- An existing Chromium smoke workflow exists, but it is scoped to pushes on `qa/phase-00-baseline-2026-11-25` and pull requests targeting `main`; it is not a comprehensive application E2E suite.
- No evidence from this audit establishes a completed full-site Playwright run or a k6 load-test run.
- Mobile app folders and mobile workflows exist in the repository, but they are explicitly outside this web-only programme.

## Authentication and provisioning observations

- Customer, partner, and driver signup pages call `auth.signUp` and then the corresponding organization-provisioning RPC.
- Signup flows attach `krim_account_type` and profile fields in user metadata. Such metadata must not be treated as authorization. Server-side authorization must rely on authenticated identity, trusted role assignments, organization membership, and policy checks.
- Customer and partner provisioning functions read `auth.uid()`, use advisory transaction locks, create organization/member/role assignment records, and write audit events. Partner provisioning also creates a pending verification case.
- Driver provisioning checks the account-type metadata before creating a driver organization/member. This check alone is not a substitute for driver verification or authorization.
- Owner-testing documentation requires a confirmed owner account, TOTP MFA at AAL2, and exactly one active `platform_superadmin` assignment in Staging. Never share the owner's password, TOTP seed, recovery codes, publishable key, or service-role secret in chat.

## Required remediation sequence

1. Reconcile Staging schema and migration provenance without resetting or importing Production data.
2. Review the three provisioning RPC bodies, exact grants, RLS policies, and audit behavior; design narrowly scoped Staging grants only after review.
3. Reconcile and validate `krim-auth-workspace-route` implementation and response contract; deploy to Staging only after explicit release review.
4. Verify the owner-testing account process and least-privilege owner assignment in Staging.
5. Add a root web test harness with pinned Playwright dependency/lockfile, test config, and CI workflow. Keep mobile apps excluded.
6. Add safe Auth tests for signup, confirmation, session, logout, duplicate signup, unconfirmed user, and unauthorized role routing.
7. Create synthetic users only after the preceding controls pass; use dedicated controlled test mailboxes and never send to uncontrolled recipients.

## Evidence limitations

This was a source and database metadata audit. No browser session, signup, login, RPC invocation, email delivery, MFA enrollment, or cross-tenant runtime test was performed. PASS is not assigned to any runtime behavior. No changes were made to Production or Staging.

## Status register

| Check | Status |
|---|---|
| Staging project health | PASS (control-plane status only) |
| Staging isolation / migration provenance | BLOCKED — reconciliation pending |
| Provisioning RPC authorization | FAIL — authenticated EXECUTE absent in Staging |
| Workspace-routing function availability | FAIL — missing from Staging inventory |
| Organization test fixtures | BLOCKED — no organizations |
| Owner MFA and role runtime verification | NOT TESTED |
| Playwright E2E suite | BLOCKED — harness not yet established |
| Synthetic identity creation | BLOCKED — prerequisites unresolved |
