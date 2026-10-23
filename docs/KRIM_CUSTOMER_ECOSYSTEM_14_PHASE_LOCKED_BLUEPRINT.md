# KRIM Customer Ecosystem — 14-Phase Locked Blueprint
**Version:** 1.0  
**Established:** 2026-10-23  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Status:** Canonical scope and acceptance contract — implementation is NOT yet certified complete.

> This document locks the intended customer journey, phase boundaries, and acceptance criteria. It does not freeze software against security fixes or necessary improvements. Changes to scope or canonical routes require a documented change record, dependency review, regression tests, and an explicit approval. Never claim a phase is verified from a page existing or a static smoke test alone.

## 1. Non-negotiable operating rules

1. **One canonical route per purpose.** Existing aliases may redirect to the canonical route when needed for backward compatibility. Never delete a page until references, inbound links, scripts, tests, redirects, and deployment dependencies are checked.
2. **One source of truth per business record.** Use the established canonical database entities and RPC/Edge Function contracts. Do not introduce parallel shipment, quote, payment, or customer records to work around a defect.
3. **Real state only.** Never show demo prices, fake tracking, invented capacity, false partner assignment, or a success state before the backend confirms it. Label previews and test data clearly.
4. **Customer convenience without false promises.** A user can start from a village, rural collection point, town, city, industrial area, warehouse, airport, or seaport. Show only verified service options; if a location is unsupported, provide a coverage-request path and explain the next step.
5. **Secure by default.** Authenticate users; verify active organization membership and record ownership on the server/database; rely on RLS and server-side authorization for data isolation. Client-side hiding/redirects are not a security boundary.
6. **Every action has feedback.** Buttons must lead somewhere valid or perform a real action. Show loading, success, empty, and recoverable-error states; disable duplicate submissions; preserve entered data on recoverable failure where safe.
7. **No destructive cleanup by guesswork.** Inspect dependencies and data first. Keep backward-compatible redirects where useful. Do not delete production records or schema as part of page cleanup.
8. **Mobile-first and global-ready.** Keyboard accessible, readable on low-width screens, resilient to slow networks, explicit about language, currency, units, time zone, local rules, route coverage, and supported payment methods. Do not imply every country or lane is already operational.
9. **Audit evidence is required.** Save test steps, environment, timestamp, expected/actual result, evidence/reference, and defects. Static link checks prove neither authentication nor business transactions.
10. **No phase is “done” by design alone.** A phase closes only after its exit criteria pass in the deployed environment, including negative/security cases where relevant.

## 2. Canonical end-to-end customer loop

Discover KRIM → create account/sign in → select organization/workspace → enter origin, destination, cargo and service needs → validate route/location coverage → create a shipment request → obtain eligible saved quotations → compare full commercial terms → accept a valid quote → verify booking/payment eligibility → create payment order → pay through supported provider → verify payment server-side/webhook → confirm booking and partner assignment when required → pickup and custody scan → line-haul/transshipment/warehouse/customs milestones as applicable → exception alerts and resolution → final-mile delivery → proof of delivery (POD) → invoice/credit/refund and partner settlement reconciliation → close shipment with an auditable record → request feedback/support → repeat or schedule recurring shipment.

**Truthful state distinction:** shipment request ≠ accepted quote ≠ confirmed booking ≠ paid transaction ≠ carrier assigned ≠ picked up ≠ delivered ≠ financially reconciled. Each is a separate state supported by a record or verified event.

## 3. The 14 locked phases

### Phase 1 — Global customer entry, account and access
**Goal:** A new or returning customer can reach the correct customer journey without dead ends or role confusion.  
**Scope:** Public homepage links, signup, sign-in, recovery, session handling, organization provisioning/membership, logout, redirects and access-denied recovery. Keep privileged admin access separate from public customer entry.  
**Acceptance gate:**
- Test new customer signup, email verification if configured, sign-in, refresh/session persistence, logout and sign-in again.
- Test password recovery end-to-end and expired/invalid links.
- Test no-session, no-active-membership and wrong-role paths; provide clear recovery instructions.
- Each public customer CTA resolves to an existing canonical destination.
- No public customer navigation exposes privileged admin entry.
**Evidence:** deployed browser tests + auth/organization records + route scan.  
**Status at establishment:** NOT VERIFIED end-to-end.

### Phase 2 — Global location, coverage and service discovery
**Goal:** Customers can enter practical origin/destination locations and understand real serviceability.  
**Scope:** Country → state/region/province → city/town → locality/postcode/hub where data supports it; pickup/delivery type; route/mode eligibility; coverage request; service constraints and estimated service information.  
**Acceptance gate:**
- Validate configured locations and country/region/city relationships; handle empty, duplicate and ambiguous results.
- Validate rural/remote address input without forcing a false nearby-city substitution.
- Unsupported locations create a traceable coverage inquiry or a clear next step.
- Do not promise carrier availability, delivery dates, customs clearance or rates without verified source data.
- Store/display units, local time zones, and location labels consistently.
**Evidence:** test matrix covering configured, unsupported, ambiguous and international lanes.  
**Status:** NOT VERIFIED.

### Phase 3 — Shipment creation
**Goal:** A signed-in customer can create one accurate, authorized shipment request.  
**Scope:** Origin/destination, cargo description, package/weight/dimensions where required, mode/service preference, ready date, special handling, documents/notes, validation, duplicate-submit protection and confirmation.  
**Acceptance gate:**
- Form validation explains missing/invalid fields and preserves safe inputs after recoverable errors.
- Backend/RPC validates the session, active organization and input; client-side checks alone are insufficient.
- Exactly one authorized `krim_shipments` record is created on a successful submission; failures do not show success.
- Customer receives a real reference and next steps; a request is not described as a confirmed booking.
- Customer can open that exact record from the register.
**Evidence:** before/after database record, error-path test, duplicate-submit test and ownership test.  
**Status:** NOT VERIFIED in a live end-to-end test.

### Phase 4 — Quotations and pricing
**Goal:** Customer can request, receive and compare real commercial offers.  
**Scope:** Quote request, partner/rate-card sourcing, quote list/detail, currency, validity, inclusions/exclusions, taxes/surcharges, transit assumptions, revision/rejection/expiry, comparison and approval where applicable.  
**Acceptance gate:**
- Every displayed quote maps to a saved authorized record and its shipment.
- No invented or placeholder price appears as a real offer.
- Only approved and eligible rates are used where rate-card policy applies; otherwise show unavailable/needs review.
- Currency is explicit; do not add unlike currencies without a verified conversion source and timestamp.
- Expired, withdrawn, rejected or ineligible quotes cannot be accepted.
- Partner/customer organization boundaries are enforced.
**Evidence:** quote creation/read/expiry/ownership tests and pricing-source audit.  
**Status:** NOT VERIFIED.

### Phase 5 — Booking, quote acceptance and payment
**Goal:** A valid accepted offer can become a confirmed commercial transaction with reliable payment evidence.  
**Scope:** Quote acceptance, booking readiness, order creation, provider checkout, signature/webhook verification, idempotency, payment status, receipts, failed/cancelled/pending/refund paths. Current provider capability must be stated accurately; do not imply global payment coverage if only specific currencies/providers are enabled.  
**Acceptance gate:**
- Quote acceptance is server-validated against ownership, status, validity and applicable partner linkage.
- Order amount/currency are derived from the accepted quote server-side, not trusted from browser input.
- Payment success is recorded only after trusted provider verification/webhook; a return URL or order creation is not proof of payment.
- Duplicate callbacks/retries do not double-charge or duplicate ledger entries.
- Failed, abandoned, pending, disputed and refunded payments show accurate states and recovery guidance.
- Receipt and booking confirmation correspond to verified records.
**Evidence:** sandbox transaction matrix, webhook/signature/idempotency logs, ledger reconciliation. Never test with live charges without explicit authorization.  
**Status:** NOT VERIFIED end-to-end.

### Phase 6 — Customer shipment register and dashboard
**Goal:** One dependable place to see the customer's own shipment portfolio and next actions.  
**Scope:** Canonical shipment-list route, search/filter/sort/pagination, status summary, shipment detail links, quote/payment/support actions, empty/loading/error states.  
**Acceptance gate:**
- List is populated from real `krim_shipments` records scoped to the active authorized organization.
- Counts and filters agree with returned records; no demo records appear in production.
- Opening a row shows that shipment's reference and authorized details.
- Empty and error states explain what to do next.
- Each action points to an existing canonical route and carries required identifiers safely.
**Evidence:** multi-record tests across two organizations plus route checks.  
**Status:** Page implementation exists; live scope/filter/action behavior still requires independent verification.

### Phase 7 — Tracking, timeline and notifications
**Goal:** Customers can understand current status, milestone history and changes without misleading them.  
**Scope:** Shipment timeline, tracking/map when data exists, event timestamps, location, notification preferences and delivery updates.  
**Acceptance gate:**
- Timeline is sourced from authorized persisted events; chronological order and time zone are correct.
- No location is presented as live GPS unless a live source actually provides it; stale/estimated events are labeled.
- Notifications are triggered only by confirmed events, are not duplicated on retries, and avoid exposing sensitive shipment data.
- Customer can distinguish “not yet available” from “delayed” and “delivered.”
- Unauthorized users cannot read another organization's tracking records.
**Evidence:** milestone-event tests, notification delivery/logs, freshness and RLS tests.  
**Status:** NOT VERIFIED.

### Phase 8 — Pickup and custody handover
**Goal:** Customer knows whether pickup is requested, scheduled, attempted, completed or failed.  
**Scope:** Pickup readiness, appointment/window, driver/partner assignment when authorized, collection checklist, scan/OTP/signature or other configured evidence, failed pickup and rescheduling.  
**Acceptance gate:**
- Pickup is not shown as scheduled until an authorized operational record confirms it.
- Pickup completion requires a permitted event/evidence record with timestamp and actor.
- Failed/attempted pickup has a reason and next action.
- Customer and driver see only data needed for their role.
- Repeated event submissions are idempotent or clearly reconciled.
**Evidence:** customer-to-operations/driver workflow test with event and access logs.  
**Status:** NOT VERIFIED.

### Phase 9 — Transport, warehouse, customs and cross-workspace execution
**Goal:** Each applicable leg is coordinated across operating workspaces with clear custody and compliance.  
**Scope:** Partner/carrier assignment, dispatch, legs/transshipment, warehouse in/out, customs documents/status/holds, exceptions, operational handovers and service-specific workflow.  
**Acceptance gate:**
- Assignment is persisted and authorized; no partner is implied merely because a quote exists.
- Every handover/scan/warehouse event is attributable, timestamped and linked to the shipment.
- Customs steps are shown only when relevant and require applicable documentation/review; KRIM does not claim official clearance without evidence.
- Holds, missing documents, failed handovers and exceptions have owners and next actions.
- Customer-facing status reflects operational source-of-truth events.
- Workspace boundaries and RLS are tested for customer, partner, driver, warehouse, customs and operations roles.
**Evidence:** multi-role test shipment through applicable legs, event history and policy tests.  
**Status:** NOT VERIFIED across workspaces.

### Phase 10 — Final-mile delivery and proof of delivery
**Goal:** Delivery is recorded with appropriate evidence and visible to the authorized customer.  
**Scope:** Out-for-delivery, delivery attempt, recipient confirmation, timestamp/location where appropriate, configured signature/photo/POD, refusal/damage/partial delivery and dispute path.  
**Acceptance gate:**
- Delivery status changes only through an authorized workflow.
- POD is stored in the intended private storage location with access controls and ownership checks.
- Customer can view/download only their own permitted evidence.
- Failed, refused, damaged or partial deliveries are not marked as successfully delivered without correct status/evidence.
- Evidence retention and privacy rules are documented.
**Evidence:** successful and failed delivery tests, storage access tests, status/audit trail.  
**Status:** NOT VERIFIED.

### Phase 11 — Finance, invoices, refunds and closure
**Goal:** Customer can reconcile what was quoted, accepted, charged, credited and settled.  
**Scope:** Invoice/receipt, taxes/fees, payment ledger, refunds/adjustments, partner settlement references, disputes, reconciliation and closure.  
**Acceptance gate:**
- Amounts reconcile to accepted quote and verified payment/adjustment records.
- Invoice/receipt is not fabricated or issued as paid before payment verification.
- Refunds and adjustments are separate auditable entries; never silently rewrite the original transaction.
- Partner settlement is not inferred from customer payment.
- Currency, rounding, tax assumptions and transaction references are explicit.
- A shipment closes financially only when required balances/reconciliation rules pass; operational completion and financial closure remain distinct.
**Evidence:** ledger reconciliation, invoice checks, refund/adjustment scenarios and finance authorization tests.  
**Status:** NOT VERIFIED.

### Phase 12 — Support, claims and exception resolution
**Goal:** Customers can get help and follow a traceable case to resolution.  
**Scope:** Support ticket creation/list/detail, shipment/payment linkage, claim or damage flow, attachments, priority, case ownership, responses, status, escalation and closure feedback.  
**Acceptance gate:**
- Ticket submission creates a real record and returns a reference; no fake success.
- Ticket and attachment access is organization-scoped and follows private-storage policy.
- Customer sees case status and clear expected next action without promising unsupported SLA.
- Payment, delivery, customs and technical issues route to an appropriate queue or owner.
- Repeated submissions and replies are auditable; secrets/payment-card data are not requested.
**Evidence:** create/reply/escalate/close tests and access-control tests.  
**Status:** NOT VERIFIED.

### Phase 13 — Retention, repeat and recurring shipments
**Goal:** After successful service, customers can easily repeat work and give feedback without re-entering everything.  
**Scope:** Feedback/NPS or equivalent, issue follow-up, saved shipment templates, recurring schedules, repeat-booking review, preferences and consent-aware communications.  
**Acceptance gate:**
- Repeat booking copies only safe, permitted fields and always revalidates current rates, coverage, compliance and dates.
- Recurring jobs can be reviewed, paused, edited and cancelled; no hidden bookings are generated.
- Feedback links to the correct shipment and can be submitted once per defined policy.
- Marketing/contact preferences and opt-outs are respected.
- Retention metrics use real events and do not manufacture success claims.
**Evidence:** repeat/recurring lifecycle tests, consent tests and event analytics checks.  
**Status:** NOT VERIFIED.

### Phase 14 — Global accessibility, security, reliability and governance
**Goal:** All phases work as a coherent, accessible, secure and maintainable global service.  
**Scope:** Mobile and low-bandwidth UX, accessibility, languages, currencies, time zones, local formats, service coverage truthfulness, performance, monitoring, backup/recovery, RLS, audit logs, route integrity, incident handling and change governance.  
**Acceptance gate:**
- Automated link/path checks and manual browser navigation cover all customer-facing routes and JS-generated links.
- No broken customer CTA, unresolved duplicate logical route, unsafe redirect or console-breaking runtime error in supported browsers.
- Test at narrow mobile widths, keyboard-only use, reduced motion and slow network; key actions remain understandable.
- RLS and server-side authorization tests include cross-organization negative cases; client-side guards are not treated as security.
- Secrets stay server-side; public static hosting is never treated as private delivery.
- Monitoring, backup/restore expectations, incident owner and rollback plan are documented.
- Release has smoke tests, phase-specific regression tests and a reversible change plan.
**Evidence:** CI results, manual test log, security/RLS matrix, performance/accessibility findings and release record.  
**Status:** NOT VERIFIED as a complete system.

## 4. Phase dependencies and release order

**Gate A — Foundation:** Phases 1, 2 and 14's baseline security/route checks.  
**Gate B — Commercial request:** Phases 3, 4 and 6.  
**Gate C — Transaction:** Phase 5, with Phase 14's secure payment and audit controls.  
**Gate D — Fulfilment:** Phases 7, 8, 9 and 10 across relevant roles.  
**Gate E — Financial and service closure:** Phases 11 and 12.  
**Gate F — Retention and global readiness:** Phases 13 and final Phase 14 regression.

A phase can be developed in parallel, but cannot be certified before its dependencies pass. Do not skip a blocked phase and represent the whole loop as operational.

## 5. Mandatory status vocabulary

- **NOT AUDITED** — no evidence review yet.
- **AUDIT IN PROGRESS** — evidence is being collected.
- **BLOCKED** — a concrete dependency/defect prevents the acceptance test.
- **IMPLEMENTED — UNVERIFIED** — code/page exists but acceptance tests have not passed.
- **VERIFIED** — all phase acceptance criteria passed in the specified environment with saved evidence.
- **NOT APPLICABLE** — only for a shipment-specific conditional workflow, with a recorded reason; never use this to hide an unimplemented phase.

**Initial phase baseline:** No phase is certified VERIFIED by this blueprint. Existing pages and prior smoke-test reports are useful evidence but are not a substitute for live transaction and security tests. Re-audit all 14 phases against the criteria above and update status only with evidence.

## 6. Route and duplicate governance

Before any page is rebuilt, renamed, redirected or deleted:
1. Inventory all HTML, JS-generated links, forms, redirects, scripts, imports, tests, workflows and inbound links.
2. Assign each logical function exactly one canonical route and list approved compatibility redirects.
3. Search all references to each proposed removal and inspect runtime navigation.
4. Verify the replacement implements the same or better behavior, permissions and responsive UX.
5. Update route tests and run them; test GitHub Pages path-prefix behavior.
6. Remove only after a clean dependency review; record old path, replacement, rationale, test evidence and commit.
7. Keep customer, admin and specialist workspaces access-separated. Static pages are public source even if their interface redirects.

## 7. Change control and permanent-lock policy

The 14 phase definitions, customer-loop states, security rules, canonical-route discipline and acceptance gates are **locked baseline requirements**. Changes require a written decision record containing:
- proposed change and reason;
- affected phase(s), route(s), schema/API contracts and users;
- backward compatibility and migration/rollback plan;
- security, privacy, financial and accessibility impact;
- acceptance tests and evidence;
- explicit approval and resulting commit reference.

Security fixes, data-integrity fixes, accessibility fixes and defect repairs are allowed without changing the intended scope, but still require regression evidence. No blanket “permanent lock” may prevent essential security or compliance updates.

## 8. Audit log template

For each phase, record:
- Phase / build commit / deployed URL / test environment / date;
- Test case and user role;
- Preconditions and steps;
- Expected result and actual result;
- Database/RPC/Edge Function/event evidence (redact secrets and personal data);
- Security negative test result;
- Defects and severity;
- Status and reviewer.

## 9. Immediate execution sequence

1. Run a full internal-route scan (literal HTML, JavaScript-generated links, redirects, forms, scripts and route prefix).
2. Verify Phase 1 signup/sign-in/session/membership and Phase 2 location coverage in the deployed customer journey.
3. Verify Phase 3 shipment creation and Phase 6 customer register with a test account; confirm database ownership and exactly one record.
4. Verify Phase 4 saved quote and Phase 5 accepted quote → order → trusted payment verification in sandbox.
5. Continue through Phases 7–13 using the same shipment reference across relevant workspaces.
6. Run Phase 14 security, accessibility, mobile, regression and release checks.
7. Only then mark phases VERIFIED and consider duplicate cleanup/rebuild complete.

**Lock statement:** This document is the single scope-and-acceptance baseline for the KRIM Customer Ecosystem. It does not assert that the existing production system already passes these requirements.
