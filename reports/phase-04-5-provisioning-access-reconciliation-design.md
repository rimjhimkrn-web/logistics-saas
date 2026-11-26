# KRIM Phase 04.5 — Provisioning and Access Reconciliation Design

Date: 2026-11-26
Branch: remediation/phase-03dw-isolation-2026-11-26
Scope: Read-only design based on current Production and Staging function definitions, function ACLs, and four organization/RBAC SELECT policies.

## Decision

**Do not create synthetic users yet. Do not apply a permission migration yet.** A concrete Staging permission delta is now confirmed, but restoring driver RPC access without correcting its trust boundary would enable an authenticated user to create an active driver-individual organization by supplying editable signup metadata.

No database changes, repository source changes, deployments, or test-user creation were performed.

## 1. Function-level comparison (live database evidence)

All three provisioning routines are SECURITY DEFINER functions with an empty search_path, and no anon EXECUTE privilege in either environment.

| Function | Production authenticated EXECUTE | Staging authenticated EXECUTE | Body comparison |
|---|---:|---:|---|
| krim_provision_customer_organization(text) | Yes | No | Same definition in inspected output |
| krim_provision_partner_organization(text) | Yes | Yes | Same definition in inspected output |
| krim_provision_driver_organization() | Yes | No | Same definition in inspected output |

This confirms customer and driver permission drift. Partner permission is present in Staging but still has no canonical Staging migration provenance.

## 2. Driver provisioning is a security blocker

The current driver function reads `auth.users.raw_user_meta_data` and accepts `krim_account_type = 'driver'` as its gate. Supabase user metadata is user-editable and must not be used as trusted authorization.

The function then creates:
- an active organization with type code `driver_individual`;
- an active organization membership with role `driver`.

This does not prove that a driver can dispatch, because downstream licence, verification, vehicle, assignment and dispatch gates may still restrict access. Nevertheless, it creates a trusted-looking active driver membership from an untrusted metadata field. **Do not restore authenticated EXECUTE on this function until its authorization model is redesigned and tested.**

Required redesign:
1. Treat signup metadata only as a user-selected onboarding intent, never as authorization.
2. Establish driver eligibility through a server-controlled state: verified invitation, admin-approved onboarding request, or a separately validated driver application.
3. Create a pending driver application/membership, not an active operational driver membership, until approval.
4. Ensure downstream dispatch and assignment paths independently require active verified driver status, valid licence, vehicle eligibility, partner authorization and shipment-leg readiness.
5. Audit every transition and reject metadata-only attempts.

## 3. Customer and partner RPC considerations

Both functions validate `auth.uid()`, validate names, use per-user advisory transaction locks, and create organization membership under the authenticated user. The partner function creates a pending verification case and sets partner verification/compliance statuses to pending.

Before enabling signup in Staging, add runtime negative and concurrency tests:
- unauthenticated call rejected;
- empty/short/oversized name rejected;
- repeated call is idempotent and does not create duplicate organizations;
- concurrent calls for the same user do not create duplicate memberships;
- user cannot provision or attach another user's identity;
- partner remains unverified and cannot publish verified capacity, receive assignments, or dispatch until required review is complete;
- audit event and verification case are created exactly once.

Customer provisioning creates an active customer organization. Confirm that this is intended to mean workspace existence only, not credit, booking, shipment, or financial authority.

## 4. Four-table RLS policy review

The inspected Production and Staging SELECT policies match:
- `krim_organization_members`: authenticated user can read their own membership rows.
- `krim_user_role_assignments`: authenticated user can read their own role assignments.
- `krim_organizations`: active organization members can read their organization; platform admin path requires AAL2 plus `admin.platform`.
- `krim_partner_verification_cases`: organization-scoped access or platform-admin permission.

These policies are appropriately scoped at a high level, but policy definitions alone do not prove application behavior. The two environments differ in authenticated SELECT table grants. No table SELECT grant should be restored until page/API call-site inventory demonstrates it is required and a signed-in runtime test confirms the intended row scope.

## 5. Proposed minimal reconciliation sequence

### Gate A — code/security remediation (required before grants)
- Replace driver metadata authorization with server-controlled eligibility.
- Decide whether customer organization status should be active at signup or pending activation.
- Review partner pending-state restrictions across marketplace, capacity, assignment, and dispatch functions.
- Confirm every SECURITY DEFINER function has an explicit authenticated-user identity check and fixed search_path.

### Gate B — migration design (not yet created)
- Staging-only migration.
- Customer RPC: grant authenticated EXECUTE only after the tests above pass.
- Partner RPC: retain current authenticated EXECUTE only if source provenance and the same negative tests are satisfactory; otherwise reconcile to the approved migration.
- Driver RPC: keep authenticated EXECUTE revoked until Gate A and dedicated driver authorization tests pass.
- Table SELECT: grant only the exact table privileges needed by verified application reads; never grant all four as a bundle by default.
- Explicitly revoke EXECUTE from PUBLIC and anon for each exposed SECURITY DEFINER routine.

### Gate C — verification
- Inspect resulting ACLs and RLS policies.
- Run Supabase security advisors.
- Test anon denial, own-organization access, cross-organization denial, role escalation denial, unverified partner restrictions, and driver eligibility restrictions.
- Test signup retries and concurrent requests.
- Confirm no changes to Production and preserve freight-payment collection/payout disablement.

### Gate D — synthetic user generation
Only after Gates A–C pass, generate a small, isolated Staging-only set of synthetic accounts. Start with one identity per ecosystem and prove cleanup/retention controls before any larger batch.

## Status register

| Item | Status |
|---|---|
| Live function ACL comparison | VERIFIED |
| Customer/driver Staging EXECUTE mismatch | VERIFIED |
| Partner EXECUTE exists but provenance unresolved | VERIFIED |
| Provisioning function bodies same across inspected environments | VERIFIED |
| Driver user-metadata trust flaw | VERIFIED |
| Four SELECT policy definitions match | VERIFIED |
| Required authenticated table SELECT grants | UNRESOLVED |
| Driver provisioning redesign | NOT IMPLEMENTED |
| Reconciliation migration | NOT CREATED |
| Runtime security tests | NOT TESTED |
| Synthetic users | BLOCKED |

No Production or Staging state was changed.
