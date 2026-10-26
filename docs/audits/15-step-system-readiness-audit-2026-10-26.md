# KRIM Logistics — System Readiness Audit (15-Step Roadmap)
Date: 2026-10-26
Environment: Production Supabase project `ebltviniygljwwseplph`; repository `rimjhimkrn-web/logistics-saas`.

## Scope of this pass
Read-only production checks and focused inspection of selected SECURITY DEFINER functions. No production data, permissions, auth settings, or schema were changed in this pass.

## Current verified baseline
- `public.krim_shipments`: 17 rows.
- `public.krim_quotes`: 7 rows.
- `public.krim_pricing_rate_cards`: 1 row; 0 active positive-price rate cards.
- The live pricing blocker remains: no valid approved active rate card; do not invent prices or treat draft/zero-price cards as customer-usable.
- Country/market setup remains configured for six markets, but only India has explicit operational market activation; configured catalogue entries do not prove real service coverage.
- Previous Step 1 checks found 17 legacy/incomplete shipment rows and one historical closed-shipment leg exception. These are historical exceptions, not safe targets for blind updates.
- Authenticated booking, quote-to-payment, partner assignment, delivery/POD, and financial settlement have not yet passed a complete end-to-end acceptance test.

## Security advisor results (2026-10-26)
- WARN: 26 SECURITY DEFINER functions in `public` are executable by authenticated users. This is a review queue, not proof that all 26 are vulnerable. A focused sample of shipment creation, driver trip events, tracking, customer organization provisioning, customer service requests, and warehouse movements was inspected. The sampled functions contain authentication and context-specific organization/assignment checks; several also use explicit permission checks. Continue reviewing each function against its intended caller and authorization contract before any ACL changes.
- WARN: Leaked-password protection is disabled in Supabase Auth. Enable through the supported Auth settings/dashboard before real-user launch; this pass did not change account-level settings.
- INFO: Four RLS-enabled tables have no policies: three in the non-exposed `private` schema (`krim_payment_capabilities`, `krim_payment_providers`, `krim_payment_transactions`) and `public.krim_inquiry_followups`. Live privilege checks show anon and authenticated have no SELECT/INSERT table privileges on these four tables. Do not add broad policies merely to silence the advisor.
- Performance advisor: four warehouse RLS initplan warnings; one unindexed FK on `krim_warehouse_inventory_movements`; 16 multiple-permissive-policy warnings; 643 unused-index INFO findings. Do not drop unused indexes without a considered usage window and workload review.

## Priority decisions
1. Keep real payment acceptance and launch blocked until security, payment reconciliation, and full workflow tests pass.
2. Review the 26 SECURITY DEFINER functions individually, beginning with privileged/admin actions and functions that read or mutate shipment, partner, financial, or warehouse data. Do not blanket-revoke execution: intended authenticated workflows depend on some of these RPCs.
3. Enable leaked-password protection in Supabase Auth before launch.
4. Verify organization isolation and unauthorized access with dedicated authenticated test accounts.
5. Run full booking-to-delivery and payment-to-ledger reconciliation tests using controlled test data and test-mode payments.
6. Defer low-risk performance cleanup until security and workflow acceptance are stable.

## Roadmap status snapshot
1. Database & Booking Integrity — safeguards implemented; historical exceptions documented; authenticated E2E acceptance pending.
2. Global Foundation — base catalogue/localization implemented; market activation intentionally restricted; parity and cross-market checks pending.
3. Commercial Pricing — blocked by absence of approved positive-price rate cards and verified commercial inputs.
4. Partner Acquisition & Verification — implementation exists; genuine provider verification/capacity is not established.
5. Shipment Matching & Assignment — implementation exists; complete authorized assignment flow unverified.
6. Operational Fulfilment — UI/functions exist; pickup-to-POD E2E unverified.
7. Payment & Financial Integrity — test-mode foundation exists; reconciliation, revenue allocation, settlement and payout acceptance pending.
8. Security & Compliance — audit in progress; warnings above remain.
9. Customer Support & Communications — components exist; delivery and exception handling require E2E verification.
10. Automated Global Growth — automation infrastructure exists; safe, real acquisition outcome not verified.
11. Sustainable Revenue & Business Controls — no approved live rate card; financial rules and real unit economics not proven.
12. Integrations & Reliability — integrations exist; retries, webhook reconciliation and recovery require targeted testing.
13. Automated End-to-End Testing — incomplete.
14. Live Payments & Acceptance Testing — not started; test mode remains.
15. Controlled Launch & Global Expansion — blocked pending acceptance and real operating readiness.

## Next technical action
Continue a per-function authorization review of SECURITY DEFINER RPCs, beginning with administrative and financial mutations. For each function, document caller, authentication, organization/role/permission checks, input validation, search_path, grants, and a negative authorization test. Only change grants or function bodies when the expected access contract is confirmed; verify every change afterward.
