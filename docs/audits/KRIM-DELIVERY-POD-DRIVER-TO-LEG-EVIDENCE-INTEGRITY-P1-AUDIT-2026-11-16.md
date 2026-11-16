# KRIM Delivery POD and Driver-to-Leg Evidence Integrity Audit
Date: 2026-11-16

## Executive result

**P1 — the driver POD submission wrapper does not verify that the driver assignment's shipment leg equals the linked commercial partner assignment's shipment leg.** The driver assignment table enforces that its own `shipment_leg_id` belongs to its `shipment_id`, and the partner assignment ID is a separate FK, but no cross-table constraint or trigger was found enforcing that both leg IDs match.

The submission function validates driver assignment ownership, active driver membership, in-transit state, and evidence uploaded by that driver. It then loads the partner assignment using partner-assignment ID, shipment ID, organization ID and active status — but omits the equality check for `shipment_leg_id`. It calls the internal POD creator using the partner assignment's leg. As a result, if a driver assignment is mismatched to another partner leg on the same shipment and partner organization, evidence from the driver's assigned leg could be used to submit POD against the other leg.

The admin review function later checks that some driver evidence exists for the partner assignment, but does not independently prove that the evidence driver's leg equals the POD leg. This compounds the need for exact-leg binding at submission and review.

No business RPC was invoked. No records or schema were changed.

## Production evidence

### 1. Driver assignment table constraints

The live `krim_driver_assignments` constraints include:
- `(shipment_leg_id, shipment_id)` FK to `krim_shipment_legs(id, shipment_id)`.
- `partner_assignment_id` FK to `krim_shipment_partner_assignments(id)`.
- Separate FKs for organization, driver user and vehicle.

There is no composite FK tying `partner_assignment_id` to the same `shipment_id`, `shipment_leg_id` and `organization_id`. No non-internal trigger was found on this table.

### 2. Driver POD submission wrapper

Production `krim_driver_submit_delivery_pod(uuid,text,text,text)`:
- Authenticates the driver and selects their own driver assignment.
- Requires active driver membership and driver assignment status `in_transit`.
- Requires a linked partner assignment.
- Selects the partner assignment by ID, shipment ID and partner organization, with status accepted/active.
- **Does not compare `v_partner_assignment.shipment_leg_id` to `v_driver_assignment.shipment_leg_id`.**
- Collects private delivery evidence registered to that driver assignment and owned by that driver.
- Calls the internal POD creator with the partner assignment ID.

### 3. Internal POD creator

Production `krim_internal_submit_delivery_pod(bigint,text,text,text,jsonb)`:
- Uses the partner assignment's shipment, leg and partner organization.
- Validates exact shipment/leg/partner linkage, active shipment/leg lifecycle and active route-plan item for multi-leg shipments.
- Requires evidence metadata to contain a driver-assignment ID and at least one evidence item.
- Is executable only by service_role and postgres in the observed ACL.

Because it trusts the driver-assignment ID/evidence JSON passed by the wrapper, the wrapper must enforce exact cross-link equality before calling it.

### 4. POD reviewer

Production `krim_admin_review_delivery_pod(bigint,text,text)`:
- Requires AAL2 and platform-admin permission.
- Prevents a driver who submitted evidence from reviewing their own POD.
- Requires at least one private delivery-evidence object owned by a driver assigned to the partner assignment.
- Does not independently verify that the evidence assignment's shipment leg equals the POD's shipment leg, nor that the evidence metadata attached to the POD corresponds exactly to the evidence rows reviewed.

### 5. Delivery authorization safeguards

Positive controls observed:
- Delivery verification requires AAL2 platform-admin review.
- POD status must be submitted/under_review.
- The reviewer must provide a meaningful reason.
- Delivery authorization verifies POD-to-assignment-to-shipment-to-leg-to-partner linkage.
- It requires the shipment to be in transit; for multi-leg, the exact leg must be in transit and match the active route-plan item.
- Delivery updates leg and assignment lifecycle, and only marks a multi-leg shipment delivered when all planned legs are completed.
- POD submission retries compare canonical recipient fields and evidence metadata and reject conflicting retries.

## Required remediation — not applied

1. In `krim_driver_submit_delivery_pod`, require `v_partner_assignment.shipment_leg_id = v_driver_assignment.shipment_leg_id` and require exact shipment, partner organization and assignment binding before collecting evidence or invoking the internal creator.
2. Validate that the driver's accepted assignment and evidence rows all match the same driver assignment, shipment, leg and partner organization.
3. At POD review, require the evidence metadata's driver-assignment ID to resolve to the same partner assignment, shipment, shipment leg and organization as the POD; verify every referenced storage object is uploader-owned and belongs to the registered evidence rows.
4. Add a database-level integrity constraint or carefully designed validation trigger for the cross-table assignment binding. First assess historical rows and migration-history mismatch; do not add a constraint blindly.
5. Add staging negative tests for a driver assignment linked to a different leg on the same shipment, wrong partner organization, wrong shipment, evidence path substitution, missing/deleted object, and cross-leg POD replay.
6. Preserve independent AAL2 review and no-self-review separation of duties.

## Release impact

**NO-GO for unattended POD verification and delivery completion until exact driver-to-partner leg binding is enforced and staging negative tests pass.** The downstream delivery authorization has useful linkage and lifecycle controls, but the submission wrapper leaves a cross-leg binding gap.

## Evidence boundaries

Read-only inspection of live function definitions, ACLs, table columns, foreign-key constraints and triggers. No production records, storage objects, schema, policies or functions were changed; no shipment, POD, delivery or driver operation was executed.
