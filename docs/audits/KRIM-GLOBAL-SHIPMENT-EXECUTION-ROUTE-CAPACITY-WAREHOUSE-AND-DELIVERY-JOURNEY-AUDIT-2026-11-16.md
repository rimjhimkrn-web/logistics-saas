# KRIM Global Shipment Execution, Route Planning, Capacity, Warehouse and Delivery Journey Audit — 2026-11-16

## Scope and method
Read-only production inspection of transport modes, routes, route segments, shipment leg plans/legs, capacity, dispatch, tracking and warehouse data. Inspected selected route-plan creation/evaluation/activation function definitions, authenticated table grants and live record counts. No production RPCs, bookings, assignments, dispatches, inventory movements or writes were executed.

## CI for previous compliance audit
All three workflows passed for commit `64be3a59539039cffba4f033f209bcf6baef3f63`:
- Production smoke: `43801033453` success
- Static link audit: `43801033427` success
- Pages deployment: `43801033062` success

These CI checks do not prove live carrier, capacity, warehouse or shipment execution.

## 1. Transport mode catalogue
Six active mode records exist:
- ROAD
- RAIL
- OCEAN
- AIR
- WAREHOUSE
- MULTIMODAL

These are catalogue entries only. Active mode flags do not prove a service provider, legal operating authority, capacity, route, rate or booking is available.

## 2. Live execution data snapshot
| Component | Records |
|---|---:|
| Route options | 0 |
| Route segments | 1 |
| Shipment routes | 1 |
| Shipment legs | 1 |
| Leg plans | 0 |
| Leg plan items | 0 |
| Capacity resources | 0 |
| Capacity reservations | 0 |
| Capacity leg bindings | 0 |
| Dispatches | 0 |
| Tracking events | 1 |
| Warehouse facilities | 0 |
| Warehouse inventory | 0 |
| Warehouse shipment allocations | 0 |
| Warehouse tasks | 0 |
| Warehouse transfers | 0 |

The single route/segment/leg is an old core test route record with no distance, no planned schedule and no plan-item binding; the leg's assignment status is `unassigned`. It is not evidence of an executable commercial route.

## 3. Route planning logic — positive controls
The customer-facing route-plan creation function:
- requires authenticated user and `shipment.update` permission in the owning customer organisation;
- locks the shipment;
- only permits pre-execution shipment states;
- requires 1–20 legs;
- validates active locations and active transport modes;
- validates connected sequential legs, shipment origin/destination, timestamps and positive finite capacity requirements;
- uses an idempotency key and request fingerprint;
- records plan snapshots and audit events.

Plan evaluation checks contiguous sequence, route connectivity, active locations/modes, schedule order, capacity field consistency, existing active plans, commercial quote conflicts for multi-leg plans, and conflicts with an existing initial leg.

Plan activation calls the evaluator, creates shipment-leg records transactionally, records a mapping/event snapshot and is idempotent.

Authenticated users have SELECT-only table grants on inspected route/plan/leg/activation tables; direct table writes are not granted. These are positive controls.

## 4. Critical route-plan activation compliance gap — needs correction
The inspected route-plan evaluation and activation functions do not themselves re-check:
- origin and destination operational market activation;
- exact corridor dossier approval and mandatory corridor controls;
- transit-jurisdiction country operating pack approval/currentness;
- shipment compliance-gate status and freshness.

The shipment-write triggers enforce market activation and exact corridor/country-pack requirements when the shipment row is written. However, route-plan activation creates or updates rows in `krim_shipment_legs` and plan tables, not the shipment row. The existing route-plan evaluation/activation function definitions do not show an equivalent re-evaluation of those compliance predicates.

This creates a control-boundary gap for pre-existing/legacy shipments: an existing shipment may reach plan evaluation/activation without the route-plan workflow itself proving current market/corridor/compliance clearance. It is not evidence that a dispatch can complete; dispatch has separate assignment, driver, capacity and authorisation controls. But every route-plan activation and every dispatch authorisation should bind to fresh compliance evidence, not rely solely on an earlier shipment-write trigger.

### Required correction design (not applied)
- Add a canonical internal route-and-shipment execution eligibility evaluator used by both plan activation and dispatch authorisation.
- Re-check current origin/destination market activation, exact corridor dossier and mandatory controls, transit country packs, current source validity, cargo restrictions and shipment compliance result.
- Store a deterministic compliance snapshot/fingerprint on plan activation and dispatch authorisation.
- Invalidate/re-evaluate when shipment endpoints, cargo, mode, plan, country pack, corridor source, compliance evidence or market activation changes.
- Make stale/blocked status fail closed.
- Test legacy shipments, changed route after plan, expired source after plan, market suspension after plan, cargo change, and activation/dispatch race conditions in staging.

## 5. Multi-leg commercial workflow limitation
The evaluator explicitly blocks activation of multi-leg plans while shipment-wide partner opportunities or customer quotes remain active, with a message that leg-specific sourcing is not yet enabled. This is a safe stop, but means multi-leg shipment commercial sourcing is not yet a complete customer journey. A future design needs per-leg provider discovery, quotes, independent award/assignment, capacity reservation and commercial aggregation without treating a shipment-wide quote as a valid substitute.

## 6. Capacity and dispatch
Live capacity resources, reservations and leg bindings are all zero. There are no dispatch records. Earlier detailed reviews identified the necessary controls: accepted exact-leg partner assignment, partner capability/compliance, confirmed capacity binding and reservation, driver/vehicle eligibility for road, current authorisation, and accepted custody from the immediately previous leg for later legs.

A separate edge case remains for dispatch authorisation currentness: the currentness helper was found to require an active plan with `total_legs > 1`. Single-leg shipments may therefore fail a later currentness/replay check even when their one-leg assignment and capacity are valid. This requires a staging test and a canonical predicate that explicitly supports single-leg routes without a multi-leg plan.

## 7. Warehouse and inventory
No live warehouse facilities, stock, allocations, tasks or transfers exist. Warehouse workflow functions and controls exist, but none of these real-world workflows has live data to validate.

A previously identified inventory invariant remains unresolved: warehouse dispatch transfer can decrease source stock without accounting for outstanding reserved shipment allocations. The shared inventory-row lock serialises operations but does not by itself protect stock already reserved for a shipment. All stock-decreasing paths must calculate available-to-promise as on-hand less active reserved allocations, and picking must consume its own allocation atomically. This must be tested under concurrent reservations, picks, transfers and releases in staging.

## 8. Tracking and delivery
One tracking event exists; no dispatches or tracking sessions exist in the current snapshot. Earlier POD/custody review established controlled driver-owned evidence submission, independent review, verified-POD requirement for delivery authorisation and adjacent-leg custody controls. Those protections are useful architecture, but no end-to-end delivery was present to prove them operationally.

Manual or carrier-reported coordinates must not be described as independently verified GPS/telematics. Verified POD should mean the evidence passed the configured review workflow, not that authenticity is guaranteed solely by file ownership.

## 9. Production readiness conclusion
The platform has substantial route planning, leg activation, capacity, dispatch, warehouse, tracking and POD code. Yet the live data snapshot contains no capacity resources, reservations, dispatches, warehouse facilities, inventory or tasks, and no leg plans. There is no demonstrated complete carrier-backed journey.

Do not advertise live carrier coverage, capacity, real-time dispatch, warehouse availability, customs clearance or guaranteed delivery from catalogue records or code presence.

## 10. Priority actions
1. Close the route-plan activation compliance revalidation gap.
2. Fix/validate single-leg dispatch-authorisation currentness.
3. Complete leg-specific sourcing and quote/award for multi-leg shipments.
4. Enforce reservation-aware warehouse stock decrease across transfer, pick, release and adjustment paths.
5. Run a full staging pilot with a verified partner, a real capacity resource, one leg, one multi-leg route, road driver/vehicle, warehouse receipt/pick if needed, dispatch, custody, tracking and independently reviewed POD.
6. Keep production dispatch and customer booking disabled for corridors without independently approved operating evidence.

No production changes or operational transactions were performed. Migration-history reconciliation remains a prerequisite for production schema changes.
