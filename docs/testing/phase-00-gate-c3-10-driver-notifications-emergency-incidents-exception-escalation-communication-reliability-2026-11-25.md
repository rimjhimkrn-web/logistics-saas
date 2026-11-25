# Gate C3.10 — Driver notifications, emergency/incident reporting, exception escalation and communication reliability

**Programme:** KRIM GLOBAL PLATFORM — AI QUALITY ASSURANCE, SIMULATION & RELIABILITY PROGRAMME  
**Gate:** Phase 00 / C3.10  
**Source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**QA branch:** `qa/phase-00-baseline-2026-11-25`  
**Review date:** 2026-11-25  
**Disposition:** **PARTIAL PASS / BLOCKED — NO-GO for claiming reliable driver emergency or end-to-end operational notification delivery.**

## 1. Scope and method

Read-only source inspection of:
- `app/driver/module-09-exceptions-incidents.html`
- `app/driver/module-15-notifications-support.html`
- `public/driver/emergency-support.html`
- `public/driver/incident-report.html`
- `supabase/migrations/20261124120000_krim_report_operational_exception.sql`
- `supabase/migrations/20261105080000_secure_support_ticket_conversation_and_admin_workflow.sql`
- `supabase/migrations/20261115082000_support_sla_targets_and_response_integrity.sql`
- `supabase/functions/krim-notification-provider-adapter/index.ts`
- `supabase/functions/krim-notification-retry-worker/index.ts`
- `public/support/support-runtime.js`

This is static source evidence only. No browser session, RPC, database query, Edge Function invocation, provider send, or delivery receipt was executed in this gate.

## 2. Positive source controls

1. Driver exception page requires an authenticated session, exactly one active driver membership and active organization before listing assignments or submitting an incident.
2. Driver incident submission requires an active assignment selection, factual notes and an accuracy attestation; it calls `krim_driver_record_trip_event` with event type `exception`.
3. Driver notifications page reads only the signed-in user's notification rows and customer-visible support messages; internal support notes are excluded from its conversation query.
4. Customer support reply RPC locks the ticket, checks ownership, blocks replies to resolved/closed tickets, records a support message, ticket event and audit event.
5. Admin support RPCs require AAL2 and `admin.platform` permission in source.
6. Operational partner exception RPC validates category, severity and description; resolves one unambiguous active assignment; records exception and audit event; marks high/critical, cargo-damage and safety/security exceptions as requiring evidence.
7. The operational exception RPC creates in-app notification rows for selected partner, customer and operations users in the same database transaction. This is useful inbox-record creation, not proof of delivery to an external channel.
8. Notification provider adapter is limited to authenticated platform administrators. Resend is explicitly `sending_enabled: false`; Telegram test sends a fixed founder-only test message.
9. Retry worker authenticates either a configured high-entropy cron secret or an AAL2-independent platform-admin permission check, then claims and completes founder Telegram retry queues in batches of ten. Its source paths are founder enquiry/follow-up Telegram queues, not the nine-workspace user notification pipeline.
10. Driver-facing copy correctly distinguishes an inbox record from confirmed email/SMS/push delivery and says emergency services take precedence over platform reporting.

## 3. Findings and release risks

### P1 — Driver incident submission is not proven to trigger a dispatch notification
The driver page submits `krim_driver_record_trip_event` and then tells the driver dispatch can review the exception. Source inspected here does not establish that this RPC creates a notification, outbox event, assigned dispatcher alert, acknowledgement timer or escalation if nobody responds. The separate `krim_report_operational_exception` RPC is a partner/carrier workflow; the driver UI does not call it. These two exception paths are not shown to converge on a single durable incident/escalation record.

**Impact:** A saved driver event may be mistaken for a dispatched/acknowledged incident. Safety-critical incidents could remain unseen.

### P1 — Essential user notification delivery is not end-to-end
The driver inbox reads `notifications` rows; the partner exception RPC inserts rows directly into that table. No user-facing provider delivery, durable generic outbox, per-channel delivery state, provider receipt, retry/dead-letter handling, or user-level acknowledgement/escalation is established by these inspected paths. Existing retry worker handles founder Telegram queues only. Resend sending remains disabled; SMS/push delivery is not evidenced.

**Impact:** KRIM cannot yet claim reliable delivery of assignment, safety, shipment-change, exception, security or other essential service notifications across all nine workspaces. Marketing preferences must remain separate from mandatory service notices.

### P1 — Emergency contact and escalation response are not operationally verified
The driver copy correctly instructs drivers to contact local emergency services first and then their dispatcher/carrier using an organization-verified channel. The inspected driver workflow does not prove a current, verified, route-/country-aware emergency contact directory, one-tap dispatch contact, dispatcher on-call roster, acknowledgement deadline, fallback escalation, or incident command ownership. Do not invent or display a global emergency number; local emergency numbers and carrier contacts require jurisdiction-specific validation.

**Impact:** The page is guidance, not a certified emergency-response service.

### P1 — Legacy emergency and incident routes still redirect into staging-named driver routes
`public/driver/emergency-support.html` redirects to `app/driver/staging/page-16-notifications-support.html`; `public/driver/incident-report.html` redirects to `app/driver/staging/page-10-exceptions-incidents.html`. Prior C3.5/C3.6 findings establish that the folder name is not an environment boundary and that GitHub Pages defaults to Production Supabase unless the resolver is changed. Runtime deployment/auth/isolation of these destinations is not proven. Keep these aliases release-blocked until a production-safe canonical route is verified.

### P2 — Partner exception notification recipient/deduplication semantics need hardening
The partner exception RPC inserts notifications synchronously into the legacy table and deduplicates by user, shipment, title and full message text. It has no durable event/outbox identifier or delivery-attempt key in the inspected function. Recipients are derived from active membership/permissions, but notification delivery after membership changes, recipient suppression, severity-specific escalation and repeat-event behavior are not proven. Driver assignment matching checks shipment/user/partner assignment but does not demonstrate a full exact shipment-leg-driver tuple across the complete notification workflow.

### P2 — Support SLA values are internal targets, not response guarantees
The support trigger assigns internal 48-hour first-response and 30-day resolution targets and explicitly comments that these are not public guarantees or proof of statutory acknowledgement. No automated SLA breach escalation/notification was proven in the inspected code. Do not advertise these values as guaranteed or legally compliant response times.

### P2 — Notification inbox state is not delivery state
The driver page marks a notification row read by updating `is_read`. That records inbox interaction only; it does not establish device receipt, external provider delivery, user acknowledgement of a safety alert, or incident resolution. No explicit unread/acknowledgement escalation state was found in the inspected page.

## 4. Required remediation before release

1. Establish one canonical incident model and correlate driver trip events, partner exceptions and operations incidents using immutable incident/event IDs plus exact shipment, leg, assignment, organization and reporter tuple.
2. Make driver incident submission return a durable incident reference and create a mandatory dispatch alert in the same transaction or via a transactional outbox. Clearly distinguish **recorded**, **queued**, **delivered**, **acknowledged**, **escalated** and **resolved**.
3. Implement a generic notification outbox/delivery ledger for all nine workspaces, with provider/channel adapters, idempotent claims, retry/backoff, dead-letter handling, delivery receipts, observability and tenant-scoped access. Essential service notices cannot be disabled by marketing preferences.
4. Define severity-based response policies: critical safety/security incidents require immediate local emergency action, on-call dispatch notification, acknowledgement deadline and a documented fallback escalation. Build country-specific emergency directory data only from verified sources and show its provenance/last-verified date.
5. Provide verified carrier/dispatcher contacts and escalation ownership for each active assignment/route; fail closed when no verified contact exists and show a clear manual fallback.
6. Reconcile legacy aliases to a production-safe canonical driver route. Verify deployment, HTTP redirect chain, authentication, environment selection and route/query/hash preservation before release.
7. Add support SLA timers and internal escalation notifications without representing internal targets as statutory or contractual guarantees.
8. Add isolated Staging tests for unauthorized/foreign-tenant incidents, wrong-leg/assignment tuples, duplicate submissions, retry races, provider timeout/rejection, dead-letter recovery, recipient changes, read-vs-acknowledged semantics and escalation when no dispatcher acknowledges. Do not test with real emergency services or send uncontrolled external notifications.

## 5. Verification matrix

| Check | Result | Evidence / limitation |
|---|---|---|
| Driver auth + active membership gate | SOURCE PASS | Driver page checks session, one active driver membership and active organization. |
| Driver incident event write | SOURCE PARTIAL | Calls `krim_driver_record_trip_event`; RPC runtime, exact tuple and notification side effects not tested in this gate. |
| Driver event → dispatch alert | BLOCKED | No end-to-end alert/ack/escalation path established. |
| Partner exception record + audit | SOURCE PASS | Migration records exception and audit event after unambiguous assignment authorization. |
| Partner exception → in-app inbox row | SOURCE PASS | Direct insert into legacy `notifications`; not a delivery receipt. |
| Essential notification delivery across nine workspaces | BLOCKED | Generic outbox/provider delivery pipeline not established. |
| Resend delivery | BLOCKED | Adapter explicitly disables sending. |
| Telegram founder test/retry | SOURCE PARTIAL | Source paths exist; no send or retry was executed. |
| Emergency contact and on-call fallback | BLOCKED | Not verified per route, country or partner. |
| Legacy emergency/incident redirect target | BLOCKED | Redirects to staging-named pages; deployed environment/auth unverified. |
| Support conversation controls | SOURCE PASS | Owner reply checks and admin AAL2/permission checks are present in inspected migration. |
| Support SLA automated escalation | NOT TESTED | Internal targets exist; automated breach handling not proven. |
| Browser, RLS, provider and runtime tests | NOT TESTED | Deferred until Staging deployment and migration parity gates pass. |

## 6. Change and safety record

- No Production or Staging SQL, RPC, RLS, grant, table, row, account, secret, provider, deployment or notification was changed or invoked.
- No driver, customer, partner or operations user was created.
- No external notification was sent.
- No production load or destructive test was run.
- This artifact is documentation-only on the isolated QA branch.

**Gate C3.10 result: PARTIAL PASS / BLOCKED.** Keep live driver emergency/incident-response claims and certified essential-notification delivery on **NO-GO** until the P1 findings are remediated and isolated Staging tests pass.
