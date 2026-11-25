# Phase 00 — Nine-workspace protected-page and authorization coverage audit

Date: 2026-11-25  
Repository: `rimjhimkrn-web/logistics-saas`  
Ref: `qa/phase-00-baseline-2026-11-25`  
Scope: Read-only source review of all nine named workspace entry pages, selected high-risk child pages, shared guards, and page-to-RPC/Edge Function patterns. No login, direct-access runtime probe, cross-tenant request, privileged RPC, write, or Production/Staging data mutation was performed.

## Executive verdict

**NOT VERIFIED for real-user onboarding.** The sampled workspace entry pages generally implement some form of identity, membership, organization-state or permission check. The strongest visible page-level gates are Customs, Finance, Customer and the Platform Admin control plane. Partner pathway routing is also comparatively explicit. However, controls are inconsistent across workspaces, and several high-risk pages rely on backend RPC/RLS enforcement without a visible page-level role/permission gate.

A frontend redirect or disabled button is not an authorization boundary. The decisive evidence must be server-side JWT validation, active organization membership, permission checks, tenant-scoped queries, AAL enforcement where required, and negative runtime tests. This audit did not execute those tests.

## Coverage by workspace

### 1. Customer — SOURCE PARTIAL PASS
Entry page: `app/customer/index.html` (SHA `04ccb1f89077d70a33531e8a9a4c62151bf95e15`).

Observed:
- Requires a Supabase session; otherwise redirects to customer sign-in.
- Queries active `krim_organization_members` for the signed-in user and resolves organization type.
- Rejects no membership, ambiguous multiple workspace roles and platform-admin role.
- Customer dashboard queries filter shipments and quotes by the resolved customer organization IDs.
- Page explicitly describes database permissions/RLS as the authoritative data boundary.

Gaps:
- No direct page-level AAL2 enforcement; the login flow requires TOTP enrollment and MFA challenge, but protected backend operations still need their own policy.
- Organization IDs are obtained in browser code. Every query/RPC must independently enforce membership and tenant scope; the client filter alone is not sufficient.
- Cross-tenant direct-query and RPC tests not run.

### 2. Partner — SOURCE PARTIAL PASS
Entry/gateway: `app/partner/index.html` (SHA `d7177579de9504dbd3b94213380dfe166cea8403`). Pathways: registered business, individual interest and development/test.

Observed:
- Gateway calls `auth.getUser()`, checks active memberships, resolves partner organization type/status and partner account mode, and routes to the matching pathway.
- Registered-business pathway (`app/partner/business/index.html`, SHA `85415eaa120dc1831d468441e684b224e0c2c8b7`) checks authenticated identity, active membership, organization state, verification/lifecycle/compliance status and registered-business mode before exposing its operational modules.
- Individual and development pathways also check identity and membership and route based on recorded account mode.
- UI states that a pathway or application does not itself create commercial authority.

Gaps:
- Gateway/pathway checks are browser-side and do not replace server authorization.
- Several specialist subdirectories and linked operational modules were not exhaustively inspected in this pass.
- Each quote, capability, opportunity, assignment, document and commercial RPC must independently validate partner organization, status, capability, service area and action-specific permission.
- No direct child-page or cross-partner access test was run.

### 3. Driver — SOURCE PARTIAL PASS / PREVIEW MODE PRESENT
Entry redirect: `app/driver/index.html` redirects to `dashboard.html`. Dashboard SHA `4c2b5b1c488e1fd579641413e4a75be5d5852a05`.

Observed:
- Unauthenticated dashboard path deliberately stays on a preview state and renders no assignments; it does not open private data.
- With a session, dashboard checks active driver membership and requires exactly one driver organization.
- Assignment query is filtered to the signed-in user's driver assignments; profile is fetched for the signed-in user.
- Legacy module-01 route redirects to the staging assignment inbox, which then redirects to the driver dashboard's assignments section.

Gaps:
- Driver dashboard does not visibly enforce AAL2 or check a dedicated driver permission before querying; the database policies and server-side assignment ownership checks must do so.
- No direct module-by-module guard test, driver/vehicle binding test or cross-driver query test was run.
- A preview page is not proof that every child route is protected.

### 4. Warehouse — SOURCE PARTIAL PASS / SERVER GATE REQUIRED
Entry page: `app/warehouse/index.html` (SHA `fd5b6a8162dc7ece13f641dbeb58c4fc8260d81d`). Allocation page: `app/warehouse/allocation.html`.

Observed:
- Dashboard checks for a signed-in session and then invokes `krim_warehouse_dashboard` and `krim_warehouse_list_tasks`.
- Allocation page checks session, active memberships, organization status, registered-business mode, partner verification/lifecycle/compliance, verified warehouse capability and approved active facilities before presenting controls.
- Allocation/task actions are routed through named RPCs.

Gaps:
- The dashboard entry page itself does not visibly resolve warehouse role, organization membership, AAL2 or facility scope before calling dashboard/list RPCs.
- Allocation page does not visibly check a specific warehouse permission code before displaying eligible organizations/facilities.
- RPCs must enforce organization/facility scope and action-specific permissions, including QC dual control and creator/approver separation.
- Direct RPC and cross-facility negative tests were not run.

### 5. Customs — STRONGER SOURCE GATE; RUNTIME NOT VERIFIED
Entry page: `app/customs/index.html` (SHA `2db26e47d953645af74286860e92d1229e147cd8`). Shared child gate: `app/customs/secure-workspace.js` (SHA `643808a5db7b345d13de553b45c5b2388f24131e`).

Observed:
- Requires a session, explicitly checks MFA assurance `currentLevel === "aal2"`, active customs organization membership and `compliance.view`.
- Licence submission separately checks `compliance.manage`.
- Shared child gate repeats session, AAL2, membership and `compliance.view` checks.
- UI states that database policies determine record access.

Gaps:
- Must confirm every customs workflow page imports/runs the shared guard before exposing data/actions.
- Upload and review RPCs must independently enforce organization membership, permission, evidence ownership and AAL2; frontend guard is not enough.
- No runtime AAL1 denial or cross-broker test was run.

### 6. Finance — SOURCE PARTIAL PASS
Entry page: `app/finance/index.html` (SHA `5d366a18543abeeb8f4b8804c8f42d8f329ce5b1`). Refund/dispute page: `app/finance/refunds-disputes.html` (SHA `5975a827d4fb4447bc8831a93fe39269142ef0f8`).

Observed:
- Finance entry requires session, active membership in an active finance organization and `krim_has_permission(..., 'finance.view')`.
- Permission query errors fail closed.
- Refund/dispute workflow reads the signed-in user's own payment/refund records and submits refund requests through an idempotent RPC.
- Refund review is submitted through a separate RPC with the UI stating that AAL2 and finance authorization are required; no provider refund is directly executed from the page.

Gaps:
- The refunds page's reviewer organization list includes finance, platform and operations organization types; the server RPC must enforce the exact reviewer role and organization permission, not rely on that client-side list.
- Finance page-specific AAL2 controls are not consistently visible.
- No unauthorized refund/review, cross-customer payment, or ledger mutation test was run.

### 7. Operations — SOURCE PARTIAL PASS; PERMISSION GATE INCOMPLETE AT PAGE LEVEL
Entry page: `app/operations/index.html` (SHA `86b20e9dbbd5916112b4895d11fad43e4e1e03c7`).

Observed:
- Requires session and active membership in an active operations organization.
- Data reads use database queries and dedicated snapshot RPCs.
- Child dispatch page uses dedicated readiness RPCs and describes returned records as policy-authorized.

Gap:
- Entry code visibly checks organization type/status but does not visibly call a specific `operations.view` permission check before loading shipment, exception, event, transfer and return records.
- This is acceptable only if RLS/RPCs independently apply permission and tenant scoping. That must be proven from database policies/function source and negative tests.
- No AAL2 gate is visible at the operations entry; sensitive dispatch, exception and control actions must enforce step-up requirements server-side where policy requires.

### 8. Enterprise — SOURCE PARTIAL PASS; STAGING PREVIEW EXCEPTION
Entry page: `app/enterprise/index.html` (SHA `754a9bd0f396c87f2d8867ee1b9eb434093475f6`).

Observed:
- Production unauthenticated access redirects to enterprise sign-in.
- Authenticated access requires active membership in an active enterprise organization before loading workspace data.
- A special `.krim-staging.pages.dev` no-session path explicitly labels itself “PREVIEW MODE” and says no private records are loaded and protected actions remain unavailable.

Gaps:
- Enterprise entry does not visibly call a specific enterprise permission code before loading all enterprise views.
- Every enterprise child view, export, approval, document, finance and shipment RPC must independently enforce organization membership, role and permission.
- Staging preview must remain strictly visual/read-only; its origin is not yet proven deployed/reachable, and no runtime check has verified that no data requests or actions occur in preview mode.

### 9. Admin / Platform Admin — SERVER GATE PATTERN PRESENT; VEHICLE REVIEW NEEDS STRONGER PROOF
Platform control centre: `app/platform-admin/index.html` (SHA `5628a7f4dde30ec444fe7cbc0bbd5e463c0a2d01`).  
Partner verification: `app/platform-admin/partner-verification.html` (SHA `b1c6b09f6496a6ec740262e76cb625bc71fc5e9d`).  
POD verification: `app/platform-admin/delivery-pod-verification.html` (SHA `fa674d4d0a4e7d15d7f3f681a921c80879d04444`).  
Vehicle verification: `app/admin/vehicle-verification.html` (SHA `9134940a9f7de4a733209a27ac2b66ec4f63564c`).

Observed:
- Platform control centre uses `global-admin-control` for privileged overview and actions; it distinguishes platform admin from superadmin and hides elevated tools from non-superadmins.
- Partner verification and POD verification pages check a session, call `global-admin-control` and require `platform_admin` or `platform_superadmin` before listing/reviewing evidence.
- Driver verification page requires a session before invoking its admin list RPC.
- Vehicle verification page checks a session and decodes the JWT AAL claim in the browser before calling vehicle-review RPCs.

Gaps:
- Driver verification page's visible code does not show an explicit platform-admin role check before its RPC; server-side RPC authorization is essential.
- Vehicle verification page's visible code checks client JWT AAL2 but does not visibly call the platform-admin gate before RPCs. AAL2 alone is not an admin role. The vehicle RPCs must independently enforce both platform-admin permission and AAL2.
- Direct URL access to every platform-admin child page, including the vehicle review page, must be denied without the required role and assurance level.
- No direct RPC invocation or unauthorized reviewer test was run.

## Cross-workspace observations

1. No single, consistently applied shared page guard is evident across all nine workspaces. Entry pages implement different patterns: membership-only, membership + permission, AAL2 + permission, session + privileged Edge Function, or session + RPC.
2. The shared `auth-core.js requireAuth()` is not visibly the universal guard for all sampled workspace entry pages.
3. AAL2 enforcement is explicit in Customs and selected privileged review flows, but not consistently visible in Customer, Driver, Warehouse, Finance, Operations or Enterprise entry code. Backend functions must enforce step-up for sensitive actions.
4. Several pages depend on RPCs for the actual authorization boundary. This is the right architecture only if each RPC validates the caller's JWT, role, active membership, permission, organization/facility/record ownership and AAL requirements independently.
5. Browser-side organization ID filters and role checks are UX/routing controls, not tenant isolation.
6. Existing RLS and SECURITY DEFINER catalog reviews show broad policies/functions and some staging parity drift; those findings remain relevant. A page passing a frontend check does not clear the database-level blockers.
7. No runtime evidence exists yet for unauthorized direct page access, direct RPC access, cross-tenant reads/writes, AAL1 denial, expired sessions, or revocation.

## Required remediation / verification gates

1. Create one shared, fail-closed workspace bootstrap contract for session + user + active organization + role + permission + optional minimum AAL; each page declares its required workspace and minimum assurance.
2. Do not rely on the shared client guard as the security boundary. Repeat authorization in RLS policies and every privileged RPC/Edge Function.
3. Add explicit page-level permission checks where missing for Operations, Enterprise, Warehouse dashboard and Admin/Driver verification; keep server checks authoritative.
4. Verify every Driver and Partner child route either imports a secure gate or exposes only public/non-sensitive preview content.
5. Verify Staging enterprise preview performs no private data reads, writes, storage access or provider calls.
6. Review vehicle and driver admin RPCs for both admin-role and AAL2 checks. AAL2 without a platform-admin role must be denied.
7. Build an isolated Staging negative-test matrix: unauthenticated direct URL, wrong workspace role, inactive membership, wrong organization, cross-tenant object ID, AAL1, expired session, revoked membership, direct RPC invocation, and read/write attempts.
8. Test the same controls through each real UI and direct network/RPC calls. Capture sanitized evidence without exposing user IDs, emails, JWTs, documents or signed URLs.
9. Only after the Staging origin and test-sink protections are proven should synthetic test identities and controlled runtime tests be created.

## Release decision

| Workspace | Source review | Runtime authorization |
|---|---|---|
| Customer | Partial pass | Not verified |
| Partner | Partial pass | Not verified |
| Driver | Partial pass; preview mode | Not verified |
| Warehouse | Partial pass; server RPC dependency | Not verified |
| Customs | Stronger explicit gate | Not verified |
| Finance | Partial pass | Not verified |
| Operations | Membership gate; permission gap at page level | Not verified |
| Enterprise | Membership gate; safe-preview branch by source | Not verified |
| Admin / Platform Admin | Privileged server gate on sampled pages; vehicle/driver RPC role proof required | Not verified |

**Real-user onboarding: NOT APPROVED.** No workspace receives a runtime authorization pass from this source-only review.

No code, database, Auth settings, user/session, storage object, provider or deployment was changed. NO EVIDENCE = NO PASS.
