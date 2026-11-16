# KRIM Nine-Workspace Integration and Permission Consistency Audit — 2026-11-16

## 1. Scope and release decision
Read-only review of the nine workspace entry points, shared browser security helper, live role/permission catalogue and active assignment counts. No production writes, role changes, grants, policy changes or business RPC calls were performed.

**Release decision: NO-GO for unrestricted multi-workspace production use.** The platform has a useful role/permission foundation and several well-designed workspace gates, but the nine entry points do not yet enforce one consistent authorization contract. Some pages rely on authentication or organization type/membership before displaying data, while others explicitly call permission checks and MFA. Database RLS and server-side RPC checks remain the final security boundary; frontend navigation is never authorization.

## 2. Nine workspace inventory

| Workspace | HTML pages in app tree | Entry point observed | Current access pattern / gap |
|---|---:|---|---|
| Customer / Shipper | 2 | `app/customer/index.html` | Requires active organization membership and maps membership/organization type to one customer workspace. Refuses multiple workspace roles and platform-admin use. Displays AAL level but does not block dashboard load when AAL2 is absent. |
| Partner / Carrier | 19 | `app/partner/index.html` | Strong gateway: verifies signed-in user, active partner organization membership, partner account pathway and ambiguity; routes only after checks. Gateway explicitly does not grant permissions. |
| Driver | 18 | `app/driver/index.html` | Requires authenticated session; loads active driver membership and assignments, invitation acceptance may be attempted from URL/session token. Individual RPCs enforce assignment/driver state. Entry page needs a clearer explicit role/profile verification result before all profile features are exposed. |
| Warehouse | 3 | `app/warehouse/index.html` | Requires session and calls server-side dashboard/task RPCs. This is better than direct table access, but page itself does not visibly verify active warehouse organization membership or a named warehouse permission before the RPC calls; RPC must be the authority. |
| Customs | 1 | `app/customs/index.html` | Stronger gate: session, AAL2 and active customs-organization membership. Customs workflows call dedicated RPCs. Need ensure every broker/document/review action has exact permission and separation-of-duties checks server-side. |
| Finance | 12 | `app/finance/index.html` | Requires active finance-organization membership and calls `krim_has_permission(...,'finance.view')`. Page describes itself as read-only. No evidence that page provides a general write capability; sensitive finance RPCs remain separately gated. |
| Operations Control Tower | 15 | `app/operations/index.html` | Session-scoped queries and permission/RLS-aware messaging, but the inspected entry script did not show an explicit active operations-organization membership or named permission gate before loading. This needs a dedicated server-side operations access predicate. |
| Enterprise | 14 | `app/enterprise/index.html` | Requires session and active enterprise-organization membership. The inspected entry point did not show a named enterprise permission check before enabling workspace data queries; row policies still constrain results. |
| Admin / Platform | 22 platform HTML pages plus one `app/admin` page; platform pages live outside `app/platform/` | Example: `app/admin/vehicle-verification.html` | Vehicle verification page explicitly requires platform-admin access and AAL2 in its notice and workflow; the full platform route inventory and every admin page still need one consistent platform guard. |

The tree count is an inventory of checked-in HTML entry points, not proof every page is deployed, linked, or fully functional.

## 3. Live role and permission catalogue

Production currently has:
- 11 system roles.
- 23 permission codes.
- 155 role-permission mapping rows (155 is the current catalogue mapping count; the summary below counts granted mappings).
- 17 active user-role assignments in the latest baseline; 13 active organization memberships.
- Active role assignments include compliance_manager (1), customer_user (2), finance_manager (1), operations_manager (1), organization_admin (1), organization_owner (6), partner_user (2), platform_admin (2), platform_superadmin (1).
- No active dispatcher role assignment appeared in the inspected assignment summary.

### Granted permissions by role

| Role | Granted permission count | Notable scope |
|---|---:|---|
| customer_user | 10 | Shipment create/update/view, quote create/view, document upload/view, finance view |
| partner_user | 11 | Partner view, quote create, shipment assign/update/dispatch, tracking update, documents |
| dispatcher | 9 | Shipment assign/dispatch/update, tracking update, partner view |
| operations_manager | 15 | Broad shipment/partner/quote/dispatch/tracking operations, including shipment.cancel |
| finance_manager | 7 | finance.manage/view, invoice/document controls and read visibility |
| compliance_manager | 8 | compliance.manage/view and document management |
| organization_admin | 21 | Broad organization, partner, shipment, quote, finance view, compliance and dispatch scope |
| organization_owner | 22 | Broad organization, partner, shipment, quote, finance.manage, compliance.manage and dispatch scope |
| platform_admin | 22 | Broad business permissions; does not hold `admin.platform` in the role map |
| platform_superadmin | 23 | All listed permissions including `admin.platform` |
| viewer | 7 | Read-only visibility permissions |

## 4. Key permission consistency findings

### P0 — role scope is broader than the workspace boundaries suggest
- `partner_user` is granted `shipment.assign` and `shipment.dispatch` in the role map. Some partner operations legitimately need to accept assignments or authorize their own leg, but the generic permission names are too broad if not paired with exact partner organization, exact leg, accepted assignment, current capability, confirmed capacity, route eligibility and AAL2 where required.
- `organization_owner` and `organization_admin` receive `finance.manage`, `compliance.manage`, `partner.manage`, shipment dispatch and cancellation-related permissions (owner has 22, admin 21). This is excessive by default for a generic business owner/admin and undermines finance/compliance separation of duties.
- `platform_admin` has broad operational and finance management permissions even though it does not have the distinct `admin.platform` permission. Clarify the difference between platform administration, platform operations and finance/compliance reviewer powers.

**Required correction:** split generic roles into narrow functional roles and scope each operation by organization, shipment/leg, assigned partner, jurisdiction, record state and reviewer independence. Do not use the permission catalogue alone as proof a transition is valid.

### P0 — inconsistent AAL2 requirements
- Customs entry explicitly blocks unless current assurance is AAL2.
- Vehicle verification page says AAL2 required.
- Customer page only reports assurance level and continues loading when AAL2 is not present.
- Partner and other workspaces rely on individual action RPCs for sensitive action assurance; entry-point consistency is not demonstrated.

**Required correction:** define an action-to-assurance matrix. Require AAL2 server-side for high-impact actions: platform approvals, partner verification, capability approval, customs clearance/review, dispatch authorization, claims/refunds, finance posting/recovery, sensitive exports and role/permission changes. Ordinary read-only access may use AAL1 if approved by policy. Never rely on a client-side assurance check alone.

### P0 — enterprise and operations entry gates are not uniform
- Enterprise verifies active enterprise organization membership, but no explicit named enterprise permission check was observed in the entry flow.
- Operations loads operational datasets through the current session and database policies; a dedicated operations membership/permission gate was not visible in the inspected entry script.
- Warehouse relies on server-side RPCs after session verification but lacks an explicit entry-level organization gate.

**Required correction:** every workspace should call one server-side `krim_workspace_access_decision`-style evaluator with workspace code, requested action and organization context. It should return allow/deny, safe reason code, required assurance level, organization scope and policy version. It must not trust client-supplied role claims or user metadata.

### P1 — mixed role sources
KRIM has both `krim_organization_members` and `krim_user_role_assignments` / `krim_security_roles` / `krim_role_permissions`. The customer workspace maps active organization membership role plus organization type; the shared `platform/krim-security.js` helper separately reads role assignments and role-permission mappings. Different pages may therefore resolve workspace eligibility from different sources.

**Required correction:** establish one canonical identity/organization/role source and document a migration from legacy roles. No client metadata or editable user metadata may grant authorization. Ensure revocation takes effect for sensitive actions even if a JWT has stale claims.

### P1 — no dispatcher assignment currently visible
The role catalogue includes `dispatcher`, but no active dispatcher assignment appeared in the queried live assignments. A workspace may still be reachable by other roles, but the operational ownership model is not fully provisioned or demonstrated.

**Required correction:** define dispatcher organization membership, shift/coverage, AAL2 and per-leg authorization, with explicit revocation and handover.

### P1 — UI visibility is not a security boundary
Workspace links and module cards are navigation. A user may open a direct URL. Every read must be RLS-scoped and every write must pass a narrowly scoped RPC with authorization, state, evidence and audit checks. This is especially important for the many dedicated sub-pages outside the nine workspace indexes.

## 5. Shared helper review
`platform/krim-security.js` provides functions for authentication, MFA assurance, role assignments, role checks, permission checks and route guards. This is a good shared foundation. However:
- The helper's role/permission resolution uses the role-assignment catalogue, while some workspace pages use organization membership role and organization type directly.
- Helper existence does not prove every page imports or invokes it.
- All high-risk permissions still need server-side enforcement inside the called RPCs.
- Avoid client-side role-derived hiding as the only protection.

## 6. Target workspace access contract

Every workspace and dedicated module should follow this sequence:

1. Validate Supabase session using `auth.getUser()` (not just locally cached session data for sensitive operations).
2. Resolve active organization membership from the canonical server-side source.
3. Resolve organization type and active lifecycle/verification status.
4. Resolve effective role and permission from the canonical server-side role catalogue.
5. Enforce workspace-specific permission for the requested operation.
6. Enforce current AAL2 for high-impact actions.
7. Enforce exact object scope: organization, shipment, leg, partner, facility, customs jurisdiction or finance entity.
8. Enforce object state and prerequisite evidence server-side.
9. Record immutable audit event for state-changing actions.
10. Return safe denial reason and trace/correlation ID without leaking private evidence or cross-organization details.

A workspace access decision must never itself create membership, activate an organization, verify a partner, approve a licence or authorize dispatch.

## 7. Proposed role separation

| Functional responsibility | Suggested narrow role | Do not automatically grant |
|---|---|---|
| Customer shipment user | customer_user | Partner verification, dispatch authorization, finance posting |
| Partner account user | partner_user | Customer shipment creation, platform approval, finance posting |
| Driver | driver | Partner assignment award, finance, compliance approval |
| Warehouse operator | warehouse_operator | Independent QC approval, dispatch authorization without handover checks |
| Warehouse quality reviewer | warehouse_quality_reviewer | Self-approval of own work |
| Customs broker operator | customs_broker | Platform legal clearance or broker licence approval |
| Customs reviewer | customs_reviewer | Review of own submitted evidence |
| Operations controller | operations_manager / dispatcher | Finance posting, independent compliance approval |
| Finance operator | finance_manager | Independent approval of own posting/refund |
| Finance approver | finance_approver | Initiating own financial request and approving it |
| Compliance reviewer | compliance_manager | Approval of own evidence submission |
| Enterprise viewer/admin | enterprise_viewer / enterprise_admin | Platform-wide access or unrelated tenant visibility |
| Platform support | platform_support | Financial, legal or dispatch approval powers |
| Platform approver | platform_approver | Approval of own request or evidence |
| Platform superadmin | platform_superadmin | Routine business operation without separate audit controls |

These are target role design recommendations, not existing roles to assign immediately.

## 8. Staging test matrix
Before changing production roles, build synthetic tenants and run:
- No session, expired session, revoked membership and disabled organization.
- User belongs to customer and partner orgs; workspace routing must not silently choose an arbitrary organization.
- Multiple active memberships of the same type; user must select or be explicitly scoped to one.
- Wrong organization type and wrong role.
- Cross-tenant ID substitution for shipments, quotes, legs, documents, customs cases, warehouse facilities and finance rows.
- Partner user tries to dispatch another partner's assignment.
- Driver tries to submit POD for another driver's assignment.
- Warehouse operator tries to approve own QC.
- Customs operator tries to approve own broker licence/document.
- Finance operator tries to approve own refund or posting.
- Operations manager tries to execute finance posting.
- Platform admin without `admin.platform` tries platform-only approval.
- AAL1 tries each high-impact action; AAL2 passes only with correct permission and object scope.
- Direct URL and direct RPC invocation bypass attempts.
- Membership revoked while session remains open.
- Role changed while JWT remains unrefreshed.
- Permission mapping denied/removed and cache invalidation.
- RLS query error must display unavailable, never fabricated zero.
- Notification and audit event delivery must be verified separately from event creation.

## 9. Recommended implementation order
1. Reconcile production migration lineage and sanitized schema manifest. No production grants/role changes before this.
2. Declare canonical identity, membership, role and permission sources.
3. Approve a permission matrix for every workspace action, not just workspace entry.
4. Split owner/admin/platform roles to restore finance/compliance/operations separation of duties.
5. Implement shared server-side workspace access evaluator and wire every index page and module action.
6. Standardize AAL2 for high-impact actions in RPCs.
7. Audit all dedicated sub-pages and RPC callers, not only workspace dashboards.
8. Build staging multi-tenant adversarial tests and verify negative cases.
9. Roll out only after independent security review and regression tests.

## 10. Verification boundary
Reviewed live role/permission records and selected workspace HTML/JS entry points read-only. No production permissions, roles, RLS policies, memberships, organization states, grants, functions or data were changed. This audit does not certify every dedicated page or RPC as secure; the complete module-by-module audit remains necessary.
