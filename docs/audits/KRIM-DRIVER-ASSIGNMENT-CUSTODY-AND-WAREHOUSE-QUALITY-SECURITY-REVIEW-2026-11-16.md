# KRIM Driver Assignment, Custody and Warehouse Quality Security Review
**Captured:** 16 November 2026  
**Project:** Production Supabase `ebltviniygljwwseplph`  
**Method:** Read-only inspection of selected live SECURITY DEFINER function definitions. No RPCs invoked and no production data/schema changed.

## Executive result
The reviewed operational functions contain strong control points: driver assignment acceptance requires independently accepted identity/licence evidence, verified vehicle and documents, active driver binding and payload fit; custody transfer requires adjacent legs, completed releasing leg, receiving assignment and confirmed capacity, complete cargo manifest and private evidence; warehouse quality release requires independent review and evidence.

The functions were inspected as source only. They have not been exercised with adversarial staging tests, and this report does not certify operational readiness.

## 1. Driver assignment acceptance
Function: `public.krim_driver_accept_assignment(uuid)`

Observed controls:
- Authenticated caller must own the driver assignment row.
- Caller must have active driver membership in the assigned partner organization.
- Driver profile must be verified/approved with a non-empty licence number and unexpired licence.
- Front and back licence documents and identity document must each have independently accepted review status.
- A vehicle must be explicitly linked to the assignment.
- Vehicle must be verified, operationally active and actively bound to this driver in the same organization.
- Required vehicle documents for registration country/category must be approved and unexpired.
- Partner shipment assignment must be accepted/active and match shipment, exact leg and partner organization.
- Shipment must be assigned, or be an active multi-leg shipment already in transit for a subsequent leg.
- Shipment weight and vehicle payload must be present; supported payload units are normalized to kilograms and over-capacity acceptance is rejected.
- Exact shipment leg must still be assigned to that partner and must be a ROAD leg.
- Partner needs an active approved service area and matching verified road capability for the pickup location.

**Assessment:** Strong server-side gates for driver acceptance. Assignment acceptance is not dispatch authorization or proof of departure.

**Follow-up:** Test revoked documents, expired licence at the date boundary, inactive vehicle binding, wrong partner, wrong leg, unknown payload unit, over-capacity load and multi-leg state transitions. Confirm all administrative document-review paths are independent and auditable.

## 2. Inter-leg custody transfer creation
Function: `public.krim_create_leg_custody_transfer(...)`

Observed controls:
- Requires authenticated caller and non-empty cargo manifest, valid condition, private evidence path and idempotency key.
- Locks both legs and requires adjacent sequence, same shipment, distinct assigned partners and plan-linked legs.
- Both legs must belong to the same active route plan.
- Releasing leg must be completed/delivered with actual arrival recorded and have a completed/active partner assignment.
- Releasing partner caller must have `partner.manage`.
- Receiving partner must have accepted/active assignment and confirmed physical capacity reservation for the exact next leg.
- Manifest must account for every shipment cargo line with exact quantity and unit.
- Evidence must be uploader-owned in the private `krim-warehouse-evidence` bucket, under releasing organization/user path, with allowed MIME type and size up to 10 MB.
- Idempotency key is locked and replay is accepted only when shipment, legs, manifest, condition and evidence path all match.
- Creates a pending transfer and explicit offered event; does not itself mark the transfer accepted.

## 3. Receiving partner custody response
Function: `public.krim_respond_to_leg_custody_transfer(...)`

Observed controls:
- Requires authentication and `partner.manage` on the receiving organization.
- Locks transfer, verifies it is pending and receiving leg/partner linkage has not changed.
- Before acceptance, rechecks receiving assignment and confirmed capacity reservation.
- Requires a reason when rejecting.
- Writes accepted/rejected state and event, with safe replay for an identical final response.

**Assessment:** The two-sided custody handover is explicitly separated into offer and receiver response. A transfer record is not equivalent to proof of physical arrival at destination or successful quality inspection.

**Follow-up:** Confirm private evidence read permissions are limited to authorized parties; test same-key replay, conflicting-key replay, concurrent accept/reject, manifest tampering, stale capacity and route-plan replacement.

## 4. Warehouse inventory quality review
Function: `public.krim_warehouse_review_inventory_quality(...)`

Observed controls:
- Requires authenticated verified warehouse operator at the task facility.
- Only completed goods-receipt or damage-exception tasks qualify.
- A task can receive only one final quality decision.
- Reviewer cannot be task creator or completer.
- Requires an uploader-owned private inspection report, not created by reviewer.
- Inventory SKU, lot and facility must match the task.
- Every receipt movement contributing to the inventory balance is checked for completed receipt task, independent reviewer and valid private inspection evidence.
- Writes quality status, task event and audit event with previous/new state.

## 5. Warehouse transfer quality review
Function: `public.krim_warehouse_review_transfer_quality(...)`

Observed controls:
- Only received transfers with destination inventory can be reviewed.
- Requires verified destination warehouse operator.
- Reviewer must differ from dispatcher and receiver.
- Uses transaction lock and idempotency key; conflicting replay rejected.
- Requires reviewer-owned private image/PDF evidence in organization/user path, up to 10 MB.
- Destination inventory must exist at destination facility and remain on hold.
- Updates inventory/transfer quality and writes audit record.

## Priority follow-ups
1. Test role separation and evidence provenance against colluding users and same-user aliases; identity uniqueness and account recovery should be considered.
2. Confirm all private evidence read policies enforce organization, facility, assignment and role boundaries; uploader ownership alone is not an access policy.
3. Test concurrency, replay, document revocation and expiry races for driver acceptance, custody response and warehouse review.
4. Verify no UI changes inventory to available or leg custody to accepted before the corresponding reviewed RPC succeeds.
5. Keep dispatch and custody gates intact until complete staging tests and migration recovery.
6. Review remaining authenticated SECURITY DEFINER functions, especially vehicle/driver administrative verification, capacity reservation and warehouse receipt/transfer creation.

## Limits
This is source inspection of five selected live functions, not full call-graph review, staging execution, document forgery testing, two-tenant penetration testing, or proof of real-world service availability. No production changes were made.
