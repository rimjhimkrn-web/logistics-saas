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
