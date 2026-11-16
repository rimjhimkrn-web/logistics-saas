# Driver assignment currentness and profile-to-vehicle binding — remediation specification

**Date:** 2026-11-17  
**Status:** Read-only production function and index inspection; NOT applied.  
**Production writes:** None. No driver assignment, vehicle binding, shipment or operational event was created or changed.

## Inspected production entry points

- `public.krim_assign_driver_to_partner_shipment(bigint,uuid)`
- `public.krim_vehicle_driver_bind(bigint,uuid,uuid)`
- `public.krim_vehicle_driver_unbind(uuid,text)`
- `public.krim_authorize_leg_dispatch(bigint,text)`

All four inspected functions are SECURITY DEFINER. The driver assignment and bind/unbind functions explicitly grant EXECUTE to authenticated, service_role and postgres. The authorization RPC independently rechecks driver/vehicle readiness at dispatch, but the earlier assignment write still needs complete currentness and tuple validation.

## Verified gaps in driver assignment writer

The assignment RPC correctly checks:
- accepted/active partner assignment and exact shipment/leg relationship;
- partner dispatch permission, shipment/leg assignment and partner ownership;
- active verified partner, current compliance, approved service area and transport capability;
- verified driver profile, active driver membership, non-empty licence number and accepted front/back licence evidence;
- active binding to a verified operational vehicle owned by the partner;
- mandatory vehicle documents and recognized positive payload units;
- shipment weight within vehicle payload capacity;
- existing assignment tuple consistency and no other open assignment for the selected driver or vehicle.

However, the inspected driver-profile selection does **not** require `licence_expiry_date >= current_date` (or even explicitly require a non-null, future expiry). It also does not require independently accepted identity-document evidence, although the separate `krim_vehicle_driver_bind` function does require it.

The active vehicle-driver binding lookup matches organization, driver user, vehicle and active status, but does not explicitly require `binding.driver_profile_id = selected_profile.id`. Independent foreign keys do not prove that the binding's profile row is the exact selected profile for the same user and organization.

The writer only checks required vehicle document existence/approval/expiry; it must also confirm the applicable requirements set is authoritative and current for the vehicle's jurisdiction/category. Dispatch authorization later rechecks some readiness, but later rejection does not make an invalid driver assignment safe to create.

## Existing structural controls confirmed

- `krim_driver_assignments_partner_assignment_uidx` is unique for non-null partner_assignment_id, preventing more than one driver assignment row per partner assignment.
- `krim_vehicle_driver_one_active_driver_idx` permits only one active binding per driver user.
- `krim_vehicle_driver_one_active_vehicle_idx` permits only one active binding per vehicle.
- `krim_driver_assignments_leg_shipment_fk` binds driver assignment shipment_leg_id and shipment_id to the same shipment leg.

These controls are useful but do not prove the complete driver-profile, vehicle, binding, partner-assignment and organization tuple.

## Required remediation

1. Require a non-null current licence expiry date at assignment time and at dispatch/departure; expiry must be evaluated using the correct jurisdiction/time-zone policy.
2. Require accepted identity evidence and all mandatory licence evidence at assignment time, not only at initial vehicle binding.
3. Join the active vehicle-driver binding on the exact selected driver profile ID as well as driver user, vehicle and organization.
4. Use one canonical private validator for driver profile, user, membership, licence evidence, identity evidence, vehicle, vehicle documents, active binding, partner assignment, shipment, exact leg and organization.
5. Revalidate the same tuple under deterministic row locks at dispatch and physical departure. Revocation, reassignment, profile replacement, membership suspension or evidence expiry must invalidate readiness.
6. Add composite unique keys/foreign keys only after read-only mismatch inventories and migration-history reconciliation. Do not apply speculative DDL.
7. Review all SECURITY DEFINER callers, overloads, direct grants, edge functions and internal service-role entry points. Authenticated callers and service-role callers need separate tests.
8. Ensure audit records identify the exact profile, driver, vehicle, binding, partner assignment, shipment and leg without leaking identity-document contents.

## Required staging tests

- Missing, null, expired or boundary-date licence expiry: assignment rejected.
- Missing or unaccepted identity evidence: assignment rejected.
- Binding references a different profile row for same/different user: assignment rejected.
- Wrong organization, driver, vehicle, partner assignment, shipment or leg: rejected.
- Vehicle document missing, unapproved, expired or requirement set stale: rejected.
- Driver membership suspended or profile replaced after assignment: dispatch/departure rejected.
- Binding revoked after assignment: dispatch/departure rejected.
- Two concurrent attempts to assign one driver or vehicle: no double assignment.
- Direct authenticated and service-role invocation of all relevant RPCs.
- Tenant isolation, audit completeness, rollback and idempotent retry.

## Release gate

**NO-GO for unrestricted ROAD driver assignment and dispatch** until current licence/identity checks and exact profile-to-binding equality are enforced in the canonical backend path, all callers are reconciled, staging tests pass, and the production migration history is reconciled.

This is a remediation specification only. No production DDL or grants were changed.
