# Phase 00 — Live RLS, grants and tenant-isolation audit

**Date:** 2026-11-25  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Supabase environments inspected:** Production `ebltviniygljwwseplph`; Staging `qrpcivhdxobiaofppbkl`  
**Method:** Read-only Postgres catalog queries and Supabase Security Advisor results. No test users, API writes, policy changes, migrations, or data mutations.

## Executive result

**Status: BLOCKED — tenant isolation is not release-certified.**

Both environments currently expose the same broad catalog shape: **391 public tables and 6 private-schema tables**. All public tables inspected have RLS enabled; no public table with RLS disabled was found. However, 24 public tables have RLS enabled with no policy. Their current grants are service-role-only (or absent), so the missing policies are not by themselves evidence of public/authenticated data exposure. They still need ownership classification and explicit intended-access documentation. The Security Advisor additionally reports six private-schema tables with RLS enabled and no policies; these are backend-only candidates and should remain inaccessible to client roles.

The material release blocker is **financial approval authorization in Production**: five finance-control tables grant authenticated users INSERT/UPDATE/DELETE, while their policies authorize on broad organization membership rather than finance-specific permission, approval authority, step-up authentication, or separation of duties. Staging has no authenticated table grants for the same critical tables, so it is fail-closed but not a usable parity environment.

## Environment comparison

| Control | Production | Staging | Result |
|---|---:|---:|---|
| Public tables | 391 | 391 | Same catalog count |
| Private-schema tables | 6 | 6 | Same catalog count |
| Public tables with RLS disabled | 0 | 0 | Positive |
| Public tables with RLS enabled and ≥1 policy | 367 | 367 | Positive count only; policy semantics still matter |
| Public tables with RLS enabled and no policy | 24 | 24 | Restricted by current grants; inventory required |
| Critical table authenticated grants | Present on selected reads/writes | None on sampled critical tables | **Parity blocker** |
| Anonymous grants on sampled critical tables | None found | None found | Positive |
| Security-invoker view | `partner_rating_summary` has `security_invoker=true` | Not separately inspected | Production positive |

Counts above are catalog snapshots at audit time. They do not establish behavioral correctness or prove that every table has been tested through the Data API.

## Critical finding

### RLS-01 — Financial approval tables permit broad organization-member writes in Production
**Severity: HIGH / release blocker**

Production grants authenticated users `DELETE, INSERT, UPDATE` on:
- `krim_financial_approval_requests`
- `krim_financial_approval_policies`
- `krim_financial_approval_events`
- `krim_financial_monitoring_alerts`
- `krim_financial_posting_dlq`
- `krim_financial_posting_events`

The sampled policy expressions use `private.krim_has_organization_access(auth.uid(), organization_id)` (or derive the organization through the approval request). This proves organization membership/access, not that the actor holds a finance-specific permission or approval authority. The policy is an `ALL` policy and the grant includes direct writes. The current policy expression does not visibly require AAL2, a finance permission, an independent second approver, or creator/approver separation.

**Risk:** A normal authenticated member of an organization may be able to create or mutate finance-control records directly, bypassing the intended finance workspace workflow and dual-control checks. Exact exploitability for UPDATE/DELETE must be verified against the absence of SELECT grants/policies and the table constraints, but INSERT is directly granted and must be treated as unsafe until narrowed.

**Required remediation (not applied):**
1. Revoke direct authenticated INSERT/UPDATE/DELETE on these workflow/control tables unless a specific operation is intentionally client-writable.
2. Route state transitions through narrowly scoped RPCs or server functions.
3. Require active membership plus the precise finance permission; enforce AAL2 for sensitive approval actions.
4. Enforce maker-checker separation in database logic: creator cannot approve own request; approvals must be independently authorized; state transitions must be immutable/audited.
5. Keep event, posting, DLQ and monitoring writes service-only wherever possible.
6. Add negative tests for ordinary customer, partner, driver, warehouse, customs and enterprise members attempting direct writes.

## Other findings

### RLS-02 — Staging grant parity is incomplete
**Severity: HIGH / staging readiness blocker**

The sampled Staging tables have policies but no authenticated table grants, including:
- `krim_shipments`
- `krim_organizations` and `krim_organization_members`
- `krim_driver_profiles` / `krim_driver_assignments`
- `krim_partner_capabilities` / `krim_partner_service_areas`
- Finance approval tables and ledger tables
- `krim_notification_outbox`
- Customs and warehouse tables in the sample

A policy does not grant table privileges. These routes will fail closed at the Data API even where policies exist. This matches the previously observed Staging grant/parity gap. Do not widen grants indiscriminately; compare the intended access model and apply least-privilege grants only in an isolated approved staging remediation.

### RLS-03 — 24 public tables have no RLS policy
**Severity: MEDIUM; access currently fail-closed by grants**

The following public tables have RLS enabled but no policy in the live Production catalog snapshot:

```
krim_corridor_compliance_controls
krim_corridor_compliance_dossiers
krim_corridor_compliance_events
krim_corridor_compliance_legs
krim_country_operating_packs
krim_country_pack_control_events
krim_country_pack_controls
krim_country_pack_events
krim_inquiry_followups
krim_market_activation_controls
krim_market_activation_events
krim_market_readiness_assessments
krim_market_readiness_events
krim_market_readiness_requirements
krim_market_regulatory_source_events
krim_market_regulatory_sources
krim_partner_compliance_evidence
krim_partner_compliance_reviews
krim_partner_shipment_capacity_commitments
krim_pricing_rate_cards
krim_shipment_leg_custody_transfer_events
krim_shipment_leg_custody_transfers
krim_shipment_leg_dispatch_authorizations
shipment_pod_documents
```

Current Production grants for this list are service-role-only or absent; no `anon` or `authenticated` grants were found. Therefore, this is not being reported as a confirmed public exposure. It is still a maintainability and verification gap: document each table as backend-only or add a deliberate least-privilege policy/grant pair if client access is intended. The six private-schema tables flagged by the Advisor are `krim_ai_rate_limits`, `krim_driver_invitations`, `krim_payment_capabilities`, `krim_payment_providers`, `krim_payment_transactions`, and `krim_public_inquiry_ip_limits`; no client policies should be added merely to silence the lint.

### RLS-04 — Sensitive tables with no policy are currently service-only
**Severity: LOW / intentional-deny verification**

`krim_shipment_leg_custody_transfers`, `krim_shipment_leg_dispatch_authorizations`, and `shipment_pod_documents` have no authenticated or anonymous table grants in the inspected Production catalog; their RLS is enabled. This is a fail-closed boundary, not a reason to add permissive policies. Validate the approved server/RPC paths and retain service-only access.

### RLS-05 — Driver direct table access is narrowly scoped but asymmetric
**Severity: MEDIUM**

Production `krim_driver_profiles` grants authenticated INSERT/SELECT/UPDATE with policies binding `user_id=auth.uid()` and requiring an active driver membership on create/update. `krim_driver_assignments` has an own-user + active-driver-membership SELECT policy but no authenticated table grant. Driver delivery evidence insert checks bind the user to their own active assignment, validate file metadata/path and Storage object ownership. Staging has the policies but no authenticated grants on these sampled tables. Runtime cross-driver and cross-organization tests remain required.

### RLS-06 — Shipment visibility is complex and needs adversarial testing
**Severity: MEDIUM**

The Production `krim_shipments` SELECT policy has explicit branches for:
- active partner assignment,
- customer organization access,
- operations users with shipment.view,
- verified/compliant registered partner organizations with a matching open opportunity and capability coverage.

This is materially better than a generic authenticated read policy, but the policy is complex and depends on helper functions and several live organization/capability fields. It needs negative tests for unrelated customers, unverified partners, expired compliance, wrong lane/mode/capacity, closed opportunities, inactive memberships and revoked assignments. Staging currently lacks the corresponding authenticated table grant.

### RLS-07 — View RLS behavior verified for the sampled view
**Severity: INFO / positive control**

Production `public.partner_rating_summary` is configured with `security_invoker=true`, so it does not silently use the default owner-privilege view behavior. Its definition aggregates partner and shipment rating data. Keep this option in future view migrations and inspect every other exposed view/materialized view independently.

### RLS-08 — RLS is not forced on most tables
**Severity: INFO / configuration note**

Many tables have RLS enabled but not `FORCE ROW LEVEL SECURITY`. Table owners can bypass RLS unless forced; Supabase `service_role` is privileged and bypasses RLS. This is not automatically a defect: server-side service-role access is expected in selected workflows. The required control is that service-role credentials never reach browsers and every privileged server/RPC path independently authenticates and authorizes before access. Review owner-context functions and privileged code together with the earlier SECURITY DEFINER audit.

## Nine-ecosystem boundary review

| Ecosystem | Tables / boundaries sampled | Source-level assessment |
|---|---|---|
| Customer | `krim_shipments`, organizations, notifications, payments, POD | Organization-scoped shipment reads exist; finance and POD boundaries need end-to-end tests |
| Partner | Capabilities, service areas, assignments, compliance evidence | Organization helper scopes reads; backend-only compliance evidence currently denies client access |
| Driver | Driver profiles, assignments, delivery evidence | Own-user and active driver membership checks exist; Staging grants absent |
| Warehouse | Facilities, tasks, receipts, inventory, movements, evidence, transfers | RLS policies exist in sampled tables; cross-facility/organization runtime tests not run |
| Customs | Broker assignments, licenses, document submissions/events, jurisdiction requirements | Shipment-view / accepted-broker compliance-view and AAL2 admin branches present; policies require negative tests |
| Finance | Approval, posting, reconciliation, ledger, payment/revenue tables | **Production direct-write grants and broad organization-access policies are a release blocker** |
| Operations Control Tower | Shipment and organization permission branches | Shipment.view permission used; test cross-organization scope and elevated access |
| Enterprise | Organization-scoped documents, financial workflows, memberships | Organization isolation helper used; finance approval controls need permission/dual-control correction |
| Admin | Admin deny policies and AAL2/admin.platform policy branches | Admin-only paths exist; test AAL1 denial, non-admin denial and organization spoofing |

## Verification still required

These catalog reads do **not** prove runtime tenant isolation. The following tests are NOT RUN and must not be marked PASS:

1. Customer A cannot read/update Customer B shipments, quotes, payment rows, documents or POD.
2. Partner A cannot enumerate Partner B capabilities, assignments, service areas, rates, compliance evidence or shipment data.
3. Driver A cannot read or submit evidence against Driver B's assignment or another organization.
4. Warehouse A cannot read or mutate Warehouse B facility, task, inventory, QC or transfer data.
5. Customs broker A cannot access another broker's unaccepted assignment, license or shipment documents.
6. Ordinary organization member cannot create, alter, approve or delete finance approvals or posting controls without finance permission and required step-up.
7. Approval creator cannot approve own request; a second authorized approver can complete the transition; replay and concurrent approval attempts are rejected.
8. Enterprise user cannot read another enterprise's documents, exports, payment or reconciliation data.
9. Non-admin cannot call admin RPCs; AAL1 admin is denied; organization/user IDs supplied by a caller cannot elevate access.
10. Anonymous role cannot access private rows or any protected table through REST/RPC; views preserve invoker RLS.
11. Removed membership, disabled organization, revoked assignment and stale JWT/session do not preserve access beyond the documented revocation window.
12. Service-role credentials are absent from all public frontend assets and browser network requests.

## Required next actions, in priority order

1. **P0:** Restrict Production finance approval/control direct writes and move sensitive transitions behind permission-checked, step-up and maker-checker server/RPC controls. This needs a reviewed remediation migration and explicit change approval; no changes were made during this audit.
2. **P0:** Establish a repeatable, isolated Staging migration/grant baseline. Do not copy or reset Production data to solve parity.
3. **P1:** Classify all 24 no-policy public tables as backend-only or client-readable; preserve current service-only grants unless there is a reviewed use case.
4. **P1:** Add automated catalog assertions for RLS, grants, policy presence, view `security_invoker`, and privileged function ACLs to CI.
5. **P1:** Run the 12 negative tenant-isolation tests against synthetic users in isolated Staging only.
6. **P2:** Re-audit the full set of SECURITY DEFINER functions together with table policies and function ACLs; a policy cannot protect a table when a callable privileged function bypasses it.

## Evidence and safety statement

- Evidence source: live read-only Postgres catalog queries on Production and Staging; Supabase Security Advisor; results captured during this audit on 2026-11-25.
- The public schema had 391 tables in each environment; six private-schema tables were also catalogued.
- No table data was selected; only system catalogs, policy definitions, grants and view metadata were inspected.
- No INSERT/UPDATE/DELETE, migration, function invocation, test-user creation, payment action, email, notification, Storage upload, deployment, branch merge or production change was performed.
- All runtime negative tests above remain **NOT TESTED**.
