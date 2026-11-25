# Phase 00 — Nine-workspace page-to-backend integration matrix (representative routes)
Date: 2026-11-25
Branch: qa/phase-00-baseline-2026-11-25
Method: inspected exact QA-branch HTML/JavaScript sources for representative canonical routes, followed earlier QA reports for route/RPC/security evidence, and cross-checked relevant Production/Staging catalog and ACL findings. This is a representative integration map, not a claim that every HTML file among the repository's 1,000+ pages has been individually traced.
Safety: no browser login, form submission, RPC invocation, upload, DB write, provider call or Production/Staging configuration change.

## Executive result
The nine workspaces are not uniformly live. Several have meaningful authenticated DB reads or RPC-backed actions, while other pages are explicit previews, withheld registers or paused workflows. The most important finding from this pass is that the canonical Customer booking page has a production-project fallback in its client initialization, even though it loads the shared environment config first. Its actual booking action is explicitly disabled by `BOOKING_CREATION_RELEASED = false`. Do not release or merge this route until the fallback is removed and environment-isolation tests prove fail-closed behavior.

## Route and backend map

| Ecosystem | Representative canonical page(s) | Direct data/backend calls found | State and restrictions |
|---|---|---|---|
| Customer/Shipper | `public/shipper/booking-request.html` (legacy `public/customer/shipment-create.html` redirects here); `public/customer/quote-acceptance.html` is a compatibility redirect | Session; reads `krim_organization_members`, `krim_organizations`, `krim_countries`, `krim_locations`, `krim_markets`, `krim_market_activation_controls`; intended submit RPC `krim_create_global_shipment_idempotent` | Booking is fail-closed: `BOOKING_CREATION_RELEASED=false`, submit button disabled, visible production RPC/trigger defect notice. No booking can be submitted from this page while flag remains false. Client initializer includes hardcoded Production Supabase URL/key fallback if `window.KRIM_SUPABASE` is absent; remove this fallback before release so unknown/misconfigured hosts cannot route to Production. |
| Partner/Carrier | `public/partner/partner-onboarding.html`; `public/partner/services-capabilities.html`; `public/partner/submit-quote.html` | Onboarding RPCs `krim_set_partner_account_mode`, `krim_submit_partner_onboarding_global_multi_v1`; private bucket `krim-partner-verification`; capability RPC `krim_partner_submit_service_capability_v2`; quote RPC `krim_submit_partner_quote`; reads organizations, memberships, opportunities, shipments, currencies, existing quotes | Onboarding checks session, organization and MFA/AAL2 in Staging; evidence upload is used. Quote UI is wired, but authenticated EXECUTE is missing in Staging and the Staging implementation is stricter. No verified commercial partner, active verified capability, approved service area, open opportunity, bid or assignment in prior snapshot. |
| Driver | `public/driver/pod-submission.html` redirects to `app/driver/staging/page-11-proof-of-delivery.html`; 18-page Driver OS navigation | POD page reads session, active driver membership, active organization and `krim_driver_assignments`; no write RPC is called from this page | POD is explicitly paused. Page states no uploads, evidence creation or delivery confirmation. It shows only the signed-in driver's assignment records. GPS tracking was separately found disabled; do not describe the tracking page as live GPS. Fleet register/bind RPCs have Staging authenticated EXECUTE drift from Production. |
| Warehouse | Workspace pages are present in warehouse routes; prior source audit reviewed task/receipt/inventory/QC/handover flow | `krim_warehouse_transition_task`, `krim_warehouse_review_transfer_quality`; underlying receipt/inventory/evidence flows and private `krim-warehouse-evidence` bucket | Source workflow includes row locks, state graph, idempotency, independent QC and evidence checks. Both key warehouse RPCs are authenticated-executable in Production but not Staging. Zero facilities, tasks, receipts, inventory and evidence in both DBs. A prior partner driver/vehicle staging route was explicitly local-browser preview; do not count preview state as persisted backend data. |
| Customs | Protected customs workflow guarded by `app/customs/secure-workspace.js`; `app/customs/staging/cases.html` is preview | Session, MFA AAL2, active `customs` organization membership, `krim_has_permission(..., 'compliance.view')`; underlying case/broker/license/document RPC wrappers reviewed in earlier audit | The secure gate is source-wired. The staging case page explicitly says no sign-in/live customs data/customer records and is navigation/design preview. Private customs implementations and complete Staging ACL parity remain unverified. Zero broker assignments, document submissions and shipment customs rows. |
| Finance | `app/finance/index.html`; `app/finance/partner-settlements.html` | Session, finance organization membership, `krim_has_permission(...,'finance.view')`; page deliberately withholds invoice, settlement and payment-order reads and legacy revenue ledger | Controlled read-only workspace. It renders explicit restricted-data states; no financial writes. Settlement register is temporarily unavailable pending tenant-scope/partner-direct review. This is not a working finance command centre for invoices, payouts or reconciliations. |
| Operations Control Tower | `app/operations/exception-management.html` | Direct reads `krim_exceptions`, `krim_exception_escalations`; acknowledge RPC `krim_acknowledge_exception_escalation`; write permission described as `compliance.manage` | Authenticated organization-scoped operational register. Acknowledgement can be submitted with a factual note; resolution is paused pending backend closure controls. Preparation form is browser-side only and does not save. This is not a notification inbox or proof of on-call alerts. |
| Enterprise | `app/enterprise/approvals.html`; `app/enterprise/enterprise-live.js` | Session; active Enterprise membership; reads `krim_financial_approval_requests` and `krim_financial_approval_events`; enterprise-live.js provides other membership/quote/shipment/audit datasets per earlier source audit | Authenticated organization-scoped approval register and event history; this page does not approve/reject requests and is not an actionable notification inbox. Staging no enterprise organization or test records. |
| Platform Admin | `app/platform-admin/support-desk.html`; `public/admin/siem-audit-logs.html` | Session; invokes `global-admin-control` Edge Function with action overview; requires platform_admin/platform_superadmin role; RPCs `krim_admin_list_support_tickets`, `krim_admin_get_support_ticket_thread`, `krim_admin_reply_support_ticket`, `krim_admin_transition_support_ticket` | Support queue and ticket replies/status changes are wired to admin APIs behind AAL2/admin checks. SIEM page explicitly says verified event stream/hash validation is not connected. This is not proof of complete platform-wide security monitoring or on-call notification. |

## Important source findings

### A. Customer booking — environment fallback and disabled action
The booking page loads `config.js`, but its inline script still defines a hardcoded Production Supabase project URL and publishable key, then initializes with:
`window.KRIM_SUPABASE || window.supabase.createClient(PRODUCTION_URL, PRODUCTION_KEY)`.
If the shared client is absent, the page can fall back to Production even on a non-production host. This contradicts the fail-closed host allowlist architecture established elsewhere on the QA branch. It is a release-blocking environment-isolation defect in this route.

The same source sets `BOOKING_CREATION_RELEASED = false`, disables the submit button, and displays a warning that the production shipment-creation RPC/mandatory corridor-trigger contract needs remediation. This is a positive fail-closed operational guard, but it does not remove the hardcoded Production client fallback used for page reads.

### B. Partner quote — UI exists, Staging caller blocked
The partner quote form directly calls `krim_submit_partner_quote`. Production grants authenticated EXECUTE; Staging does not. Staging's body also adds a current-compliance check. The route is therefore wired but not executable for a signed-in synthetic partner in Staging until an explicit reviewed grant/contract decision.

### C. Driver POD — intentionally no write path
The canonical POD page requires an authenticated driver, exactly one active driver membership and an active organization. It reads only assignments whose `user_id` matches the current session. The UI explicitly pauses POD submission and does not call the POD submit RPC. Do not mistake the backend RPC's existence for a currently enabled driver submission journey.

### D. Finance — deliberate data withholding
The finance page does not attempt broad legacy ledger or cross-entity payment queries. It returns explicit withheld states for invoice, settlement and payment-order datasets and withholds the legacy revenue ledger because it is not organization-scoped. This is a security-conscious restricted view, not completed finance functionality.

### E. Operations — real register, bounded actions
The exception page queries exception and escalation tables and acknowledges an escalation through a dedicated RPC. It disables resolution and clearly says browser preparation does not persist. This is a limited live operational register; it does not establish notification delivery.

## Cross-workspace gaps
1. No common notification inbox is evidenced across the nine workspaces; the earlier outbox/provider audits show routing/provider configuration empty.
2. No synthetic JWT tests have established customer/partner/driver/warehouse/customs/finance/operations/enterprise/admin cross-organization isolation.
3. Staging currently has zero authenticated table privileges across the 79-table workspace/security scope. Workspace UI pages depending on direct table reads cannot run authenticated Staging journeys under the inspected ACLs.
4. Multiple RPC permission drifts remain: partner quote, vehicle/fleet registration/binding, warehouse task transition and transfer-quality review; finance/refund/revenue client functions also differ.
5. Many old public paths are redirects/compatibility pages. Test canonical destinations, preserve query strings, and do not count a redirect page as a functioning workflow.
6. A large HTML source count does not equal unique routes or functioning journeys. This report traces representative routes and uses prior audits; full per-page coverage remains open.

## Required next actions
1. **Fix customer booking environment fallback on QA branch only:** require `window.KRIM_SUPABASE`; if absent, render configuration error and stop. Do not use a hardcoded Production URL/key fallback. Keep booking disabled until the separate atomic RPC/trigger defect is fixed and tested.
2. Generate a full route manifest for all nine workspace directories, deduplicate redirects and identify each canonical page.
3. For every canonical page, record its auth gate, data reads, RPC/Edge Function writes, storage buckets, event outputs, and notification source. Label each as live-read, write-enabled, disabled, preview/local-only, redirect, or unknown.
4. Review Staging grants only after a dedicated sink/isolation test plan. Never copy Production grants wholesale.
5. After explicit approval and isolated fixtures, run browser tests for representative role journeys and negative cross-tenant tests. Capture traces and before/after DB snapshots.
6. Keep real onboarding gated until all critical routes, security isolation, notifications, finance and operational workflows have runtime evidence.

## Evidence boundary
Page findings are based on QA-branch source inspection; environment/function findings rely on the referenced prior Phase 00 reports and read-only catalog snapshots. No runtime browser test was performed. No RPC, Edge Function, upload, provider or payment operation was invoked. No Production or Staging data/configuration was changed.

## Decision
**Nine-workspace page-to-backend wiring: PARTIALLY MAPPED. Full route coverage and runtime verification remain OPEN.**
**Customer booking: PAUSED; remove Production fallback before release.**
**All nine workspaces: NOT VERIFIED for unrestricted onboarding.**
