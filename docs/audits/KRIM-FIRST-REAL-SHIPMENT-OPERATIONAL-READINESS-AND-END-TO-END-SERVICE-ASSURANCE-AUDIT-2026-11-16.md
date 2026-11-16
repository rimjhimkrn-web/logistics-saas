# KRIM First Real Shipment Operational Readiness and End-to-End Service Assurance Audit — 2026-11-16

## Executive decision

**NO-GO: KRIM is not ready to accept, book, dispatch or promise completion of a real customer shipment.** The application has many of the required workflow components, but the operating network and physical execution chain are not populated or independently evidenced. The live production snapshot has ten legacy partner records but zero partner-submitted quotes, zero service areas, zero capacity resources/reservations, zero accepted assignments, zero driver assignments, zero dispatch authorizations, zero warehouse inventory, zero customs cases and zero POD records.

The one route row and one capability row do not establish a feasible, approved or executable service. Earlier audits identify critical backend gate defects that must be remediated only after migration reconciliation and an authorized change plan.

This report is a read-only cross-journey assurance assessment. No customer/partner was contacted, no quote or shipment was created, no assignment/capacity was reserved, no dispatch or physical movement was initiated, no customs filing was made, and no production data or schema was changed.

## 1. Fresh live production snapshot

Read-only counts queried from the production project on 16 November 2026:

| Operational object | Rows | Meaning |
|---|---:|---|
| Legacy partners (`partners`) | 10 | Records exist; not proof of current verified supply |
| Partner capabilities | 1 | Earlier audit: inactive and pending review |
| Approved partner service areas | 0 | No approved geographic service coverage |
| Partner opportunities | 3 | Earlier audit: all closed (cancelled/expired) |
| Partner-submitted quotes | 0 | No supplier offer to book |
| Shipment partner assignments | 0 | No accepted partner execution owner |
| Capacity resources | 0 | No registered/verified capacity resources |
| Capacity reservations | 0 | No shipment capacity reserved |
| Shipment routes | 1 | Does not prove a feasible approved route |
| Dispatch authorizations | 0 | No dispatch-ready shipment |
| Driver assignments | 0 | No assigned and verified driver |
| Warehouse inventory | 0 | No stock or fulfilment evidence |
| Customs cases | 0 | No customs case workflow evidence |
| POD records | 0 | No delivery completion evidence |

Additional prior audited baseline:
- 6 market catalogue rows, but operational status blocked.
- 249 country operating packs remain `research_pending`.
- 7 corridor candidates are draft; zero approved corridor dossiers/controls.
- 14 organizations, 13 active memberships; no organization relationship records.
- 18 shipments in the live database (8 draft, 3 quoted, 6 confirmed, 1 closed); 17/18 have requested transport mode NULL.
- 7 customer quote records, all expired and unlinked to a partner quote; zero partner-submitted quotes and zero accepted assignments.
- 0 active route plans/plan items/activations, 0 custody transfers, 0 GPS sessions, 0 verified vehicles and 0 POD evidence objects.

These are counts, not proof that a particular customer request can be served. Do not convert catalogue, test, legacy or draft rows into public availability claims.

## 2. Stage-by-stage real shipment gate

### Gate A — Customer request and scope (BLOCKED)
Required:
- customer identity and authorized organization membership;
- accurate origin, destination, cargo description, dimensions/weight, handling and regulatory classification;
- requested transport mode and service tier mapped to a canonical physical mode;
- shipment mode persisted in the authoritative shipment-create operation;
- market/corridor readiness checked server-side;
- idempotent create/recovery for shipment and partner opportunity.

Critical prior finding: the customer form collects service tier but does not pass requested transport mode into `krim_create_global_shipment`; it passes tier only to the separate partner-opportunity RPC, which requires a non-null requested mode. This can leave a shipment row without a matching opportunity. The live 17/18 NULL mode count is consistent with this defect. Correct only after schema/migration reconciliation and an approved implementation plan.

### Gate B — Market, route and legal feasibility (BLOCKED)
Required:
- operationally approved origin/transit/destination markets;
- approved corridor dossier and current jurisdiction controls;
- route options based on actual transport providers, transit time, restrictions, border crossings and physical feasibility;
- cargo-specific regulatory, sanctions/export-control, customs and dangerous-goods checks;
- evidence-backed route plan and independent activation where required.

Critical prior findings:
- all country operating packs remain research_pending and corridor dossiers/controls are absent;
- route-plan activation RPC is callable to authenticated users despite a disabled UI path; server-side market/corridor enforcement was not visible in the reviewed evaluator/activation definitions;
- a single-leg dispatch guard requires an active route plan with total_legs > 1, conflicting with the exact-leg dispatch interface. Do not attempt a real single-leg dispatch.

A route segment or route row is not a bookable route and does not establish partner service.

### Gate C — Partner admission and commercial offer (BLOCKED)
Required:
- legal entity identity and independently verified organization;
- active registered-business eligibility and current compliance;
- independently approved capability for exact mode/cargo/service;
- approved origin/destination service areas and corridor eligibility;
- executed service contract/data-sharing terms and clear liability/insurance;
- current capacity and an actual scoped quote;
- quote currency, inclusions/exclusions, validity, surcharge/tax/demurrage/claims terms;
- customer acceptance linked to exact partner quote and partner acceptance of assignment.

Current state: no approved capability/service area, no partner quote, no match results, no capacity and no accepted assignment. No public claim of partner coverage or quote availability is justified.

### Gate D — Capacity, assignment and booking (BLOCKED)
Required:
- capacity resource tied to the correct partner, mode, route, date, equipment and shipment constraints;
- atomic capacity reservation with lock and idempotency;
- customer award and partner acceptance as distinct transitions;
- exact shipment/leg/partner/capacity binding;
- cancellation/expiry/release logic and conflict reconciliation.

Existing RPC controls include exact-leg capacity checks and row locking, but production has zero capacity resources/reservations and zero accepted assignments. A quote acceptance is not proof that the partner has accepted the assignment or that capacity is reserved.

### Gate E — Dispatch and driver/vehicle (BLOCKED)
Required:
- accepted partner assignment and active exact-leg capacity binding;
- current partner compliance/capability and corridor approval rechecked at dispatch;
- driver identity and licence verification, vehicle registration/fitness/insurance/permit checks as applicable;
- driver-to-partner and vehicle-to-assignment binding;
- load payload, handling/equipment compatibility and route instructions;
- dispatch authorization plus separate departure/custody event;
- signed pickup evidence and timestamped milestone sequence.

Current production: zero driver assignments, zero dispatch authorizations, zero verified vehicles/bindings and GPS sessions. Dispatch authorization is not physical departure. Manual coordinates are not verified GPS. Milestone predecessor ordering and durable idempotency need remediation/testing.

### Gate F — Warehouse and custody (BLOCKED)
Required:
- approved facility, verified operator, physical stock or receipt, lot/unit/quality/location tracking;
- shipment allocation under available-to-promise invariant;
- picking, packing, scan/weight/seal evidence and handover to authorized carrier;
- independent quality inspection where needed;
- exact-leg custody acceptance for every multimodal transfer.

Current production: all operational warehouse tables and custody records are empty. Known P1 defects:
1. inter-facility transfer dispatch does not subtract active shipment reservations before consuming stock;
2. generic non-shipment picking may consume reserved stock;
3. return receipt RPC does not explicitly reject SQL NULL payload;
4. movement idempotency replay comparison omits some business fields.

Do not use live inventory or a shipment to test these defects.

### Gate G — Customs and regulatory release (BLOCKED)
Required:
- exact jurisdiction, commodity classification, required documents and current rules;
- licensed broker for the jurisdiction, accepted assignment and current licence;
- validated declarations and documents, independent review;
- actual authority-issued receipt/release evidence, independently verified and linked to shipment/case;
- holds, inspections and duty/tax obligations resolved.

Current production: zero customs cases, broker assignments, document submissions or authority-release evidence. P0 compliance evaluator defect: zero configured checks can result in a `clear` status. Internal broker/document review is not government clearance. No cross-border shipment may proceed on this basis.

### Gate H — Delivery, POD and exception closure (BLOCKED)
Required:
- final-mile partner/driver assignment and consignee contact controls;
- delivery attempt and exception flow;
- recipient identity/authority validation appropriate to the service;
- private POD evidence, independent reviewer and customer-authorized visibility;
- ordered milestone history, durable idempotency and customer notification;
- claims/incident handling and final custody reconciliation.

Current production: zero POD records/evidence, zero driver assignments and zero operational exception/claim records. POD upload/metadata/RPC atomicity and reviewer independence remain to be proven. A shipment status of delivered alone must not substitute for verified POD.

## 3. Critical cross-system defects to resolve before any real shipment

| Priority | Finding | Required outcome |
|---|---|---|
| P0 | Compliance evaluator can mark clear with zero checks | Fail closed when rule set is missing/incomplete; prove every applicable control |
| P0 | Market/corridor approval not enforced consistently in route activation | Activation and downstream booking/dispatch require approved market pack and corridor controls |
| P0 | Customer shipment mode omitted from authoritative create RPC; opportunity may fail separately | Canonical mode mapping and atomic/idempotent shipment+opportunity lifecycle |
| P0 | Single-leg dispatch guard conflicts with exact-leg dispatch model | Resolve dispatch model and test single-/multi-leg safely in staging |
| P0 | Migration history does not reconcile (558 production rows vs 363 repo SQL files; mismatched names/timestamps) | Complete sanitized schema manifest and migration crosswalk before any DDL/migration repair |
| P1 | Transfer can consume reserved warehouse stock | One ATP invariant for every stock-decreasing path |
| P1 | Milestone ordering/idempotency incomplete | Strict predecessor checks and durable event keys |
| P1 | Customs official clearance evidence workflow absent | Separate authority-issued evidence and independent verification |
| P1 | POD storage/metadata/write not proven atomic | Atomic or recoverable evidence workflow with uploader/record ownership |
| P1 | Customer quote list includes unlinked/expired generic quotes | Only show exact current partner quote/eligibility and linked accepted assignment state |
| P1 | Partner/assignment visibility helper does not revalidate all current compliance/capability branches | Recheck current authorization and eligibility on every sensitive read/action |
| P1 | Customer request and opportunity creation are separate calls | Recovery/reconciliation path prevents orphan requests |

No production patch is authorized by this audit. Resolve the migration reconciliation blocker and prepare reviewed changes with rollback and staging tests first.

## 4. Minimum first-shipment acceptance test (staging only)

Use synthetic customer, partner, carrier, driver, vehicle, warehouse and shipment records in an isolated staging environment. Do not use a production business function as a test.

1. Create a synthetic customer organization and prove tenant isolation.
2. Submit a shipment request with origin/destination/mode/cargo; verify exact values persisted and duplicate retries return the same record.
3. Prove unapproved markets/corridors and missing compliance rules fail closed.
4. Submit a synthetic partner application; independently verify legal entity, compliance, capability and service area.
5. Create a partner quote scoped to the exact shipment/leg; test expiry, currency, amount, conflicting retry and cross-tenant access.
6. Award the quote; require separate partner acceptance.
7. Reserve exact capacity; test concurrent oversubscription, expiry and cancellation.
8. Verify driver, licence, vehicle, equipment and insurance; bind them to exact assignment/leg.
9. Activate a feasible route plan; test single-leg and multi-leg behavior.
10. Authorize dispatch; prove no departure/custody is inferred until a distinct signed handover event.
11. For warehouse handling, receive, inspect, reserve, pick and hand over; prove transfer/picking cannot consume reserved stock.
12. For customs, verify broker licence and documents; prove internal verification cannot set official cleared without authority evidence.
13. Track ordered milestones and consented location; test token revocation and tenant privacy.
14. Upload POD to private storage; verify ownership, independent review, authorized customer retrieval and short-lived access.
15. Resolve an exception, reconcile custody and confirm final shipment closure.
16. Verify event/audit records, duplicate suppression, retry recovery and notification semantics at every boundary.

Acceptance requires positive tests, negative/adversarial tests, concurrency tests, rollback tests and evidence from logs/records. Static page checks or green CI are not substitutes.

## 5. Safe initial operating scope recommendation

KRIM should not begin by advertising global live freight coverage. The safe next operational milestone is a tightly scoped, manually supervised domestic pilot only after:
- one actual registered logistics partner has passed independent verification and contract review;
- one specific domestic route and service scope has been physically/legally validated;
- current market/corridor and cargo controls are approved;
- the partner supplies written capacity, quote and insurance evidence;
- a named operations owner and manual escalation path are available;
- the full synthetic staging journey above passes;
- the customer contract clearly identifies the carrier as service provider and the direct freight payment route;
- KRIM does not receive, hold, split, escrow or settle partner freight funds;
- a qualified CA/legal adviser confirms KRIM's separate fee and tax treatment.

Do not publish a guaranteed ETA, price, coverage area or customs capability before that specific service is verified. The initial pilot should be one route/service at a time, not a claim of pan-India or global operational readiness.

## Release decision

**NO-GO for accepting or executing a real shipment today.** The first shipment is blocked by absent verified supply, no approved route/corridor, no capacity/assignment/driver, no warehouse/customs/POD evidence, and unresolved P0 integrity defects. KRIM can continue controlled partner acquisition and staging remediation, but it must not represent the platform as ready to move freight.

No production state, shipment, quote, assignment, capacity, dispatch, warehouse stock, customs record, POD, payment or customer communication was created or changed.
