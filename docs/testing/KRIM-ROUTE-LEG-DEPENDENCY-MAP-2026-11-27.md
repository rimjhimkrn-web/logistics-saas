# KRIM Route-Leg Dependency Map — 2026-11-27

## Staging inspection
Project: qrpcivhdxobiaofppbkl (Staging only).

The route-generation design was checked against live catalog metadata. The following are direct foreign-key dependents of `public.krim_shipment_legs` (the same composite constraints may appear as multiple rows in the catalog output):

| Dependent table | Leg reference | Delete behavior | Risk |
|---|---|---|---|
| krim_capacity_leg_bindings | shipment_leg_id | NO ACTION and CASCADE constraints present | Capacity binding history and reservation identity |
| krim_capacity_reservations | shipment_leg_id | NO ACTION | Reservation ledger |
| krim_driver_assignments | shipment_leg_id | NO ACTION | Driver assignment and execution |
| krim_eta_sla_evaluation_runs | shipment_leg_id | SET NULL | ETA/SLA history |
| krim_exception_signal_bridges | shipment_leg_id | SET NULL | Exception lineage |
| krim_execution_prerequisite_gates | shipment_leg_id | CASCADE | Execution gates |
| krim_operational_execution_events | shipment_leg_id | SET NULL | Operational event history |
| krim_operational_execution_state | shipment_leg_id | CASCADE | Current execution state |
| krim_operational_notification_runs | shipment_leg_id | SET NULL | Notification history |
| krim_partner_assignment_activations | shipment_leg_id | NO ACTION and CASCADE constraints present | Partner activation history |
| krim_partner_opportunities | shipment_leg_id | RESTRICT | Commercial sourcing history |
| krim_partner_quotes | shipment_leg_id | RESTRICT | Commercial quote history |
| krim_shipment_leg_custody_transfers | from_leg_id / to_leg_id | RESTRICT | Chain-of-custody history |
| krim_shipment_leg_dispatch_authorizations | shipment_leg_id | RESTRICT | Dispatch authorization |
| krim_shipment_partner_assignments | shipment_leg_id | NO ACTION | Partner assignment history |
| krim_shipment_returns | shipment_leg_id | RESTRICT | Returns lineage |
| krim_tracking_events | shipment_leg_id | SET NULL | Tracking history |
| krim_tracking_synchronization_runs | shipment_leg_id | SET NULL | Tracking integration history |
| krim_warehouse_receipts | shipment_leg_id | RESTRICT | Warehouse receipt history |
| krim_warehouse_shipment_allocations | shipment_leg_id | RESTRICT | Warehouse allocation |
| krim_warehouse_tasks | shipment_leg_id | RESTRICT | Warehouse execution |
| shipment_dispatches | krim_shipment_leg_id | SET NULL | Dispatch history |

## Structural constraints
- `krim_shipment_legs` has a unique `(shipment_id, leg_sequence)` index.
- It has a unique `(id, shipment_id)` index used by composite foreign keys.
- It has a nullable `leg_plan_item_id` reference.
- Plan versions are unique per shipment.
- Only one plan per shipment can have status `active`.
- Existing route-plan activation/evaluation logic compares operational legs against plan-item sequence and route details.

## Consequence
A plan version cannot safely be treated as an independent new operational leg list while `leg_sequence` remains shipment-global. Deleting or repurposing old rows is not an acceptable migration strategy: RESTRICT/NO ACTION references block it, while CASCADE references could erase execution state.

## Required migration order
1. Introduce route-generation identity in a new additive schema, without altering current leg identities or uniqueness.
2. Backfill legacy generation association deterministically from each leg's `leg_plan_item_id` and the owning plan; separately mark unlinked legacy legs as legacy generation. Validate no ambiguous mapping.
3. Update all leg readers/writers and all FK-dependent workflows to carry generation identity and use generation-local sequence. Keep legacy columns during compatibility period.
4. Add database invariants for exactly one active generation per shipment and no active generation replacement after execution evidence.
5. Implement atomic replacement and cancellation workflows only after dependency consumers are migrated.
6. Run isolated two-customer/two-partner E2E, concurrency, rollback, capacity reconciliation, POD/custody, tracking, warehouse and notifications tests.
7. Only then consider retiring the old shipment-global sequence semantics; never remove historical leg IDs.

## Current data and gate
- Route plans: 0.
- Shipment legs: 0.
- No operational data was changed during this audit.
- No schema migration was applied during this audit.
- Route-plan RPC and scoped SELECT permission fixes remain applied from prior checkpoint.
- Replacement implementation remains OPEN pending dependency-aware design and integration.
- Phase 00 remains OPEN / NOT APPROVED. Production untouched.
