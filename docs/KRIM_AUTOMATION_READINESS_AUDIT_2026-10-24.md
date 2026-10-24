# KRIM Logistics Automation Readiness Audit — 2026-10-24

## Scope and evidence

Read-only review of production Supabase project `ebltviniygljwwseplph`, deployed Edge Function metadata/source, database table counts, `cron.job`, `cron.job_run_details`, and the preceding 24 hours of platform logs. No test email, customer message, AI request, payment, shipment, or production write was triggered during this audit. Secrets were not read or exposed.

This is an evidence-based readiness assessment, not a certification that every workflow works in a real browser.

## Executive result

**Automation is partially running, but KRIM is not ready to claim that every automation is operational.** Database cron is running reliably. AI is deployed but has not been proven by a live authenticated prompt in this audit. Outbound email notification sending is explicitly disabled in the deployed adapter. Support intake saves inquiries, but an automated support notification/response path is not evidenced. Several frontend requests are still failing against schema/permission mismatches.

## Confirmed healthy components

### Database cron
Two active jobs are configured:
- Every minute: `krim_internal_process_workflow_runtime_batch('krim-db-cron', 25, 50, 25)`
- Every five minutes: `krim_internal_process_growth_signals(50)`

In the preceding 24 hours, job 2 completed **1,440/1,440** runs successfully and job 3 completed **288/288** runs successfully. The latest observed runs were successful. This proves the scheduled SQL functions execute; it does not prove every business workflow step, provider delivery, or partner action is succeeding.

### Workflow runtime
The `krim_workflow_runs` table contains 9 records, all with status `completed`. This is encouraging but too small to establish full coverage of all workflow types.

### Deployed Edge Functions
The production project lists active functions including `krim-ai`, `krim-notification-provider-adapter`, `krim-public-contact-inquiry`, `krim-global-growth-operations`, payment order/verification/webhook functions for Razorpay and Cashfree, public tracking, and administrative control functions. Active deployment metadata proves the functions are deployed, not that their credentials, integrations, or end-to-end journeys are all operational.

## High-priority gaps

### AUTO-001 — Outbound email notification is deliberately disabled
**Severity: Critical for automated customer communications**

The deployed `krim-notification-provider-adapter` explicitly says it is a readiness check only and never sends messages. Its response hard-codes `sending_enabled: false`. It only checks whether `RESEND_API_KEY` exists; it does not deliver email.

Production database counts:
- `krim_communication_providers`: 0 rows
- `krim_message_templates`: 0 rows
- `krim_notification_outbox`: 0 rows
- `krim_notification_deliveries`: 0 rows

**Required before enabling:** verify Resend credential and sender-domain status without exposing secrets; configure approved templates, consent and suppression checks, recipient validation, delivery tracking, retries/dead-letter handling, and a controlled test recipient; then prove accepted, delivered, bounced and failed outcomes. Do not enable bulk or customer-facing sending until these controls are tested.

### AUTO-002 — Support intake is not yet proven as an automated support service
**Severity: High**

The deployed `krim-public-contact-inquiry` function validates and inserts contact inquiries into `krim_public_contact_inquiries`. The inspected implementation returns “inquiry received” after the insert but does not send an email or create a support ticket in that code path.

Production counts:
- `support_tickets`: 0 rows
- `krim_support_ticket_messages`: 0 rows
- `krim_support_ticket_events`: 0 rows
- `notifications`: 5 legacy/current records (count alone does not prove delivery)

**Required:** verify inquiry persistence and admin visibility, connect inquiries to a ticket lifecycle, set ownership/SLA/status transitions, and connect email notifications only after AUTO-001's delivery controls are ready. Test failure/retry and duplicate submission handling.

### AUTO-003 — AI assistant is deployed but not live-verified here
**Severity: High**

The `krim-ai` Edge Function is active (version 12) and JWT verification is enabled. Its source requires `OPENAI_API_KEY`, validates the caller's Supabase session, calls the OpenAI Responses API, and returns the generated text. This is source-level evidence only.

Production counts:
- `ai_conversations`: 0
- `ai_messages`: 0
- `ai_actions`: 0

No AI prompt was submitted in this audit, and the environment secret's presence/value was not read. Therefore key availability, model/API access, frontend request wiring, response rendering, error UX, usage/cost limits, and any role-specific AI action behavior remain unverified.

**Required:** test with a real signed-in test account; confirm successful response, invalid-session behavior, missing-key/provider error handling, rate/cost limits, and that AI cannot claim live shipment/payment data it has not actually retrieved. Any action that changes shipment, finance or partner state must remain permission-checked and approval-gated.

### AUTO-004 — Growth automation runs, but discovery/outreach are not fully automated
**Severity: High for automated acquisition**

The active five-minute cron job for `krim_internal_process_growth_signals(50)` is running successfully. However, the deployed `krim-global-growth-operations` function explicitly reports:
- `source_ingestion_configured: false`
- `signal_processing_cron_configured: true`
- `outbound_outreach_enabled: false`
- `partner_activation_automatic: false`

This means scheduled signal processing exists, but external source ingestion, outreach delivery and automatic partner activation are not complete. Do not represent customer/partner acquisition as fully autonomous.

### AUTO-005 — Frontend/backend schema and authorization errors remain visible
**Severity: High**

The previous 24-hour Supabase gateway logs included **29 HTTP 400**, **7 HTTP 403**, and **1 HTTP 401** responses on requests classified as errors by status code. Examples include:
- `/rest/v1/krim_shipments` selecting legacy fields such as `pickup_location`, `delivery_location`, `material_goods`, `weight`, and `truck_type`
- `/rest/v1/krim_shipments` and `/rest/v1/krim_quotes` filtered by `organization_id`, which returned HTTP 400
- `/rest/v1/revenue_ledger` and `/rest/v1/krim_customer_identity_links` returning HTTP 403

Some 401/403 responses may be expected for unauthenticated or unauthorized requests; the 400s on legacy/missing-column query shapes indicate frontend/schema alignment needs review. The log window contains activity on 2026-10-23; classify each route and confirm whether it is still present in the current deployed frontend before changing it.

### AUTO-006 — Notification records are not being processed as a delivery pipeline
**Severity: High**

The outbox and delivery tables are empty. There is no production evidence in these counts that a notification was queued, sent, retried, delivered, bounced, or dead-lettered. The existing minute cron is a workflow-runtime worker; it must not be assumed to be an email delivery worker without verifying its workflow actions and provider integration.

## Readiness matrix

| Area | Evidence-backed status | Safe conclusion |
|---|---|---|
| Database cron | PASS for scheduled execution in last 24h | Both configured jobs ran successfully at their expected cadence |
| Workflow runtime | PARTIAL | 9 completed runs; all workflow types not verified |
| AI assistant | DEPLOYED, NOT LIVE-VERIFIED | Source requires OpenAI credential and authenticated user; live prompt test remains |
| Email notifications | NOT READY TO SEND | Adapter explicitly returns `sending_enabled: false`; no provider/template/outbox/delivery rows |
| Support | INTAKE CODE PRESENT, AUTOMATION UNVERIFIED | Contact inquiry insert path exists; no ticket or outbound support notification evidence |
| Customer/partner acquisition | PARTIAL | Signal processor runs; ingestion and outreach disabled per function response |
| Payment automation | DEPLOYED, NOT END-TO-END VERIFIED | Provider functions exist; real/sandbox transaction reconciliation is a separate gate |
| Frontend/backend integration | NEEDS FIXES | Recent HTTP 400/403/401 gateway responses require route-level triage |
| All automation / global launch | NOT CERTIFIED | No claim of end-to-end automation readiness is justified yet |

## Safe implementation sequence

1. Reconcile the failing frontend queries against the canonical schema and role/RLS rules; do not bypass authorization.
2. Run an authenticated AI smoke test with a dedicated test account and verify frontend response/error behavior.
3. Build the notification delivery pipeline in a non-production/test recipient path first; verify provider/domain, consent, suppression, templates, idempotency, retries and delivery events.
4. Link contact inquiries to the support-ticket lifecycle and notification outbox.
5. Connect workflow action outcomes to observability and dead-letter handling; verify per-workflow success rather than only cron invocation success.
6. Verify payment, booking, partner assignment, shipment execution, delivery proof and settlement end to end with sandbox/test fixtures.
7. Re-run advisors, logs and regression tests. Only then approve a controlled live launch for services with verified capacity, approved pricing and compliance.

## Safety notes

- No production rows or schema were changed for this audit.
- No external email/SMS/WhatsApp message or payment was sent or initiated.
- No secret values were read or included.
- No production security permissions were changed.
