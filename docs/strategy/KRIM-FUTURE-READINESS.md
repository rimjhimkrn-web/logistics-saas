# KRIM Future-Readiness Foundation

**Baseline date:** 2026-11-07  
**Platform:** KRIM Global Logistics OS  
**Repository:** rimjhimkrn-web/logistics-saas  
**Purpose:** Keep KRIM adaptable, reliable, commercially grounded, and capable of expanding from India to international corridors without replacing working systems unnecessarily.

## Operating principle

**Build a system that can adapt to change—not a system that assumes today's technology will never change.**

Future-readiness is not a promise that a business can never decline. It is a disciplined programme for reducing avoidable obsolescence risk through modular design, customer value, partner-network depth, operational reliability, financial discipline, and continuous learning.

## Guardrails

1. Preserve working production behaviour; make changes in small, reviewable increments.
2. Prefer configuration and adapter boundaries over hard-coded provider dependencies.
3. Do not activate a country, corridor, mode, payment method, or service based only on catalogue presence. Require verified partners, capacity, compliance evidence, pricing, operational ownership, and a tested customer journey.
4. Do not treat AI output as authority for pricing, compliance, payment, partner verification, or shipment status. Keep human approval and auditable controls where required.
5. Do not add expensive infrastructure or speculative technologies until a measurable customer or operating need justifies them.
6. Keep customer and partner data protected by least privilege, row-level security, server-side authorization, audit trails, and tested recovery procedures.
7. Every production change needs a rollback plan and verification evidence.

## Baseline audit — 2026-11-07

The connected Supabase project was reported as ACTIVE_HEALTHY, running PostgreSQL 17.6. The database inventory returned 378 public tables and 337 public functions. The following are observed counts, not a certification of production readiness.

### Operational footprint

| Area | Observed records |
|---|---:|
| Partner records | 10 |
| Partner capabilities | 1 |
| Partner verification cases | 1 |
| Network corridors | 7 |
| Network lanes | 0 |
| KRIM shipments | 18 |
| Quotes | 7 |
| Partner shipment assignments | 0 |
| Rate cards | 0 |
| Financial transactions | 1 |
| Workflows / steps / triggers / runs | 6 / 13 / 6 / 9 |

**Interpretation:** The platform has a substantial technical and data-model foundation, but live network depth and completed operating evidence are still thin. The next business priority is verified partner capability and service coverage, then controlled shipment execution and reconciliation—not broad international activation.

### Security and database findings

- All 378 inventoried public tables had RLS enabled.
- 21 public tables and 5 private tables had RLS enabled but no policies. This may be intentional for internal/server-only tables; each table's access path and intended owner must be verified. Do not add broad policies just to silence an advisor.
- 307 public functions use SECURITY DEFINER; 126 were reported executable by the authenticated role and none by anon.
- A static heuristic found 144 security-definer function bodies without obvious auth.uid(), is_admin(), or has_role() markers. This is a review queue, **not proof of a vulnerability**: trigger functions and tightly permissioned internal functions may correctly use other controls.
- Leaked-password protection is reported disabled in Supabase Auth.
- Performance advisors reported 27 foreign keys without covering indexes, 10 RLS init-plan warnings, 5 tables with multiple permissive SELECT policies, 1 duplicate index, and 671 unused-index notices. Unused-index notices are not a reason to drop indexes without workload evidence.
- The Supabase health advisor returned no lints at audit time.

### Payment and provider posture

Razorpay is the current India payment path. Keep provider-specific code behind a stable internal payment interface. Do not advertise global payment or settlement availability until each provider, country, currency, refund flow, webhook, reconciliation, and payout path has been verified. Legacy Cashfree functions remain present in the project inventory and should be assessed for references before any retirement; do not delete them blindly.

## Strategic architecture requirements

### 1. Modular provider boundaries
- Payment adapter interface: create order, verify/confirm, webhook ingest, refund, reconciliation, and settlement status.
- Notification adapter interface: email, Telegram, SMS/WhatsApp and future providers, with retries, idempotency, suppression, and delivery logs.
- AI provider boundary: model-independent prompts, structured outputs, evaluation tests, safety checks, usage limits, and a fallback/manual path.
- Logistics integration boundary: partner systems, carrier events, warehouse events, customs/document providers, and future EDI/API integrations.
- Version internal APIs and record provider capability/availability separately from country or currency catalogues.

### 2. Reliable operating core
- Treat shipment lifecycle transitions as explicit, authorized, auditable state changes.
- Require idempotency for payment, webhook, booking, assignment, and notification actions.
- Maintain event history, reconciliation, exception queues, retry/dead-letter handling, and operational ownership.
- Define measurable service levels only where partner commitments and monitoring support them.

### 3. Network and marketplace quality
- Verify legal identity, licences where applicable, service areas, modes, equipment, insurance/evidence, contacts, and operating capacity before activation.
- Keep draft, submitted, under-review, verified, suspended, and rejected states distinct.
- Match only on confirmed route, mode, cargo fit, capacity, service window, and compliance status.
- Track acceptance, on-time performance, damage/claims, cancellations, customer feedback, and partner responsiveness.

### 4. Customer value and retention
- Make quote quality, transparency, reliable status, documentation, exception handling, and support measurable.
- Capture feedback and repeat usage without dark patterns or misleading availability claims.
- Build retention from successful operations—not cosmetic features or lock-in.

### 5. Data, security, and resilience
- Maintain least-privilege RLS policies and explicit function grants.
- Review every SECURITY DEFINER function for caller authorization, search_path safety, input validation, and intended execution roles.
- Keep secrets server-side; rotate credentials and audit provider access.
- Verify backups, restore procedures, incident response, dependency updates, and observability.
- Define data retention, deletion, and export processes appropriate to applicable law.

### 6. Global readiness
- Model country, market, currency, language, time zone, business calendar, tax, customs, and documentation as separate capabilities.
- Require a country/corridor launch checklist with local legal review and operational proof.
- Treat catalogue entries as reference data, not proof of live service.
- Expand only after an India operating playbook is repeatable and financially sustainable.

## Execution roadmap and acceptance gates

### Phase A — Complete the foundation audit
- Map repository structure, build/test/deploy workflows, environment configuration, and runtime dependencies.
- Map critical database tables, RPCs, Edge Functions, triggers, RLS policies, and grants to user journeys.
- Review all externally executable SECURITY DEFINER functions and the 21 public no-policy tables.
- Verify payment and notification provider dependencies and remove only confirmed-unused legacy paths.
- Record backup/restore, monitoring, incident, and rollback evidence.

**Gate:** A reviewed system map, prioritized risk register, and reproducible baseline tests.

### Phase B — Harden the existing operating core
- Fix confirmed authorization and RLS issues only after policy intent is established.
- Add missing FK indexes only where query plans and workload justify them.
- Resolve duplicate policies/indexes with regression tests.
- Enable and test compromised-password protection where supported by the account configuration.
- Add tests for idempotency, duplicate webhooks, failed payments, refunds, retries, and reconciliation.

**Gate:** No unresolved critical/high security issue in reviewed paths; regression tests pass.

### Phase C — Prove India operations
- Verify and onboard partners with evidence.
- Configure real, approved rates and service areas.
- Test enquiry → quote → acceptance → payment → assignment → pickup → tracking → delivery proof → invoice/settlement.
- Reconcile every money movement and establish support/exception ownership.

**Gate:** At least one real route and service mode has a verified partner, confirmed commercial terms, legal/tax review, end-to-end test evidence, and reconciled funds.

### Phase D — Expand capabilities when justified
- Add partner integrations, AI assistance, automation, predictive operations, and additional payment providers behind adapters.
- Introduce enterprise plans and additional revenue models only after customer demand and unit economics are validated.
- Pilot new technologies in isolated, reversible scopes.

**Gate:** Each new capability has a named owner, customer case, cost/benefit measure, security review, rollback path, and adoption metric.

### Phase E — International corridors
- Select one corridor at a time (for example India–UAE only after India operations are proven).
- Validate local partners, customs, tax, payment, documentation, insurance, sanctions/trade restrictions, and customer support.
- Monitor service quality and contribution margin before widening coverage.

**Gate:** Country- and corridor-specific operational and legal approval with real partner capacity.

## Ongoing governance

- **Weekly:** operating incidents, failed workflows, customer/partner feedback, unresolved exceptions.
- **Monthly:** partner coverage, retention, quote conversion, shipment success, contribution margin, payment reconciliation, competitor and technology watch.
- **Quarterly:** architecture, security, dependency, cost, resilience, and country-readiness review.
- **Annually:** reassess the business model, market strategy, risk appetite, and long-term technology choices.

## Current external change watch

- Supabase CLI v3 was released in November 2026 and changes command defaults to local-first; hosted database operations now require explicit remote targeting and confirmation. Audit any CI/deployment scripts before upgrading or changing CLI versions.
- Supabase announced removal of a subset of legacy TLS 1.2 CBC cipher suites from project APIs beginning 2026-11-10. Confirm that supported client runtimes use modern TLS; do not weaken TLS to preserve obsolete clients.
- Supabase Data API table exposure defaults changed in 2026; verify explicit grants and exposure for each API-backed table rather than assuming new public tables are automatically exposed.

## Audit limitations

This baseline used connected Supabase project metadata, table inventory, advisors, read-only SQL metadata queries, Edge Function inventory, and recent GitHub commit metadata. Repository code search did not return file matches in this pass, and root README/package manifests were not retrievable by the connector. Therefore frontend code, CI workflows, dependency versions, and end-to-end browser behaviour are **not yet audited**. No production schema, data, payment setting, Edge Function, or user-facing code was changed as part of this baseline.

## Definition of success

KRIM is future-ready when it can safely add or replace providers, introduce new modes and corridors, improve AI and automation, and adapt to regulatory changes without destabilizing existing customers or compromising funds, data, partner trust, or operational evidence—and when each expansion is supported by measurable customer demand and sustainable economics.


## Security review continuation — 2026-11-07

A second read-only review checked the 10 authenticated-executable SECURITY DEFINER functions that did not contain the common textual markers auth.uid(), is_admin(), or has_role(). This is important because textual searches can produce false positives.

- The capacity-resource admin wrapper delegates to krim_admin_list_capacity_resources(), which explicitly requires a signed-in user, AAL2 MFA, and the admin.platform permission.
- The lane-specific partner capacity registration wrapper delegates to krim_partner_register_capacity_resource(), which checks auth.uid(), active organization membership, partner.manage permission, current compliance, verified capability, and evidence storage paths.
- The service-capability submission wrapper delegates to krim_partner_submit_service_capability(), which checks auth.uid(), partner.manage permission, registered-business partner status, current compliance, valid mode/country, and private evidence storage.
- The six vehicle administration/review functions inspected call krim_vehicle_admin_guard(), which requires an authenticated AAL2 session and admin.platform permission. The inspected review/finalization paths also enforce separation of duties and evidence validity.

**Result:** These 10 sampled exceptions have an identifiable authorization guard in their own body or in a delegated function/guard. This reduces the concern raised by the static marker heuristic, but does not replace a full review of all 126 externally executable functions and their call graphs.

The 26 RLS-enabled/no-policy tables were also checked for direct table grants. None of those tables had direct SELECT/INSERT/UPDATE/DELETE privileges for anon or authenticated roles in the inspected grant check. This supports an internal/server-only interpretation, but the intended access paths, views, triggers, and service-role use still need documentation and verification. Do not add client policies or grants without an explicit user journey and authorization design.

### Revised security review queue

1. Continue function-by-function authorization and call-graph review for the remaining authenticated-executable SECURITY DEFINER functions, prioritizing admin, payment, payout, partner verification, shipment transition, and document access paths.
2. Map each no-policy table to its callers, views, triggers, Edge Functions, and service-role access.
3. Confirm compromised-password protection in the Supabase Auth configuration UI/API; the current connected toolset did not expose an Auth settings read/write operation, so it has not been changed.
4. Review the five multiple-permissive-policy warnings for equivalent access semantics before considering consolidation.
5. Review the duplicate capacity-reservation indexes and foreign-key index recommendations against constraints and query plans. Do not drop indexes based only on unused-index notices.

### Current safety decision

No RLS policy, table grant, function grant, function body, index, Auth setting, or production data was changed in this continuation. The evidence gathered is read-only. Security hardening should proceed as targeted, tested migrations after the remaining call paths and intended access contracts are established.


### Privileged RPC scope sampling

A further metadata pass grouped the authenticated-executable SECURITY DEFINER functions by operational area:

- 53 admin-prefixed functions were found. 52 contain auth.uid(), the permission helper, and an AAL2/admin guard marker. The remaining lane-aware capacity list is a wrapper around the already-guarded capacity-list function.
- 28 partner/capacity/capability functions were found; 25 contain auth.uid() and 21 contain the organization permission helper. The remaining cases require call-graph review rather than assuming a vulnerability.
- The current function-name grouping returned no SECURITY DEFINER functions with payment/finance/refund/settlement/payout names. This does **not** establish payment security: payment handling may be implemented in Edge Functions, triggers, or differently named routines and remains a separate review task.
- 16 shipment/document/POD-related functions were identified for the next targeted call-graph and tenant-isolation review.

These are code-pattern inventory results, not penetration-test results. A marker can appear without a correct authorization check, and a function can be protected by a delegated helper without containing the marker itself.


## Payment and Razorpay operating-path audit — 2026-11-07

### Controls observed in active Edge Functions

- Canonical Razorpay order creation and payment verification are active with JWT verification enabled; both independently validate the Supabase user token.
- Order creation checks customer-organization access, confirmed shipment state, accepted customer quote, accepted partner assignment, confirmed capacity reservation/binding, amount/currency precision, and the payment capability registry.
- Live checkout fails closed unless the payment capability registry confirms the provider/currency readiness flags. Non-INR currency requires explicit merchant, presentment, settlement, refund, and FX evidence.
- Payment verification validates the Razorpay HMAC signature, fetches the payment from Razorpay, checks provider order ID, amount, currency, and captured status, then conditionally updates the local payment order.
- The signed webhook verifies HMAC against the raw request body, requires Razorpay event ID, records events idempotently, validates captured amount/currency/status against the canonical order, and invokes a service-role-only transactional finance reconciler.
- The finance reconciler checks the paid order's shipment/organization/accepted quote/partner quote and accepted assignment with confirmed capacity reservation before creating the completed INR financial transaction. Unique provider-reference and idempotency constraints are present.
- Refund execution requires authenticated AAL2, finance approval and permission, requester/reviewer separation, full INR payment amount, and a stable idempotency key. Provider outcomes are reconciled through signed refund webhooks. No refund request rows existed at audit time.
- Legacy Cashfree create, verify, and webhook endpoints inspected are deployed but return HTTP 410 with a retired-provider message. Legacy Razorpay create/process endpoints inspected also return HTTP 410. They are retired at the application endpoint, not deleted from the project.

### Payment data snapshot

| Record category | Current observed state |
|---|---|
| Razorpay payment orders | 1 paid; 5 created |
| Financial transactions | 1 completed Razorpay payment |
| Webhook events | 6 processed payment.authorized; 4 unprocessed captured/order.paid events |
| Refund requests | 0 |
| Partner payouts | 1 marked paid |

These database records are not proof of successful bank settlement or actual withdrawable funds. Provider dashboard and bank reconciliation are still required.

### Exceptions requiring manual reconciliation

1. Four unprocessed payment.captured/order.paid webhook events date from 2026-09-15. Their Razorpay order IDs do not match any current local payment_orders row. Their payloads show captured INR payment attempts, but they are not linked to a canonical KRIM payment order. Do not mark them processed, create revenue, or assume they represent valid KRIM customer receipts. Reconcile against the Razorpay dashboard and original test/live context; preserve the raw event records.
2. Five Razorpay payment_orders remain in created state from 2026-09-25/26, each without a KRIM quote binding and without a stored payment ID. They are about six weeks old. Their provider order status and whether any payment attempt occurred must be checked in Razorpay before expiry/closure or any customer communication. Do not mark them failed/refunded or delete them based only on age.
3. The canonical order creator calls Razorpay before inserting the local payment_orders row. If the provider order succeeds but the database insert fails, it can leave an orphan Razorpay order. The client response currently includes the provider order ID and database error details. Add a safe reconciliation/idempotency design and return a generic public error in a reviewed code change.
4. The order creation request has no explicit timeout/retry strategy around the Razorpay API call. Design a stable idempotency/correlation key and bounded timeout/reconciliation flow before changing this path. Never blindly retry an uncertain provider order creation.
5. The webhook's failed-payment branch updates the canonical order to failed unless it is already paid. Verify retry semantics for multiple failed payment attempts followed by a successful captured payment, and add an explicit state-transition regression test.

### Positive database controls

- Unique constraints exist for Razorpay order ID, Razorpay payment ID, webhook event ID, one open payment order per quote, refund request per payment, refund idempotency key, and provider transaction reference.
- Internal Razorpay financial reconciliation is SECURITY DEFINER with an empty search_path and explicitly requires service_role. It is not executable by anon or authenticated roles.
- Legacy payout mutation functions inspected are not executable by anon or authenticated roles; service_role only. Their older shipment_requests/shipment_financials data model should be kept out of the canonical KRIM shipment payout path until separately reconciled.

### Next safe payment work

1. Reconcile the four orphan webhook events and five stale created orders in the Razorpay dashboard; preserve evidence and do not mutate production status until provider state is known.
2. Add a documented operational reconciliation runbook and a support/finance owner.
3. Harden order-creation uncertainty handling and generic error responses in a separate reviewed Edge Function release.
4. Add regression tests for failed-attempt-then-captured, duplicate event delivery, concurrent order creation, provider timeout, orphan provider order, amount/currency mismatch, duplicate payment ID, refund retry, and payout reconciliation.
5. Verify the one completed financial transaction and one paid payout against provider settlement reports and bank records before describing either as settled or withdrawable.

### Audit boundary

This review inspected deployed Edge Function source and read-only database metadata/aggregate records. No Razorpay API payment/refund was created, no refund was initiated, no payout was sent, no payment/webhook status was modified, and no secrets or keys were read. Live provider and bank reconciliation remains outstanding.


## Shipment, tracking, POD, and document-access review — 2026-11-07

### Controls observed

- The public tracking Edge Function has JWT verification disabled by design, but accepts only a 32-character uppercase hexadecimal opaque token (128 bits of entropy), not sequential shipment IDs. It returns a restricted set of shipment status, route locations, and tracking-event timestamps/location references. It does not return customer identity, goods description, pricing, invoices, or POD files in the inspected response.
- The authenticated shipment tracking RPC requires a signed-in user and checks customer-organization access or active membership in an accepted/active partner assignment before returning shipment details and event history.
- Global shipment creation requires active origin and destination countries/locations, organization access, shipment.create permission, and operational activation of both markets.
- Global quote acceptance checks organization access and shipment.update permission and locks the quote/shipment rows.
- Shipment status transition RPC is not directly executable by anon or authenticated roles; this is consistent with a controlled internal transition path.
- Delivery POD submission verifies the authenticated driver owns the assignment, has active driver membership, is in transit, is linked to an accepted/active partner assignment, and has private evidence uploaded by that driver.
- POD review requires AAL2 MFA and platform-admin permission, rejects self-review by the driver who submitted the evidence, requires an existing private driver evidence object, and records a reason and audit event. Verification then authorizes delivery through an internal function.
- All five inspected Storage buckets are private: pod-documents, krim-partner-verification, krim-driver-evidence, krim-warehouse-evidence, and krim-driver-verification. Storage access is governed by object policies; the inspected customer POD evidence policy requires a verified POD and customer-organization access.
- Customs document submission/review functions require authenticated users, AAL2 for review, accepted broker/customer role checks, uploader ownership, file metadata/path checks, and submitter/reviewer separation.

### Items requiring deeper verification

1. The private pod-documents bucket had no direct authenticated/anonymous object policies in the inspected policy listing. Confirm whether it is intentionally service-role/signed-URL-only and whether it is still used; do not make it public.
2. The public tracking endpoint uses a 128-bit opaque token. Confirm tokens are generated with a cryptographically secure random source, unique constraint/index, and no predictable fallback. The legacy generate_tracking_number() trigger function returns a sequential TRK-<id> value; that legacy identifier must never be accepted by the public token endpoint.
3. Review the complete JSON fields stored in tracking-event metadata before returning any new event types publicly. Keep customer/partner contact data, internal notes, commercial terms, and evidence references out of public tracking responses.
4. The authenticated krim_get_shipment_tracking RPC returns event metadata, coordinates, milestone notes, goods description, and route labels to authorized customer/partner users. Confirm role-based field minimization for each role and ensure partner access is limited to assignments that are still operationally valid.
5. Complete a full call-graph review of all document and POD storage policies, signed URL generation, expiry, revocation, and access logging. Current metadata inspection is not a signed-link penetration test.
6. Verify that every document upload has MIME/content-signature validation, file-size limits, malware scanning or a documented compensating control, and retention/deletion ownership. Storage bucket MIME settings alone are not content validation.

### Current decision

The inspected controls show good design direction for private evidence and role-scoped shipment access. No document, POD, tracking token, storage object, policy, or production record was changed. No public bucket was enabled. The remaining work is focused validation and role-by-role testing, not broad permission changes.


## AI assistant and workflow reliability review — 2026-11-07

### KRIM AI assistant controls observed

- The active `krim-ai` Edge Function has JWT verification enabled, accepts POST only, rejects unapproved browser origins, and independently validates the caller's bearer token with Supabase Auth.
- AI context is resolved through a self-scoped RPC that uses `auth.uid()` and does not accept a caller-supplied user ID.
- AI requests are rate-limited by a database RPC to 20 requests per authenticated user per rolling 10-minute window. If the rate-limit service is unavailable, the endpoint fails closed.
- Conversation lookup is constrained to the authenticated user's own active conversation. Message history is limited to 20 entries, each truncated to 6,000 characters.
- Live operational context is queried using the caller's JWT and existing RLS policies. Inspected policies scope shipments, driver assignments, warehouse tasks/inventory, customs documents, invoices, partner payables/capabilities, exceptions, and alerts to relevant organizations, roles, or assignments.
- The system prompt explicitly makes AI read-only: it cannot execute shipments, approve partners, move funds, issue refunds, change access, or activate markets. It instructs the assistant not to invent rates, shipment status, verification, payment state, FX, legal approvals or compliance.
- Provider calls have a 30-second timeout, output is capped at 1,000 tokens, and provider errors are returned without exposing raw provider response bodies. Requests use `store: false`.
- AI conversation and message RLS policies restrict records to the owning user.

### Notification provider and retry worker

- Notification provider adapter has JWT verification enabled and requires an authenticated platform administrator.
- Resend is currently a credential-readiness check only; the inspected adapter does not send customer email.
- Telegram test path sends a clearly identified founder-authorized test message, not customer/partner notifications.
- Notification retry worker has JWT verification disabled at the gateway, but requires a high-entropy cron secret or a validated authenticated platform administrator before creating a service-role client and processing queued work.
- The retry worker uses bounded provider timeouts and separate claim/finish RPCs for founder enquiry and follow-up Telegram queues. The secret itself was not read.

### Workflow engine snapshot

- 9 workflow runs were present and all 9 were completed.
- 18 action executions were present and all 18 were marked succeeded.
- No queue leases and no dead-letter records were present in the inspected queue tables.
- Automation execution logs contained 3,662 successful workflow-runtime entries, 10 partner-discovery entries, 3 daily-settlement entries, and 2 autonomous-outreach entries. These are application log records, not independent proof that every external message or settlement occurred.
- The current database has extensive workflow queue, lease, retry, idempotency, concurrency-lock and dead-letter tables. The queue tables were empty in the inspected snapshot; the active notification retry worker handles the founder Telegram retry queues.

### Evolution and reliability gaps

1. The AI provider model is currently hard-coded to `gpt-4.1`. Add a centrally controlled model/provider configuration and compatibility test suite so model upgrades can be evaluated and rolled back without changing business workflows.
2. Add automated tenant-isolation regression tests for every role and every live-context table. The current source uses caller JWT/RLS and the inspected policies are scoped, but source inspection is not a cross-tenant penetration test.
3. Add prompt-injection, data-exfiltration, multilingual, long-history, provider-timeout, malformed-response, rate-limit and cost-ceiling tests.
4. Add monitoring for AI provider latency/error rates, token/cost usage, rate-limit denials, context query failures, and conversation persistence failures. No end-to-end monitoring dashboard or alert delivery was proven in this review.
5. Add notification retry tests for duplicate claims, expired leases, concurrent workers, provider 429/5xx, invalid credentials, timeout after provider acceptance, and idempotent completion. No external customer notification was sent during this audit.
6. Keep automated outreach disabled or tightly approval-gated until partner/customer consent, suppression lists, unsubscribe handling, rate limits, and message templates are verified.
7. Confirm the workflow runtime scheduler/worker invocation and recovery behavior operationally. A zero queue/dead-letter snapshot alone does not prove that scheduled workers are running continuously.

### Audit boundary

This was a read-only source, RLS-policy and aggregate-record review. No AI prompt, provider model, rate limit, workflow, notification, secret, queue, or production data was changed. No customer or partner message was sent, and no AI provider request was triggered by this audit.


## Database scalability, scheduler, and resilience baseline — 2026-11-07

### Current database footprint and headroom

- Project is ACTIVE_HEALTHY on PostgreSQL 17.6.1, region ap-northeast-1.
- Database size at audit time: approximately 65 MB.
- Current connections: 13 of configured max_connections 60 (snapshot only; not a concurrency/load test).
- Database buffer cache hit ratio reported 100% at audit time (not a substitute for latency/load testing).
- No deadlocks were recorded in pg_stat_database at audit time; 847 rollbacks and 3,302,716 commits were cumulative counters, not recent-window error rates.
- Largest application tables by size were job_run_details (~12 MB total), krim_country_pack_controls (~1.5 MB), schema_migrations (~872 kB), automation_execution_logs (~608 kB), and audit_log_entries (~288 kB). Current canonical shipments estimate 18 rows; this is a small early-stage workload, not a production-scale benchmark.

### Scheduler reliability evidence

Six active pg_cron jobs were inspected. Their run-history snapshot showed zero failures:
- workflow runtime every minute: 38,392 successful runs
- growth-signal worker every five minutes: 7,673 successful runs
- inquiry follow-up queue every five minutes: 2,002 successful runs
- exception escalation every five minutes: 304 successful runs
- capacity-hold expiry every five minutes: 298 successful runs
- notification retry worker every five minutes: 231 successful runs

All six had recent successful executions on 2026-11-07. This is positive scheduler evidence, but does not prove downstream third-party delivery or end-user outcomes.

### Performance advisor findings

- 27 foreign-key relationships lack a covering index. Review by query workload and join/delete path; do not add all automatically.
- 10 RLS policies have auth-function init-plan warnings. These should be reviewed for safe `(select auth.uid())`/equivalent optimization while preserving policy semantics.
- 5 tables have multiple permissive SELECT policies. Confirm intended OR semantics and consolidate only with regression tests.
- 1 exact duplicate partial unique index exists on `krim_capacity_reservations(organization_id, idempotency_key) WHERE idempotency_key IS NOT NULL`. Both indexes are 8 kB and currently show zero index scans. Do not drop until migration history, dependencies, and production constraints are checked; one unique index must remain to preserve idempotency.
- 671 unused-index notices exist. This is a cumulative/early-workload signal, not a safe deletion list. Keep integrity/unique indexes; evaluate candidates using workload history before any removal.
- No health-advisor findings were returned in this snapshot.
- Security advisor still reports 26 RLS-enabled/no-policy tables (many are private/internal tables) and 126 authenticated-executable SECURITY DEFINER functions, plus leaked-password protection disabled. These are security review items, not automatically database performance defects.

### Query and log interpretation

The top cumulative pg_stat_statements entries at audit time were dominated by schema/introspection queries and the one-minute workflow batch. The workflow batch averaged about 20.7 ms over 38,403 calls. This is encouraging for the worker itself; it is not a user-facing API latency benchmark. No production load test or representative shipment-volume test has been run.

### Resilience and cost safeguards

1. No Supabase development branches existed at audit time. Production DDL must be tested on a branch or isolated staging database before merge; branch creation may incur costs, so confirm pricing first.
2. Verify backup/PITR entitlement, retention window, and restore procedure in the Supabase dashboard. This tool audit did not establish backup availability or a successful restore test.
3. Establish an encrypted, independent export/backup procedure for critical business records and payment reconciliation evidence, subject to privacy and retention rules.
4. Define recovery objectives: RPO/RTO, incident severity, responsible operator, and customer communication.
5. Add alerts for database connection saturation, slow queries, failed scheduled jobs, queue age/dead letters, storage growth, Edge Function errors, and payment reconciliation drift.
6. Set a retention/archive policy for `job_run_details`, automation logs, audit logs, webhook payloads and other high-growth records. Never purge financial/audit evidence without a documented retention schedule and compliant archive.
7. Before scale-up, benchmark realistic flows: customer shipment creation, partner quote search/acceptance, capacity reservation, driver updates, warehouse receipt, customs documents, POD verification, payment webhook reconciliation, and customer tracking.
8. Do not increase compute, create branches, add paid monitoring, or delete indexes until a measured need and cost are known.

### Current scale assessment

The database is small and healthy in this snapshot, with a scheduler showing consistent successful runs. That is a sound early foundation, but it does not establish readiness for high traffic, high availability, disaster recovery, or global multi-region operations. The next engineering task is safe query/policy optimization and tested backup/restore planning, followed by measured end-to-end load tests.

### Audit boundary

Read-only project, advisor, SQL statistics, migration/branch metadata and scheduler history were inspected. No indexes, policies, tables, migrations, compute settings, backups, cron schedules, or production records were changed.
