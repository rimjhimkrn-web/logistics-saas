# KRIM Customer–Partner Contracts, Agreements and Commercial Terms Integrity Audit
**Date:** 16 November 2026  
**Scope:** Read-only review of public legal terms, partner agreement framework, customer and partner contract pages, quote submission/acceptance flows, service-contract/payment-term/quote-acceptance/dispute/claim/refund schema and live record counts, and selected live RPC definitions and privileges. No contract was created or accepted, no quote was submitted/awarded/accepted, no claim or refund was filed/reviewed, no partner/customer contacted, no payment action taken, and no production data or schema changed.

## Executive decision
**NO-GO for representing KRIM as having a complete, signed customer–partner contracting and dispute-resolution lifecycle.** The public legal content is unusually careful about KRIM's intended partner-direct referral/coordination model and repeatedly distinguishes a framework or quote from a binding shipment booking. The quote workflow has meaningful server-side checks and immutable-style quote version/acceptance data structures. However, the production service-contract, quote-acceptance, payment-terms, SLA, claims and dispute registers are empty; no complete executable contract creation, counterparty signature/acceptance, versioned legal-document acknowledgement, and contract-to-shipment binding workflow was established by this audit.

## 1. Live production baseline
Read-only exact counts at the audit snapshot:

| Object | Rows |
|---|---:|
| `krim_service_contracts` | 0 |
| `krim_service_contract_slas` | 0 |
| `krim_payment_terms` | 0 |
| `krim_quote_acceptances` | 0 |
| `krim_quote_events` | 0 |
| `krim_quote_versions` | 0 |
| `krim_quotes` | 7 |
| `krim_partner_opportunities` | 3 |
| `krim_partner_quotes` | 0 |
| `krim_claims` | 0 |
| `krim_claim_events` | 0 |
| `krim_claim_evidence` | 0 |
| `krim_disputes` | 0 |
| `krim_dispute_cases` | 0 |
| `krim_dispute_appeals` | 0 |
| `krim_dispute_decisions` | 0 |
| `krim_dispute_evidence_links` | 0 |
| `krim_dispute_investigations` | 0 |
| `krim_refund_requests` | 0 |
| `krim_invoices` | 0 |

Seven quote rows and three opportunities do not prove any customer/partner contract was signed or any partner service was performed. Zero partner quote rows means no live partner bid is present in the current table snapshot.

## 2. Legal document and public disclosure review
### Positive controls
- `terms.html` identifies itself as a structured business-terms draft for operational review, not legal advice or a final customer/partner contract. It says paid booking must wait for legal review and accurate entity disclosures.
- The public terms describe the intended referral-led launch model: customer contracts with and pays the logistics provider directly, while KRIM may separately receive an agreed partner marketing/referral/coordination fee. They also correctly note that actual legal role depends on transaction design, documents, representations and conduct, not merely labels.
- The terms distinguish quote request, estimate and partner bid from confirmed booking; booking requires explicit acceptance/confirmation after provider, service, price, payment and operational checks.
- The partner agreement framework `partner-agreement.html` explicitly says it is a framework for negotiation and that commercial variables and legal choices must be completed in a signed contract and schedules.
- It calls for exact legal names, constitution, addresses, tax details and authorised signatories; defined services/territory/cargo/equipment/capacity; shipment-specific work orders; partner and KRIM duties; cargo custody; rates/tax/accessorials; insurance; compliance; data; subcontracting; disruption; suspension/termination; dispute resolution and mandatory schedules.
- The partner standards page says it is not a signed contract, appointment, licence, guarantee of work or payment. It says commission, platform fees, tax, currency, invoicing, milestones and settlement terms must be separately accepted.
- Legacy `legal/customer-terms.html` redirects to the canonical terms page. Legacy partner terms route to partner standards. This reduces conflicting legal text.

### Legal/document gaps
1. **P0 — Draft is not execution-ready:** the canonical public terms expressly remain preliminary, and the partner agreement is a framework. Neither is evidence of a final contract reviewed for KRIM's actual legal operator, exact proprietorship details, statutory status and transaction structure. Do not present either as a signed contract or imply customers/partners have accepted it.
2. **P1 — Missing legal entity completion:** final documents need exact contracting legal name, constitution, proprietor identity as appropriate, principal business/notice address, grievance contact, authorised signatory and relevant registrations. These must be reconciled with current GST/legal status and professional advice before commercial use.
3. **P1 — Customer-specific service-provider contract:** the public framework correctly requires a direct provider/customer contract where the partner-direct model is used, but this audit found no complete live workflow to generate, present, accept and preserve that agreement with the customer and the exact provider for a shipment.
4. **P1 — No executable agreement acceptance evidence:** no live service-contract rows, quote-acceptance rows or signature/acceptance records exist. No end-to-end counterparty acceptance was tested.
5. **P1 — Version and precedence rules:** the final system must bind the exact terms/document version, hash, language, timestamp, actor, organization, authority, acceptance method and transaction reference. It must define precedence among master agreement, service schedule, quote version, shipment work order, provider terms and mandatory law.
6. **P1 — E-signature and evidence standard:** define the legally appropriate electronic acceptance process, identity/authority checks, evidence retention, tamper-evident snapshots and audit export. A button click or generic checkbox alone should not be assumed sufficient for every contract.
7. **P1 — Cross-border terms:** international contracting, jurisdiction, currency, tax, customs, sanctions, insurance and dispute forum must be jurisdiction/service specific; no global standard terms should imply universal legal suitability.

## 3. Contract and commercial data model
The live database contains:
- `krim_service_contracts` with organization/counterparty IDs, contract number/type/status, effective dates, currency, service definition, commercial terms and metadata.
- `krim_service_contract_slas` with SLA metrics, measurement/breach definitions, exclusions and status.
- `krim_payment_terms` with organization, method, credit days, currency and active/default flags.
- `krim_quote_versions` with version number, subtotal/tax/total, validity, customer terms and pricing snapshot.
- `krim_quote_acceptances` with customer organization, accepting user, method, timestamp, terms version, acceptance snapshot, evidence reference and hashed IP/user-agent fields.

These are useful foundations. But every counted contract/SLA/payment-term/quote-version/quote-acceptance row was zero. A schema field named acceptance snapshot is not proof of a valid signature or executed contract. The table model needs a documented lifecycle and controlled write path. The audit did not identify a public executable service-contract creation/signature/acceptance routine by name in the targeted function inventory. This is a scoped search result, not proof that no private or differently named workflow exists.

### Required contract state model
At minimum, keep these states distinct:
- draft / negotiation;
- issued to counterparty;
- viewed (not accepted);
- accepted by first party;
- accepted by counterparty / fully executed;
- effective for defined scope;
- amended / superseded;
- suspended;
- expired / terminated;
- disputed.

Only fully executed and currently effective agreements should satisfy the contract prerequisite for the exact parties, service, territory and date. A quote acceptance or assignment must not silently stand in for a master agreement unless the final legal design expressly makes the quote/work order the complete contract and records all required terms and acceptances.

## 4. Quote and booking commitment lifecycle
### Positive controls observed
- Partner quote submission `krim_submit_partner_quote` is SECURITY DEFINER, requires authenticated identity, exactly one eligible active registered-business partner organization, current verification/lifecycle/compliance, active verified capability, `quote.create`, active currency, open opportunity, deadline, shipment coverage and non-self-bidding. It locks the opportunity, bounds amount/notes/validity and records an audit event.
- Customer quote preparation `krim_award_partner_quote_for_checkout` requires customer organization access plus `quote.update` and `shipment.update`, checks opportunity and partner quote eligibility/expiry, matching customer shipment, shipment state, existing quote conflicts, and blocks shipment-wide award while an active multi-leg plan exists. It creates a customer quote and a version/pricing snapshot/event. The snapshot states that payment is arranged directly with the provider after final acceptance and assignment confirmation, tax breakdown is not separately calculated, and production tax invoice is not ready.
- Customer quote acceptance `krim_accept_global_quote` locks quote and shipment, checks customer organization access and `shipment.update`, expiry and shipment state, and requires a matching accepted partner quote and accepted partner assignment, active verified partner, acceptable compliance state, current active verified capability and route coverage before confirming the shipment and finalizing the assignment.
- The customer quote page correctly warns that quote acceptance is not proof of carrier assignment, final booking, payment collection or delivery.
- Partner quote submission UI asks the partner to confirm its offer terms and explicitly says a submitted offer is not a customer award or accepted assignment.
- The customer claims UI accurately says a claimed amount is a request, not an approved debt or guaranteed compensation, and that under the current partner-direct model KRIM does not promise or fund freight compensation.

### Findings
1. **P1 — Award is not full contract execution:** the award routine creates a customer quote and an assignment in an offered stage; a later partner acceptance and customer quote acceptance are separate. This is a useful multi-step control but it does not by itself prove a signed service agreement, full commercial schedule or mutual acceptance of liability/claims terms.
2. **P1 — Commercial snapshot is incomplete for binding acceptance:** quote version snapshot currently records tax breakdown as not separately calculated and production tax invoice not ready. Do not represent the quote as a final tax-complete invoice or universal all-in price without the required tax/charge analysis.
3. **P1 — Assignment and booking semantics:** the customer quote acceptance routine transitions shipment to confirmed only after accepted partner quote/assignment checks. It should be tested alongside shipment status transitions, exact-leg controls, partner capacity and contract prerequisite. This audit did not execute it.
4. **P1 — Terms version binding not proven in quote acceptance:** `krim_quote_acceptances` has a `terms_version` and `acceptance_snapshot` structure, but no records exist and the reviewed `krim_accept_global_quote` definition changes quote/shipment state without visibly writing that table. A downstream trigger/helper may exist; verify the complete trigger chain before concluding it is absent. Ensure the exact terms and quote version are durably bound to the acceptance event.
5. **P1 — Idempotency and concurrent retry:** static quote routines use row locks and have some existing-quote retry handling, but staging must prove duplicate clicks, network timeouts, concurrent acceptances, stale versions and partial failure cannot create conflicting awards, duplicate assignments or inconsistent acceptance evidence.
6. **P1 — Customer/partner contract linkage:** the selected source pages show quote and claim journeys but the customer contract-management page is only a generic workflow guide and partner contract-management redirects to the partner landing page. These pages do not constitute a live agreement register or signature workflow.

## 5. Claims, disputes, cancellation and refunds
### Positive controls observed
- Customer claims register reads organization-scoped claim records, shipment history, events and evidence, and submits claims through `krim_claim_submit`.
- Claim submission is limited by the UI to confirmed/closed shipments; the earlier database migration history includes hardened claim evidence/review and confirmed-shipment restrictions.
- Claim evidence upload uses a private bucket and the UI restricts files to PDF/JPEG/PNG up to 10 MB. The public wrapper delegates to a private database routine; this audit did not execute it or fully inspect its private implementation.
- The claim interface distinguishes claim submission from support tickets and states that compensation is determined by provider agreement and applicable insurance.
- Refund requests are separate from claims and have separate submit/review routines; refund execution is independently gated and remains disabled unless a separate legacy execution flag/version is enabled.

### Findings
1. **P1 — No operational claims/dispute evidence:** claims, events, evidence and dispute tables are all empty. There is no evidence that a real claim was filed, investigated, decided, appealed or closed.
2. **P1 — KRIM/provider/customer responsibilities need case routing:** define who is the contracting carrier, who investigates, who communicates with the customer, who handles insurance notice and who pays an approved claim. KRIM's referral/coordination role must not be confused with carrier liability or insurer status.
3. **P1 — Cancellation/refund policy alignment:** public terms, refund policy, partner contract, quote validity, provider work order and actual provider cancellation schedule must agree. A platform refund request is not proof that KRIM received or holds the partner's freight funds; under the current model, customer freight payment is direct to provider.
4. **P1 — Dispute independence and appeal:** verify maker-checker, reviewer independence, evidence ownership, reasoned decisions, appeal rights, time limits, escalation and audit retention in staging. The dispute register has no records.
5. **P1 — Contractual notice and statutory rights:** final cancellation, limitation, liability cap, claims notice, insurance and dispute forum provisions must not conflict with mandatory transport, consumer, contract, insurance or data law.
6. **P2 — UI page placeholders:** several customer pages for contract management and disputes are generic workflow guides rather than live record-management tools. They must not be presented as completed case or contract workflows.
7. **P2 — Refund execution separation:** retain the existing execution gate; do not enable refunds or any customer/partner fund movement as part of this phase.

## 6. Non-custodial commercial model guardrails
The launch design remains:
- customer contracts with and pays the selected logistics provider directly for freight;
- KRIM separately earns only its own agreed referral/coordination/platform service fee for real services, when legally and tax-authorized;
- KRIM does not receive, hold, pool, escrow, split, settle or pay out partner freight funds;
- freight GMV and partner freight collections are not KRIM revenue.

The public terms broadly reflect this model but correctly say actual legal treatment depends on substance and conduct. It is not automatically GST-exempt. Before any paid activity, obtain CA/legal confirmation of GST applicability, e-commerce/operator classification, invoicing, TDS/TCS if relevant, consumer disclosures, common-carrier obligations and exact contracting entity. The current quote snapshot explicitly indicates tax breakdown is not separately calculated and production tax invoice is not ready. Keep payment collection and finance implementation deferred to the final phase.

## 7. Required staging-only acceptance tests
1. Customer contract: exact provider and KRIM entity identity, legal capacity, service scope, schedule, version hash, customer authority and electronic acceptance evidence.
2. Partner master agreement: partner authority, scope, territory, rate schedule, commission/referral fee if any, insurance, subcontracting, liability, claims, data, termination and counterparty acceptance.
3. Quote versioning: revise after issue, expire, supersede, reject, reissue; ensure old acceptance cannot accept a newer or stale version.
4. Quote/assignment: partner bid → customer award → partner assignment acceptance → customer acceptance → final booking; verify every actor and tenant boundary.
5. Duplicate/retry/concurrency: simultaneous quote award, accept, reject and retry after network timeout.
6. Cancellation: before provider acceptance, after acceptance but before pickup, after pickup, in transit, after delivery; apply correct party-specific fees and statutory rights.
7. Claim: loss/damage/delay, evidence upload, reviewer independence, insurer/provider routing, partial approval, rejection, appeal, settlement and closure.
8. Refund: prove no KRIM-held freight money is assumed; no refund execution without authorized funds, provider responsibility and explicit approval.
9. Data protection: contract/evidence access limited to parties, retention/legal hold, signed-link expiry and audit export.
10. Legal-version change: material terms update triggers fresh acceptance where required and does not rewrite historical agreements.

None of these end-to-end staging tests was executed in this audit.

## 8. Remediation order
1. Obtain CA/legal review and finalize the actual contracting model and KRIM legal identity before publishing final binding terms.
2. Build a canonical contract/booking document model linking customer, provider, KRIM role, shipment, exact quote version, service schedule and signed work order.
3. Implement authenticated, tenant-scoped, authorized create/issue/accept/counter-sign/amend/suspend/terminate routines with version hashes, idempotency, audit and private document evidence.
4. Bind quote acceptance to the precise customer terms version and accepted partner work order/contract; inspect triggers/private helpers to verify acceptance persistence.
5. Align cancellation, claims, insurance, liability, dispute, appeal and refund processes across public terms and signed schedules.
6. Implement the live contract register in customer and partner workspaces; replace generic placeholder pages only after backend contracts exist.
7. Run staging tests above. Keep live finance/collection deferred.
8. No production DDL/function/policy changes until the outstanding migration-history reconciliation is completed.

## 9. Change control and release decision
This was a read-only audit. No agreements, quotes, assignments, claims, disputes, refunds, invoices, payments or customer/partner communications were created or changed.

The production/repository migration crosswalk and sanitized schema manifest remain unresolved. Do not apply schema/function/policy changes or retire legacy routines until reconciliation is complete.

**Release status: NO-GO for claiming a completed signed customer–partner contract lifecycle or fully operational claims/dispute process.** Public framework documents are useful preparatory material, but they are not final signed agreements. Quote controls have meaningful server-side safeguards, but there is no live acceptance evidence or contract population. Financial collection remains deferred to the final phase.
