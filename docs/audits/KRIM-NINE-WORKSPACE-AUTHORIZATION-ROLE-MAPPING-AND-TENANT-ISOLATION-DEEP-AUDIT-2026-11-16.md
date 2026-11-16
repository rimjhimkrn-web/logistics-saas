# KRIM Nine-Workspace Authorization, Role Mapping and Tenant-Isolation Deep Audit — 2026-11-16

## Executive decision
**NO-GO for broad multi-tenant production rollout.** The live database has RLS enabled on the reviewed core tables and several important server-side authorization gates. Finance, customs, warehouse and platform-admin entry paths show meaningful permission controls. However, the nine-workspace system is not yet a single consistent authorization model: legacy localStorage route guards remain non-security controls; the generic app entry can present a customer-labelled shell to any active organization member; enterprise workspace admission is membership-only while enterprise-to-customer data relationships are not provisioned; warehouse dashboard access reuses `partner.manage`; and a partner shipment-visibility helper does not revalidate current compliance/capability evidence. The full cross-tenant adversarial test matrix remains unexecuted.

This is a read-only source and live catalog review. No user session was impersonated, no cross-tenant request was attempted, no RPC/Edge Function was invoked, no database or Storage writes were made, and no production setting/schema/policy/grant was changed.

## 1. Live identity and role baseline

Snapshot from the production catalog:
- Organizations: **14**
- Active organization memberships: **13**
- Active role assignments in `krim_user_role_assignments`: **17**
- Legacy `user_roles` rows: **5**
- Role-permission mappings: **155**
- Permission definitions: **23**
- Organization relationships: **0**
- Organization invitations: **0**
- Organization onboarding records: **0**
- Network memberships: **0**

Organization types represented:
- Customer: 5 organizations, 5 active owner memberships.
- Partner: 2 organizations, 1 active owner membership.
- Driver individual: 1 organization, 1 active driver membership.
- Customs: 1 organization, 1 active manager membership.
- Enterprise: 1 organization, 1 active manager membership.
- Finance: 1 organization, 1 active manager membership.
- Operations: 1 organization, 1 active manager membership.
- Warehouse operator: 1 organization, 1 active member membership.
- Platform: 1 organization, 1 active owner membership.

The 17 active role assignments include organization_owner (6), platform_admin (2), platform_superadmin (1), customer_user (2), partner_user (2), organization_admin (1), operations_manager (1), finance_manager (1) and compliance_manager (1).

These counts show a small configured identity sample, not nine-workspace production adoption or proof that every role combination has been tested. Two role systems remain present (`krim_user_role_assignments` and legacy `user_roles`), alongside organization membership's free-text `role`. The canonical precedence and conflict-resolution rules are not yet demonstrated end to end.

## 2. Positive security controls observed

### Shared tenant identity
- `private.krim_has_organization_access(user, org)` requires the supplied user to match `auth.uid()` when an authenticated JWT exists, and requires an active membership in an active organization.
- `private.krim_has_permission(user, org, permission)` requires an active organization membership, active role assignment, granted role-permission mapping and active organization.
- Core shipment, partner quote, assignment, organization, finance and warehouse tables reviewed have RLS enabled.
- `krim_shipments` SELECT policy scopes customer rows by customer organization, operations visibility by operations membership plus shipment.view, and partner visibility through eligible opportunity/assignment conditions.
- `krim_partner_quotes` SELECT policy limits visibility to the partner organization or the customer organization attached to the opportunity.
- `krim_shipment_partner_assignments` SELECT policy scopes reads to the customer or assigned partner organization.
- `krim_driver_assignments` SELECT policy requires the row's user_id to equal auth.uid() and an active driver membership for that organization.
- Driver profile INSERT/UPDATE policies bind the profile to auth.uid() and active driver membership. A before-write trigger independently protects verification status, onboarding mode, user identity and organization reassignment; licence changes reopen previously accepted licence evidence and force the profile back to pending.
- Customs workspace requires an authenticated session, AAL2, active customs organization membership and `compliance.view`; licence submission separately requires `compliance.manage`.
- Finance workspace requires active finance organization membership and `finance.view`. It withholds the legacy revenue report because it is not organization-scoped and clearly labels restricted datasets.
- Warehouse task listing uses a server-side RPC that checks an eligible warehouse operator, organization and facility. Direct warehouse task/inventory SELECT policies require active membership, active approved facility and warehouse organization eligibility.
- Platform administration uses the `global-admin-control` Edge Function for protected requests; the page does not rely on a browser role claim for mutations. Server response determines platform roles and superadmin-only controls.
- Partner gateway uses `auth.getUser()`, active membership, recognized partner organization type, active organization status and an explicit account mode before routing. It says the gateway does not itself grant commercial access.

## 3. P0 — Legacy localStorage role/session guard is not an authorization boundary

### Evidence
- `js/session.js` stores a custom session object in browser localStorage.
- `js/guards.js` validates that custom localStorage session and uses its `session.role` value to decide access to legacy customer, partner, enterprise, driver, warehouse, operations, finance, compliance and support folders.
- This guard is separate from Supabase Auth and trusts a client-editable browser value. A user can modify localStorage or bypass JavaScript route checks.
- The legacy guard explicitly returns early for public/auth paths but has no ability to enforce backend access to protected data.

### Impact
This guard must not be described as secure RBAC or tenant isolation. Any page relying only on it can be opened by direct URL or by changing browser storage. Data and mutations are safe only where backend RLS/RPC/Edge Function authorization independently protects them. The earlier authentication audit also identified legacy localStorage session trust and React AuthContext trust of editable user_metadata role/tenant.

### Required remediation
- Inventory every page importing `js/guards.js` or `KrimSession`; retire the custom session as an auth source.
- Migrate protected pages to Supabase Auth `getUser()`/current session and server-enforced membership/permission checks.
- Treat route guards as UX only; every protected read/write must independently enforce tenant, membership, role/permission, lifecycle and AAL where required.
- Remove client-controlled role/tenant authorization decisions. Do not use `user_metadata` for authorization.
- Include direct-URL, disabled-JavaScript and manipulated-localStorage staging tests.

## 4. P1 — Generic `app/index.html` is a customer-labelled workspace for any active organization member

The legacy generic entry page:
- verifies a Supabase session;
- loads all active organization memberships for the current user;
- lets the user select any active organization and remembers the choice in sessionStorage;
- labels the page as a Customer Workspace;
- does not first require that the selected organization is a customer organization or that the user has customer workspace permission.

The dedicated `app/customer/index.html` is stricter: it maps active membership role and organization type, rejects platform admin from customer workspace, requires exactly one supported workspace role and redirects non-customer roles to their matching workspace. However, the older generic `app/index.html` remains a confusing alternative route.

### Impact
This is an entry-point/role-confusion issue. Backend RLS and RPC checks remain the actual data security boundary, so static review does not prove a tenant data breach. But a partner, driver, finance, operations or other organization member can reach a customer-labelled page and select an organization they belong to. This can expose irrelevant customer actions and create false expectations; any direct write still needs independent backend authorization.

### Required remediation
- Redirect the generic entry to a role-aware workspace router or require an active customer organization plus explicit customer permission before rendering customer functions.
- Never use the selected organization from sessionStorage as proof of authorization; validate it against active membership and server-side permissions on every request.
- Keep a single canonical workspace entry path.

## 5. P1 — Enterprise workspace is membership-gated but enterprise data relationship is absent

### Evidence
- `app/enterprise/index.html` checks Supabase session and active membership in an active organization whose `organization_type='enterprise'`.
- It does not perform a separate enterprise permission check before showing the workspace shell.
- It queries `krim_shipments`; on error it falls back to legacy `shipment_requests`.
- Prior live authorization audit found 0 `krim_organization_relationships` and that the canonical shipment RLS policy has no enterprise relationship path. Enterprise membership alone does not establish access to customer shipments.
- The fallback can hide the canonical query failure and display a partial/legacy dataset as if the workspace refreshed.

### Impact
The page may open successfully but not provide the enterprise's intended multi-organization shipment visibility. Conversely, do not broaden shipment RLS merely to make the page populate: the legal customer-to-enterprise relationship and scope must be explicit.

### Required remediation
- Implement and verify an approved enterprise-to-customer organization relationship lifecycle (contract/authority, active dates, scope, revocation, audit).
- Require a specific enterprise permission and relationship for every linked customer dataset.
- Remove silent legacy fallback; display “canonical source unavailable” rather than mixing schemas or masking authorization errors.
- Test relationship revocation during an active session.

## 6. P1 — Partner shipment read helper does not revalidate current compliance and capability

The RLS policy on `krim_shipments` includes `private.krim_user_has_active_partner_assignment(shipment_id)`. The live helper checks:
- active membership in the assigned partner organization;
- an assignment status not in rejected/declined/cancelled/expired;
- active partner/carrier/forwarder organization;
- partner verification/lifecycle/compliance status strings.

However, this helper does not call `private.krim_partner_compliance_is_current` and does not recheck current active verified capability coverage for the shipment. The separate open-opportunity branch of the shipment RLS policy does check both current compliance and capability coverage.

### Impact
If a partner's insurance/licence/compliance evidence expires or its capability is withdrawn after an assignment is created, a member may continue to read shipment details through the assignment branch while the helper's cached status strings remain favourable. This is a stale-authorization risk, not proof that any current partner has exploited it.

### Required remediation
- Define the exact assignment statuses that permit partner shipment visibility (including whether offered/proposed assignments should reveal full shipment details).
- Revalidate current partner compliance, required capability, service area and assignment state in the read authorization helper, or use a restricted shipment projection until acceptance.
- Ensure evidence expiry, capability suspension, organization suspension and membership revocation immediately narrow access.
- Review the helper's SECURITY DEFINER ownership, safe search_path and execute grants as part of migration reconciliation.

## 7. P1 — Warehouse dashboard uses `partner.manage` as its authorization permission

The live `krim_warehouse_dashboard()` SECURITY DEFINER function requires:
- authenticated user;
- active membership;
- warehouse organization eligibility;
- `private.krim_has_permission(user, org, 'partner.manage')`.

The live permission catalogue contains 23 codes and has no warehouse-specific permission such as `warehouse.view`, `warehouse.manage` or `inventory.manage`. The task list RPC uses `private.krim_warehouse_is_operator`, which is a more purpose-built facility/operator check.

### Impact
The dashboard reuses a partner-management permission for warehouse inventory/task visibility. Even though warehouse organization eligibility narrows the target organizations, this is an authorization vocabulary and least-privilege defect. A role designed to manage partner relationships may inadvertently satisfy warehouse dashboard access, while a legitimate warehouse role may need an unrelated partner permission.

### Required remediation
- Define explicit warehouse permissions and assign them through the canonical role-permission matrix.
- Use a consistent facility-scoped warehouse operator check across dashboard, task list, inventory, allocation, QC and evidence operations.
- Keep financial/partner permissions separate from warehouse access.
- Test a warehouse member with no partner.manage permission and a partner manager with no warehouse membership.

## 8. P1 — Operations and customer workspace access are not fully permission-aligned

### Operations
- `app/operations/index.html` checks an active operations organization membership before displaying the control tower.
- It then queries shipments, exceptions, tracking, warehouse transfers, returns and shipment snapshots.
- The direct data queries rely on RLS. The snapshot RPC additionally requires an active operations organization and `shipment.view` for each customer organization.
- This is safer than relying on the entry check alone, but the page's “authorized operations session” indicator is set after membership validation, before each dataset's permission result is known. Dataset-specific status must remain authoritative.
- Prior operations audit identified a permission mismatch in the snapshot path and a need to keep direct shipment RLS and snapshot access semantics consistent.

### Customer
- The dedicated customer entry checks membership/org type and blocks mixed or unsupported workspace roles.
- Customer child pages still depend on their own backend RLS/RPC controls; the entry check is not a substitute.
- The generic `app/index.html` bypasses this role-specific routing discipline.

### Required remediation
- Display separate states for authenticated, workspace membership verified, permission verified, and data query succeeded.
- Keep operations read access explicitly scoped to customer relationships and shipment.view; do not treat operations membership as global shipment visibility.
- Ensure customer shipment creation/quote/acceptance RPCs independently check customer organization type, membership and permission.

## 9. Driver and warehouse workspace details

### Driver
- Driver assignment SELECT policy is narrow: only the exact authenticated user, with active driver membership in the assignment's organization.
- Driver profile reads are user-scoped.
- Driver profile INSERT/UPDATE require active driver membership; a server-side trigger prevents self-approval, immutable identity changes and unauthorized organization moves. Licence changes reopen accepted evidence and set verification back to pending.
- The driver page uses `session.user.user_metadata` to prefill personal profile fields. Those fields are convenience values only; they must never become authorization attributes.
- The driver workspace relies on server/RLS controls for milestones, proof upload and assignment operations. Staging tests must verify that a driver cannot alter assignment owner, organization, verification state or another driver's profile/evidence.

### Warehouse
- Warehouse landing page authenticates a session and calls `krim_warehouse_dashboard` and `krim_warehouse_list_tasks`; it does not perform a full membership/role check in the browser.
- This is acceptable only because the SECURITY DEFINER RPCs independently validate user/org/facility permission. Direct access to linked module pages must have equivalent backend checks.
- `krim_warehouse_list_tasks` uses `private.krim_warehouse_is_operator(user, organization, facility)`, and limits results to 250 rows; the UI shows up to 12 open tasks and explains the cap.
- Warehouse RLS policies on tasks/inventory require active membership, active approved facility and eligible warehouse organization.
- The dashboard permission mismatch in section 7 must be fixed before workspace certification.

## 10. Customs, finance and platform administration

### Customs
- AAL2 is checked before workspace data loads.
- Active customs organization membership and `compliance.view` are required.
- Licence submission is shown only for organizations with `compliance.manage`.
- Broker assignment/document mutations are expected to be server/RPC-authorized; government customs release remains a separate authority evidence requirement.
- No live customs cases, broker assignments or documents existed in the previous operational audit; no real workflow has been tested.

### Finance
- AAL2 is not visibly required merely to enter the finance read workspace; the page requires finance organization membership and `finance.view`.
- The workspace intentionally withholds the unscoped legacy revenue report and performs no financial writes.
- Higher-risk finance mutations (rule changes, refund approvals, financial posting) must independently require finance.manage/AAL2 and maker-checker controls. Do not assume read-page access authorizes them.
- Financial direct-write exposure and Razorpay webhook bypass remain separate critical findings from the prior financial audits.

### Platform admin
- Privileged requests go through the `global-admin-control` Edge Function.
- The page obtains the role from server response and reveals superadmin-only controls only when the server reports `platform_superadmin`.
- The platform-admin page calls the Edge Function for protected actions; client role state is display logic only.
- The deployed Edge Function/source parity and complete AAL2/session-revocation tests remain part of the broader edge/auth release gate.

## 11. RLS and SECURITY DEFINER baseline

- The reviewed core tables have RLS enabled.
- `krim_organization_members` SELECT is self-only; members cannot enumerate all colleagues through this policy. Team-directory and enterprise people views need a separately scoped permission endpoint rather than weakening membership RLS.
- `krim_user_role_assignments` SELECT is self-only; `krim_role_permissions` and `krim_security_permissions` are platform-admin only.
- Live public function inventory remains **332 SECURITY DEFINER functions**, **150 executable by authenticated**, **0 executable by anon**. Each callable function must be reviewed for auth.uid, tenant/org scope, permission, AAL2, safe search_path, EXECUTE grants and service-role assumptions.
- SECURITY DEFINER functions in the public schema are privileged API surfaces; RLS on base tables does not automatically protect an unsafe function body.
- A private helper `krim_has_organization_access` allows a null auth.uid context for trusted server-side use; authenticated calls must still match auth.uid and active membership. Do not expose this helper through a public API or rely on it without validating the calling context.

## 12. Required staging adversarial matrix — not run

For every workspace (Customer, Partner, Driver, Warehouse, Customs, Finance, Operations, Enterprise, Platform Admin):
1. Anonymous user direct URL and direct Data API read/write.
2. Authenticated user with no organization membership.
3. Active membership in wrong organization type.
4. Revoked/suspended membership with an unexpired JWT.
5. User with correct membership but no required permission.
6. Permission assigned in a different organization only.
7. AAL1 versus AAL2 for sensitive actions.
8. Forged user_metadata role, organization_id and tenant claims.
9. Forged sessionStorage/localStorage role and selected organization.
10. Direct URL to every protected child page and Edge Function.
11. Cross-tenant IDs for shipment, quote, assignment, driver profile, facility, inventory, customs case, invoice, payment and evidence.
12. Wrong organization relationship, expired relationship and revoked relationship.
13. Partner compliance/capability expiry after assignment.
14. Offered versus accepted partner assignment visibility.
15. Driver attempts to change profile verification, identity, organization or another driver's record.
16. Warehouse member without partner.manage; partner manager without warehouse membership.
17. Enterprise membership without customer relationship; relationship revoked mid-session.
18. Operations membership without shipment.view on a particular customer organization.
19. Finance viewer attempts financial posting/refund/allocation or direct DML.
20. Platform admin AAL1, ordinary admin, superadmin and revoked session separation.
21. Storage object read/upload/update/delete cross-tenant attempts.
22. Query error, partial response, timeout and fallback behaviour must not show stale/unauthorized data as a successful complete refresh.

No staging test has been run. The current production sample is too small to certify these controls.

## 13. Remediation order
**P0**
1. Retire legacy localStorage session/role guard as an access control and inventory all dependent pages.
2. Reconcile the canonical role/permission/membership authority and remove conflicting role sources after migration review.

**P1**
3. Replace generic `app/index.html` with a role-aware entry router.
4. Correct partner assignment read helper to enforce current compliance/capability and exact assignment visibility state.
5. Introduce warehouse-specific permission codes and consistent facility scope.
6. Implement enterprise-to-customer relationship authorization; remove silent legacy data fallback.
7. Align operations workspace indicators with per-dataset permission outcomes.
8. Review all public SECURITY DEFINER functions and deployed Edge Function parity.

**P2**
9. Add team membership directory endpoint with scoped organization.manage/view permission.
10. Add full role matrix tests, access-decision audit events, session revocation tests and user-friendly permission-denied recovery.

## 14. Release decision
**NO-GO for unrestricted nine-workspace production access.** The architecture has strong controls in important areas, but it is not yet a certified unified authorization system. Keep live customer onboarding, partner activation, dispatch, warehouse fulfilment, customs execution and financial collection behind their existing business readiness gates.

## Change boundary and CI
- Repository HEAD audited: `bdd882eecffa8fd83f5cbdb6c59f1fdae94bf805`.
- Production smoke checks for this HEAD: passed (run `43854796889`).
- Static link audit for this HEAD: passed (run `43854796950`).
- Pages build/deployment for this HEAD: in progress at last check (run `43854795982`).
- CI success validates the repository checks/Pages workflow only; it is not an authorization penetration test, database migration reconciliation or Edge Function source-parity certification.
- Production/repository migration-history mismatch remains unresolved. No migration, DDL, RLS policy, grant, function, Edge Function deployment, user/role assignment, partner/customer operation or financial action was performed.
