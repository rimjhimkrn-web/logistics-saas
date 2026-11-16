# KRIM Commercial Agreement & Fee Management System
**Date:** 16 November 2026  
**Status:** production-schema assessment and implementation blueprint only. No production records, policies, grants, functions or schema were changed.

## 1. Purpose

Define the commercial control layer that must exist before KRIM can safely earn partner referral/coordination fees, sell software subscriptions, or enter enterprise/white-label arrangements. A database row marked active is not, by itself, proof of a legally executed agreement.

The system must distinguish:
- partner logistics service agreements (shipper ↔ logistics partner);
- KRIM referral/marketing agreements (KRIM ↔ partner);
- KRIM coordination/service agreements (KRIM ↔ customer or partner);
- KRIM software subscription/licence agreements (KRIM ↔ customer/enterprise);
- data processing, confidentiality, API, white-label and other ancillary terms.

Each agreement type has its own service provider, payer, obligations, evidence, fee model, tax treatment and approval path. Never combine these into one generic “commission contract”.

## 2. Live production assessment

### Existing `public.krim_service_contracts`

Observed columns:
- `id`, `organization_id`, `counterparty_organization_id`;
- `contract_number`, `contract_type`, `status`;
- `effective_from`, `effective_until`, `currency_code`;
- `service_definition`, `commercial_terms`, `metadata`;
- `created_at`, `updated_at`.

Observed controls:
- unique constraint on `contract_number` only;
- index on `(organization_id, counterparty_organization_id, status)`;
- RLS enabled, not forced;
- authenticated users have SELECT only;
- one SELECT policy permits access where the user belongs to either party organisation;
- service_role has broad table privileges;
- no user-defined triggers;
- zero rows;
- no public functions found whose definitions directly reference this table.

### Existing `krim_service_contract_slas`

Contains contract ID, SLA/metric codes, target values/units, measurement, breach and exclusion JSON, status and timestamps. It has zero rows.

### Critical gaps

The existing contract record has no dedicated:
- immutable contract version or amendment chain;
- signed-document storage reference and cryptographic hash;
- signature ceremony/provider envelope and per-party signer evidence;
- signatory authority verification;
- legal/tax/compliance approval record;
- explicit contract type catalogue and permitted status transition model;
- acceptance timestamp per counterparty;
- renewal, notice, suspension, termination and dispute events;
- fee schedule version and trigger binding;
- data-processing purpose, retention and deletion schedule;
- audit-event history;
- execution-state invariant preventing premature activation.

The current party-level SELECT policy intentionally lets both parties read the shared contract row, including commercial terms. This may be appropriate for a fully executed bilateral agreement, but draft negotiation terms and sensitive internal notes should not be stored in the same mutually visible record. Separate internal review/negotiation material from the shared final agreement. Do not weaken or broaden current RLS without a tenant-by-tenant test plan.

## 3. Canonical agreement types

Use a controlled enum/reference catalogue rather than free-form values:

| Type | Parties | Commercial basis | Required proof |
|---|---|---|---|
| partner_referral | KRIM + logistics partner | fixed / percentage / tiered referral fee | executed agreement + referral trigger evidence |
| partner_coordination | KRIM + partner | defined coordination deliverables | executed agreement + accepted work evidence |
| customer_coordination | KRIM + shipper | defined customer-paid service | executed customer agreement + deliverable evidence |
| saas_subscription | KRIM + customer/enterprise | recurring or fixed software licence | executed subscription order + entitlement terms |
| enterprise_licence | KRIM + enterprise | seats, usage, modules, locations or API | executed master agreement + order form |
| white_label | KRIM + reseller/enterprise | licence, setup, support and usage fees | executed master agreement + scoped order form |
| data_processing | controller/processor parties | generally ancillary; no automatic revenue | signed DPA and documented role/purpose |
| api_integration | KRIM + integration party | setup, usage or support fee if contracted | executed scope, API terms and acceptance |

The shipper's freight contract is between the shipper and the actual provider. KRIM should not present itself as the carrier or freight contracting principal where it only introduces or coordinates.

## 4. Agreement lifecycle

`draft → internal_review → legal_tax_review → commercial_approval → ready_to_send → sent_for_signature → partially_signed → executed → activation_review → active`

Other controlled states: `rejected`, `withdrawn`, `expired`, `suspended`, `terminated`, `superseded`, `disputed`.

Rules:
- `executed` requires all required parties' signatures and a complete immutable signed artifact.
- `active` requires executed status, valid effective dates, no unresolved activation blocker and all type-specific prerequisites.
- A referral agreement cannot activate without approved partner due diligence, a fee schedule, fee trigger and evidence rules.
- A subscription cannot activate entitlements until its order form, plan, billing cadence, service limits, cancellation and support terms are approved.
- Amendments create a new immutable version linked to the prior version; they never rewrite the signed version.
- Suspension/termination affects future performance according to the contract; it does not erase accrued obligations.
- Expiry and renewal alerts are reminders, not automatic legal renewal.

## 5. Proposed data architecture (design only)

All names are provisional; reconcile against complete production schema and migration lineage before implementation.

### A. Agreement master
- stable agreement ID, unique human-readable number;
- KRIM legal entity ID and counterparty organisation ID;
- agreement type and governing jurisdiction;
- current version ID;
- business owner and responsible KRIM function;
- status, effective date, expiry date, notice period;
- confidentiality classification;
- created/updated actor and timestamps.

### B. Immutable agreement versions
- agreement ID and monotonically increasing version number;
- canonical structured terms snapshot;
- canonical document reference, MIME type, byte length and SHA-256 hash;
- template/version identifier;
- amendment/supersedes reference;
- version creation actor/time;
- locked/finalised timestamp.
No UPDATE/DELETE after execution. Corrections are a new amendment/version.

### C. Party and signatory register
- party organisation and legal identity snapshot;
- authorised signatory name, role and authority basis;
- signatory email/contact verification state;
- authority evidence reference and review;
- signature method, provider envelope, signer ID, signed timestamp;
- certificate/audit trail reference and final document hash.
A typed name or uploaded image alone is not reliable proof of authority. Select an e-sign method appropriate to jurisdiction and obtain legal advice on enforceability.

### D. Review and approval workflow
- review type: commercial, legal, tax, privacy, security, finance, operations;
- reviewer identity and organisation;
- decision: approved, rejected, changes_requested, not_applicable;
- reason, evidence, timestamp and policy version;
- maker/checker separation and conflict-of-interest controls.
A reviewer must approve the exact version hash, not an editable draft that later changes.

### E. Commercial schedule
- currency and fee model;
- amount/rate/tier and unit;
- calculation base and exclusions;
- caps/floors/minimums;
- due date and invoice cadence;
- tax/withholding configuration reference (not guessed);
- trigger and evidence catalogue;
- cancellation, dispute, clawback and credit-note rules;
- effective date and immutable version binding.

### F. Obligations and service levels
- obligation owner, description and due date;
- acceptance criteria and evidence;
- SLA code, measurement, exclusions and remedy;
- breach notification, cure period and escalation;
- service owner and customer/partner acknowledgement.

### G. Append-only agreement events
Record every creation, submission, review, approval, signature, activation, amendment, suspension, expiry, termination, dispute and exception with actor, time, reason, source, correlation ID and before/after hashes. No hard deletes. Sensitive content remains in protected document storage, not duplicated in event payloads.

## 6. Security and privacy model

- Store signed documents in a private storage bucket, never a public bucket.
- Issue short-lived signed links only after party, role and agreement-level authorisation.
- Keep draft negotiation notes private to the originating organisation; expose only approved shared content.
- RLS must scope every agreement and document to a party relationship and permitted role; authenticated status alone is insufficient.
- Separate permissions: contract.view, contract.create, contract.edit_draft, contract.submit_review, contract.approve_commercial, contract.approve_legal, contract.sign, contract.activate, contract.suspend, contract.terminate, contract.audit.
- Do not allow a user to approve their own agreement or approve a version they modified.
- Signatory authority must be checked separately from ordinary organisation membership.
- Privileged functions, if genuinely required, belong in a non-exposed schema, fixed search_path, explicit auth.uid()/permission/tenant checks, and narrowly granted EXECUTE.
- No user_metadata JWT claims for authorisation.
- Keep private data, identity evidence and signatures only as long as justified by legal/contractual retention requirements; implement deletion/anonymisation rules for data not required to be retained.
- Cross-party access must be tested for draft, executed, expired, terminated and disputed agreements.

## 7. Fee and revenue controls

A signed agreement is necessary but not sufficient to recognise revenue.

For referral/coordination:
1. validate active agreement version and counterparty;
2. validate consent and attribution;
3. validate contract-defined trigger;
4. verify required independent evidence;
5. calculate fee from immutable terms snapshot;
6. maker-checker approve assessment;
7. create KRIM invoice only after legal/tax invoice gate;
8. reconcile actual KRIM receipt;
9. post to canonical KRIM finance entity using approved account mapping;
10. calculate net contribution after direct costs and gateway fees.

For SaaS:
1. executed subscription order form;
2. approved plan and price version;
3. effective entitlement dates and limits;
4. invoice schedule and tax setup;
5. payment collection/receipt reconciliation;
6. entitlement activation, grace, suspension and cancellation;
7. revenue recognition under CA-approved policy.

Do not treat a partner freight payment, partner invoice, shipment gross value, quote or platform GMV as KRIM revenue or cash. Do not reuse the freight collection/payment flow for SaaS billing.

## 8. Required operational controls

- Agreement templates version-controlled and jurisdiction-tagged.
- Required fields and approvals vary by contract type and risk.
- No activation without complete signatures, legal entity, counterparty, effective dates and required approvals.
- Fee schedules must be machine-readable, deterministic and human-readable in the signed document.
- Amendments cannot retroactively alter a fee already earned unless the signed amendment and applicable law permit it.
- Expiry, renewal and notice reminders with delivery/retry logs.
- Partner verification and capability are rechecked at onboarding and periodically.
- Sanctions, restricted goods, insurance, licence and regulatory checks must be proportionate to the service and jurisdiction; do not imply KRIM itself holds partner licences.
- Contract exceptions require reason, named approver, expiry and audit event.
- Maintain dispute, complaint and service-failure workflow.
- Provide a complete exportable audit package for a contract and each associated fee assessment.

## 9. Acceptance test matrix

1. Unauthenticated user cannot read agreement or document.
2. Authenticated non-party cannot discover agreement by ID or guessed URL.
3. Party member without contract permission cannot read draft.
4. Partner cannot read KRIM internal negotiation notes.
5. One party's signature cannot mark a two-party agreement executed.
6. Signatory without verified authority cannot execute.
7. Modified document after signature fails hash verification.
8. Approval for version 1 cannot approve version 2.
9. Creator cannot approve own agreement.
10. Expired/suspended agreement cannot generate a new fee assessment.
11. Termination preserves historical obligations and accrued fees.
12. Amendment preserves prior signed version and linked events.
13. Missing tax/legal review blocks activation when required.
14. Partner capability or verification lapse blocks eligible referral routing.
15. Referral fee trigger and invoice use the same immutable commercial terms version.
16. SaaS entitlements cannot exceed signed order-form limits.
17. Duplicate signature webhooks cannot duplicate execution events.
18. Out-of-order webhook cannot regress agreement state.
19. Document download links expire and are not reusable after authorisation is revoked.
20. Audit export shows complete chain without exposing unrelated tenants.

## 10. Release gates and recommendation

**Gate 0 — legal identity:** canonical KRIM contracting entity, registration details, tax status, authorised signatory and bank ownership confirmed.

**Gate 1 — commercial templates:** counsel/CA-reviewed partner referral, coordination, SaaS, enterprise, DPA and order-form templates.

**Gate 2 — platform integrity:** recover production migration SQL, reconstruct staging, reconcile schema, implement versioning and RLS, pass security tests.

**Gate 3 — signing:** choose and validate e-sign process, signatory authority checks, immutable artifact hashing and webhook idempotency.

**Gate 4 — billing integration:** fee-specific invoice/receipt flows and SaaS billing are separate from freight collections.

**Gate 5 — pilot:** one partner agreement and one customer/enterprise agreement tested end-to-end in staging; production only after legal, security and finance sign-off.

### Current decision

The existing `krim_service_contracts` table is a useful starting point but not a complete commercial agreement management system. It has zero rows, authenticated read-only access for the two contract parties, no user-defined triggers and no directly referencing public function found in the inspected catalogue. Its current schema lacks versioned execution/signature and review evidence. Do not activate it as the legal source of truth or create production agreements until the gaps above are addressed.

This is an architecture assessment, not legal advice, a signed contract, a tax opinion or proof of operational readiness.
