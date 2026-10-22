# KRIM Global Logistics OS — Build, Test & Launch Control Plan

Version: 1.0
Date: 2026-10-22
Repository: rimjhimkrn-web/logistics-saas
Status: Audit-first; no production readiness claim until evidence is recorded.

## Operating contract
1. Preserve the frozen Supabase/Auth architecture and current production records.
2. Inspect existing pages, RPCs, Edge Functions, schema, constraints, RLS and integrations before adding or replacing files.
3. Prefer one canonical page per user journey. Do not create duplicate pages that write to different tables or statuses.
4. Build/repair all required user-facing pages and shared backend contracts before full end-to-end acceptance testing.
5. Do not use localStorage or fake data as proof of operational success.
6. Use test accounts, test records and payment-provider test mode for verification. Never expose secret keys in frontend files or commit them to Git.
7. Test each role's permissions and each failure path; record evidence before marking a stage passed.
8. Do not enable live Razorpay keys until test-mode payment, server verification, webhook idempotency, refunds, reconciliation and security checks pass.
9. No marketing automation may send unsolicited messages or claim unavailable services. Use consent, suppression, rate limits and truthful service availability.
10. Deploy only after a production-readiness gate, backup/restore review, monitoring and rollback plan.

## Required user-facing journeys
- Public visitor: homepage, platform/service discovery, market/service availability, contact/support, public tracking with safe information disclosure, legal/privacy/terms.
- Authentication: signup, login, logout, email verification, password recovery, MFA enrollment/recovery, organization invitation, workspace routing.
- Customer: profile/organization, service discovery, shipment booking, documents, quote review/comparison, quote acceptance/rejection, checkout, payment history, shipment tracking, cancellation/refund request, delivery/POD, invoices, claims/support, feedback.
- Logistics partner: signup, business verification/KYC, service regions/modes/capacity, rate cards/contracts, eligible load discovery, quote submission/revisions, award/assignment acceptance, driver/fleet/warehouse coordination, milestones/POD, invoices, earnings, disputes, settlement history, support.
- Driver: secure onboarding, licence/profile verification, assignment list/details, accept/decline, pickup checklist, custody events, trip milestones, exception reporting, delivery evidence, offline/error recovery where supported.
- Warehouse operator: inbound notice, receive/scan, count/condition, storage/custody, pick/pack, dispatch, carrier handover, discrepancy/exception queue.
- Customs & trade: document checklist, validation, declarations/references, screening/holds, clearance/release events, audit trail.
- Finance & treasury: accepted commercial records, verified payments, invoices/credit notes, refunds, ledger, partner payable, reconciliation, payout initiation/status, disputes, approvals and financial reporting.
- Operations: live shipment queues, SLA/ETA, assignment and reassignment, exception ownership/escalation, service recovery, notification failures, integration health.
- Enterprise: organization members/permissions, contracted rates, bulk/recurring bookings, approval policies, reporting, document access, API/webhook integrations.
- Platform administrator: market/service configuration, RBAC and access review, audit/security events, system/integration health, emergency pause and recovery controls. Privileged admin entry must remain separate from public customer access.

## Canonical shipment journey
1. Discover service and validate route/cargo eligibility.
2. Create shipment with authenticated customer + authorized organization; idempotent request; return canonical shipment ID.
3. Validate shipment data and document requirements.
4. Calculate rate from approved, valid rate card or explicit approved pricing workflow.
5. Create versioned, expiring quote with currency and transparent line items.
6. Customer reviews/accepts/rejects quote.
7. Eligible partners submit offers where the commercial model requires bidding; contract-rate flows may bypass bidding.
8. Select eligible offer and create shipment-linked assignment; partner accepts or decline/reassignment workflow starts.
9. Server derives payable amount/currency from accepted quote and eligible assignment.
10. Create/reuse a server-side Razorpay order idempotently; browser never controls amount.
11. Verify signature and provider payment status server-side; reconcile webhooks idempotently.
12. Confirm shipment only after service-specific prerequisites (payment or approved credit, assignment, documents/compliance as applicable).
13. Schedule pickup; record pickup and custody evidence.
14. Track shipment and transport legs; record trusted milestones and source.
15. Process warehouse handovers and customs clearance where applicable.
16. Manage exceptions, delays, cancellations, refunds and notifications.
17. Record delivery attempts and secure proof of delivery; verify before delivered status.
18. Manage claims/disputes and customer feedback.
19. Generate applicable invoice/credit note; post auditable ledger entries.
20. Reconcile gateway, payment, fees, refunds, invoices and ledger.
21. Calculate partner payable from applicable agreement; approve and verify payout outcome.
22. Close operational and financial workflows independently when claims/holds remain open.

## Global cross-cutting requirements
- Multi-country market activation, country/location/currency/time-zone/units/language configuration.
- Role + organization + resource authorization enforced by backend/RLS, not UI only.
- Secure documents/storage, access controls, retention and audit.
- Idempotency for bookings, orders, webhooks, ledger postings, refunds and payouts.
- Explicit state-transition rules; separate shipment state from payment, customs, claim and settlement states.
- Notifications with retries, suppression/consent where relevant, and delivery logs.
- Integration timeouts, retries, dead-letter/reconciliation path and observability.
- Accessibility, mobile responsiveness, useful empty/loading/error states.
- Privacy, data minimization, applicable regional compliance, sanctions/restricted cargo controls.
- Monitoring, alerting, backups, restore test, incident response and rollback.
- SEO and acquisition only for services/markets KRIM can truthfully serve; measure qualified conversion, repeat usage, complaints and retention.

## Test/approval gate for every workflow
Record: test ID, environment, account role, input fixture, expected result, actual result, shipment/quote/payment reference, relevant database evidence, authorization test, failure/retry result, audit event, screenshots/log references, known limitation and pass/fail.
Minimum tests: valid flow; missing/invalid input; unauthorized actor; cross-organization access denial; duplicate/retry; backend/integration failure; invalid state transition; concurrent request where relevant; correct database linkage; audit trail.
A page rendering or a redirect alone is not a pass.

## Build and release sequence
Phase 0 — Inventory current repository, canonical URLs, entry points, migrations, tables, RLS, RPCs, Edge Functions, secrets/config references and deployment wiring.
Phase 1 — Reconcile duplicates and create/repair canonical pages for all nine workspaces and public/auth journeys.
Phase 2 — Align frontend pages to authoritative backend/RPC/Edge Function contracts without replacing the frozen architecture.
Phase 3 — Verify each role's direct access and navigation.
Phase 4 — End-to-end test full shipment lifecycle in test environment, including failure/retry/authorization cases.
Phase 5 — Test Razorpay test mode: order creation, signature verification, provider status, webhooks, idempotency, refunds and reconciliation.
Phase 6 — Production-readiness review: security, RLS, secrets, backup/restore, monitoring, incident and rollback plan, privacy/legal/market readiness.
Phase 7 — Only after explicit approval, configure live Razorpay credentials securely, perform controlled live smoke test, verify real settlement, and monitor.
Phase 8 — Cloud deployment/custom domain, performance/accessibility checks, indexing and truthful acquisition campaigns, consent-safe lifecycle messaging and retention measurement.
Phase 9 — Expand markets only after partner coverage, service availability, payment support, regulatory and operational readiness for each market.

## Current evidence snapshot (2026-10-22)
- GitHub main branch has 976 tracked files; many workflow-related HTML files exist, so audit canonical paths before creating more duplicates.
- Latest main commit message: "Build Page 05 partner selection and assignment workflow".
- Supabase project ref: ebltviniygljwwseplph; project status reported ACTIVE_HEALTHY.
- Existing shipment, quote, payment, status-history, partner and settlement-related schema is present. Schema/table existence is not proof of end-to-end success.
- A read-only schema inventory shows legacy and canonical shipment entities coexist (including shipment_requests and krim_shipments) with relationships between them. Do not migrate or delete either without a documented compatibility plan.
- Existing lifecycle documents describe shipment, partner and payment flows; reconcile them with actual code and live schema before changes.
- Step 1 booking is not approved until a fresh, authorized booking is created and verified end-to-end with its canonical ID passed to the next stage.

## Release status
No live-key activation, public launch or global-production-readiness claim is authorized until the relevant evidence gates pass. Maintain a separate status register and update it only with reproducible evidence.
