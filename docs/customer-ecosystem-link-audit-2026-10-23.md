# KRIM Customer Ecosystem — Link and Duplicate Audit
Date: 2026-10-23
Repository: `rimjhimkrn-web/logistics-saas`

## Approved canonical routes

The user approved one canonical page for each route group and permanent deletion of all listed alternatives. These deletions are committed on `main`.

| Workflow | Canonical page retained | Duplicate pages permanently deleted |
|---|---|---|
| Shipment List | `public/customer-os/customer-services/shipment-list.html` | `public/customer/shipment-list.html`; `public/shipments/shipment-list.html` |
| Quote Comparison | `public/shipper/quote-comparison.html` | `public/customer-os/customer-services/quote-comparison.html`; `public/customer-os/quotes-pricing/quote-comparison.html`; `public/customer-os/shipper-services/quote-comparison.html`; `public/customer/quote-comparison.html`; `public/quotes/quote-comparison.html` |
| Quote Request | `public/customer/quote-request.html` | `public/customer-os/customer-services/quote-request.html`; `public/customer-os/quotes-pricing/quote-request.html`; `public/quotes/quote-request.html` |
| Payment Checkout | `public/shipper/payment-checkout.html` | `public/customer-os/shipper-services/payment-checkout.html`; `public/finance/payment-checkout.html` |

## Preserved functionality and link repairs

- The canonical Customer OS Shipment List remains an organization-scoped Supabase shipment register. It reads real `krim_shipments` records, scopes results by active customer/shipper/enterprise organization memberships, and provides search, status filtering and shipment navigation.
- Repaired the Customer OS directory links and Customer OS workflow links to point to the retained quote-comparison, quote-request, shipment-list and payment-checkout routes.
- Repaired legacy Customer, Quotes and Shipments navigation links that pointed to the deleted routes.
- Updated the production smoke test to require the approved canonical routes instead of deleted aliases.
- The homepage and customer signup/sign-in entry flow were not intentionally changed by this cleanup.

## Automated verification

- GitHub Actions production smoke check passed on commit `03de29d7bae7d17bdbac7ccd166256fc7cf86b5d`.
- The check includes required production path checks, inline JavaScript syntax checks, and local-link/path-prefix validation for the Customer OS HTML pages.
- Run: https://github.com/rimjhimkrn-web/logistics-saas/actions/runs/39905090515
- This automated source-level check is not a browser-based end-to-end test of authentication, shipment creation, live quote acceptance, payment settlement, partner assignment, delivery evidence, or refunds.

## Remaining verification gates

- Confirm the latest GitHub Pages deployment completes successfully before treating these changes as live.
- Browser-test the customer lifecycle end-to-end: homepage → signup/sign-in → Customer Workspace → shipment creation → partner opportunity → quote → acceptance → payment verification → assignment → delivery proof → settlement.
- A passing local-link smoke test does not by itself prove every transactional action works in production.


## Customer OS 404 and access separation follow-up — 2026-10-23

- Current repository inventory: **798 HTML files overall**, **55 HTML files in `public/customer-os/`**, consisting of **53 feature-route HTML files**, the public journey portal (`index.html`), and `INTEGRATION-MANIFEST.html`.
- Fixed stale shared-navigation targets in `public/customer-os/assets/customer-workflow.js`: quote comparison now points to `public/shipper/quote-comparison.html`, shipment list to `public/customer-os/customer-services/shipment-list.html`, and payment checkout to `public/shipper/payment-checkout.html`. The stale links were inserted dynamically by JavaScript and were not caught by a scan of literal HTML links.
- Replaced the public all-pages catalogue with a guided customer portal. Its public flow is shipment creation → quote request → quote comparison → checkout → shipment register → tracking/delivery evidence → invoices/claims/support.
- Added `public/admin/customer-ecosystem-os.html`, a no-index inventory using the existing privileged-session guard, for founder/admin audit and rebuild planning. It is not linked from the public customer portal.
- Expanded `scripts/krim-production-smoke.mjs` to verify the canonical routes used by shared Customer OS navigation and fail if the deleted aliases are reintroduced.

### Access-control limitation — do not treat this as a private static site

GitHub Pages serves static HTML and source files publicly. A client-side guard can redirect ordinary visitors away from the rendered directory, but cannot make the underlying HTML source or individual customer routes truly private. The new directory is therefore a guarded administrative interface, **not a confidentiality boundary**. Genuine admin-only confidentiality for the directory itself requires authenticated server-side delivery. Supabase RLS and server-side authorization must protect customer records and transactional actions regardless of whether links are visible.

### Verified inventory versus live functionality

The counts above are file/route inventory counts, not the number of end-to-end proven operational workflows. Automated smoke checks cover source-level conditions and local route references. The exact count of pages whose complete live workflow works—including authentication, shipment creation, approved quotes, payment verification, partner assignment, delivery evidence, invoice handling and settlement—remains **unverified until tested against the live browser and backend**.


## Systematic Customer OS rebuild — current implementation status

- Added the shared mobile-first UI stylesheet at `public/customer-os/assets/customer-os-global.css` and linked it from every remaining Customer OS HTML page. This creates consistent design tokens, responsive tables/forms, focus states and common card/button styling while leaving each page's business logic separate.
- Found and removed three byte-for-byte duplicate Customer OS route files:
  - Removed `public/customer-os/customer-services/quote-acceptance.html`; canonical quote acceptance remains under `public/customer-os/quotes-pricing/quote-acceptance.html`.
  - Removed `public/customer-os/customer-services/quote-details.html`; canonical quote details remains under `public/customer-os/quotes-pricing/quote-details.html`.
  - Removed `public/customer-os/shipper-services/shipment-details.html`; canonical shipment details remains under `public/customer-os/customer-services/shipment-details.html`.
- Updated the privileged `global-admin-control` Edge Function inventory to omit the three deleted routes. Its inventory now contains **53 unique feature routes**, rather than showing deleted paths.
- Extended `scripts/krim-production-smoke.mjs` so CI fails when an exact duplicate Customer OS HTML page reappears, when a Customer OS page omits the shared stylesheet, or when the shared stylesheet is missing.
- Latest repository inventory from GitHub tree: **798 HTML files overall**, **55 Customer OS HTML files** (53 feature routes + portal index + integration manifest), and **zero exact duplicate HTML blobs within Customer OS**.
- Smoke check for the cleanup commit `fe9fd4526b6c43eca2dd6fdff1f0a227845b4455` passed: https://github.com/rimjhimkrn-web/logistics-saas/actions/runs/39940143840
- The new deduplication/style-coverage smoke test is running on commit `76cde0634ddc2c30f1b30d14a1e610d16ffe1ebf`: https://github.com/rimjhimkrn-web/logistics-saas/actions/runs/39940270945

### Important functional boundary

The shared stylesheet standardizes presentation; it does **not** convert navigation-only screens into working transactions. Several remaining pages (for example invoice and claims screens) still explicitly describe themselves as workflow/navigation shells. The next rebuild batches must connect each business action to its proper authenticated Supabase operation, confirm the saved result, and keep organization-level RLS and role checks intact. Until then, the number of fully end-to-end verified Customer OS pages remains **not yet established**.


### Additional semantic duplicate consolidation

The first review also found three pages that were not byte-identical but were generic navigation-only shells duplicating a stronger canonical workflow. These were removed from the repository and from the privileged inventory:

- `public/customer-os/shipper-services/active-shipments.html` → canonical live shipment register: `public/customer-os/customer-services/shipment-list.html`.
- `public/customer-os/shipper-services/invoices.html` → canonical invoice route: `public/customer-os/customer-services/invoices.html`.
- `public/customer-os/shipper-services/support-claims.html` → canonical claims route: `public/customer-os/customer-services/claims.html`; general support remains a separate function at `public/customer-os/customer-services/support.html`.

The privileged `global-admin-control` Edge Function inventory was updated to remove these three routes and remains JWT-protected. It now advertises 53 unique Customer OS feature routes. Local link validation in CI is being used to catch any surviving references to removed paths.
