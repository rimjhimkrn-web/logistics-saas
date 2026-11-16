# KRIM Partner-to-Shipment Matching, Quote & Assignment Readiness Audit

**Date:** 16 November 2026  
**Status:** read-only production audit and design specification. No production rows, schema, grants, policies, functions or partner statuses were changed.

## 1. Release decision

**Automated matching and assignment are not approved for live operational use.** The database contains substantial matching, opportunity, quote, capacity and assignment infrastructure, but the live dataset has no verified service-area records, no match runs/results, no partner quotes, no assignments and no capacity commitments. The one capability record is not proof that a partner is eligible.

KRIM must not tell a customer that a partner is available, quote a confirmed rate, or dispatch a shipment unless the specific partner, service, route, operating window, contract and capacity have all been validated.

## 2. Live production snapshot

| Table | Rows |
|---|---:|
| `krim_shipments` | 18 |
| `krim_shipment_legs` | 1 |
| `krim_partner_capabilities` | 1 |
| `krim_partner_service_areas` | 0 |
| `krim_partner_capacity_availability` | 0 |
| `krim_partner_capacity_commitments` | 0 |
| `krim_partner_match_runs` | 0 |
| `krim_partner_match_results` | 0 |
| `krim_partner_quotes` | 0 |
| `krim_quote_acceptances` | 0 |
| `krim_shipment_partner_assignments` | 0 |
| `krim_partner_assignment_activations` | 0 |
| `krim_partner_assignment_activation_events` | 0 |
| `krim_partner_shipment_capacity_commitments` | 0 |

These are database counts at audit time, not evidence that the system has been exercised end-to-end.

## 3. Existing safeguards observed

### Matching engine
The internal matching routine `krim_internal_create_partner_matching_run` is SECURITY DEFINER and its execute ACL is limited to the service role and database owner. It checks shipment/customer organisation consistency, active locations, active transport mode and positive cargo weight. Its candidate query requires:

- an active partner capability for the requested transport mode and service type;
- capability verification status `verified`, active state and effective dates;
- sufficient declared maximum weight;
- partner lifecycle `active`, verification `verified` and compliance status `compliant`;
- coverage at both endpoints or a matching active route/corridor record.

The location-coverage helper is also SECURITY DEFINER with service-role-only execution. It checks active, effective service areas or active verified capability coverage.

### Capacity registration and reservation
The inspected capacity registration routine checks active organisation membership, `partner.manage`, partner organisation type, current compliance, a verified capability for the selected mode/country, active location/mode, future availability dates and organisation/user-scoped document paths.

The shipment-leg reservation routine checks partner membership and permission, accepted/active assignment status, current compliance, shipment/leg/partner consistency, verified capability coverage, future departure/arrival and idempotency key format. This is a useful control foundation, but it is not proof that every assignment-creation path is equally protected.

### Tenant access
RLS is enabled on match runs/results, assignment activations, quotes, assignments and partner-shipment capacity commitments. The inspected match/assignment policies scope access to the shipment's customer organisation and/or the relevant partner organisation. The capacity-commitment table had RLS enabled but no policy was present in the inspected policy list; this may intentionally deny ordinary authenticated access, but its service-role workflow and intended user access must be documented before rollout.

## 4. Material gaps and risks

1. **Compliance freshness is not explicit in the matching candidate predicate.** The matcher checks the organisation's persisted `partner_compliance_status='compliant'`; unlike capacity registration and reservation, the inspected candidate predicate does not call `krim_partner_compliance_is_current()`. A stale status could therefore remain eligible if evidence expires or a suspension is not synchronously propagated. Add a current-evidence predicate and explicit suspension/expiry exclusion before enabling matching.
2. **A capability row is not a service-area or live-capacity confirmation.** No service-area or availability records exist. Matching eligibility is not the same as a current operational commitment.
3. **Declared maximum weight is only one constraint.** Matching must also validate cargo dimensions/volume, equipment/body type, handling, temperature, hazardous/restricted-goods permissions, route restrictions, timing, insurance limits and any mode-specific legal prerequisites.
4. **The matcher currently produces eligible candidates, not guaranteed capacity.** Results must be labelled “potentially eligible — partner confirmation required”, not “available” or “booked”.
5. **Opportunity creation and matching are separate.** The customer-facing opportunity routines validate shipment access and sourcing state, while the internal matching routine generates candidate rows. Their invocation order, retries, deadlines and customer-visible state need one tested orchestration contract.
6. **Assignment activation has no live test evidence.** Activation and event tables are empty. The complete activation function chain, maker/checker controls, idempotency, partner acceptance, customer consent and event immutability must be reviewed in staging.
7. **Quote acceptance is not yet evidenced.** No quote or quote acceptance exists. Quote validity, version locking, tax/fee disclosure, partner identity, currency, customer consent, withdrawal/expiry races and contract linkage need end-to-end tests.
8. **RLS is enabled but not forced on several workflow tables.** SECURITY DEFINER and service-role paths need explicit tenant-boundary tests. No client-side role, editable metadata, applicant checklist or partner-supplied status may be treated as a privileged approval.
9. **No actual partner outcome data exists.** Do not publish reliability rankings or performance scores until based on independently verified completed shipments, with fair denominators and dispute handling.
10. **No production readiness can be inferred from successful static CI checks.** CI currently validates repository checks and Pages deployment, not live partner verification, quote acceptance, capacity reservation or dispatch.

## 5. Canonical eligibility contract

A partner may enter a customer-facing candidate list only if all of the following are true at evaluation time:

1. Legal organisation identity and beneficial/authorised signatory checks are complete for the applicable jurisdiction.
2. Independent verification and compliance review are approved, current and not suspended.
3. Every required licence, registration, insurance and safety evidence item is authentic, in date and scoped to the service being offered.
4. Partner agreement is signed, active, versioned and covers the requested service, fee model, geography, liability and data processing.
5. Requested mode/service and cargo class are within an independently approved capability record.
6. Origin, destination and route are covered by current verified service-area evidence.
7. Capacity is current for the requested equipment, quantity, weight/volume and operating window; a live hold/commitment is required before “reserved” is shown.
8. Partner has affirmatively accepted the specific opportunity/quote and the customer has accepted the exact quote version and applicable terms.
9. Assignment activation succeeds atomically, with an immutable event, idempotency key, authorised actor and all required approvals.
10. No legal, safety, sanctions, fraud, insurance, suspension, incident or operational hold blocks the transaction.

A match score may rank only candidates that pass every hard gate. A high score must never compensate for a failed compliance, coverage, contract or capacity requirement.

## 6. Required customer and partner states

Use distinct, unambiguous states:

- `not_sourced`
- `sourcing_pending`
- `no_verified_partner`
- `potential_matches_found`
- `partner_invited`
- `partner_responded`
- `quote_received`
- `quote_expired` / `quote_withdrawn`
- `customer_acceptance_pending`
- `customer_accepted`
- `assignment_pending_activation`
- `assignment_active`
- `capacity_hold_pending`
- `capacity_reserved`
- `dispatch_ready`
- `suspended` / `cancelled` / `failed`

Do not collapse “candidate”, “invited”, “quoted”, “accepted”, “assigned”, “capacity reserved” and “dispatched” into one status.

## 7. Required staging acceptance tests

1. Unverified, pending, suspended, expired or non-compliant partner is excluded.
2. Expired evidence excludes partner immediately, even if the organisation status still says compliant.
3. Missing, inactive or mismatched capability is excluded.
4. Wrong transport mode, service type, country, region, route or weight is excluded.
5. Restricted/hazardous cargo is excluded without the exact current approval and equipment.
6. A service-area declaration without independent review is not treated as verified.
7. A stale capacity record or expired availability window cannot be reserved.
8. Two concurrent requests cannot reserve the same finite capacity.
9. Repeated matching and opportunity creation are idempotent and do not duplicate active invitations.
10. Customer A cannot read or alter Customer B's shipment, match run, quote or assignment.
11. Partner A cannot read Partner B's commercial quote or assignment.
12. Customer cannot modify partner verification, capacity evidence or reviewer decisions.
13. Partner cannot self-approve its compliance, quote acceptance or activation.
14. Quote amount, currency, validity, scope and version are immutable after customer acceptance.
15. Expired/withdrawn quote cannot be accepted, including under concurrent requests.
16. Partner acceptance alone does not activate an assignment.
17. Customer acceptance alone does not activate an assignment.
18. Activation requires the required partner, customer, capacity, contract and reviewer gates.
19. Duplicate retries create one assignment, one capacity hold and one event chain.
20. Cancellation, rejection, timeout and failed activation release holds exactly once.
21. Every state transition records actor, organisation, timestamp, reason and correlation/idempotency ID.
22. Customer-visible copy never claims a confirmed carrier, rate, ETA or availability before the corresponding evidence exists.
23. No matching path can bypass the compliance-freshness predicate.
24. All SECURITY DEFINER routines use fixed safe search paths, explicit authorisation, tenant binding and minimal execute grants.

## 8. Implementation sequence

1. Recover and reconcile the production migration source and schema backup; do not patch production while migration lineage remains unresolved.
2. Reconstruct a staging environment and run the complete partner verification, matching, quote, capacity and assignment test matrix.
3. Add a canonical shared eligibility function that enforces current compliance, contract, capability, service-area and suspension gates.
4. Make every matching path use that function; separate hard eligibility from ranking.
5. Implement explicit customer/partner invitation and response states, versioned quote acceptance and immutable event history.
6. Add capacity holds with concurrency-safe reservation, expiry and exact-once release.
7. Implement assignment activation as an atomic, idempotent, dual-control operation.
8. Validate RLS, SECURITY DEFINER grants and all service-role paths with multi-tenant negative tests.
9. Run a controlled pilot only after at least one real partner has passed verification, signed the agreement and supplied current service/capacity evidence.
10. Enable wider matching only after operational, legal, safety and support readiness is demonstrated.

## 9. Commercial and operational boundaries

The initial KRIM model remains partner-direct: the customer contracts with and pays the logistics provider directly; KRIM earns only a separately agreed and properly documented referral/coordination fee for services actually provided. Do not collect or hold freight funds, promise partner settlement, or treat shipment gross value as KRIM revenue. Tax treatment and registration obligations require qualified Indian professional review before commercial launch.

No prospect outreach, partner invitation, contract acceptance, booking, dispatch, payout or live activation is authorised by this audit.

## 10. Audit limitations

This review inspected selected live table counts, function definitions/ACLs and RLS policy expressions. It is not a complete source-code review of all Edge Functions, frontend clients, scheduled workers, external integrations or every function capable of creating or changing assignments. Those paths must be traced before production enablement.

**Final status: design and database foundations exist, but verified partner supply and operational evidence are absent. Keep automated matching, booking and dispatch gated.**
