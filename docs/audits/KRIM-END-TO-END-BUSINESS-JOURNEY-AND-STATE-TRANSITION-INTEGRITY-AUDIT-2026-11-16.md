# KRIM End-to-End Business Journey and State-Transition Integrity Audit
**Date:** 16 November 2026  
**Method:** Read-only review of live PostgreSQL RPC definitions and transition configuration, cross-checked against prior customer/partner, shipment, warehouse, customs and workspace audits. No RPCs were executed and no production records were created or changed.

## Executive decision
**NO-GO for real shipment execution or commercial launch.** The customer-to-partner quote path has meaningful transaction locks and partner eligibility checks, but several stages remain intentionally separate and cannot be treated as a single completed booking. Shipment transition configuration blocks some direct transitions, yet milestone sequencing, compliance fail-open behavior, warehouse reservation protection and official customs clearance remain material gates. Finance remains deferred.

## 1. Customer enquiry -> qualification -> quote
Positive controls:
- Public inquiry RPC validates and bounds fields, applies email-scoped throttling/advisory locking, and transactionally creates inquiry, acquisition profile/event, qualification case and founder outbox record.
- Customer quote orchestration requires verified customer identity and active customer workspace, locks the service request, and checks ownership/qualification.
- Customer global quote acceptance locks quote and shipment; checks customer organization access and shipment.update permission; validates the linked partner quote, matching shipment/amount/currency, accepted partner assignment, active verified/compliant partner and current route/mode/weight capability.
- Quote expiry is checked before acceptance.

Gaps:
- Public privacy acknowledgement is currently recorded as consent without a separate explicit notice acknowledgement input; this is not marketing or channel consent.
- Lead conversion from anonymous acquisition profile to customer organization requires a controlled, auditable founder/admin path; it is not completed by public enquiry itself.
- Quote orchestration retry/duplicate behavior needs staging proof.
- A partner award first creates an assignment in `offered` status. It does not mean the partner has accepted custody or dispatch. The customer quote acceptance RPC requires a matching accepted partner assignment before it can confirm the shipment. This two-party sequence must remain explicit in UI and API semantics.
- Signed customer/partner commercial contract and executed fee/insurance/SLA terms remain unverified.

## 2. Partner award and customer acceptance
Live definition of `krim_award_partner_quote` confirms:
- Requires authenticated user and customer-organization access.
- Requires quote.update and shipment.update on the customer organization.
- Blocks development/test partner organizations from commercial awards.
- Checks opportunity/quote state and expiry, registered-business mode, active organization, current verification/compliance, active verified capability and shipment coverage.
- Locks quote, opportunity and shipment; rejects active multi-leg shipment-wide awards until leg-specific sourcing is supported.
- Accepts the selected partner quote, rejects competing submitted/under-review/shortlisted quotes, marks opportunity awarded and creates a partner assignment as `offered`.
- Writes an audit event.

Assessment: good eligibility and transaction controls, but an offered assignment is not an accepted assignment. The partner acceptance stage and customer quote acceptance must both be tested under retries and competing offers. A complete signed service contract is still not proven.

## 3. Shipment status state machine
Live `krim_transition_shipment` locks the shipment, reads current status, consults `krim_shipment_status_transitions`, checks the configured permission when non-null, enforces reason where configured, then updates shipment, status history and audit records.

Current transition table includes allowed paths:
- draft -> quoted (`quote.create`)
- draft/quoted/confirmed/assigned/dispatched -> cancelled (`shipment.cancel`)
- confirmed -> assigned (`shipment.assign`)
- quoted -> confirmed (`shipment.update`)
- dispatched/in_transit -> exception (`shipment.update`, reason required)
- delivered -> closed (`shipment.update`)
- delivered -> exception (`shipment.update`, reason required)

Direct transitions marked not allowed include:
- assigned -> dispatched
- dispatched -> in_transit
- in_transit -> delivered

These disabled paths help prevent a generic status RPC from bypassing the more specific dispatch, transit and POD workflows.

Assurance gaps:
- The transition RPC is a generic SECURITY DEFINER function and does not itself prove every business prerequisite for every transition. The specific assignment, dispatch authorization, capacity, warehouse handover, POD and customs workflows must remain the only valid entry points for their respective operational stages.
- The permission organization falls back to platform organization ID 1 when shipment.customer_organization_id is NULL. Verify schema constraints make that null case impossible for every executable shipment; otherwise do not allow fallback to a generic platform scope.
- No AAL2 requirement is visible in this generic transition body. High-impact transitions must be gated by the dedicated workflow or an explicit risk-tiered approval check.
- Confirm that direct authenticated EXECUTE grants and every caller are constrained; do not treat function body inspection alone as proof of all invocation paths.

## 4. Compliance gate — P0
Live `krim_internal_evaluate_shipment_compliance_gate` counts blocked, review and expired checks. If all three counts are zero, it writes status `clear`.

This includes the case where there are **zero configured compliance checks** for the shipment. Therefore, absence of configured controls can be represented as clear. The earlier production baseline also found readiness-gate rows marked ready while no configured compliance rules/checks were present.

Required design:
- Require an applicable, approved set of controls for shipment country, corridor, mode, commodity and service before evaluation.
- If no applicable controls exist, return `review_required` or `blocked`, never `clear`.
- Persist which control-set version was evaluated and prove all mandatory checks were completed and current.
- Test missing rules, missing checks, waived checks, expired evidence, newly applicable rules and concurrent changes in staging.

No production function was changed.

## 5. Operational milestones and delivery
Live milestone routine:
- Requires authenticated user.
- Locks shipment and selects a single active partner assignment available to the actor.
- Driver actor must own the matching active driver assignment; partner actor must hold shipment.update or shipment.dispatch.
- Validates event type, notes and coordinate ranges.
- Blocks most events on terminal shipments and explicitly blocks direct `delivered` event pending verified POD/delivery authorization.
- Inserts milestone and tracking event together.

Gap: it does not enforce predecessor order between `pickup_arrived`, `pickup_completed`, `departed_origin`, `in_transit`, `arrived_checkpoint` and `delivery_arrived`. Duplicate suppression is only a 60-second same-event check, not durable request idempotency. This can produce impossible event histories or allow later replay.

Required design: finite-state transition table per mode/leg, actor-class permissions, durable idempotency key plus payload fingerprint, and exact-leg scope. GPS coordinates supplied manually must not be represented as verified GPS.

## 6. Warehouse, customs and POD handoffs
Previously established P1/P0 findings remain release blockers:
- Warehouse transfer dispatch does not subtract outstanding shipment reservations before reducing stock.
- Generic non-shipment-linked picking task may consume stock through a shared negative movement path without visible reserved-quantity protection.
- Return receipt validation lacks an explicit SQL NULL input guard.
- Customs case transition path has no inspected callable authority-evidence workflow to reach `cleared`; internal broker/document review is not government clearance.
- Compliance evaluator can mark no-check shipments clear (P0 above).
- POD requires private driver-owned evidence and independent AAL2 review, but complete staging proof of delivery authorization and customer access is outstanding.

These stages must be linked with immutable handover references: shipment leg -> accepted assignment -> reserved capacity -> warehouse pick -> dispatch handover -> authorized dispatch -> custody events -> customs authority evidence where applicable -> ordered milestones -> POD review -> delivery closure.

## 7. Market, partner and legal prerequisites
The previous live baseline remains unchanged:
- Six market catalogue entries exist but operational status is blocked.
- 249 country operating packs are research_pending.
- Seven corridor candidates are draft, with no approved corridor dossiers or controls.
- No verified operational partner capability, confirmed capacity, accepted assignment or executed service contract was established.
- Therefore catalogue rows and route metadata do not establish authority to serve a route.

India domestic pilot must wait for approved India operating pack/corridor evidence, partner contract and verified capability/capacity, staging tests and CA/legal confirmation. Cross-border operation remains blocked.

## 8. Required staging acceptance suite (not executed)
1. Public inquiry -> lead review -> customer-org conversion; distinguish privacy acknowledgement from marketing consent.
2. Customer service request -> qualification -> quote orchestration; test duplicate and concurrent requests.
3. Partner quote -> independent eligibility recheck -> award -> offered assignment -> partner acceptance -> customer quote acceptance; test expiry and competing awards.
4. Verify each shipment status transition against configured permission, actor, AAL2 and prerequisite evidence; attempt direct RPC bypasses in staging.
5. Compliance evaluation with zero rules, zero checks, expired checks, waived checks and missing mandatory checks must never return clear.
6. Dispatch must require current exact-leg assignment, committed capacity, partner compliance/capability, route/corridor controls and completed warehouse handover.
7. Milestone out-of-order, duplicate, replay, wrong-leg and wrong-actor requests must be rejected.
8. Warehouse concurrent transfer/reservation/pick must preserve reserved quantities.
9. Customs cannot reach cleared without independent authority release reference, issuer, jurisdiction, evidence, verifier and validity/revocation controls.
10. POD upload, independent review, delivery authorization and customer visibility must be tested with wrong-tenant and revoked-session actors.
11. Every critical state change must atomically persist audit evidence.
12. All tests use isolated staging identities/data; do not invoke production business functions as tests.

## Release decision
**NO-GO for unrestricted production shipment execution, customs clearance claims, cross-border operation or financial collection.** Finance remains the final phase by instruction. No live shipment, quote, partner award, assignment, inventory, customs, POD, payment or notification operation was performed during this audit.

## Change boundary
Read-only live database definition/configuration inspection and source-report review only. No production DDL/DML, function deployment, RPC invocation, partner/customer contact, provider request or financial transaction occurred.
