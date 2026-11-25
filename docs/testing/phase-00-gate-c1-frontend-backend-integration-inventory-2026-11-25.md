# Phase 00 — Gate C1: Frontend-to-backend integration inventory (baseline)

Date: 2026-11-25
Repository: rimjhimkrn-web/logistics-saas
Baseline commit inspected: 72d75a18f985ceb09e468839435ee95700e11e46 (main)
Scope: repository Git tree plus targeted HTML/JS source reads. This is a source inventory, not runtime verification.
Safety: read-only GitHub inspection. No Supabase queries, writes, deployments, provider calls, test accounts or notifications.

## 1. Repository inventory baseline

GitHub recursive Git tree was fetched by immutable commit SHA. Response reported `truncated=false`.
- 2,180 tracked blobs total
- 1,023 HTML files
- 134 JavaScript files
- 377 SQL files
- 20 Supabase Edge Function entrypoints under `supabase/functions/`

HTML workspace page counts (all nested HTML under each top-level workspace directory; includes workflow/staging subfolders and therefore is not a count of unique production routes):
| Workspace | HTML files |
|---|---:|
| Customer | 2 |
| Partner | 19 |
| Driver | 39 |
| Warehouse | 26 |
| Customs | 29 |
| Finance | 24 |
| Operations Control Tower | 28 |
| Enterprise | 14 |
| Admin | 22 |

The root tree also contains separate legacy/alternate admin pages and extensive public, customer-OS, staging, workflow and docs trees. These counts are a navigation/inventory starting point, not proof every file is deployed or linked.

## 2. Backend service surface found

Twenty Edge Function entrypoints:
- Payments: `create-global-razorpay-order`, `create-razorpay-order`, `razorpay-webhook`, `verify-razorpay-payment`, `execute-razorpay-refund`, `krim-global-payment-options`, `krim-payment-capability-status`, `krim-payment-verification-status`, plus legacy Cashfree aliases and `process-payment--`.
- Notifications: `krim-notification-provider-adapter`, `krim-notification-retry-worker`.
- Tracking/driver: `public-shipment-tracking`, `krim-driver-gps-update`, `krim-driver-tracking-session`.
- Platform/admin/AI: `global-admin-control`, `krim-ai`.
- Public intake: `krim-public-contact-inquiry`.
- Remaining tree entrypoints include the Cashfree alias wrappers listed above.

This is a source-tree list only. It does not establish deployed function status, JWT settings, invocation permissions, provider configuration or successful execution.

## 3. Targeted workspace source sampling

Sampled main-branch workspace entry pages:
- Customer: direct reads reference organization membership/organization and shipment/quote tables.
- Partner: direct reads reference organization membership and organization.
- Driver: `app/driver/index.html` is a 501-byte redirect/shell; actual feature modules are separate pages.
- Warehouse: dashboard/task RPC-like identifiers are referenced as table/query targets in the sampled page.
- Customs: direct references include shipment customs, exceptions, broker assignments/licences, document submissions, jurisdiction requirements and organization membership; storage bucket and customs submission/review identifiers also appear in the file.
- Finance: organization membership and permission-check references.
- Operations: shipments, exceptions, tracking events, operations shipment snapshot, warehouse transfers and returns.
- Enterprise: both canonical `krim_shipments` and legacy `shipment_requests` are referenced, indicating a mixed data-model dependency requiring a canonicalization review.
- Admin: `admin-control-center.html` references the `global-admin-control` Edge Function.

Targeted supporting files inspected: `app/enterprise/enterprise-live.js`, `app/customs/secure-workspace.js`, `core/krim-supabase.js`. Their full route-to-RPC/table/storage/function mapping was not exhaustively extracted in this pass.

## 4. Material findings and risks

### C1-01 — Workspace surface is large and duplicated
There are 1,023 HTML files and substantial nested staging/workflow copies. A simple folder count cannot distinguish active routes, legacy pages, staging prototypes, redirects and orphan pages. A manifest must classify every HTML route as active, linked, redirect, legacy, staging-only or unreferenced before page testing.

### C1-02 — Enterprise mixed canonical/legacy shipment sources
The sampled enterprise index references both `krim_shipments` and `shipment_requests`. This is a data-contract risk. Confirm which reads are legacy compatibility vs live source of truth; no migration or data change authorized.

### C1-03 — Integration surface not proven end-to-end
Static source references do not prove that each workspace calls the correct RPC/function, that the endpoint exists in both projects, that the user's role is authorized, or that the call returns the expected schema. Runtime integration tests remain NOT TESTED and are blocked by Staging acceptance.

### C1-04 — Legacy payment provider code remains
Cashfree Edge Function aliases remain tracked alongside Razorpay. This conflicts with the stated Razorpay-only direction and needs a safe usage/deployment/config inventory before retirement. Do not delete or disable without dependency proof and explicit approval.

### C1-05 — Notification surface is incomplete by design evidence
Only two notification-named Edge Function workers were identified in the tree; previous read-only notification audit found no proven generic event dispatcher for all nine workspaces. Mandatory transactional event coverage and delivery evidence remain a release blocker.

## 5. Gate disposition

- Git tree enumeration: PASS (complete response, immutable main commit).
- Workspace page-count baseline: PASS (tree-level count only).
- Edge Function entrypoint inventory: PASS (tree-level count/list).
- Exhaustive HTML-to-RPC/function/table/bucket mapping: NOT TESTED.
- Deployed Edge Function status/config and runtime invocation: NOT TESTED.
- Nine-workspace integration acceptance: BLOCKED by Staging deployment/schema/auth parity and no isolated test identities.
- Gate C1 overall: **PARTIAL PASS / BLOCKED**.

## 6. Next deterministic work

1. Generate a complete page manifest from all HTML files and classify active/staging/legacy/redirect/orphan.
2. Extract static Supabase table/RPC/function/storage references from all active JS/HTML files using a syntax-aware scanner; avoid regex-only claims for template strings or dynamic names.
3. Crosswalk each reference against live read-only Production and Staging catalogues and Edge Function deployment inventory; do not invoke business functions.
4. Only after Staging is accepted, create isolated synthetic identities and execute controlled read-only journey probes, then explicitly approved write-path tests.

No application source, Supabase configuration, data, secrets, users or external providers were changed.
