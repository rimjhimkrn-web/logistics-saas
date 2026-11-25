# Phase 00 — Gate C3.38: Platform Observability, Monitoring, Alerting & Operational Support Readiness

**Date:** 25 November 2026  
**Baseline:** immutable source commit `72d75a18f985ceb09e468839435ee95700e11e46`  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Method:** read-only source review of platform-health/status pages, smoke/deployment workflows, support desk, enterprise integration workspace and dated monitoring/notification/provider audits. No live monitoring endpoint, provider credential, log stream, webhook, alert route or customer support record was queried or changed.

## Executive decision

**C3.38 FAIL / BLOCKED — NO-GO for monitoring certification, 24/7 operational support claims, incident-response SLA claims, or customer/partner notification guarantees.**

There is a useful distinction between the privileged platform-health page, which correctly says infrastructure telemetry is not connected, and the public status page, which still presents static “All Systems Operational” / “Updated: Live” badges and unsupported service claims. The Production smoke workflow provides static repository validation, not production service monitoring. Founder-only Telegram alert infrastructure exists, but it is not general customer/partner alerting and does not prove human receipt. The support desk has a protected authenticated workflow, but it does not establish a staffed, monitored, time-bound support operation.

This is a static source and dated-evidence audit. It does not claim a fresh live health check or current provider configuration.

## 1. Monitoring surface inventory

### 1.1 Privileged platform health page

`public/admin/platform-health.html` is guarded by the admin access script and explicitly states:
- not connected to a verified infrastructure telemetry provider;
- no live cluster, database latency, connection-pool, AIS socket, KMS or uptime measurements;
- “NOT MONITORED” and not suitable for incident response or availability decisions;
- no production configuration controls exposed.

This is a positive truthfulness control. It is an administrative disclosure page, not a monitor.

### 1.2 Public status page

`public/status.html` statically asserts “All Systems Operational”, “Updated: Live” and marks Supabase/RLS, Razorpay escrow, GPS telemetry and cryptographic ePOD services “Operational”. The reviewed page contains no verified live status endpoint, timestamp source, health probe, region inventory, incident feed or data freshness contract. These statements conflict with the actual audited readiness of those services and the privileged platform-health page.

**P0:** The public page can mislead customers and partners about current availability and operational capability. Remove unsupported live/operational labels or replace them with an honest status feed with timestamp, source, scope, unknown/degraded states and incident history. Do not call the status feed live until independent probes and freshness checks are actually operating.

### 1.3 Smoke tests and deployment workflows

`.github/workflows/krim-production-smoke.yml` runs on pushes to `main`, pull requests targeting `main`, and manual dispatch. It runs `scripts/krim-production-smoke.mjs` and the static repository audit, then uploads an artifact with 30-day retention. The inspected job does not call a production health endpoint, authenticate a synthetic user, test a tenant boundary, measure API latency, inspect Edge Function health, validate provider callbacks or assert customer/partner workflow success. Its name must not be mistaken for a production runtime smoke test.

`.github/workflows/deploy-krim-pages.yml` builds the site and deploys GitHub Pages after a successful build. It has a concurrency group, but the reviewed workflow itself does not demonstrate post-deploy URL verification, synthetic browser journeys, service health assertions, automated rollback or incident notification. Actions are referenced by version tags rather than immutable commit SHAs in the inspected baseline. C3.31 already recorded that mandatory branch protection/review/status checks were not demonstrated.

**P1:** Separate static CI checks from runtime synthetic monitoring; add a post-deploy smoke stage only after safe test identities and environment isolation are proven. Pin third-party actions, retain build/deploy provenance and alert on failed or stale deployment checks.

## 2. Metrics and telemetry coverage

No verified provider-sourced telemetry contract was found for:
- public site availability and DNS/TLS expiry;
- Supabase database/API availability, latency, connection pool saturation, quota, storage, Auth and Edge Function error rates;
- per-function invocation count, error class, duration, timeout and cold-start/limit signals;
- queue depth, oldest pending age, stuck processing leases, retry count, dead letters and claim/reclaim outcomes;
- cron last success/failure, schedule lag, duration and missed-run recovery;
- payment webhook signature/processing/reconciliation lag and unknown outcomes;
- customer/partner provider delivery receipts, bounce/rejection and callback latency;
- tenant-isolation/security events, privileged actions, audit-write failures and session revocation;
- route, shipment, dispatch, warehouse, customs and POD service-state freshness.

The admin health page accurately labels these categories unmonitored. No live telemetry or time-series query was executed for this gate.

## 3. Alerting and notification readiness

Historical notification evidence and C3.30 show a narrow founder Telegram retry path, not a general operational alerting service. The worker is limited to founder inquiry/follow-up notifications. Telegram API acceptance is not proof of device delivery or human acknowledgement. Claimed jobs can remain `processing` indefinitely after worker failure because stale lease reclaim is absent. The notification provider adapter has no verified customer/partner dispatch path; Resend sending is disabled; WhatsApp Cloud API is not connected in the reviewed evidence. General outbox/delivery/receipt evidence is not established.

**P0:** No independently verified alert path guarantees detection and acknowledgement of critical platform or operational incidents. Stuck worker/queue and provider outage states can remain unnoticed.

**P1:** Build alert routing only after defining severity, ownership, deduplication, suppression, escalation and acknowledgement semantics. Use independent channels for critical alerts; distinguish queued, claimed, provider-accepted, delivered (only with genuine receipt), acknowledged by operator, failed, retrying and dead-lettered. Maintain a tested fallback if the primary alert provider is unavailable. Do not send customer-facing alerts until consent, purpose, contact verification and callback controls are proven.

## 4. Operational support and incident management

The privileged support desk (`app/platform-admin/support-desk.html`) requires a signed-in session and invokes a server-side admin overview gate; it checks platform administrator role, presents persisted tickets only, and separates customer-visible replies from internal notes. Status closure is not a refund, claim approval, shipment change or payment action. This is a positive access-boundary foundation.

However, the existence of a support UI does not prove:
- a staffed support team or named on-call rota;
- published and contractually accepted support hours;
- response/resolution SLAs, measurable queue monitoring or escalation coverage;
- incident commander, technical lead and business decision-maker availability;
- 24/7 coverage across time zones and languages;
- independent alert delivery and operator acknowledgement;
- customer/partner status communications during outages;
- post-incident review, corrective action ownership and closure evidence.

Prior continuity and operations audits recorded no complete incident command and communications lifecycle. Do not advertise 24/7 support, guaranteed response times or operational SLA until owners, staffing, escalation and measured performance are evidenced.

## 5. Integration and provider health

The enterprise integration workspace is an authenticated directory, not a live connector monitor. It does not query connector health, API/EDI delivery, webhook latency or automation execution. The prior provider inventory found no verified HubSpot, Resend send, WhatsApp Cloud API, LinkedIn, YouTube or carrier/ERP/TMS/WMS/GPS integration health. Razorpay technical endpoints exist, but commercial collection is disabled/blocked and the C3.25/C3.30 captured-webhook kill-switch issue remains a P0.

**P1:** Create a canonical integration registry with provider, owner, environment, enabled state, permitted scopes, credential reference (never secret value), last successful probe, last failure, health timestamp, webhook verification status, delivery lag, revocation state and evidence link. Health probes must be read-only, least-privilege and rate-limited; provider API acceptance must not be confused with downstream business completion.

## 6. Cross-gate critical risks

- C3.30: stale notification processing claims, false Telegram delivered state and Razorpay captured webhook bypass of freight collection disable control.
- C3.31/C3.37: no verified backup/restore, measured RPO/RTO, full environment observability or tested recovery.
- C3.26: stale control-tower data and no proven unified incident/escalation operation.
- C3.28/C3.32: admin authorization/audit durability and broad privileged-function review remain blocked.
- C3.36: customer support, notification, claims and service-level journey not proven end to end.

These are dependencies, not repeated runtime tests. No remediation was performed in this gate.

## 7. Minimum acceptance plan — NOT RUN

Only after environment isolation, safe synthetic identities and explicit authorization are established:

1. Publish a non-sensitive health endpoint with dependency status, source timestamp and stale/unknown behavior; prove it never exposes secrets, tenant data or internal topology.
2. Run external synthetic checks for DNS/TLS/site reachability and controlled authenticated Staging journeys.
3. Collect provider-sourced database/API/function/queue/cron metrics with bounded cardinality and redacted payloads.
4. Simulate an Edge Function timeout, stuck queue lease, cron miss and provider outage; prove detection, alert deduplication, escalation, operator acknowledgement and recovery.
5. Simulate alert-provider failure and prove independent fallback without uncontrolled message storms.
6. Verify webhook signature/error/retry/unknown-outcome metrics with freight collection disabled and no financial side effects.
7. Exercise incident declaration, commander assignment, customer/partner communication approval, safe resume and post-incident review.
8. Confirm status page values, timestamps, incident history and stale-data warnings match source telemetry.
9. Measure support queue first-response/resolution metrics from real authorized synthetic tickets; do not infer staffing or SLA from the UI.

All tests above remain NOT TESTED. No production endpoints were probed and no messages were sent.

## 8. Gate disposition

| Control | Status |
|---|---|
| Privileged platform-health disclosure is truthful | PASS (static source review) |
| Public status page truthfulness | FAIL / BLOCKED |
| Production runtime synthetic monitoring | NOT TESTED |
| Database/API/function telemetry | NOT EVIDENCED |
| Queue/cron health and stale-worker alerts | FAIL / BLOCKED |
| General customer/partner alerting | FAIL / BLOCKED |
| Founder Telegram alert delivery/acknowledgement | PARTIAL / NOT HUMAN-VERIFIED |
| Integration connector health monitoring | NOT EVIDENCED |
| Incident command and on-call operation | FAIL / BLOCKED |
| Support staffing and SLA evidence | NOT EVIDENCED |
| Post-deploy runtime validation/rollback | NOT TESTED |

**Final verdict: C3.38 FAIL / BLOCKED.** No monitoring certification, 24/7 support promise, uptime/response SLA, live provider-health claim or customer/partner notification guarantee is supported. Internal development and limited non-binding partner discovery may continue with truthful disclosures.

## 9. Evidence references

- `public/admin/platform-health.html`
- `public/status.html`
- `.github/workflows/krim-production-smoke.yml`
- `.github/workflows/deploy-krim-pages.yml`
- `app/platform-admin/support-desk.html`
- `app/enterprise/integrations.html`
- `docs/audits/KRIM-PAGE-101-SYSTEM-HEALTH-AND-INTEGRATION-MONITORING-REVIEW-2026-11-16.md`
- `docs/audits/KRIM-NOTIFICATION-ALERT-ROUTING-DELIVERY-AND-RETRY-ASSURANCE-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-EXTERNAL-INTEGRATION-READINESS-AND-PROVIDER-INVENTORY-AUDIT-2026-11-16.md`
- `docs/testing/phase-00-gate-c3-30-shared-events-notification-provider-delivery-reliability-2026-11-25.md`
- `docs/testing/phase-00-gate-c3-31-global-infrastructure-environment-isolation-deployment-reliability-2026-11-25.md`
- `docs/testing/phase-00-gate-c3-37-global-platform-resilience-disaster-recovery-backup-business-continuity-audit-2026-11-25.md`

## 10. Safety and evidence boundary

Read-only immutable-baseline source review and reconciliation with dated audit records only. No live health probes, log queries, provider calls, credential access, support ticket access, webhook replay, alert/notification, workflow dispatch, DNS change, Production/Staging SQL/RPC, branch protection change or deployment was performed. Static CI validation is not runtime monitoring; historical findings are not fresh live measurements.
