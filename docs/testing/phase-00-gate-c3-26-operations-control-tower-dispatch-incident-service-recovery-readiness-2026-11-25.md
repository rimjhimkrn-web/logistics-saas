# Phase 00 Gate C3.26 — Operations Control Tower, dispatch, incident and service recovery readiness

**Date:** 2026-11-25  
**Immutable source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**Method:** Read-only source and migration review reconciled with prior Production audits dated 2026-11-16. Historical counts/timestamps below are explicitly prior snapshots, not refreshed in this gate. No SQL/RPC, scheduler, worker, dispatch, shipment transition, exception, incident, notification, customer/partner contact or deployment operation was executed.

## Executive decision

**FAIL / BLOCKED — NO-GO for live dispatch, real-time control-tower claims, operational SLA certification, incident-response certification, automated rerouting, or customer/partner alert-delivery guarantees.**

KRIM has a meaningful operational control foundation: an authenticated Operations workspace, permission-scoped shipment snapshot listing, exact-leg dispatch authorization and revocation primitives, partner/driver/vehicle/capacity/custody checks, exception acknowledgement/resolution with audit events, severity-based escalation policies, signal-bridge primitives, private claim evidence checks, and an explicit decision not to fabricate AIS/ETA/reroute telemetry.

But the source and prior Production evidence reveal serious safety and readiness gaps:

1. **P0 — legacy privileged shipment-wide dispatch path bypasses the newer exact-leg authorization contract.** It can transition a shipment to dispatched without checking the exact-leg dispatch authorization, confirmed physical reservation/binding, full ROAD driver/vehicle/document checks, or exact leg selection. The single-leg driver pickup/transit path also does not require the current exact-leg authorization helper.
2. **P0 — stale control-tower snapshots can look current.** The prior audit found 18 snapshots about 9 days 21 hours old at that audit and one open medium delay alert about 57 days 17 hours old. The UI showed capture time, but no enforced freshness threshold prevented stale data from being used as current health/SLA evidence.
3. **P1 — Operations child workspace authorization is inconsistent.** Several pages rely on browser session and operations membership while fine-grained action permissions are absent or explicitly not connected; direct table reads depend on RLS. Browser membership checks are not backend authorization.
4. **P1 — no operational exception/incident journey is evidenced.** Prior snapshot had zero exceptions, timers, escalations, escalation runs, signal events, incidents and claims. Three active policies support only one escalation level in the reviewed worker; external notifications are disabled; response and escalation deadlines are not independently enforced in the reviewed processor.
5. **P1 — exception resolution does not prove actual recovery.** Textual reason and cancellation of linked timers/actions/runs do not establish restored service, safe revised plan, customer/partner communication or resumed milestones.
6. **P1 — no durable unified operator queue or verified real-time monitoring.** Current snapshot list/dashboard is not a real-time operational queue with accountable owner, due time, current evidence, next permitted action and communication state.
7. **P1 — claims and incident command are untested.** Claim reviewer independence is not explicit in the reviewed function; claims evidence reuses the partner-verification bucket; no complete respondent/appeal or formal incident-command lifecycle was evidenced.
8. **P1 — no physical operations network is proven.** The previous control-tower snapshot had no partner assignments, capacity resources/reservations, dispatches, verified PODs, warehouse facilities/inventory or custody transfers.

## Scope and evidence reviewed

### Main source files
- `app/operations/index.html`
- `app/operations/dispatch-control.html`
- `app/operations/exception-management.html`
- `app/operations/shipment-control.html`
- `app/operations/tracking-activity.html`
- `app/operations/capacity-planning.html`
- `app/operations/carrier-coordination.html`
- `app/operations/customs-readiness.html`
- `app/operations/warehouse-coordination.html`
- `public/operations/operations-runtime.js`
- `supabase/migrations/20261106180000_operations_dispatch_readiness_register.sql`
- `supabase/migrations/20261106181000_fail_closed_dispatch_capability_check.sql`
- `supabase/migrations/20261115144628_add_exact_leg_dispatch_authorization.sql`
- `supabase/migrations/20261115144752_integrate_multileg_dispatch_authorization_with_driver_events.sql`
- `supabase/migrations/20261115145000_guard_leg_dispatch_plan_partner_and_mode_readiness.sql`
- `supabase/migrations/20261115145401_add_dispatch_revocation_and_revalidate_at_driver_execution.sql`
- `supabase/migrations/20261115150526_align_dispatch_readiness_with_multileg_authorization.sql`
- `supabase/migrations/20261115152002_reject_revoked_dispatch_authorization_replay.sql`
- `supabase/migrations/20261124120000_krim_report_operational_exception.sql`
- `supabase/migrations/20261115082000_support_sla_targets_and_response_integrity.sql`

### Prior audit evidence
- `docs/audits/KRIM-GLOBAL-OPERATIONS-CONTROL-TOWER-ACCESS-FRESHNESS-AND-EXCEPTION-ORCHESTRATION-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-GLOBAL-LOGISTICS-CONTROL-TOWER-AND-EXECUTION-INTEGRITY-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-OPERATIONAL-EXCEPTIONS-INCIDENT-ESCALATION-CLAIMS-AND-RECOVERY-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-DISPATCH-AUTHORIZATION-AND-SINGLE-LEG-EXECUTION-GATE-P0-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-CUSTOMER-SHIPMENT-VISIBILITY-TRACKING-SUPPORT-EXCEPTIONS-AND-NOTIFICATION-RELIABILITY-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-DISPATCH-CALLER-AND-PRIVILEGED-PATH-TRACE-2026-11-16.md`
- `docs/audits/KRIM-DISPATCH-CURRENTNESS-AND-WAREHOUSE-STOCK-COMMITMENT-ADDENDUM-2026-11-16.md`
- `docs/remediation-pending/2026-11-16-dispatch-authorization-enforcement.md`
- `docs/remediation-pending/2026-11-16-shipment-milestone-lifecycle-enforcement.md`

## Positive controls confirmed

1. **Operations workspace admission:** main `app/operations/index.html` checks authenticated session and active membership in an active operations organization. The main shipment-snapshot RPC checks active operations membership and `shipment.view` on the shipment's customer organization.
2. **Scoped dashboard reads:** prior audit found dashboard counts and empty states permission-scoped rather than advertised as global network totals.
3. **Dispatch readiness is read-only and fail-closed:** `krim_operations_dispatch_readiness` checks partner dispatch permission, exact assigned leg, active/verified partner state, completed warehouse handover, eligible driver and verified capability. Capability helper is explicitly tested with `IS NOT TRUE` in the later fail-closed version.
4. **Exact-leg authorization foundation:** newer RPC requires authenticated caller, accepted exact-leg partner assignment, dispatch permission, assigned leg, confirmed capacity-leg binding and partner-owned confirmed reservation. ROAD path checks accepted driver assignment, active membership, verified profile/current licence, accepted licence documents, active verified vehicle and active driver/vehicle binding. Later legs require accepted custody from the immediately preceding leg.
5. **Authorization revocation:** newer path records revocation reason, actor and partner execution event; revoked authorization is revalidated at driver execution and replay is rejected in later migrations.
6. **Exception acknowledgement/resolution:** permission checks, row locks, reason validation, audit events, signal bridge and cancellation of linked open escalations/timers/actions/runs are present.
7. **Partner exception reporting:** 2026-11-24 migration restricts reporting to an authenticated active member of one unambiguous active assignment; driver must be assigned to that shipment; supported categories/severity/description are validated; exception and audit record are created; in-app notifications are attempted for scoped recipients. This is not proof of notification delivery.
8. **Explicitly disabled external telemetry:** `public/operations/operations-runtime.js` returns `provider_not_connected`, AIS unavailable, automated rerouting disabled and predictive ETA disabled. It creates no simulated events or network writes. Preserve this honesty.
9. **Claim submission/evidence controls:** prior audit found shipment/customer ownership, permission, claim type/currency/amount/description checks, claim event creation and owner/path/MIME/size validation for private evidence; AAL2 platform claim review and bounded approved amount.
10. **Internal support targets are labelled:** support ticket trigger sets 48-hour first-response and 30-day resolution targets, with comments that these are internal targets and not public guarantees or proof of statutory acknowledgement.

These controls are source/prior-audit observations. This gate did not execute them against live records.

## Critical and high-priority findings

### P0 — Privileged legacy dispatch bypasses exact-leg authorization

Prior Production function review found `public.krim_dispatch_shipment(bigint,text,jsonb)` selects the first assigned leg instead of accepting an exact leg ID. It checks partner access/dispatch permission, accepted assignment, active shipment-weight capacity commitment, current partner compliance and shipment-level capability, but it does not require:
- a current exact-leg dispatch authorization;
- a confirmed physical capacity-leg binding and reservation;
- the full ROAD driver acceptance, current licence, licence documents, verified vehicle and driver/vehicle binding checks enforced by the newer authorization path;
- exact-leg selection for the intended dispatch.

It transitions the shipment to `dispatched` and creates/updates a legacy dispatch record. It is a privileged backend path, so service-role callers bypass RLS and must independently enforce the complete contract.

The reviewed `krim_driver_record_trip_event` checks current exact-leg authorization for pickup/transit only when an active multi-leg plan exists. The single-leg branch relies on shipment status, active assignment, driver assignment acceptance and non-terminal leg; it does not call the exact-leg authorization helper.

**Required remediation:** unify all single-leg and multi-leg dispatch and pickup/transit paths on one exact-leg authorization contract. Trace every caller of the legacy RPC, remove/disable bypass semantics only after caller migration and compatibility review, and make server-side transition reject any missing, revoked, stale, wrong-leg or wrong-partner authorization. Keep ROAD-specific checks mandatory and add mode-specific resource/operator evidence for rail, air, ocean and other modes. Test all paths in isolated Staging, including privileged/service-role callers.

### P0 — Stale snapshot and alert data are not fail-closed

Prior audit snapshot:
- 18 shipment snapshots; 17 health states healthy and one attention.
- Latest snapshot capture: 2026-11-06 06:46:23 UTC, about 9 days 21 hours old at the 2026-11-16 audit.
- One open medium delay alert triggered 2026-09-19 11:08:30 UTC, about 57 days 17 hours old at that audit.

The main dashboard displayed capture timestamp, but no enforced freshness threshold or stale-state guard prevented obsolete snapshots from appearing as current health/SLA evidence. The old alert was not reconciled to an owner, source event, shipment state, SLA basis and evidence in that audit.

**Required remediation:** define source-specific freshness SLOs and enforce them server-side and in UI. Every snapshot/alert must show captured/observed time, source, age, last successful refresh and freshness status. Stale/unknown data must be excluded from health, SLA and ETA conclusions and require explicit refresh/review. Reconcile the historic alert through evidence; never blind-close or rewrite it. A snapshot's stored `healthy` value is not current health proof.

### P1 — Operations child workspace authorization contract is inconsistent

Prior audit found the main dashboard uses meaningful server-side scope checks, but child workspaces such as shipment control, tracking activity, capacity planning, carrier coordination, customs readiness and warehouse coordination mainly check browser session and active operations membership. Several pages explicitly state fine-grained permissions or write workflows are not connected; direct table reads rely on RLS.

**Required remediation:** for every read/action, require authenticated user, active operations membership, named permission, exact tenant and shipment/leg scope, current record state and server-side RPC/RLS enforcement. Build a role/action/route matrix and test no membership, suspended membership, wrong organization, wrong shipment, wrong leg, read-only role, missing permission and stale JWT claims. Browser gating is usability, not security.

### P1 — No unified accountable operator queue

The main dashboard does not provide a complete queue binding shipment/leg, verified issue, severity, owner, due time, last evidence, next permitted action, customer communication state and immutable event history. The previous audit explicitly required such a queue. Snapshot aggregates and child pages do not replace accountable work orchestration.

**Required remediation:** one scoped work queue with source-event linkage, exact shipment/leg, severity/priority, accountable owner and backup, response/escalation due times, last verified evidence, next allowed action, notification state and full audit history. Empty data must remain empty; do not seed fake operational work.

### P1 — Exception detection and escalation are not operationally proven

Prior Production snapshot had zero operational exceptions, actions, timers, escalations, escalation runs/events, signal bridges/events and system incidents. Three active severity policies existed (critical, high, medium); no low policy was found in that snapshot. The reviewed escalation processor creates level 1 only, despite a schema that includes maximum escalation level. It selects escalation time from `detected_at + escalation_minutes`; separate response deadline enforcement was not visible. External notifications are explicitly `disabled_until_verified`. A durable escalation row is not proof of human receipt.

**Required remediation:** establish tested detectors for missed pickup/delivery, milestone silence, route deviation, cargo condition, inventory shortage, customs hold, capacity cancellation and provider outage. Deduplicate by source event and exact shipment/leg; implement separate response and escalation clocks, configurable tiers, worker lease/reclaim, retry/dead-letter and delivery evidence. Keep external notifications disabled until provider delivery, consent, retry and fallback are verified. Never mark a message delivered without provider/human evidence.

### P1 — Exception closure is not verified recovery

Resolution currently accepts a meaningful text reason, updates status/audit and cancels associated pending/active timers, actions and orchestration runs. It does not inherently prove physical service restoration, revised route approval, customer/partner communication, resumed milestones or completion of the recovery task. Cancelled work is not completed work.

**Required remediation:** high/critical exceptions require evidence-backed mitigation and recovery checks, safe operational re-plan, customer/partner communication status, resumed downstream milestones and independent reviewer where warranted. Preserve cancelled-vs-completed action states. Link root cause, corrective/preventive action owner, due date and effectiveness verification.

### P1 — Formal incident command lifecycle is absent/unproven

Prior snapshot had zero system incidents. No journey was evidenced for incident commander, affected services/shipments/tenants, event timeline, internal/external communications, recovery test, status updates and post-incident review.

**Required remediation:** create and stage-test an incident lifecycle with commander and roles, severity, affected services/shipments, timeline, decisions, comms approvals, recovery validation, customer impact, postmortem and corrective action. Do not claim business continuity or incident-response certification from schema presence.

### P1 — Claims review and evidence governance incomplete

Prior audit found zero claims, claim events and claim evidence. The review function required AAL2 and platform permission but did not visibly compare reviewer to claimant/submitter or require second review for high-value/sensitive claims. Claim evidence reused the private partner-verification bucket, creating purpose/retention/access-policy ambiguity. A claim decision is not a refund, partner debit, insurer recovery or payout.

**Required remediation:** enforce reviewer independence and maker-checker thresholds, respondent response and appeal workflow, exact shipment/assignment scope, evidence access/retention/legal hold and immutable review history. Keep claim adjudication separate from finance execution; no claim approval may directly move money.

### P1 — No real operational execution footprint is evidenced

Historical Production snapshot from the 2026-11-16 control-tower audit:
- 18 shipments (8 draft, 3 quoted, 6 confirmed, 1 closed), but no active assigned/dispatched/in-transit shipment;
- 1 shipment leg, 1 planned route, zero route options and zero active leg plans/items;
- zero capacity resources, reservations/bookings and partner capacity commitments;
- zero partner assignments and leg dispatch authorizations;
- zero dispatch records, zero verified PODs and one tracking event;
- zero warehouse facilities/inventory/receipts/tasks/allocations/transfers;
- zero custody transfers;
- zero operational exceptions/escalations/timers.

These historical counts were not refreshed here. They show no demonstrated physical network journey, not proof that source functions are absent.

### P2 — SLA and provider telemetry semantics need governance

The support SLA trigger hard-codes internal 48-hour first-response and 30-day resolution targets. These are explicitly not public guarantees or statutory compliance proof. AIS, predictive ETA and automated rerouting remain disabled because providers are not connected. Rerouting must remain a proposal until route, compliance/customs, capacity, partner, customer approval and cost are verified.

**Required remediation:** effective-dated service/contract-specific SLA policy with timezone, business hours, pause rules, event source, version and legal review. For any later ETA/telemetry provider, capture provenance, timestamp, coverage, freshness, model version/confidence and outage status.

## Readiness matrix

| Capability | Result | Boundary |
|---|---|---|
| Main Operations workspace admission | PARTIAL PASS | Source/prior audit; no runtime role test |
| Scoped shipment snapshot listing | PARTIAL PASS | Permission-scoped RPC exists; freshness not enforced |
| Snapshot/alert freshness | FAIL / P0 | Historical stale snapshot and alert not fail-closed |
| Child workspace authorization | FAIL / BLOCKED | Inconsistent fine-grained server-side checks |
| Dispatch readiness evaluation | PARTIAL PASS | Read-only fail-closed readiness; not execution |
| Exact-leg dispatch authorization | PARTIAL PASS | Strong newer primitives; not universal |
| Legacy shipment-wide dispatch path | FAIL / P0 | Bypasses exact-leg physical authorization contract |
| Single-leg pickup/transit authorization | FAIL / P0 | Does not enforce exact-leg helper in reviewed branch |
| Multi-leg custody/dispatch | PARTIAL PASS / BLOCKED | Source guards exist; zero live custody/dispatch |
| Operational exception reporting | PARTIAL PASS | RPC exists; no lifecycle runtime proof |
| Exception detection coverage | NOT TESTED / BLOCKED | No detector E2E evidence |
| Escalation tiers and response SLA | FAIL / BLOCKED | Level-1 only; response clock not distinct |
| External notification delivery | BLOCKED by design | Disabled until verified; no delivery proof |
| Evidence-backed recovery/closure | FAIL / BLOCKED | Text reason does not prove restored service |
| Incident command/postmortem | NOT TESTED / BLOCKED | No incident lifecycle evidence |
| Customer claims and evidence | PARTIAL PASS / BLOCKED | Source controls; zero claims; reviewer independence gap |
| Customer/partner service SLA | NOT TESTED / BLOCKED | Internal support target is not a service guarantee |
| Live tracking / AIS / predictive ETA | BLOCKED by design | No verified provider; GPS/telemetry not certified |
| Automated rerouting | BLOCKED by design | Remains disabled pending verified corridor/partner/capacity |
| Physical dispatch-to-delivery journey | NOT TESTED / BLOCKED | No real assignment, dispatch, POD or recovery proof |

## Required remediation and controlled test order

1. Reconcile Production migration history and deployed function definitions against repository sources. The prior migration audit found duplicate migration-version collisions; do not apply/replay/baseline/squash migrations or execute corrective Production DDL before a sanitized schema manifest and migration crosswalk.
2. Trace all callers of legacy shipment-wide dispatch and the single-leg driver event branch. Remove bypass semantics only after compatibility/caller review; make exact-leg authorization mandatory for all dispatch/pickup/transit paths.
3. In isolated Staging, test positive/negative single-leg ROAD and non-road dispatch; wrong leg/partner, missing or revoked reservation, stale capacity, missing driver acceptance, expired licence, unverified vehicle, missing documents, missing handover, stale compliance, custody gaps, replay and service-role caller.
4. Implement source-specific snapshot freshness and stale/unknown suppression. Test delayed snapshots, worker outage, timestamp skew, stale alerts and manual review; never mutate the historical alert merely to clear the UI.
5. Standardize Operations child workspace authorization with server-side permissions and exact row/leg scope; test every role and cross-tenant negative case.
6. Build the accountable operator queue and prove empty/partial/stale data handling.
7. Test exception source detection, dedupe, ownership, response SLA, escalation SLA, multi-tier escalation, worker crash/retry/reclaim and provider failure in Staging.
8. Keep external notification disabled until outbox, provider parity, consent, delivery, fallback and dead-letter evidence pass.
9. Require evidence-backed independent high/critical recovery; test cancellation vs completion, customer/partner comms and milestone resumption.
10. Implement incident command and post-incident review; enforce claim reviewer independence and evidence lifecycle.
11. Only after all prior tests pass, run a synthetic end-to-end operational journey in isolated Staging: verified partner → capacity → exact leg assignment → warehouse handover → dispatch authorization → driver pickup/transit → exception/mitigation if injected → delivery/POD → customer visibility → SLA/claim closure. No Production load or real customer operation during QA.

## Safety and launch boundary

No Production or Staging SQL/RPC, dispatch, shipment transition, scheduler/worker, exception/incident/claim, notification, customer/partner contact, provider integration, financial action or deployment was executed. Historical Production data is labelled as a prior snapshot and was not refreshed in this gate. No fake telemetry or sample operational records were created.

**Gate C3.26: FAIL / BLOCKED — NO-GO for live dispatch, real-time control-tower claims, operational SLA certification, incident-response certification, automated rerouting or alert-delivery guarantees.**
