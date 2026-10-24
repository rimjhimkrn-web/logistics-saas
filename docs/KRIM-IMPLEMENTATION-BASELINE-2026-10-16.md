# KRIM Implementation Baseline — 2026-10-16

This is a read-only inspection snapshot of GitHub `main` and the connected Supabase Production project. It records findings, not a production certification.

## Repository snapshot
- Repository: `rimjhimkrn-web/logistics-saas`
- Branch inspected: `main`
- Tree commit inspected: `14a64af08c15d5961611945cc7d2430a4e43c37e`
- Files in recursive tree: **625**
- Top-level counts from the tree: `public` 287, `node_modules` 179, `auth` 31, `docs` 23, `core` 15, `domains` 13, `app` 11, `platform` 9, `src` 18, plus root/config/legal/partner/workspaces/templates/js.
- Important: 179 committed `node_modules` files suggest repository hygiene and deployment size should be reviewed; do not delete them without checking Pages/build requirements.
- There are many pages and shared runtimes already. This is not a blank-slate project. Do not create duplicate paths before mapping the current ones to the lifecycle checklist.

## Supabase project snapshot
- Project name: `logistics-saas`
- Ref: `ebltviniygljwwseplph`
- Status: `ACTIVE_HEALTHY`
- Region reported by Supabase: `ap-northeast-1`
- Database engine: PostgreSQL 17
- Applied migrations returned by the connector include extensive global lifecycle, workflow, RLS, payments, partner, compliance, localization, financial reconciliation and reliability work through 2026-10-16.
- The live public schema includes global market/org/role/shipment/quote/workflow/integration/compliance/finance/partner tables. A table existing or containing demo rows does not prove a user workflow works end-to-end.
- Many operational tables are currently empty in this snapshot, including partner verification cases, partner service areas, partner quotes, partner match runs/results, shipment partner assignments, partner execution events, POD records, partner payables, settlements, webhook deliveries, integration sync runs, compliance screening runs and various notification/exception tables. Empty may be expected before real traffic, but these are not evidence of live operational scale.

## Deployed Edge Functions returned by the current inventory
- `razorpay-webhook` — ACTIVE v4; JWT verification disabled (normal for a provider webhook only if the request signature is validated).
- `krim-ai` — ACTIVE v6; JWT verification enabled.
- `create-global-razorpay-order` — ACTIVE v2; JWT verification enabled.
- `verify-razorpay-payment` — ACTIVE v1; JWT verification enabled.
- `krim-notification-provider-adapter` — ACTIVE v4; JWT verification enabled.
- `global-admin-control` — ACTIVE v2; JWT verification enabled.
- `krim-global-growth-operations` — ACTIVE v2; JWT verification enabled.
- `create-razorpay-order` — ACTIVE v1; JWT verification enabled.
- `process-payment--` — ACTIVE v1; JWT verification enabled. The double trailing hyphen in this deployed slug is unusual and must not be guessed or silently renamed. Determine the canonical payment verification flow before any frontend change.

## Verified checkout contract observations
- The inspected `public/quote-result.html` on `main` currently uses `supabaseClient.functions.invoke("create-global-razorpay-order", ...)` and `verify-razorpay-payment`, and only shows success after the verification response includes both `success` and `verified`. This is a safer pattern than trusting the browser checkout callback alone.
- `public/shipper/spot-approvals.html` links accepted quotes to `public/quote-result.html?shipment_id=...`, so this appears to be the current canonical checkout path. The quote-acceptance action and quote statuses still require an end-to-end test.
- The current deployed `create-global-razorpay-order` function expects an authenticated request and a shipment identifier; it calculates the amount server-side and returns fields including `razorpay_order_id`, `key_id`, `amount_paise`, `currency`, and shipment identifiers. The frontend's expected response fields appear aligned with the current function contract based on source inspection.
- The current deployed `verify-razorpay-payment` function expects Razorpay payment/order/signature identifiers and returns `success: true` and `verified: true` on successful verification. The database binding, provider status check, idempotency and cross-tenant behavior still need end-to-end tests.
- The separate older `create-razorpay-order` / `process-payment` pattern is still present in deployed functions and must not be reintroduced into the canonical page without review. The deployed slug `process-payment--` is not the same as `process-payment`.
- Do not activate live Razorpay keys based on a frontend modal closing or the browser's callback alone. The server must confirm the correct order, payment status, amount/currency and shipment/customer binding, then record the financial ledger idempotently.

## Current Supabase advisory blockers / warnings
### Security
- **7 SECURITY DEFINER functions are executable by the authenticated role** according to the security advisor. Findings include:
  - `krim_award_partner_quote(p_partner_quote_id bigint)`
  - `krim_create_partner_opportunity(p_shipment_id bigint, p_response_deadline timestamptz, p_service_tier text)`
  - `krim_provision_customer_organization(p_legal_name text)`
  - `krim_provision_partner_organization(p_legal_name text)`
  - `krim_respond_to_partner_assignment(p_assignment_id bigint, p_accept boolean, p_reason text)`
  - `krim_submit_partner_onboarding(...)`
  - `krim_submit_partner_quote(...)`
- These may be intentional RPC boundaries, but each must be reviewed for authorization, tenant scope, argument tampering, search_path hardening and grants. Do not indiscriminately revoke them without testing the workflows they serve.
- **Leaked-password protection is disabled** according to the security advisor. Enable before general public production onboarding if supported by the selected Auth configuration/plan; if it cannot be enabled, document a compensating control and launch limitation.

### Performance
- Advisor reports one RLS init-plan optimization warning on `revenue_ledger`.
- Advisor reports many unused indexes (634 in the returned snapshot). Do not mass-delete indexes: some may be new and unused simply because traffic is low. Review in measured batches with query plans and rollback options.

## Required next steps (ordered; no production changes made by this report)
1. Map all 625 existing paths against the master lifecycle checklist, identify canonical page for each journey, and record duplicate/legacy routes.
2. Audit the Get Started → sign-up → email verification → onboarding → role dashboard redirects.
3. Review the seven SECURITY DEFINER RPCs and leaked-password protection; test role boundaries and tenant isolation before modifying grants.
4. Establish one canonical shipment/quote/payment contract and remove false-success behavior in a staged branch.
5. Add automated smoke tests for navigation, auth, tenant isolation, quote acceptance, payment verification/idempotency, partner assignment and settlement reconciliation.
6. Verify scheduled jobs and provider integrations from run logs; never treat scheduled-job creation as proof that the job completes successfully.
7. Only after staging acceptance, security review, reconciliation tests and backup/restore review, consider live payment credentials and acquisition automation.

## Evidence rule
Every “complete” status must reference a test result, request/response evidence, relevant migration/function version, and date. A route existing, a migration being applied, an Edge Function being ACTIVE, or a sample row existing is not enough to call a business lifecycle operational.
