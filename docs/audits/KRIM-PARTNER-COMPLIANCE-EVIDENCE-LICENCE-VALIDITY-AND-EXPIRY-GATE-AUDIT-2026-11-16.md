# KRIM Partner Compliance Evidence, Licence Validity and Expiry-Gate Audit — 2026-11-16

## Executive decision

**NO-GO for partner commercial activation and live logistics execution remains unchanged.**

This read-only production audit examined the registered-business compliance evidence submission page, AAL2 administrator review page, compliance RPCs, validity helper, capability approval, capacity registration, service-area approval, quote submission and dispatch authorization dependencies.

A small administrator UI clarification was committed. No production data, partner status, compliance decision, capability, Storage object, Auth record, database function, policy, cron job or schema was changed.

## Production snapshot

- Compliance evidence rows: **0**.
- Current compliance evidence rows: **0**.
- Compliance review rows: **0**.
- Approved compliance reviews: **0**.
- Logistics organization state: one development/test partner account remains pending; other returned logistics organization rows are not commercial registered-business partners.
- Partner capability rows: **1**, pending and inactive.
- Active partner capabilities: **0**.
- No production evidence documents were uploaded or opened in this audit.
- No partner compliance review was submitted or approved.

Counts are point-in-time read-only results, not evidence of a completed partner onboarding journey.

## Positive controls confirmed

### 1. Partner evidence submission
The current `public/partner/compliance-evidence.html` page:
- requires a signed-in user and active organization membership;
- restricts the UI to eligible registered-business partner organizations;
- submits exactly four categories: business registration, tax registration, operating authority and insurance/liability;
- supports an explained `not_applicable` declaration for a category;
- limits uploads to PDF/JPEG/PNG and 10 MB per file in the browser;
- uses private `krim-partner-verification` storage and an organization/user/category-specific UUID path;
- invokes `krim_partner_submit_compliance_evidence` only after uploads;
- attempts cleanup only when an upload fails before the RPC is attempted;
- retains files after an ambiguous RPC outcome and warns against retrying until reconciliation;
- confirms submission only when the server returns the expected four-category submitted state and commercial activation false.

The database RPC independently validates partner manager permission, organization state, jurisdiction, four distinct categories, file path, MIME, size, Storage owner and object metadata. It records a new evidence generation, marks prior evidence as not current, writes an audit event and does not grant commercial activation.

### 2. Independent review
The administrator review page requires AAL2 and platform-admin permission. The review RPC independently enforces:
- active registered-business organization and verified business identity;
- exact four baseline checks;
- current submitted object path, category, owner, MIME and size for each verified check;
- rationale for not-applicable checks;
- independent AAL2 platform reviewer;
- review validity required for approval and bounded to the next 365 days;
- no approval while any check is pending or rejected;
- atomic review-row, organization-state and audit-event changes.

### 3. Expiry gate
`private.krim_partner_compliance_is_current` returns true only when:
- the organization is active, registered-business, verified and approved/active;
- the latest compliance review is approved;
- the latest review has a non-null `valid_until`;
- `valid_until > now()`.

The source review confirmed this helper is referenced by important workflows, including partner capability approval, capacity resource registration, service-area approval, quote submission and dispatch authorization. Thus expiry is enforced at these sensitive decision points even though there is no scheduled status-flipping job.

## Findings

### P1 — Document-level expiry is not structured
The four-category evidence table has submission timestamp and file metadata but no separate issue date, expiry date, issuing authority, policy number, renewal window or supersession fields for each document.

The review stores a single overall `valid_until` timestamp. The reviewer page previously presented this as a generic review-validity date without explaining that it must not extend beyond the earliest applicable underlying licence, permit or insurance expiry.

**UI clarification committed:** the review form now tells reviewers to inspect every submitted document and set the overall compliance expiry no later than the earliest applicable document expiry. It explicitly states that the current workflow does not independently track each document's expiry or send automated renewal reminders.

This is an instruction to the human reviewer, not an automated validation of the document dates.

### P1 — No automated partner renewal reminder or pre-expiry workflow
No active cron job or scheduled command matching partner compliance expiry/reminder processing was found in the inspected production cron catalogue.

The expiry gate is checked when protected actions are attempted. That is fail-closed for the inspected actions, but it does not notify the partner in advance, collect replacement evidence, create a renewal case or give operations a proactive expiry queue.

### P1 — Compliance rejection has no clearly evidenced resubmission path
A rejected compliance review sets the organization to `non_compliant` and lifecycle `restricted`. The partner evidence submission page only offers organizations with approved/active lifecycle state, and the administrator compliance queue likewise lists only approved/active lifecycle organizations. The inspected workflow therefore does not establish a complete partner-initiated remediation/re-review path after rejection.

An `on_hold` decision keeps lifecycle approved and compliance pending, which leaves a route for additional evidence submission. Rejection recovery needs an explicit, audited workflow rather than relying on support intervention or direct database edits.

### P2 — Expiry gate does not physically deactivate capability records
The compliance helper prevents protected actions that explicitly call it. It does not itself update every previously approved capability to inactive, nor does it write an expiry event or suspend service-area rows when a review expires.

This distinction must be maintained in reporting:
- expired compliance means protected actions that re-check the helper should fail closed;
- it does not prove all capability/service-area status rows were automatically changed;
- dashboard counts and partner-facing status must not present stale active flags as current operational authority.

A future status projection or scheduled process must be designed only after dependency review and migration reconciliation. It should not weaken the live helper gate.

### P2 — No document malware/content validation evidence
The current workflow validates file metadata and ownership. This audit found no demonstrated malware scan, PDF content validation, image authenticity check or document authenticity verification integration. File extension/MIME and uploader ownership do not prove the document is genuine or legally sufficient.

### P2 — Renewal replacement and supersession need end-to-end tests
The submit RPC marks previous evidence rows not current and inserts a new set. This preserves historical rows, but no staging test has verified:
- previous evidence remains auditable and no longer qualifies as current;
- a partially uploaded replacement cannot invalidate the last accepted review;
- a new submission does not silently preserve an old approval beyond its intended scope;
- reviewer decisions always bind to the exact current evidence generation;
- an expired/replaced policy cannot be accidentally reused for a later category review.

The current review RPC binds each verified item to a current evidence row and its exact object path/owner/MIME/size, which is a positive control.

## Repository change

Administrator review page:
`app/platform-admin/partner-compliance.html`

Commit: `4804a14f17a221a666f7364e1b415fbc799a955c`

Changes:
- renamed the date field to make clear it is the overall compliance expiry;
- instructed reviewers to set it no later than the earliest applicable source-document expiry;
- clarified that individual document expiry tracking and automated renewal reminders are not implemented;
- clarified that quote, capacity, service-area and dispatch authorization workflows re-check the compliance gate.

No review or approval was submitted.

## Recommended next engineering sequence

1. Define structured per-document metadata: document category, issuer, jurisdiction, reference number (masked where appropriate), issue date, expiry date, source object path, uploader, review state, reviewer, review timestamp, superseded-by reference and retention classification.
2. Add a durable evidence-generation ID and bind every review decision to that generation.
3. Create a partner-visible read-only compliance status and renewal timeline based on authoritative review records.
4. Add reminder orchestration at configurable lead times, with consent/notification preferences and delivery/retry observability. Do not mark a reminder delivered merely because a provider accepted a request.
5. Define explicit renewal, hold, rejection, remediation and re-review transitions with maker-checker controls.
6. Add staging tests for expiry boundary (just before, exactly at, and just after expiry), timezone boundaries, earliest-document-expiry rule, replacement, concurrent review/submission, rejection recovery, revoked membership and cross-tenant evidence access.
7. Reconcile production migration history before any DDL, cron changes, trigger changes or backend remediation.

## Verification and change control

- Read-only production catalog/function/data inspection completed.
- Current partner evidence and compliance submission pages source-reviewed.
- AAL2 administrator review page source-reviewed.
- Compliance gate helper and protected workflow references source-reviewed.
- No production upload, download, signed URL, delete, RPC, review or partner action performed.
- No SQL migration or production DDL performed.
- Browser E2E and staging tests not performed.

## Release gate

KRIM remains **NO-GO for partner commercial activation, real shipment execution and financial collection**. No verified commercial partner, current compliance review, approved capability or approved service area was evidenced in the production snapshot.
