# Driver-to-leg and POD evidence binding — corrective specification

**Date:** 2026-11-16  
**Status:** Prepared from read-only production inspection; NOT applied.  
**Production writes:** None. No driver assignment, POD, evidence, shipment or leg was created or changed.

## Verified live behavior

### Driver assignment acceptance

`public.krim_driver_accept_assignment(uuid)` performs substantial checks:

- The assignment belongs to the authenticated driver.
- Active driver membership and verified driver profile are required.
- Front/back licence and identity documents must be accepted.
- A verified active vehicle must be bound to the driver, with mandatory vehicle documents approved.
- The linked partner assignment must match shipment, leg and partner organization.
- The shipment must be in an eligible assigned/in-transit state.
- The exact leg must be assigned to the partner and ROAD mode.
- Current partner compliance, capability and approved origin service area are checked.
- Shipment weight must fit verified vehicle payload.

This acceptance function does not eliminate the separate POD binding issue.

### Driver POD wrapper

`public.krim_driver_submit_delivery_pod(uuid,text,text,text)`:

- Selects a driver assignment belonging to the authenticated user.
- Requires active driver membership, in-transit status and a linked partner assignment.
- Looks up the partner assignment by assignment ID, shipment ID, partner organization and accepted status.
- Collects private delivery evidence owned by the assigned driver.
- Calls the internal POD creator with the partner assignment ID and the driver assignment ID in metadata.

**Critical mismatch:** the partner-assignment lookup does not require
`partner_assignment.shipment_leg_id = driver_assignment.shipment_leg_id`.
It also does not explicitly require `partner_assignment.shipment_leg_id IS NOT NULL` in that lookup.

### Internal POD creator

`public.krim_internal_submit_delivery_pod(bigint,text,text,text,jsonb)`:

- Uses the partner assignment's shipment leg as the POD leg.
- Checks that the supplied driver-assignment metadata is present and that driver-evidence metadata is a non-empty array.
- Does not independently resolve the driver assignment and prove its shipment, leg, partner organization and driver user equal the POD's assignment/leg and evidence owners.

The result is that a driver assignment for one leg could be used by the wrapper to submit evidence against a different partner-assignment leg if the remaining conditions line up.

### POD reviewer

`public.krim_admin_review_delivery_pod(bigint,text,text)` requires AAL2, platform admin permission, a meaningful decision reason, and evidence owned by a driver associated with the partner assignment. Its evidence lookup joins driver assignments to the POD by partner-assignment ID, but does not explicitly compare the driver's assignment leg to the POD leg.

## Required remediation

1. **Enforce exact leg equality in the wrapper**
   - Require non-null `driver_assignment.shipment_leg_id`.
   - Require partner assignment shipment ID, leg ID and partner organization all equal the driver assignment.
   - Require partner assignment status accepted/active and exact leg still assigned/in-transit as allowed by the POD lifecycle.
   - Re-read and lock both assignment rows in a consistent order.

2. **Independently validate inside the internal POD creator**
   - Do not trust caller-supplied `driver_assignment_id` or evidence metadata.
   - Parse the UUID safely; reject missing, malformed or non-UUID values.
   - Resolve the driver assignment row and verify:
     - `driver_assignment.partner_assignment_id = partner_assignment.id`
     - shipment IDs equal;
     - leg IDs equal and are non-null;
     - organization IDs equal partner organization;
     - driver user is the authenticated submitting user (or a narrowly authorized internal principal);
     - assignment status and in-transit milestone are valid.
   - Independently query evidence records and storage objects; require object owner, bucket, path, MIME, size and evidence type to match the driver assignment and submitting user.
   - Do not accept evidence-array metadata as proof of file existence or ownership.

3. **Reviewer exact-leg control**
   - Require at least one evidence record whose driver assignment matches the POD's partner assignment, shipment, exact leg and partner organization.
   - Require storage object ownership and private bucket/path match.
   - Preserve no-self-review and AAL2 controls.
   - Record which exact driver assignment and evidence objects supported the review.

4. **Data model defense in depth**
   - Consider a composite FK or constraint trigger tying driver assignment `(partner_assignment_id, shipment_id, shipment_leg_id, organization_id)` to the corresponding partner assignment tuple.
   - Before adding constraints, inventory historical mismatches and nulls; do not silently rewrite evidence history.
   - Add uniqueness only after confirming intended cardinality for driver assignments per leg.

5. **Lifecycle and idempotency**
   - POD idempotent retry must compare exact driver assignment ID, exact leg, evidence object identifiers/metadata, recipient, signature and payload.
   - A changed driver, leg or evidence set must be a conflicting retry, not an idempotent success.
   - If the driver assignment is cancelled, reassigned or no longer in transit, block new POD submission.
   - Ensure POD verification and delivery authorization refer to the same exact leg and assignment.

## Required staging tests

- Driver assignment leg A with partner assignment leg B: reject in wrapper and internal creator.
- Driver assignment and partner assignment have different shipment IDs or partner organizations: reject.
- Null leg on either assignment: reject.
- Correct exact-leg pair and owned private evidence: allow submission in staging.
- Evidence array contains fabricated path, another driver's object, another leg's evidence, wrong bucket, oversized file or invalid MIME: reject.
- Internal POD RPC invoked directly with forged metadata: reject.
- Reviewer sees evidence for same partner assignment but wrong leg: reject.
- Reviewer attempts self-review: reject.
- Same idempotency key with changed driver assignment, leg or evidence object: reject as conflict.
- Concurrent duplicate POD submissions: one canonical POD; identical retry returns same result.
- Assignment cancelled/reassigned between initial page load and submission: reject.
- Tenant isolation, AAL2 review, audit evidence, transaction rollback.

## Release gate

Do not enable live POD verification or delivery completion until migration history is reconciled, function definitions/ACLs and all direct callers are inventoried, exact-leg binding is enforced in both wrapper and internal creator, and staging tests prove fabricated or cross-leg evidence cannot be accepted.

**Evidence context:** Prior operational snapshot showed zero driver assignments and zero POD records. The control remains unproven end to end; no live POD has been submitted or verified.


## 2026-11-17 read-only revalidation and additional findings

The live definitions and relational constraints were re-read on 2026-11-17. No production writes were performed.

### Confirmed wrapper defect remains live

The current wrapper still selects the partner assignment using ID, shipment ID, partner organization and status, but omits equality on `shipment_leg_id`. It then returns the partner assignment leg in the response. Therefore the frontend pause remains necessary; the frontend pause does not protect direct authenticated RPC callers.

### Internal creator is callable only by privileged roles, but still needs independent binding

Current routine grants show:

- `krim_driver_submit_delivery_pod`: EXECUTE for `authenticated`, `postgres`, `service_role`.
- `krim_internal_submit_delivery_pod`: EXECUTE for `postgres`, `service_role` (no authenticated grant observed).
- `krim_admin_review_delivery_pod`: EXECUTE for `authenticated`, `postgres`, `service_role`.

The internal creator does verify that the partner assignment has a non-null exact shipment leg belonging to the same shipment and partner, and it checks the leg's lifecycle. It also has canonical retry comparison for recipient fields and the entire evidence metadata payload. However, it still trusts the supplied `driver_assignment_id` JSON value and evidence array shape; it does not resolve the driver assignment and independently compare its partner assignment, shipment, leg, organization and user to the POD being created. A privileged direct caller can therefore bypass the wrapper's missing relationship checks unless the internal routine is hardened.

### Reviewer has a second serious mismatch

The current reviewer checks AAL2, `admin.platform`, meaningful reason, no-self-review, and at least one evidence object owned by a driver associated with the POD's partner assignment. However, its evidence query joins only on `partner_assignment_id`; it does not compare the evidence driver's shipment ID, exact shipment leg, organization, or user to the POD tuple. On verification it invokes delivery authorization and then updates driver assignments using only `partner_assignment_id` and status, without exact-leg scoping. It uses `RETURNING` into scalar variables, so if more than one row matches, only one assignment identity is retained for the subsequent trip event. The reviewer must select exactly one driver assignment matching the POD's full shipment/leg/partner tuple, or explicitly reject ambiguous/multiple matches; then update only that exact row.

### Relational constraints are insufficient for cross-table binding

The live driver-assignment table has a composite FK `(shipment_leg_id, shipment_id) -> krim_shipment_legs(id, shipment_id)`, but the partner assignment relationship is only a single-column FK on `partner_assignment_id` with `ON DELETE SET NULL`. No composite FK ties `partner_assignment_id`, shipment, leg and organization together. The evidence table has independent FKs to driver assignment and user, but no composite ownership/leg relationship. The POD table's inspected constraints likewise do not provide this cross-table binding. Historical data must be audited before adding composite unique keys/FKs or triggers.

### Revised implementation order

1. Keep the driver-facing POD submission UI paused.
2. Reconcile production migration history with repository SQL before preparing/deploying any DDL. This remains an outstanding release blocker.
3. Build a single canonical private validator that accepts the authenticated driver identity and exact driver-assignment ID, resolves all rows from the database, and proves the complete tuple: driver assignment ID, partner assignment ID, shipment ID, shipment leg ID, partner organization ID, driver user ID, assignment status and leg status.
4. Call that validator inside both the public wrapper and internal creator; never treat JSON metadata or a client-supplied evidence list as authority.
5. Make evidence validation query the evidence table and `storage.objects` for each registered path, enforce exact bucket/owner/path/assignment/user binding, MIME allowlist and size limit, and persist immutable evidence object IDs in the POD payload.
6. Harden reviewer to select exactly one driver assignment matching the POD's full tuple, prove each evidence object belongs to that exact assignment and driver, preserve AAL2/no-self-review, and update only that exact driver assignment.
7. Add relational constraints only after a production mismatch/null inventory and a staging rehearsal. Avoid cascading `SET NULL` behavior that can detach an operational assignment from its commercial partner record without an explicit cancellation/reconciliation workflow.
8. Stage-test forged direct calls, cross-leg/cross-driver evidence, ambiguous driver assignments, conflicting retries, concurrent submissions, reviewer isolation, and transaction rollback. Only then reopen the frontend action.

**Current decision: NO-GO for live POD submission, verification or delivery completion.** The frontend pause is deployed as a temporary mitigation; backend correction remains pending and production DDL is still blocked by migration reconciliation.
