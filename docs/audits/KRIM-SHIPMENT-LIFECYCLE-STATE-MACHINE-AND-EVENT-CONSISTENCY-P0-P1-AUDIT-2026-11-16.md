# KRIM Shipment Lifecycle State Machine and Event Consistency Audit
Date: 2026-11-16

## Executive result

**NO-GO for end-to-end shipment execution.** The canonical `krim_shipments` lifecycle has multiple layers of protection—transition registry, readiness trigger, market/corridor gates, leg validation, capacity and custody guards, status history and event emission. The database state and live execution evidence still show that this is not an operationally proven journey. One key architectural inconsistency is that a legacy status-transition trigger remains attached to the legacy `shipment_requests` table, while the current canonical shipment table uses a different status model and a different set of controls.

This audit complements (does not replace) the earlier focused booking, dispatch, driver/POD, warehouse and custody audits.

## Live snapshot

- Canonical shipments: 18 — 8 draft, 3 quoted, 6 confirmed, 1 closed.
- Shipment legs: 1, currently `assigned`.
- Shipment status-history rows: 41.
- Driver assignments: 0.
- Driver trip events: 0.
- Custody transfers: 0.
- POD records: 0.
- The shipment transition RPC is executable only by `service_role` (plus postgres), not anon/authenticated.
- Authenticated users have SELECT but no direct INSERT/UPDATE/DELETE grants on `krim_shipments`; service_role has full table privileges.

## Positive controls confirmed

1. **Canonical transition registry:** `krim_transition_shipment` locks the shipment, checks an explicitly allowed from/to transition, enforces the configured permission and required reason, and writes status history.
2. **Readiness trigger:** changes into `confirmed`, `assigned` or `dispatched` invoke a server-side shipment-readiness evaluator and reject non-ready transitions.
3. **Market/corridor enforcement:** before-write triggers enforce the active market and corridor compliance gates. These currently block booking/execution because no market/corridor is approved.
4. **Leg integrity:** leg triggers validate shipment, locations, transport mode and route-segment consistency.
5. **Multi-leg custody:** later legs cannot enter transit until the immediately preceding leg's custody transfer is accepted by the receiving partner.
6. **Audit/event trail:** canonical shipment status changes append history and emit a `shipment.status_changed` event to the event table.
7. **Direct client writes:** ordinary authenticated users cannot directly mutate canonical shipment rows through table grants.

## Findings

### P0 — Legacy and canonical shipment status models coexist

The live `validate_shipment_status_transition()` trigger is still attached to legacy `shipment_requests`, not `krim_shipments`. Its transition vocabulary includes legacy states such as `new`, `quote_accepted`, `partner_accepted`, `picked_up`, `pod_submitted` and `completed`. The canonical transition registry uses a different vocabulary, including `draft`, `quoted`, `confirmed`, `assigned`, `dispatched`, `in_transit`, `delivered`, `exception`, `closed` and `cancelled`.

This leaves two shipment lifecycle models and a live legacy trigger in production. The audit did not prove every legacy caller is retired. This increases the risk of pages, reports, notifications or integrations updating/reading the wrong lifecycle. Treat `krim_shipments` as the only canonical model for new work; identify and retire or isolate every legacy `shipment_requests` caller after compatibility analysis.

### P1 — Transition registry deliberately blocks generic transit/delivery transitions

The canonical registry marks `dispatched -> in_transit` and `in_transit -> delivered` as `allowed=false`. This is consistent with specialized driver/leg operations being the only valid route to those milestones, but it means generic shipment transition code must not be used for those events. Ensure every UI, integration and privileged worker uses the specialized leg-aware driver/dispatch/POD workflow, not a direct generic status update.

### P1 — Readiness and corridor gates are stronger than current operating evidence

The readiness trigger blocks confirmed/assigned/dispatched when its evaluator is not ready. The global market/corridor audit found all 6 market activation controls blocked, 249 country packs in research_pending, 7 corridors draft and zero approved corridor dossiers/controls. Therefore the safeguards currently prevent a real shipment from moving into execution; this is a correct fail-closed result, not a reason to bypass the trigger.

### P1 — Event history exists, but operational event delivery is not demonstrated

There are 41 status-history records, but zero driver assignments, trip events, custody transfers and POD records. The status trigger creates pending domain events; notification delivery is a separate subsystem and the notification audit found zero outbox/delivery rows and no proof of provider delivery. Status history, event creation, workflow dispatch and external customer notification must be verified separately. An event row or API acceptance is not proof that a user received an update.

### P1 — End-to-end lifecycle remains unproven

No live evidence demonstrates the complete chain:
customer request -> approved route -> verified partner/capability/service area -> partner commercial quote -> customer acceptance -> accepted assignment -> confirmed physical capacity -> exact-leg dispatch authorization -> driver pickup/transit -> required inter-partner custody acceptance -> warehouse/customs release where applicable -> driver delivery evidence -> independent POD review -> delivery authorization -> shipment closure -> correctly bound finance event.

Prior audits have separately confirmed blockers at booking creation, partner matching, pricing, assignment/capacity, dispatch, warehouse, customs, POD and finance. The present production records do not constitute a successful shipment pilot.

## Required remediation — not applied

1. Declare `krim_shipments` and shipment legs as the sole canonical model; inventory all remaining legacy `shipment_requests` UI, RPC, trigger, webhook, reporting and notification callers.
2. Add a compatibility/retirement plan for the legacy table and status trigger; do not drop it until references and data migration are reconciled.
3. Publish one canonical lifecycle/state-transition contract for customer, partner, driver, warehouse, customs, operations and finance clients, with leg-level vs shipment-level statuses clearly distinguished.
4. Require all pickup/transit/delivery transitions to pass through exact-leg, authorized specialized RPCs; prohibit direct status writes from UI and generic admin shortcuts.
5. Reconcile dispatch, physical capacity reservation, driver assignment, custody acceptance, warehouse/customs release and POD verification as required per route/mode.
6. Add staging-only end-to-end tests for every supported single-leg and multi-leg journey, with injected failures, retries, duplicate events, revoked membership, stale evidence, expired capacity, wrong-leg IDs, partial deliveries and exception recovery.
7. Prove event outbox delivery, retry/reclaim, provider webhook confirmation and customer/partner notification preferences independently from status-history writes.
8. Resolve the production/repository migration-history mismatch before any DDL, trigger changes, RPC replacements or legacy retirement.

## Release decision

**NO-GO for live shipment execution and unrestricted global operations.** The state machine has useful safeguards, but the route activation and real-world execution evidence needed to release shipments are absent. Keep the product in controlled application/preparation mode; do not promise dispatch, tracking, custody, customs clearance or delivery until each required gate is operationally verified.

## Evidence boundaries

Read-only inspection of live function definitions, transition rows, trigger attachments, table grants and aggregate counts. No shipment, status, assignment, driver event, custody transfer, POD, dispatch authorization, notification or finance record was created or changed. No lifecycle RPC was executed. No production schema or settings were modified.
