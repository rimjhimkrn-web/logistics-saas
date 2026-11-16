# KRIM Tracking, POD and Custody Evidence Security Review — 2026-11-16

## Scope and method
Read-only review of live SECURITY DEFINER function definitions, table grants/RLS policies and storage object policies for tracking events, driver delivery evidence, POD records and custody transfer records. No RPCs, uploads, downloads or production mutations were performed.

## CI
For commit `e13c480a2133187ce8951b4da5eb2e59c88fe59b`, all three checks passed:
- Static link audit: success (`43800454630`)
- Production smoke checks: success (`43800454676`)
- Pages deployment: success (`43800454197`)

These are not end-to-end logistics tests.

## Tracking event access and provenance

### Controls observed
- `krim_tracking_events` has RLS enabled and a scoped SELECT policy for active assigned partners, the shipment's customer organisation, authorized operations users with `tracking.view`, and the assigned driver.
- Authenticated and anon roles have no direct INSERT or UPDATE privilege on the tracking event table.
- Operational milestone RPC validates authenticated active assignment membership/permission, shipment state, supported milestone vocabulary, coordinate ranges and paired latitude/longitude.
- The generic shipment-level milestone RPC refuses ambiguous shipments with multiple active leg assignments and directs callers to a leg-specific workflow.
- Final `delivered` milestone is explicitly blocked from the generic milestone RPC and is reserved for verified POD and delivery authorization.
- Repeated same-type events within 60 seconds are deduplicated at the RPC level.

### Limitations / next tests
- The inspected generic milestone path records source `manual`; supplied coordinates are syntactically validated but are not independent proof of GPS/telematics origin.
- Validate every leg-specific milestone workflow for assignment ownership, allowed state transitions, event ordering, idempotency and whether a user can record a future or out-of-order event.
- Keep UI labels explicit: manually entered milestone, carrier-reported event and independently authenticated telematics are different evidence classes.
- Run staging negative tests for wrong partner, wrong driver, inactive membership, terminal shipment, duplicate event and invalid coordinate pair.

## POD submission and review

### Controls observed
- Driver POD submission requires the authenticated driver to own the driver assignment and have active driver membership.
- Assignment must be `in_transit`, linked to a commercial partner shipment assignment that remains accepted/active.
- At least one registered delivery evidence row must match the driver's own storage object in the private driver-evidence bucket.
- Driver cannot review their own POD through the platform admin review function.
- Admin POD list/review functions require AAL2 MFA and platform-admin permission.
- Review function requires a reason and a pending/submitted POD state.
- Verification requires driver evidence associated with the partner assignment, calls the internal verification and delivery authorization functions, and updates the driver assignment to delivered only after successful verification.
- Direct authenticated INSERT/UPDATE is denied on `krim_pod_records`; RLS exposes only scoped SELECT.
- Driver evidence table allows authenticated INSERT only under a strict owner/assignment/evidence metadata check; no direct UPDATE privilege.

### Storage controls observed
- Driver uploads are restricted to the authenticated driver's own assignment folder and active driver membership.
- Driver reads are scoped to their own assignment.
- Customers can read only evidence referenced by a verified POD belonging to a shipment in their customer organisation.
- Platform admins can preview driver evidence only with AAL2 and platform-admin permission.

### Limitations / next tests
- Review the internal POD verification and delivery authorization functions in a dedicated pass, including shipment/leg status changes and multi-leg delivery semantics.
- Verify storage object UPDATE/DELETE policies and bucket size/MIME configuration, not only SELECT/INSERT policies.
- Test that rejection leaves the shipment undelivered, resubmission rules are correct, verified POD is immutable, and signed access links expire as intended.
- A submitted POD is not verified delivery; customer evidence access is intentionally gated on verified POD.

## Custody transfer access and controls
- Custody transfer and transfer-event tables have RLS enabled but no direct authenticated INSERT/UPDATE privileges and no table policies; access is through controlled RPCs.
- Offer workflow checks adjacent legs in the same active route plan, different releasing/receiving partners, completed releasing leg with actual arrival, completed releasing assignment, receiving accepted assignment and confirmed receiving-leg capacity.
- Cargo manifest must account for every shipment cargo line with exact quantity and unit.
- Evidence must be an uploader-owned private object in the warehouse evidence bucket, in the releasing organisation/user path, with permitted MIME type and 10 MB maximum.
- Receiver response requires permission in the receiving organisation and rechecks receiving assignment and confirmed capacity before acceptance.
- Dispatch authorization for subsequent legs independently requires accepted custody transfer from the immediately preceding leg.

### Limitations / next tests
- Check whether rejecting or later revoking a custody transfer invalidates any existing downstream dispatch authorization and whether transfer offers expire.
- Test races between transfer acceptance, capacity revocation, leg reassignment and dispatch authorization.
- Confirm source/receiver roles cannot be the same user where separation of duties is required by operating policy.

## Findings and status
No direct unauthenticated tracking write path was found in the inspected table grants/policies. Tracking visibility is scoped and POD verification is MFA-gated. The primary residual risks are evidentiary provenance (manual coordinates are not authenticated telemetry), unreviewed internal POD authorization helpers, and untested revocation/expiry behavior across custody and dispatch.

Production remains non-operational for real freight until verified partners, live capacity and end-to-end staging evidence exist. No production changes were made.

## Next actions
1. Inspect internal POD verification and delivery authorization helpers.
2. Review leg-specific milestone and tracking ingestion workflows.
3. Verify storage UPDATE/DELETE policies, bucket configuration and signed URL expiry.
4. Test custody rejection/revocation/expiry against downstream dispatch.
5. Keep migration reconciliation as a hard prerequisite for any production schema change.
