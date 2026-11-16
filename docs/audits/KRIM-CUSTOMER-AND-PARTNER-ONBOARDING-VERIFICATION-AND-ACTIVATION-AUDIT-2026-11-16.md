# KRIM Customer and Partner Onboarding Experience, Verification and Activation Audit
**Date:** 16 November 2026  
**Scope:** Read-only review of customer and partner registration/onboarding pages, partner workspace pathways, business verification, compliance evidence, service-capability submission/review, selected live PostgreSQL RPC definitions and production record counts. No account was registered, no onboarding RPC was invoked, no documents were uploaded, no verification or compliance decision was made, and no production data or schema was changed.

## Executive decision
**NO-GO for opening broad external customer/partner self-service onboarding as a fully verified operational journey.** KRIM has a meaningful partner registration and evidence-review design, including distinct development, individual-interest and registered-business pathways. Several important server-side safeguards exist. However, the customer onboarding page is currently a static workflow guide rather than a complete customer setup flow; production contains almost no evidence of real partner onboarding, compliance or capability completion; and the registration-to-verification journey has unresolved consent, retry, evidence ownership and operational-readiness gaps.

This is an experience and workflow audit, not a claim that every underlying RPC or workspace has been exhaustively tested. All conclusions below distinguish source/catalog inspection from actual user journey proof.

## 1. Live production baseline
Read-only exact counts at the audit snapshot:

| Object | Rows |
|---|---:|
| Organizations | 14 |
| Organization memberships | 13 |
| Partner verification cases | 1 |
| Partner capabilities | 1 |
| Partner compliance evidence | 0 |
| Partner compliance reviews | 0 |
| Partner onboarding checklists | 0 |
| Partner service areas | 0 |
| Partner capacity availability | 0 |
| Partner capacity commitments | 0 |
| Shipment capacity commitments | 0 |
| Organization verification records | 0 |
| Organization onboarding records | 0 |
| Document verification records | 0 |
| Legacy partner records | 10 |
| Legacy partner document records | 0 |

The single capability is pending and inactive. The single verification case does not establish a completed partner admission journey. There is no production evidence of a partner completing compliance evidence submission, service-area approval or capacity activation. Legacy partner rows are not proof of verified organizations or service coverage.

## 2. Customer onboarding journey
### Current experience
- Legacy customer onboarding and verification routes redirect to canonical Customer OS pages.
- The canonical `public/customer-os/customer-services/onboarding.html` currently presents workflow guidance (verify sign-in and active organization, use canonical records, confirm server persistence). It does not itself provide a complete customer organization creation, profile completion, team setup, consent capture or identity-verification journey.
- A server-side `krim_provision_customer_organization(p_legal_name)` routine exists. Static definition review shows it requires `auth.uid()`, validates the organization name, serializes per-user provisioning with an advisory lock, reuses an existing active customer/enterprise membership where available, otherwise creates a customer organization, owner membership, role assignment and audit event in one transaction.
- This RPC definition is positive evidence of a controlled provisioning primitive, not proof that the full customer registration journey is connected and tested end to end.
- The customer/enterprise reuse behavior and organization type boundary should be tested: the routine may return an existing enterprise organization when it is the user's first active customer/enterprise membership. This is not automatically wrong, but customer onboarding must not silently create or attach the wrong tenant type.

### Customer gaps
1. **P1 — Incomplete customer-facing onboarding:** no complete, verified flow was found for business profile, billing/contact details, authorized users, customer identity verification, consent preferences, onboarding status and support handoff.
2. **P1 — Tenant binding and org selection:** the customer experience must explicitly resolve one correct active customer organization and must not infer authority from account metadata or a selected workspace label.
3. **P1 — Consent evidence:** the wider CRM audit found privacy acknowledgement and marketing/communications consent are not equivalent. Customer onboarding must record separate, versioned, purpose-specific consent and withdrawal events; a checkbox or editable user metadata field is not a durable consent ledger.
4. **P1 — No completed journey evidence:** live customer organizations/memberships do not by themselves prove a real customer completed profile, verification, quote, contract or shipment workflows.
5. **P2 — Canonical routes:** retired route redirects should remain consistent and all destination pages must enforce authorization independently.

## 3. Partner registration and pathway experience
### Positive controls observed
- `auth/partner-signup.html` offers distinct registered-business and individual-interest paths and explains that account creation is not business verification or commercial activation.
- The registration script calls Supabase Auth sign-up, then the authenticated `krim_provision_partner_organization` RPC, then `krim_set_partner_account_mode`. The user is told not to register again if a later provisioning step fails and to sign in to retry.
- `krim_provision_partner_organization` requires an authenticated user, validates the legal name, serializes provisioning per user, blocks ambiguous multiple active partner organizations, creates the organization, owner membership, partner/owner role assignments, pending verification case and audit event.
- `krim_set_partner_account_mode` only operates on exactly one active partner organization and supports `development_test`, `individual_interest` and `registered_business`. It records the mode and an audit event; its response explicitly says commercial access is false. It blocks switching an already approved/active partner into a non-commercial pathway.
- The partner gateway checks server-authenticated user identity and active organization membership before routing to the selected pathway. It does not grant permissions itself.
- The registered-business onboarding form associates uploaded files with the selected organization and signed-in user path, submits a separate business verification packet, and explicitly states that submission is not approval or permission to accept shipments.
- Development/test mode is described as non-commercial and individual-interest as an expression of interest, not identity verification.

### Partner gaps and risks
1. **P1 — Multi-step sign-up partial completion:** Auth account creation, organization provisioning and account-mode selection are separate network operations. A failure after Auth sign-up can leave a valid Auth identity without confirmed organization/pathway completion. The UI advises retry, but no complete recovery state or reconciliation dashboard was proven. Add idempotent resume/reconcile behavior and visible progress without encouraging duplicate accounts.
2. **P1 — Terms acceptance is not a consent ledger:** registration stores `terms_accepted` and a terms version in user metadata. User metadata is editable and should not be treated as authoritative proof of acceptance. Record the exact terms/privacy versions, purpose, timestamp, actor, policy text/hash and withdrawal/change events in a server-controlled immutable consent history. Keep contractual acceptance separate from marketing consent.
3. **P1 — Business evidence owner check at initial submission:** the inspected global v2 business-onboarding routine checks that evidence objects exist in the private bucket and that their paths contain the target organization and submitting user IDs, but does not itself compare Storage object ownership to the authenticated user. The later business-verification reviewer does compare owner metadata for approval, so the reviewed path does not prove an unauthorized approval bypass; however, submission should fail early on wrong-owner objects and staging must test path spoofing and cross-tenant substitution.
4. **P1 — Customer and partner onboarding state are not a single journey:** organization status, partner account mode, business verification, compliance, individual capability, service area, capacity and contract status are separate. UI must show these as distinct gates and never collapse them into a generic “verified” badge.
5. **P1 — Development/individual pathways:** ensure these pathways cannot submit commercial compliance, capability, quote, assignment or capacity actions, even through direct URLs or forged client state. Backend authorization remains the source of truth.
6. **P2 — Registration uses client session state:** some onboarding initialization reads `getSession()`; server RPCs still check `auth.uid()`, but the client should use server-verified `getUser()` for identity-dependent UI and handle expired/revoked sessions consistently.
7. **P2 — Recovery messaging:** after partial failure, do not display a generic registration failure that prompts another sign-up. Provide an explicit “account exists / resume setup” route and a safe correlation reference.

## 4. Business verification and evidence review
### Positive controls observed
- Partner business verification is a distinct administrator review from compliance and capability approval.
- The verification queue is protected by platform-admin authorization and AAL2; the database review routine also checks authentication, AAL2 and `admin.platform`.
- Approval requires registered-business mode, an active eligible logistics organization, required legal identity and location metadata, a submitted registration document, private storage object existence and submitter ownership. Rejection requires a reason; decisions are written to audit events.
- The administrator interface labels approval as business identity only and says compliance and service capability remain separate.
- Private evidence previews use short-lived signed URLs (60 seconds) in the reviewed interface.
- The review interface prevents a business decision for development/test or individual-interest pathways.

### Findings
1. **P1 — Human evidence review is not official verification by itself:** document inspection must be independently validated against the relevant official registry/issuer where appropriate. The interface correctly disclaims legal certification; operational procedure and evidence sources still need to be formalized.
2. **P1 — No expiry/renewal lifecycle proof:** current source review does not establish a complete automated expiry, renewal, revocation, suspension and in-flight work process for every business licence and registration document.
3. **P1 — Organization identity conflict handling:** staging must test duplicate legal identity, multiple organizations for one user, conflicting registration numbers, organization type changes and re-submission after rejection.
4. **P2 — Signed-link controls:** short expiry is positive, but expiry, revocation, wrong-tenant access and access logging must be tested against real private objects.

## 5. Compliance evidence and review
### Positive controls observed
- Partner compliance evidence submission requires an authenticated manager with `partner.manage` for the exact organization, an active registered-business organization, verified business identity and an approved/active partner lifecycle.
- The RPC requires exactly four baseline categories: business registration, tax registration, operating authority and insurance/liability. Each may be uploaded or marked not applicable with a reasoned declaration.
- Uploaded evidence paths are bound to organization and user, and the server verifies Storage object owner, MIME type and size (maximum 10 MB) against the actual object metadata.
- Not-applicable declarations require a bounded explanation. The submission is audited and explicitly returns `commercial_activation=false`.
- The compliance review interface requires an AAL2 administrator session and keeps compliance clearance separate from capability, capacity, contract and final activation.

### Findings
1. **P1 — Baseline checklist is not a universal legal checklist:** the interface acknowledges this. Requirements must be determined by actual jurisdiction, entity, service, cargo and mode; a fixed four-category template cannot establish legal compliance for every country or service.
2. **P1 — Not-applicable declarations need governed acceptance:** declarations must be reviewed with reasons, reviewer identity, jurisdictional source and validity period; “not applicable” must never silently satisfy a legally mandatory control.
3. **P1 — Compliance evidence/review is not operationally populated:** current live counts are zero. The code path is not evidence that any partner has been cleared.
4. **P1 — Revalidation:** evidence expiry, insurer/issuer confirmation, policy coverage, territorial scope, exclusions, suspension and revocation must invalidate new commercial eligibility promptly.
5. **P2 — Evidence lifecycle:** verify replacement/supersession, retention, secure deletion, audit preservation and recovery from upload success/database failure.

## 6. Service capability submission and approval
### Positive controls observed
- Capability requests are separate from business identity and compliance review.
- The partner capability UI distinguishes recorded capability rows from approvals and real-time availability.
- The server-side capability submission functions require an authenticated organization member with the relevant partner permission and accept evidence paths; the v2 wrapper validates structured submission details and calls the underlying guarded routine.
- Capability review is an AAL2 platform-admin operation. The reviewer checks organization status, registered-business mode, current compliance, active country and transport mode, evidence paths, owner metadata, effective dates and valid limits.
- Hazardous-goods and refrigerated capability approval are deliberately blocked in the standard workflow pending specialized evidence/controls.
- Capability review rejects self-approval, requires a documented decision, and writes an audit event.
- The admin list function excludes capability rows whose evidence paths, submitter identity, organization/user path or Storage owner metadata do not meet its evidence gate; incomplete pending records are separately counted/held.

### Findings
1. **P1 — Capability approval is not route activation:** an approved service mode/country/region does not prove a corridor is legally activated, a partner has approved service areas, available equipment or time-window capacity, or an accepted assignment.
2. **P1 — Category mapping needs validation:** multi-category onboarding maps broad categories to transport modes/service types. Test every category mapping, especially warehouse, customs, cargo insurance, inspection, port/terminal and multimodal categories, so non-carrier services are not accidentally treated as ordinary freight transport.
3. **P1 — No empirical capability/capacity evidence:** one pending inactive capability exists; service-area and capacity records are zero. Do not publish partner coverage or availability from declared profile data.
4. **P2 — Evidence scope:** capability evidence must be tied to the exact mode, equipment, service, country, region, validity period and limits—not merely to the organization.

## 7. Workspace and user-facing truthfulness
- Partner pathway pages and the partner gateway correctly distinguish development, individual interest and registered business.
- The partner capabilities page correctly says a record is not proof of equipment ownership, licence validity, insurance, route availability or shipment eligibility.
- Customer-facing and partner-facing surfaces must consistently distinguish: account created; organization provisioned; business identity submitted; business identity approved; compliance submitted/cleared; each service capability approved; service area approved; capacity available; commercial agreement executed; corridor/market active; shipment-specific eligibility; assignment accepted; dispatch authorized.
- No badge, KPI, map or public directory may imply verified partner count, live coverage, service availability, performance rating or bookability without current evidence-backed records.

## 8. Required staging-only acceptance tests
1. Customer signup: email confirmation, duplicate registration, recovery after partial Auth/org provisioning, idempotent retry and wrong organization reuse.
2. Partner signup: Auth success followed by RPC failure at each step; resume without duplicate identity, organization, role or verification case.
3. Terms/privacy: versioned acceptance, separate marketing consent, withdrawal, re-consent, audit immutability and no reliance on editable user metadata.
4. Partner modes: development and individual-interest accounts cannot call commercial actions through UI or direct RPC; registered-business mode remains non-commercial until all gates pass.
5. Business evidence: wrong bucket, wrong owner, cross-organization path, forged user folder, duplicate file, unsupported MIME, oversize, expired/revoked evidence and signed URL expiry.
6. Business review: self-approval, wrong org type, inactive org, missing registration metadata, duplicate legal identity, rejection/resubmission, concurrent review and audit failure.
7. Compliance: all four categories, missing category, duplicate category, not-applicable rationale, wrong issuer, wrong jurisdiction, expired insurance, policy exclusions, evidence replacement and withdrawal.
8. Capability: wrong tenant, unsupported mode, inactive country, no evidence, wrong owner, self-approval, expired effective dates, hazardous/refrigerated specialized gates and category mapping.
9. Immediate revocation: membership, role, business verification, compliance, capability, licence and organization suspension while a session is open.
10. Customer/partner journey: synthetic quote and acceptance in staging only; no live shipment, dispatch, payment, capacity reservation or partner contact.

None of these end-to-end staging scenarios was executed in this audit.

## 9. Remediation order
1. Build one customer onboarding experience backed by canonical organization membership, profile, contact, billing and consent records; remove placeholder-only workflow expectations.
2. Make signup and organization provisioning resumable/idempotent, with a durable setup state and support correlation ID.
3. Replace user-metadata-only terms acceptance with server-recorded versioned consent/contract acceptance events.
4. Enforce Storage owner, organization path, MIME, size and evidence-category checks at initial business onboarding as well as review.
5. Establish jurisdiction/service-specific compliance requirement packs, source provenance, expiry/revalidation and governed not-applicable decisions.
6. Complete capability category mapping and exact service-area/capacity activation dependencies.
7. Add staging acceptance coverage for the ten test groups above and verify direct-route/backend enforcement.
8. Only after migration reconciliation may production schema/function/policy remediation be considered.

## 10. Change control and release decision
This was a read-only audit. No user or organization was registered, no invitation was sent, no partner was contacted, no document was uploaded, no capability or compliance decision was made, no RPC was invoked, and no production schema, policy or function was changed.

The production/repository migration crosswalk and sanitized schema manifest remain unresolved. Do not apply schema/function/policy changes or retire legacy routines until reconciliation is complete.

**Release status: NO-GO for broad self-service customer/partner onboarding as a certified operating journey, and NO-GO for claims of verified partner coverage or live capacity.** The partner pathway and evidence-review foundations are useful, but production adoption and end-to-end verification are not demonstrated. Financial collection remains deferred to the final phase.
