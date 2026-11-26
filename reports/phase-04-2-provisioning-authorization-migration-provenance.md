# KRIM Phase 04.2 — Provisioning Authorization and Migration Provenance Review

Date: 2026-11-26
Branch: remediation/phase-03dw-isolation-2026-11-26
Scope: Read-only comparison of provisioning RPC definitions, function ACLs, relevant RLS policies, table grants, and selected migration ledger versions in Production and Staging.

## Decision

**Synthetic-user creation remains BLOCKED.** This review made no database, auth, migration, permission, Edge Function, secret, or deployment changes.

## Confirmed function ACL difference

The following exact results were checked with `has_function_privilege` and `pg_proc.proacl`:

| RPC | Production anon | Production authenticated | Staging anon | Staging authenticated |
|---|---:|---:|---:|---:|
| `krim_provision_customer_organization(text)` | No | Yes | No | No |
| `krim_provision_partner_organization(text)` | No | Yes | No | Yes |
| `krim_provision_driver_organization()` | No | Yes | No | No |

Note: earlier Phase 04.1 summarized all three Staging RPCs as lacking authenticated EXECUTE. This deeper check corrects that: **partner provisioning is currently executable by authenticated users in Staging; customer and driver provisioning are not.** Partner provisioning still requires full runtime verification.

## Function source review

All three functions are SECURITY DEFINER, owned by postgres, and set an empty search_path. They use `auth.uid()` and schema-qualified application tables.

- Customer provisioning validates an authenticated user and organization name; it creates a customer organization, active owner membership, organization_owner role assignment and audit event.
- Partner provisioning validates an authenticated user and legal name; it prevents ambiguous existing active partner memberships, creates a pending verification case, assigns organization_owner and partner_user roles, and records an audit event.
- Driver provisioning checks `raw_user_meta_data.krim_account_type = 'driver'`, then creates a driver-individual organization and active driver membership. This is user-editable metadata, so it must not be treated as proof of verified driver status or permission to perform commercial driver actions. The downstream driver verification and capability controls must remain mandatory.

The SECURITY DEFINER functions bypass ordinary table RLS during execution, so their internal authorization logic and ability to create roles/memberships require careful review. Do not broaden EXECUTE grants to solve missing permissions without a reviewed, explicit migration and tests.

## Table access and RLS observations

- The four inspected tables have SELECT policies for authenticated users in both environments.
- The policy expressions for these four tables were identical in the inspected results:
  - `krim_organization_members`: current user's memberships only.
  - `krim_organizations`: active member organization, or AAL2 platform admin permission.
  - `krim_partner_verification_cases`: organization access or platform admin permission.
  - `krim_user_role_assignments`: current user's own role assignments.
- `information_schema.role_table_grants` showed authenticated SELECT grants on these tables in Production, but no authenticated table grants on the same four tables in Staging. Service-role table grants were present in both.
- This means Staging's public Data API read behavior is not at parity with Production for these four tables. Do not apply blanket table grants; confirm intended Data API exposure and least-privilege policies first.

## Migration provenance caution

Selected ledger versions `20261020074510`, `20261104192000`, and `20261115111500` were checked:
- Production ledger contained `20261020074510` only.
- Staging ledger contained none of those three versions.

The repository migration `20261115111500_harden_customer_and_partner_organization_provisioning.sql` defines the customer and partner functions but contains no explicit GRANT/REVOKE statements for these functions. Therefore, the observed Production authenticated EXECUTE privilege cannot be attributed to that migration from the inspected source. Its provenance remains unresolved (could be another migration or manual drift). Do not infer that applying this migration alone would restore the desired ACL.

The selected driver migration source includes invitation and profile guard controls; the live provisioning function's current metadata check must be assessed separately. Ledger presence alone is not proof of function or schema equivalence.

## Workspace routing remains a separate blocker

Staging's current Edge Function inventory still lacks `krim-auth-workspace-route`. The repository implementation on the isolated branch is not deployed. Login/workspace runtime tests remain blocked.

## Next safe actions

1. Search the complete migration history for explicit provisioning-function ACL changes and determine their intended state.
2. Compare the complete migration ledger and schema/function definitions, not only the three selected versions.
3. Confirm intended authenticated SELECT exposure for the four organization/RBAC tables.
4. Review the driver metadata gate and all downstream verification controls; do not promote metadata to a trusted authorization claim.
5. Reconcile and test workspace-routing function source/contract/CORS before Staging deployment.
6. Build the web-only Playwright harness with pinned dependencies and CI, then test auth in a controlled Staging environment.
7. Only after these gates pass, create the first synthetic account and verify the full provisioning transaction.

## Status

| Check | Status |
|---|---|
| Customer RPC authenticated EXECUTE parity | FAIL |
| Partner RPC authenticated EXECUTE parity | PASS (privilege only; runtime NOT TESTED) |
| Driver RPC authenticated EXECUTE parity | FAIL |
| Provisioning function source review | PARTIAL |
| Four selected RLS policy comparisons | PASS (definitions matched in inspected output) |
| Four selected table-grant parity | FAIL |
| Migration provenance for ACLs | BLOCKED / UNRESOLVED |
| Workspace-routing function availability in Staging | FAIL |
| Browser signup/provisioning runtime | NOT TESTED |
| Synthetic-user creation | BLOCKED |

No Production or Staging state was changed.
