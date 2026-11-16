# KRIM Partner Verification, Due Diligence & Activation System
**Date:** 16 November 2026  
**Status:** read-only production assessment and design blueprint. No production schema, grants, policies, functions, partner records or activation states were changed.

## 1. Objective and operating rule

KRIM must only introduce a logistics provider as **verified**, **compliant**, **capability-approved**, **contracted** or **available** when the corresponding evidence has been independently reviewed and is current. Registration, an uploaded file, a populated capability row, an open verification case, or a partner's own declaration is not approval.

The initial India activation should use a risk-based, service-specific process. Requirements differ by transport mode, geography, cargo class and legal role. Do not require irrelevant licences, and do not treat one generic checklist as proof of global compliance. Before expanding into another country, configure jurisdiction-specific rules with qualified local review.

KRIM's role remains platform/referral/coordination unless a separately approved operating model says otherwise. Actual freight service is provided and contracted by the logistics partner; KRIM must not imply that it is the carrier or that it has operational coverage until verified.

## 2. Live production snapshot (read-only)

### Relevant table counts
| Area | Live rows |
|---|---:|
| Legacy `partners` | 10 |
| `partner_documents` | 0 |
| `partner_fleet` | 0 |
| `partner_drivers` | 0 |
| `krim_partner_verification_cases` | 1 |
| `krim_partner_discovery_profiles` | 0 |
| `krim_partner_onboarding_checklists` | 0 |
| `krim_partner_capabilities` | 1 |
| `krim_partner_service_areas` | 0 |
| `krim_partner_compliance_evidence` | 0 |
| `krim_partner_compliance_reviews` | 0 |
| `krim_partner_capacity_availability` | 0 |
| `krim_partner_capacity_commitments` | 0 |
| `krim_partner_quotes` | 0 |
| `krim_shipment_partner_assignments` | 0 |
| `krim_partner_performance_events` | 0 |
| `krim_partner_performance_metrics` | 0 |
| `krim_partner_opportunities` | 3 |

### Verification case
One case exists for organisation 14, case number `KPV-6A319F5518AD`, standard level, status `open`, no decision, no assigned reviewer, and no started/completed timestamp. Organisation 14 is labelled **ABC Logistics**, account mode `development_test`, lifecycle `verification_pending`, verification/compliance `pending`, onboarding `in_progress`. This is a development/test account, not evidence of an approved live partner.

Other partner-type organisation 2 is named **KRIM Test Transport Partner** and has no partner account mode or verified/approved/compliant lifecycle state. No live production-ready partner was established by this audit.

### Existing architecture
- `krim_organizations` has partner lifecycle, verification, compliance, onboarding, review and account-mode fields.
- `krim_partner_verification_cases` tracks case number, level, status, submitter, reviewer, decision and timestamps.
- `krim_partner_discovery_profiles` tracks source opportunity, identity summary, onboarding/verification/visibility status and self-registration flag.
- `krim_partner_onboarding_checklists` tracks requirement code/type, status, required flag and evidence reference.
- `krim_partner_capabilities` records transport mode, service type, geography, weight, refrigeration/hazardous-goods capability, verification status and effective dates.
- `krim_partner_service_areas` records geographic and service scope.
- `krim_partner_compliance_evidence` and `krim_partner_compliance_reviews` exist but are empty.
- Capacity, assignment, matching, quote and performance tables exist but are empty or not populated with real partner operating history.

## 3. Important security and integrity findings

1. **Applicant-editable onboarding data:** authenticated users have an ALL policy on discovery profiles scoped to their organisation, and an ALL policy on checklist rows through their discovery profile (or platform admin). This is useful for draft/self-service intake, but means checklist status/evidence references cannot be treated as independently verified. Split applicant-submitted fields from reviewer-controlled verification decisions. Applicant must never set a checklist to approved or close a verification case.
2. **Legacy partner documents:** authenticated partner owners can INSERT and SELECT their own `partner_documents`. The table has document type/number/expiry/file path/status fields. A partner-uploaded status or file reference is not proof of authenticity, and the inspected policy does not provide an independent review/approval workflow. Keep these rows untrusted until reviewed.
3. **Legacy partner profile:** partner owners can update their own `partners` row. Do not use the legacy `status` value as the authoritative approval source.
4. **Verification cases:** authenticated access observed is SELECT-only, scoped to own organisation or platform admin. This is safer than direct applicant writes, but no end-to-end reviewer workflow or decision audit was proven.
5. **Capability table:** authenticated SELECT is scoped by organisation membership; service_role has broad privileges. The single capability row is not evidence of approval. Matching must require verified organisation lifecycle, current compliance, approved capability, active service area, executed agreement and fresh capacity together.
6. **No live operating evidence:** there are no partner assignments, partner quotes, capacity availability/commitments, compliance evidence/reviews or performance events in the inspected tables. Do not show coverage, prices, capacity, partner availability or service-level promises from empty/test data.

No changes were made to address these findings because production migration history is unreconciled. All future changes must first be designed, tested in reconstructed staging, reviewed for tenant isolation and dual control, then delivered as forward-only migrations.

## 4. Recommended partner lifecycle

`discovered → invited → registered → submitted → identity_review → document_review → compliance_review → capability_review → commercial_review → approved → contracted → activation_ready → active`

Controlled exception states:
- `information_requested`
- `rejected`
- `expired`
- `restricted`
- `suspended`
- `terminated`
- `withdrawn`
- `under_investigation`

Rules:
- Registration and profile completion do not equal verification.
- Approval is scoped to a specific legal entity, service type, geography, mode and validity period.
- Contract execution is separate from compliance approval.
- Activation requires all release gates and a current reviewer sign-off.
- Suspension/restriction immediately blocks new matching and new assignments; existing shipments receive a controlled safety/continuity review.
- Expired mandatory evidence automatically makes the affected capability non-matchable until renewed and reviewed.
- Re-approval after material ownership, licence, insurance, safety, banking, legal-entity or operating-scope changes requires a documented reassessment.

## 5. Due-diligence evidence catalogue

Use configurable requirements by jurisdiction, provider role, mode and service. Examples for India (confirm applicability with qualified legal/compliance reviewers):

### Entity and authority
- legal name and entity type; registration/incorporation proof where applicable;
- PAN and GSTIN only where applicable/required; validate identifiers through authoritative sources;
- registered and operating addresses; beneficial ownership/control where proportionate;
- authorised signatory identity and authority; board/owner authorisation where applicable;
- bank account ownership only when a legitimate payment relationship requires it; do not collect bank details for mere discovery.

### Operational licences and permissions
- mode- and service-specific licences, permits, registrations and operating authorisations;
- vehicle registration, fitness, permit, pollution and other vehicle-specific evidence where applicable;
- driver licence class, endorsements and required training for assigned vehicle/cargo;
- warehouse occupancy, fire/safety and operating permissions where applicable;
- customs/freight-forwarding authorisations only where the provider actually performs those regulated services.

### Insurance and safety
- relevant motor, carrier, cargo, warehouse, public liability, workers/employer or professional cover as appropriate;
- insurer, policy scope, limits, exclusions, insured entity, geography and expiry;
- incident reporting, claims history and safety controls proportionate to risk;
- dangerous-goods/hazardous cargo training and permissions only where applicable.

### Compliance and conduct
- sanctions/restricted-party screening where legally required and proportionate;
- fraud/adverse-media checks with documented source, human review and false-positive resolution;
- anti-bribery, modern-slavery, data protection and security attestations where applicable;
- restricted cargo and prohibited goods acceptance rules; route/country-specific controls;
- tax and invoicing readiness, without representing KRIM as the freight supplier.

Never store excessive identity documents or sensitive personal data without a defined lawful purpose, access control, retention schedule and deletion process. Mask identifiers in routine UI/logs. Store files in private object storage with malware scanning, content-type/size controls, short-lived signed access and immutable evidence hashes. Do not put raw identity documents in public buckets or metadata JSON.

## 6. Independent review and decision controls

Roles should be separated:
- applicant/partner administrator: submits profile and evidence, responds to questions;
- intake analyst: checks completeness, not final approval;
- verification reviewer: validates entity, signatory and documents;
- compliance reviewer: assesses legal/safety/screening obligations;
- capability reviewer: validates modes, services, geography and resources;
- commercial approver: approves agreement and fee terms;
- activation approver: independent final maker-checker decision;
- platform security administrator: manages access, not evidence outcomes.

Controls:
- no reviewer may approve their own submission or evidence;
- high-risk cases require two independent approvals;
- every decision records actor, timestamp, reason, evidence version/hash, scope and expiry;
- rejected/expired evidence remains in immutable history; replacement creates a new version;
- overrides require a reason, authorised role, expiry and second approval;
- no self-approval via editable metadata, client-side flags or service-role calls without explicit server-side authorisation;
- every transition is enforced server-side with tenant binding and optimistic concurrency.

## 7. Capability and availability activation gates

A capability becomes matchable only when all conditions are true:
1. legal entity and organisation binding verified;
2. partner account mode is registered business (or a separately approved individual-provider route);
3. partner lifecycle is approved/active;
4. verification and compliance are verified/current;
5. required evidence is accepted and unexpired;
6. capability has explicit service/mode/geography/cargo scope and reviewer approval;
7. matching service area is active and current;
8. relevant agreement is executed and in force;
9. operating capacity is supplied by an authorised partner user and refreshed within a configured freshness window;
10. no restriction, suspension, unresolved critical finding or compliance hold exists.

Do not infer lane coverage from a broad country/region field. Do not infer vehicle availability from fleet registration. Capacity is time-bounded, resource-bound and must account for existing commitments. Match results must preserve the evidence snapshot and reasons the partner was eligible at match time.

## 8. Performance and ongoing monitoring

Only score actual, completed, attributable operations. Suggested measures:
- on-time pickup/delivery against agreed windows;
- completion and cancellation rates, with cause attribution;
- damage/loss/claims frequency and severity;
- POD/document completeness and timeliness;
- quote response and acceptance rates;
- capacity accuracy and no-show rate;
- customer complaints and independently resolved disputes;
- safety/compliance incidents and corrective-action closure;
- service-specific reliability and customer feedback.

Use minimum sample sizes, confidence intervals and recency weighting. Separate partner-controlled failures from customer, weather, infrastructure, customs or force-majeure causes. Never publish a score based on a single shipment or unverified self-reported data. Provide an appeal/correction process.

## 9. Required system architecture before implementation

- **Submission layer:** draft-only partner portal; strict field validation; consent and privacy notice.
- **Evidence vault:** private storage, checksum, malware scanning, versioning, access logs, expiry monitoring and retention/deletion.
- **Requirement engine:** jurisdiction/mode/service/cargo applicability with versioned sources and effective dates.
- **Review workspace:** queue, assignment, conflicts of interest, maker-checker, evidence comparison and decision reasons.
- **Lifecycle service:** server-side state machine; idempotent transitions; event history; suspension/expiry propagation.
- **Capability registry:** only approved and time-valid scopes feed matching.
- **Capacity service:** partner-submitted, time-bounded availability and commitments; freshness and overbooking controls.
- **Commercial gate:** executed agreement and fee schedule binding; partner freight contract remains directly between shipper and provider where applicable.
- **Monitoring:** scheduled expiry alerts, periodic review, incident-triggered reassessment and audit reporting.
- **Public discovery:** show only approved, current, explicitly permitted claims; hide draft, test, restricted and suspended profiles.

## 10. Required acceptance tests

1. Applicant cannot set their own verification, compliance, approval or activation status.
2. Applicant cannot alter reviewer, decision, review timestamp or immutable event history.
3. Partner A cannot read or modify Partner B's profile, checklist, evidence, files, capacity or case.
4. Customer cannot read partner confidential evidence, legal identifiers, insurance files or internal review notes.
5. A platform reviewer cannot approve their own submission.
6. A reviewer without the required jurisdiction/service authority cannot approve that scope.
7. Expired, revoked, mismatched or superseded evidence blocks affected capabilities.
8. A capability cannot be matched if agreement, service area or capacity is absent/expired.
9. Suspended/restricted partners are excluded immediately from new matches and assignments.
10. Partner profile edits do not silently change approved scope.
11. Duplicate submission/review requests are idempotent; concurrent approvals cannot create conflicting decisions.
12. Every approval, rejection, override, expiry and suspension is attributable and append-only.
13. Signed file URLs expire and are not exposed in logs, public pages or analytics.
14. Uploads reject unsupported content types, oversized files and malware.
15. A public page cannot display unverified claims or test organisations.
16. Scorecards exclude test data and retain the evidence basis and sample size.
17. Partner-specific records cannot be enumerated through guessed IDs (BOLA/IDOR tests).
18. Service-role Edge Functions validate caller identity, role, organisation, scope and allowed transition; they do not trust client-provided organisation IDs.
19. All approval paths fail closed if a requirement rule is missing or ambiguous.
20. Backup/restore preserves evidence hashes, decisions, events and current lifecycle state.

## 11. Release gates and next work

**Current state: NOT READY for live partner matching or public verified-partner claims.**

Priority order:
1. recover/reconcile migration source and schema export; reconstruct staging before database changes;
2. map every existing partner-related table, function, Edge Function, trigger, storage bucket and frontend writer;
3. define canonical organisation/legal-entity binding and retire or quarantine test/legacy partner identities;
4. close applicant-controlled verification fields and legacy document-status trust gaps through tested server-side workflows;
5. implement immutable evidence versions, reviewer decisions, dual control and expiry monitoring;
6. connect approved capability, service area, executed agreement and fresh capacity to matching;
7. test all acceptance cases, tenant isolation, concurrency and recovery in staging;
8. onboard one real partner with explicit authorisation, independently verify documents and agreement, then run a supervised non-custodial pilot.

No prospect was contacted, no partner was activated, no verification status was changed, and no production DDL or permission changes were made in this assessment.
