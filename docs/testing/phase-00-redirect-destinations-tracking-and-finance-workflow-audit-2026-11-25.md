# Phase 00 — Redirect destination and Finance workflow source audit
Date: 2026-11-25
Branch: qa/phase-00-baseline-2026-11-25
Scope: Driver assignment destination, Partner marketplace destination and quote page, public tracking destination, Finance invoicing and settlement modules.
Method: read-only inspection of exact QA-branch sources and correlation with prior Phase 00 database/permission reports. No browser session, RPC call, form submission, provider operation, storage upload or database mutation.

## Executive findings
1. The Driver assignment route is a 12-line redirect to the Driver dashboard's assignment anchor. The dashboard itself is a real authenticated, account-scoped database read—not a local mock—but has no assignment accept/decline/write action on this page.
2. The Partner marketplace destination is a real authenticated database-backed opportunity register. It verifies active partner organization, requires exactly one active partner organization, and requires registered-business + approved/verified + compliant + active lifecycle before exposing open opportunities. Prior database snapshot had zero open opportunities and zero verified capabilities/approved service areas. The page is therefore wired but has no current marketplace inventory evidence.
3. The partner quote page exists as a separate commercial submission form and calls `krim_submit_partner_quote`; prior ACL audit found authenticated EXECUTE in Production but not Staging. Staging partner quote execution remains blocked until permission and function parity are reviewed.
4. Public tracking destination is a public Edge Function consumer that refreshes every 30 seconds, but it hardcodes the Production Supabase URL and publishable key rather than using the shared host-verified environment client. This is a critical environment-isolation defect on a public route. The page's live-GPS display is conditional on a returned position marked fresh/live and GPS sharing active; a 30-second refresh does not itself create GPS data.
5. Finance invoicing and settlement pages are authenticated preparation/review surfaces, not transaction execution. Invoicing validates only browser fields and explicitly saves or issues nothing. Partner settlement data remains held. Payment processing source also withholds payment-order rows pending scope review. No proof of invoice posting, receivable collection, refund, journal posting, payout or bank settlement was found in these pages.

## 1. Driver assignment destination
Canonical alias: `app/driver/staging/page-02-assignment-inbox.html`.
Destination: `app/driver/dashboard.html#assignments`.

The alias is only a redirect; it has no independent workflow. The destination:
- Requires `window.KRIM_SUPABASE`; if missing, it shows a connection-not-configured state and renders no assignments.
- Calls `auth.getSession()`; without a session it shows a sign-in prompt and empty assignment list.
- Reads active `krim_organization_members` rows for the current Auth user and requires exactly one active membership whose role is `driver`.
- Reads `krim_driver_assignments` filtered by `user_id = auth.uid()`, newest first, limit 100.
- Reads `krim_driver_profiles` for the same user to personalize the greeting.
- Does not invoke a mutation RPC, accept an assignment, change status, upload POD or submit GPS from this dashboard. Its “Open assignment workflow” link navigates to another child route.
- Sign-out calls Supabase signOut but leaves the page open; the status changes to SIGNED OUT and assignments are cleared locally.

Assessment: **AUTHENTICATED ACCOUNT-SCOPED READ — NOT AN ACTIONABLE ASSIGNMENT ACCEPTANCE FLOW.** Prior DB snapshot had zero driver assignments/profiles and zero partner assignments in both environments. Runtime sign-in and tenant isolation remain untested.

## 2. Partner marketplace destination
Legacy alias `public/partner/load-marketplace.html` identifies the prior fictional sample-load page and redirects to `public/partner/available-loads.html`. Only the destination is relevant for live marketplace verification.

Destination source behavior:
- Requires shared client `window.KRIM_SUPABASE` / `window.supabaseClient`; no hardcoded Production fallback was found in the inspected initializer.
- Requires a signed-in session; otherwise renders secure sign-in prompt.
- Reads active `krim_organization_members` for current user, then reads the linked `krim_organizations`.
- Requires exactly one active partner/carrier/forwarder/logistics-provider organization. Multiple partner organizations cause access to pause to avoid ambiguous cross-org context.
- Requires `partner_account_mode=registered_business`, verification `verified` or `approved`, compliance `compliant`, and lifecycle `active`.
- Only after those checks does it query `krim_partner_opportunities` with status open (limit 200), then shipment, location, country details and current partner's `krim_partner_quotes`.
- Displays only unexpired, not-cancelled, not-awarded opportunities. Quote submission link is shown only when the partner passes the source-level verification test.
- It does not create sample opportunities or substitute fictional freight. It explicitly reports an empty live feed if none are returned.

Assessment: **LIVE-DATA SOURCE-WIRED, ELIGIBILITY-GATED, BUT NO LIVE INVENTORY PROVEN.** Prior Production snapshot showed zero open opportunities, zero active verified capabilities and zero approved service areas. Prior Staging snapshot also had no partner data. Source query success and RLS behavior require runtime verification with an approved isolated synthetic partner.

## 3. Partner quote submission
`public/partner/submit-quote.html` is the actual quote submission destination linked from eligible opportunities. It is a separate authenticated commercial form. The existing source and prior page-to-RPC audit identify `krim_submit_partner_quote` as its write RPC.

Prior catalog/ACL evidence:
- Production: authenticated EXECUTE granted.
- Staging: authenticated EXECUTE absent.
- Staging implementation has a stricter current-compliance check.
- No partner quote rows or active verified partner organization were present in the prior Production snapshot; Staging has no organizations or quote data.

Assessment: **SOURCE-WIRED; STAGING RUNTIME JOURNEY BLOCKED BY ACL DRIFT.** Do not copy Production grant wholesale. Review the function body, compliance requirements, role scope, idempotency and test-fixture strategy before any Staging permission change.

## 4. Public tracking destination
Canonical alias `public/tracking.html` redirects to root `tracking.html`.

Root tracking page:
- Calls the Production Supabase Edge Function endpoint `/functions/v1/public-shipment-tracking` using a hardcoded Production project URL and publishable key.
- Sends a POST body containing the user-entered `tracking_number`; response is rendered using DOM text nodes rather than injecting response strings as HTML.
- Shows shipment number/status, origin/destination, current location if present, delivered/estimated delivery time and shipment creation time.
- Renders milestone events from the returned `events` array.
- Renders GPS coordinates only when the response contains finite latitude/longitude. The “LIVE” visual state additionally requires `freshness === live` and `gps_sharing_status === active`. Otherwise it labels stale/inactive/starting/completed states.
- Refreshes the same tracking number every 30 seconds while the page is visible and refreshes on visibility change.
- This page does not itself collect GPS, create a driver session, authenticate a driver or upload location data. GPS collection requires a separate native/driver-side consented source; prior Driver audit found GPS collection disabled.
- The function's server-side lookup authorization, enumeration/rate limits, response minimization, tracking-number entropy and abuse protections must be checked in the Edge Function source/catalog. This page inspection alone does not establish those controls.

**CRITICAL ENVIRONMENT-ISOLATION DEFECT:** The tracking page bypasses `config.js` and hardcodes the Production URL/key. Because the shared environment resolver is not used, a staging/preview host can still call the Production public tracking endpoint. Replace with the shared verified client/host resolver or a strictly environment-routed endpoint and fail closed when configuration is absent. No deploy until tested.

Assessment: **PUBLIC TRACKING UI SOURCE-WIRED; LIVE TRACKING NOT VERIFIED; PRODUCTION ENDPOINT HARD-CODED.** The 30-second timer is a polling interval, not evidence of real-time driver GPS.

## 5. Finance invoicing and receivables
`app/finance/invoicing.html`:
- Loads shared `config.js` and requires a Supabase session.
- Reads active organization memberships and calls `krim_has_permission` for `finance.view`.
- It does not query invoice rows or call an invoice create/issue/post RPC.
- Its form captures references and notes in browser memory only; submit handler prevents default and displays “Browser-side fields validated only. Nothing was saved and no financial action was performed.”
- The page explicitly distinguishes KRIM's own contracted software/referral/coordination fee from partner freight invoices. Under partner-direct model, logistics partner issues freight invoice to customer; KRIM should invoice only its own separately contracted, legitimately earned fee with tax treatment confirmed.

`app/finance/accounts-receivable.html` and other generic finance preparation modules use the same preparation pattern; inspect each page's final script and any page-specific backend reads before claiming a live register. The page family is not a functioning accounts-receivable ledger merely because the routes and forms exist.

Assessment: **AUTHENTICATED FINANCE PREPARATION — NO INVOICE ISSUE/POST OR AR COLLECTION EVIDENCE.**

## 6. Partner settlements and payment processing
`app/finance/partner-settlements.html`:
- Requires session, active organization membership and `finance.view` permission.
- Explicitly states customers pay the contracting provider directly; KRIM does not hold escrow, collect freight charges or disburse partner freight payouts.
- Payable register is deliberately withheld pending partner-only visibility and finance-role authorization review.
- Preparation form validates in browser only and does not save.
- Does not calculate commission or execute payouts.

`app/finance/payment-processing.html`:
- Requires session, membership and `finance.view`.
- Payment-order table is deliberately held pending strict customer-entity scope and designated finance authorization; no payment amounts or provider references are displayed.
- Does not create orders, capture payments, refund or post journals from this page.

Correlated prior Finance audit:
- Production payment data exists historically (payment orders, payments, webhook events, one payout and one revenue ledger row), but the canonical double-entry ledger had 14 accounts and zero ledger transactions/entries.
- Four Production webhook events were unprocessed at the snapshot and need dashboard reconciliation; no replay occurred.
- Refund requests and invoices had zero rows.
- A `paid` partner payout row is not proof of bank settlement.
- Staging financial tables were empty.
- Real financial transactions remain NOT VERIFIED.

Assessment: **PARTNER-DIRECT FINANCIAL MODEL IS CLEAR; FINANCE UI IS MOSTLY READ-ONLY/PREPARATION; END-TO-END FINANCIAL EXECUTION NOT VERIFIED.**

## Cross-cutting blockers
1. Remove hardcoded Production endpoint/client configuration from Customer booking and public tracking. Both routes must fail closed if the host-verified shared configuration is unavailable.
2. Establish a protected Staging deployment origin and environment-specific public tracking Edge Function route before browser E2E.
3. Create an isolated test sink and synthetic fixtures only after approved controls; do not use Production data for test mutations.
4. Resolve Staging partner quote and workspace RPC grants with least privilege and function parity review.
5. Implement/test the actual assignment acceptance, POD and GPS workflows before describing Driver OS as operational.
6. Implement/test invoice, receivable, refund and finance posting workflows consistent with the partner-direct commercial model; keep payouts/escrow out of scope unless the business model and compliance posture change.
7. Verify public tracking Edge Function server-side authorization, rate limiting, anti-enumeration, response minimization and audit logs.

## Evidence boundary
This is a source-level audit correlated with earlier read-only catalog and data-count reports. No browser runtime test, sign-in, RPC execution, Edge Function call, provider operation, payment, email, Telegram, upload or DB write was performed. Source code can establish intended UI behavior but cannot prove deployed behavior or RLS correctness.

## Verdict
- Driver assignment destination: **AUTHENTICATED READ, NO ACCEPTANCE ACTION**.
- Partner marketplace: **LIVE-DATA SOURCE-WIRED, NO OPEN INVENTORY PROVEN**.
- Partner quote: **STAGING ACL BLOCKER**.
- Public tracking: **SOURCE-WIRED, PRODUCTION ENDPOINT HARDCODED, GPS NOT VERIFIED**.
- Finance invoicing/settlements: **PREPARATION/RESTRICTED, NOT TRANSACTIONAL**.
- Full runtime and financial acceptance: **OPEN — NO ONBOARDING APPROVAL**.
