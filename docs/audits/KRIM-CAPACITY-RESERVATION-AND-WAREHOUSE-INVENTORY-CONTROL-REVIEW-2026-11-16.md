# KRIM Capacity Reservation and Warehouse Inventory Control Review — 2026-11-16

## Scope and method
Read-only inspection of live PostgreSQL function definitions and effective EXECUTE grants for authenticated users. No RPCs were invoked and no production data, schema, grants, or triggers were changed. This is a source-level control review, not a staging or concurrency test.

## CI verification
For commit `cce0d15cd97e0dc8673801723dfd68cff3e8592c`, the GitHub Actions static-link audit, production smoke checks, and Pages deployment all completed successfully. These checks do not establish correctness of live business workflows.

## Capacity reservation

### Controls observed
- Reservation requires an authenticated active member of the assigned partner organisation with `shipment.update`.
- Assignment must be accepted/active and bound to an exact shipment leg; shipment and leg are locked and checked against each other.
- Partner compliance is rechecked, and current verified capability must still cover the exact leg.
- Reservation time window must be finite, future-dated, and ordered.
- Availability is restricted to verified, available resources and availability records on an active exact origin/destination/mode lane.
- Resource and availability rows are locked with `FOR UPDATE ... SKIP LOCKED` before calculating overlapping reservations, preventing two concurrent reservations from both consuming the same locked resource row.
- Capacity accounting includes both the availability record and underlying resource, only counts overlapping confirmed or unexpired held reservations, and checks compatible units.
- Reservation, leg binding, leg schedule, assignment binding, reservation events and audit event are written in one function transaction.
- Idempotency reuse is scoped to partner organisation and checks shipment/leg binding; conflicting reuse is rejected.

### Follow-up verification still required
- Exercise simultaneous requests against the same resource in staging, including different availability records attached to one resource, overlapping and adjacent time windows, expired holds, and retry/replay after partial client timeouts.
- Confirm the lifecycle releases expired/unused reservations and that dispatch refuses missing, released, or time-incompatible capacity bindings.
- Test unit conversions and malformed legacy reservation metadata with representative fixtures.
- Do not infer real capacity from registered records: capacity remains unverified until independent evidence and partner review are complete.

## Driver assignment and acceptance

### Controls observed
- Driver assignment is limited to an accepted/active partner assignment and an assigned ROAD leg belonging to that partner.
- Partner active status, registered-business mode, verification, lifecycle, current compliance, verified mode capability and approved effective service area are rechecked.
- Driver must have active driver membership, verified profile, accepted front/back licence evidence and active binding to a verified operational vehicle.
- Mandatory vehicle documents must be approved and unexpired.
- Shipment weight and vehicle payload must be present; kg/tonne units are normalized and over-capacity assignments are rejected.
- Existing assignment linkage is checked for consistency; a driver or vehicle with another open assignment is rejected.
- Driver acceptance independently checks the authenticated user owns the assignment, active driver membership, current licence expiry, accepted identity and licence evidence, vehicle binding/status/documents, partner assignment, shipment and exact ROAD leg, route capability, and payload capacity.

### Follow-up verification still required
- Test simultaneous driver/vehicle assignment attempts and race conditions around vehicle binding revocation and document expiry.
- Confirm admin verification/revocation paths invalidate already-created but not-yet-dispatched assignments.
- Verify driver user provisioning no longer treats user-editable `raw_user_meta_data` as an authorization source; this remains a previously identified hardening item.
- A driver assignment or acceptance is not proof of dispatch or physical movement.

## Warehouse inventory and transfer controls

### Controls observed
- Shipment inventory reservation requires authenticated partner-management permission and approved facility operator access.
- Allocation is tied to an accepted/active partner assignment and, where supplied, the exact active shipment leg.
- Only released inventory at an active, approved facility can be allocated.
- Inventory rows are locked before unallocated stock is calculated; positive finite quantity, stock availability, and idempotency payload consistency are checked.
- Transfer receipt requires approved destination-facility operator access and a different user from the dispatcher.
- Received transfer stock is created/merged only in `hold` quality state; mismatched units and merging into an already released/non-hold balance are rejected.
- Transfer quality review requires received transfer, destination operator access, a reviewer different from both dispatcher and receiver, reason, idempotency key, and reviewer-owned private evidence in the designated bucket with allowed MIME types and a 10 MB size ceiling.
- Final quality review is immutable against conflicting replay and only changes inventory still on hold.
- Quality decision and audit evidence are recorded together.

### Follow-up verification still required
- Run staging concurrency tests for two simultaneous allocations against the same inventory row, transfer receipt retries, and duplicate quality-review submissions.
- Verify private storage bucket policies independently, including download restrictions and object lifecycle; ownership checks inside the RPC are not a substitute for storage policy review.
- Confirm all warehouse task transitions and shipment allocation pick/release paths preserve exact facility, lot, unit, quantity, and quality-state linkage.
- A receipt is not a quality release; a quality release is not proof of shipment dispatch or delivery.

## Security review queue
- `krim_partner_register_capacity_resource_for_lane` is authenticated-callable SECURITY DEFINER with function search_path `pg_catalog, public`. This is not by itself proof of exploitability; review its dependency resolution and harden to an empty/controlled search path with fully qualified references when migration reconciliation permits.
- The lane-specific registration wrapper checks an active lane matching origin and mode, then delegates to the base capacity registration function. Confirm the base function independently enforces organisation ownership, partner permission, evidence ownership and verification state.
- Continue reviewing authenticated SECURITY DEFINER functions and public-schema object shadowing risks. Do not change grants or definitions until the production/repository migration crosswalk is reconciled.

## Operational status
The inspected functions contain meaningful access, verification, idempotency, locking, and audit controls. However, CI is not an end-to-end test; production has no verified operational partner and no confirmed capacity-backed booking. Do not represent KRIM as ready to dispatch real freight on the basis of this review.

## Next actions
1. Reconcile production migration history with repository migrations before any DDL or function hardening.
2. Produce isolated staging fixtures and negative/concurrency test suites for capacity, driver, inventory and transfer flows.
3. Verify storage policies and base capacity registration function.
4. Validate real partner evidence and capacity before enabling customer-facing booking claims.
