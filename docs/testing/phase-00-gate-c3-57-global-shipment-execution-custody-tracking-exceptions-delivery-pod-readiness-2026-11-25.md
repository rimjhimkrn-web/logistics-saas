# C3.57 — Global shipment execution, custody, tracking, exceptions and delivery/POD readiness

**Programme:** KRIM GLOBAL PLATFORM — AI QUALITY ASSURANCE, SIMULATION & RELIABILITY PROGRAMME  
**Phase:** 00 — Infrastructure Audit  
**Gate:** C3.57  
**Immutable source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**Audit date:** 2026-11-25  
**Method:** Read-only review of immutable migration source and dated 16 Nov audit artifacts. No business RPCs, browser journeys or runtime operations executed.

## Verdict

**FAIL / BLOCKED — NO-GO for real dispatch, live tracking promises, exception auto-resolution, delivery certification or customer-facing delivered status until the end-to-end exact-leg lifecycle passes isolated Staging tests.**

The source has a meaningful control design: exact-leg dispatch authorization, verified driver/vehicle requirements for road, warehouse picked-stock handover, previous-leg custody acceptance, constrained trip milestones, private POD evidence, independent POD verification and a separate delivery authorization step. However, a critical current-source conflict blocks ordinary single-leg dispatch, GPS collection is intentionally disabled, milestone sequencing and idempotency are not sufficiently strong, and exceptions/claims/recovery are not operationally proven.

## Scope reviewed

- Driver staging pages: shipment milestones, live tracking, exceptions/incidents and POD.
- Operations staging pages: dispatch control, exception management and tracking activity.
- Platform-admin POD verification page.
- Migrations for exact-leg dispatch authorization, revocation/revalidation, leg-scoped POD/completion, POD idempotency, multi-leg shipment-wide dispatch blocking, picked-allocation requirement, warehouse handover and dispatch proof.
- Dated 16 Nov end-to-end execution, dispatch/driver/tracking/custody/POD, POD authorization, customer ePOD and exception/claims/recovery audits.

## Positive source controls — PARTIAL PASS

1. **Exact-leg dispatch authorization is designed as a separate privileged operation.** The RPC requires authenticated identity, an accepted/active partner assignment linked to an exact shipment leg, `shipment.dispatch`, a bounded idempotency key, nonterminal shipment/assigned leg, confirmed exact-leg capacity binding and partner-owned confirmed reservation. It locks relevant assignment/leg/shipment records.
2. **Road dispatch has driver and vehicle prerequisites.** The reviewed dispatch design requires accepted driver assignment, verified driver profile and current licence, independently accepted front/back licence evidence, active verified vehicle, active driver–vehicle binding and mandatory current vehicle documents.
3. **Multi-leg continuation requires custody from the immediately preceding leg.** The authorization-current helper checks an accepted transfer from the prior sequence and receiving partner. Custody acceptance separately validates receiving partner assignment and capacity.
4. **Warehouse handover is an independent dispatch prerequisite.** Migration `20261116027000` requires an exact shipment-leg/facility allocation with picked stock and no remaining reserved allocation. Migration `20261116028000` requires a completed exact-leg warehouse handover and current private dispatch proof, including owner/path/MIME/size checks, before authorization can be created or remain current.
5. **Shipment-wide dispatch is blocked for active multi-leg plans.** Migration `20261116016000` prevents legacy shipment-level `dispatched` transition for multi-leg plans, directing execution to per-leg authorization.
6. **Driver trip events do not self-certify final delivery.** The dated audit found the driver event path permits pickup, in-transit and exception events but excludes final delivered; delivery is reserved for verified POD and separate authorization.
7. **POD submission and verification are distinct.** Driver submission requires active driver membership, an in-transit assignment/leg, active partner assignment and uploader-owned private evidence. Conflicting POD payload retries are rejected after locking the assignment. Internal verification/delivery helpers are SECURITY DEFINER with empty search path and were historically found not directly executable by anon/authenticated; the admin wrapper requires AAL2/platform-admin permission.
8. **Delivery authorization contains single-leg and multi-leg branches.** Dated source review found verified POD, exact assignment/shipment/leg/partner linkage, active route-plan checks for multi-leg, terminal leg/shipment rules and transactional tracking/execution/audit events. Repeat authorization is intended to be idempotent.
9. **Tracking access has privacy and organization gates.** Dated source audit found customer/partner tracking scoped to customer organization or assigned partner membership; GPS visibility requires active, consented, verified driver in-transit session, with raw GPS excluded from generic history.

## P0 — release blockers

1. **Single-leg dispatch is blocked by the current authorization-current helper.** The immutable baseline migration `20261115145401_add_dispatch_revocation_and_revalidate_at_driver_execution.sql` joins an active route plan with `p.total_legs > 1` inside `private.krim_leg_dispatch_authorization_is_current`. The dispatch trigger/currentness check also uses that helper. Therefore a normal one-leg route cannot satisfy the current authorization predicate even though the public dispatch RPC accepts an exact-leg assignment. The 16 Nov audit independently described the same trigger conflict. This is a direct functional blocker, not merely missing runtime evidence.
2. **No complete execution journey has been executed in isolated Staging.** No evidence shows accepted assignment → confirmed capacity → warehouse picked allocation → completed handover/private proof → dispatch authorization → physical departure → driver pickup → in-transit → exceptions/custody → POD submission → independent verification → delivery authorization → customer-visible completion.
3. **Non-road dispatch is explicitly held.** The dated dispatch trigger rejects non-ROAD modes. This is safer than pretending all modes are supported, but it means rail, air, ocean and other mode dispatch are not implemented through this execution gate. Do not advertise all-mode execution.
4. **GPS collection is intentionally disabled.** Driver tracking UI explicitly states it does not request or transmit browser location pending retention/deletion/legal review and native-device foreground/background tests. Tracking RPC privacy gates do not create GPS data. Do not advertise live GPS or continuous tracking.
5. **Exception and recovery operations are not proven.** Dated production inspection found zero operational exceptions, actions, timers, escalations, recovery plans or checkpoints. Configured escalation policies are not proof of due-time processing, delivery, acknowledgement or recovery. No exercised operational incident exists in the evidence.
6. **Delivery/POD is not a completed real-world proof chain.** Dated snapshot found zero driver assignments, dispatch authorizations, custody transfers, POD records and POD documents. The code's independent verification step does not prove evidence depicts the correct goods, recipient, time or location. No human review or real delivery journey was executed.
7. **Alternate and legacy lifecycle paths need complete caller/grant closure.** Dated audit identified a legacy internal transit helper that selected the first shipment leg by sequence rather than the leg attached to the supplied partner assignment, potentially flattening later-leg execution if reachable. Current callers, grants and retirement status were not independently revalidated here. The full direct DML, legacy RPC, service-role and job caller matrix is not closed.

## P1 — workflow integrity and operational gaps

1. **Milestone predecessor order is not enforced by the reviewed routine.** The dated audit found `krim_record_operational_milestone` validates actor, assignment, milestone vocabulary, note and coordinate bounds, but does not enforce strict predecessor order. A later permitted checkpoint may be recorded before earlier checkpoints unless another guard prevents it. Implement a canonical concurrency-safe per-leg transition graph.
2. **Milestone duplicate suppression is only a 60-second window.** This is not durable caller-supplied idempotency. A retry after the window can duplicate an event; two legitimate same-type events inside the window can be suppressed. Use durable event idempotency and payload conflict detection.
3. **Custody-transfer replay omits seal and discrepancy fields.** Dated audit found replay comparison omitted `seal_number` and `discrepancy_note`; a changed retry can be treated as the original transfer. Include all business-significant manifest, seal, condition, discrepancy and evidence fields in the idempotency comparison.
4. **Physical departure is separate from authorization.** An authorization event is not proof that the vehicle departed. UI/API must distinguish dispatch-ready, authorized, departed, picked up, in transit, arrived and delivered.
5. **GPS privacy lifecycle and device validation remain incomplete.** Before enabling GPS: lawful notice and explicit consent, revocation, retention/deletion, battery and background behavior, spoofing/accuracy controls, location permissions, data minimization, access audit and Android device tests are required. No GPS session was created or tested.
6. **POD evidence quality requires accountable human review.** File ownership/existence, metadata and private bucket do not prove the evidence shows the correct shipment/recipient/cargo/location. Verify evidence checklist, reviewer independence, tamper/change behavior, rejected resubmission, evidence deletion and immutable verified record.
7. **POD and delivery authorization require revocation regression.** Test stale assignment, changed route plan, revoked dispatch authorization, cancelled capacity, driver suspension, deleted/replaced evidence, duplicate review and repeated delivery authorization. Ensure verified POD cannot be silently overwritten.
8. **Exception resolution may close without required evidence or completed actions.** Dated deep audit found `krim_resolve_operational_exception` requires explanation and `compliance.manage`, but does not enforce `evidence_required`, attached evidence, action completion, shipment state or responsible partner acknowledgement before resolution; it cancels pending/in-progress actions and timers. Resolution must not silently erase unfinished corrective work.
9. **Escalation acknowledgements and timers need operational controls.** Dated audit found optional acknowledgement notes and no demonstrated timer/worker/notification lifecycle; notification metadata could remain `disabled_until_verified`. Test due-time timezone/DST, overlapping policies, concurrent worker claims, retry/lease recovery, notification receipts and re-open.
10. **Claims/disputes are not recovery settlement.** Dated audit identified claim approval/evidence and tenant linkage gaps, and approval does not prove payable/refund/settlement. Separate service complaints from monetary claims; require evidence and independent review, exact claimant/tenant/assignment/respondent linkage, and never imply KRIM refunded funds it did not receive.
11. **Customer visibility and tracking freshness need proof.** No current customer tracking journey, stale-event handling, event source confidence, timezone display, share-token expiry/revocation, notification delivery or tenant-negative test was executed.
12. **Global modes and intermodal custody semantics are incomplete.** The reviewed execution path is ROAD-specific. Rail wagon, air cargo, ocean container/vessel, warehouse dwell, customs hold/release and cross-mode handover require distinct authoritative events, custody evidence, safety checks and mode-specific POD.
13. **Control tower is not proven as an active incident command system.** Exception management pages and configured policies do not establish monitored queues, on-call ownership, SLA timers, escalation acknowledgement, action tracking or recovery closure.

## Required isolated Staging acceptance tests

- Prove both one-leg and multi-leg route plans. A valid one-leg road shipment must pass dispatch authorization when every prerequisite is satisfied; missing prerequisites must fail closed.
- Attempt non-ROAD dispatch and require explicit unsupported/blocked state, never a false dispatched status.
- Test dispatch with expired/revoked partner compliance, capability, capacity, driver licence, vehicle documents, driver–vehicle binding, membership, assignment and warehouse proof.
- Test warehouse exact-leg picked stock, remaining reservations, wrong facility/partner, missing/expired/wrong-owner private dispatch proof and concurrent reservation/handover races.
- Test authorization replay, same key/different assignment or leg, revoke/re-authorize, stale authorization and revalidation at driver execution.
- Execute physical departure separately from authorization; verify exact driver/vehicle/leg and timestamp provenance.
- Record milestone transitions in and out of order; test concurrent calls, durable idempotency, duplicate/conflicting payloads and actor/tenant denial.
- Test later-leg custody with exact manifest, quantities, condition, seal, discrepancy, timestamp, location, private evidence, receiving assignment/capacity and conflicting retries.
- Keep GPS disabled unless legal/privacy gates pass; then test consent grant/revoke, no-consent denial, session expiry, access audit, location accuracy/spoofing and supported Android foreground/background behavior.
- Submit POD with missing, wrong-owner, wrong-leg, wrong-driver, wrong MIME/size and conflicting evidence; verify independent reviewer AAL2, rejection/resubmission, immutability and exact delivery authorization.
- Verify shipment delivered only after verified POD and authorization; test single-leg, each multi-leg leg and final-leg completion; no driver self-declaration.
- Exercise late pickup, missed milestone, damage, shortage, failed delivery, safety incident, customs hold, custody refusal and partner non-response; verify holds, evidence, actions, escalation, customer notice mock, recovery checkpoint, resolution and reopen.
- Test claims/disputes with wrong claimant tenant, wrong exception/partner/leg, missing evidence, zero-value monetary claim, reviewer self-approval and approval-versus-payment separation.
- Capture browser traces, RPC outputs, DB before/after snapshots, evidence object metadata, event sequence, audit history, worker traces and repeatable negative tests.

## Status

| Area | Status | Basis |
|---|---|---|
| Exact-leg dispatch source controls | PARTIAL PASS | Authorization/capacity/driver/warehouse/custody gates exist |
| One-leg dispatch | FAIL | Current authorization-current helper requires active plan with total_legs > 1 |
| Multi-leg dispatch/custody | PARTIAL PASS | Source gates exist; no E2E execution |
| Non-road dispatch | BLOCKED | Trigger explicitly holds non-ROAD modes |
| Physical departure and milestone order | BLOCKED | Departure distinct; predecessor order/idempotency not proven |
| GPS/live tracking | BLOCKED | Collection deliberately disabled |
| Operational exceptions and escalation | NOT TESTED | No operational population or worker exercise |
| POD submission and independent verification | PARTIAL PASS | Source control chain exists; no real evidence quality/E2E test |
| Delivery authorization and completion | PARTIAL PASS | Guarded source transition; no E2E run |
| Claims/disputes/recovery | BLOCKED | Evidence, tenant, resolution and settlement gaps |
| Customer-visible tracking/delivery | NOT TESTED | No browser/device/customer journey executed |

## Safety boundary

No Production or Staging RPC/SQL, dispatch authorization, driver assignment, physical departure, milestone, tracking/GPS session, custody transfer, exception, claim, POD, delivery authorization, notification, provider call or deployment was performed. No secrets or personal driver/customer records were read. No synthetic users were created. The operational row counts and defects quoted from 16 Nov are historical snapshot evidence, not assertions about the current live database.

## Exit criteria

Do not enable live dispatch, GPS tracking, automated exception closure or customer delivery certification until the single-leg dispatch predicate is corrected and independently tested; non-road modes remain explicitly disabled until mode-specific controls exist; milestone/custody idempotency and order are fixed; GPS privacy/device gates pass; exception evidence/actions/recovery are enforced; POD evidence is independently reviewed; and complete one-leg and multi-leg journeys pass isolated Staging with retained evidence.
