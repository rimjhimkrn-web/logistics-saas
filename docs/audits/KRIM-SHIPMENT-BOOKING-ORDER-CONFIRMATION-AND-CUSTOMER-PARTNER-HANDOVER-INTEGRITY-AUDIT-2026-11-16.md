# KRIM Shipment Booking, Order Confirmation and Customer–Partner Handover Integrity Audit
**Date:** 16 November 2026  
**Scope:** Read-only review of customer quote/booking pages, partner quote submission and assignment acceptance UI, operations handover entry point, live shipment/quote/assignment/capacity/dispatch/contract record counts, and selected production booking RPC definitions. No quote was accepted, no assignment responded to, no capacity reserved, no shipment created, no dispatch authorized, no payment attempted, and no production data or schema changed.

## Executive decision
**NO-GO for live shipment booking or dispatch readiness certification.** KRIM has a multi-stage commercial award and booking design: partner bid, customer award, partner assignment acceptance, customer quote acceptance, then assignment finalization. This is materially safer than treating a quote or partner award as a confirmed booking. However, there are no live partner quotes, assignments, capacity bindings, service contracts or dispatch authorizations at the audit snapshot. The customer-facing booking confirmation must not be interpreted as proof of a complete legal contract, capacity reservation, payment or dispatch. Several important dependencies still require staging validation.

## 1. Production baseline
Read-only live counts at the audit snapshot:

| Record | Count |
|---|---:|
| Shipments | 18 |
| Customer quotes | 7 |
| Partner opportunities | 3 |
| Partner quotes | 0 |
| Shipment–partner assignments | 0 |
| Shipment legs | 1 |
| Capacity bindings/reservations | No confirmed records evidenced in the reviewed snapshot |
| Dispatch authorizations | 0 |
| Service contracts | 0 |
| Quote acceptance records | 0 |
| Invoices | 0 |

These counts show seeded or historical shipment/quote state, not a functioning live booking network. The partner network audit separately found no verified service coverage/capacity population. No actual customer-to-partner handover was evidenced.

## 2. Customer booking and quote acceptance
### Positive controls
- Customer quote acceptance is a server-side SECURITY DEFINER routine with an empty search path and explicit auth.uid() requirement through organization-access and permission checks.
- It locks the quote and shipment rows before state changes.
- It only accepts a quote in sent state, checks validity, and requires the shipment to be in quoted state.
- Before confirming the shipment, it requires a matching accepted partner quote and accepted partner assignment for the exact shipment, same amount/currency, active and verified partner organization, acceptable compliance state, current active verified capability and capability coverage for the shipment.
- It transitions the shipment to confirmed only after these checks, then finalizes the matching accepted partner assignment. The function has an idempotent path for already accepted quotes, but requires the matching accepted assignment and an eligible shipment state.
- Customer-facing quote acceptance text distinguishes quote acceptance from carrier assignment, final booking, payment and delivery. Booking confirmation copy describes the backend state rather than claiming dispatch.

### Findings
1. **P1 — Contract prerequisite not visibly enforced in booking RPC:** the reviewed krim_accept_global_quote definition does not visibly require an executed customer–partner service contract or shipment work order. The quote/assignment may be intended to form the contract, but the legal design has not been finalized and there are no acceptance records. Decide and document whether a quote/work order is the contract; if not, add a contract gate after migration reconciliation.
2. **P1 — Quote acceptance audit record chain:** krim_quote_acceptances exists but has zero rows. The reviewed acceptance function updates quote state and transitions shipment; it does not visibly insert a row into krim_quote_acceptances. A trigger/private helper may record this elsewhere; inspect the complete trigger chain and prove exact quote version, terms version, actor authority, timestamp and acceptance evidence are persisted. Do not infer acceptance evidence from the quote status alone.
3. **P1 — Pricing/tax disclosure:** quote preparation snapshots explicitly say tax is not separately calculated and production tax invoice is not ready. A quote total must not be described as tax-final or an invoice. The customer must see the applicable inclusions/exclusions, tax status, validity and direct-provider payment responsibility before accepting.
4. **P1 — Multi-leg booking limitation:** customer quote preparation deliberately blocks shipment-wide award when an active multi-leg plan has more than one leg. This is a safe hold, not a completed multi-leg booking workflow. Do not accept a whole-shipment price until leg-specific sourcing, custody, liability and price aggregation are implemented.
5. **P1 — Retry and concurrency:** row locks and existing-quote checks are positive, but concurrent partner awards, customer acceptance retries, rejected assignments, quote expiry races and stale versions require staging tests. The idempotent path must not finalize an assignment under a different or superseded quote version.
6. **P2 — Booking confirmation UI:** static page content is not proof of backend state. The page must show separately: quote accepted, partner assignment accepted, assignment finalized, capacity reserved, contract effective, payment responsibility, dispatch authorized. Unknown/failed data must display as unknown/partial, not as completed.

## 3. Partner bid, award and assignment handover
### Positive controls
- Partner quote submission checks active authenticated partner membership, registered-business mode, partner lifecycle/verification/compliance, approved capability, quote.create, open opportunity, response deadline, positive amount, active currency and quote validity. The UI warns that a submitted bid is not a customer award or accepted assignment.
- Customer award routine checks the customer organization's access and both quote.update and shipment.update, locks the opportunity and partner quote, validates open deadline and submitted/shortlisted partner quote, validates shipment/customer organization match and shipment state, and prevents conflicting active customer quotes.
- Awarding creates an offered partner assignment, not an accepted assignment. Partner acceptance remains a separate action.
- Partner assignment register explicitly distinguishes commercial award from partner assignment acceptance and dispatch/transit. It says assignment acceptance does not prove customer payment, delivery or settlement.
- Partner assignment acceptance and decline are separate recorded actions; decline requires a reason.
- Capacity reservation is a separate action after assignment acceptance. The UI reports a reservation only when the backend returns a confirmed reservation and binding.
- Dispatch authorization is a separate later gate. Assignment acceptance and capacity reservation do not themselves dispatch a shipment.

### Findings
1. **P1 — No actual handover population:** no partner quotes or assignments exist in the live database snapshot. The workflow has not been proven with real counterparties.
2. **P1 — Handover packet completeness:** before an assignment is accepted, partner and customer should receive the same immutable shipment work order: exact origin/destination, commodity, weight/dimensions, handling and safety requirements, pickup/delivery windows, accessorials, agreed amount/currency, tax status, cancellation terms, documents, custody boundaries, service-level commitments and escalation contacts. The inspected partner job page shows useful shipment context, but a single signed/accepted handover packet is not evidenced.
3. **P1 — Capacity remains a separate commitment:** partner assignment acceptance without a confirmed exact-leg capacity reservation is not proof of available vehicle, warehouse slot or equipment. The UI correctly separates it; backend and customer status must preserve the distinction.
4. **P1 — Customer notification/acknowledgement:** no live quote acceptance or assignment rows and no notification delivery records were present in prior CRM audit. Do not claim that customer/partner notification or receipt has occurred merely because the database state changed.
5. **P1 — Multi-party role clarity:** identify who owns pickup readiness, cargo custody, loading, transit, border/customs handling, delivery, POD, claims notice and customer communication. For multimodal shipments, each leg needs a receiving party and custody handover.
6. **P2 — Direct page access:** partner/customer workspace gateways are not security boundaries. Every assignment, quote, capacity and dispatch RPC must enforce current tenant membership, role permission, AAL where required, exact shipment/leg/partner binding and current compliance independently.

## 4. Dispatch and operations handover
- The partner job page clearly says dispatch and transit are downstream from accepted assignment; capacity reservation is an explicit separate step.
- Prior dispatch authorization audit established layered guards for exact active route plan, partner assignment, current compliance/capability, confirmed capacity binding, completed warehouse handover, picked inventory and private dispatch proof.
- Prior operations audit established that dispatch readiness is an assessment, not authorization.
- This audit found zero dispatch authorizations and no live assignments/capacity population. Therefore, those safeguards are code-level controls, not proof of an operational dispatch handover.
- Operations must receive a durable handover record only after the exact shipment/leg has a valid accepted assignment, capacity, legal/market/corridor approval and all required warehouse/customs prerequisites. Any missing or stale dependency should block dispatch and show the exact blocker.

## 5. Required staging-only acceptance tests
1. Partner bid → customer award → offered assignment → partner acceptance → customer acceptance → finalization; verify all IDs and actors.
2. Wrong customer tenant, wrong partner tenant, forged organization, revoked membership and insufficient permission at each transition.
3. Expired/rejected/withdrawn partner quote and stale customer quote version.
4. Duplicate award and simultaneous customer acceptance; verify one assignment/quote and durable idempotency.
5. Assignment accepted but no capacity; customer booking must not imply capacity confirmed or dispatchable.
6. Capacity reserved then partner compliance/capability/vehicle evidence revoked; new dispatch must block.
7. Missing executed agreement/work order and missing acceptance evidence; verify the agreed legal gate.
8. Shipment with multi-leg route; shipment-wide award must remain blocked until leg-specific award/handover exists.
9. Missing warehouse pick/handover proof, customs clearance or required documents; dispatch must remain blocked.
10. Notification failure or provider acceptance without recipient confirmation; UI must not report delivered.
11. Payment not collected under the partner-direct model; KRIM must not show paid or settled.
12. Full cancellation/rejection at each stage with correct release of opportunity, assignment, capacity and customer communication.

None of these end-to-end staging tests was executed in this audit.

## 6. Remediation order
1. Decide with legal counsel whether quote/work order forms the customer–partner contract or a separate executed service agreement is mandatory.
2. Verify and persist immutable quote/terms acceptance evidence; inspect trigger/helper chain before asserting the acceptance table is unused.
3. Build one versioned shipment work-order/handover packet accepted by the correct customer and provider authorities.
4. Make customer booking status a truthful composite of quote, assignment, contract, capacity, regulatory/warehouse prerequisites and dispatch state.
5. Add explicit multi-leg commercial award and custody handover before enabling multi-leg bookings.
6. Run the staging suite with synthetic identities and data only.
7. Do not enable live freight collection or refunds; financial setup remains the final phase.
8. Do not change production DDL/functions/policies until the migration-history reconciliation is complete.

## 7. Change control and release decision
Read-only audit only. No booking, quote acceptance, assignment response, capacity reservation, dispatch, shipment, customer/partner communication or financial action was performed. No production schema or records were changed.

The production/repository migration crosswalk and sanitized schema manifest remain unresolved. No migration replay, baseline or corrective production DDL is authorized.

**Release status: NO-GO for live shipment booking/dispatch certification.** Server-side controls provide a sensible staged lifecycle, but live partner, contract, capacity and handover evidence is absent and the complete staging journey remains untested. Financial collection remains deferred to the final phase.
