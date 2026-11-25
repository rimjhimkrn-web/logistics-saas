# Phase 00 — Enterprise workspace authorization and approval-governance audit

Date: 2026-11-25  
Repository: `rimjhimkrn-web/logistics-saas`  
Branch: `qa/phase-00-baseline-2026-11-25`  
Production Supabase: `ebltviniygljwwseplph`  
Staging Supabase: `qrpcivhdxobiaofppbkl`

## Executive verdict

**Enterprise workspace: NOT VERIFIED. Financial approval governance: CRITICAL SOURCE-LEVEL AUTHORIZATION DEFECT.**

This pass traced the Enterprise entry page, approval queue page, shared enterprise live-data module, related Production RLS policies and grants, and Staging table permissions. All database inspection was read-only. No user JWT, RPC, REST mutation, browser session, export, provider call or database write was performed.

### Critical finding — approval controls are writable under organization-access RLS, not finance authorization

Production catalog evidence shows:
- `krim_financial_approval_policies`, `krim_financial_approval_requests`, and `krim_financial_approval_events` have RLS enabled.
- Each has an authenticated `ALL` policy based on `private.krim_has_organization_access(auth.uid(), organization_id)` (events inherit the request's organization).
- None of those policies requires `finance.manage`, `finance.approve`, `admin.platform`, AAL2, independent reviewer identity, or another action-specific approval permission.
- Authenticated has table-level INSERT, UPDATE and DELETE privileges on all three tables. Table-level SELECT is not granted.
- For approval requests and events, column-level INSERT and UPDATE privileges are also present across sensitive fields, including request status, approver identity/timestamps, amount, action fingerprint, execution reference, event type, actor identity, status transitions and event payload.
- No database triggers were found on the approval request or approval event tables in the inspected trigger catalog.
- The approval-policy table contains sensitive governance controls: `auto_approval_limit`, `founder_approval_limit`, `require_founder_approval`, `require_dual_control`, `transaction_scope`, currency and active status.

This creates an over-broad direct database write surface: a caller admitted by the organization-access helper can be granted direct writes to approval configuration and request/event state without a finance-specific authorization predicate in the RLS policy. The schema and grants therefore do not enforce the same controls as the protected internal approval workflow. This is a **critical release blocker** until least-privilege table grants and policies are corrected and verified.

The direct REST exploit was not attempted. The finding is based on effective database grants, RLS policy definitions, sensitive column privileges and absence of triggers; runtime exploitability and actual role distribution still require controlled negative tests. Do not interpret the absence of SELECT as a sufficient safety control: INSERT/UPDATE/DELETE are separately granted.

## 1. Enterprise entry page — membership gate only

File: `app/enterprise/index.html`  
Source SHA: `754a9bd0f396c87f2d8867ee1b9eb434093475f6`

Observed:
- Uses `window.KRIM_SUPABASE`.
- Requires a Supabase session in Production; unauthenticated users are redirected to Enterprise sign-in.
- Staging no-session path explicitly renders visual preview and says no private records are loaded.
- Queries active `krim_organization_members` for the current Auth user and resolves active Enterprise organizations.
- Blocks when no active Enterprise membership exists.
- It does not visibly require a specific Enterprise permission such as `enterprise.view` or an action-specific permission before showing the workspace shell.
- After the membership gate, it directly queries `krim_shipments`, with fallback to legacy `shipment_requests`; the data boundary must therefore be enforced by the database RLS and table grants.
- Shipment export is generated locally from rows returned to the session; no mutation is present in this page.

Assessment: **MEMBERSHIP GATE PRESENT; PERMISSION AND TENANT BOUNDARY DEPEND ON BACKEND.** The membership gate is routing/UI logic, not proof that all Enterprise members are authorized for every displayed dataset. The main page's direct query also needs runtime proof that both current and legacy shipment sources return only the intended enterprise/customer/contract records.

## 2. Approval queue — read-only UI, but the database write boundary is unsafe

File: `app/enterprise/approvals.html`  
Source SHA: `2f48a3ffc0288833bf05a8b2dee3b7cad6df6cc7`

Observed:
- Requires a session in Production and active membership in an active Enterprise organization.
- Staging no-session branch is labelled preview and makes no private approval query.
- The page reads `krim_financial_approval_requests` filtered to the Enterprise organization IDs, then reads related `krim_financial_approval_events`.
- The UI exposes search/filter and read-only queue/event display. It contains no approve/reject/execute button and no approval mutation RPC.
- The page does not check `finance.view`, `finance.manage`, `finance.approve`, or AAL2 before querying.
- It states that row-level policies remain authoritative.

Production grant mismatch:
- The approval request and event tables have no table-level authenticated SELECT privilege, and the inspected column-grant result contains INSERT/UPDATE but no SELECT privileges for their columns.
- Therefore, the exact SELECT queries used by this page do not have the necessary table/column-level SELECT grant in the inspected Production catalog. The current approval queue is expected to fail at the database privilege layer, even before a meaningful row-level visibility test.
- At the same time, authenticated INSERT/UPDATE/DELETE grants exist under the broad organization-access `ALL` policies described above.

Assessment: **APPROVAL QUEUE READ PATH BLOCKED; DIRECT WRITE AUTHORIZATION OVER-BROAD.** The UI being read-only does not make the database read-only. The current grant/policy combination is inconsistent and must be corrected before the queue is used for financial governance.

## 3. Protected internal approval routines

Production catalog contains:
- `krim_internal.evaluate_financial_approval(...)`: SECURITY DEFINER, non-public internal schema, no authenticated or anon EXECUTE. It checks amount/currency and reads the active matching approval policy; it creates a pending approval request/event when founder approval is required or amount exceeds the auto-approval limit.
- `krim_internal.consume_financial_approval(...)`: SECURITY DEFINER, non-public internal schema, no authenticated or anon EXECUTE. It requires a matching action fingerprint, approved status, unexpired request and unused execution reference; it locks the request, marks it executed and appends an event.
- Both have pinned `search_path` settings.

These private functions are a positive control and the consumption path has meaningful idempotency/fingerprint checks. However, they do **not** neutralize direct table grants and RLS policies that allow client-role writes to the underlying policy/request/event tables. The policy and request tables must be server-managed only or use narrow, audited RPCs with finance permission, AAL2 and dual-control rules. Keep the internal functions inaccessible to client roles.

## 4. Enterprise live-data module — generic direct reads rely entirely on RLS

File: `app/enterprise/enterprise-live.js`  
Source SHA: `7702f91984ec9e6c5e407db111506ff865cad736`

The module's generic `read(source)` selects configured columns from each table, orders by a date column and limits to 100 rows. It does not add an organization filter itself. Its safety depends entirely on the database policy for each table.

Source datasets include:
- Membership directory: `krim_organization_members`
- Documents: `krim_documents`
- Integration registry and sync runs: `krim_integrations`, `krim_integration_sync_runs`
- AI activity: `ai_actions`
- Financial approval requests: `krim_financial_approval_requests`
- Workflow runs: `krim_workflow_runs`
- Automation execution logs: `automation_execution_logs`
- Audit events: `krim_audit_events`
- Overview pulse: `krim_shipments`, `krim_quotes`, `krim_invoices`, `krim_workflow_runs`
- Shipment view through `window.KRIM.api.listShipmentRequests()`

### Production policy observations

| Dataset | Observed RLS boundary | Assessment |
|---|---|---|
| Memberships | SELECT where `user_id = auth.uid()` | Shows the current user's memberships, not a complete organization directory |
| Documents | SELECT where organization is non-null and caller has organization access | Tenant predicate present; private file contents/URLs are not selected by this module |
| Integrations | SELECT only for non-null organization and organization access | Tenant predicate present |
| Integration sync runs | Parent integration organization is NULL OR caller has organization access | Global/null-organization sync runs are visible to every authenticated caller if linked to a null-org integration; verify these rows contain no tenant-sensitive sync details or errors |
| AI actions | SELECT where `user_id = auth.uid()` | User-scoped; the table also has own-user INSERT policy and authenticated table CRUD grants, which is broader than this read-only Enterprise UI |
| Workflow runs | Organization access OR `admin.platform` permission | Tenant/admin boundary present |
| Automation execution logs | Service-role-only policy; authenticated SELECT privilege absent | Enterprise page's generic read will be denied for ordinary authenticated users |
| Audit events | SELECT where `actor_user_id = auth.uid()` | Actor-scoped, not a full enterprise organization audit stream |
| Quotes | SELECT through customer organization access | Customer-organization scope; Enterprise organization access alone may not authorize records |
| Invoices | SELECT via finance permission on finance, owning, customer, supplier or partner organization | Action-specific finance permission boundary present |
| Shipments | Customer organization access, active partner assignment, Operations membership + shipment.view, or eligible partner opportunity | No explicit Enterprise-specific read branch was observed in this policy; Enterprise access must be demonstrated via its actual customer/partner relationship or an intentionally defined Enterprise policy |

The Enterprise module presents some sources as enterprise-wide governance views, but their actual policy scope is narrower or different:
- Membership directory only shows the signed-in user's memberships.
- Audit events only show records where the current user is the actor.
- Automation logs are unavailable to authenticated users.
- The generic approval source has no authenticated SELECT grant.
- Shipment access does not visibly include an Enterprise-specific branch in the sampled RLS policy.
- Integration sync runs have a broad null-organization visibility branch that should be checked against real global integration rows and payload sensitivity.

Assessment: **MODULE IS A COLLECTION OF SESSION-DEPENDENT TABLE READS, NOT A PROVEN ENTERPRISE TENANT DATA SERVICE.** Labels such as “live”, “directory”, “audit trail” or “governance” should not be interpreted as completeness or enterprise-wide coverage until the relevant policies are explicitly mapped and runtime-tested.

## 5. Production vs Staging

Staging has RLS enabled on the sampled tables but effective authenticated SELECT/INSERT/UPDATE/DELETE privileges are false for all sampled Enterprise data sources, including approvals, documents, integrations, shipments, invoices and workflow runs.

This is consistent with the previously recorded broad Staging API-grant gap. The Staging Enterprise UI cannot currently exercise the same direct-table read paths as Production. Do not grant broad table privileges or copy Production grants wholesale. First establish the intended least-privilege API surface, review all policies, and reconcile the Staging migration history.

## 6. Required remediation — review before any change

**Priority 0 — financial approval governance**
1. Revoke direct authenticated INSERT/UPDATE/DELETE privileges on `krim_financial_approval_policies`, `krim_financial_approval_requests` and `krim_financial_approval_events` unless a specific, justified column/action is required.
2. Replace broad authenticated `ALL` policies with read-only finance permission policies where reads are required; no client-side write policy should allow approval status, approval identity, execution fingerprint/reference, thresholds or event history to be directly modified.
3. Keep all approval creation, decision, policy change and consumption in narrowly scoped server-side RPCs/functions that enforce active membership, `finance.manage` / `finance.approve`, AAL2, request ownership, reviewer separation, dual control, immutable audit events and idempotency.
4. Restrict approval-policy changes to a separately authorized platform/finance governance role with step-up and immutable audit.
5. Add database-level constraints/triggers only where appropriate after reviewing the full lifecycle; do not rely on a frontend read-only design.

**Priority 1 — Enterprise read model**
6. Define an explicit Enterprise permission contract (for example `enterprise.view` plus finance/document/integration-specific permissions); enforce it in RLS/RPCs, not only the page.
7. Map each configured dataset to the intended organization relationship and action permission. Add explicit tenant filters in the client as defense in depth, while keeping RLS authoritative.
8. Decide whether global integration sync runs are meant to be visible to all authenticated users. If not, remove the `organization_id IS NULL` visibility branch or replace it with a platform-admin-only predicate.
9. Either provide an authorized server-side audit stream for the organization or rename the current actor-only view so it does not imply a complete enterprise audit trail.
10. Remove or clearly mark datasets that cannot be read by authenticated users, such as service-role-only automation logs, instead of presenting them as a normal live data source.

**Priority 2 — controlled verification**
11. After explicit approval and isolated test-fixture protection, test:
   - unauthenticated and non-Enterprise users at the Enterprise entry and child pages;
   - Enterprise member without finance permission reading approvals/invoices;
   - Enterprise member attempting direct INSERT/UPDATE/DELETE on approval policies, requests and events;
   - AAL1 finance user attempting approval/policy mutation;
   - finance user attempting to approve own request;
   - wrong-organization and cross-tenant approval IDs;
   - forged event actor/status/payload and modified execution fingerprint/reference;
   - null-organization integration sync visibility;
   - cross-customer shipment and invoice reads;
   - direct CSV export contains only rows authorized for that session.
12. Capture sanitized request/response evidence and before/after test-database snapshots. Do not perform these tests against Production.

## Release decision

| Area | Source review | Runtime |
|---|---|---|
| Enterprise entry | Active membership gate; no explicit enterprise permission gate | Not tested |
| Enterprise shipment overview | Direct table read; relies on RLS; no Enterprise branch visible in sampled policy | Not tested |
| Enterprise approvals UI | Read-only UI, but SELECT privilege missing in Production | Not tested |
| Approval policy/request/event database boundary | **Critical over-broad authenticated DML grants + organization-access-only ALL policies** | Direct exploit not attempted |
| Enterprise documents/integrations | Organization RLS predicates present | Not tested |
| Integration sync runs | Global/null-org branch broadens visibility | Not tested |
| Enterprise audit/automation views | Actor-only audit; service-only automation logs | Not tested |
| Staging Enterprise parity | Authenticated table privileges absent on sampled sources | Blocked |

**Real-user onboarding: NOT APPROVED.** Financial approval governance must be treated as a critical release blocker. No code, schema, policy, grant, data, Auth configuration, user, storage object, provider or deployment was changed. NO EVIDENCE = NO PASS.
