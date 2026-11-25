# Phase 00 — Driver, fleet, dispatch, tracking and proof-of-delivery audit
Date: 2026-11-25
Branch: qa/phase-00-baseline-2026-11-25
Base commit inspected: d876820bb02e2f3c8e1efd4c206d4a512ca9b881

## Scope and method
Read-only inspection of Production Supabase project ebltviniygljwwseplph and Staging project qrpcivhdxobiaofppbkl; reviewed function definitions, EXECUTE privileges, RLS/policy presence, exact row counts for canonical driver/fleet/POD tables, and QA-branch HTML/JavaScript for driver POD, tracking, readiness and partner driver–vehicle binding. No database writes, storage uploads, auth changes, function invocations, GPS collection, provider calls, or real-world dispatch actions were performed.

## Evidence — canonical data is absent
Exact counts at inspection time:

| Table | Production | Staging |
|---|---:|---:|
| krim_driver_assignments | 0 | 0 |
| krim_driver_profiles | 0 | 0 |
| krim_driver_verification_documents | 0 | 0 |
| krim_driver_delivery_evidence | 0 | 0 |
| krim_driver_tracking_sessions | 0 | 0 |
| krim_driver_trip_events | 0 | 0 |
| krim_pod_records | 0 | 0 |
| krim_vehicles | 0 | 0 |
| krim_vehicle_documents | 0 | 0 |
| krim_vehicle_driver_bindings | 0 | 0 |
| krim_shipment_legs | 1 | 0 |
| krim_shipment_partner_assignments | 0 | 0 |

Therefore there is no real driver, vehicle, binding, dispatch, tracking or POD record with which to execute a meaningful end-to-end journey in either environment.

## Function permission parity
The following SECURITY DEFINER functions were checked. They are not automatically unsafe; their body-level authorization and grants must both be reviewed.

| Function | Production authenticated EXECUTE | Staging authenticated EXECUTE |
|---|---:|---:|
| krim_driver_submit_delivery_pod | yes | yes |
| krim_vehicle_register | yes | no |
| krim_vehicle_document_register | yes | no |
| krim_vehicle_driver_bind | yes | no |
| krim_vehicle_finalize_verification | yes | no |
| krim_transition_shipment | no | no |

The vehicle function grant drift is a Staging functional blocker for authenticated owner/manager fleet registration and driver binding through direct RPC. Do not blindly grant access: first inspect each function's full authorization path, page callers, intended deployment model and privilege requirements, then reconcile through reviewed migration and test. Production being callable does not itself establish correctness.

krim_transition_shipment is not executable by authenticated clients in either environment. A trusted server-side workflow or explicitly authorized wrapper must own status transitions; browser code should not be granted broad direct access as a shortcut.

## Source-level safeguards observed
- krim_driver_submit_delivery_pod requires an authenticated user, assignment owned by that user, active driver membership, assignment state in_transit, a linked accepted/active commercial partner shipment assignment, and at least one evidence object in the private krim-driver-evidence bucket owned by the driver. It delegates POD creation to an internal function. This is source-level evidence only; storage owner semantics and runtime behavior were not tested.
- krim_vehicle_register requires active owner/manager membership in an active organization and validates legacy fleet ownership when a legacy ID is supplied.
- krim_vehicle_document_register requires owner/manager membership, an organization/user/vehicle-scoped storage path, PDF/JPEG/PNG, a 10 MB ceiling, matching uploaded-object MIME/size and uploader ownership, and valid date/country/document metadata. Notably, this source reads from bucket krim-partner-verification; confirm this is intentional for vehicle records and ensure storage policies isolate vehicle evidence correctly.
- krim_vehicle_finalize_verification prevents self-review by the registrant and by a reviewer who uploaded any of the vehicle's evidence; it requires a configured country/category document profile and all mandatory evidence approved and unexpired.
- krim_vehicle_driver_bind requires dispatch permission, active verified/compliant registered-business partner status, current verified transport capability, verified active vehicle, positive recognized payload unit, all mandatory vehicle documents approved/unexpired, verified driver profile, active driver membership, valid licence expiry, accepted front/back licence and identity evidence, and no existing active binding for that driver or vehicle.
- Driver, vehicle, evidence, tracking, POD, shipment and partner-assignment tables all have RLS enabled and at least one policy in each environment. None of the inspected tables has FORCE ROW LEVEL SECURITY. Policy count alone does not prove correct isolation; cross-organization JWT tests remain outstanding.

## UI/source wiring observations
- app/driver/staging/page-11-proof-of-delivery.html is intentionally read-only: it authenticates the driver, enforces exactly one active driver organization, checks active organization status and loads only that driver's assignments. It explicitly states POD submission is paused pending backend integrity remediation. It does not create POD or claim delivery completion.
- app/driver/staging/page-09-live-tracking.html loads the authenticated driver's assignments and related krim_tracking_events; it explicitly states GPS collection is disabled and shows no fabricated map positions when no events exist. This is event-history visibility, not proof of continuous live GPS tracking.
- app/driver/staging/page-05-driver-vehicle-readiness.html checks driver profile, front/back licence evidence, the krim_driver_my_vehicle RPC and assignment context. It states that readiness does not authorize pickup.
- app/partner/driver-vehicle-assignment.html has a local staging preview with illustrative driver/vehicle/binding records; its staging bind/revoke actions only mutate browser-local preview state. It is not a Staging database integration test. Its non-staging path calls eligible-vehicle, eligible-driver, binding-list, bind and unbind RPCs.
- app/partner/vehicle-registry.html and related pages require separate authenticated runtime verification; static file presence is not proof of successful registration or upload.

## Findings and severity
1. Critical — no E2E evidence: no driver, vehicle, binding, dispatch, tracking or POD rows exist in either environment. No synthetic user journey has been executed.
2. High — Staging RPC grant drift: four fleet functions are authenticated-executable in Production but not Staging. Driver-vehicle binding cannot be runtime-tested via the current Staging client path until a reviewed access model is agreed.
3. High — POD deliberately unavailable in the staging UI: the page explicitly pauses submission. Backend function source has strong preconditions, but there is no working UI-level POD path evidenced.
4. High — no demonstrated GPS feed: the tracking UI reads historical tracking events and explicitly disables GPS collection. Do not advertise continuous driver live tracking as operational.
5. Medium — vehicle evidence bucket coupling: vehicle document registration reads the partner-verification bucket. Confirm expected bucket naming, storage policies, retention and reviewer access.
6. Medium — RLS is enabled but not forced: test RLS behavior using distinct customer, partner, driver, operations and admin JWTs; verify cross-organization reads/writes and Storage object access.
7. High — shipment transition is privileged: authenticated clients cannot execute the canonical transition function in either environment. Identify and test the intended trusted orchestration path before declaring shipment state progression operational.

## Required next verification gates
- Reconcile Staging vehicle RPC grants through a least-privilege reviewed migration; do not mirror Production grants automatically.
- Establish a safe Staging test sink and isolated synthetic organizations/users before any writes or uploads.
- Exercise driver signup/invitation, membership, profile, licence uploads, independent review, vehicle registration, document uploads, independent verification, binding, assignment acceptance, dispatch readiness, pickup/in-transit events, GPS/tracking ingestion and POD submission.
- Verify idempotency, duplicate submissions, invalid states, expired documents/licences, self-review denial, wrong-org access, wrong-driver access, missing evidence, revoked partner assignment, storage ownership and retry/recovery.
- Verify the trusted shipment transition caller and the event-to-notification chain without real external sends.
- Capture browser traces, request/response evidence, DB before/after snapshots and RLS denial evidence. Do not call a workflow PASS until each runtime assertion is evidenced.

## Decision
Driver/fleet/dispatch/tracking/POD are NOT VERIFIED for real onboarding. Source-level safeguards exist, but data is absent, the Staging fleet permission mismatch remains, the POD UI is paused, and GPS collection is disabled. No Production or Staging data/configuration was changed.
