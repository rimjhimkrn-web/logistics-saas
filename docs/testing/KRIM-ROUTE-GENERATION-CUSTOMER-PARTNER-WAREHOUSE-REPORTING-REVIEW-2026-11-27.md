# KRIM Route-Generation Customer, Partner, Warehouse and Reporting Consumer Review — 2026-11-27

## Scope
Read-only inspection of selected high-risk files fetched from `staging/phase00-env-isolation`. Reviewed customer shipment detail/ePOD, partner dispatch/driver assignment, warehouse dispatch handover, operations tracking and reporting. This is a focused consumer review, not a complete repository-wide inventory.

## Confirmed findings

### Customer shipment detail
`public/shipper/shipment-details.html` loads a customer-authorized row from `krim_shipments` by shipment ID and customer organization. The inspected query is shipment-level and does not retrieve active route generation, route plan, operational legs or per-leg history.
Required: add an organization-scoped active-generation summary and leg timeline. Keep shipment aggregate status separate from exact-leg states.

### Customer ePOD vault
`public/shipper/epod-vault.html` loads shipment-scoped POD rows, but its selected POD fields include `shipment_leg_id` and `assignment_id`. It renders the leg reference and only exposes private evidence links for verified records.
Required: preserve this exact-leg linkage and display route generation / plan-item context; ensure shipment-wide filtering does not merge current and superseded generation evidence in the current execution summary. Historical POD evidence must remain visible as historical evidence.

### Partner dispatch assignment
`public/partner/dispatch-assignment.html` loads accepted partner assignments with `shipment_leg_id`, then calls:
- `krim_list_dispatchable_drivers(p_partner_assignment_id)`
- `krim_assign_driver_to_partner_shipment(p_partner_assignment_id,p_driver_user_id)`

This is better scoped than a shipment-only driver picker because the assignment record carries the exact leg. The generation identity is not selected or shown in the inspected page. Backend RPCs must pin the assignment's leg to the active generation and return/display generation context.

### Warehouse dispatch handover
`public/warehouse/dispatch-handover.html` calls `krim_warehouse_list_assigned_shipment_legs(p_organization_id,p_facility_id)`, selects a specific `shipment_leg_id`, checks allocations by both `shipment_id` and `shipment_leg_id`, and creates the handover task with both IDs. The UI explicitly says task completion records a warehouse custody checkpoint only; it does not dispatch or assign a driver.
This is an exact-leg foundation. The RPC/task schema and all warehouse inbound/outbound/returns workflows still need generation identity, and the backend must validate the selected leg belongs to the active generation where required.

### Operations tracking
`app/operations/tracking-activity.html` queries `krim_tracking_events` by timestamp and selects `shipment_id,event_type,event_time,source_type,source_reference,location_id`. The inspected query has no leg or generation filter and the table renders shipment ID.
Required: show exact leg/generation when event metadata contains it; provide a separate shipment aggregate timeline. Do not infer leg ownership from shipment ID.

### Operations reporting
`app/operations/operations-reports.html` is a review/preparation surface; its form validates browser fields only and does not persist a report. No operational route-generation dataset was observed in the inspected source. It should remain clearly non-operational until generation-aware reports are implemented.

## Cross-surface compatibility matrix
| Surface | Current linkage | Generation gap |
|---|---|---|
| Customer shipment detail | Shipment ID + customer organization | No active generation / leg history |
| Customer ePOD vault | Shipment + exact leg + assignment | No generation context in view |
| Partner driver assignment | Partner assignment + exact leg | No generation display / explicit generation recheck in page |
| Warehouse handover | Shipment + exact leg + facility + allocation | No generation identity in task context |
| Operations tracking | Shipment ID only | No exact leg/generation timeline |
| Operations reports | Preparation-only | No generation-aware reporting |

## Safe implementation requirements
1. Add immutable generation identity to the canonical route-plan / operational-leg model, preserving old leg and POD IDs.
2. Keep exact `shipment_leg_id` links in partner, warehouse, POD and driver flows; do not downgrade to shipment-only joins.
3. Revalidate active-generation membership in backend RPCs, not just frontend filters.
4. Split shipment aggregate timeline from exact-leg/generation event timelines.
5. Preserve historical and superseded generation POD/tracking records with explicit historical labels.
6. Keep reporting and operations pages read-only until their generation-aware queries and permission tests are complete.
7. Test customer and partner organization isolation, warehouse facility scope, stale assignment rejection, duplicate retries and superseded-generation visibility.

## Status
Confirmed findings documented. No frontend code or database schema changed. No migration applied. No runtime tests possible without operational fixtures. Phase 00 remains OPEN — NOT APPROVED. Production untouched.
