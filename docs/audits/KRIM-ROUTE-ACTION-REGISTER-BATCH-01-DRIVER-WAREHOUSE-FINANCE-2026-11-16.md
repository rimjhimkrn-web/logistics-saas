# KRIM Route-and-Action Register — Batch 01
**Date:** 16 November 2026  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Scope:** Eight source pages inspected directly on `main`. This is static source evidence, not live functional or authorization certification.

## Page-level inventory

| Page | Direct data/API surface observed | Initial risk / verification note |
|---|---|---|
| `app/driver/module-01-assignment-inbox.html` | Reads `krim_organization_members`, `krim_organizations`, `krim_driver_assignments`; uses session retrieval | Verify server-side driver-to-assignment ownership and tenant scoping. Session presence alone is not permission proof. |
| `app/driver/module-06-shipment-milestones.html` | Reads organization membership, organization and driver assignment records; uses session retrieval | Confirm milestone writes are exclusively through authorized server-side RPCs and reject out-of-order/foreign-shipment events. |
| `app/driver/module-08-live-tracking.html` | Reads organization membership, organization, driver assignments, driver profiles and tracking events | Location disclosure requires current assignment, driver identity, tenant and purpose checks; test revoked assignment and stale sessions. |
| `app/driver/module-10-proof-of-delivery.html` | Calls `krim_driver_submit_delivery_pod`; references driver assignments, private `krim-driver-evidence` storage and delivery-evidence records | Verify upload path ownership, MIME/size/content checks, assignment linkage, reviewer independence and verified-POD visibility. |
| `app/warehouse/index.html` | Calls `krim_warehouse_dashboard`, `krim_warehouse_list_tasks` | Confirm warehouse-organization membership and facility scope enforced by RPCs; test empty and unauthorized states. |
| `app/warehouse/allocation.html` | Calls `krim_warehouse_list_assigned_shipment_legs`, `krim_warehouse_reserve_shipment_inventory`, `krim_warehouse_pick_shipment_allocation`, `krim_warehouse_release_shipment_allocation`; reads facility, inventory, partner capability and allocation tables | Critical inventory concurrency boundary: prove reservation atomicity, no double allocation, no consumption of reserved stock by legacy picking, and safe release/rollback. |
| `app/warehouse/reverse-logistics.html` | Calls `krim_warehouse_dispatch_transfer`, `krim_warehouse_receive_transfer`, `krim_warehouse_review_transfer_quality`, `krim_respond_to_shipment_return`, `krim_receive_authorized_shipment_return`, `krim_review_shipment_return_quality`; references private warehouse evidence and transfer/return receipt tables | High-risk custody and inventory mutations. Existing audit flags a SQL NULL-validation defect in `krim_receive_authorized_shipment_return`; do not exercise against production or patch DDL before migration reconciliation. Validate reserved-stock protection, independent QC and atomic return receipt. |
| `app/finance/payment-processing.html` | Reads `krim_organization_members`; no direct RPC or Edge Function invocation identified by the static call scan | This page does not establish a functioning payment collection flow. Live revenue work remains deliberately deferred. |

## Source evidence and limits
- Each row is based on literal source scan of the named HTML file for Supabase `.from(...)`, `.rpc(...)`, `functions.invoke(...)` and common session/MFA/permission signals.
- The driver pages use client session retrieval. A session check is not a substitute for server-side authorization, tenant isolation, AAL2 enforcement or resource ownership checks.
- Absence of a literal direct RPC/Edge Function call in a page does not prove that no operation occurs through imported scripts, shared modules, event handlers, or indirect helpers.
- This batch does not inspect the full RPC definitions or prove grants/RLS policy semantics. Those must be cross-checked against the reconciled production catalog and staged tests.
- No browser interaction, production mutation, shipment, dispatch, inventory reservation, evidence upload, payment, refund or settlement was executed.

## Required staging test cases
1. Driver A cannot list, track, update or submit POD for Driver B's assignment, including after membership/assignment revocation.
2. Tracking events cannot disclose another tenant's driver location or shipment.
3. Milestone RPC rejects out-of-order events, forged actor identity and cross-tenant shipment IDs.
4. POD evidence rejects wrong assignment, invalid content type/size, duplicate/conflicting submission and self-approval; private signed access expires and remains tenant-scoped.
5. Two concurrent warehouse reservations for the same available stock cannot over-allocate; retries are idempotent.
6. Picking cannot consume inventory reserved for a shipment; transfer dispatch cannot remove reserved units.
7. Return receipt rejects null/invalid required fields and mismatched item quantities; receipt and inventory changes are atomic.
8. Warehouse QC reviewer must be independent of creator/receiver; rejected quality state must not merge with accepted inventory.
9. Finance page remains non-collecting until the final, separately authorized own-service-fee phase.

## Release status
**Not certified.** The batch exposes operationally sensitive actions requiring server-side authorization and concurrency tests. Production schema/function changes remain blocked by migration-history reconciliation. No financial collection work is started.
