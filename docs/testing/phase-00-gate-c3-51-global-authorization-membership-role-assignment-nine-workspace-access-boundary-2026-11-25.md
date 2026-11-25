# C3.51 — Global authorization, organization membership, role assignment and nine-workspace access-boundary audit
**Date:** 25 November 2026  
**Immutable source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**Method:** Read-only source inspection of nine workspace entry points, legacy generic customer entry, organization switch/invitation pages, admin guard, RBAC/tenant pages, provisioning and permission migrations, tenant-isolation model, and dated 16–17 November authorization/membership audits. Historical live-catalog figures are clearly dated snapshots. No SQL, RPC, Edge Function, user impersonation, cross-tenant request, role/member mutation, storage access, or deployment was performed.

## Executive verdict
**FAIL / BLOCKED — NO-GO for certifying nine-workspace authorization, tenant isolation or general external team onboarding.**

Meaningful server-side controls exist: core membership and role tables have self-read RLS, selected tables use permission-scoped reads, shared permission helpers require active membership/organization/role assignment, customs and finance have explicit permission gates, platform-admin actions use a privileged Edge Function with AAL2/action checks, and customer/partner provisioning binds to `auth.uid()`. However, the nine workspaces still do not share one fully reconciled authorization contract. Client-side route guards, multiple role authorities, membership-only entry gates, workspace permission inconsistencies and incomplete membership lifecycle remain.

**Important distinction:** this audit does not prove a cross-tenant data breach. It identifies concrete authorization design/route defects and missing adversarial proof. Backend RLS/RPC/Edge Function enforcement is decisive; a page opening or hiding a button is not proof of data access.

## 1. Nine-workspace access matrix — static source review
| Workspace | Observed entry control | Assessment |
|---|---|---|
| Customer | Dedicated entry resolves active membership, organization type and role, rejects platform-admin/ambiguous cases and routes other types appropriately. | PARTIAL PASS. Stronger UX gate; no deployed cross-tenant negative test. Legacy generic `app/index.html` remains weaker. |
| Partner | Authenticated membership and supported partner/carrier organization types; rejects ambiguous organization selection and considers account mode. | PARTIAL PASS. Gateway is not universal deep-link guard; commercial verification/capability/compliance must be independently enforced on each backend operation. |
| Driver | Authenticated user, exactly one active driver membership, active organization and eligible carrier state for commercial driver journey. | PARTIAL PASS. Invitation acceptance leaves driver profile verification pending; assignment-specific backend controls remain essential. |
| Warehouse | Authenticated entry calls server dashboard/task RPCs; server derives eligible warehouse organizations and task operator. | PARTIAL PASS. Dashboard reuses `partner.manage`; confirm this permission is intentionally granted to warehouse operators and scoped to warehouse resources. |
| Customs | Explicit AAL2, active customs membership and `compliance.view`; licence submission uses `compliance.manage`. | PARTIAL PASS. Good entry checks, but customs zero-check evaluator and operational findings remain open from C3.43. |
| Finance | Active finance membership and `finance.view`; restricted datasets are withheld. | PARTIAL PASS. Financial posting/refund/settlement must continue to require server-side action permissions and approval. |
| Operations | Active operations organization membership; direct shipment/event reads and snapshot RPC use differing permission scopes. | FAIL for consistent permission contract. Dated audit found direct reads did not explicitly require `operations.view`, while snapshot RPC filters by `shipment.view` on customer organization. |
| Enterprise | Active enterprise organization membership opens shell; no named enterprise permission gate at entry. | FAIL for complete workspace authorization contract. Shipment scope relies on RLS; historical audit found no organization relationships/network memberships and legacy shipment fallback. |
| Platform Admin | Protected actions/data routed through `global-admin-control`; server verifies AAL2, active privileged role and action-specific superadmin for sensitive role changes. | PARTIAL PASS. Strongest observed server boundary; audit-write atomicity and full privilege/call-graph inventory remain unproven. |

This matrix summarizes inspected source and dated audit observations, not live runtime behavior of current deployed Pages or Supabase configuration.

## 2. P0 — Tenant isolation and privileged access have not passed adversarial verification
The immutable source and historical audits do not provide a complete deployed table × operation × role × tenant matrix, exhaustive SECURITY DEFINER caller/EXECUTE grant proof, or realistic two-tenant negative test results across database, RPC, Edge Functions, Storage, views, Realtime, exports and background jobs.

A dated 16 November deep audit found RLS enabled on reviewed core identity and operational tables and several scoped policies, but it also documented unresolved gaps and explicitly stated the full cross-tenant adversarial matrix had not been executed. Historical production sample: 14 organizations, 13 active memberships, 17 active numeric role assignments, five legacy `user_roles` rows, 155 role-permission mappings, 23 permission definitions, zero organization relationships, zero generic invitations and zero network memberships. These are point-in-time counts, not current values and not proof of nine-workspace coverage.

**Impact:** tenant isolation cannot be certified. This is a verification blocker, not a claim that unauthorized cross-tenant reads have been observed.

**Required:** execute controlled isolated-Staging tests using unrelated organizations A/B and users A1/B1, realistic JWTs and normal authenticated grants (not service-role credentials): read/insert/update/delete ID substitution; direct RPC and Edge Function calls; Storage object/signed URL; views; Realtime; export; background-job paths; anonymous access; inactive/suspended membership; revoked role; stale JWT/session; and platform-admin exceptions. Every negative case must be denied and logged with auditable evidence.

## 3. P1 — Three competing role authorities have no proven canonical precedence
The dated membership audit identified:
1. `krim_organization_members.role` — organization-scoped free-text role;
2. `krim_user_role_assignments` → `krim_security_roles` — numeric RBAC assignments, with nullable organization scope;
3. legacy global `user_roles` — text role.

The historical sample had 13 memberships, 17 active numeric assignments and five legacy role rows. No complete precedence/consistency contract was established. Nullable organization scope may be intentional for platform roles, but global-vs-tenant semantics, duplicate prevention and separation of platform privileges from tenant roles require explicit constraints and negative tests.

**Required:** declare one authoritative organization-scoped permission model; separate platform-global roles; document compatibility mapping; prevent stale/legacy rows from elevating permissions; reconcile role changes atomically and audit old/new role, scope, actor and reason.

## 4. P1 — Legacy generic customer entry admits any active organization membership
`app/index.html` authenticates and loads active memberships, then lets the user choose an active organization and renders a customer-labelled shipment workspace without first verifying customer organization type or customer permission. The newer `app/customer/index.html` is stricter.

**Impact:** non-customer organization members can reach a misleading customer-labelled shell. This is a workspace-boundary and role-confusion defect; it does not by itself prove protected customer shipment data can be read.

**Required:** retire the legacy route after dependency review or make it redirect to the canonical role-aware router. Never treat a sessionStorage-selected organization ID as authorization.

## 5. P1 — Workspace-specific permission inconsistencies
- **Operations:** dated route audit found the entry gate checks active operations membership but not an explicit `operations.view`; direct reads and snapshot RPC have differing permission filters. Define one explicit operations permission contract and consistent per-resource scope.
- **Enterprise:** entry gate is membership-only; no explicit enterprise permission gate. A historical audit found zero organization relationships/network memberships and no enterprise relationship path in canonical shipment RLS. Do not widen RLS to compensate; implement verified customer-enterprise relationship scope first.
- **Warehouse:** dashboard authorization reuses `partner.manage` while task listing uses a warehouse-operator helper. Confirm the intended least-privilege permission and organization/facility scoping for every dashboard RPC.
- **Partner:** dated audit identified a shipment-visibility helper that did not revalidate current compliance/capability evidence. Partner verification/capability/route readiness must be checked at the operation boundary, not inferred from membership or organization status.
- **Driver:** invitation acceptance may create/reactivate a driver membership while profile verification remains pending. Every read/dispatch/assignment action must independently enforce current driver verification, carrier eligibility and exact assignment binding.
- **Finance/Customs:** entry gates are stronger, but high-impact actions still require separate server-side permissions, AAL/approval and lifecycle checks.

## 6. P1 — Membership, invitation and provisioning lifecycle
Dated 16 November membership audit found:
- Generic organization invitation table had no verified create/accept/revoke RPC workflow and zero rows.
- Membership audit trigger covered INSERT only; UPDATE/DELETE/revocation/role changes were not equivalently audited.
- Driver organization provisioning relied on user-editable `raw_user_meta_data.krim_account_type='driver'`, which is not trusted authorization state.
- Customer/partner self-provisioning functions use `auth.uid()`, input validation, advisory locking and create pending partner verification/compliance state rather than approving a partner.
- Driver invitation flow is stronger: random 32-byte token, SHA-256 hash storage, expiry, confirmed-email binding, one-time/revocation checks and current carrier eligibility.
- Legacy driver invitation overload and canonical private driver-invitation model are distinct; callers must not mix the two token stores.

**Required:** generic organization invitation with allowlisted non-platform roles, authorized inviter permission, token hashing/expiry/revocation, exact email binding, atomic membership/role provisioning and immutable audit. Add membership update/revoke audit and session coordination. Replace editable metadata driver eligibility gate with trusted invitation/approved onboarding state.

## 7. Positive controls — PARTIAL PASS
- `private.krim_has_permission` checks active role assignment, granted mapping, active organization membership and active organization; `private.krim_has_organization_access` checks active membership and active organization.
- Authenticated identity tables reviewed have self-read policies; core organization/member/role tables had no authenticated direct INSERT/UPDATE/DELETE grants in the dated 17 November audit, so controlled RPCs are the intended mutation route.
- Customer/partner provisioning functions derive actor from `auth.uid()`, validate legal-name input, use advisory locks and create audit events.
- Partner provisioning remains pending verification/compliance rather than marking the partner operationally approved.
- Selected finance, customs, warehouse, driver and platform-admin data/actions have server-side permission or eligibility checks.

Caution: permission helpers include a NULL-auth accommodation for trusted service-role execution. The dated audit requires a full SECURITY DEFINER caller/ACL review to prove no authenticated-callable function accepts arbitrary `p_user_id` and exploits that branch. Do not modify the shared helper without call-graph analysis.

## 8. Remediation and acceptance criteria
### P0 before tenant-isolation certification
1. Build exhaustive table/view/Storage/Realtime/RPC/Edge Function/job authorization inventory with operation, role, tenant predicate, grants, policy, function owner, SECURITY DEFINER, search_path and EXECUTE ACL.
2. Run isolated two-tenant adversarial tests with realistic JWTs and normal grants. No test may rely only on frontend hiding or service-role credentials.
3. Confirm all protected operations derive actor from verified JWT and reject caller-supplied user/tenant/role authority.

### P1 before nine-workspace onboarding claims
1. Retire legacy generic customer entry and client-only role/session guards.
2. Reconcile the three role stores and nullable global role scope; define one canonical precedence.
3. Normalize operations, enterprise and warehouse permission contracts.
4. Revalidate partner compliance/capability and driver verification at every sensitive operation.
5. Implement generic organization invitation, membership update/revocation audit and session coordination.
6. Replace driver provisioning's editable metadata eligibility gate.
7. Add a workspace-by-workspace direct-URL and deep-link matrix, including multi-role/multi-organization and suspended-member cases.

### Mandatory isolated-Staging tests — NOT EXECUTED
- Nine workspaces × valid/invalid organization type × active/inactive membership × allowed/denied permission × AAL1/AAL2 where required.
- A1/B1 cross-tenant SELECT/INSERT/UPDATE/DELETE, RPC/Edge Function, Storage, signed URL, view, Realtime, export and background job.
- Client-supplied organization ID, role, permission, user ID, account mode and status tampering.
- Role-store conflict, nullable organization scope, legacy role residue and stale JWT after role removal.
- Enterprise with/without explicit customer relationship; operations membership without shipment.view; warehouse non-operator and wrong-facility; partner expired/revoked compliance; driver pending verification and wrong assignment.
- Generic and driver invitation wrong email, replay, expiry, revoke, ambiguous organization, role escalation and idempotency.
- Anonymous and authenticated-but-unrelated user access, service-role call path and platform-admin step-up/least privilege.

## Final decision
**C3.51 FAIL / BLOCKED.** NO-GO for tenant-isolation certification, nine-workspace authorization certification or general external team onboarding. Useful server-side controls exist, but a consistent canonical role model, complete lifecycle, workspace permission contracts and deployed cross-tenant negative evidence remain outstanding.

This is a read-only immutable-baseline and dated-evidence audit. No live users, roles, memberships, invitations, permissions, SQL/RPC, Storage, Realtime, provider calls, settings or deployments were changed. Historical counts are not current live-state assertions. This is not penetration testing or compliance certification.
