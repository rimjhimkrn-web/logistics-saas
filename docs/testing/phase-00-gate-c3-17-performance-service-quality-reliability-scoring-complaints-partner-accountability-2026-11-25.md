# Gate C3.17 — Performance, service quality, reliability scoring, complaints and partner accountability

**Programme:** KRIM GLOBAL PLATFORM — AI QUALITY ASSURANCE, SIMULATION & RELIABILITY PROGRAMME  
**Gate:** Phase 00 / C3.17  
**Source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**QA branch:** `qa/phase-00-baseline-2026-11-25`  
**Review date:** 2026-11-25  
**Disposition:** **PARTIAL PASS / BLOCKED — NO-GO for live partner rankings, published performance scores, public customer ratings, guaranteed SLA attainment or automated partner sanctions.**

## 1. Scope and method

Read-only review of:
- Driver performance and quality page and its staging counterpart.
- Partner performance and quality preview and legacy performance aliases.
- Carrier reliability/ESG scorecard.
- Customer ratings and reviews canonical page.
- Operations Service Performance & SLA page and staging service performance/SLA workspace.
- Customer/partner complaint pages and canonical support ticket backend.
- Support ticket status, response and resolution timestamps and internal SLA trigger.
- Driver trip-event RPC access grant.

The source baseline was fixed at `72d75a18f985ceb09e468839435ee95700e11e46`. This is a source review, not a live database query or runtime test. No customer review, rating, complaint, score, SLA record, partner sanction or support ticket was created or modified. No RPC, notification, provider, external party or live shipment record was invoked or contacted. No Production or Staging data was accessed or changed.

## 2. Positive source controls

1. **Driver page avoids inventing a score.** The authenticated driver performance page loads the signed-in user's active driver membership, active organization, driver assignments, trip events and delivery-evidence metadata. It explicitly states that activity counts are not a performance score or proof of delivery and does not manufacture punctuality or customer satisfaction results.
2. **Driver data is scoped in the page queries.** Assignment and event/evidence queries are filtered by the authenticated user ID and the driver's assignment IDs. This is useful defense-in-depth, but actual row-level security and cross-tenant runtime isolation remain untested in this gate.
3. **Partner scorecard preview discloses illustrative data.** The partner performance-quality page clearly labels all metrics and sample shipment records as illustrative preview examples, not actual KRIM partner results. It explains evidence-based definitions and avoids presenting its sample figures as live ranking.
4. **Customer ratings are explicitly disabled.** The canonical Customer Ratings & Reviews page states there are no live rating/review records, no records are loaded, and no persistent submissions are available. It identifies the unresolved shipment ownership/completion authorization issue and instructs that ratings remain disabled pending backend/RLS and negative cross-tenant testing.
5. **Complaint draft preview is honest.** The partner complaint page says it creates only a local browser draft, does not submit a ticket or notify KRIM, and makes no liability or compensation finding. It separates service complaints from insurance claims and commercial disputes.
6. **Canonical support workflow has durable records.** Support ticket conversation functions write messages, status events and audit events. Customer replies require the ticket to be owned by the authenticated user and reject closed/resolved tickets. Internal notes are distinct from customer-visible replies.
7. **Admin support actions are strongly gated in source.** Admin reply and transition functions require authenticated identity, AAL2 and `admin.platform`; ticket rows are locked for updates; status/priority inputs are constrained; terminal closure requires a reason; changes create support events and audit events.
8. **Support response targets are explicitly labelled internal.** A database trigger sets first response due at 48 hours and resolution due at 30 days, but column comments explicitly say these are internal targets, not public guarantees or proof of statutory acknowledgement.
9. **Driver trip event RPC is not anonymous.** The reviewed access-restoration migration revokes PUBLIC/anon and grants execution to authenticated users. This grant alone does not prove function-body authorization or RLS at runtime.
10. **Operations page avoids fabricated live KPI values.** The canonical operations service-performance page verifies a signed-in session and active operations organization membership, and clearly says live integration is unverified and no operational records are changed. Its form only validates browser-side references.

## 3. Findings and release risks

### P1 — Operations performance workspace does not prove fine-grained permission authorization
The canonical operations service-performance page checks for a signed-in session and an active organization of type operations. It then displays an authorization-ready state while explicitly saying fine-grained operations permissions still require verification. The page itself does not demonstrate a specific permission such as `operations.performance.view` or a server-authorized performance dataset. The page's claim of permission-scoped access is therefore not established by its visible client-side check alone.

**Impact:** An active operations organization membership must not be treated as authorization to view every partner, customer or performance record. Verify server-side permission enforcement and tenant/partner scope before exposing operational KPIs.

### P1 — No canonical audited performance calculation / scorecard pipeline established
The driver page is read-only activity history. Partner page data is static illustrative demo data. Carrier scorecard contains hard-coded scores (including 94/100 and 96/100), punctuality and invoice accuracy values, despite no verified data pipeline, reporting period, agreement binding or partner identity in that page. The static figures are not live KRIM results and could mislead if publicly reachable or misunderstood.

**Impact:** There is no established canonical source-of-truth scorecard for on-time pickup/delivery, milestone completeness, exception rate, damage/loss, POD quality, invoice accuracy, communication, sustainability or partner reliability. Hard-coded sample scores must never be represented as real partner performance.

### P1 — Customer ratings/reviews are correctly disabled, but the core review workflow is not yet implemented
The canonical page explicitly says no rating data is available and no submissions are enabled because the rating policy has not been sufficiently bound to shipment ownership and completion. No proven backend review table/RPC/policy lifecycle was found in the inspected source set for one-rating/amendment rules, verified completed shipment, exact service provider/leg, review moderation, abuse reporting, appeal, response rights or publication consent.

**Impact:** Do not accept, display, average or rank customer ratings until the exact shipment, organization, provider/leg and completed-service tuple is verified server-side and cross-tenant negative tests pass.

### P1 — Complaint intake is inconsistent across customer and partner routes
The partner complaint page is a local-only draft. Customer complaint alias redirects to the generic support ticket creation page. The canonical support backend supports authenticated tickets and conversation, but the partner preview does not submit into it. No verified end-to-end partner complaint intake, ticket receipt, category/urgency mapping, ownership, partner-visible conversation, or complaint-specific appeal lifecycle was demonstrated.

**Impact:** Partners may believe they have formally lodged a complaint when only a local draft exists. Clearly distinguish draft from submitted ticket and provide a confirmed ticket number/receipt for any live intake.

### P1 — Support SLA timer is not a monitored/automated SLA service
The database trigger sets internal 48-hour first-response and 30-day resolution target timestamps. The reviewed code does not establish a scheduled SLA breach scanner, priority-sensitive business calendar, time-zone/holiday handling, pause/resume rules, customer/partner update cadence, acknowledgement deadline enforcement, breach escalation, assigned owner fallback or notification delivery. The internal policy is expressly not a public guarantee.

**Impact:** Stored due dates alone do not establish active SLA monitoring or compliance. Do not advertise guaranteed response/resolution times or show SLA attainment until breach monitoring, clock rules, escalation and delivery are verified.

### P1 — No partner corrective-action and accountability lifecycle established
The partner performance page explains improvement concepts and lists illustrative exception rows, but no canonical live workflow was established for a verified service failure finding, partner response, evidence submission, root-cause analysis, corrective/preventive action (CAPA), owner, due date, independent validation, repeat-failure escalation, probation/suspension or appeal. Existing partner capability/compliance reviews are not a substitute for shipment service quality adjudication.

**Impact:** KRIM cannot claim automated quality enforcement, performance-based partner suspension or completed corrective actions.

### P2 — KPI definitions, denominators, exclusions and comparability are incomplete
The partner preview provides sensible metric concepts but no approved versioned calculation specification was established for booking acceptance, pickup punctuality, delivery punctuality, partial delivery, cancellation, customer-caused delay, force majeure, waiting time, time-zone boundaries, rescheduling, failed attempts, incomplete POD, damage/loss, disputed events, multi-leg attribution or missing data. Different modes, lanes and service classes must not be compared without normalized definitions and minimum sample thresholds.

### P2 — No evidence-backed customer satisfaction / complaint outcome analytics
No verified review or complaint dataset was shown to calculate CSAT, NPS, complaint rate, repeat complaint rate, resolution time, appeal overturn rate, partner response quality or satisfaction confidence intervals. Small sample sizes and selection bias must be disclosed.

### P2 — No durable notification proof for performance/complaint lifecycle
Support messages and audit events are recorded, but this review did not establish mandatory notification outbox, delivery receipts, retry/dead-letter, acknowledgement and fallback for ticket received, partner response requested, complaint escalated, SLA at risk/breached, corrective action due, score disputed or review moderated. A persisted message/event is not proof that the intended user received it.

### P2 — Static carrier scorecard carries credibility and route-safety risk
The carrier scorecard page contains hard-coded carrier category labels and KPI figures, including numerical scores, on-time percentages and invoice accuracy. It does not load a live authorized partner dataset. Review publication status, noindex/access restrictions, route references and link discoverability before exposing this page as a real marketplace scorecard.

### P2 — Dispute and appeal protections are not proven for performance decisions
No complete appeal mechanism was established for partner score calculation, data correction, customer review moderation, complaint outcome or consequential partner access restriction. Partner response, evidence visibility, reviewer independence, decision rationale and immutable calculation versions are required before scores affect commercial allocation.

## 4. Required remediation before release

1. Define a versioned global KPI dictionary with formulas, source tables, event authority, UTC clock, IANA display zone, business calendars, exclusions, mode/service-class comparability, denominator, minimum sample size and missing-data handling.
2. Build a canonical performance calculation service from verified shipment/leg, agreed schedule, dispatch, milestone, independently verified POD, exception, claims and invoice source records. Store immutable calculation version, reporting period, scope, evidence references and recomputation audit.
3. Require Operations performance read permission server-side and scope every dataset to authorized organization, customer, partner, country, service and assigned operational responsibilities. Add cross-tenant negative tests.
4. Remove or permanently isolate hard-coded public carrier scores and illustrative partner records from production-visible scorecard routes. Use explicit demo banners and noindex or authenticated sandbox access.
5. Implement customer review eligibility: authenticated customer org owns completed shipment; exact provider and service leg; one review or versioned amendment; submission window; moderation; abuse controls; provider reply; privacy/consent; appeal; deletion/retention policy. Keep writes disabled until verified.
6. Connect partner complaint intake to authenticated support ticket creation, enforce partner organization ownership, preserve evidence securely, classify severity and return a durable ticket reference and receipt. Critical safety/security cases need a separate immediate emergency channel.
7. Implement SLA engine with policy version, priority-specific clocks, business hours/time zones/holidays, pause/resume, breach scanner, accountable owner, fallback escalation, durable notification and customer/partner acknowledgement.
8. Implement partner service-failure adjudication and CAPA: verified finding, partner response window, root cause, corrective action, accountable owner, due date, evidence, independent closure and repeat-failure escalation. Provide appeal and prevent automated punitive decisions from unreviewed or disputed data.
9. Establish customer/partner feedback governance: anti-manipulation, verified transaction, duplicate/fraud detection, moderation transparency, right of reply, data minimization and appeal.
10. Add mandatory notification pipeline for ticket receipt, reply, SLA risk/breach, incident, complaint status, review outcome, CAPA assignment/due date and material performance changes, with per-recipient delivery status, retry/dead-letter, acknowledgement and fallback.
11. Staging tests with synthetic users: cross-tenant scorecard read, unverified/incomplete shipment rating, wrong partner/leg rating, duplicate rating, edit/amendment, abusive review, complaint ownership, local draft vs actual submission, internal note leakage, SLA clock pause/resume, holiday/timezone boundary, breach escalation failure, partner response and appeal, score recomputation and audit immutability.
12. Keep public ranking, ratings, SLA attainment and automated partner sanctions disabled until independent verification and runtime evidence are complete.

## 5. Verification matrix

| Check | Result | Evidence / limitation |
|---|---|---|
| Driver performance activity page uses authenticated driver session | SOURCE PASS | Session and active driver membership/organization checks. |
| Driver activity history queries are user/assignment scoped | SOURCE PASS / PARTIAL | User ID and assignment IDs in client query; RLS/runtime negative tests not run. |
| Driver score is evidence-backed and not fabricated | SOURCE PASS | Page explicitly reports activity counts only, not a rating. |
| Partner performance preview labels sample metrics illustrative | SOURCE PASS | Explicit demo disclaimer and static sample data. |
| Carrier reliability scorecard uses live authorized records | FAIL | Hard-coded sample scores and KPI percentages; no live data query. |
| Customer rating submission authorization | FAIL / BLOCKED | Canonical page states submissions disabled due to ownership/completion policy gap. |
| Customer review moderation/appeal/provider reply | NOT TESTED | Full lifecycle not established. |
| Partner complaint preview submits a real ticket | FAIL | Browser-local draft only; no backend submission. |
| Customer support ticket owner-scoped reply | SOURCE PASS | Customer reply RPC checks authenticated ticket owner and writes event/audit. |
| Admin support reply/status transition authorization | SOURCE PASS | AAL2 + admin.platform; locked row, reasoned transition, event/audit. |
| Internal support due timestamps | SOURCE PASS | 48h first response / 30d resolution trigger; explicitly internal targets only. |
| SLA breach detection, clock rules and escalation | BLOCKED | No active monitor, escalation or delivery proof established. |
| Operations performance fine-grained permission | BLOCKED | Active operations membership check only; page says fine-grained permission needs verification. |
| Partner CAPA/disciplinary lifecycle and appeal | NOT TESTED / BLOCKED | No complete canonical workflow established. |
| Performance/complaint mandatory notifications | BLOCKED | Durable delivery, acknowledgement, retry and fallback not proven. |
| KPI calculation accuracy and mode comparability | NOT TESTED | No canonical versioned calculation pipeline. |
| Cross-tenant, moderation, concurrency and failure tests | NOT TESTED | Requires isolated Staging synthetic users and data. |

## 6. Change and safety record

- No Production or Staging SQL, RPC, RLS, grant, table, row, account, secret, provider, deployment, support ticket, rating, review, complaint, score or partner status was changed or invoked.
- No real customer, partner, driver or support user was contacted.
- No notification was sent.
- Documentation-only QA branch change.

**Gate C3.17 result: PARTIAL PASS / BLOCKED.** KRIM has responsible source-level foundations for driver activity visibility, internal support conversations and administrative audit. It intentionally disables customer ratings and labels partner preview figures as illustrative. A live performance scoring, SLA monitoring, customer-review, partner complaint submission and partner accountability system has not yet been proven. Keep public rankings and automated consequential decisions disabled pending remediation and isolated Staging verification.
