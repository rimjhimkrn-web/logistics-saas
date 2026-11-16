# KRIM Nine-Workspace Entry-Point, Route-Guard and Permission-Consistency Audit
**Date:** 16 November 2026  
**Scope:** Read-only review of the nine workspace HTML entry points, sign-in/registration helpers, selected backend RPC definitions and production organization/membership baseline. No sign-in was attempted, no user session or MFA factor was changed, no RPC was invoked, and no production data, policy, function or page was modified.

## Executive decision
**NO-GO for declaring all nine workspace entry points consistently authorized or production-certified.** Several workspaces have clear server-backed membership gates; sensitive customs and platform-admin paths add MFA/privileged server checks. However, the route guards are inconsistent, some landing pages are only authentication gates that rely entirely on RPC/RLS for actual access, and the legacy `app/index.html` customer workspace accepts any active organization membership without checking that the selected organization is a customer organization.

This is a route/permission consistency finding, not evidence that an unauthorized user can read another tenant's protected data. Database RLS and RPC authorization remain the effective security boundary and must be independently tested.

## 1. Live organization baseline
Production currently has 14 organizations and 13 active organization memberships. Active membership distribution:
- Platform: 1 owner
- Customer: 5 owner memberships
- Partner: 1 owner membership
- Carrier: 1 driver membership
- Warehouse: 1 member membership
- Customs: 1 manager membership
- Finance: 1 manager membership
- Operations: 1 manager membership
- Enterprise: 1 manager membership

One partner organization has no active member. The production identity catalogue is small and contains no evidence of a full nine-workspace customer/partner network operating at scale. Organization catalogue status `active` does not itself mean partner verification, capability, corridor approval or operational readiness.

## 2. Workspace gate matrix

| Workspace | Entry-point behavior observed | Assessment |
|---|---|---|
| Customer (`app/customer/index.html`) | Auth session; active membership lookup; organization-type/role mapping; rejects platform admin and ambiguous multi-role; routes other role types to their matching workspace. | Stronger UI gate; server RLS still decisive. AAL2 is displayed/requested as an optional step for the customer dashboard, not a general read gate. |
| Partner (`app/partner/index.html`) | Authenticated user; active membership; fetches linked organizations; accepts partner/carrier/forwarder/logistics-provider/warehouse-operator types; blocks multiple matching organizations; routes by partner account mode. | Good ambiguity handling, but this is a gateway, not a universal deep-link guard. It does not itself certify current compliance/capability or enforce AAL2. Sensitive actions must continue to be server-gated. |
| Driver (`app/driver/index.html`) | Auth session; accepts driver invitation token if present; requires exactly one active driver membership; checks active organization and, for commercial eligible carrier, verified/compliant partner status. | Good identity/org ambiguity handling. Driver-specific RPCs also check exact user, active driver membership and assignment ownership. AAL2 is not imposed for all driver functions; sensitive evidence review is separate. |
| Warehouse (`app/warehouse/index.html`) | Auth session then calls `krim_warehouse_dashboard` and `krim_warehouse_list_tasks`; no client-side organization-type/AAL2 check. | UI gate is intentionally thin, but server RPCs are the real authorization. Dashboard derives eligible warehouse orgs and requires `partner.manage`; task list uses `private.krim_warehouse_is_operator`. Must test those helpers against wrong-org, non-warehouse and suspended membership. |
| Customs (`app/customs/index.html`) | Auth session; AAL2 required; active customs organization membership; then `compliance.view` permission check. | Strong explicit entry gate for sensitive customs workspace. Internal customs review remains distinct from government clearance. |
| Finance (`app/finance/index.html`) | Auth session; active finance organization membership; explicit `finance.view` permission. | Strong read-entry gate. AAL2 and separate server permission checks remain required for financial posting, refunds, settlement and other high-impact operations. Finance remains deferred. |
| Operations (`app/operations/index.html`) | Auth session; active operations organization membership; loads shipment/exception/event data and a guarded snapshot RPC. | P1 consistency gap: the page-level gate checks organization type but does not explicitly call `operations.view`. Direct shipment/event queries rely on table RLS; snapshot RPC checks operations membership but filters snapshots using `shipment.view` on each customer organization. This can make authorized operations users see different results across direct queries and snapshots. |
| Enterprise (`app/enterprise/index.html`) | Auth session; active enterprise organization membership; then opens workspace. | Membership-only entry gate; no explicit enterprise permission check at the page gateway. Shipment visibility relies on RLS. Earlier audit found no organization relationships/network memberships and an enterprise shipment query/fallback mismatch. |
| Platform Admin (`app/platform-admin/index.html`) | Auth session; all data/actions through `global-admin-control` Edge Function; server verifies AAL2, active privileged roles and action-specific superadmin for sensitive role changes. | Strong server-side privileged boundary. Page UI alone is not authority. Earlier audit found its audit helper ignores an audit insert error, so privileged action and durable audit may not be atomic. |

## 3. Confirmed route and implementation issues

### P1 — Legacy customer workspace lacks organization-type validation
`app/index.html` calls `auth.getSession()`, loads all active `krim_organization_members` rows and lets the user choose any active organization ID. It does not fetch `krim_organizations.organization_type` or require a customer organization before rendering the legacy customer shipment workspace.

Impact:
- A warehouse, customs, finance, operations, enterprise, carrier or platform member can reach the customer-labelled page and select their active organization.
- This does **not** prove they can read customer shipments or create a valid shipment: backend RLS/RPC controls still apply.
- It is nevertheless a workspace-boundary and user-confusion defect, and any legacy `shipment_requests` path must be reviewed for organization binding and role authorization.
- The newer `app/customer/index.html` has a more explicit role/type mapping and should be the canonical customer entry. The legacy route should be retired or given the same strict gate after migration/dependency review.

### P1 — Operations entry gate and operation-specific permission are inconsistent
The operations landing page checks active operations organization membership but does not explicitly require `operations.view` before attempting direct reads. The `krim_operations_list_shipment_snapshots` SECURITY DEFINER RPC does require an active operations membership, then filters by `shipment.view` permission on the customer organization. This means a valid operations member without customer-organization membership may see shipment rows through one RLS path but not receive corresponding snapshots. This matches the earlier operations audit finding.

Required fix direction: define a single explicit operations permission contract and have both page/RPC queries use it consistently, while preserving per-shipment customer data scope and minimum necessary visibility.

### P1 — Enterprise page uses membership as the UI gate, not a named permission
The enterprise entry page opens on active enterprise organization membership alone. It then depends on RLS for shipment access. Given no network membership/organization relationships in production and the earlier observed legacy fallback, enterprise membership is not proof of access to customer shipments or subsidiary data. The UI must distinguish “enterprise workspace access” from “authorized linked-organization data access”.

### P1 — Route gateway is not a deep-link security boundary
The partner index performs organization selection and account-mode routing, but users can navigate directly to child HTML paths. The driver, warehouse, customs, finance, operations and enterprise pages each have their own differing checks. Every sensitive RPC/table/storage operation must enforce authorization independently; the gateway redirect cannot be relied on to protect a deep link.

### P2 — Authentication-only sign-in is correctly separated from authorization, but portal return paths are generic
`app/sign-in.html` allows only customer/partner/enterprise/field portal query values, validates same-origin `/app/` return paths and rejects the sign-in page itself. Registration explicitly states it creates an authentication identity only and does not create an organization or workspace membership. This is correct separation of identity from authorization. However, the portal allowlist does not include driver, warehouse, customs, finance, operations or platform-admin, which use older/role-specific sign-in routes; the overall authentication entry experience is fragmented.

## 4. Positive backend controls verified from definitions
- `krim_warehouse_dashboard` requires auth and builds visible organization IDs only from active membership in eligible warehouse organizations with `partner.manage`.
- `krim_warehouse_list_tasks` requires auth and uses `private.krim_warehouse_is_operator(user, organization, facility)` for every returned task.
- `krim_operations_list_shipment_snapshots` requires auth and active operations membership; it does not accept a client-supplied organization ID.
- `krim_driver_record_trip_event` requires auth, exact assignment ownership, active driver membership for the assignment organization, active exact partner assignment, linked shipment and leg, and valid state/dispatch conditions.
- Customs page explicitly requires AAL2, customs organization membership and `compliance.view`.
- Finance page explicitly requires active finance organization membership and `finance.view`.
- Platform-admin browser actions are routed through the privileged Edge Function; sensitive role changes are server-side and require superadmin.
- `krim_has_permission` is an authenticated-only wrapper delegating to the private permission function; anon cannot execute it in the inspected privilege snapshot.

These are source-level observations, not runtime penetration-test results.

## 5. Required staging-only access matrix
For each of the nine workspace types, test:
1. Anonymous access and expired/revoked session.
2. Authenticated user with no membership.
3. Active membership in a different workspace type.
4. Membership in two organizations of the same type; explicit organization selection, no silent first-match.
5. Multiple workspace types; no ambiguous automatic routing.
6. Suspended membership, inactive organization, revoked role and stale JWT/session.
7. Missing workspace permission, wrong permission scope and permission in another organization only.
8. AAL1 versus AAL2 for each high-impact action.
9. Direct deep-link to every child page without visiting the workspace gateway.
10. Direct table REST calls, RPC calls and private storage object access.
11. Tenant A attempting to read/update/delete Tenant B records and evidence.
12. Cross-workspace access: customer-to-partner, driver-to-warehouse, enterprise-to-customer, operations-to-finance, customs-to-finance and platform-admin-to-all.
13. User metadata/app metadata claim tampering; authorization must not trust user-editable metadata.
14. Role revocation while a session is active; confirm immediate server denial.
15. Error states: permission denied must not be rendered as an empty successful dataset.

No test user or tenant was created for this review; all tests remain staging-only.

## 6. Remediation order
1. Make `app/customer/index.html` the only supported customer entry or bring legacy `app/index.html` into exact customer organization/type/role validation.
2. Establish explicit `operations.view` and enterprise workspace permission contracts, and align UI, RPC and RLS visibility.
3. Add shared, non-authoritative UI session/role helpers for consistency, while retaining mandatory backend authorization on every operation.
4. Inventory all child HTML deep links and verify their data calls fail closed without the correct role, permission, tenant and AAL.
5. Ensure error states never convert permission failures into empty/zero metrics.
6. Run the nine-workspace staging matrix and record request/response evidence before production release.

## 7. Change control and release gate
This was a read-only audit. No data, memberships, roles, functions, policies, storage rules or user sessions were changed. No privileged RPC was invoked. Financial collection remains deferred.

The production/repository migration crosswalk is still unresolved. Do not change production policies/functions or retire legacy pages/routes until migration reconciliation and dependency review are complete.

**Release status: NO-GO for claiming uniform nine-workspace authorization certification.** Several strong server-side controls are present, but route-gate inconsistency, legacy customer workspace role mismatch, operations permission mismatch and enterprise access semantics require remediation and staging proof.
