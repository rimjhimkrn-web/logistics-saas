# Fleet driver–vehicle binding eligibility consistency

**Date:** 17 November 2026  
**Scope:** Read-only review of the five public fleet compatibility RPCs used by the Partner Driver–Vehicle Assignment page.  
**Status:** Remediation specification only — no production SQL changed.

## Summary

The binding RPC is materially stricter than the eligible-driver listing RPC. This creates a misleading dispatch experience: a driver can appear in the eligible list but fail when a dispatcher attempts to bind them. The database remains the final gate, but the UI should not present incomplete eligibility as confirmed eligibility.

## Verified live function behavior

### `krim_vehicle_driver_bind(bigint, uuid, uuid)`

The SECURITY DEFINER function requires:
- authenticated caller and `shipment.dispatch` permission in the target organization;
- active, verified, compliant registered-business partner organization;
- current verified transport capability;
- vehicle owned by the organization, verified and active, with positive recognized kg/tonne payload;
- mandatory vehicle documents configured for the vehicle's country/category and approved/current;
- driver profile in the same organization, active driver membership, verified profile, non-empty licence number, non-null unexpired licence date;
- accepted front and back licence documents and accepted identity document;
- no existing active binding for the vehicle or driver.

It creates the binding and an audit event. EXECUTE is granted to authenticated, service_role and postgres.

### `krim_vehicle_driver_eligible_drivers(bigint)`

This SECURITY DEFINER listing checks:
- dispatch permission;
- active driver membership in the target organization;
- profile verification status in ('verified','approved');
- non-empty licence number;
- accepted front and back licence documents;
- no active vehicle binding.

It does **not** filter for:
- non-null and unexpired `licence_expiry_date`;
- accepted `identity_document`.

Therefore it can list a driver whom the bind RPC will reject. The bind RPC correctly fails closed, but the preselection list is not an accurate eligibility contract.

### `krim_vehicle_driver_eligible_vehicles(bigint)`

The vehicle list checks active/verified/compliant registered-business organization, current verified transport capability, verified/active vehicles, positive payload and recognized units, required vehicle-document configuration and approved/current required documents, and no active binding.

### `krim_vehicle_driver_binding_list(bigint)`

Requires authenticated caller and dispatch permission, then returns all bindings in the requested organization. It does not itself repeat the organization's active/verified/compliant status checks. Confirm whether the permission helper already guarantees those lifecycle conditions before relying on this list as an operationally current view.

### `krim_vehicle_driver_unbind(uuid, text)`

Requires authentication, an active binding, dispatch permission for that binding's organization, and a reason of at least five characters. It blocks unbinding when an assignment for that vehicle+driver is in assigned/accepted/pickup_complete/in_transit/exception status, then revokes the binding and writes an audit event.

The review did not establish a common row-lock/serialization protocol between unbind and every assignment-creation/acceptance path. A race must be ruled out before treating the open-assignment check as a concurrency-safe invariant.

## Required remediation

1. Make eligible-driver selection use the same canonical eligibility predicate as binding, including licence expiry and accepted identity evidence.
2. Avoid duplicating subtly different eligibility rules: create a private canonical validator or a shared read-only eligibility predicate with explicit organization, profile, membership and evidence tuple checks.
3. Confirm that profile/document review status changes invalidate any previously displayed eligibility; the bind RPC must always revalidate at commit time.
4. Establish a shared lock/serialization strategy for bind, unbind, assignment creation, assignment acceptance and driver/vehicle reassignment. Prove no active assignment can lose its binding due to a race.
5. Ensure all functions have explicit, least-privilege EXECUTE grants and that SECURITY DEFINER search paths remain empty/fully qualified.
6. Add staging tests for expired/missing licence dates, missing identity evidence, stale/revoked documents, multiple active memberships, wrong-organization driver/vehicle IDs, duplicate active bindings, concurrent bind attempts, and concurrent unbind vs assignment creation.
7. Verify binding history and audit-event immutability and confirm that assignment execution validates the exact active driver–vehicle binding, not only the presence of a binding somewhere on the shipment.

## Release decision

**NO-GO for treating the eligible-driver list as authoritative until it matches the bind validator.** The final bind RPC currently rejects the missing/expired licence and missing identity-evidence cases, so this review does not establish that those cases can bypass binding. Do not change production DDL or function definitions until repository/production migration history reconciliation is complete, a staging migration is tested, and ACL/RLS review is signed off.
