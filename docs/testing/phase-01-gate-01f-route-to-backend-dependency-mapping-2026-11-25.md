# Phase 01 — Gate 01F: Route-to-backend dependency mapping

Date: 2026-11-25
Immutable source baseline: 72d75a18f985ceb09e468839435ee95700e11e46
QA branch: qa/phase-00-baseline-2026-11-25
Scope: targeted static mapping from representative route families to client modules, Supabase tables/RPCs, Storage/Edge Function signals and external integrations. No runtime requests, SQL, provider calls or live operations.

## 1. Verdict

**FAIL / BLOCKED FOR ENVIRONMENT AND BACKEND-CONNECTIVITY CERTIFICATION.** A shared Supabase client and data-access layer exist, and representative customer, warehouse, finance and customs surfaces reference real backend objects. However, multiple independent client initializers bypass the environment-aware configuration and hard-code the Production Supabase URL/key. This creates a material risk that preview/staging pages can touch Production. A full route-by-route dependency graph and deployed runtime proof are not established. This gate is static source evidence only.

## 2. Highest-priority finding — P0 environment isolation bypass

The canonical root config.js detects preview/staging hosts and selects the Staging Supabase project for non-production environments. But independent modules in the immutable baseline initialize Supabase directly with the Production project URL and publishable key:
- public/app/app-store.js — hard-coded Production URL/key; reads/writes krim_user_app_preferences, krim_organization_members, krim_user_activity_events.
- public/app/backend-modules.js — hard-coded Production URL/key; accesses account preferences, activity events, consent events, integrations, export requests, offline queue items and client error reports.
- platform/krim-supabase.js — hard-coded Production URL/key in a separate client initializer.
- core/krim-supabase.js — initializes from legacy KRIM_CONFIG.SUPABASE_URL / SUPABASE_ANON_KEY rather than the canonical config.js globals; exact legacy configuration compatibility is not proven.

These initializers are separate from config.js and do not consume window.KRIM_SUPABASE. Therefore hostname-based staging selection in config.js does not protect these code paths. If their pages/scripts execute on staging, requests may be sent to Production. This is a source-level hazard, not proof that a Production write occurred. **Do not use these pages for Staging tests or create synthetic accounts until all client initializers fail closed and are proven to target the isolated Staging project.** No request was made and no Production data was changed during this audit.

Required remediation: one shared environment-aware client factory; remove all independent project URLs/keys from page modules; assert expected Supabase project ref against host/environment at initialization; abort with visible error on mismatch; prohibit Production-derived DDL/bootstrap or test data against the wrong project; CI scan must fail if an unapproved project ref or direct createClient call appears outside the factory.

## 3. Representative route-to-backend map

| Route / ecosystem | Source client / dependency | Observed tables / RPCs / external services | Evidence status and limitation |
|---|---|---|---|
| Public root / customer enquiry | config.js + core/js/site.js + KRIM API | Shared Supabase client; createShipmentRequest() via API wrapper; tracking form explicitly says live tracking not connected | Static source only; exact target RPC/table for all calls needs API call-site tracing |
| Customer workspace | app/customer/index.html; public/customer-os/assets/* | krim_organization_members, krim_organizations, krim_shipments, krim_quotes, krim_locations, krim_shipment_leg_plans, krim_shipment_legs, krim_shipment_leg_plan_items, krim_transport_modes, krim_shipment_status_history, krim_tracking_events, krim_shipment_milestones; krim_accept_global_quote RPC; OpenStreetMap link | Source refs exist; row policies, exact tenant scope, writes, storage and deployed execution not verified |
| Partner workspace | app/partner/index.html + shared Supabase CDN/config | krim_organization_members, krim_organizations in inspected gateway; further partner workflows use other pages/modules | Gateway source alone does not establish operational partner data flow; complete route/page mapping open |
| Driver / field | app/driver/index.html redirects to dashboard.html; core/js/portal.js field view | Shared portal JS; field queue stored in browser IndexedDB; no connected event/POD API in inspected field workflow | Explicitly local draft only; no verified assignment, event, POD, GPS or driver API path in inspected portal |
| Warehouse | app/warehouse/index.html | krim_warehouse_dashboard and krim_warehouse_list_tasks RPCs; Supabase CDN + config.js; shared brand/language assets | RPC presence only; grants, table access, allocation/stock invariants and runtime results not tested |
| Customs | app/customs/secure-workspace.js | krim_organization_members table; krim_has_permission RPC | Auth/permission bootstrap references only; case, declaration, document, broker, tariff and authority-release dependencies not fully mapped |
| Finance | app/finance/index.html | krim_organization_members table; krim_has_permission RPC; additional page modules not exhaustively enumerated | Permission gate references only; payment/ledger/refund/payout runtime contract not verified |
| Enterprise / generic app shell | public/app/app-store.js; public/app/app-runtime.js | krim_user_app_preferences, krim_organization_members, krim_organizations, krim_user_activity_events; client-side store; no confirmed server permission list in store | App shell currently uses hard-coded Production client; frontend permission state is empty in inspected initialization and presentation-only |
| Account / preferences / privacy modules | public/app/backend-modules.js | krim_user_activity_events, krim_user_app_preferences, krim_user_consent_events, krim_integrations, krim_data_export_requests, krim_offline_queue_items, krim_client_error_reports | Hard-coded Production client; exact per-page invocation and RLS outcomes untested |
| Platform admin | representative staging/admin HTML shells | Supabase/config script references; underlying per-page RPC/table mapping not fully extracted | No admin RPC/Edge Function authorization proof |
| Notifications | public/app/backend-modules.js and shared notification UI | Consent/activity tables referenced; notification delivery backend not mapped in this sample | In-app/email/push/Telegram delivery and retries not proven |
| Storage / documents | POD and document route families | No storage.from() bucket reference surfaced in the sampled JS modules | Not evidence of no Storage use; full Storage call-site scan remains open |
| Edge Functions | sampled client modules | No functions.invoke() calls surfaced in the sampled files | Not evidence of no direct fetch/function calls elsewhere; global call-site inventory remains open |
| Payments | finance/customer payment routes | No checkout/provider call in sampled route modules | Payment functions and webhooks are separately audited in Phase 00; no payment runtime call made |

## 4. Shared API/data-access layer observations

platform/krim-api.js wraps generic Supabase select/insert/update/upsert/delete and RPC operations. It requires a table name for generic operations and requires at least one filter for update/delete. This centralization helps standardize access but does not itself enforce a table allow-list, tenant scope or permission boundary; these must be enforced by backend RLS/RPC and higher-level contracts. Dynamic table/RPC names mean simple literal-string scans undercount actual dependencies.

config.js provides environment detection and a canonical KRIM_ROUTES registry. However, the independent hard-coded clients listed above bypass that environment-aware client. The legacy core/krim-supabase.js expects KRIM_CONFIG settings and is a separate configuration path whose page inclusion and runtime compatibility require inventory.

## 5. Cross-ecosystem P0/P1 gaps

### P0
1. Remove the independent Production Supabase client initializers from app-store, backend-modules and platform/krim-supabase; migrate to the one fail-closed environment-aware factory.
2. Add an automated source/CI guard for direct Supabase URLs, createClient calls, unexpected project refs and staging-host/production-project combinations.
3. Prove actual project identity at runtime on every staging route before any synthetic account, test write or browser test.
4. Do not rely on visible preview banners or disabled-auth flags as isolation controls.

### P1
1. Complete route-level data dependency mapping across all deployable HTML pages, including dynamic imports, inline scripts, forms, fetch, RPC, Edge Function, Storage, Realtime and third-party integrations.
2. Cross-reference every referenced table/RPC/function/bucket with grants, RLS, tenant scope and role/permission catalog.
3. Identify all generic API wrapper call sites and resolve dynamic table/RPC names to canonical contracts.
4. Map customer/partner/driver/warehouse/customs/finance/operations/enterprise/admin dependencies separately; distinguish read, write, privileged and public operations.
5. Trace notification, payment, document/POD, tracking/GPS and external provider flows end-to-end after safe Staging isolation is proven.
6. Confirm no service-role key or privileged secret is present in browser bundles; only publishable client keys may be public and still require RLS.

## 6. Safety and release disposition

Read-only immutable GitHub source inspection only. No Supabase SQL/RPC, Auth, database query, Storage, Edge Function, provider, webhook, notification, payment, browser or deployment operations were performed. No records or data were changed. Phase 01 remains IN PROGRESS. Phase 00 remains FAIL / BLOCKED. Staging is not cleared for synthetic users or runtime tests until the P0 environment-client bypass is fixed and independently verified. General customer/partner/driver onboarding remains NO-GO.
