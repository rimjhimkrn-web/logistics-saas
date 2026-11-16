# KRIM Driver, Vehicle, GPS Tracking, Delivery Proof and Final-Mile Readiness Audit
**Date:** 16 November 2026  
**Scope:** Read-only review of production driver/vehicle/tracking/POD/milestone/exception record counts, selected database function definitions and grants, plus deployed source for the GPS edge functions and native driver tracking client. No driver, vehicle, shipment, GPS session, POD, exception or delivery record was created or changed. No GPS endpoint or business RPC was invoked.

## Executive decision
**NO-GO for real driver dispatch, live GPS tracking or final-mile delivery operations.** The production database contains no driver profiles, driver assignments, driver verification documents, vehicles, vehicle documents, vehicle bindings, tracking sessions, POD records, delivery evidence, shipment POD documents or exceptions. There is one tracking event and two milestone records, both `pickup_completed`; these isolated records do not establish a functioning shipment journey.

A positive privacy control is present: GPS collection is intentionally disabled in both server edge functions and the native app until the exact consent notice and retention/deletion/legal-hold controls are approved. Do not enable GPS by setting environment variables alone; the source-level approval constant is also false.

## 1. Production record baseline
| Object | Rows |
|---|---:|
| Driver profiles | 0 |
| Driver assignments | 0 |
| Driver verification documents | 0 |
| Vehicles | 0 |
| Vehicle documents | 0 |
| Vehicle-driver bindings | 0 |
| Driver tracking sessions | 0 |
| Driver trip events | 0 |
| Tracking events | 1 |
| Shipment milestones | 2 |
| POD records | 0 |
| Driver delivery evidence | 0 |
| Legacy shipment POD documents | 0 |
| Operational exceptions | 0 |
| Exception timers | 0 |
| Exception escalations | 0 |

Both milestone records are `pickup_completed`. There is no production evidence of driver arrival, pickup, route progress, delivery arrival, independently verified POD or an exception escalation lifecycle.

## 2. Positive driver and vehicle controls
The reviewed `krim_driver_accept_assignment` routine:
- Requires the signed-in user to own the driver assignment and hold active driver membership in the exact partner organization.
- Requires a verified driver profile, unexpired licence and independently accepted front/back licence plus identity evidence.
- Requires the exact assigned vehicle to be verified, active and actively bound to the driver.
- Requires all mandatory country/category vehicle documents to be approved and unexpired.
- Checks shipment weight against verified vehicle payload capacity, with explicit kg/tonne unit normalization.
- Requires the exact partner assignment, shipment leg, road mode, active partner compliance, matching verified capability and approved effective service area.
- Only then changes a pending driver assignment to accepted.

Vehicle verification requires an independent reviewer, AAL2 platform-admin guard, configured mandatory country/category document requirements, accepted current evidence and evidence-owner/path/metadata checks. Expired mandatory vehicle evidence can suspend the vehicle through the expiry routine.

These are useful safeguards, but there are no production driver/vehicle records to prove that they have been exercised.

## 3. GPS privacy and technical readiness
The deployed source currently has multiple independent closed gates:
- Edge function `krim-driver-gps-update` requires the environment launch flag/version and a source-level `CONSENT_NOTICE_APPROVED=false`.
- Edge function `krim-driver-tracking-session` permits stop operations but blocks session start while the source-level consent approval is false.
- Native driver client sets `DRIVER_GPS_LAUNCH_ENABLED=false` and `DRIVER_GPS_CONSENT_NOTICE_APPROVED=false`, and refuses to start local collection.
- GPS updates require a valid authenticated user, exact user-owned driver assignment, in-transit assignment, verified driver profile/licence, active tracking session, matching shipment/partner/organization/session, exact archived notice hash/version/language, active driver membership and native Android/iOS client.
- Coordinates are range-checked; accuracy must be 250m or better; device timestamps must be within five minutes; heading and speed are bounded; only foreground/background native collection methods are accepted.
- Idle tracking sessions are designed to expire after 15 minutes without a GPS event, with a scheduled five-minute worker.

**Decision:** Keep GPS disabled. Before launch, publish and approve a clear notice and language versions, purpose and visibility, retention schedule, deletion process, legal-hold rules, driver withdrawal behavior, background permission and notification behavior, device-loss/revocation procedure, data-subject request handling and customer access controls. Then verify that the scheduled expiry job is active and that stale/revoked assignments stop collection. Do not treat GPS as emergency monitoring or guaranteed live navigation.

## 4. POD and delivery authorization controls
- Driver-facing POD submission is exposed through `krim_driver_submit_delivery_pod`; the internal submission routine is service-role-only.
- Internal submission locks the exact partner assignment, shipment and leg, rejects inconsistent linkage, requires in-transit shipment and active/accepted assignment, and serializes duplicate submissions.
- Same-payload retry is idempotent; a conflicting retry payload is rejected.
- Submission requires driver-assignment linkage and at least one driver evidence reference.
- Platform POD review requires authenticated AAL2 and platform-admin permission, a meaningful decision reason, pending review state, and rejects a reviewer who is the assigned driver.
- Review additionally checks that at least one delivery evidence storage object exists in the private driver evidence bucket and is owned by the assigned driver.
- Verified POD invokes delivery authorization, completes the exact leg/assignment and only marks the shipment delivered when all legs are complete; tracking and partner execution events are recorded.
- Internal verify/authorization routines are not directly executable by anon/authenticated roles.

These controls are not proof of customer-recognized receipt or successful E2E delivery. Staging must validate recipient identity/role, signature/photo evidence integrity, object retention and access, evidence supersession, wrong-tenant denial, reviewer independence, exact leg/assignment binding, multi-leg final-delivery calculation and retry conflicts. Customer ePOD access must remain limited to independently verified evidence for an authorized organization.

## 5. Known lifecycle gaps and risk
1. **Milestone sequencing:** the previously reviewed operational milestone routine validates identity/assignment, coordinate ranges, duplicate events and closed-shipment rules, but does not enforce strict predecessor milestone order. A caller with otherwise valid assignment access may submit a later milestone before its prerequisite. Add a server-side state machine/leg-aware predecessor guard before live use.
2. **Manual coordinates are not GPS proof:** operational milestone RPC accepts paired latitude/longitude from an authorized caller. These coordinates must be labelled as manually supplied event metadata, not verified device tracking.
3. **Tracking capability indicator:** previously reviewed UI `can_record` is broader than actual server-side write authorization. Keep UI affordances advisory; server authorization remains decisive.
4. **No exception data:** zero exceptions/timers/escalations means there is no empirical evidence that detection, escalation, acknowledgement, resolution and timer cancellation work in production.
5. **Driver/vehicle evidence expiry and revocation:** staging must test licence expiry, vehicle-document expiry, partner compliance suspension, driver membership revocation, vehicle unbinding and assignment cancellation during active trips.
6. **GPS retention and consent:** current disabled state is correct; the draft notice is not commercial consent. Retention/deletion/legal-hold policy and approved translated notices are prerequisites.
7. **POD is not regulatory/customs release:** delivery evidence does not establish customs clearance, insurance acceptance, customer contract completion or payment settlement.

## 6. Required staging-only end-to-end tests
Use synthetic organizations, users, shipments and evidence in staging only:
1. Driver invitation acceptance: wrong email, unconfirmed email, expired/revoked/reused token, inactive/unverified carrier and development-test profile.
2. Driver evidence: missing front/back licence, identity, expired licence, uploader ownership, wrong tenant, wrong bucket/path, altered MIME/size and self-review.
3. Vehicle: no requirement profile, missing/expired mandatory document, wrong registration jurisdiction/category, insufficient payload, invalid unit, binding conflict, unbind during active assignment and independent verification.
4. Assignment: wrong user, wrong organization, wrong partner assignment/leg, suspended capability, missing service area, expired compliance, missing capacity and assignment cancellation.
5. Milestones: every valid predecessor sequence, out-of-order transitions, duplicate retry, conflicting retry, ambiguous multi-leg assignment, forged coordinates, closed shipment and driver-vs-operations role.
6. GPS: all launch gates closed, no consent, stale notice hash, revoked membership, wrong session/assignment, out-of-transit state, stale timestamp, low accuracy, invalid coordinates, app termination, offline stop and idle expiry.
7. POD: no evidence, evidence not owned by driver, wrong shipment/leg, duplicate same payload, conflicting payload, rejected POD, self-review, unauthorized reviewer, AAL1, AAL2 approval, multi-leg completion and customer ePOD tenant isolation.
8. Exceptions: trigger creation, severity, timers, retries, escalation, independent acknowledgement/resolution, duplicate signals and cancellation of timers after resolution.

## 7. Remediation and release order
1. Add and test strict leg-aware milestone predecessor enforcement.
2. Reconcile UI state/permissions with server-side milestone and tracking authorization.
3. Complete GPS legal/privacy policy and approved notice before enabling any GPS code path.
4. Verify scheduled idle-session expiry, monitoring and retention/deletion execution.
5. Run all synthetic staging tests above, including revoked/expired evidence and multi-leg delivery.
6. Onboard real driver and vehicle evidence only after a partner, market, corridor and facility are independently approved.
7. Conduct a controlled live pilot only after all release gates pass and explicit authorization is given.

## 8. Change control and release gate
This was a read-only audit. No live GPS was collected, no tracking session was started, no driver or vehicle was verified, no POD was submitted/reviewed, no exception was raised and no shipment state was changed. Production migration reconciliation remains unresolved; do not apply production schema/function fixes until the repository/production migration crosswalk and sanitized schema manifest are reconciled.

**Release status: NO-GO for real driver assignment, dispatch, live GPS, final-mile delivery and POD-based shipment completion.** The system contains useful authorization and privacy controls, but there are no operational driver/vehicle/evidence records and no staging E2E certification.
