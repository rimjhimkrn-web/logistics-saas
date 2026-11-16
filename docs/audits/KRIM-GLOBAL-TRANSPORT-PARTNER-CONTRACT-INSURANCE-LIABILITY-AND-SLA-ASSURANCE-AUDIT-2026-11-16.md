# KRIM Global Transport Partner Contracts, Insurance, Liability and SLA Assurance Audit — 2026-11-16

## Executive decision
**NO-GO for representing any carrier/warehouse/customs partner as contractually appointed, insured for KRIM services, SLA-committed or commercially operational.** The database has useful read-only contract/SLA structures and partner compliance evidence controls, but there are no executed contracts, SLA schedules, insurance evidence/reviews, shipment SLA targets, breach records, remedies, ETA/SLA evaluation runs, claims or claim evidence. A contract-shaped schema is not a signed agreement, and a compliance upload is not proof of valid insurance cover.

This is a read-only audit. No partner was contacted, no insurance certificate was uploaded or verified, no contract or SLA was created, no claim was filed, no SLA evaluator or other RPC was invoked, and no production data/schema was changed.

## 1. Live production evidence

| Object | Rows |
|---|---:|
| Service contracts | 0 |
| Contract SLA schedules | 0 |
| Shipment SLA targets | 0 |
| SLA breaches | 0 |
| SLA remedies | 0 |
| ETA/SLA evaluation runs/results | 0 / 0 |
| Reliability metric snapshots | 0 |
| Partner compliance evidence/reviews | 0 / 0 |
| Partner capabilities | 1 (pending; no approved active capability) |
| Partner capacity commitments | 0 |
| Claims / claim events / claim evidence | 0 / 0 / 0 |

The earlier partner network audit also found no verified active partner capability, no service areas, no capacity and no executed partner contract evidence. The ten legacy partner directory rows marked active are not evidence of current verified providers or signed agreements.

## 2. Contract register and execution assurance
The live `krim_service_contracts` record includes the two organisation IDs, contract number/type/status, effective dates, currency, service definition, commercial terms and metadata. `krim_service_contract_slas` contains metric/target, measurement definition, breach definition, exclusions and status. Both tables have RLS enabled, party-scoped SELECT policies and no authenticated direct INSERT/UPDATE/DELETE privileges.

These are good confidentiality and write-boundary defaults. They are not an executable contract lifecycle. The existing contract integrity audit found no complete, demonstrated counterparty signing/acceptance process, immutable signed document version/hash, signatory authority proof or amendment chain. No current row proves either party accepted a fee, service scope, liability allocation or SLA.

**P1 requirements before commercial use:**
- Verify both parties' exact legal identity, jurisdiction, registration and authorised signatory authority.
- Bind each agreement to a specific KRIM service role (referral, introduction, coordination, SaaS, etc.), territory, cargo/service scope and term.
- Preserve immutable final document bytes/hash, exact version, both-party signatures/acceptance evidence, identity/authority, timestamps, audit trail and amendments.
- Define fee trigger and calculation, invoice/tax treatment, due date, currency, dispute/clawback, cancellation and termination.
- Keep draft negotiations and internal legal notes private; only final agreed terms should be mutually visible.
- A partner agreement must not imply that KRIM is the carrier, freight contracting principal, insurer or customs authority when it is only an intermediary.

## 3. Insurance evidence and coverage — P1
No dedicated first-class insurance policy/coverage/endorsement/claims-made register was found among the live public tables searched. Partner compliance evidence and reviews exist as generic tables, but both are empty. The current baseline has no approved partner compliance evidence or review. The existing partner compliance workflow checks private object ownership, MIME/file size, category and reviewer evidence, but an uploaded document or generic compliance approval is not automatically a validated insurance policy.

Before a provider can be advertised as insured or eligible for a shipment, evidence should be verified against:
- named insured and exact legal entity/registration;
- insurer identity and independently checked policy authenticity;
- policy number, coverage type, limits, aggregate limits, deductible/excess and currency;
- insured operations, cargo classes, modes, geography/jurisdictions and subcontractor scope;
- effective and expiry dates, cancellation/non-renewal status and endorsements;
- exclusions (including high-value, temperature-controlled, hazardous, theft, unattended vehicle, delay, customs and storage risks as applicable);
- claims-made vs occurrence basis, retroactive date and reporting/notice requirements;
- additional insured/waiver of subrogation requirements where legally appropriate;
- independent reviewer, verification source, timestamp, evidence hash and revalidation schedule.

Insurance must be checked at partner onboarding, before each relevant contract/service activation, and again at quote/assignment/dispatch where route, cargo, value or mode may exceed policy scope. Expired, cancelled, unverifiable or mismatched cover must fail closed. Do not describe KRIM as providing cargo insurance or guaranteeing claims payment unless KRIM itself is lawfully authorised and actually underwrites/places that product under a separately reviewed arrangement.

## 4. Liability and responsibility allocation — P1
The public partner agreement framework identifies the right topics, but no executed schedule or shipment-specific allocation was evidenced. A legally reviewed agreement and customer-facing disclosures must define:
- which party contracts with the shipper and has custody at each leg;
- who is responsible for pickup, loading, securing, carriage, transshipment, storage, customs brokerage, delivery and proof of delivery;
- liability standard, cap, exclusions, claim notice periods and mandatory statutory conventions/law;
- cargo declared value, packaging responsibility, dangerous-goods declaration and shipper warranties;
- subcontracting approval and flow-down of equivalent insurance, safety, privacy and liability obligations;
- loss/damage, delay, temperature excursion, theft, contamination, misdelivery and data/security incident handling;
- force majeure, mitigation, salvage, evidence preservation and cooperation;
- indemnities, contribution, insurer notification and no double recovery;
- complaint escalation, governing law, jurisdiction, arbitration/court and language.

Do not copy one universal liability cap across road, rail, ocean, air, warehousing and customs. Mandatory law and conventions can override contract wording. Obtain jurisdiction- and mode-specific counsel review before execution.

## 5. SLA data model and execution gap — P1
The current SLA schema separates:
- contract-level metric target, measurement definition, breach definition and exclusions;
- shipment-level promised pickup/delivery and target definition;
- breach records linked to contract/SLA/shipment/exception with evidence and resolution;
- remedies with formula, amount/currency and separate approval/application fields;
- ETA/SLA evaluation runs and results with snapshots and idempotency keys.

The structures are not populated. The only discovered internal ETA/SLA function, `krim_internal.start_eta_sla_evaluation(...)`, enqueues a run with empty input/result snapshots and a `queued` state, returning an existing run for a matching shipment/idempotency key. No corresponding worker/evaluator was found in the public function-name scan, and the live run/result tables are empty. This does not prove no differently named external worker exists, but no evidence of completed SLA evaluation was found.

The SLA cannot be certified until the system:
- derives promised times from the exact accepted quote/contract/work order and route, not generic defaults;
- defines clock start/stop, timezone, business days, cut-offs, waiting/customer-caused delay and force-majeure exclusions;
- distinguishes partner operational SLA from KRIM's own response/coordination SLA;
- binds metric inputs to verified event sources and immutable shipment/leg/contract versions;
- handles missing, delayed, corrected, duplicate and out-of-order events;
- calculates pickup, milestone, transit, delivery, damage/condition, POD and response metrics only where measurable;
- records evaluator version, input snapshot/hash, source events, confidence, outcome and reproducible calculation;
- creates breach evidence once (idempotent), notifies appropriate parties and preserves dispute/correction workflow;
- applies credits/remedies only when contractually agreed, independently approved and financially authorised.

## 6. Access controls and data integrity
Read-only production privilege review confirmed RLS enabled for contracts, contract SLAs, shipment SLA targets, breaches, remedies, ETA evaluation runs/results, partner compliance evidence/reviews, claims and claim evidence. Authenticated users have SELECT privileges on contract/SLA/claim records but no direct INSERT/UPDATE/DELETE on those listed tables. Partner compliance evidence/review tables have no authenticated table privileges in the reviewed grants.

Party-scoped contract/SLA policies restrict reads to either contract party. Shipment SLA targets and ETA evaluation rows are scoped to the customer organisation. Claims and claim evidence are scoped to claimant/respondent organisations and authorised platform/operations reviewers. This is a strong baseline, but staging tests are still required for cross-tenant IDs, enterprise relationships, revoked membership, shared contracts, private evidence and admin access.

## 7. Commercial responsibility for KRIM's lean non-custodial model
For the initial partner-direct model:
- the shipper and actual logistics provider contract directly for freight service and freight charges;
- the shipper pays the provider directly;
- KRIM separately contracts for and invoices only its own agreed referral/coordination/platform service fee, where legally and tax-compliant;
- KRIM does not receive, hold, pool, escrow, split, settle or pay out partner freight funds;
- partner freight collections and freight GMV are not KRIM revenue;
- KRIM must not guarantee provider capacity, cargo insurance, delivery or customs clearance unless a separately reviewed, lawful contract and operational capability actually supports that undertaking.

This model does not itself establish GST exemption or eliminate agency/consumer-protection/liability duties. Obtain CA and legal review of the actual transaction, fee, documents and conduct before collecting any commercial fee.

## 8. Staging acceptance tests — not run
1. Contract cannot activate without immutable final version/hash and all required authorised-party acceptances.
2. Signatory authority is checked for both organisations; one party cannot sign for the other.
3. Amendments create a new version and do not overwrite executed terms.
4. Contract scope, territory, currency, service and effective dates must cover the shipment/leg.
5. Draft negotiation notes are not visible to the counterparty.
6. Contract expiry, suspension, termination or partner verification revocation blocks new work.
7. Insurance certificate issuer, insured entity, policy status, scope, limits and expiry are independently verified.
8. Policy exclusions and cargo/mode/route mismatch block the affected service.
9. Insurance expiry/cancellation between quote and dispatch revokes eligibility.
10. No public page or API says “insured” or displays policy coverage from an unreviewed upload.
11. Shipment SLA targets are derived from accepted commercial terms and exact route/work order.
12. Missing/out-of-order/duplicate events do not produce false on-time or breach results.
13. SLA evaluator is idempotent and reproducible from immutable inputs.
14. SLA breach/remedy requires contract-defined formula, evidence and independent approval.
15. A credit/remedy cannot trigger an unauthorised refund, payment or financial posting.
16. Customer/partner/enterprise access cannot read another tenant's contract, evidence, claim or SLA data.
17. KRIM referral/coordination obligations remain distinct from carrier freight obligations.
18. No freight payment or settlement is routed through KRIM under the initial non-custodial model.

All tests remain unexecuted. No production RPCs or provider operations were performed.

## 9. Release decision and remediation order
**NO-GO** for commercial partner activation, insurance-backed claims, contractual SLA promises, service guarantees or partner referral revenue until the evidence and agreements exist.

Priority:
- **P0/P1:** complete a legally reviewed, signed KRIM–partner agreement for the exact referral/coordination service and fee model before any paid referral.
- **P1:** implement and independently verify partner insurance evidence and policy-scope matching; do not infer insurance from generic compliance status.
- **P1:** complete customer–provider direct service contract/work order and clear custody/liability allocation for each accepted shipment.
- **P1:** finish an actual SLA evaluation worker and contract-bound measurement model; test event integrity and breach/remedy handling in staging.
- **P1:** test party/tenant access, expiry/revocation and claims evidence.
- **Final financial phase:** only after the above and after the user's business bank/accounting/tax/legal decisions, implement KRIM's own service-fee invoicing/collection. Keep freight money outside KRIM.

## Change boundary
Read-only review of production tables, grants, RLS policies, function inventory and repository documents/pages. No DDL/DML, migration, RPC invocation, contract, claim, insurance upload, partner contact, payment or provider call. Production/repository migration-history mismatch remains unresolved; no migration or corrective production DDL may be applied until schema-manifest reconciliation and separate authorisation.
