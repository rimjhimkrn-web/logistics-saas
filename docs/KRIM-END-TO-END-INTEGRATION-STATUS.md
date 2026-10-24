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

## Security and performance findings that block a blanket launch claim

The connected Supabase advisors returned the following findings on 2026-10-24:

- **Security warning:** 28 `SECURITY DEFINER` functions in the exposed `public` schema are executable by the `authenticated` role. Some may be intentionally callable if their function bodies perform strict role/tenant checks, but each must be inspected. Do not blindly revoke or change them because that can break critical workflows; do not declare them safe until the authorization checks and grants are reviewed.
- **Performance information:** 9 foreign-key constraints were reported without covering indexes, including relationships on driver assignments, driver delivery evidence, driver profiles, driver trip events, and private payment transactions.
- **Performance information:** the advisor reports 629 unused indexes. This is a review queue, not permission to delete indexes: some are for infrequent but critical workflows, and usage history can be incomplete.

These findings should be reviewed alongside the route/link audit. RLS being enabled on a table is necessary but does not by itself prove that its policies, grants, RPCs, or organization isolation are correct.

## Verified workflow gap found during the next audit batch

A read-only schema inspection on 2026-10-24 found **no warehouse-specific operational tables** in the public schema: no `krim_warehouse_facilities`, `krim_warehouse_receipts`, `krim_warehouse_inventory`, or `krim_warehouse_movements` tables. The existing Warehouse Control Centre checks for `krim_warehouse_inventory`, so its schema probe will currently fail. The 12 linked warehouse module pages verify identity/membership and explicitly state that their form validation does not save operational records.

This is a real backend gap, not just a navigation issue. The next warehouse implementation needs a reviewed, additive schema for facilities, receiving, inventory movements, dispatch, and exceptions; RLS scoped to active warehouse organizations; and persisted operational actions with audit evidence. It must not fabricate a receipt or inventory balance. Shipment linkage must be restricted to shipments legitimately routed to the facility, not arbitrary shipment IDs.

The canonical route registry's 14 destinations were individually checked through the GitHub file API and each destination exists in the repository. The static audit was improved to validate the registry destinations and correctly resolve root-relative URLs. The complete repository-wide report still needs to run in GitHub Actions and be inspected.

## Core journey source inspection

The following frontend/backend connections were confirmed by source inspection on 2026-10-24. This confirms that calls are present, not that every call has passed a live authenticated end-to-end test.

| Journey step | Current implementation found | Verification still required |
|---|---|---|
| Create shipment | `public/shipper/booking-request.html` calls `krim_create_global_shipment_idempotent` | Test role permissions, idempotency, persisted shipment, validation and retry behavior |
| Customer quote view | `public/customer/quote-request.html` reads `krim_shipments` and `krim_quotes` | Confirm RLS returns only the user's organization records and quotes refresh after partner submission |
| Accept quote | `public/shipper/spot-approvals.html` calls `krim_accept_global_quote` | Test quote validity, one-time acceptance, status transitions and audit events |
| Partner marketplace | `public/partner/load-marketplace.html` reads opportunities and calls `krim_submit_partner_quote` | Test approved-partner eligibility, currency/rate validation and duplicate submissions |
| Checkout | `public/quote-result.html` invokes payment capability/order creation and payment verification functions | Use provider test transactions; verify signature, amount/currency, booking linkage, webhook idempotency and ledger reconciliation |
| Public tracking | `public/tracking.html` calls the `public-shipment-tracking` Edge Function | Test authorized reference behavior, no data leakage and not-found responses |
| Driver assignments | `app/driver/module-01-assignment-inbox.html` reads `krim_driver_assignments` scoped to the signed-in user | Test assignment lifecycle and actual milestone/POD persistence |
| Finance | `app/finance/index.html` reads invoices, settlements, payment orders and revenue ledger | Test organization scoping and reconcile records to provider-confirmed payments and actual payouts |
| Operations | `app/operations/index.html` reads shipments, exceptions and tracking events | Test cross-workspace event consistency, queue ownership and exception resolution |
| Enterprise | `app/enterprise/index.html` reads shipment data and falls back to legacy `shipment_requests` if the primary query fails | Decide whether legacy fallback is still required; verify it does not mask schema/RLS errors or mix incompatible records |
| Platform administration | `app/platform-admin/index.html` calls `global-admin-control` | Verify each action's server-side authorization and audit trail |
| Warehouse | Entry and 12 module pages verify identity/membership, but operational forms explicitly state that they do not save data; warehouse tables were absent | Build reviewed schema, tenant/facility-scoped policies, validated write paths, and audit/event records before enabling live actions |

## Workspace authorization hardening committed

A source audit found that Customs, Finance, Operations, and Enterprise entry pages previously accepted any authenticated session at the UI gate, even though the page's role-specific organization membership had not been verified there. Backend RLS remains the real data boundary, but the UI should also prevent incorrect workspace entry.

Committed fixes now require an active organization of the matching type before opening these workspaces:
- Customs: active `customs` organization membership.
- Finance: active `finance` organization membership.
- Operations: active `operations` organization membership.
- Enterprise: active `enterprise` organization membership.

The checks fail closed when the membership query errors. These are source-level changes; they still need live tests with authorized and unauthorized test accounts, and they do not replace backend RLS or server-side authorization.

## Latest backend changes and checks — 2026-10-24

Two additive Supabase migrations were applied and their policy records were verified:

- `20261024072613_add_role_scoped_cross_workspace_read_policies`
  - Operations users with active `shipment.view` permission can read shipment records and exceptions.
  - Operations users with active `tracking.view` permission can read tracking events.
  - Finance users with active `finance.view` permission can read invoices, settlements, payment orders and revenue-ledger rows.
  - Customs users with active `compliance.view` permission can read customs records.
- `20261024072632_add_customs_exception_read_policy`
  - Customs users with active `compliance.view` permission can read exception records.

These policies are **SELECT-only**; they add no cross-workspace insert, update, or delete permissions. Each policy requires an active organization of the matching type plus the relevant role permission. The database confirmed all nine policy records after application.

Manual repository checks also confirmed that all 14 canonical route-registry destinations exist, all nine checked homepage destinations exist, and all 16 checked customer-workspace destinations exist. This is a targeted check, not a complete audit of every local link in the 805 HTML files.

The Supabase advisors were rerun. The security advisor still reports 28 authenticated-callable `SECURITY DEFINER` functions for manual review. The performance advisor reports 9 unindexed foreign keys and 629 unused-index candidates. No functions were revoked and no indexes were deleted: those changes require a function-by-function and index-by-index dependency review.

**Not yet verified:** real authenticated positive/negative tests for each new RLS policy, live browser execution, complete GitHub Actions audit results, payment-provider test transactions, and full end-to-end shipment execution.

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
