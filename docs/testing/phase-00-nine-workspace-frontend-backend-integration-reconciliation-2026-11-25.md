# Phase 00 — Nine-Workspace Frontend-to-Backend Integration Reconciliation
Date: 2026-11-25  
Repository: `rimjhimkrn-web/logistics-saas`  
Branch: `qa/phase-00-baseline-2026-11-25`

## Executive status

**PARTIALLY MAPPED — NOT RUNTIME VERIFIED.** This pass re-opened the nine representative canonical pages and extracted direct browser references to RPCs, tables, Edge Functions, Storage and authentication signals. It reconciles those observations with the existing nine-workspace integration matrix. It does not claim complete coverage of every route, shared JavaScript module or dynamically constructed backend call.

No application code, database, auth configuration, storage object, payment provider or notification provider was changed or invoked. This is read-only source inspection plus QA-branch documentation.

## Method and sample

Inspected nine canonical/representative HTML sources on the QA branch:

1. `public/shipper/booking-request.html`
2. `public/partner/submit-quote.html`
3. `app/driver/staging/page-11-proof-of-delivery.html`
4. `app/warehouse/index.html`
5. `app/customs/dashboard.html`
6. `app/finance/index.html`
7. `app/operations/exception-management.html`
8. `app/enterprise/approvals.html`
9. `app/platform-admin/support-desk.html`

Extraction was static: direct `.rpc(...)`, `.from(...)`, `functions.invoke(...)`, `storage.from(...)` string references and simple auth/disabled-state indicators. Shared modules and dynamically composed calls may not appear in these page-level matches.

## Integration matrix

| Workspace | Direct table references found in representative page | RPC / Edge Function references found | Storage references found in this page | Source-level state / caveat |
|---|---|---|---|---|
| Customer / Shipper | `krim_organization_members`, `krim_organizations`, `krim_countries`, `krim_locations`, `krim_markets`, `krim_market_activation_controls` | `krim_create_global_shipment_idempotent` | None | Booking action is explicitly disabled (`BOOKING_CREATION_RELEASED=false`) pending backend release conditions. Existing matrix flags a hardcoded Production fallback in the page initializer: release blocker. |
| Partner / Carrier | `krim_organization_members`, `krim_organizations`, `krim_currencies`, `krim_partner_opportunities`, `krim_shipments`, `krim_partner_quotes` | `krim_submit_partner_quote` | None in quote page; onboarding evidence uses private `krim-partner-verification` bucket on a different route | Quote form is source-wired; Staging authenticated EXECUTE grant drift is recorded in prior matrix. Do not treat form presence as a successful quote journey. |
| Driver | `krim_organization_members`, `krim_organizations`, `krim_driver_assignments` | None | None | POD route is paused/read-only and does not invoke a submission RPC. It reads assignment scope only. GPS and delivery evidence flow are not established by this page. |
| Warehouse | No direct table references in sampled index page | `krim_warehouse_dashboard`, `krim_warehouse_list_tasks` | None in index page; evidence route separately uses Storage and RPCs `krim_warehouse_list_tasks`, `krim_warehouse_list_evidence`, `krim_warehouse_register_evidence` | Dashboard is RPC-backed. Task transitions, QC, receipts and evidence are separate workflows and require their own route-level checks. |
| Customs | `krim_shipment_customs`, `krim_exceptions`, `krim_customs_broker_assignments`, `krim_organization_members` | `krim_has_permission` | None in sampled dashboard | Auth/permission gate signal is present. Full broker/document workflows and runtime access remain unverified; a staging case page is a preview per prior matrix. |
| Finance | `krim_organization_members` | `krim_has_permission` | None | Controlled/withheld view. Invoice, settlement, payment-order and legacy-ledger data are deliberately not exposed on this page according to the prior matrix. Not a complete finance execution workspace. |
| Operations Control Tower | `krim_organization_members`, `krim_exceptions`, `krim_exception_escalations` | `krim_acknowledge_exception_escalation` | None | Exception acknowledgement is wired; resolution and other actions are constrained/paused per prior matrix. This does not prove alerts are delivered to users. |
| Enterprise | `krim_organization_members`, `krim_financial_approval_requests`, `krim_financial_approval_events` | None | None | Approval queue and event history are read paths. The sampled page is not evidence that approval/rejection writes are enabled or safely governed. |
| Platform Admin | No direct table references in sampled page | Edge Function `global-admin-control`; RPCs `krim_admin_list_support_tickets`, `krim_admin_get_support_ticket_thread`, `krim_admin_reply_support_ticket`, `krim_admin_transition_support_ticket` | None | Restricted support desk invokes admin Edge Function and admin RPC family. This is not evidence of complete admin, SIEM or security-monitoring coverage. |

## Key reconciliation findings

### 1. Browser references are heterogeneous
The sampled pages mix direct table reads, RPC-only data access, Edge Function calls and intentionally withheld functionality. A generic “page loads” test will miss authorization and business-logic failures.

### 2. Disabled or preview paths must remain explicitly gated
- Customer booking: disabled pending safe backend release; remove the hardcoded Production fallback before release.
- Partner quote: source-wired, but Staging grant parity must be deliberately reviewed.
- Driver POD: no write operation from the inspected page; do not represent it as live proof-of-delivery.
- Finance: data is intentionally withheld; not ready for settlement/reconciliation operations.
- Operations: acknowledge action is bounded; resolution is not fully released.
- Enterprise: read queue is present; action path is not evidenced by the inspected page.

### 3. Storage and upload routes need separate coverage
The absence of a Storage call on a workspace landing/dashboard page does not mean the workspace has no document flow. Partner verification and warehouse evidence have dedicated upload routes. Customs and driver documents also need page-by-page route tracing. For each upload route, verify bucket privacy, object key scope, MIME/size/signature validation, ownership registration, orphan cleanup, signed URL authorization and audit evidence.

### 4. Notification delivery is not established by these integrations
No sampled page-level direct provider call demonstrates a reliable event-to-delivery pipeline. The prior notification audits remain authoritative: provider configuration, dispatch worker execution, retries/callbacks and nine-workspace mandatory event coverage remain release blockers until runtime evidence exists.

### 5. Staging cannot yet serve as a valid full-workspace E2E environment
Prior Phase 00 database/ACL audits report major Staging parity gaps, including missing authenticated table privileges and missing workspace fixtures. Do not “fix” this by copying Production grants or data. Staging readiness must be established with reviewed schema, least-privilege ACLs, synthetic organizations/users and explicit isolation tests.

## Required evidence for each workspace before pilot

For every canonical route in each workspace, the test record must capture:
- commit SHA, deployment URL, environment and timestamp;
- route canonicalization, redirect chain and loaded scripts/assets;
- signed-in synthetic identity, organization, role, permission and AAL;
- expected and actual table/RPC/Edge Function/Storage calls;
- positive access and negative wrong-role/cross-organization tests;
- expected and actual state transition, with before/after synthetic DB evidence;
- notification event and provider-delivery evidence where applicable;
- browser console/network trace, screenshots and reproducible test ID.

## Status

| Coverage item | Status |
|---|---|
| Nine-workspace representative page source trace | PASS |
| Direct table/RPC/Edge Function extraction for these nine pages | PASS |
| Prior route matrix reconciliation | PASS |
| Every canonical page mapped | IN PROGRESS |
| Shared/dynamic JS backend calls fully mapped | NOT TESTED |
| Storage upload/download routes fully mapped | IN PROGRESS |
| Runtime positive/negative authorization | NOT TESTED |
| End-to-end business journeys | NOT TESTED |
| Notification delivery per workspace | NOT TESTED |
| Staging E2E readiness | BLOCKED by known environment/ACL/fixture gaps |

**Decision:** no unrestricted customer or partner onboarding release from this evidence. Keep booking and other paused paths gated. Continue the source inventory by tracing dedicated upload/document routes and shared JavaScript modules, then proceed to controlled Staging runtime tests only after environment isolation and ACL readiness are proven.
