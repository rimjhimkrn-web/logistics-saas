# KRIM Partner Acquisition Workspace Journey, Verification Controls and Recruitment-Page Remediation Audit — 2026-11-16

## Executive decision

**Partner acquisition architecture exists, but it is not yet a proven end-to-end carrier activation workflow.** Registration, organization provisioning, identity review, compliance review, capability review and service-area review are separate workflows. That separation is good. However, onboarding-created capability rows do not carry the submitter/evidence metadata expected by the capability review RPC, and the public recruitment page previously made unsupported claims about shipper volume, guaranteed loads, escrow payouts and international corridors. The public page has now been corrected in source.

This was a source and read-only production review. No partner was contacted, no account or verification decision was created, no evidence was uploaded, and no production database, storage, Auth or partner state was changed.

## 1. Changes made to the public partner recruitment page

File updated: `public/partners.html`

Three commits:
- `e5c93b33150a67a8d665f636b71406841cfb14a7`
- `e2abbb0ec4a42cf86a832190a64a04ae05668fcc`
- `afb19b9ef684ac48b0f5219f42a2945af9d206be`

Corrections:
- Replaced "1,250+ enterprise shippers", guaranteed spot loads and instant escrow disbursement claim with a clear application/verification description.
- Removed claim of 140+ active international corridors.
- Replaced guaranteed escrow payout messaging with the current non-custodial model: customer contracts with and pays the logistics provider directly; KRIM does not hold, escrow, split or settle partner freight funds.
- Explained that opportunities depend on a relevant customer request, approved scope and confirmed capacity.
- Clarified that vehicle, driver, licence, permit, insurance and service-area evidence may be required.
- Corrected primary CTA to `auth/partner-signup.html`.
- Corrected partner sign-in CTA to `auth/partner-signin.html`.
- Removed an unsupported payment-delay/backhaul promise.

Remaining word "escrow" appears only in a sentence explicitly saying KRIM does not hold or escrow partner freight funds. The updated copy makes no claim of current partner volume, available loads, revenue or activated corridors.

## 2. Registration and account provisioning

Source reviewed: `auth/partner-signup.html`.

Positive controls:
- Separates registered-business and individual-interest pathways.
- Requires country, city and service category.
- Creates Supabase Auth identity and provisions a partner organization through `krim_provision_partner_organization`.
- Sets partner account mode through `krim_set_partner_account_mode`.
- Handles partial failure by telling the applicant not to register a duplicate account and to sign in to recover.
- Routes through authenticator enrollment before the partner workspace.

Limitations:
- Account creation and organization provisioning are separate operations, so recovery is important and must be exercised in staging.
- Registration does not itself create verified business status, capability approval, service-area approval or commercial eligibility.
- CAPTCHA/automated-signup protections and provider rate-limit configuration were not proven in this page audit; see the separate public authentication abuse audit.
- The UI path was not browser-executed in this audit.

## 3. Partner onboarding pathways

The existing onboarding lifecycle distinguishes:
- Registered business: business identity, address, country, service categories, coverage and private evidence submission.
- Individual interest: interest-only path; commercial access remains false.
- Development/test: non-commercial test path; commercial access remains false.

The existing core onboarding RPC requires active partner membership, matching active organization and registered-business mode. It scopes uploaded evidence to the organization and submitting user and creates/updates an open verification case. It sets verification/compliance pending and writes an audit event.

**Important:** a partner application is not an approval, and an individual-interest or development account must not be represented as a carrier available to serve freight.

## 4. Independent review stages

### Identity verification
The platform-admin verification queue uses the protected admin control function and requires a privileged admin role. The review RPC requires AAL2/admin permission and verifies that the submitted documents still exist and are owned by the original submitter. Approval marks identity verification as verified but leaves compliance pending.

### Compliance review
The compliance workspace requires AAL2 and a reviewer rationale. It collects baseline checks for business registration, tax registration, operating authority and insurance liability. Approval requires all checks to be verified or properly marked not applicable, plus an expiry date. The fixed baseline is not a substitute for jurisdiction-, mode-, service- and cargo-specific controls.

### Capability review
The capability review page is restricted to platform superadmin, requires AAL2 and calls the independent capability-review RPC. Approval requires a verified/compliant registered-business organization, current country/mode, evidence owned by the original submitter, submitter/reviewer separation and a documented approval basis. Hazardous-goods and cold-chain capabilities are held pending specialist controls.

**P1 workflow gap confirmed by prior detailed audit:** the multi-category onboarding RPC creates capability rows without the `submitted_by` and evidence metadata expected by the capability approval RPC. The reviewer cannot approve those rows as submitted; a separate evidence-backed capability submission may be required. The partner journey must clearly explain that additional step or the backend workflow must be reconciled. Do not bypass reviewer ownership or auto-approve.

### Service-area review
The platform-admin service-area queue is restricted to platform superadmin and provides short-lived signed evidence previews and a reasoned approve/reject RPC. An approved service area still does not establish a route/corridor approval, available capacity or a shipment assignment.

## 5. Live-state reminder

The last verified production snapshot from the partner due-diligence audit:
- 10 legacy partner records;
- 1 verification case, open and unassigned;
- 1 capability row, inactive/pending review;
- 0 approved service areas;
- 0 compliance evidence/reviews;
- 0 capacity resources/commitments;
- 0 partner-submitted quotes;
- 0 partner assignments.

The only verification case was associated with a development/test account. It is not evidence of a production-ready carrier. No partner should currently be displayed as verified, available or bookable based on these records.

## 6. Required partner lifecycle states

Use separate, evidence-backed states rather than one generic "approved" badge:

`prospect → invited → registered → submitted → identity_review → compliance_review → capability_review → service_area_review → commercial_review → contracted → activation_ready → active`

Controlled states: `information_requested`, `rejected`, `expired`, `restricted`, `suspended`, `terminated`, `withdrawn`, `under_investigation`.

Each approval must be scoped to legal entity, service, transport mode, cargo scope, geography, effective dates and evidence validity. Expiry or suspension must remove the affected capability from matching and new assignment eligibility. A verified entity must not automatically inherit every capability or service area.

## 7. Remaining blockers and recommended implementation order

| Priority | Gap | Required action |
|---|---|---|
| P0 prerequisite | Production migration history remains unreconciled | Finish sanitized schema manifest and migration crosswalk before any production DDL or RPC changes |
| P1 | Onboarding-created capability rows lack review-required submitter/evidence metadata | Reconcile onboarding and capability submission contract; preserve original uploader ownership and independent reviewer |
| P1 | Partner-facing stage/status view can be misunderstood as overall activation | Show identity, compliance, capability, service area, contract and market/corridor gates separately |
| P1 | Jurisdiction/service compliance is a fixed baseline | Derive required checks from approved country packs, service/mode/cargo and legal review |
| P1 | Service-area approval UI text says coverage is "now active" | Clarify it activates only the approved service-area record; route/corridor/capacity/booking remain separate |
| P1 | No end-to-end partner activation staging evidence | Test registered business, individual interest and development mode; cross-tenant access; evidence ownership; AAL2; maker-checker; rejection/resubmission; expiry and suspension |
| P2 | Applicant evidence lifecycle not fully tested | Verify upload limits, private read, signed preview, delete/orphan cleanup, retention and account deletion |
| P2 | Public signup anti-automation not proven | Add verified CAPTCHA/rate limits only after configuration review |

## 8. Required staging acceptance tests

1. Register a synthetic registered business; test Auth confirmation, organization provisioning, mode setup and recovery from each partial failure.
2. Register individual-interest and development/test accounts; prove neither gains commercial access.
3. Attempt cross-organization document path injection and evidence reference substitution; require rejection.
4. Upload invalid MIME, oversized, duplicate and expired documents; prove validation and cleanup.
5. Submit business identity; applicant cannot set reviewer-controlled status.
6. Verify identity approval requires privileged AAL2 and current owned evidence.
7. Verify compliance approval requires all applicable checks, evidence, expiry and independent reviewer.
8. Verify capability rows created by onboarding enter a reviewable evidence-backed queue without weakening ownership controls.
9. Verify service-area review requires an approved country operating pack and evidence.
10. Verify contract execution and market/corridor approval remain separate from identity/capability approval.
11. Suspend or expire one capability; prove it is no longer matchable and cannot receive a new assignment.
12. Verify every reviewer action is audited and audit failure prevents false success.
13. Verify applicant can see their own stage and missing items but cannot see another partner's data.
14. Confirm public page contains no unverified shipper counts, guaranteed loads, active corridors, escrow or payout claims.

## Release decision

**Partner recruitment page source is now materially more accurate, but the partner acquisition and activation journey remains NO-GO for declaring any carrier operationally verified or bookable.** Continue partner prospect research and evidence collection only through a controlled, clearly non-binding process. Do not activate a partner or expose capacity until the workflow gap, market/corridor gates and staging tests are complete.

No production partner record, verification status, capability, service area, capacity, contract, shipment or payment was created or changed.
