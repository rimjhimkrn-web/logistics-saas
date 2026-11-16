# KRIM Physical Shipment Execution, Tracking, Exceptions and POD Audit — 2026-11-16

## Scope
Read-only review of driver tracking/milestone/POD pages, customer tracking page, platform POD verification page, and live Supabase tracking, milestone, POD, delivery authorization and exception RPC definitions. Queried operational row counts. No production data, policies or functions were changed and no operational event was created.

## Current operational evidence
- Partner shipment assignments: 0
- Driver assignments: 0
- Driver delivery evidence: 0
- Driver tracking sessions: 0
- Tracking events: 1
- Shipment milestones: 2
- POD records: 0
- Operational exceptions: 0
- Exception escalations: 0
These counts mean KRIM has no demonstrated live shipment execution journey in production yet. The single tracking event and two milestones do not prove a real partner/driver execution chain.

## Positive controls
1. Driver live-tracking browser module is explicitly read-only. It does not request browser location or transmit GPS. It states native GPS is disabled pending legal/privacy approval and requires future explicit consent, OS permission and active in-transit assignment.
2. `krim_get_shipment_tracking` is SECURITY DEFINER, empty search_path, authenticated-only. It checks customer organization access or active membership in a partner organization assigned to the shipment. It excludes GPS from historical event arrays and only returns latest GPS when there is an active consented Android/iOS tracking session, active in-transit driver assignment, active partner assignment, active driver membership, active organization, verified driver profile and valid consent notice hash. It marks GPS active/delayed/stale based on event age.
3. `krim_driver_submit_delivery_pod` requires the authenticated driver to own the driver assignment, active driver membership, in-transit state, exact linked active/accepted partner assignment and at least one private driver-owned evidence object before submitting POD.
4. POD submission is leg-scoped, checks active route-plan item for multi-leg journeys, is idempotent for exact matching retries and rejects conflicting retry payloads. POD submission records pending verification, not delivery completion.
5. Admin POD listing/review requires AAL2 and platform admin permission. Review requires a meaningful reason and prevents the submitting driver from reviewing their own POD. It requires private driver evidence ownership. Verified POD is followed by delivery authorization; only then are leg, partner assignment, driver assignment and shipment lifecycle advanced.
6. Delivery authorization checks POD/assignment/shipment/leg linkage, active assignment and in-transit state, and for multi-leg routes exact plan-item binding. It completes only the relevant leg and marks the shipment delivered only when all plan legs are complete.
7. Exception acknowledge/resolve functions require compliance.manage, lock the relevant records, record audit events and stop pending timers/actions/escalation runs when an exception is resolved.

## P0/P1 corrections required
### P0 — Milestone RPC does not enforce ordered execution state
`krim_record_operational_milestone` accepts `pickup_arrived`, `pickup_completed`, `departed_origin`, `in_transit`, `arrived_checkpoint`, `delivery_arrived`, and `exception_reported`. It checks assignment membership/permission and rejects ambiguous multiple legs, but does not visibly enforce prerequisite order or current leg/driver state for each milestone. It writes a completed milestone and manual tracking event immediately. A permitted partner member or linked driver could potentially record later-stage events out of sequence, and the RPC does not itself transition the driver/leg/shipment state. Replace with a leg-scoped state transition contract that checks exact driver/partner assignment, current state, predecessor milestone, corridor/compliance gate, idempotency and evidence requirements.
### P0 — Tracking read RPC returns overly broad `can_record` advisory
`krim_get_shipment_tracking` computes `can_record` from existence of any active partner assignment joined to any active member of that partner organization. It does not check `shipment.update`, `shipment.dispatch`, driver assignment ownership, or role. This can tell an ordinary partner member they can record events even though the write RPC may reject them. Make `can_record` use the same authorization predicate as the actual write operation, ideally returning separate capabilities for driver and partner roles.
### P1 — Partner tracking read access is organization-wide
The tracking read function permits any active member of a partner organization assigned to the shipment to read the shipment tracking response, including shipment details and latest consented GPS. Consider least-privilege roles/permissions, assigned-leg scope, and separate GPS visibility permission. Customer organization access should remain separate. Validate that all partner staff genuinely need shipment-wide GPS coordinates rather than only their assigned leg and operational role.
### P1 — Manual coordinates are not verified telemetry
The milestone RPC accepts caller-supplied latitude/longitude and labels source as `manual`. These coordinates must never be represented as verified GPS or live tracking. UI and API consumers should visibly distinguish manually reported location, carrier milestone, third-party event, and consented device GPS, with provenance and freshness.
### P1 — Exception workflow is not end-to-end proven
Exception/escalation tables currently contain zero records. Acknowledgement and resolution RPCs exist, but actual event-to-exception creation, SLA policy coverage, notifications, owner routing, evidence attachment, and retry/dead-letter handling need staging tests. Do not report an alert as delivered based solely on an outbox or provider HTTP response.
### P1 — POD evidence chain needs lifecycle tests
The driver UI uploads evidence, inserts metadata, then submits POD. If metadata insert or RPC fails it attempts to delete the uploaded object; if cleanup fails it logs an administrator-review warning. Add durable orphan-upload reconciliation, upload integrity/checksum verification, malware scanning, evidence retention controls and tests for duplicate/conflicting retries, rejection/resubmission, reviewer independence and multi-leg POD.

## Customer-facing presentation
Customer tracking should continue to distinguish shipment status, recorded milestones, manual partner updates and verified live GPS. A shipment is not delivered merely because a driver submits POD; final delivery requires independent verification and delivery authorization. Avoid estimated arrival or real-time map claims unless the relevant source is present and fresh.

## Release safety
The production migration-history mismatch remains unresolved. No production RPC replacement, grant/policy change or schema change was attempted. The above P0 corrections should be implemented only after the sanitized schema manifest and migration crosswalk are reconciled, then tested in staging with positive and negative cases.

## Verification
- Inspected canonical driver/customer/admin pages and live function definitions.
- Re-queried live counts listed above.
- No shipment, milestone, GPS session, exception, POD, delivery authorization or notification was generated.

## Next priority
Resolve migration/schema reconciliation, then implement a leg-scoped ordered milestone transition RPC and align tracking read capabilities with actual write permissions. Run a staging end-to-end shipment test through pickup, transit, exception/recovery, POD review, delivery authorization and customer visibility.