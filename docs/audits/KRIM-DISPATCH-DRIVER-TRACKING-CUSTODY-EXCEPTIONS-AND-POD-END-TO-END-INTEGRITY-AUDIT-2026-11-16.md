# KRIM Dispatch, Driver Execution, Tracking, Custody, Exceptions and POD End-to-End Integrity Audit
Date: 2026-11-16
Repository: rimjhimkrn-web/logistics-saas
Supabase project: ebltviniygljwwseplph
Scope: read-only production catalog/function inspection, aggregate operational counts, and static frontend review. No business RPCs were invoked. No production rows, schema, policies, or functions were changed.

## Executive decision

**NO-GO for live shipment execution, dispatch or customer delivery promises.** The codebase contains meaningful execution controls, but production has no operational driver assignments, dispatch authorizations, POD records, custody transfers or exception records. GPS collection is explicitly gated off in the driver browser workspace pending privacy/legal and real-device validation. This is an implementation/readiness audit, not an end-to-end certification.

## Production evidence snapshot

| Object | Rows |
|---|---:|
| krim_driver_assignments | 0 |
| krim_driver_trip_events | 0 |
| krim_shipment_leg_dispatch_authorizations | 0 |
| krim_shipment_leg_custody_transfers | 0 |
| krim_tracking_events | 1 |
| krim_shipment_milestones | 2 |
| krim_pod_records | 0 |
| krim_exceptions | 0 |
| krim_partner_execution_events | 0 |

These are production counts at audit time, not evidence that the workflows have passed live execution tests.

## Positive controls observed

1. Driver assignment requires an accepted/active partner assignment, dispatch permission, assigned shipment leg, current approved partner service area/capability, active driver membership, verified driver profile and accepted front/back licence evidence. It also requires an active driver/vehicle binding, verified operational vehicle, required vehicle documents and sufficient payload capacity.
2. Driver acceptance rechecks active driver membership, verified identity/licence evidence, licence expiry, linked verified vehicle, binding and vehicle-document requirements.
3. Dispatch authorization is exact-leg scoped, requires confirmed physical capacity binding/reservation, and for road legs requires an accepted driver assignment and current licence/vehicle controls. Multi-leg dispatch requires accepted custody transfer from the immediately preceding leg.
4. Driver trip events intentionally exclude final delivery. Pickup and in-transit records are separated from final POD verification.
5. Driver POD submission requires the assignment to be in transit, active driver membership, commercially active partner assignment and at least one uploader-owned evidence file in the private driver-evidence bucket.
6. Internal POD submission rejects conflicting payload retries when a POD already exists for the same assignment/leg. POD verification records an independent verifier and audit/execution events; the internal verifier function is service-role-only.
7. Customer/partner tracking RPC requires authentication and either customer-organization access or active membership in an assigned partner organization. GPS is only exposed for an active, consented, verified driver's in-transit session; raw GPS points are not included in the generic historical event list.
8. The driver live-tracking browser module explicitly states that GPS collection is disabled pending retention, deletion, legal review and native-device foreground/background tests. It does not request or transmit browser location.

## Findings and severity

### P1 — Legacy transit-start helper can select the wrong leg in a multi-leg shipment
Function: public.krim_internal_start_shipment_transit(bigint). Its implementation selects the first shipment leg ordered by leg_sequence and updates that leg to in_transit, rather than selecting the leg linked to the supplied partner assignment. It also updates shipment-level status to in_transit. If this helper remains reachable from any active execution path for a later leg, it can write transit state against the wrong leg and flatten a multi-leg journey. Confirm all callers and retire or make this helper assignment-leg-specific before enabling multi-leg execution. The function is internal/service-role-only; no caller execution was tested in this audit.

### P1 — Custody-transfer idempotency omits two business-significant fields
Function: public.krim_create_leg_custody_transfer(...). On replay, the function compares shipment, from/to legs, cargo manifest, cargo condition and evidence path, but does not compare seal_number or discrepancy_note. A retry with a changed seal number or discrepancy note can therefore be treated as a replay and silently return the original transfer rather than rejecting a conflicting payload. Include both fields in the replay comparison and add a concurrency/retry test after migration reconciliation.

### P1 — GPS collection is not launch-ready and must not be advertised as live
The driver tracking module explicitly says GPS is disabled pending approved retention/deletion/legal review and native Android foreground/background device tests. The tracking RPC has privacy gates for consented, active, verified in-transit sessions, but no live session rows or physical-device test evidence were supplied by this audit. Keep customer-facing live-GPS promises disabled until lawful notice/consent, revocation, retention/deletion, battery/background behavior, spoofing/accuracy controls and device tests are complete.

### P1 — No operational execution evidence exists in production
Zero driver assignments, trip events, dispatch authorizations, POD records, custody transfers, exceptions and partner execution events were found. One tracking event and two shipment milestones are insufficient to validate a complete pickup-to-delivery journey. No live E2E test, dispatch, driver assignment, shipment mutation, POD submission or customer tracking test was run.

### P2 — Driver trip-event replay semantics are weaker than the POD path
Function: public.krim_driver_record_trip_event(uuid,text,text). Repeated pickup/in-transit events can return the existing assignment based on the assignment's current status and presence of a prior event. The RPC has no caller-supplied idempotency key or explicit payload-equivalence check for notes/source context. Define whether duplicate events are exact replays or separate observations; use a stable event key and compare canonical payloads before accepting retries.

### P2 — Exception workflow is not demonstrated end-to-end
Exception resolution code updates the exception, resolves escalations, cancels pending timers/actions and writes an audit event. However, production has zero operational exceptions and this audit did not execute the workflow or verify shipment/leg-specific holds, customer notification, carrier response, evidence review, or re-open semantics. Require staging tests for late pickup, failed delivery, damage/shortage, safety incident, customs hold, missed handover and recovery.

### P2 — POD submission and POD verification are separate control points; customer completion must remain gated
Driver submission creates/reuses a submitted POD; an independent verification step is required before delivery authorization. The public-facing driver module currently says evidence upload/submission is unavailable from that module and warns not to claim saved evidence. Ensure all customer, partner and operations interfaces distinguish submitted, under review, rejected, verified and delivery-authorized states. Do not translate a driver-submitted POD into delivered/closed shipment status.

## Frontend review

Repository contains dedicated driver modules for pickup, milestones, live tracking, exceptions and POD, plus operations dispatch, partner dispatch, customer tracking and platform-admin POD verification pages. The live-tracking module explicitly disables browser GPS. The POD module explicitly says evidence upload/submission is unavailable in that module. Static review only; authenticated browser tests were not performed.

## Required remediation sequence

1. Identify all callers of krim_internal_start_shipment_transit and confirm it cannot incorrectly mutate later legs; replace with exact-assignment/leg logic or retire it.
2. Correct custody-transfer replay comparison to include seal_number and discrepancy_note; add concurrent duplicate/conflicting retry tests.
3. Define event idempotency for driver trip events and enforce canonical payload equivalence.
4. Complete GPS legal/privacy/retention/revocation review and native-device test suite before enabling collection or advertising live location.
5. Add staging-only, isolated synthetic fixtures for one-leg and multi-leg journeys. Verify dispatch authorization, driver acceptance, pickup, transit, exceptions, arrival, custody handover, POD upload, independent verification, delivery authorization and customer visibility.
6. Verify tenant isolation across customer, releasing partner, receiving partner, assigned driver, operations and admin actors; verify revoked memberships and expired driver/vehicle evidence.
7. Reconcile production migration history against repository SQL before any production DDL/function changes. Existing migration-history mismatch remains a hard blocker.

## Test boundaries and limitations

- Read-only catalog/function definitions, aggregate counts and static HTML/source review only.
- No business RPC was invoked; no shipment, dispatch, assignment, tracking session, custody transfer, POD, exception, notification, payment or financial record was created or changed.
- Function excerpts and UI text do not prove actual execution behavior under concurrency or all actor roles.
- This report does not authorize production changes or commercial operations.

## Release gate

**NO-GO** for unrestricted live operations, GPS tracking, customer delivery commitments or proof-of-delivery certification. Reassess only after the migration crosswalk is resolved, P1 findings are corrected, and staging-only end-to-end and tenant-isolation tests pass with retained evidence.
