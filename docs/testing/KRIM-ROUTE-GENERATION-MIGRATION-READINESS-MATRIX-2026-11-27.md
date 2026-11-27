# KRIM Route-Generation Migration Readiness Matrix — 2026-11-27

## Decision
**NO-GO for route-generation schema migration or operational activation.** The consumer inventory is broad enough to define the migration workstreams, but not complete enough to safely alter the schema. The Staging database currently has no shipment/route/leg operational records, so a meaningful legacy backfill rehearsal and runtime compatibility test cannot yet be performed.

This is a design/readiness gate only. No schema, code, or production changes were made.

## Staging data snapshot
Project: `qrpcivhdxobiaofppbkl` (Staging only).

| Dataset | Current rows |
|---|---:|
| Shipments | 0 |
| Operational shipment legs | 0 |
| Route plans | 0 |
| Route-plan items | 0 |
| Legacy shipment routes | 0 |
| Legacy route segments | 0 |
| Tracking events | 0 |
| Driver tracking sessions | 0 |
| Warehouse tasks | 0 |
| In-app notifications | 0 |
| Active route plans | 0 |
| Superseded route plans | 0 |
| Plan-linked legs | 0 |
| Unlinked legs | 0 |

Integrity spot-checks: orphaned legacy routes 0; orphaned legacy segments 0; plan-linked legs with missing plan item 0; orphaned operational legs 0. These zero counts are not proof of a correct backfill; they reflect an empty operational dataset.

## Migration readiness matrix

| Workstream | Existing dependency / evidence | Required migration or compatibility work | Gate |
|---|---|---|---|
| Canonical route model | Versioned route plans/items coexist with durable operational legs; shipment-wide `leg_sequence` is unique | Add immutable route-generation identity distinct from plan-local sequence and operational leg ID; preserve all existing leg IDs | OPEN |
| Legacy route model | `krim_shipment_routes` / `krim_route_segments` and validation/audit triggers remain active; driver route-stop UI reads this model | Inventory every legacy writer/reader; define deterministic route/segment-to-plan mapping; quarantine ambiguous rows | OPEN |
| Activation / replacement | Plan creation/evaluation/activation RPCs exist; activation currently has no safe supersession/cancellation workflow | Implement locked, atomic generation replacement only before irreversible execution evidence; idempotency, audit and concurrency controls | OPEN |
| Sourcing / quotes | Opportunities, quotes and partner assignments bind exact operational leg and active plan item | Revalidate active generation at create/submit/award; reject stale-generation opportunities and quotes | OPEN |
| Dispatch / capacity | Dispatch authorization and capacity binding use exact leg and plan item; guard currently uses shipment-wide counts in multi-leg logic | Scope eligibility, active-leg counts, reservations and capacity release to generation; stale authorization must fail | OPEN |
| Driver assignment / tracking | Driver assignment uses exact leg; tracking sessions/events are shipment/assignment-oriented in some routines | Persist exact leg and generation in tracking sessions/events; expire and query by exact session + leg + generation | OPEN |
| Custody / transit | Custody predecessor uses shipment-wide sequence minus one; legacy transit/arrival routines select first shipment leg | Use generation-local predecessor ordering; retire or rewrite legacy transit/arrival routines before any multi-leg execution | BLOCKER |
| POD / delivery finalization | POD is exact assignment/shipment/leg; final completion checks shipment-wide legs | Scope delivery completion and plan-item counts to current generation; retain superseded-generation POD as immutable history | OPEN |
| Warehouse | Handover/task data stores shipment and exact leg, but list RPCs expose shipment-wide leg sequence without generation | Include generation in task and work-queue identity; active work queue excludes stale generations; historical view preserves prior work | OPEN |
| Customer / partner UI | Customer details and tracking are shipment-level; partner dispatch page carries exact leg but not generation; ePOD has exact leg linkage | Add generation-aware current timeline and explicit historical route views; never infer leg from shipment ID | OPEN |
| Operations / reporting | Tracking and operations workspace are shipment-level; reporting surface is preparation-only | Split aggregate shipment reporting from per-generation/per-leg operations; keep write surfaces gated | OPEN |
| Notifications | In-app history immutability exists; shipment status notifications deduplicate at shipment/title level | Add source-event idempotency and generation-aware leg events; keep a single aggregate shipment notification policy | OPEN |
| Security / tenant isolation | Existing organization/facility checks and scoped RPCs; runtime JWT tests incomplete | Test customer, partner, driver, warehouse and admin boundaries with separate authenticated sessions; deny anon/direct writes | BLOCKER |
| Legacy data backfill | Staging has zero route/leg records | Build dry-run reconciliation report on representative fixture data; require zero unexplained mappings before applying | BLOCKER |
| Rollback / operations | No generation migration implemented | Define additive rollout, dual-read/dual-write transition only if necessary, rollback boundary, observability and recovery runbook | OPEN |

## Required migration sequence
1. **Freeze the contract:** finalize shipment → immutable route generation → route plan → plan items → durable operational legs → exact-leg assignment/driver/capacity/tracking/custody/POD.
2. **Complete callsite inventory:** inspect all remaining frontend pages, edge functions, scheduled jobs, triggers, dynamic SQL and external RPC call paths. Current reviews are bounded, not exhaustive.
3. **Build fixtures through supported workflows:** use owner-controlled staging test identities and legitimate application APIs; no direct writes to auth internals or fabricated operational history.
4. **Legacy reconciliation dry run:** classify every legacy route, segment and operational leg as deterministic mapping, already linked, or quarantine/manual review.
5. **Implement additive schema only after gates 1–4:** generation identity, constraints/indexes, backfill function with preview mode, audit trail, and controlled replacement/cancellation.
6. **Update backend consumers atomically:** sourcing, assignment, dispatch, capacity, driver, custody, POD/finalization, warehouse and notifications.
7. **Update frontend and edge consumers:** generation-aware display, current vs historical labels, event filters and stale action handling.
8. **Run negative and positive E2E tests:** concurrency, retries, stale generations, cross-tenant access, historical preservation, route replacement before/after execution evidence, single- and multi-leg workflows.
9. **Approve release separately:** staging acceptance, rollback rehearsal, explicit production authorization, then production verification.

## Non-negotiable acceptance tests
- Existing operational leg IDs and all foreign-key history remain unchanged.
- A new route generation never reuses prior generation's plan sequence or operational leg IDs.
- Replacement is rejected after pickup, dispatch, transit, custody, warehouse handover or other irreversible execution evidence.
- Stale quote, assignment, driver assignment, capacity binding, tracking session and warehouse task cannot mutate current-generation execution.
- Custody predecessor is the immediately preceding leg in the same generation, not merely sequence minus one across the shipment.
- Delivery finalization evaluates only the intended generation and its exact plan items/legs.
- Superseded-generation tracking and POD remain auditable but cannot enter current work queues.
- Customer/partner/warehouse data remains organization/facility scoped; anon and direct table writes remain denied.
- All write operations are idempotent and concurrency-safe.

## Evidence and limitations
This matrix consolidates the Staging reviews documented in:
- `KRIM-ROUTE-GENERATION-SCHEMA-DECISION-RECORD-2026-11-27.md`
- `KRIM-ROUTE-GENERATION-CONSUMER-INVENTORY-2026-11-27.md`
- `KRIM-ROUTE-GENERATION-READ-WRITE-INVENTORY-2026-11-27.md`
- `KRIM-ROUTE-GENERATION-WRITER-TRIGGER-REVIEW-2026-11-27.md`
- `KRIM-ROUTE-GENERATION-EXECUTION-WORKFLOW-REVIEW-2026-11-27.md`
- `KRIM-ROUTE-GENERATION-DISPATCH-CUSTODY-GUARD-REVIEW-2026-11-27.md`
- `KRIM-SHIPMENT-AGGREGATE-STATUS-DELIVERY-FINALIZATION-REVIEW-2026-11-27.md`
- `KRIM-ROUTE-GENERATION-FRONTEND-CONSUMER-REVIEW-2026-11-27.md`
- `KRIM-ROUTE-GENERATION-CUSTOMER-PARTNER-WAREHOUSE-REPORTING-REVIEW-2026-11-27.md`
- `KRIM-ROUTE-GENERATION-LEGACY-TRACKING-WAREHOUSE-NOTIFICATION-REVIEW-2026-11-27.md`

The file-level and SQL scans are bounded. They do not prove absence of indirect calls, dynamic SQL, external clients or uninspected UI paths.

## Current status
- Migration readiness: **NO-GO**
- Route-generation schema implemented: **No**
- Backfill run: **No**
- Runtime E2E: **Blocked — no operational fixtures**
- Production touched: **No**
- Phase 00: **OPEN — NOT APPROVED**
