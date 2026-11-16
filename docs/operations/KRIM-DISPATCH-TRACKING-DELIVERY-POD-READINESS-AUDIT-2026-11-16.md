# KRIM Dispatch, Tracking, Delivery & Proof-of-Delivery Readiness Audit

**Date:** 16 November 2026  
**Status:** read-only production audit and release specification. No production rows, schema, grants, policies, functions or shipment states were changed.

## 1. Release decision

**KRIM is not ready to execute real dispatch or certify delivery at scale.** A substantial operational workflow exists, including exact-leg dispatch authorisation, driver/vehicle checks, consented GPS tracking, milestone events, private driver evidence, POD review and delivery authorisation. However, the live production evidence is nearly empty and legacy dispatch surfaces coexist with the newer exact-leg flow.

Do not mark a shipment dispatched, delivered or completed based only on a user-edited status, a tracking ping, an uploaded file, a driver assertion or an unverified POD. The exact assignment, route leg, capacity, driver/vehicle, custody, evidence and independent verification gates must all pass.

## 2. Live production snapshot

| Table | Rows |
|---|---:|
| `krim_shipments` | 18 (previous audit) |
| `krim_shipment_legs` | 1 (previous audit) |
| `shipment_dispatches` | 0 |
| `krim_shipment_leg_dispatch_authorizations` | 0 |
| `krim_shipment_leg_activation_events` | 0 |
| `krim_tracking_events` | 1 |
| `krim_shipment_milestones` | 2 |
| `krim_driver_tracking_sessions` | 0 |
| `krim_driver_delivery_evidence` | 0 |
| `krim_pod_records` | 0 |
| `shipment_pod_documents` | 0 |
| `delivery_proofs` | 0 |
| `krim_shipment_event_receipts` | 0 |
| `krim_shipment_event_sequences` | 0 |
| `krim_tracking_synchronization_runs` | 0 |
| `krim_tracking_synchronization_links` | 0 |
| `krim_event_workflow_dispatches` | 9 |
| `krim_event_workflow_dispatch_events` | 0 |

Nine workflow dispatch rows without corresponding dispatch event rows require lifecycle/retry inspection; they are not proof of successful notification or operational execution. The single tracking event and two milestones are not proof of a real shipment in transit or delivery.

## 3. Positive controls observed

### Exact-leg dispatch authorisation
`krim_authorize_leg_dispatch` is SECURITY DEFINER and has authenticated execute permission. It requires:
- an accepted/active partner assignment tied to a specific shipment leg;
- partner `shipment.dispatch` permission;
- idempotency key, with replay bound to the same assignment and leg;
- exact leg in assigned state;
- confirmed physical capacity binding and partner-owned capacity reservation;
- for ROAD, accepted driver assignment, verified driver profile, current licence, accepted licence front/back evidence, active verified vehicle and required current vehicle documents;
- for later legs, accepted custody transfer from the immediately preceding leg.

It writes an authorisation row and a partner execution event. The separate trigger set on the authorisation table includes a warehouse handover requirement and an authorisation guard. This is a stronger model than a shipment-wide dispatch flag.

### Dispatch readiness
`krim_operations_dispatch_readiness` checks partner active/registered/verified/compliant state and current compliance, exact active multi-leg plan item, warehouse dispatch handover, driver and vehicle suitability, vehicle payload, required vehicle documents, driver assignment and exact-leg dispatch authorisation/capacity/custody. It returns explicit blockers and distinguishes `ready_for_authorized_review` from `blocked`.

### Driver POD submission
`krim_driver_submit_delivery_pod` verifies the caller is the assigned driver, active driver membership, driver assignment in `in_transit`, linked accepted/active partner assignment, and at least one private evidence object in the `krim-driver-evidence` bucket owned by that driver. It passes the evidence references into the internal POD submission routine.

### POD review
`krim_admin_review_delivery_pod` requires authenticated AAL2/MFA and platform administrator permission, a valid decision and reason, a POD awaiting review, a reviewer who is not the submitting driver, and at least one private delivery evidence object owned by the assigned driver. Verification calls the internal delivery authorisation routine and updates driver assignment status; review is audited.

### Tracking privacy
`krim_get_shipment_tracking` requires authentication and verifies customer organisation access or an active assignment partner membership. GPS coordinates are not returned in the generic event history. The latest position is returned only for an active, consented tracking session joined to a verified driver in transit, a current assignment and active partner organisation. GPS freshness is labelled active/delayed/stale and terminal shipments suppress current GPS.

### Tenant controls
RLS is enabled on POD, driver evidence, tracking sessions, tracking events, dispatch authorisations and legacy dispatch/POD tables. Customer POD access is restricted to verified records; partner organisation access is separately scoped. Driver evidence reads are limited to the driver's own evidence and active driver membership. Tracking event reads are scoped to customer, assigned partner, operations tracking permission or the assigned driver.

## 4. Critical release risks and legacy coexistence

1. **Two dispatch models coexist.** The older `krim_dispatch_shipment` routine is service-role-only but is shipment-wide, selects the first assigned leg, uses the legacy `krim_partner_shipment_capacity_commitments` table and transitions the shipment to dispatched. The newer `krim_authorize_leg_dispatch` is exact-leg, capacity-reservation and custody aware. Keep the legacy routine unavailable to client roles and do not route new UI or edge workflows through it. Before any service-role invocation, prove the caller enforces equivalent exact-leg gates.
2. **Readiness is not dispatch.** `ready_for_authorized_review` is an assessment, not a dispatch authorisation. Only the exact-leg authorisation and physical departure event should move the operational state.
3. **Physical departure and dispatch authorisation are distinct.** The exact-leg routine explicitly says physical departure must be recorded separately. UI must not imply the vehicle has left when only authorisation exists.
4. **Non-road execution is held.** The readiness routine explicitly blocks non-ROAD dispatch pending mode-specific resource and execution controls. Air, ocean, rail, warehouse and customs legs require their own operational handover, resource, custody and evidence workflows; do not reuse road driver/vehicle assumptions.
5. **Legacy status synchronisation is high risk.** `shipment_dispatches` has a large `sync_shipment_status_from_dispatch` trigger function and delivery-time synchronisation. This legacy path must be fully traced in staging to ensure direct legacy status writes cannot bypass the newer exact-leg authorisation, POD and delivery verification rules.
6. **Legacy proof tables coexist.** `delivery_proofs` and `shipment_pod_documents` coexist with `krim_pod_records` and driver-owned private evidence. Their RLS policies are based on legacy `shipment_requests`/partner identity in some cases. Do not treat any legacy proof row as canonical verified KRIM POD without an explicit migration and evidence reconciliation.
7. **POD review is platform-admin centred.** The inspected public review function requires AAL2 and `admin.platform`. Define a least-privilege operations verifier role and tenant-bound approval model before scaling; do not weaken the current gate just to make the UI convenient.
8. **Delivery authorization is a separate privileged step.** Internal verify/authorize routines are service-role/database-owner only. The orchestration must prove that POD verification, delivery authorization, shipment/leg status transition, driver completion and customer notification are atomic or recoverable as one idempotent state machine.
9. **Evidence integrity needs staging verification.** The driver submission checks a private object owner and evidence row, but file content authenticity, malware scanning, hash capture, EXIF/location handling, retention, redaction and tamper-evidence need explicit controls. A storage path is not proof that the image depicts delivery.
10. **Tracking consent and minimisation are mandatory.** Consent version, notice text/hash, language, platform and timestamps are recorded. Test consent withdrawal, stop events, session expiry, stale GPS, access revocation, retention and access audit. Never expose continuous GPS after delivery, cancellation or session stop.
11. **Tracking output contains commercial shipment data.** The authenticated function returns shipment number, route labels, goods description, weight, mode, ETA, milestones and notes. Review field-by-field whether each user class needs every field; mask or omit sensitive cargo details where not necessary.
12. **Event delivery is unproven.** Nine workflow dispatches but zero workflow dispatch events and zero shipment event receipts/sequences were found. Retry, dead-letter, ordering, idempotency and notification delivery require staging evidence.
13. **No operational performance claims are supported.** Do not advertise live tracking, real-time ETA accuracy, POD verification turnaround or delivery reliability as proven from this empty test dataset.

## 5. Canonical operational state machine

Keep the following states distinct and auditable:

1. `assignment_accepted`
2. `warehouse_handover_pending`
3. `warehouse_handover_completed`
4. `driver_vehicle_validation_pending`
5. `driver_vehicle_ready`
6. `capacity_confirmation_pending`
7. `capacity_confirmed`
8. `custody_transfer_pending` (multi-leg only)
9. `dispatch_authorization_pending`
10. `dispatch_authorized`
11. `physical_departure_recorded`
12. `in_transit`
13. `checkpoint_arrival` / `exception_reported`
14. `delivery_arrival_recorded`
15. `pod_evidence_pending`
16. `pod_submitted`
17. `pod_under_review`
18. `pod_rejected` or `pod_verified`
19. `delivery_authorized`
20. `delivered` / `closed`

Every transition must bind shipment, exact leg, assignment, partner, actor and correlation/idempotency ID. A multi-leg shipment is complete only when every required leg and custody handover is complete.

## 6. Required staging acceptance tests

### Dispatch and execution
1. No dispatch without accepted exact-leg assignment.
2. No dispatch without current partner compliance and verified route capability.
3. No dispatch without confirmed physical capacity for the exact leg.
4. ROAD dispatch rejects unverified, expired or unaccepted driver licence evidence.
5. ROAD dispatch rejects inactive/unverified vehicle, missing binding or expired mandatory documents.
6. Driver must be assigned to the same partner, shipment and exact leg and must accept their assignment.
7. Multi-leg dispatch rejects missing or mismatched active route-plan item.
8. Later leg rejects missing, wrong-order or unaccepted custody transfer.
9. Non-road legs remain blocked until mode-specific controls pass.
10. Duplicate authorisation with same idempotency key returns the same authorisation; reuse against another leg fails.
11. Revoked authorisation cannot be reused.
12. Warehouse handover must be completed by an authorised actor before dispatch.
13. Physical departure cannot be inferred from dispatch authorisation.
14. Client users cannot invoke the legacy shipment-wide dispatch function.

### Tracking and privacy
15. No tracking read without authentication and customer/active-assignment partner scope.
16. Unassigned partner and unrelated tenant cannot infer shipment existence.
17. GPS requires active session, recorded consent, verified driver, active assignment and in-transit status.
18. Consent withdrawal/stop immediately suppresses new GPS exposure.
19. Terminal shipment never returns live GPS.
20. Stale GPS is labelled stale/delayed, never represented as live.
21. GPS points never appear in generic historical event list.
22. Coordinates and shipment details are field-minimised by user role.
23. Event ordering, duplicate suppression and source attribution are deterministic.

### POD and delivery
24. Only assigned driver can submit evidence for own active assignment.
25. Submission requires in-transit status and a private evidence object owned by that driver.
26. Reject public, cross-user, wrong-bucket, oversized, unsupported or path-traversal uploads.
27. Evidence hash, content scan, timestamp and chain of custody are recorded.
28. Driver cannot verify their own POD.
29. Reviewer requires approved permission, MFA where required and reasoned decision.
30. POD rejected state permits controlled resubmission without erasing history.
31. POD verification alone cannot bypass delivery authorisation.
32. Delivery authorisation is idempotent and bound to verified POD, shipment, leg and assignment.
33. Driver, leg, shipment and customer-facing delivery states remain consistent after retries or partial failures.
34. Customer sees POD only after independent verification and only with valid organisation access.
35. Multi-leg shipment cannot be marked delivered until all required legs and custody handovers are complete.
36. Legacy `delivery_proofs` or `shipment_pod_documents` cannot silently mark canonical shipment delivered.

### Resilience and operations
37. Event dispatch retries are bounded, observable and idempotent; poison events enter a dead-letter queue.
38. Notifications never claim delivery before verified POD and authorization.
39. Audit events preserve actor, tenant, previous/new state, evidence reference and timestamp.
40. RLS and SECURITY DEFINER access are tested against customer A/B, partner A/B, driver, warehouse, operations verifier and platform admin identities.

## 7. Implementation sequence

1. Recover and reconcile the production migration source and schema backup before any production patch.
2. Reconstruct staging from a current schema-only export and reconciled migration lineage.
3. Trace every caller of legacy shipment-wide dispatch, status sync triggers, legacy proof tables and service-role paths.
4. Make exact-leg dispatch authorisation the only supported dispatch entry point; remove or permanently gate legacy write paths after staging proof.
5. Unify physical departure, tracking, milestone, exception and custody events under one append-only, idempotent event contract.
6. Complete mode-specific readiness for road, rail, air, ocean, warehouse and customs; do not mark non-road as ready by reusing road checks.
7. Harden GPS consent, freshness, field minimisation, retention and access audit.
8. Unify driver evidence and canonical POD, preserving private storage, file integrity, independent review and immutable decision history.
9. Make POD verification → delivery authorization → leg completion → shipment completion a recoverable idempotent workflow.
10. Test workflow dispatch retries, dead-letter recovery and customer notifications.
11. Pilot only after a real partner, signed agreement, verified route/capacity, trained driver/vehicle or mode resource and operational support are in place.

## 8. Commercial and user-facing boundaries

KRIM remains a coordination platform connecting customers to verified logistics providers. The partner performs transport and the customer contracts with and pays the partner directly under the initial non-custodial model. Do not represent KRIM as the carrier, insurer, customs broker or party holding freight funds unless separately authorised and contracted. Do not count freight value as KRIM revenue.

Customer-facing statuses must say what has actually happened:
- “Dispatch authorised” is not “vehicle departed”.
- “Tracking unavailable” is not “shipment stopped”.
- “POD submitted” is not “delivery verified”.
- “POD verified” is not “all multi-leg obligations completed”.
- “Delivered” requires the full required delivery authorization and shipment/leg completion checks.

## 9. Audit limitations

This was a focused read-only inspection of selected production table counts, column definitions, function definitions/ACLs and RLS policies. It did not execute operational RPCs or inspect every frontend caller, Edge Function, external tracking integration, storage policy, trigger body, scheduled worker or notification provider. Those must be traced and tested in staging before enabling real shipments.

**Final status: useful dispatch/tracking/POD foundations exist, but live operational evidence is absent and legacy pathways need reconciliation. Keep real dispatch and delivery certification gated.**
