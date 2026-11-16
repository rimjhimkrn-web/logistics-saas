# KRIM Nine-Workspace Live Database Authorization Catalog Audit
**Date:** 16 November 2026  
**Project:** `ebltviniygljwwseplph`  
**Method:** Read-only PostgreSQL catalog inspection via Supabase SQL. No table writes, DDL, policy changes, RPC calls or user impersonation tests.

## Executive summary
The current catalog baseline is materially better than an unprotected database: all 391 ordinary public tables have RLS enabled, no public table has RLS disabled, and none of the 24 RLS-enabled tables without policies grants anon/authenticated table privileges. No public SECURITY DEFINER function is executable by anon.

However, this is **not a nine-workspace authorization certification**. The database contains 332 SECURITY DEFINER functions, 150 executable by authenticated users, and 42 tables where authenticated has all four table-level DML privileges. Several sensitive finance and revenue tables are among them. These grants must be assessed together with their RLS policies and actual workflow requirements; catalog presence alone neither proves exploitability nor establishes safe workflow enforcement.

## 1. Live catalog baseline

| Measure | Read-only result |
|---|---:|
| Public relations (tables + view) | 392 |
| Ordinary public tables | 391 |
| RLS enabled tables | 391 |
| RLS forced tables | 35 |
| Tables with RLS disabled | 0 |
| RLS-enabled tables with no policies | 24 |
| No-policy tables with anon/authenticated DML privilege | 0 |
| Public tables with anon INSERT/UPDATE/DELETE privilege | 0 |
| Tables with authenticated INSERT + UPDATE + DELETE privileges | 42 |
| Public functions/procedures | 364 |
| SECURITY DEFINER functions | 332 |
| SECURITY DEFINER functions executable by authenticated | 150 |
| SECURITY DEFINER functions executable by anon | 0 |
| Public views | 1 |

The one public view, `partner_rating_summary`, has `security_invoker=true`.

### Interpretation
- RLS is enabled across the public table set. This is a strong baseline, but policies may still be too broad, incomplete, inconsistent or bypassed by privileged functions.
- The 24 no-policy tables currently have no anon/authenticated SELECT or DML privilege in the inspected catalog. This is not an immediate Data API exposure finding; preserve the grants boundary.
- No anon-executable SECURITY DEFINER public function was found.
- Authenticated function execution is a separate permission surface from direct table grants. Each callable function still requires body-level review for tenant binding, role/permission checks, AAL2 where needed, actor integrity, idempotency and state validation.
- Table-level DML grants and RLS policies must be reviewed together. A row policy that checks organization membership does not necessarily enforce maker-checker approval or force all writes through a controlled RPC.

## 2. Workspace identity and role tables
The inspected policy catalog showed:

| Table | Authenticated access | Policy |
|---|---|---|
| `krim_organization_members` | SELECT only | User can view rows where `user_id = auth.uid()`. |
| `krim_user_role_assignments` | SELECT only | User can view own role assignment rows. |
| `user_roles` | SELECT only | User can view own role row. |
| `krim_role_permissions` | SELECT only | Platform-admin permission check against organization ID 1. |
| `krim_security_permissions` | SELECT only | Platform-admin permission check against organization ID 1. |

These policies support self-scoped identity reads and restrict role/permission catalogue reads. They do **not** by themselves prove that every application RPC checks the current organization membership, workspace type, resource ownership and specific permission on each mutation. The fixed organization ID 1 in permission catalogue policies should be reviewed against the canonical platform-organization model.

No user impersonation, JWT alteration, cross-tenant query or RPC mutation test was run.

## 3. Elevated SECURITY DEFINER surface
- 332 of 364 public functions are SECURITY DEFINER.
- 150 SECURITY DEFINER functions are executable by authenticated users.
- None are executable by anon in the inspected effective privilege check.
- All sampled SECURITY DEFINER functions had a function-level `search_path` setting.
- Eight authenticated-executable SECURITY DEFINER functions have `public` first in their configured search path:
  - `krim_admin_list_partner_verification_cases`
  - `krim_admin_schedule_inquiry_followup`
  - `krim_admin_set_global_rate_card_status`
  - `krim_create_global_shipment_from_places`
  - `krim_create_partner_opportunity`
  - `krim_create_tariff_quote`
  - `krim_record_operational_milestone`
  - `krim_submit_customer_service_request`

A configured search path is a positive control, but placing `public` first warrants review for untrusted object shadowing and unqualified object references. This catalog observation is not proof of an exploit. Inspect each function body, object qualification, EXECUTE grant source and authorization branch before proposing changes.

## 4. Authenticated direct-DML review candidates
42 public tables grant authenticated INSERT, UPDATE and DELETE privileges. The set includes legacy/user-owned operational tables and organization-scoped KRIM tables. The inspected RLS policies on several sensitive tables use organization-access predicates.

High-priority candidates for workflow-bypass review include:
- `krim_financial_posting_events`
- `krim_financial_posting_dlq`
- `krim_revenue_allocation_rules`
- `krim_revenue_allocation_runs`
- `krim_revenue_allocations`
- `krim_shipment_compliance_gates`
- `krim_customer_consents`
- `krim_partner_onboarding_checklists`

For example, the posting events and DLQ tables have authenticated all-operation grants and a single organization-scoped ALL policy. Revenue allocation tables also have authenticated all-operation grants and organization-scoped ALL policies. Whether these are unsafe depends on intended direct client writes; for authoritative financial posting and allocation, direct table mutation may bypass state-machine, maker-checker, immutable-event and service-role-only controls. Finance remains deferred, so do not enable or exercise these paths.

The compliance-gates table's organization-scoped ALL policy also needs a separate integrity review: an organization member's ability to insert/update a compliance decision must not be confused with independent compliance approval. Existing audit evidence also found no configured compliance rules/check rows in the readiness gate baseline.

## 5. Nine-workspace implications

| Workspace | Catalog-level conclusion | Remaining proof required |
|---|---|---|
| Customer/Shipper | Organization membership and customer data policies exist. | Two-customer tenant isolation, shipment/quote ownership, consent and private-document boundaries. |
| Partner/Carrier | Partner and organization-scoped tables/policies exist. | Verified partner identity, current capability, service area, assignment ownership, resource and evidence isolation. |
| Driver | Driver-specific SECURITY DEFINER RPCs exist and are authenticated-callable. | Assignment ownership, licence/vehicle validity, actor identity, location privacy, AAL2 where sensitive. |
| Warehouse | Warehouse RPC surface and RLS exist. | Facility assignment, stock atomicity, reserved inventory protection, independent QC and evidence access. |
| Customs | Customs and regulatory tables are RLS-protected. | Broker licence/jurisdiction, case assignment, independent review and authority-clearance distinction. |
| Finance | Sensitive posting/revenue tables have authenticated direct DML grants. | Workflow bypass analysis, immutable ledger, service-only posting, maker-checker and final-phase authorization. |
| Operations Control Tower | Operations RPC surface exists. | Least-privilege shipment snapshots, dispatch gates, reason-coded transitions and cross-tenant privacy. |
| Enterprise | Organization-scoped data policies exist. | Two-enterprise isolation across reports, documents, approvals, integrations and analytics. |
| Admin/Platform Admin | Numerous authenticated SECURITY DEFINER admin functions exist. | Per-function permission/AAL2 checks, independent reviewer, platform scope, audit and no self-approval. |

## 6. Required next read-only review
1. Extract full definitions for all 150 authenticated-executable SECURITY DEFINER functions, then prioritize the 8 public-first search-path functions and high-impact admin, shipment, partner, driver, warehouse, customs and finance functions.
2. Compare each function's body against the intended permission code, organization binding, active membership, workspace type, AAL2, actor derivation, state transition and idempotency.
3. Inspect all 42 authenticated all-DML tables, separating intended user-owned CRUD from privileged workflow records. Identify whether any direct grant is unnecessary.
4. Review the exact policies and grants on shipment, partner assignment, driver assignment, capacity, warehouse inventory, customs case, POD and support data.
5. Build nine-workspace positive/negative test fixtures in staging. Do not impersonate users or mutate production data.
6. Only after the migration-history crosswalk and sanitized schema manifest are complete, propose controlled remediation migrations for explicit review.

## 7. Change-control and limitations
- This was a read-only catalog audit; no business function was invoked.
- Catalog privileges show effective role access, but do not prove application UI behavior or the correctness of function bodies.
- No live cross-tenant test was run. No user JWT or AAL claims were forged.
- Do not modify production DDL, policies, grants, triggers or functions while migration history remains unreconciled.
- Do not enable finance collection or test real financial posting. The user's own-fee financial phase remains last.
- Supabase's current Data API exposure behavior separates table grants from RLS; preserve both layers during review.

## 8. Release decision
**NO-GO for nine-workspace authorization certification.** RLS coverage and anon privilege posture are positive, but the authenticated SECURITY DEFINER and direct-DML surfaces require function-body and workflow-integrity review, followed by staging tests. No production remediation is included in this report.
