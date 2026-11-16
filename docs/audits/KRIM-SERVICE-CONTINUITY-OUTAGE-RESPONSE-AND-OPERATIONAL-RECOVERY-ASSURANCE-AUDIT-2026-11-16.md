# KRIM Service Continuity, Outage Response and Operational Recovery Assurance Audit — 2026-11-16

## Executive decision

**NO-GO for continuity/recovery certification and unrestricted production logistics operations.** KRIM has scheduled database workers and a business-continuity interface, but no verified full backup/restore, no measured RPO/RTO, no tested outage response, no externally confirmed notification delivery, and no live incident/recovery exercise. The continuity register page also contains a material UI truthfulness defect: it says records are saved to Supabase while the same page explicitly states that entries are only browser-local preview and its form handler is not connected to a server-side record workflow.

This audit is read-only. No jobs were invoked, paused or changed; no incidents were created; no messages were sent; no database records were changed.

## Evidence reviewed

- Prior backup/DR audit: `docs/audits/KRIM-BACKUP-DISASTER-RECOVERY-AND-BUSINESS-CONTINUITY-AUDIT-2026-11-16.md`.
- Prior operational exception/incident audit: `docs/audits/KRIM-OPERATIONAL-EXCEPTIONS-INCIDENT-ESCALATION-CLAIMS-AND-RECOVERY-AUDIT-2026-11-16.md`.
- Event/notification readiness audit: `docs/operations/KRIM-EVENT-NOTIFICATION-DELIVERY-AND-RECOVERY-READINESS-AUDIT-2026-11-16.md`.
- Business continuity page: `public/global-operations/business-continuity.html`.
- Incident management legacy route: `public/operations/incident-management.html`.
- Production cron catalog queried read-only.

## 1. Scheduled jobs: configured, not proof of successful recovery

Nine active cron jobs were visible in the live catalog at the inspection time:

| Job | Schedule | Purpose |
|---:|---|---|
| 2 | Every minute | Workflow runtime batch |
| 3 | Every 5 minutes | Growth signal processing |
| 13 | Every 5 minutes | Inquiry follow-up reminders |
| 14 | Every 5 minutes | Due exception escalation processing |
| 15 | Every 5 minutes | Capacity-hold expiry |
| 17 | Every 5 minutes | Notification retry Edge Function |
| 18 | Every 5 minutes | Expire stale driver tracking sessions |
| 21 | Every 5 minutes | Expire partner assignment offers |
| 22 | Every 5 minutes | Refresh vehicle expiry state |

These rows prove that jobs are configured and active in pg_cron at the query snapshot. They do **not** prove the last run succeeded, that failures alert an operator, that jobs recover after an outage, or that jobs are idempotent under delayed/duplicate execution. This audit did not inspect job-run histories or invoke any job.

**P1:** Add a read-only operations health view for last success, last failure, duration, lag/backlog, next due time, error class, and owner for each job. Alert on missed intervals and growing backlog. Reconcile cron job definitions against version-controlled source.

## 2. Business continuity workspace — P0 UI integrity defect

The page `public/global-operations/business-continuity.html` has four key issues:

1. It shows “No records loaded” and all metrics as em dashes, appropriately avoiding fabricated counts.
2. It states that browser entries are a UI preview and are not saved to the KRIM backend.
3. Its form notice nevertheless says: **“Authenticated records are saved to KRIM Supabase in the Global Operations register.”**
4. The page labels the form action “Save operational record” although no connected authenticated server-side create operation is present in the inspected HTML/inline workflow. The page is therefore a local UI preview, not an operational continuity register.

**P0:** Correct the contradictory save claim and label the form clearly as a non-persistent preview or disable submission until an authorized backend workflow exists. Do not imply the continuity plan, exercise or recovery evidence has been saved.

Additional P1: the page's checklist is local-only; there are no live records, owners, evidence attachments, review approvals, RTO/RPO fields, tested recovery outcomes or change history.

## 3. Incident command and outage communications

The legacy incident route redirects to the authenticated operations exception-management page. Prior audits show:
- system incident records: 0;
- operational exceptions, timers and escalations: 0;
- notification outbox/delivery/retry rows: 0;
- external notifications disabled pending verification;
- no complete incident commander, communications timeline, affected-service inventory, status-page publication or post-incident review journey demonstrated.

The exception engine is not a complete major-incident command process. Creating an exception or escalation is not equivalent to declaring an incident, coordinating technical recovery, informing affected customers/partners, or verifying service restoration.

**P1 required controls:**
- severity and incident declaration criteria;
- named incident commander and technical/business leads;
- affected services, regions, tenants and shipments;
- immutable timeline with decision/action ownership;
- internal and external communications templates and approval;
- status page or verified alternative customer notice channel;
- customer/partner contact eligibility and consent/contract rules;
- recovery validation, safe resumption decision and post-incident review;
- incident evidence retention and lessons-learned action tracking.

## 4. Notification and workflow recovery

Prior event-processing evidence includes 23 processed events and nine completed workflow runs with 18 completed steps. However:
- all nine dispatch rows remained in `dispatched` with `completed_at = NULL`, despite linked runs being completed;
- notification outbox, delivery and retry tables were empty;
- the deployed Telegram retry worker is scheduled every five minutes, but actual delivery was not independently confirmed;
- deployed worker source parity is not fully reconciled with repository source;
- provider accepted/sent/delivered/bounced/failed semantics and customer receipt have not been tested.

**P1:** distinguish dispatch handoff from workflow completion; establish durable queue leases, bounded retry/backoff, dead-letter recovery, idempotency, operator alerting, verified provider callbacks and recipient confirmation. No automated recovery should retry a non-idempotent logistics or financial action without a durable operation key and state reconciliation.

## 5. Backup and restore remains the dominant P0

The Supabase organization is Free and the production database is hosted in Tokyo. The earlier audit established:
- no Supabase automatic daily database backup or PITR on the current Free plan;
- no independently stored full data-bearing backup evidenced;
- the encrypted repository export is schema-only;
- Auth identities, Storage object bytes, Vault, custom roles and managed schemas are outside that export;
- no full isolated restore drill or measured recovery duration;
- RPO and RTO remain undefined/untested.

This audit does not treat the schema export or an empty preview branch as a production backup.

**P0:** Before live shipment execution, create an encrypted data-bearing backup covering supported database data and separately backed-up Storage object bytes, protect keys separately, and complete an isolated restore drill. Include Auth identity recovery, role/grant/RLS/function validation, secrets reauthorization, cron/Edge Function reconstruction and business-record reconciliation.

## 6. Dependency and single-region resilience

The production Supabase project is in `ap-northeast-1` (Tokyo). A single active project and GitHub Pages deployment do not constitute tested multi-region failover. No independent warm standby, DNS cutover rehearsal, write-freeze procedure or split-brain protection was evidenced.

Required:
- classify critical dependencies: DNS/domain registrar, GitHub Pages, Supabase DB/Auth/Storage/Edge Functions, payment provider, Telegram/email, partner/carrier systems and operator access;
- define outage modes and fallback for each;
- keep a minimal offline emergency contact/runbook copy;
- prohibit manual shipment/finance side-channel actions that bypass audit controls;
- define data reconciliation and duplicate prevention after service recovery;
- test rollback and cutover in an isolated environment before considering production failover.

## 7. Minimum recovery acceptance tests

Run only in isolated staging with synthetic data:

1. Restore database and object backup into a clean project; verify checksums, key row counts, FKs, RLS, grants, functions and Auth linkage.
2. Rebuild Edge Functions, secrets by controlled reauthorization, cron jobs and provider configuration without copying production secrets into artifacts.
3. Simulate DB unavailability; prove customer-facing booking/quote/dispatch actions fail closed and do not create partial state.
4. Simulate Edge Function/provider outage; prove queue backoff, no duplicate side effects, dead-letter visibility and operator alert.
5. Simulate a missed cron interval; prove backlog catch-up and idempotent execution.
6. Simulate notification provider acceptance with delayed callback; prove status is not mislabeled delivered.
7. Exercise incident declaration, commander assignment, customer/partner communications approval, recovery validation and post-incident review.
8. Test business continuity page: no false “saved” claim; server records only appear after successful authorized backend response.
9. Rehearse rollback/cutover with a documented write freeze, consistency checks and explicit go/no-go decision.

Record actual RPO/RTO measurements; do not invent targets or declare the exercise passed before evidence exists.

## 8. Priority remediation register

| Priority | Remediation | Release gate |
|---|---|---|
| P0 | Full encrypted data-bearing backup + Storage bytes + isolated restore drill | Required before real operational data |
| P0 | Fix continuity UI false persistence claim | Required before page is presented as operational |
| P1 | Cron last-run/failure/lag observability and alerting | Required before relying on automation |
| P1 | Major incident command and approved communications lifecycle | Required before customer shipment execution |
| P1 | Notification source parity, delivery semantics and retry/dead-letter proof | Required before external operational alerts |
| P1 | Outage/failover/cutover and reconciliation runbooks | Required before production scale |
| P1 | Measured RPO/RTO and dependency owners | Required before commercial SLA promises |
| P2 | Multi-region design and tested failover | Evaluate against budget and actual service criticality |

## Release decision

**NO-GO for continuity certification, live shipment execution, customer/partner SLA promises, or financial collection.** The cron schedule and workflow architecture are useful foundations, but backup/restore, operator alerting, incident command, notification delivery and safe recovery have not been demonstrated.

No production configuration, schema, cron job, incident, message, shipment, payment, customer record or provider account was changed.
