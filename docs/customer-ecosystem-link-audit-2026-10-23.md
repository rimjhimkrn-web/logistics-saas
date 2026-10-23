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
