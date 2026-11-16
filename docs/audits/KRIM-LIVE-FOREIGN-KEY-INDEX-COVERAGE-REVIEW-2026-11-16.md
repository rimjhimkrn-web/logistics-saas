# KRIM Live Foreign-Key Index Coverage Review
**Date:** 16 November 2026  
**Method:** Read-only PostgreSQL catalog inspection. No DDL, data changes, or migration-history edits.

## Summary
Across the `public` and `private` schemas:
- Foreign-key constraints inspected: **559**
- Constraints with a valid, ready, non-partial B-tree index whose leading key columns match the FK columns in order: **510**
- Constraints without such a leading index: **49**

This is a structural coverage screen, not a proof that all 49 need a new index. Workload frequency, table size, write overhead, existing equivalent indexes, composite-index use, and query plans must be considered before any change.

## Candidate list requiring review
### Driver / partner
- `public.krim_driver_assignments(partner_assignment_id)`
- `public.krim_driver_assignments(vehicle_id)`
- `public.krim_driver_tracking_sessions(driver_assignment_id)`
- `public.krim_partner_compliance_evidence(organization_id)`
- `public.krim_partner_opportunities(shipment_leg_id)`
- `public.krim_partner_quotes(shipment_leg_id)`
- `public.krim_vehicle_driver_bindings(driver_user_id)`
- `public.krim_vehicle_driver_bindings(vehicle_id)`

### Quotes / claims / payments
- `public.krim_quotes(partner_quote_id)`
- `public.partners(user_id)`
- `public.payment_orders(krim_quote_id)`
- `public.payments(quote_id)`

### Custody / dispatch authorization
- `public.krim_shipment_leg_custody_transfer_events(actor_user_id)`
- `public.krim_shipment_leg_custody_transfer_events(transfer_id)`
- `public.krim_shipment_leg_custody_transfers(from_leg_id, shipment_id)`
- `public.krim_shipment_leg_custody_transfers(to_leg_id, shipment_id)`
- `public.krim_shipment_leg_custody_transfers(receiving_organization_id)`
- `public.krim_shipment_leg_custody_transfers(accepted_by)`
- `public.krim_shipment_leg_custody_transfers(created_by)`
- `public.krim_shipment_leg_custody_transfers(responded_by)`
- `public.krim_shipment_leg_dispatch_authorizations(partner_assignment_id)`
- `public.krim_shipment_leg_dispatch_authorizations(capacity_binding_id)`
- `public.krim_shipment_leg_dispatch_authorizations(reservation_id)`
- `public.krim_shipment_leg_dispatch_authorizations(shipment_leg_id)`

### Returns and reverse logistics
- `public.krim_shipment_return_quality_reviews(facility_id)`
- `public.krim_shipment_return_quality_reviews(return_id)`
- `public.krim_shipment_return_quality_reviews(reviewer_user_id)`
- `public.krim_shipment_return_receipt_items(return_id)`
- `public.krim_shipment_return_receipts(facility_id)`
- `public.krim_shipment_return_receipts(received_by)`
- `public.krim_shipment_returns(partner_response_by)`
- `public.krim_shipment_returns(requested_by)`
- `public.krim_shipment_returns(shipment_id)`
- `public.krim_shipment_returns(shipment_leg_id)`

### Warehouse
- `public.krim_warehouse_shipment_allocations(facility_id)`
- `public.krim_warehouse_shipment_allocations(inventory_id)`
- `public.krim_warehouse_shipment_allocations(picked_by)`
- `public.krim_warehouse_shipment_allocations(released_by)`
- `public.krim_warehouse_shipment_allocations(reserved_by)`
- `public.krim_warehouse_shipment_allocations(shipment_leg_id)`
- `public.krim_warehouse_transfer_quality_reviews(facility_id)`
- `public.krim_warehouse_transfer_quality_reviews(reviewer_user_id)`
- `public.krim_warehouse_transfers(destination_facility_id)`
- `public.krim_warehouse_transfers(destination_inventory_id)`
- `public.krim_warehouse_transfers(dispatched_by)`
- `public.krim_warehouse_transfers(quality_reviewed_by)`
- `public.krim_warehouse_transfers(received_by)`
- `public.krim_warehouse_transfers(source_facility_id)`
- `public.krim_warehouse_transfers(source_inventory_id)`

## Interpretation
The screen checks whether an index begins with the exact FK column sequence. A composite index can cover an FK when the FK columns are its leading columns; an index with those columns only later in its key does not qualify for this screen. Partial indexes and expression indexes were excluded. This is a conservative catalog-level test.

Before proposing indexes:
1. Inspect table row counts and index sizes.
2. Check equivalent indexes with alternate names or compatible leading prefixes.
3. Review query plans and actual workload/slow-query evidence.
4. Prioritize high-volume join/delete/update paths and operational tables.
5. Estimate write amplification and storage cost.
6. Prepare a migration only after repository/production migration reconciliation and an approved deployment plan.

## Priority for deeper review
Start with dispatch/custody, driver assignments, warehouse allocation/transfer, return workflows, and payment/quote relationships because they participate in core operational journeys. This is a review priority, not authorization to create indexes or enable those workflows.

## Safety status
This was a read-only catalog check. No production indexes were created, dropped, renamed, or modified. No migrations were applied. The migration-reconciliation blocker remains: the sanitized production schema manifest workflow has not yet appeared in GitHub Actions. The operator guide still contains the manual workflow-dispatch inputs.
