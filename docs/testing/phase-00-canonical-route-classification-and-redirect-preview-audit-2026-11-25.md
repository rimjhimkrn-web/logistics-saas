# Phase 00 — Canonical route classification and redirect/preview audit
Date: 2026-11-25
Branch: qa/phase-00-baseline-2026-11-25
Scope: all 27 keys in `window.KRIM_ROUTES`, route destination existence and source-level classification of canonical destinations plus selected legacy aliases.
Method: read-only GitHub source inspection on the QA branch. No browser navigation, auth session, form submission, RPC invocation, storage upload, provider call or database mutation.

## Executive result
- Canonical route registry: 27 keys.
- Unique destination files: 25 (the customs queue and customs home keys share `app/customs/index.html`; operations control and operations home share `app/operations/index.html`).
- Every canonical target existed in the previously captured complete recursive Git tree (2,396 entries, `truncated=false`) and was fetched in this pass.
- Source classification shows a mix of real authenticated data pages, deliberately restricted workflows, public guidance pages and redirect/alias destinations.
- Route existence is not functional acceptance. No runtime route was exercised.

## Canonical registry classification

| Registry key | Destination | Classification | Source evidence / caveat |
|---|---|---|---|
| home | `index.html` | Public marketing/home | Full marketing HTML; not an authenticated workspace. |
| access | `auth/access.html` | Authentication/access shell | Exists; this page's runtime access decision was not browser-tested. |
| login | `auth/login.html` | Authentication workflow | Source includes session, membership and organization routing; partner/driver/warehouse provisioning RPC references; AAL2 enforcement for privileged access. Runtime sign-in not tested. |
| customer | `app/customer/index.html` | Authenticated workspace landing | Requires session and active organization membership; rejects platform admin in customer workspace; reads shipment and quote counts scoped to customer organization IDs. |
| partner | `app/partner/index.html` | Authenticated workspace with Staging preview mode | Source explicitly says Staging keeps page read-only and skips authentication/backend access; non-preview path checks session, memberships and organizations. Do not treat preview as signed-in partner acceptance. |
| driver | `app/driver/index.html` | Redirect/alias | Meta refresh and script redirect to `dashboard.html`. Test destination, not alias as an independent workflow. |
| warehouse | `app/warehouse/index.html` | Workspace dashboard shell | Loads shared Supabase config and dashboard content; linked task routes carry the actual task/RPC operations. No full dashboard runtime check. |
| customs | `app/customs/index.html` | Authenticated customs workspace | Source loads session and routes unauthenticated users to customs login; customs document form and secure workspace JS are connected. Earlier audit identified AAL2 + active customs membership + compliance.view gate; private function implementation/parity remains incomplete. |
| finance | `app/finance/index.html` | Authenticated restricted read-only workspace | Explicit read-only language; checks finance membership and `finance.view`; sensitive invoice/settlement/payment data are withheld per earlier audit. |
| operations | `app/operations/index.html` | Authenticated operational control centre | Reads shipments, exceptions, tracking events, warehouse transfers and returns; calls `krim_operations_list_shipment_snapshots`. This is not proof of universal alerts or complete resolution workflow. |
| enterprise | `app/enterprise/index.html` | Authenticated workspace with preview fallback | Reads shipment data and checks enterprise memberships. On staging hostname, unauthenticated users enter preview state instead of a signed-in workspace. Separate approval and shipment pages have distinct read scopes. |
| platformAdmin | `app/platform-admin/index.html` | Privileged admin shell | Restricted admin control-centre source. Actual admin session, AAL2, organization scoping and every action must be tested through dedicated gates; shell existence is not authorization proof. |
| customerBooking | `public/shipper/booking-request.html` | Authenticated booking form; write paused | Session/org/market preflight and intended idempotent shipment RPC; submit disabled by `BOOKING_CREATION_RELEASED=false`. Hardcoded Production fallback remains a critical environment-isolation defect. |
| customerQuoteRequest | `public/customer/quote-request.html` | Authenticated quote/shipment read page | Reads active customer memberships, organizations, shipments and quotes. Full quote-request write journey not established by this route inspection. |
| quoteResult | `public/quote-result.html` | Payment-guidance redirect | Page says KRIM freight checkout disabled and partner-direct payments only; immediately redirects to `public/shipper/payment-checkout.html`. Not a live quote-result or payment execution page. |
| customerShipments | `public/customer-os/customer-services/shipment-list.html` | Authenticated customer shipment register | Verifies session, memberships and customer orgs; reads shipment rows and location catalogue. No runtime data or tenant-isolation test. |
| tracking | `public/tracking.html` | Redirect/alias | Redirects to root `tracking.html`, preserving query/hash. Root tracking implementation was not exercised in this pass. |
| partnerOnboarding | `public/partner/partner-onboarding.html` | Mixed registered flow + local preview | Staging review mode explicitly permits pathway exploration and local file selection only; no upload. Non-preview path reads countries/membership/org, uses private partner-verification storage, checks AAL2 and calls account-mode/onboarding RPCs. Not a real completed verification case. |
| partnerMarketplace | `public/partner/load-marketplace.html` | Redirect/legacy sample page | Explicitly says older page displayed fictional sample loads and redirects to `available-loads.html`, the live-data-only exchange. Do not count alias as marketplace implementation. |
| driverAssignments | `app/driver/module-01-assignment-inbox.html` | Redirect/alias | Redirects to `app/driver/staging/page-02-assignment-inbox.html`. Destination's name includes staging; must inspect its environment and data behavior before accepting it as a production driver inbox. |
| warehouseInbound | `public/warehouse/inbound-receiving.html` | Authenticated task workflow | Session required; reads leg options, calls `krim_warehouse_list_tasks`, has task form and transition RPC flow. Staging authenticated EXECUTE drift on warehouse transition RPCs blocks signed-in Staging journey. |
| warehouseInventory | `public/warehouse/inventory-ledger.html` | Authenticated read-only ledger | Calls `krim_warehouse_dashboard`; reads warehouse inventory, facilities and inventory movements; explicitly says screen cannot post stock changes. |
| customsQueue | `app/customs/index.html` | Duplicate registry alias | Same destination as `customs`; not a separate queue route or independent implementation. |
| financeInvoices | `app/finance/invoicing.html` | Navigation shell / child route | Source is a very short shell linking finance modules; it is not evidence that invoice creation, posting, delivery or payment reconciliation works. |
| operationsControl | `app/operations/index.html` | Duplicate registry alias | Same destination as `operations`; not a separate control-tower implementation. |
| enterpriseShipments | `app/enterprise/shipments.html` | Authenticated shipment register with preview mode | Reads enterprise membership and `krim_shipments`; staging host can enter local preview with empty records without authentication. Preview must never be counted as persisted shipment data. |
| support | `public/support/help-centre.html` | Public support/help centre | Public help content; separate support-ticket flow is elsewhere. This page alone does not prove a ticket was stored or delivered to an agent. |

## Redirect and compatibility findings
1. `app/driver/index.html` → `app/driver/dashboard.html`.
2. `app/driver/module-01-assignment-inbox.html` → `app/driver/staging/page-02-assignment-inbox.html`.
3. `public/partner/load-marketplace.html` → `public/partner/available-loads.html`; source expressly retires the old fictional sample-load page.
4. `public/tracking.html` → root `tracking.html`.
5. `public/quote-result.html` → `public/shipper/payment-checkout.html`; destination is partner-direct payment guidance and does not initiate KRIM freight checkout.
6. Customs and operations each have duplicate registry keys pointing to one destination. They are aliases, not separate workflows.

## Preview/local-only and restricted paths
- Partner workspace index has a Staging read-only mode that skips authentication and backend access.
- Partner onboarding review mode supports local file selection; it explicitly says no upload occurs.
- Enterprise shipment page supports an unauthenticated Staging preview with an empty local record set.
- Customer booking submission is deliberately disabled pending the booking RPC/mandatory corridor-trigger remediation.
- Driver POD is explicitly paused in its canonical page; no file upload or POD write path is available there.
- Finance is intentionally restricted/read-only; invoice/settlement/payment datasets are withheld.
- Warehouse inventory ledger is read-only; stock movement must occur through controlled tasks.
- Operations exception resolution is paused, although acknowledgement is wired.
- Customs/finance/admin pages may have protected source-level gates, but runtime role and AAL2 behavior has not been verified.

## Release blockers and audit priorities
| Priority | Finding | Required action |
|---|---|---|
| Critical | Customer booking page hardcodes Production URL/key as fallback if shared client missing | QA-only code correction: require the shared, hostname-verified client and fail closed if absent. No deploy before explicit approval. |
| Critical | Staging preview pages can look like functional workspace pages while skipping auth or showing local-only data | Add unmistakable preview banners and keep preview state out of acceptance evidence; use a protected authenticated staging host. |
| High | Driver assignment canonical route redirects to a `staging/` destination | Determine whether the destination is genuinely production-ready, environment-neutral and auth-gated; do not infer from the route name. |
| High | Finance invoice route is only a navigation shell in inspected source | Trace each finance child route to secure DB/RPC and partner-direct commercial model; refund/invoice/reconciliation remain untested. |
| High | Partner marketplace legacy alias has fictional sample content and redirects | Verify only the destination's real data and authorization path; do not use legacy page screenshots as proof of live opportunities. |
| High | Redirect aliases and duplicate route keys can inflate apparent route coverage | Normalize route manifest to unique destinations and mark alias chains explicitly. |
| High | Tracking public alias points to root tracking implementation | Inspect root tracking auth/share-token behavior, event freshness and distinction between event history and live GPS. |
| High | Static route existence does not prove browser reachability or runtime behavior | Establish protected authenticated staging and run browser tests after isolated fixtures/test sink exist. |

## Evidence boundary and safety
- All 27 registry keys were parsed from QA-branch `config.js`; there are 25 unique destination files.
- Source inspection confirms file content and source-level branches only. It does not establish that any deployed URL is reachable, that a signed-in role can complete the action, or that a database write succeeds.
- No auth users or test records were created. No browser or RPC execution, storage upload, notification, payment, email, Telegram, webhook or Production/Staging configuration change occurred.
- Do not use the GitHub Pages production host for synthetic mutations. The current config routes it to Production.
- Do not treat the current `krim-staging.pages.dev` preview hostname as a validated authenticated E2E host until deployment origin and host mapping are proven.

## Verdict
**Canonical route existence: PASS (file existence only).**
**Canonical route classification: SOURCE-MAPPED for 27 keys / 25 unique destinations.**
**Redirect/preview/local-only paths: identified and recorded.**
**Runtime route reachability, authentication, RLS and workflow execution: NOT TESTED.**
**Unrestricted onboarding: NOT APPROVED.**
