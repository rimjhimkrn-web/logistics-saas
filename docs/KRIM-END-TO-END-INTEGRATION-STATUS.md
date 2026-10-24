# KRIM Global Logistics — Integration Work Status

**Updated:** 2026-10-24  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Production frontend:** GitHub Pages under `/logistics-saas/`  
**Supabase project:** `logistics-saas` (`ebltviniygljwwseplph`)

## Scope and honesty

This is a staged integration, not a claim that every HTML page is fully connected. The repository inventory contains 805 HTML files outside `node_modules`; many are module pages, aliases, or legacy routes. Bulk-rewriting all files before auditing their purpose would risk breaking working customer, partner, payment, and administrator flows.

## Work completed in this batch

- Added a shared canonical route registry and `window.krimRoute(name, query)` helper to `config.js`.
- Updated `auth/login.html` to use the shared route registry for the eight standard workspaces. It still requires a valid active organization membership and verified MFA before redirecting.
- Added a static local-link audit script at `scripts/audit-krim-links.mjs`. It scans HTML `href`, `src`, `action`, `formaction`, and `poster` references and reports missing local targets without changing or deleting files.
- No pages were deleted and no payment, role, or RLS policies were weakened.

## Canonical route keys

| Route key | Canonical file |
|---|---|
| `home` | `index.html` |
| `access` | `auth/access.html` |
| `login` | `auth/login.html` |
| `customer` | `app/customer/index.html` |
| `partner` | `app/partner/index.html` |
| `driver` | `app/driver/index.html` |
| `warehouse` | `app/warehouse/index.html` |
| `customs` | `app/customs/index.html` |
| `finance` | `app/finance/index.html` |
| `operations` | `app/operations/index.html` |
| `enterprise` | `app/enterprise/index.html` |
| `platformAdmin` | `app/platform-admin/index.html` |
| `customerBooking` | `public/shipper/booking-request.html` |
| `customerQuoteRequest` | `public/customer/quote-request.html` |
| `quoteResult` | `public/quote-result.html` |
| `customerShipments` | `public/customer-os/customer-services/shipment-list.html` |
| `tracking` | `public/tracking.html` |
| `partnerOnboarding` | `public/partner/partner-onboarding.html` |
| `partnerMarketplace` | `public/partner/load-marketplace.html` |
| `driverAssignments` | `app/driver/module-01-assignment-inbox.html` |
| `warehouseInbound` | `public/warehouse/inbound-receiving.html` |
| `warehouseInventory` | `public/warehouse/inventory-ledger.html` |
| `customsQueue` | `app/customs/index.html` |
| `financeInvoices` | `app/finance/invoicing.html` |
| `operationsControl` | `app/operations/index.html` |
| `enterpriseShipments` | `app/enterprise/shipments.html` |
| `support` | `public/support/help-centre.html` |

The route registry is the agreed destination map; it does not automatically change every legacy link yet. Remaining pages must be migrated in audited batches.

## Backend observations from the connected Supabase project

- 338 public-schema tables were returned by the project inventory; the inventory reported Row Level Security enabled on the listed tables. This does not prove every policy is correct or every role has the intended access.
- Core data objects include `krim_organizations`, `krim_organization_members`, `krim_shipments`, `krim_quotes`, `krim_shipment_partner_assignments`, `krim_tracking_events`, `krim_shipment_customs`, `krim_invoices`, `krim_settlements`, `revenue_ledger`, and legacy `shipment_requests`.
- 16 Edge Functions were listed as ACTIVE, including Razorpay/Cashfree order and payment verification functions, payment webhooks, public tracking, notifications, AI, global admin control, and growth operations.
- Customer, partner, driver, customs, finance, operations, enterprise, and platform-admin entry pages contain Supabase-backed session or data access code. This is not equivalent to proving every action works.
- Warehouse entry explicitly labels several operational actions as awaiting backend connection. Warehouse receiving, inventory, picking/packing, dispatch, and evidence therefore remain a priority for schema/policy/action-level verification.

## Required next steps

1. Run `node scripts/audit-krim-links.mjs` from the repository root and fix broken local references in controlled batches.
2. Verify the actual GitHub Pages publishing root and live destinations before redirecting aliases.
3. Compare canonical and legacy pages by purpose, links, scripts, role checks, and backend calls; do not delete by filename alone.
4. Verify role-specific database access and organization isolation with separate test accounts.
5. Complete the customer journey: shipment request → quote → quote acceptance → payment order → verified payment → booking → tracking.
6. Complete partner assignment → driver execution → milestone persistence → proof of delivery.
7. Connect and verify warehouse receiving/inventory/dispatch and customs records where applicable.
8. Verify invoice/revenue/partner payable/settlement reconciliation using test transactions before any live money movement.
9. Verify enterprise approvals and privileged admin actions with audit evidence.
10. Record test evidence and keep unverified actions clearly labelled; never display simulated success as a real transaction.

## Definition of done

A page is **connected** only when its intended route resolves, its correct authenticated role can open it, its data reads are scoped by backend authorization, permitted writes persist to the expected records, the next workflow step receives the same canonical shipment/quote/payment IDs, and failures are visible without false success.
