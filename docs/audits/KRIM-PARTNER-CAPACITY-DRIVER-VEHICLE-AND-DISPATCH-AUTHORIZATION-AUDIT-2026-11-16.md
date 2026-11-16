# KRIM Partner Capacity, Driver/Vehicle and Dispatch Authorization Audit — 2026-11-16

## Scope
Reviewed partner capacity-resource registration, lane-specific availability, capacity reservation, driver discovery/assignment and exact-leg dispatch authorization. Inspected current Supabase function definitions and the partner capacity/dispatch browser pages. Two browser gates were tightened. No production SQL, policy, assignment, reservation, dispatch or shipment data was changed.

## Browser safeguards implemented
1. `public/partner/capacity-resources.html` now requires exactly one active registered-business partner/warehouse organization with verified identity, lifecycle exactly `active`, and compliance exactly `compliant`. Ambiguous organization contexts are blocked.
2. `public/partner/dispatch-assignment.html` now requires exactly one active partner organization and the same explicit identity/compliance/lifecycle conditions before listing accepted assignments or offering driver assignment.

## Backend strengths confirmed
- `krim_partner_register_capacity_resource` is SECURITY DEFINER with empty search_path and requires authentication, active organization membership, `partner.manage`, current partner compliance helper, active transport mode/location, an individually verified capability for the resource's country/mode, future finite availability, and 1–5 unique private evidence paths owned by the submitter. New resources are `pending_review`; their availability starts `unavailable`. This correctly prevents a partner's self-reported capacity from becoming bookable.
- `krim_partner_register_capacity_resource_for_lane` checks an active lane matching origin and transport mode, delegates to the registration function, and binds the resulting availability to that lane.
- `krim_partner_reserve_shipment_leg_capacity` requires active membership and shipment.update, accepted/active exact-leg assignment, current partner compliance, verified exact-leg capability, pre-dispatch leg state, matching verified resource and availability, approved active network lane, future time window and positive remaining capacity. It uses row locks with `SKIP LOCKED`, overlap-aware reservations, idempotency and audit events. A confirmed reservation and leg binding are created together.
- `krim_assign_driver_to_partner_shipment` requires an accepted partner assignment, shipment.dispatch permission, assigned exact leg owned by the partner, ROAD mode, route capability, approved service area, active driver membership, verified driver profile and accepted front/back licence documents, active driver-vehicle binding, verified active vehicle and current mandatory vehicle documents, plus payload capacity sufficient for shipment weight. It prevents a driver or vehicle from receiving another open assignment.
- `krim_authorize_leg_dispatch` requires shipment.dispatch, accepted exact-leg partner assignment, assigned leg, confirmed physical capacity binding and partner-owned confirmed reservation. ROAD dispatch requires accepted driver assignment, verified driver and unexpired licence, verified active vehicle, current licence documents and current mandatory vehicle documents. Later legs require accepted custody transfer from the immediately preceding leg. Authorization is idempotent and explicitly does not record physical departure.

## P0 backend issues to correct after migration reconciliation
1. `krim_list_dispatchable_drivers` checks shipment.dispatch permission and organization status fields, plus route capability, but does not call `private.krim_partner_compliance_is_current`. Its organization compliance allowlist accepts `clear`, `approved`, `verified`, `not_required`, and `not_applicable`. Direct authenticated callers may obtain driver names/emails for an assignment even when the current compliance review is stale or revoked, unless another uninspected helper blocks it.
2. `krim_assign_driver_to_partner_shipment` checks a verified driver profile and licence number and accepted front/back evidence, but the visible function does not check `licence_expiry_date >= current_date` at assignment time. Dispatch authorization later does check expiry and will block physical dispatch, but KRIM should prevent assigning an expired-licence driver in the first place.
3. `krim_assign_driver_to_partner_shipment` does not visibly require an explicit accepted driver response before assignment creation. The dispatch authorization later requires `da.status='accepted'`, `accepted_by=da.user_id` and `accepted_at IS NOT NULL`; verify the driver acceptance flow is mandatory and cannot be bypassed through any alternate RPC or direct write.
4. `krim_partner_reserve_shipment_leg_capacity` and `krim_authorize_leg_dispatch` do not visibly invoke the unified market activation / approved corridor dossier / mandatory corridor-control / customs-clearance gate. The earlier RPC audit found this corridor integration gap. A partner's capacity and driver readiness must never bypass legal corridor activation and shipment-specific compliance.
5. Dispatch authorization is not physical departure. The physical departure event, GPS/telematics provenance, driver identity, timestamps, and exception handling must remain separate, evidence-backed steps. Do not label authorization as dispatched or in-transit.

## Operational data reality
Earlier live inventory showed zero capacity resources/reservations, zero partner assignments and zero dispatches. Therefore the existence of the functions and safeguards is not evidence that any route or partner can currently execute real freight. The new resource submission workflow is pending review and cannot create bookable capacity by itself.

## Migration and release safety
The production migration history remains unreconciled against repository SQL (558 production history rows versus 363 repository SQL files, 348 unique timestamps, and significant name/timestamp divergence). No backend correction or production DDL was applied. Resolve the sanitized schema manifest and migration crosswalk before replacing SECURITY DEFINER functions or changing grants/policies.

## Verification
- Re-fetched the updated capacity and dispatch pages from GitHub and verified their one-organization and explicit-compliance gates.
- GitHub Actions for the latest commit are not yet confirmed complete.
- No driver was assigned; no capacity was reserved; no dispatch authorization, physical departure, tracking event, payment or settlement was created.

## Next priority
Reconcile the production schema/migrations, then implement and test the four backend corrections above (driver discovery compliance, licence-expiry precondition, mandatory driver acceptance, and corridor/customs gates) in staging before enabling real dispatch.