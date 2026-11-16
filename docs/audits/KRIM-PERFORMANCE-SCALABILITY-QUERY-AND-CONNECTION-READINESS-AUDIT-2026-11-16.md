# KRIM Performance, Scalability, Query and Connection Readiness Audit
**Date:** 16 November 2026  
**Method:** Read-only production PostgreSQL statistics/catalog/cron inspection and static review of selected application list queries. No EXPLAIN ANALYZE on production, no workload/stress tests, no DDL/DML, no settings changes.

## Executive decision
**NO-GO for a claim of proven high-volume scalability.** The database is currently small and operationally quiet. No invalid/not-ready indexes were found, pg_stat_statements is enabled, and scheduled jobs sampled in this review were succeeding. However, no load test has established throughput or latency under concurrent users, several frequently scanned small tables rely on sequential scans, application list views use fixed result caps rather than a demonstrated pagination contract, and background jobs create a continuous workload that needs capacity monitoring.

## 1. Database and connection baseline
- PostgreSQL version: 17.6.
- Configured max_connections: 60.
- Snapshot: 13 connections reported by the first count query; one active connection at that instant. The pg_stat_activity state breakdown showed four idle ClientRead sessions, one active session and extension-related sessions. ClientRead is an idle client wait, not evidence of a database lock wait.
- The count and state snapshots were taken in separate queries and are not an atomic measurement.
- Connection-pool configuration and peak concurrent usage were not verified. A quiet snapshot cannot prove capacity for peak traffic.
- pg_stat_statements 1.11 is installed and available.

## 2. Index health and query statistics
- Public indexes inspected: 1,561.
- Invalid indexes: 0.
- Not-ready indexes: 0.
- Earlier catalog review found 673 unique indexes.
- Index statistics are cumulative since their last reset and reflect both current code and past audit/tool activity; zero index scans do not establish an index is unnecessary.
- Several tables have many sequential scans relative to their very small current size. Examples: krim_events (21,048 sequential scans, 417,292 tuples read, estimated 23 live rows), krim_organization_members (6,243 sequential scans, 37,137 tuples read, estimated 13 live rows), krim_organizations (2,294 sequential scans, 23,706 tuples read, estimated 14 live rows), krim_shipments (647 sequential scans, 10,432 tuples read, estimated 18 live rows), and krim_quotes (682 sequential scans, 4,744 tuples read, estimated 7 live rows).
- At current cardinalities, sequential scans can be the correct PostgreSQL plan. These counters are scale-up watchpoints, not confirmed missing-index defects. Review actual query plans and predicate shapes after representative staging data exists.
- No production index was added or removed.

## 3. Query workload and scheduled jobs
pg_stat_statements highlights the following KRIM workload totals (cumulative, not a single request's latency):
- workflow runtime batch: 51,479 calls, mean 22.48 ms, cumulative 1,157,423.8 ms.
- inquiry follow-up reminder queue: 4,617 calls, mean 29.33 ms, cumulative 135,424.4 ms.
- growth signal processor: 10,289 calls, mean 12.78 ms, cumulative 131,523.1 ms.
- exception escalation processor: 2,920 calls, mean 39.34 ms, cumulative 114,863.9 ms.
- capacity-hold expiry: 2,914 calls, mean 22.44 ms, cumulative 65,402.5 ms.

The largest overall statement totals also include Supabase/PostgREST catalog introspection, extension metadata and timezone catalog queries. They should not be attributed to KRIM customer-facing application requests.

Nine active cron jobs were inspected. The selected job histories contained successful runs only in the returned grouped snapshot. The one-minute workflow runtime job had 51,468 succeeded runs; five-minute jobs for growth signals, follow-up reminders, exception escalation, capacity expiry and notification retry were also returning succeeded rows. Recent runs completed in tens to low hundreds of milliseconds in the sample. This is positive operational evidence, but it does not verify queue backlog, work completion semantics, alerting on missed schedules, or recovery after a worker crash.

## 4. Table maintenance and storage
- Current public table sizes are small; the largest observed table was country-pack controls at approximately 1.48 MB total, followed by automation execution logs at approximately 608 KB.
- Some small tables show high estimated dead-tuple percentages, including workflow dispatch/execution tables and quote/organization tables. Absolute counts are low, estimates are approximate, and dead-tuple percentages alone do not prove bloat or require VACUUM intervention.
- Last auto-analyze/autovacuum timestamps are absent or old for some tables. Review autovacuum thresholds and analyze freshness as event/audit tables grow; do not run manual maintenance without an approved maintenance plan.

## 5. RLS and query shape
- 412 public RLS policies were counted; 352 reference auth.uid() and 263 call private.krim_has_* membership/permission helpers.
- Many policies already wrap auth.uid() in scalar SELECTs, consistent with Supabase's recommendation to avoid repeated per-row function evaluation.
- Membership helper predicates are used across many tables. Ensure their lookup keys and underlying organization-membership joins remain indexed and measure representative tenant queries under realistic data volume.
- RLS policy count or use of helper functions is not itself a performance failure. Security semantics must not be weakened to improve speed.

## 6. Frontend list and pagination review
Selected workspace landing pages use bounded result caps:
- Enterprise landing: up to 200 canonical shipment rows, with a fallback to legacy shipment_requests on any canonical query error (the fallback correctness issue is already recorded in the frontend integration audit).
- Operations landing: up to 50 shipments, 50 exceptions, 12 tracking events, 20 warehouse transfers and 20 returns.
- The reviewed landing pages do not show a cursor/next-page contract in those query paths. These are dashboard summaries, but they must not be mistaken for complete operational registers.
- Use stable keyset/cursor pagination for large shipment, audit, event, finance and exception registers; include all sort keys plus a unique tie-breaker. Apply server-side filters and bounded page sizes. Preserve tenant filters in every page request.
- Keep dashboard summaries bounded and clearly label them as recent/limited; provide a separate paginated register for full history.

## 7. Priority actions (after migration reconciliation)
1. P1: Establish a baseline load-test profile in isolated staging: representative nine-workspace concurrent users, list reads, RLS, quote/assignment contention, workflow queues and event ingestion. Measure p50/p95/p99, error rate, pool wait time, DB CPU/IO and queue age.
2. P1: Verify Supabase pooler mode and application connection path; monitor active, idle, idle-in-transaction and waiting sessions against the 60-connection ceiling. Alert well before saturation.
3. P1: Add cursor pagination and explicit completeness labels to full operational registers; retain bounded dashboard cards.
4. P1: Profile workflow runtime and event-processing queries with EXPLAIN (without ANALYZE on production unless explicitly approved) in staging with representative volume; inspect backlog and idempotent retry behavior.
5. P2: Revisit sequential-scan-heavy small tables only when realistic growth and query plans show a problem; avoid speculative indexes.
6. P2: Monitor autovacuum/analyze freshness and table/index growth for audit, workflow, event and shipment history.
7. P2: Add operational dashboards for cron last success, consecutive failures, duration, backlog age, retry/lease recovery and notification delivery.

## Release decision
**NO-GO for high-volume scalability certification.** The current small production footprint and successful sampled cron runs are encouraging, but there is no load test, no proven peak connection profile and no complete pagination strategy for operational history. No database settings, indexes, cron jobs or application code were changed.

## Change boundary
Read-only PostgreSQL statistics, catalog, cron metadata/history and static frontend source inspection only. No EXPLAIN ANALYZE, stress test, production mutation, function invocation, cron change, provider request, shipment operation or financial transaction was performed.
