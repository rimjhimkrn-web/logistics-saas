# KRIM Global Operations Control Tower Audit — 2026-11-16

## Scope and safety
Read-only audit of the main operations workspace, shipment/dispatch/tracking/exception/warehouse/customs child workspaces, escalation RPCs, shipment snapshot RPC, dispatch-readiness RPC and live operational counts. One unsafe unused-looking frontend runtime was neutralized. No production database records, schema, RLS policies, permissions, dispatches, alerts or exceptions were changed.

## Main findings

### 1. Main control tower access
- `app/operations/index.html` verifies an authenticated session and active membership in an active organization whose type is `operations`.
- The main dashboard then queries shipment, exception, tracking, snapshot, warehouse-transfer and return data. Table queries remain subject to Supabase RLS.
- `krim_operations_list_shipment_snapshots(p_limit)` is SECURITY DEFINER with empty search_path, authenticated-only. It checks active operations organization membership and additionally requires `shipment.view` permission on the shipment's customer organization. This is a meaningful server-side scope check.
- Dashboard counts and empty states are permission-scoped, not global network totals. The UI communicates that caveat.
- The dashboard does not currently surface a full unified work queue with accountable owner, priority, next action, SLA clock, last verified source and customer communication state. Snapshot data exists, but it is not yet a reliable real-time control tower.

### 2. Child workspace access is inconsistent
- `app/operations/shipment-control.html`, `tracking-activity.html`, `capacity-planning.html`, `carrier-coordination.html`, `customs-readiness.html` and `warehouse-coordination.html` establish authenticated session and active operations organization membership. Their own status copy acknowledges that fine-grained permissions or write workflows are not connected.
- The data reads are direct table queries and therefore rely on table RLS. A membership check in browser code is not a substitute for server-side permission checks; the UI should not imply it is.
- `dispatch-control.html` calls `krim_operations_dispatch_readiness`, which checks `shipment.dispatch` for partner-organization scope and evaluates current partner compliance, assignment, handover, vehicle and driver conditions. It is a read-only readiness result, not dispatch execution.
- `exception-management.html` uses `krim_acknowledge_exception_escalation` and `krim_resolve_operational_exception`. Both SECURITY DEFINER functions use empty search_path and require `compliance.manage` on the exception organization. They lock relevant rows and write audit events. Resolution also closes associated open escalations and stops pending timers/actions/escalation runs.

### 3. Exception and escalation infrastructure is configured but unproven
Live counts:
- Exceptions: 0
- Exception escalation policies: 3 active
- Escalations: 0
- Exception actions: 0
- Exception timers: 0
- Escalation orchestration runs: 0
- Shipment alerts: 1 open
- Shipment returns: 0

The escalation processor is an internal SECURITY DEFINER function, not executable by anon/authenticated. It creates escalation rows from due exceptions and matching active policies, using row locks and skip-locked processing. Its metadata explicitly sets notification status to disabled until verified. Therefore an escalation record is not proof that an alert reached a human.

### 4. Snapshot and alert freshness is a critical operational blocker
- Shipment snapshots: 18.
- Snapshot health states: 17 healthy, 1 attention.
- Latest snapshot captured: 2026-11-06 06:46:23 UTC, approximately 9 days 21 hours old at audit time.
- The single open medium delay alert was triggered 2026-09-19 11:08:30 UTC, approximately 57 days 17 hours old at audit time.
- A control tower showing these values without a prominent stale-data warning could lead operators to act on obsolete status. The main workspace currently displays the snapshot capture timestamp, but does not enforce a freshness threshold or block a stale snapshot from looking current.
- Do not close, regenerate, or mutate the old alert just to clear the dashboard. Its owner, source and resolution evidence need investigation through a controlled workflow.

### 5. Unsafe simulated telemetry and rerouting removed
The legacy `public/operations/operations-runtime.js` contained a hard-coded vessel AIS coordinate/speed log and fictional rerouting result (including destination codes, hours saved and cost delta). These were not connected to a verified provider or live routing/capacity/compliance data.
- Updated the module to return explicit `provider_not_connected` / unavailable states.
- Removed timers, hard-coded vessel positions, fake reroute metrics and simulated success logs.
- Preserved exported class/function names for compatibility.
- Repository search found no current source reference to `operationsRuntime` or `operations-runtime.js`; the file appears unused by the main workspace, but it is now safe if later imported.
- No AIS provider, live ETA prediction or automated rerouting is claimed.

## Priority corrections

### P0
1. Add snapshot freshness enforcement: show last capture age, stale/unknown badge, and suppress health/SLA conclusions when snapshot exceeds an approved freshness threshold. Never treat old snapshots as current.
2. Reconcile the September open delay alert: identify owner, source event, shipment state, SLA basis and evidence. Preserve audit history; no blind close.
3. Unify operations authorization contract across child workspaces: session + active operations membership + named permission per action + row/leg scope. Backend RLS/RPC remains authoritative.
4. Add an operator queue that links shipment/leg, verified issue, priority, owner, due time, last evidence, next allowed action, customer notification status and immutable event history. Empty data must render as empty, not fabricated work.

### P1
1. Ensure every alert and escalation has idempotent source-event linkage, deduplication, accountable owner, escalation deadline, delivery status and retry/dead-letter visibility.
2. Keep dispatch readiness distinct from dispatch authorization and actual physical departure.
3. Keep rerouting as a proposal until a verified route, approved corridor, compliance/customs controls, partner capability, capacity, customer approval and cost terms are confirmed.
4. Keep ETA predictions disabled until provider provenance, model version, confidence, freshness and route coverage are observable.
5. Add staging tests for permission-denied users, cross-organization access, stale snapshots, duplicate alerts, escalation retries, missing policies, failed notification providers and exception resolution audit integrity.

## Current operating evidence
No live partner assignments, driver assignments, PODs, exceptions, exception escalations, warehouse transfers or returns were found in the current counts. The platform has 18 shipments and 18 stored snapshots, but the snapshot freshness above prevents treating those snapshots as current operational state. One tracking event and one open delay alert exist; neither proves a working real-world shipment monitoring service.

## Release safety
The production migration history and repository migration crosswalk remain unreconciled. No production schema, RPC, trigger, grants, policies or business data were modified. Any P0 database corrections must wait until the migration manifest is reconciled, then be implemented and verified in staging before production.

## Changes in this audit
- `public/operations/operations-runtime.js`: removed fake AIS stream and fictional reroute metrics; replaced with explicit unavailable/provider-not-connected results.
- Commit: `b59cd00e1e9d7a6cc579a86f3cd2bc72aea0cc63`.

## Next priority
Audit notification delivery and alert routing end-to-end: outbox creation, Telegram/email providers, retry/dead-letter behavior, user preferences, privacy consent, duplicate suppression and proof of human delivery.