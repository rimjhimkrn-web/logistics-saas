# KRIM Global Logistics — Operating Blueprint & Launch Execution Plan

**Status:** Active execution plan  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Architecture:** Global-first; India is the initial operating market, not a global coverage claim.  
**Rule:** This document is the single operational checklist for completing the existing blueprint and the global growth additions. It supplements—not replaces—the Global Build Contract, route register, and end-to-end integration status.

## 1. The three proof levels

KRIM must report these separately:

1. **Global architecture:** data model and software can represent international markets and workflows.
2. **Verified functionality:** a workflow has passed reproducible tests with appropriate evidence.
3. **Active business:** customers pay for genuine services, verified partners fulfil shipments, records reconcile, and economics are measured.

A page, table, scheduled job, registration, test payment, or successful deployment alone does not prove an active global logistics service.

## 2. Required end-to-end shipment lifecycle

Customer identity and organization → shipment request → validated transport mode and cargo/locations → approved, valid quote → customer acceptance → payment/credit decision → eligible partner matching → partner acceptance and assignment → dispatch/collection → authorized tracking milestones → delivery evidence/POD → invoice and financial allocation → provider payable and settlement → customer support/feedback → repeat-business measurement.

Every transition must be authorized, tenant-scoped, auditable, idempotent where appropriate, and recoverable. Failures must create actionable exceptions. No browser redirect may be treated as proof of payment or delivery.

## 3. Workstream launch gates

### Gate 1 — Data integrity and booking
- Investigate historical shipments missing transport modes using authoritative booking evidence; never guess or bulk-fill.
- Verify the booking UI sends the exact supported RPC arguments and that server validation persists the requested mode.
- Verify idempotency, organization ownership, location/cargo validation, shipment status, and initial shipment-leg creation.
- Preserve legacy records unless a defensible mapping is available.

### Gate 2 — Pricing and quotations
- Configure real, approved rate cards with positive commercial prices, currency, validity, service/route scope, surcharges/taxes where applicable, and approval evidence.
- Verify quote calculations, expiry, acceptance, duplicate prevention, and audit history.
- Do not create a quote or partner opportunity from missing/ambiguous transport data.

### Gate 3 — Verified fulfilment network
- Complete real partner registration, document upload, human/authorized review, service capability, route coverage, capacity, insurance/authorizations where applicable, and commercial terms.
- Only eligible verified partners may quote, accept, or receive assignments.
- Match by route, mode, cargo requirements, capacity, schedule, eligibility, service quality, and approved price.
- Never manufacture partner profiles, capacity, or verification.

### Gate 4 — Shipment operations
- Prove assignment, acceptance, dispatch, collection, milestones, exception handling, delivery, and POD persist against the same shipment.
- Build and verify warehouse facility, receiving, inventory, movement, dispatch, and exception persistence before enabling live warehouse actions.
- Prevent delivery or settlement when required evidence/conditions are missing.
- Test delays, rejection, reassignment, cancellation, claims, and recovery.

### Gate 5 — Payment and finance
- Keep test and live environments separate.
- Verify order creation, provider-side payment status, webhook signature, event idempotency/replay handling, amount/currency/order/shipment linkage, and reconciliation.
- Verify failed payments, retries, duplicate events, cancellations, refunds, disputes, and provider outages.
- Record customer funds, KRIM revenue, provider payables, fees, refunds, invoices, settlements, and payouts distinctly.
- Do not use live keys until test-mode payment and financial reconciliation passes.
- Store all provider secrets server-side; never commit or expose them in frontend code.

### Gate 6 — Security, compliance and reliability
- Review exposed SECURITY DEFINER functions and grants individually; do not blanket-revoke or weaken policies.
- Test role permissions, organization isolation, MFA, protected admin actions, storage access, public tracking, audit trails, abuse protection, and rate limits.
- Apply market-specific privacy, tax, trade, customs, sanctions/restricted-party, cargo, insurance, and data-transfer checks as applicable.
- Verify monitoring, backup/restore, migration discipline, incident response, retries, and rollback.

### Gate 7 — Support and communications
- Persist enquiries, support cases, notifications, follow-up state, delivery attempts, and escalation.
- Separate transactional notices from consent-based marketing.
- Test failed email/message delivery, customer complaints, disputes, delays, refunds, and escalation ownership.

### Gate 8 — Global Autonomous Growth Engine
Build a measurable, permission-aware acquisition funnel:
1. Market and corridor intelligence.
2. Customer prospect discovery from permitted public business information, search demand, referrals, directories, and approved integrations.
3. Partner prospect discovery and coverage-gap identification.
4. Public service pages and useful industry content.
5. Customer enquiry capture and persistent CRM.
6. Partner invitation, registration, document completion and verification workflow.
7. Lead qualification by route, mode, cargo, timing, capacity and service availability.
8. Approved quote/booking conversion.
9. Permissioned and rate-limited follow-up.
10. Campaign/referral attribution, conversion and completed-shipment analytics.
11. Customer feedback, repeat booking and partner performance retention.
12. Experimentation to improve qualified leads, fulfilment and contribution—not vanity metrics.

Automation must not fabricate prospects, scrape restricted data, spam, misrepresent availability, approve providers, promise unverified routes, or spend beyond an explicitly approved budget. Start with low-cost/organic acquisition and partner-first coverage. Paid campaigns are optional and require owner-approved budgets and evidence of unit economics. Every lead must be traceable from source to qualified enquiry to booking to completed shipment and contribution.

### Gate 9 — Global market activation
Maintain per-market readiness states: researching → preparing → pilot-ready → active → paused. A market may be advertised as serviceable only when legal/commercial review, verified partners, service capacity, pricing, payments, compliance, support, and operational testing pass. Support for a country in the database does not mean commercial coverage there.

### Gate 10 — Controlled launch
- Automated technical/static checks pass.
- Test-mode end-to-end success and failure scenarios pass.
- A genuine eligible partner and approved rate are available.
- A controlled live payment is verified against provider records and reconciled internally.
- A real pilot shipment is physically fulfilled with tracking and POD evidence.
- Financial allocations, provider obligations, refund path, support, and incident response are checked.
- Launch decision records any known limitations, responsible owner, and rollback/stop conditions.

## 4. Global platform capabilities required over time

- International country/market/location/currency/time-zone/language/address/measurement support.
- Road, rail, ocean, air and multimodal shipment/leg model.
- Jurisdiction-aware identity, business verification, trade documents, customs and compliance.
- Customer, partner, enterprise, driver, warehouse, customs, finance, operations and privileged control workspaces with least-privilege access.
- Partner matching, capacity, performance, exception, claims and service recovery.
- Payment-provider abstraction and market-appropriate methods; providers enabled only after approval and verified tests.
- ERP/TMS/WMS, carrier, tracking, port/terminal, customs, accounting, mapping and communication integrations when authorized and commercially available.
- AI assistance for enquiry qualification, document extraction, quote assistance, matching, support, forecasting and anomaly detection, always subject to the same permissions and evidence rules.
- Reliability: monitoring, backups, restore tests, retry/idempotency, incident management, rollback and auditability.
- Sustainable finance: contribution by shipment/route/customer/channel, acquisition cost, repeat rate, provider payables, cash flow and operating expenses.

## 5. Acquisition and business metrics

Track real production metrics, separating test/demo data:
- Qualified enquiries by source, country, segment and route.
- Enquiry-to-quote, quote-to-booking, payment success, partner acceptance and completed-shipment conversion.
- Time to assign, pickup/delivery reliability, exception rate, claims and customer satisfaction.
- Verified active partners and usable capacity by route/mode.
- First-time vs repeat customers and repeat-booking rate.
- Gross transaction value separately from KRIM-recognized revenue.
- Provider payables, refunds, payment fees, variable costs, contribution per shipment, acquisition cost and fixed operating costs.
- Campaign spend and ROI only where spending was authorized.
- Automation execution, delivery/failure rates and escalation time.

No target, forecast, or AI estimate should be presented as actual performance.

## 6. Operating safeguards
- No fake production data or fabricated evidence.
- No mass repair of historical records without authoritative mapping.
- No weakening RLS, verification, payment, or role checks to make a test pass.
- No provider/customer marketing outside applicable law, permissions, consent, or platform rules.
- No uncontrolled ad spend or irreversible automated financial actions.
- No launch claim without evidence.
- Preserve working pages and shared architecture; fix the smallest proven blocker first.
- Keep test and production data clearly separated.
- Every implementation change must have a verifiable test and an auditable commit/migration.

## 7. Current verified blockers at plan baseline (2026-10-25)
These are the last recorded production findings and must be refreshed before acting on data:
- 17 shipment rows were missing `requested_transport_mode`; values must not be guessed.
- No active positive-price rate card was found.
- No eligible/open partner opportunity remained after stale opportunities were closed.
- No partner quotes or assignments were found in the latest audit.
- One paid order/payment chain required provider-backed reconciliation; no assumed reconciliation.
- Warehouse operational schema/actions were previously reported incomplete and require a fresh check.
- Several authenticated-callable SECURITY DEFINER functions and performance-advisor findings require review.
- Scheduled workflow/growth workers have run successfully in the past, but this alone does not prove external prospect ingestion, lawful outreach, customer acquisition, or revenue.
- Source-level smoke/link checks have passed on previous commits; latest commit and production workflow results must be rechecked after each change.

## 8. Execution order
1. Refresh latest CI/deployment and production status.
2. Resolve booking/RPC transport-mode defect and historical-data classification.
3. Verify valid quote/pricing path.
4. Complete real partner verification and route capacity.
5. Prove assignment-to-POD operations (including warehouse schema gap).
6. Reconcile test payments and financial ledger; verify refund/failure cases.
7. Review critical security and recovery controls.
8. Verify support, notification and enquiry persistence.
9. Implement/verify the growth engine only against real serviceability and approved limits.
10. Run full test-mode end-to-end audit.
11. Configure live Razorpay and other approved providers; keep credentials server-side.
12. Run controlled low-value live payment and reconcile.
13. Conduct founder manual acceptance testing.
14. Complete a real controlled pilot.
15. Approve launch only after gates pass; activate new markets incrementally.

**This is an execution contract, not a claim that all capabilities are already implemented. Update status with evidence after each workstream.**