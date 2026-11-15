# KRIM Global Logistics OS — Production Readiness Master Register

Last reviewed: 2026-11-15  
Repository: `rimjhimkrn-web/logistics-saas`  
Production Supabase project: `ebltviniygljwwseplph`

## Purpose

This register is the single release-control record for completing KRIM as an integrated logistics operating system. A page is not considered operational merely because it exists, loads, or passes a static link check.

## Release-state definitions

- **Implemented** — the code/database workflow exists.
- **Deployed** — the intended version is present in the target environment.
- **Tested** — the relevant automated or controlled test passed.
- **Operationally validated** — a genuine authorised user journey completed with real participants and evidence.
- **Blocked** — a legal, security, data, integration, or real-world prerequisite is missing.

Do not promote a workstream to operationally validated without end-to-end evidence.

## Global release gates

| Gate | Current evidence / state | Release requirement |
|---|---|---|
| Real partner network | 0 eligible registered-business partner organisations in latest recorded audit | At least one independently verified partner per enabled service/corridor |
| Partner capabilities | 0 active verified capabilities in latest recorded audit | Approved capability, current compliance, valid service area and evidence |
| Drivers | 0 driver profiles in latest recorded audit | Verified driver, current licence details and accepted evidence |
| Vehicles | 0 vehicles and 0 vehicle-document requirement rows in latest recorded audit | Jurisdiction/category requirements legally reviewed; vehicle and documents independently verified |
| Capacity | 0 resources, availability rows, active reservations and bindings in latest recorded audit | Real resource, availability, booking and concurrency tests |
| Warehouse | Latest direct production count: 0 warehouse tasks and 0 inventory rows | Real facility, receipt, QC, stock, allocation, movement, transfer, return and dispatch journey |
| Customs | Latest recorded audit: 0 customs cases; prior audit showed no active approved jurisdiction requirements | Legal review and approval of jurisdiction-specific rules; verified broker and real authority evidence |
| Shipment execution | Prior production audit: 6 confirmed shipments without partner assignments; no verified partner capacity | Partner acceptance, capacity commitment, driver acceptance, dispatch, trip events and delivery proof |
| GPS | Legal consent and launch gates disabled | Approved privacy notice, legal approval, native-app consent and physical-device testing |
| Freight payments | Hard-blocked under partner-direct commercial model | Separate legal/tax/settlement approval before any change; customer freight remains payable to contracting partner |
| Notifications | Scheduled retry worker exists; no successful delivery evidence in outbox at prior audit | Provider configuration and actual authorised delivery test; HTTP 200 alone is not delivery proof |
| Finance | Several finance pages are templates / browser-side validation only | Real ledger-backed invoices, receivables/payables and referral-fee accounting with tax-reviewed documents |
| Security | Latest advisor snapshot: 26 RLS-without-policy informational findings, 130 generic authenticated SECURITY DEFINER warnings, leaked-password protection warning | Review each finding; retain least privilege; enable auth protection if supported and approved |
| Existing pages | Static audit: 867 product HTML pages, 0 broken local references; runtime and permissions not comprehensively tested | Page/workspace regression matrix and browser/mobile role-based testing |

## Workstream register

### A. Customer and shipment lifecycle
**State: Partially implemented; end-to-end blocked.**

Required release journey:
1. Customer signup and organisation provisioning.
2. Shipment request with validated origin, destination, cargo, dimensions, mode and service constraints.
3. Quote discovery from eligible partners only.
4. Customer selection and commercial acceptance.
5. Partner assignment offer and explicit partner acceptance.
6. Capacity commitment for the planned time window.
7. Driver and vehicle assignment with current evidence.
8. Authorised dispatch and trip execution.
9. Exception handling and customer notifications.
10. Delivery confirmation with independently verifiable proof.
11. Dispute/claim and financial reconciliation.

Release blockers: no eligible partners, verified capabilities, capacity resources, drivers or vehicles. Confirmed customer shipments must not be represented as partner-accepted, assigned, dispatched or delivered.

### B. Partner onboarding and execution
**State: Guardrails implemented; no verified operating partner.**

Required: registered-business onboarding, ownership evidence, organisation compliance, capability evidence, service areas, capacity resources, availability, quote submission, assignment acceptance, execution events, compliance renewal and suspension.

Hazardous-goods and refrigerated capabilities remain fail-closed until specialist jurisdiction-specific evidence and review workflows exist.

### C. Driver and vehicle
**State: Verification safeguards implemented; real onboarding untested.**

Driver licence front/back and identity documents are required; licence expiry is enforced; changes to licence details reopen evidence review. Vehicle verification requires private evidence ownership and applicable requirements.

Vehicle legal requirements must not be guessed or activated from a generic checklist. Configure requirements only after jurisdiction and vehicle-category legal review. GPS remains disabled pending consent/legal approval and physical device tests.

### D. Warehouse
**State: Core controls implemented; transfer/return workflow gaps identified; no live operational data.**

Existing safeguards include QC separation of duties, receipt evidence, inventory write restrictions, idempotency, unit consistency, aggregate-lot quality evidence, task replay checks and dispatch-proof storage ownership checks.

Outstanding:
- Explicit stock reservation/allocation workflow.
- Bin/location-aware stock movements.
- Atomic inter-facility and intra-facility transfers with source/destination validation.
- Returns intake, quarantine, inspection, disposition and restocking/refund linkage.
- Partial picks, short picks, damaged stock and cancellation/reversal paths.
- Concurrency and deadlock tests using controlled fixtures.
- Real operator/browser tests.

Do not enable transfer/return movement labels as a shortcut. Implement them as complete authorised workflows with atomic balance changes, evidence, audit events and idempotency.

### E. Customs
**State: Security and legal fail-closed controls implemented; jurisdiction rules not approved and no cases/brokers.**

Required:
- Legal-reviewed import/export requirements per country, customs territory, procedure and cargo category.
- Broker licence verification by jurisdiction and validity.
- Declaration/document versioning and evidence provenance.
- Submission receipt/reference from the relevant authority.
- Query/hold/examination/assessment/duty-payment/release/rejection lifecycle as applicable.
- Explicit authority-issued release evidence before marking clearance complete.
- Revalidation on expiry or legal-rule change.

Never present a research checklist as legal advice or approved jurisdiction rules.

### F. Finance and commercial model
**State: Partially implemented; several pages are templates; freight collection disabled.**

Initial partner-direct model:
- Customer contracts with and pays the logistics partner directly.
- Partner invoices customer for freight.
- KRIM invoices partner separately for an agreed referral/technology/coordination service, where contractually and tax-valid.
- KRIM does not collect freight or pay out partner freight funds.
- Razorpay may only be considered for KRIM's own fees/subscriptions after merchant, tax and invoice configuration is reviewed.
- GST/ECO/TCS treatment requires a written CA opinion; do not assume exemption.

Outstanding: referral-fee accrual/reconciliation, invoices, receivables/payables, refunds limited to KRIM's own supplies, tax reporting and finance close.

### G. Control Tower, enterprise and administration
**State: Mixed implementation; role-based runtime coverage incomplete.**

Required: tenant isolation, scoped operational views, event timeline, SLA clocks, exception ownership/escalation, auditable overrides, enterprise locations and permissions, admin AAL2 controls, incident review and operational reporting.

### H. APIs, webhooks and integrations
**State: API/Webhooks page exists; integration validation incomplete.**

Required: API authentication and scopes, idempotency, replay protection, signature verification, rate limits, schema/version policy, webhook retries/dead-letter handling, observability, secret rotation and documented partner integration tests.

### I. Notifications
**State: Scheduled workers deployed; actual provider delivery not yet evidenced.**

Test Telegram with an explicitly authorised founder test. Keep Resend/domain sending setup as the final notification integration step. Track provider message IDs and ambiguous timeout outcomes; avoid blind retries that can duplicate external messages.

## Existing release constraints

- Keep Page 46 paused until the existing 45 workspaces have a documented regression/release result.
- Defer Android APK builds until December 2026 due to the current build quota pause.
- Do not enable GPS collection until legal consent and native-device validation gates pass.
- Do not reactivate Cashfree or platform freight collection.
- Do not enable payouts, automated freight settlement or refund execution under the partner-direct model.
- Do not seed customs or vehicle legal requirements without jurisdiction-specific authoritative review.
- Do not claim production readiness based solely on static audits, SQL definition inspection, or successful deployment.

## Required regression evidence for every workspace

For each route/workspace record:
1. Canonical route and owner role.
2. Authentication and organisation-membership requirements.
3. RLS and RPC permission checks.
4. Primary success path.
5. Invalid-input and permission-denied paths.
6. Duplicate-submit/idempotency path.
7. Concurrent-update path where relevant.
8. Expiry, cancellation, rejection and recovery paths.
9. Mobile viewport and keyboard behaviour.
10. Audit/event/notification side effects.
11. Browser runtime result and deployment SHA.

## Exit criteria for production candidate

KRIM may be called a **production candidate for a specifically named corridor and service**, not universally production-ready, only when:
- A real partner, capability, capacity resource, driver and vehicle are verified for that corridor.
- Customer-to-partner booking and acceptance succeeds.
- Dispatch and trip execution succeed with correct authorisation.
- Delivery proof is independently verified.
- Exceptions, cancellation and retry paths are tested.
- Commercial invoices and money flows match the approved partner-direct model.
- Security, RLS and regression checks pass for all involved roles.
- Legal requirements and privacy notices for that corridor are approved.
- Monitoring, support ownership and recovery procedures are in place.

Global availability must be enabled country-by-country and service-by-service after equivalent validation.

## 15 November 2026 — multi-leg dispatch execution update

The multi-leg execution foundation now includes the following deployed database controls:

- Exact-leg dispatch authorisation records, separate from physical pickup and departure.
- Dispatch authorisation requires an accepted exact-leg partner assignment, shipment.dispatch permission, an assigned leg, a confirmed physical capacity binding and its partner-owned confirmed reservation.
- Road authorisation requires an accepted driver assignment, active driver membership, verified driver/current licence evidence, an active verified vehicle, active driver-vehicle binding and current mandatory vehicle documents.
- An insert guard requires an active multi-leg route plan and an exact matching plan item, partner, current registered-business verification/compliance and exact-leg capability.
- Driver pickup and transit events require an active exact-leg dispatch authorisation for multi-leg road legs. Shipment-level status remains unchanged while individual multi-leg legs move in transit. The ordinary single-leg path remains preserved.
- Dispatch authorisation can be revoked with a reason before pickup/transit. Only one active authorisation per leg is permitted; prior revoked records are retained.
- Driver pickup/transit revalidates the current plan item, assignment, partner compliance, capability, capacity binding/reservation and accepted custody.
- Non-road dispatch is deliberately held until mode-specific verified resource and execution controls are implemented.

Repository migration files are aligned to the actual production migration versions:
- 20261115144628_add_exact_leg_dispatch_authorization.sql
- 20261115144752_integrate_multileg_dispatch_authorization_with_driver_events.sql
- 20261115145000_guard_leg_dispatch_plan_partner_and_mode_readiness.sql
- 20261115145401_add_dispatch_revocation_and_revalidate_at_driver_execution.sql

The latest KRIM production smoke workflow and static local-link audit passed on commit b4e9397e2cd716634c963abc3fe4f45d8e9c8041; GitHub Pages deployment also succeeded. The smoke test is static regression evidence, not a live transaction or browser end-to-end test.

Current operational data remains empty for this path: zero active multi-leg plans, zero accepted leg-specific partner assignments, zero dispatch authorisations and zero driver trip events. No synthetic operational data was inserted. Positive end-to-end testing still requires real verified partners, exact capabilities, active lanes, confirmed physical reservations, drivers, vehicles and private evidence.

Latest Supabase advisor snapshot: no health findings; 29 RLS-enabled/no-policy informational findings; 140 generic authenticated SECURITY DEFINER warnings; leaked-password protection remains disabled. These findings require individual risk triage; do not blanket-add policies or revoke legitimate RPCs. The dispatch authorization table intentionally has no direct client table grants and is accessed through narrowly scoped RPCs.

### Page-sequence handoff note

The API & Webhooks workspace (public/partner/api-webhooks.html, identified as Page 45 in the active 103-page review sequence) remains an informational/read-only integration-access page. It does not expose API credentials or claim that endpoint creation, key rotation, secret display or webhook replay are available. The latest repository static link audit reported no broken literal local references. This is not proof of browser/RBAC/runtime behavior.

Page 46 remains paused until Pages 1–45 have documented regression/release results, in accordance with the established page-review rule. The latest passing static link audit and production smoke workflow are supporting evidence only; they do not complete the page-by-page visual, browser, role-permission and functional regression audit. The overall platform must not be described as globally production-ready. Real partner/capacity/driver operations, non-road resource controls, warehouse transfer/returns, customs legal approvals, finance/tax workflows, notification delivery and role-based browser testing remain open.
## Dispatch-readiness evaluator alignment (15 November 2026)

Migration 20261115150526_align_dispatch_readiness_with_multileg_authorization replaces the readiness evaluator without changing its return contract or caller permissions. It now recognises the active multi-leg shipment lifecycle (assigned/in_transit) instead of requiring every shipment to remain shipment-wide assigned; validates exact active plan-item/leg/partner-assignment binding; uses exact-leg capability evaluation for multi-leg and retains the shipment-level capability evaluator for legacy single-leg; and reports blockers for missing accepted driver assignment, current exact-leg dispatch authorization, confirmed physical capacity and accepted custody. It keeps non-road dispatch fail-closed and retains the warehouse handover and ROAD driver/vehicle checks.

Live verification: function is SECURITY DEFINER with empty search_path; anonymous EXECUTE is false; authenticated EXECUTE is true. The function returned zero rows because there are no accepted/active partner assignments in the current live data. Therefore the function definition/ACL were verified, but no positive readiness case or real dispatch journey was exercised.

Automated regression smoke checks now assert these readiness safeguards. Browser-based role testing and a real authorised dispatch journey remain open.
## Leg-scoped POD and multi-leg completion (15 November 2026)

Live migration 20261115150904_support_leg_scoped_delivery_pod_and_completion aligns delivery proof with the per-leg execution model. POD submission for an active multi-leg shipment no longer incorrectly requires the shipment aggregate status to be shipment-wide in_transit; it instead requires the shipment to remain in its active lifecycle, the exact leg to be in_transit, and the partner assignment to match the exact active plan item, sequence, endpoints and mode. Existing driver-owned private evidence and payload-idempotency checks are retained.

After independent POD verification, multi-leg delivery authorization marks only that exact leg completed and its partner assignment completed. It keeps the overall shipment status unchanged while later plan legs remain, emits leg_delivered events, and marks the shipment delivered only when every planned item is materialized and completed/delivered. This preserves the custody-transfer prerequisite for the next partner. The legacy single-leg delivery path remains supported.

Live database function definitions were re-read after migration; both functions remain SECURITY DEFINER with empty search_path. There are no real PODs, active multi-leg plans or driver journeys in production data, so no positive end-to-end journey was run. Automated smoke assertions were added; browser/admin review and real evidence-based execution remain pending.
## Multi-leg finance posting safety gate (15 November 2026)

Live migration `20261115151545_block_unallocated_multileg_finance_postings` adds a private SECURITY DEFINER trigger guard with an empty search_path to customer invoices, partner payables, revenue allocations and shipment revenue items. It rejects writes tied to an active multi-leg shipment until leg-level commercial allocation, partner-direct invoicing and KRIM fee recognition are explicitly reconciled. This is a fail-closed interim guard, not a completed multi-leg finance workflow.

Reason: legacy finance routines select a single completed assignment / shipment-wide quote and cannot safely represent several partner legs, customer-to-partner freight invoices, or KRIM's separate referral/coordination fee. The launch model is partner-direct: customer pays the logistics partner; KRIM separately invoices its agreed fee. Do not use platform invoice/payable routines to collect or settle freight.

Live verification: all four triggers are installed. Current invoice, payable, revenue-allocation and shipment-revenue-item tables contain zero rows associated with active multi-leg plans. The database guard and repository smoke assertions are in place; a deliberate write-failure test was not run against real commercial data. Finance remains a release blocker for multi-leg commercial execution until a reviewed leg-level settlement/commission model is implemented.

## Custody-transfer response audit correction (15 November 2026)

Migration `20261115151811_correct_custody_transfer_response_audit_fields` adds `responded_by` and `responded_at` to custody-transfer records. The response RPC now records those fields for both acceptance and rejection, while `accepted_by` and `accepted_at` are populated only on acceptance. Rejection reason remains separately recorded. This corrects the prior semantic defect in which a rejecting actor was stored in fields named as acceptance metadata.

The migration was applied to the live database, matching SQL was committed, and production smoke assertions were added. There were zero custody-transfer rows at migration time, so no historical rows required correction. No synthetic transfer was created and no positive handoff E2E test was claimed.
