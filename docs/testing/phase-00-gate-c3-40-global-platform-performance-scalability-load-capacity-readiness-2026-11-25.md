# Phase 00 — Gate C3.40: Global Platform Performance, Scalability, Load & Capacity Readiness

**Date:** 25 November 2026  
**Baseline:** immutable source commit `72d75a18f985ceb09e468839435ee95700e11e46`  
**Method:** read-only review of immutable-baseline source, capacity and rate-limit migrations, and prior dated Production performance, capacity, abuse-protection and observability audits. No live workload, EXPLAIN ANALYZE, load test, connection test, benchmark, RPC, SQL mutation or configuration change was performed.

## Executive decision

**C3.40 FAIL / BLOCKED — NO-GO for high-volume scalability certification, public traffic ramp, enterprise SLA, throughput/latency guarantees or a claim that KRIM can support thousands of concurrent users.**

The historical Production database was small and quiet, with some encouraging index, query-statistics and cron observations. There is meaningful source-level concurrency protection in selected capacity reservation paths. But no representative load test, peak connection profile, pooler verification, latency/error SLO, multi-tenant workload profile, queue-backlog stress test or resource saturation/recovery test is evidenced. Current low volume is not scalability proof.

## 1. Historical database and query baseline

The 16 November 2026 read-only performance audit recorded:
- PostgreSQL 17.6;
- configured `max_connections = 60`;
- one snapshot of 13 connections and one active connection (separate queries, not an atomic sample);
- pg_stat_statements 1.11 enabled;
- 1,561 public indexes inspected, with zero invalid and zero not-ready indexes;
- small public tables, with country-pack controls around 1.48 MB and automation execution logs around 608 KB in that snapshot.

Cumulative pg_stat_statements examples in that audit:
- workflow runtime batch: 51,479 calls, mean 22.48 ms;
- inquiry follow-up reminder queue: 4,617 calls, mean 29.33 ms;
- growth signal processor: 10,289 calls, mean 12.78 ms;
- exception escalation processor: 2,920 calls, mean 39.34 ms;
- capacity-hold expiry: 2,914 calls, mean 22.44 ms.

These are cumulative statement statistics, not end-user request latency, and include workload accumulated over an unknown interval. They cannot be used as p95/p99 service latency or capacity forecasts. The audit explicitly noted that some sequential-scan-heavy tables were tiny; no missing-index defect was asserted. Index usage counters were cumulative and potentially affected by prior audit/tool activity.

## 2. P0 — No representative load or scalability evidence

No evidence was found of a completed representative load profile covering the nine KRIM workspaces, public enquiry/auth, tenant-scoped reads, shipment lists, quote contention, capacity reservation, warehouse movement, tracking, event ingestion, finance controls, notifications and scheduled workers together.

No verified measurements exist for:
- throughput and sustainable request rate;
- p50/p95/p99 endpoint latency;
- error, timeout, retry and saturation rates;
- database CPU, memory, disk I/O, storage growth and IOPS;
- connection-pool wait, active/idle/idle-in-transaction/waiting sessions;
- lock waits, deadlocks, transaction duration and contention;
- queue depth, oldest-item age, worker throughput and retry/dead-letter rates;
- Edge Function cold starts, concurrency, execution duration and memory;
- frontend Core Web Vitals and mobile-network performance;
- degradation, backpressure, graceful rejection and recovery under overload.

**Impact:** no evidence-based safe user, shipment or request capacity can be published. Do not claim 1,000+ users, global-scale capacity, 99.99% availability, or a guaranteed service level.

## 3. P1 — Connection management and pooler path unverified

The historical database configuration showed a 60-connection ceiling and 13 connections in one quiet snapshot. The actual production client connection path, pooler mode, pool sizing, per-function concurrency, peak simultaneous sessions and saturation behavior were not established.

Required:
- document every browser/server/Edge Function/worker connection path;
- confirm Supabase pooler mode and supported transaction/session behavior for each client;
- establish an aggregate connection budget below the database ceiling, including operational/admin reserve;
- instrument pool wait, connection acquisition timeout, idle-in-transaction sessions and connection churn;
- test burst traffic and worker concurrency in isolated staging;
- use bounded concurrency, short transactions, timeouts and backpressure.

Never increase `max_connections` or change pool settings based on a single historical sample.

## 4. P1 — Fixed result caps are not complete pagination

The historical frontend review found:
- Enterprise landing reads up to 200 canonical shipment rows and falls back to legacy `shipment_requests` on canonical query errors (the fallback integrity issue is already recorded in C3.27/C3.39);
- Operations landing uses fixed caps of 50 shipments, 50 exceptions, 12 tracking events, 20 warehouse transfers and 20 returns;
- the inspected landing query paths did not show a cursor/next-page contract.

These caps can be acceptable for summary cards but do not establish complete operational registers. A capped list can silently omit older or higher-volume records.

Required:
- label dashboard cards as recent/limited with as-of timestamps;
- provide server-filtered keyset/cursor pagination for full shipment, audit, finance, exception, event and inventory registers;
- use stable sort keys plus unique tie-breakers;
- preserve tenant/organization filters on every page;
- test deep pagination, concurrent inserts/updates, duplicate/omitted rows and export limits.

## 5. P1 — Background jobs need backlog and recovery capacity proof

The historical audit inspected nine active cron jobs; selected histories showed successful runs, including a one-minute workflow runtime job and five-minute growth, follow-up, exception escalation, capacity expiry and notification retry jobs. Sampled durations were tens to low hundreds of milliseconds.

This is positive historical evidence of scheduled execution, but not proof that jobs complete intended business work, that queues remain bounded, that missed schedules are detected, or that workers recover after crashes. C3.30 separately found notification jobs can remain stuck in processing indefinitely and provider acceptance is not delivery. C3.38 found no independently verified alert/acknowledgement route.

Required:
- track scheduled last-success time, duration, consecutive failures and missed-run detection;
- measure queue depth, oldest item age, throughput, retry counts and dead-letter counts;
- add leases/visibility timeouts and safe stale-processing reclamation;
- bound worker concurrency and batch size; ensure idempotency and poison-message handling;
- test worker crash, duplicate delivery, provider slowdown, database slowdown and recovery without duplicate side effects;
- connect alerts to accountable human acknowledgement and fallback.

## 6. P1 — Capacity reservation concurrency is source-designed but untested

Selected capacity reservation source and migrations contain meaningful controls:
- exact shipment-leg and partner capability checks;
- resource and availability row locks with `FOR UPDATE ... SKIP LOCKED`;
- overlapping trip-window calculations;
- resource-level reservation aggregation across availability records;
- organization-scoped idempotency and conflicting replay rejection;
- exact route lane and transport mode checks.

These are positive code-level safeguards. They are not proof of concurrent correctness. C3.23/C3.39 independently found warehouse inventory transfer and generic picking paths that may consume shipment-reserved stock. C3.35 found market/corridor activation remains blocked. Real capacity remains unverified.

Required isolated tests:
- 1, 2, 10, 100 simultaneous reservations against the same resource and overlapping windows;
- different availability records attached to one resource;
- adjacent/non-overlapping windows, expired holds, cancellation/release and stale resource evidence;
- simultaneous driver/vehicle assignment and document expiry/revocation;
- warehouse reservation vs transfer/pick/adjustment races;
- duplicate/reordered retries and client timeout after commit;
- verify exactly one valid reservation and no overbooking/overselling.

No such concurrency tests were run in this gate.

## 7. P1 — Public endpoint abuse controls can amplify load

The 16 November public endpoint audit found useful per-email contact throttling, a trusted Cloudflare-IP limiter when the header is present, honeypot handling and high-entropy hashed driver invitation tokens. It also identified:
- the public contact IP limiter is skipped when the trusted IP header is absent;
- public shipment tracking has no visible application-level rate limiter or explicit request-body size cap;
- registration pages reviewed did not contain CAPTCHA/Turnstile integration;
- provider-side Auth rate-limit/CAPTCHA configuration was unverified.

The authenticated AI rate-limit migration provides a per-user ten-minute request window, but does not prove global abuse protection or system-wide cost/concurrency controls.

Required: trusted ingress identity, bounded body sizes, per-IP/token/user/tenant and global limits, bot mitigation where appropriate, cost budgets, burst controls, abuse telemetry and fail-closed behavior where trusted identity is required. Preserve legitimate accessibility and do not rely on CORS as rate limiting.

## 8. P2 — Indexes, query plans, vacuum and storage need representative growth data

No invalid/not-ready indexes were found in the historical review, but index health does not prove workload efficiency. Sequential scans on tiny tables are not defects. Table statistics and cumulative query counters require context.

After a representative isolated dataset exists:
- capture EXPLAIN (ANALYZE, BUFFERS) only in isolated staging for realistic query shapes;
- profile RLS membership helpers and tenant joins;
- inspect composite indexes against actual filter/order predicates;
- monitor table/index growth, dead tuples, analyze freshness and autovacuum;
- avoid speculative indexes and avoid weakening RLS to improve query speed;
- establish retention/partitioning policy only when measured growth justifies it.

## 9. Required staged performance programme — NOT RUN

Only after migration provenance is reconciled, staging isolation is independently verified, and synthetic fixtures are approved:

1. Capture an environment/resource baseline and exact application commit.
2. Seed synthetic data volumes representative of expected tenants, shipments, legs, quotes, events, audit history, inventory, and queues.
3. Establish a low-rate smoke baseline and validate correctness.
4. Run 1 → 10 → 100 → 500 → 1,000+ virtual-user steps only if each preceding stage passes.
5. Include nine-workspace mixed traffic, public endpoints, RLS, pagination, quote/capacity contention, warehouse operations, tracking, event queues and cron overlap.
6. Record p50/p95/p99, throughput, error/timeout rate, DB resource use, connection pool wait, lock waits, queue age and worker completion.
7. Run soak tests, burst tests, dependency slowdown, worker crash, database saturation and recovery.
8. Verify tenant isolation, idempotency and financial/physical integrity during all load stages.
9. Set conservative capacity limits and backpressure thresholds with evidence-based headroom.
10. Retest after remediation and preserve machine-readable results, logs, dashboards and commit/environment fingerprints.

All load, stress, soak, concurrency, failover and recovery tests remain **NOT TESTED** in this gate.

## 10. Gate disposition

**Final verdict: C3.40 FAIL / BLOCKED.** No high-volume capacity or latency commitment is supported. Limited internal development and carefully controlled partner discovery may continue, but public traffic should not be ramped on the assumption that scalability has been proven.

## Evidence references

- `docs/audits/KRIM-PERFORMANCE-SCALABILITY-QUERY-AND-CONNECTION-READINESS-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-CAPACITY-RESERVATION-AND-WAREHOUSE-INVENTORY-CONTROL-REVIEW-2026-11-16.md`
- `docs/audits/KRIM-PUBLIC-AUTHENTICATION-ABUSE-PROTECTION-RATE-LIMIT-CAPTCHA-AND-TOKEN-REPLAY-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-OPERATIONS-ROUTE-CARRIER-AND-CAPACITY-PLANNING-REVIEW-2026-11-16.md`
- Prior QA gates C3.23, C3.26, C3.30, C3.31, C3.35, C3.38 and C3.39.

## Safety and evidence boundary

Read-only source and historical audit synthesis only. No live database query, EXPLAIN, load/stress/concurrency/soak test, endpoint probe, RPC, SQL mutation, connection/pool setting change, cron action, provider request, notification, shipment, payment, inventory movement or deployment was performed. Historical 16 November metrics are dated snapshots, not current resource measurements. No Production/Staging change was made.
