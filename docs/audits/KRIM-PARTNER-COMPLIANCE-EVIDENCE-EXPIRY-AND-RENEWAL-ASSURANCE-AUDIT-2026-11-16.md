# KRIM Partner Compliance Evidence, Insurance/Permit Validity and Renewal Assurance Audit — 2026-11-16

## Executive result

A partner-facing compliance evidence upload recovery improvement is committed. The audit also identifies a material lifecycle gap: the evidence register stores submission time and current/non-current state, but does not store each document's own issue date, expiry date, issuer verification, revocation state or renewal reminder state. Compliance review validity is recorded separately at review level; it is not a substitute for the expiry date of every insurance policy, permit, licence or registration document.

**Application change:** `1e50dd2918e0985a83bbb10bc8fc858ce0a779e4`  
**File:** `public/partner/compliance-evidence.html`

No production database, storage object, Auth user, partner, compliance evidence row, review decision, capability or service-area record was changed. No upload, deletion, compliance RPC or partner communication was performed.

## 1. Live production baseline (read-only)

Current live counts:
- Partner compliance evidence rows: 0
- Partner compliance review rows: 0
- External organization verification rows: 0
- Partner capabilities: 1 (pending/inactive in the latest prior detailed partner audit)
- Partner verification cases: 1

There is no production evidence of a currently reviewed insurance policy, transport permit, operating licence or tax registration for a KRIM carrier. Legacy active partner-directory rows must not be treated as approved carriers.

## 2. Existing evidence workflow

The partner page `public/partner/compliance-evidence.html`:
- permits only active, identity-verified registered-business partner organizations managed by the signed-in user;
- submits four baseline categories: business registration, tax registration, operating authority and insurance/liability;
- accepts PDF/JPEG/PNG, up to 10 MB each;
- supports reasoned not-applicable declarations;
- uploads to the private `krim-partner-verification` bucket;
- calls `krim_partner_submit_compliance_evidence`;
- states that submission is not approval or commercial activation.

The server-side RPC checks:
- active registered-business organization and partner.manage permission;
- verified business identity and approved/active lifecycle;
- valid organization jurisdiction;
- exactly four distinct required categories;
- category-specific organization/uploader path;
- matching Storage owner, MIME type and size;
- declaration length;
- records the four submissions and audit event.

The compliance reviewer is restricted to authenticated AAL2 platform administration. Approval requires four baseline checks, verified or reasoned not-applicable statuses, evidence references for verified checks, reviewer rationale and a review-valid-until value. The review validity window is limited to at most 365 days. Compliance clearance is separate from commercial activation.

## 3. Implemented upload recovery improvement

Previously, a failure after one or more successful uploads left private objects behind and the page displayed a generic error. It did not distinguish a failed upload from a database RPC that might have committed while the browser lost its response.

The updated handler:
- tracks exact uploaded object paths;
- attempts to remove only those paths when upload fails before the RPC begins;
- reports cleanup as successful only if Storage confirms removal;
- does not delete evidence after an RPC has been attempted, because the database may have committed despite a lost/ambiguous response;
- requires the RPC to return `success=true`, exactly four evidence categories, `status=submitted` and `commercial_activation=false`;
- tells the applicant not to retry until the evidence register is checked when the RPC outcome is ambiguous;
- clears the form only after a confirmed submission.

This is a client-side best-effort recovery improvement, not a durable transaction or proof that Storage cleanup works in every deployment.

## 4. Material lifecycle gaps

### P1 — Individual document expiry is not first-class

Live `krim_partner_compliance_evidence` columns include organization, category, object path, file metadata, submitter, submitted_at, is_current, submission_status and partner declaration. There are no first-class fields for:
- document issue/effective date;
- document expiry date;
- issuer/insurer/regulator;
- policy/licence/registration reference (sensitive values should be appropriately protected or hashed where possible);
- scope/territory/cargo/mode/vehicle coverage;
- independent verification source and checked_at;
- verification outcome/reason;
- revoked/cancelled/suspended state and effective date;
- superseded-by evidence reference;
- renewal due date or notification state.

A review-level `valid_until` cannot prove that an insurance policy or permit remains valid for the whole review period. One of the four categories may contain multiple different documents with different expiries and scopes.

### P1 — Four baseline categories are not a jurisdiction/service-specific checklist

The fixed four categories are a useful intake baseline only. Actual requirements must be derived from the partner's legal entity, jurisdiction, transport mode, service type, cargo, equipment, geography and operating role. For a domestic road carrier, this may include vehicle-specific registration/fitness/permit/insurance and driver-specific licence evidence. A single organization-level upload cannot prove every vehicle and driver is current.

### P1 — Insurance verification is not policy validation

An uploaded insurance certificate does not establish:
- exact named insured/legal-entity match;
- policy authenticity with the insurer/intermediary;
- coverage type and limits;
- cargo and mode scope;
- geographic territory;
- exclusions, deductibles and endorsements;
- cancellation/non-renewal status;
- claims contact and notification requirements.

Do not advertise a partner as insured based only on the existence of a file or a generic compliance approval.

### P1 — Reviewer independence

The prior identity/compliance integrity audit found that capability approval explicitly rejects self-approval, while identity/compliance review RPCs did not visibly apply the same submitter-versus-reviewer comparison. This must be corrected only after migration reconciliation and a full function-definition review. AAL2 alone does not guarantee reviewer independence.

### P1 — Expiry enforcement and suspension proof

The system needs proof that expired, revoked or mismatched documents immediately remove affected capabilities/service areas from matching and new assignments, while safely managing in-flight shipments. The current evidence schema does not expose individual expiry dates to enforce this reliably. Review validity expiry is not enough.

### P2 — Registry checks and renewal notifications are unpopulated

External organization/document verification tables currently have zero rows. Renewal reminder delivery, failed reminder retry, escalation and audit evidence have not been demonstrated. Do not claim that KRIM automatically monitors insurer, government registry or permit revocations.

## 5. Required evidence model before production schema work

After the migration manifest and crosswalk are reconciled, design an append-only evidence version model. Each document version should carry:
- organization and, where applicable, vehicle/driver/facility/capability association;
- evidence category and jurisdiction;
- issuing authority/insurer;
- masked or protected reference identifier;
- issue/effective/expiry dates and timezone semantics;
- mode, service, cargo, territory and asset scope;
- private object path, uploader, file hash, MIME/size and upload time;
- independent verification source, reviewer, timestamp, result and rationale;
- lifecycle state: submitted, under_review, verified, rejected, expired, revoked, superseded;
- replacement/supersession link and immutable audit history.

Never overwrite the prior evidence version. A renewal should create a new version and preserve the old record for audit. Expiry and revocation should be distinct states. A policy with adequate dates but inadequate scope must remain ineligible.

## 6. Required operational rules

1. At onboarding, verify the legal entity and the baseline categories.
2. Before capability approval, verify mode/service-specific authority and insurance scope.
3. Before vehicle activation, verify that vehicle's RC, fitness, permit, PUC and insurance as applicable.
4. Before driver assignment, verify driver identity and correct class/validity of licence.
5. Recheck current document state at quote, assignment, capacity reservation and dispatch boundaries.
6. Use an expiry buffer for upcoming expirations; do not wait until midnight on expiry day to alert.
7. On expiry/revocation, suspend only affected scope where safe, block new offers/assignments and create a review task; never silently invalidate or rewrite in-flight custody.
8. Provide applicant renewal upload and reviewer revalidation, preserving the previous version.
9. Maintain notification outbox, retries, dead-letter handling and proof of delivery; configured cron is not proof of notification.
10. Display exact verified scope and evidence freshness, not a generic "compliant" badge.

## 7. Staging acceptance tests

- Upload all four categories; verify exact organization/uploader ownership and audit event.
- Fail the second or fourth upload; verify exact partial object cleanup and no evidence rows.
- Deny cleanup; verify page does not claim deletion and blocks unsafe retry guidance.
- Simulate RPC timeout after server commit; prove the UI does not delete referenced files or encourage duplicate submission.
- Submit the same evidence packet twice; test concurrency and current-version semantics.
- Attempt cross-tenant object path, mismatched MIME/size and owner substitution.
- Verify each category's not-applicable declaration requires reviewer scrutiny and cannot silently bypass mandatory legal controls.
- Test issue/expiry dates, future-dated documents, expired documents, cancelled policies, changed named insured, wrong territory, excluded cargo and mismatched vehicle.
- Test expiry warning, expiry suspension, revocation and replacement without disrupting in-flight custody.
- Test reviewer cannot approve own submission; test AAL1 denial and audit-event failure.
- Verify public partner discovery, matching, quote, assignment and dispatch all fail closed for expired or revoked required evidence.
- Verify renewal notification retries and dead-letter alerts in staging.

## 8. Change control and release decision

The production migration history remains unreconciled (558 production migration rows versus 363 repository SQL migration files, with substantial name/timestamp mismatches). Therefore no evidence schema, expiry trigger, review RPC or production policy changes were made.

**NO-GO for claiming partner compliance, valid insurance, current permits, automated expiry monitoring or commercial readiness.** The current UI improvement only reduces orphaned partial uploads and duplicate-retry risk. KRIM still has zero compliance evidence/reviews and no approved operational partner capability in the last verified snapshot.


## 8. Follow-up verification and corrective addendum — 16 November 2026

A fresh live read-only review confirmed the Storage bucket is private with a 10 MiB limit and PDF/JPEG/PNG allowlist. It also confirmed that the current Storage DELETE policies in this bucket cover customs, claims, capacity and service-area evidence, but no policy authorizes an applicant to delete their own unregistered `{organization_id}/{user_id}/compliance-...` uploads.

Accordingly, the compliance evidence page was corrected in commit `26739539307bf6c8b33cd499e13258f78fa3ec0f` so it does **not** attempt an unauthorized delete after partial upload. It explicitly warns that partial private files may remain and that the applicant should contact support before retrying. It continues to retain files when the RPC response is ambiguous.

Fresh live counts:
- compliance evidence rows: 0;
- current evidence rows: 0;
- compliance review rows: 0;
- approved review rows: 0;
- approved reviews whose validity date has passed: 0;
- active verified registered-business partner organizations: 0.

No compliance-specific expiry cron job was found. The existing partner assignment expiry job is unrelated.

The live helper `private.krim_partner_compliance_is_current(bigint)` checks that the latest review is approved, has a non-null future `valid_until`, and the organization remains active, identity-verified and compliant. Live function-reference inspection found this helper is referenced by the following operational paths: capacity availability publication, dispatch authorization guards, driver assignment, partner quote award/listing/submission, dispatch, driver acceptance, capacity registration/reservation, service-area submission, capability submission, assignment response and operations dispatch readiness. This is positive request-time fail-closed coverage, but does not prove every UI badge, public directory, API or future workflow uses it.

No scheduled process was found to update denormalized organization status or issue renewal reminders at the review expiry date. Because the helper checks the date at runtime, the partner should fail the helper even if the organization row still displays `compliant`; user interfaces and any unreviewed consumers must not rely on the denormalized field alone.

**Correction to the earlier proposed recovery approach:** do not claim applicant-side cleanup is available under current policies. Any future cleanup must be an explicit least-privilege, auditable worker or staging-tested policy, and must delete only exact objects proven unreferenced. No production policy or worker was added.
