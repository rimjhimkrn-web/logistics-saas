# KRIM India Launch — Partner Capability & Capacity Trigger Side-Effect Audit
**Date:** 27 November 2026  
**Environment:** Staging project `qrpcivhdxobiaofppbkl` only  
**Production:** Not accessed  
**Method:** Read-only trigger catalog, trigger-function definition and table privilege/RLS inspection.

## Scope
Reviewed trigger chains on:
- `krim_partner_capabilities`
- `krim_capacity_resources`
- `krim_partner_capacity_availability`
- `krim_partner_capacity_commitments`
- `krim_capacity_reservations`
- `krim_events` (notification side-effect confirmation)

## Findings

### A. Partner capability submission
- `trg_krim_partner_capability_audit` fires AFTER INSERT and calls SECURITY DEFINER `krim_log_partner_capability()`.
- It inserts an audit event with organization, capability ID, service/coverage metadata and `auth.uid()` as actor.
- It does not enqueue email or create an in-app notification in the inspected function.
- Note: if an approved backend/service-role path inserts the capability with no user JWT, actor may be NULL. The audit schema/consumer should make system actor semantics explicit rather than treating NULL as a human actor.
- Trigger is INSERT-only; this audit does not establish complete audit coverage for later capability verification/status updates.

### B. Capacity resource registration and independent review
- `krim_capacity_resources` has a BEFORE INSERT/UPDATE trigger requiring submitter and reviewer UUIDs to be present and different whenever status/metadata indicates verified/available.
- This is a useful separation-of-duties guard, but the trigger compares identity values supplied in row metadata; it does not itself prove that `reviewed_by` is an active platform reviewer or that the current executing principal is that reviewer.
- Current table privilege inspection shows RLS enabled, an authenticated SELECT policy only, and direct table grants only to service_role. Thus no direct authenticated table UPDATE path was observed in this check.
- Risk classification: **defense-in-depth gap / privileged-writer trust boundary**, not evidence of a currently exploitable authenticated table-write path. Any service-role/admin RPC that changes review metadata must independently verify reviewer authority and record the actual actor.
- No mutation made. Do not “fix” by granting authenticated UPDATE.

### C. Capacity availability publication
- BEFORE INSERT/UPDATE guard blocks publication unless:
  - lane is present and active;
  - resource is independently approved;
  - lane origin and transport mode match resource and availability;
  - matching active verified capability, current partner compliance and approved effective service area exist.
- Separate BEFORE UPDATE guard prevents changing ownership/resource/lane/mode/unit, withdrawing availability, reducing capacity, or narrowing windows while live reservations exist.
- This is a strong integrity boundary in the inspected path. It does not replace authorization checks on the RPC/service-role caller.

### D. Capacity commitments and reservations
- Commitment totals guard rejects non-finite/negative values, reserved+utilized above committed, invalid period, and terminal status while reservations remain.
- Reservation guard requires approved/available resource and availability, matching organization, future valid shipment interval within resource/booking windows, matching unit, and prevents overbooking.
- Matching commitment attachment is constrained by organization, lane, mode, unit, active status, period and remaining capacity.
- Counter synchronization updates reserved/utilized totals on reservation lifecycle transitions and rejects inconsistent counters or commitment mismatch.
- Live dependency guards prevent retiring or materially changing resources/availability while live reservations or bindings exist.
- These are database integrity controls; no reservation or capacity data was created or changed during this audit.

### E. Trigger side effects and test isolation
- `krim_events` still has AFTER INSERT triggers that create customer/partner/driver in-app notifications and enqueue essential email for eligible event types.
- No typed runtime lane/test-run boundary is present in those inspected event-trigger paths.
- Synthetic event insertion remains blocked until ingress and downstream queue/notification isolation is implemented and verified.
- No event was inserted and no notification/email queue was claimed.

## Table access snapshot
All five capacity tables inspected have RLS enabled. Authenticated access was limited to SELECT policies; direct table grants shown in this query were only for service_role. This is a targeted snapshot, not a complete database-wide privilege audit.

## Action items
1. Review every admin/service-role capacity approval RPC and ensure reviewer identity is derived from the authenticated principal or a trusted audited service identity, not accepted from caller-controlled metadata.
2. Add/verify audit coverage for capability verification and capacity approval/status transitions.
3. Define explicit system actor semantics for service-role inserts where `auth.uid()` is NULL.
4. Add negative tests for self-approval, forged reviewer metadata, wrong organization, unverified capability, inactive lane, overbooking, overlap, invalid time window and live-reservation mutation.
5. Keep synthetic events and notification/email delivery disabled for test fixtures until lane isolation is complete.

## Disposition
No immediate authenticated direct-table write path was observed for the capacity tables. One defense-in-depth issue remains around trust in review identity metadata at privileged write boundaries. Capacity integrity triggers are extensive, but require caller-level authorization tests.

## Safety record
Read-only Staging inspection. No SQL mutation, RPC invocation, fixture provisioning, event insertion, queue claim, email/provider/payment call or Production access.
