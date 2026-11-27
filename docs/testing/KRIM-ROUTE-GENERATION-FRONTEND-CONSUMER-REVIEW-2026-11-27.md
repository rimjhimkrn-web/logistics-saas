# KRIM Route-Generation Frontend Consumer Review — 2026-11-27

## Scope and evidence
Read-only source review on `staging/phase00-env-isolation` in `rimjhimkrn-web/logistics-saas`. Files fetched directly from the exact Staging branch:
- `app/driver/module-07-route-stop-management.html`
- `app/driver/module-08-live-tracking.html`
- `app/driver/module-10-proof-of-delivery.html`
- `app/operations/route-planning.html`
- `app/operations/dispatch-control.html`
- `app/operations/shipment-control.html`
- `app/operations/warehouse-coordination.html`
- `workspaces/operations-workspace.html`
- `workspaces/partner-workspace.html`

This is a focused high-risk workflow review, not a complete recursive repository inventory.

## Confirmed findings

### 1. Route planner is already connected to the versioned plan RPCs
`app/operations/route-planning.html`:
- Reads `krim_shipment_leg_plans` and `krim_shipment_leg_plan_items`.
- Creates drafts through `krim_create_shipment_leg_plan`.
- Evaluates through `krim_evaluate_shipment_leg_plan`.
- Activation is deliberately disabled in the UI pending market/corridor/customs/compliance controls.
- Plan item sequence is displayed as plan-local `leg_sequence`.

This page is a key migration consumer: its list/history display must show route-generation identity and active/superseded state when the generation schema is introduced. Do not enable activation merely by removing the UI block; backend gates and E2E evidence are still required.

### 2. Driver route-stop page still uses legacy route records
`app/driver/module-07-route-stop-management.html`:
- Authenticates driver session and active driver organization membership.
- Reads `krim_driver_assignments`, then reads `krim_shipment_routes` by shipment ID and `krim_route_segments` by route ID.
- Displays route segments by legacy `sequence_number`.
- Does not read `krim_shipment_leg_plans`, plan items, operational `krim_shipment_legs`, or route-generation identity.

This is a confirmed frontend model split: operations planning uses versioned leg plans, while the driver route-stop page uses legacy shipment routes/segments. Before enabling generation-based execution, either migrate this page to the exact assignment leg and active generation mapping, or explicitly document and enforce a separate legacy route source. Do not merge route records by shipment ID alone.

### 3. Driver live tracking is shipment-scoped, not exact-leg scoped
`app/driver/module-08-live-tracking.html`:
- Loads the driver's assignments.
- Loads `krim_tracking_events` by `shipment_id` only.
- Renders the same shipment event set alongside each assignment for that shipment.
- Does not select or display `shipment_leg_id` or route generation.
- GPS collection remains disabled, as the page states.

For multi-leg and replacement support, tracking events must be filtered and presented by exact assigned leg and generation, while shipment-level aggregate tracking remains a separate projection. Keep GPS disabled until consent/legal and security gates are cleared.

### 4. Driver POD page is currently read-only and paused
`app/driver/module-10-proof-of-delivery.html`:
- Loads driver assignments and counts assignment statuses reported as delivered.
- Explicitly states POD submission is paused pending backend integrity remediation.
- Does not currently submit or verify POD from this page.

Keep this pause. Reconnect only to the exact-leg POD workflow after generation-scoped backend finalization and evidence tests pass. Assignment status alone must not be treated as verified POD evidence.

### 5. Operations dispatch and shipment pages are preparation/read-only surfaces
- `app/operations/dispatch-control.html` shows read-only shipment/dispatch readiness and states it does not execute dispatch.
- `app/operations/shipment-control.html` reads shipment-level `krim_shipments` fields; no route-generation display observed in the inspected query.
- `workspaces/operations-workspace.html` loads shipment-level `krim_shipments`, `krim_exceptions`, and `krim_quotes`; the inspected shipment query has no leg or generation fields.
- `app/operations/warehouse-coordination.html` reads authorized warehouse facilities. Its preparation form explicitly does not save or change operational records.

These pages need a generation-aware operational detail panel and clear active-generation context; they must not imply leg-level dispatch or handover execution while they remain read-only.

### 6. Partner workspace remains evidence-oriented in inspected code
`workspaces/partner-workspace.html` calls `krim_get_partner_response_evidence`; no direct operational leg or route-generation table read was found in the inspected file. This is bounded to that file and does not establish the entire partner frontend is generation-ready.

## Frontend change matrix
| Surface | Current source of truth | Required generation work |
|---|---|---|
| Operations route planner | Versioned plans and plan items | Show generation ID, plan lineage, active/superseded state |
| Driver route stops | Legacy shipment routes/segments | Bind exact driver assignment → operational leg → plan item → generation |
| Driver tracking | Shipment-wide tracking events | Exact-leg/generation timeline; separate shipment aggregate |
| Driver POD | Read-only assignment status | Keep paused; exact-leg evidence and generation-aware verified POD |
| Dispatch control | Shipment-level register/readiness | Exact assignment/leg/generation readiness and audit references |
| Shipment control/workspace | Shipment aggregate | Active-generation summary plus preserved history |
| Warehouse coordination | Facility directory/preparation form | Exact-leg inbound/outbound handover references and generation scope |
| Partner workspace | Quote response evidence | Ensure later assignment/leg views pin exact generation |

## Implementation order
1. Close remaining frontend call-site inventory, including customer shipment details, partner assignment/dispatch, warehouse execution, public tracking, reporting, notifications, and legacy links.
2. Decide the canonical mapping between legacy `krim_shipment_routes/krim_route_segments` and the new versioned plan/operational leg model. No dual-write without explicit ownership and reconciliation.
3. Implement additive generation identity and safe backfill.
4. Update backend guards, then frontend pages, then public/customer/partner/driver/warehouse/ops reporting.
5. Keep route activation, GPS collection, dispatch writes and POD submission gated until tests pass.

## Status
Confirmed frontend compatibility gaps documented. No frontend code or database schema changed. No migration applied. Phase 00 remains OPEN — NOT APPROVED. Production untouched.
