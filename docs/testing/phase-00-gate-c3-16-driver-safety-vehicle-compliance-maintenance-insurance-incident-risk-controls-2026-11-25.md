# Gate C3.16 — Driver safety, vehicle compliance, maintenance, insurance, incident response and operational risk controls

**Programme:** KRIM GLOBAL PLATFORM — AI QUALITY ASSURANCE, SIMULATION & RELIABILITY PROGRAMME  
**Gate:** Phase 00 / C3.16  
**Source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**QA branch:** `qa/phase-00-baseline-2026-11-25`  
**Review date:** 2026-11-25  
**Disposition:** **PARTIAL PASS / BLOCKED — NO-GO for operational roadworthiness, maintenance clearance, insured-fleet, emergency-response or safety-certification claims.**

## 1. Scope and method

Read-only source review of:
- Global vehicle registry and vehicle document submission.
- Independent vehicle verification and country/category-specific document requirements.
- Driver/vehicle compatibility, binding and unbinding, assignment acceptance and dispatch readiness.
- Vehicle evidence ownership and expiry scheduler.
- Driver vehicle-readiness page and incident/exception page.
- Partner fleet maintenance, vehicle-management and insurance legacy pages.
- Global Operations fleet-maintenance form and its shared `public/krim-global-operations.js` persistence adapter.
- Partner compliance evidence submission and insurance/liability evidence category.
- Existing prior source audit artifacts for fleet and insurance/contract controls.

Key migrations:
- `20261106190000_global_vehicle_registry_foundation.sql`
- `20261106200000_vehicle_document_submission.sql`
- `20261106210000_independent_vehicle_verification.sql`
- `20261106220000_driver_vehicle_compatibility.sql`
- `20261106223000_driver_vehicle_readiness_rpc.sql`
- `20261106230000_dispatch_readiness_vehicle_compatibility.sql`
- `20261115134500_verify_vehicle_evidence_owner_before_approval.sql`
- `20261115141500_require_verified_partner_for_vehicle_driver_binding.sql`
- `20261115151000_schedule_private_vehicle_evidence_expiry_worker.sql`

This is static source inspection only. No vehicle, driver, insurance certificate, maintenance record, inspection, incident or claim was created, queried in a live database, approved, rejected or modified. No RPC, cron job, Storage object, provider, dispatch or notification was invoked. No Production or Staging records were accessed or changed.

## 2. Positive source controls

1. **Vehicle registry is a real structured backend model.** `krim_vehicles` is organization-scoped and records country, registration, category/type, capacity, ownership, operational status and independent verification status. Registration number is unique per organization and country.
2. **Vehicle evidence is private and ownership-bound.** Registration requires an active organization owner/manager; the document path is bound to organization, uploader and vehicle; the object must exist in the private `krim-partner-verification` bucket and be owned by the uploader. MIME and file-size allowlists are enforced in the RPC; issue/expiry ordering is checked.
3. **Independent review has meaningful controls.** Platform verification requires AAL2 and `admin.platform`; a reviewer cannot approve their own document or verify a vehicle containing their own submitted evidence; rejection requires a reason; expired evidence cannot be approved; decisions are audited.
4. **Vehicle verification is fail-closed when requirements exist.** Finalization locks the vehicle, requires a configured country/category mandatory-document profile, checks all mandatory evidence is approved and current, and changes the verified vehicle to active only after independent review.
5. **Evidence expiry has a scheduled private worker definition.** The migration schedules a five-minute `pg_cron` job to mark expired documents and suspend verified vehicles whose mandatory evidence is no longer valid, with audit events. This is source evidence of intended scheduling only; actual job installation/execution and alerting were not checked.
6. **Driver/vehicle assignment is tied to eligibility.** Dispatch assignment checks accepted partner assignment, partner verification/compliance/capability, active verified driver membership/profile/licence, a verified active vehicle and required current vehicle documents. The assignment stores a vehicle ID.
7. **Active binding conflict and safe unbind guards exist.** Vehicle binding requires a verified/active vehicle and eligible driver; active vehicle binding conflicts are rejected. Unbinding is reasoned and audited, and is blocked while the same driver/vehicle has an open or active shipment assignment.
8. **Driver acceptance and dispatch readiness recheck vehicle eligibility.** Acceptance requires the linked vehicle to be verified/active, the driver's active binding and current mandatory evidence. Operations dispatch readiness requires a verified active vehicle, active driver binding and current mandatory vehicle documents.
9. **Driver readiness UI is deliberately limited.** It reads the driver's own profile/licence, linked vehicle and assignments, and states that a self-check cannot replace independent document verification, fleet approval or dispatcher authorization.
10. **Incident page is connected to authenticated driver/organization/assignment context.** The reviewed page loads only the signed-in driver's assignments and requires an active driver membership and active organization before enabling incident reporting.
11. **Fleet-maintenance page is not falsely presented as a vehicle-specific maintenance ledger.** It clearly says checklist status is local-only and not saved; its general operational records save to `krim_global_ops_records`, not to the canonical vehicle, assignment, maintenance or inspection tables.
12. **Insurance legacy routes are retired.** Old partner insurance management/claims pages redirect to the authenticated Partner Workspace rather than presenting an unverified standalone workflow. Partner compliance evidence includes an insurance/liability category, upload or reasoned not-applicable declaration and independent review requirement.

## 3. Findings and release risks

### P1 — No canonical vehicle roadworthiness / pre-trip inspection record and dispatch gate
The driver vehicle-readiness page checks identity, accepted licence documents and currently bound vehicle status. The fleet-maintenance page offers generic checklist items but explicitly says checklist state is local-only. No canonical per-trip inspection record was established for tyres, brakes, steering, lights, mirrors, seatbelts, load securing, emergency equipment, defects, driver attestation, inspector identity, timestamp, odometer and vehicle/assignment linkage. No demonstrated RPC blocks dispatch when a safety-critical defect is recorded.

**Impact:** A verified registration and insurance document do not prove the vehicle is mechanically safe for a specific trip. Do not claim KRIM performs a roadworthiness inspection or blocks dispatch on failed pre-trip safety checks.

### P1 — Maintenance module writes generic operational records, not a vehicle maintenance source of truth
The fleet-maintenance page persists generic `krim_global_ops_records` by module key through a shared form adapter. It explicitly says records are not linked to underlying shipment, finance, compliance or partner source-of-truth workflows; its inspection/defect/scheduled-maintenance checklist is local-only. No canonical service schedule, odometer/engine-hour interval, work order, defect severity, parts/labour, downtime, technician approval, release-to-service or maintenance due/overdue trigger is established.

**Impact:** A saved generic note cannot prove that a specific asset received maintenance or was safely released back into service. Keep the module as an administrative record only, not an authoritative maintenance or safety clearance system.

### P1 — Insurance evidence submission is not policy verification or per-shipment coverage authorization
Partner compliance includes an insurance/liability evidence category, but the legacy partner insurance-management and claims interfaces are retired. The reviewed vehicle-specific document matrix is configurable and independently reviewed, but no insurer/broker verification, policy status/cancellation check, coverage limits, named insured, vehicle/registration match, territory, mode, cargo/value scope, exclusions, deductibles, endorsements or claim notification SLA is verified in a live workflow. The prior insurance/contract audit explicitly found no executed partner contracts, insurance evidence/reviews, claims or claim evidence in its reviewed snapshot.

**Impact:** An uploaded certificate or approved document status must not be described as proof that a carrier is insured for a particular cargo, route, mode, value or shipment. Require independent policy validation and assignment-specific coverage checks.

### P1 — No safety-critical defect stop-work and emergency response state machine
The incident page supports authenticated incident/exception submission for an active assignment. Earlier driver incident controls record partner exceptions and notifications, but no full safety-specific stop-work state machine was established for collision, injury, fire, theft, brake/tyre failure, load shift, hazardous spill, vehicle breakdown or unsafe road/weather conditions. No demonstrated control-tower acknowledgement deadline, emergency contact/on-call roster, authority escalation, vehicle quarantine, safe parking/tow/recovery, replacement vehicle, cargo custody transfer and return-to-service approval is established.

**Impact:** An incident form is not an emergency response service. Do not promise 24/7 emergency response, automatic roadside assistance, guaranteed escalation or safe vehicle recovery.

### P1 — Active driver binding uniqueness is not fully race-safe
The binding table has a unique partial index for one active binding per vehicle. The binding RPC also checks whether the driver already has an active binding before inserting, but the inspected migration does not establish a matching unique partial index for one active vehicle per driver. Concurrent requests for the same driver and different vehicles may race past the read-before-insert check unless another effective database constraint/lock exists.

**Impact:** A driver may end up with multiple active vehicle bindings under concurrent operations. Add a unique partial index on active driver identity (and organization as appropriate), ensure constraints match the actual global/tenant model, and test concurrent binding attempts.

### P2 — Vehicle eligibility and document-expiry worker runtime are not proven
The expiry migration defines a five-minute cron schedule and private function, but this gate did not verify that pg_cron is installed, the job is active, the job is executing successfully, or failures alert an owner. Existing source-only checks do not prove current expiry propagation or timely dispatch denial in deployed Production/Staging.

### P2 — Evidence integrity is metadata-level, not full content authenticity
The vehicle document RPC checks storage object ownership, path, declared MIME, file size and date ordering. The reviewed controls do not establish byte-level MIME sniffing, malware scanning, OCR/registration number matching, cryptographic content hash, immutable object version or direct authority/insurer verification. A valid upload path is not proof that the document is genuine.

### P2 — No dedicated maintenance/insurance notification and acknowledgement pipeline
No durable notification evidence was established for vehicle document expiry, policy cancellation, inspection failure, defect severity, maintenance due/overdue, vehicle suspension, incident assignment, emergency acknowledgement and return-to-service. Audit rows and in-app exception rows do not prove delivered notification, acknowledgement, retry/dead-letter or fallback escalation.

### P2 — Global vehicle compliance is only as complete as the configured country/category matrix
The schema supports country/category-specific mandatory document profiles, but this review did not verify a complete, legally current requirements matrix for all countries, vehicle classes, modes and cargo types. India road-goods-carriage requirements displayed in the admin UI are guidance, not proof that every applicable permit, fitness, tax, emissions, hazardous-goods or state-specific requirement has been configured and independently validated.

### P2 — Claims handling is not operationally established
Legacy insurance claim pages redirect; no end-to-end insured loss notification, insurer notice, claim reference, evidence preservation, adjuster workflow, coverage decision, recovery/salvage, settlement and dispute/appeal process was demonstrated.

## 4. Required remediation before release

1. Implement a canonical pre-trip inspection record bound to driver, vehicle, assignment/leg, jurisdiction, inspection checklist version, timestamp, odometer, defects and evidence. Require explicit pass or controlled defect disposition before dispatch.
2. Implement defect severity and stop-work logic. Critical safety defects must set vehicle unavailable/suspended, prevent new assignment/dispatch and require independent repair/reinspection before release. Define safe handling when cargo is already in transit.
3. Replace generic maintenance notes with a vehicle-linked maintenance ledger and work-order lifecycle: scheduled interval, due/overdue, defect, technician, parts/labour, downtime, evidence, independent release-to-service and audit.
4. Add a database uniqueness constraint for active driver binding as well as active vehicle binding; use transactional locking and concurrency tests. Reconcile active assignments before any binding change.
5. Verify the expiry cron job in isolated Staging: extension, schedule row, job execution history, failure alert, suspension latency, reactivation controls and dispatch denial after expiry. Do not assume the migration schedule ran.
6. Build an insurance verification workflow that checks policy issuer/authority, policy number, named insured, vehicle/registration, period, cancellation status, territorial/mode/cargo/value scope, exclusions, limits and endorsements. Revalidate at quote/assignment/dispatch where exposure changes.
7. Add shipment-specific insurance coverage authorization and block unsupported claims; distinguish partner liability cover from cargo insurance and KRIM's own liability.
8. Build safety incident response with severity taxonomy, immediate stop-work, control-tower owner, acknowledgement SLA, emergency contacts, escalation/fallback, vehicle quarantine, recovery/tow, custody transfer and independent return-to-service.
9. Provide mandatory service notifications with durable outbox, per-recipient delivery state, retry/dead-letter, acknowledgement distinct from read state, and fallback escalation for safety-critical events.
10. Add byte-level evidence validation, malware scanning, hash/version retention, authorized-source verification and privacy/retention controls.
11. Create country/mode/vehicle/cargo requirements profiles with qualified local compliance review and controlled versioning. A missing or stale profile must fail closed.
12. Run isolated Staging negative/concurrency tests: expired/cancelled insurance; mismatched vehicle/registration/policy; missing country requirement profile; missing mandatory document; expired registration/fitness/permit/PUC; critical inspection defect; overdue maintenance; concurrent same-driver multi-vehicle binding; active assignment unbind; vehicle suspension mid-trip; failed cron; incident acknowledgement timeout; and emergency custody/recovery. Synthetic users/data only.

## 5. Verification matrix

| Check | Result | Evidence / limitation |
|---|---|---|
| Organization-scoped vehicle registry and registration uniqueness | SOURCE PASS | `krim_vehicles`, country + organization registration unique index. |
| Private vehicle document ownership/path validation | SOURCE PASS | Storage object owner/path, MIME/size and date checks. |
| Independent AAL2 vehicle document review | SOURCE PASS | Reviewer guard, self-review prevention, audit. |
| Country/category mandatory document profile | SOURCE PASS / PARTIAL | Configurable; complete jurisdiction coverage not verified. |
| Vehicle finalization requires configured mandatory documents | SOURCE PASS | Explicit non-zero requirement count and approved/current evidence. |
| Scheduled evidence expiry and vehicle suspension | SOURCE PASS for code / NOT TESTED runtime | Five-minute pg_cron schedule defined; job state/execution not inspected. |
| Driver/vehicle binding eligibility | SOURCE PASS | Verified partner, driver, vehicle, required current docs. |
| One active binding per vehicle | SOURCE PASS | Unique partial index on active vehicle ID. |
| One active vehicle per driver under concurrency | BLOCKED | RPC read-before-insert guard; no matching active-driver unique index established. |
| Binding revocation during active assignment | SOURCE PASS | Unbind refuses open/active assignment; reason and audit. |
| Driver acceptance / dispatch readiness recheck vehicle eligibility | SOURCE PASS / PARTIAL | Source guards; deployed runtime and all later execution boundaries not tested. |
| Driver pre-trip roadworthiness checklist persistence | FAIL / NOT ESTABLISHED | Readiness is identity/licence/vehicle status; generic checklist local-only. |
| Safety defect stop-work and repair release | BLOCKED | No complete defect state machine and dispatch interlock established. |
| Vehicle-linked maintenance/work-order ledger | FAIL / NOT ESTABLISHED | Generic global ops records not linked to vehicle source of truth. |
| Insurance policy validity and shipment coverage | BLOCKED | Compliance evidence category exists; independent insurer/policy/coverage validation not established. |
| Safety incident acknowledgement/emergency response | BLOCKED | Incident form exists; emergency owner/on-call/ack/fallback/recovery lifecycle not established. |
| Claims handling | NOT TESTED / BLOCKED | Legacy pages retired; end-to-end claim workflow not established. |
| Safety/maintenance/insurance notifications | BLOCKED | Durable delivery, acknowledgement, retry and fallback not proven. |
| Evidence authenticity/malware/hash/version | NOT TESTED | Metadata checks only; content validation not established. |
| Tenant, concurrency, expiry, incident and failure recovery | NOT TESTED | Requires isolated Staging and synthetic data. |

## 6. Change and safety record

- No Production or Staging SQL, RPC, RLS, grant, table, row, account, secret, provider, deployment, cron job or Storage object was changed or invoked.
- No vehicle, driver, document, binding, inspection, maintenance record, insurance policy, incident or claim was created, modified, approved or rejected.
- No dispatch was created or blocked by a live test.
- No notification was sent and no driver/partner/insurer was contacted.
- Documentation-only QA branch change.

**Gate C3.16 result: PARTIAL PASS / BLOCKED.** The vehicle registry, private evidence, independent verification, binding and expiry controls are meaningful source-level foundations. They do not yet establish actual roadworthiness, vehicle maintenance, valid shipment-specific insurance, safety-critical stop-work or emergency-response capability. Do not make those operational claims until remediated and independently tested in isolated Staging.
