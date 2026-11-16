# KRIM Partner Identity, Compliance, Capability and Commercial Agreement Integrity Audit — 2026-11-16

## Scope
Read-only production review of partner organization verification, compliance evidence and reviews, service capability approval, service-area and capacity records, commercial service contracts, SLAs, table access policies and privileged review functions. No partner was approved, no evidence was uploaded, no contract was created or signed, and no production data/schema was changed.

## Live snapshot

| Object | Current rows / state |
|---|---:|
| KRIM organizations | 14 |
| Partner-type organizations | 2 |
| Partner organization verification states | 1 not_started; 1 pending |
| Partner verification cases | 1 open |
| Legacy partner directory records | 10 active |
| Partner capabilities | 1 pending |
| Verified active partner capabilities | 0 |
| Partner compliance evidence | 0 |
| Partner compliance reviews | 0 |
| Partner service areas | 0 |
| Partner capacity commitments | 0 |
| Service contracts | 0 |
| Contract SLA rows | 0 |
| Organization verification checks | 0 |
| Document verification checks | 0 |

The ten legacy `partners` rows marked active are not proof of ten current verified KRIM partner organizations. The current canonical organization/capability/compliance controls show no verified operational capability. No provider can presently be represented as bookable based on this data.

## What is working in the control design

### Business identity verification
The partner verification reviewer requires authentication, AAL2 and platform-admin permission. Approval is restricted to active registered-business logistics organizations with required business identity/location details and at least one submitted registration document. The document path must be under the organization and original submitter's private storage folder, and the storage object owner must match the recorded submitter.

### Compliance evidence
Partner compliance evidence submission requires an active, registered-business, identity-verified partner manager; a valid organization jurisdiction; exactly four baseline categories; a declaration; private storage ownership; matching MIME type and file size; and category-specific evidence paths. Review requires AAL2/platform-admin access, four distinct baseline checks, a substantial reviewer rationale and an expiry date for approval. Verified checks must map to current submitted evidence. Compliance clearance is explicitly not itself commercial activation.

### Capability approval
Capability approval requires AAL2/platform-admin permission, an approval rationale, an independent reviewer from the original capability submitter, current organization compliance, active country and transport-mode catalogue records, one to five private evidence objects owned by the submitter, and valid effective dates/weight scope. Hazardous and refrigerated capabilities are blocked from the standard approval path pending specialist evidence controls.

### Commercial contract data access
Contract and SLA tables have RLS enabled. Authenticated parties have SELECT access scoped to either contract party; direct authenticated INSERT/UPDATE/DELETE grants are absent. Compliance evidence/review tables are RLS-enabled and fail-closed to direct authenticated table access. This is a sound default for sensitive evidence and approval records.

## Material gaps and release blockers

### P1 — Reviewer independence is inconsistent
The partner capability approval function explicitly rejects approval by its submitter. However, the inspected partner identity verification reviewer and compliance reviewer functions do not visibly enforce the same submitter/reviewer separation. The identity reviewer reads the original submitter from organization metadata but does not compare it with the reviewing user. The compliance reviewer validates evidence provenance but does not visibly reject a reviewer who submitted the evidence.

This is a material segregation-of-duties gap. Require reviewer identity to differ from the original submitter and any evidence contributor (or document an independently authorized exception with second-person approval). Apply this consistently to verification, compliance, capability, warehouse and other high-impact approvals.

### P1 — No commercial agreement records or signed-document evidence
There are zero service contracts and zero SLA rows. The contract schema contains party IDs, contract type/status, effective dates, currency, service definition, commercial terms and metadata, but the inspected table has no first-class signed-document object/version, document hash, signatory identity/authority, signature timestamps, counterparty acceptance, or immutable amendment chain. Current contract tables are read-only to authenticated users; no complete counterparty execution workflow was demonstrated.

Do not treat an organization being verified or compliant as evidence that it has accepted KRIM's referral fee, coordination responsibilities, data-processing terms, insurance requirements or service obligations. Do not activate paid referrals or partner-facing commercial commitments without an executed agreement and evidence of both parties' acceptance.

### P1 — No verified operating scope
There are no approved capabilities, service areas or capacity commitments. Capability evidence approval is a useful foundation, but capability alone does not prove route-specific availability, current capacity, a price offer or service-level commitment. Every quote/match must remain fail-closed until the exact route/leg, mode, service scope, active market, verified capability, approved service area, current capacity and valid commercial offer are all confirmed.

### P2 — No independent registry verification activity
Organization verification and document verification tables contain no rows. Existing evidence checks are based on uploaded documents and internal review. For real partner onboarding, record the jurisdiction, registry/provider, check type, timestamp, reference hash, result, expiry and reviewer for external business registry/licence/insurance checks. Manual visual inspection should be labelled as such, not represented as a verified government registry result.

### P2 — Legacy active partner directory can mislead
Ten legacy partner records are marked active while the canonical partner organizations have no verified active capability. Public pages, dashboards, matching and marketing must derive operational claims from canonical verification and capability state, not legacy `partners.status`.

## Required commercial agreement controls

Before commercial activation, store and verify:
1. Exact legal names and registration/jurisdiction identifiers for both parties.
2. Authority of each signatory and evidence of that authority.
3. Contract type and clearly defined KRIM service scope (referral, introduction, coordination, software or other actual service).
4. Fee basis, amount/percentage, currency, trigger event, tax treatment, invoice/payment terms and dispute/refund treatment.
5. Explicit statement that freight contract/payment is directly between customer and logistics provider under KRIM's initial non-custodial model.
6. No representation that KRIM guarantees carrier capacity, insurance, delivery or customs clearance unless expressly and lawfully contracted.
7. Data protection, confidentiality, permitted use, retention, security and incident reporting.
8. Complaints, claims, liability allocation, insurance evidence, indemnities, termination, suspension and governing law/jurisdiction reviewed by qualified counsel.
9. Versioned final contract file, cryptographic hash, both-party acceptance evidence, signatory identity, timestamp and amendment history.
10. Contract validity and renewal/expiry checks before any referral fee accrues or service is represented as active.

A click-through checkbox alone is not sufficient evidence of authority to bind a company. Use an appropriate legally reviewed signing process.

## Recommended activation state machine

`registered → identity_pending → identity_verified → compliance_pending → compliant → capability_pending → capability_verified → commercial_agreement_pending → agreement_executed → service_area_verified → capacity_confirmed → operationally_eligible`

Every stage must have evidence, actor, timestamp, expiry/revalidation and audit history. Rejection, expiry, insurance lapse, licence expiry, complaint hold or material change must revoke eligibility promptly. Agreement execution does not override country/corridor activation, capability, capacity or safety gates.

## Staging verification matrix
1. Partner cannot submit evidence or capability for an organization where they lack active partner.manage authority.
2. Evidence from another organization, user, bucket or stale version is rejected.
3. Identity reviewer cannot approve their own organization's submission.
4. Compliance reviewer cannot approve evidence they submitted; second-person approval is required for any exception.
5. Capability submitter cannot approve their own capability; hazardous/cold-chain requests remain blocked until specialist workflow is approved.
6. Expired identity, licence, insurance or compliance evidence automatically removes operational eligibility.
7. Contract cannot become executed without two authorized counterparties, immutable version/hash and acceptance evidence.
8. Fee cannot accrue without an executed, effective agreement and independently evidenced qualifying referral/service.
9. Legacy active partner directory rows cannot create a match, quote, booking or marketing claim.
10. Service-area/capacity/route and offer checks are evaluated for the exact shipment leg and revalidated at award and dispatch.
11. All approval and agreement changes create append-only audit events; ordinary members cannot edit/delete evidence or decision history.
12. Test concurrent review, duplicate submissions, expiry races, revoked access and changed organization ownership.

## Release decision
**Partner onboarding foundations exist, but commercial partner activation is not ready.** Current production evidence shows zero verified active capabilities, zero service areas, zero capacity commitments, zero compliance evidence/reviews and zero executed service contracts/SLA rows. Do not publish partner coverage or invite customers to book partner capacity until the complete chain is evidenced.

Migration history remains materially divergent between repository and production. Do not modify production verification/compliance functions, triggers, grants, contract tables or policies until the encrypted schema export manifest has been safely produced and reconciled. Prioritize reviewer/submitter separation and a versioned two-party contract execution workflow in a reviewed migration and staging test environment.
