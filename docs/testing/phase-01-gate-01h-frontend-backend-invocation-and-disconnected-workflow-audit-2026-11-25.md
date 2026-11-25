# Phase 01 — Gate 01H: Frontend/backend invocation and disconnected workflow audit
Date: 2026-11-25
Immutable baseline: 72d75a18f985ceb09e468839435ee95700e11e46
Scope: targeted static call-site review. Not an exhaustive AST graph or runtime test.

## Verdict
**PARTIAL / FAIL for workflow-connectivity certification.** Some real frontend call sites are visible in source; important driver/field workflows in the inspected portal are explicitly local-only or disconnected. Dynamic API wrapper names prevent a complete literal call-site inventory in this gate. No browser/API invocation occurred.

## Confirmed call paths
| Surface | Static evidence | Limitation |
|---|---|---|
| Customer quote acceptance | `client.rpc('krim_accept_global_quote', {p_quote_id})`; reads quote/shipment/assignment/member/org data | No runtime response, grants, tenant-negative or idempotency proof |
| Customer shipment workspace | Reads preferences, membership, organizations, shipments, locations, leg plans/legs/items, modes, status history, tracking events and milestones | Full create/modify contract and runtime not proven |
| Public shipment request form | Calls `window.KRIM.api.createShipmentRequest(values)` | Wrapper implementation/endpoint and resulting booking not proven |
| Operations shipment page | Direct PostgREST fetch to `/rest/v1/krim_shipments?select=*&order=created_at.desc&limit=100`; token extracted from localStorage | Tenant filter, RLS, pagination and runtime behaviour not proven |
| Shared app store | Direct reads of `krim_user_app_preferences`, `krim_organization_members` and related organizations; supporting modules reference activity, consent, integrations, exports, offline queue and error reports | Gate 01F Production-client bypass remains P0 |
| Generic API wrapper | Dynamic select/insert/update/upsert/delete/count/RPC and Edge Function invocation methods | Callers pass dynamic table/function names; static literal scan undercounts |

## Explicitly disconnected/local-only
Inspected `core/js/portal.js` states:
- Driver/field task assignment data is not connected in this portal view.
- Field updates are local drafts, not sent to KRIM and not confirmed tracking events.
- Offline queue is browser IndexedDB only; no field-update sync endpoint is configured.
- POD upload is not connected; files are not uploaded or stored.
- Live tracking is not connected in the inspected view.

Separate driver GPS/tracking Edge Function source does not prove this portal invokes it. A caller, authorization, consent, device handling and runtime evidence are still required. Do not represent local drafts as submitted events, POD, assignment or GPS updates.

## Findings
### P0
1. Gate 01F remains open: independent browser clients hard-code Production Supabase configuration. Do not run Staging tests until one fail-closed environment-aware client factory is implemented and runtime project identity proven.
2. Operations page uses direct REST and extracts auth token from localStorage; review tenant scope, RLS, auth lifecycle, pagination and error handling.
3. Field update, POD upload and live tracking are disconnected in inspected portal; keep operational claims disabled until connected and verified.
4. Customer request form calls dynamic `createShipmentRequest`; exact backend contract and persisted booking are unproven.

### P1
- Build complete AST/call graph for all HTML inline scripts and referenced JS/TS, resolving dynamic table/RPC/function names.
- Map each form/button to endpoint, payload, permission, tenant, idempotency, success acknowledgement, retry and audit.
- Trace partner quote submission/capacity, driver assignment/invitation, warehouse QC/pick/handover, customs, finance and notifications.
- Inventory raw REST/fetch, XHR, Realtime, service-worker, IndexedDB/localStorage and third-party SDK calls.
- Distinguish server-confirmed, queued and local-draft UI states.

## Evidence boundary and safety
No literal `functions.invoke()` or `storage.from()` call surfaced in the sampled page modules, but generic wrapper invocation is dynamic and absence in samples is not proof of absence elsewhere. Gate 01G's 20 function directories do not prove deployment or caller wiring. Read-only immutable source review only; no browser, Supabase, Auth, Storage, Edge Function, provider, payment, notification, GPS, webhook or deployment operation. No data changed. Phase 01 IN PROGRESS; Phase 00 FAIL / BLOCKED; runtime testing and general operational onboarding remain NO-GO.
