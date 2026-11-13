# Step 30 — Security findings triage addendum

Date: 2026-11-13
Production project inspected read-only: `ebltviniygljwwseplph`

## New verification results

### The 26 RLS-enabled/no-policy tables are fail-closed for API roles

A direct PostgreSQL privilege check found, for every one of the 26 Advisor-listed tables:
- `anon`: no SELECT privilege.
- `authenticated`: no SELECT, INSERT, UPDATE or DELETE privilege.

This materially reduces immediate exposure risk. These are not candidate tables for blanket policy creation. Their access should remain restricted to controlled backend/service-role paths unless a specific user workflow is designed and reviewed.

### SECURITY DEFINER hardening

- Exactly 126 public SECURITY DEFINER functions are executable by `authenticated`, matching the Advisor count.
- All 126 have an explicit function-level `search_path` setting; none were missing it.
- Ten functions lacked obvious inline `auth.uid()`, `auth.jwt()`, `krim_has_permission` or `is_platform_admin` markers. Inspection shows the sampled cases are wrappers/delegates or invoke the dedicated `krim_vehicle_admin_guard()` helper. Examples include lane-aware capacity listing delegating to the guarded capacity-list function, partner capability v2 delegating to the guarded submission function, and vehicle admin routines initializing their caller identity from the AAL2/platform-admin guard.
- This is static review only; it is not proof that all 126 routines are safe. Continue per-function call-graph review and negative tests.

## Triage decision

1. Do not add broad RLS policies to the 26 tables. Their API table grants are already absent for anon/authenticated.
2. Do not blanket-revoke the 126 RPC grants. The inspected routines include intended authenticated business operations with internal checks.
3. Enable Supabase Auth leaked-password protection in project Auth security settings, then test signup/reset/change-password. This setting was not changed during this audit.
4. Complete cross-tenant negative integration tests in a staging project with migration parity before enabling real partner/customer transactions.

No production writes, grants, migrations, Auth settings, secrets, customer data, payments, or deployment actions were performed.
