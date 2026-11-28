# KRIM Fast-Track Day 1 — Versioned Partner Onboarding Correction Design
Date: 2026-11-28
Environment: Staging only
Project: qrpcivhdxobiaofppbkl
Status: DESIGN GATE — no implementation or deployment

## Evidence refreshed
Read-only Staging inspection reconfirmed:
- The deployed multi-category onboarding RPC is SECURITY DEFINER with an empty search_path and enforces authenticated AAL2 plus active registered-business partner membership.
- It validates 1–13 unique categories and a matching coverage entry for each category.
- It delegates the organization/verification-case submission to krim_submit_partner_onboarding_global_v2.
- The base v2 function accepts only ROAD_FTL, OCEAN_NVOCC, AIR_CHARTER or INTERMODAL_RAIL and creates/updates an organization-level capability as part of onboarding.
- The multi-category wrapper substitutes ROAD_FTL when the first selected category is not one of those four.
- The wrapper then creates or updates per-category capability rows as inactive/pending declarations, but does not set submitted_by, submitted_at or evidence_paths.
- Its UPDATE path unconditionally sets active=false and verification_status='pending', which can downgrade an already-reviewed row on resubmission.
- The independent evidence-backed capability submit RPC creates a new pending row and rejects a duplicate pending capability for the same org/mode/service/country/region.
- The independent admin review RPC requires the submitter identity and 1–5 private evidence files under <org>/<user>/capability/, with actual Storage ownership validation.
- The current onboarding UI sends organization-level document paths only; it does not send capability evidence.

The capability table has a primary key, foreign keys and validation checks, but no unique constraint enforcing category declaration identity. A new implementation must not assume category metadata is uniquely constrained.

## Required correction architecture
Do not replace or mutate the existing RPC in place. Add a versioned, compatibility-preserving path after the full call graph and migration baseline are reviewed.

### A. Separate organization verification from service capability records
The current base onboarding RPC conflates organization verification with creation of a transport capability. A replacement onboarding path should use a dedicated internal organization-verification submission helper that:
- validates the existing organization, membership, legal identity, registration document ownership and private bucket object;
- creates/updates the organization verification case and organization metadata atomically;
- does not invent ROAD_FTL when the selected categories are only warehouse, customs, insurance, inspection or other non-road services;
- writes an audit record with the authenticated actor;
- retains existing AAL2 and registered-business checks.

Do not remove the existing base RPC or alter its semantics until all callers and compatibility requirements are known.

### B. Treat selected categories as declarations
Category declarations remain inactive and pending until a separate evidence submission and independent review.
- Persist a server-derived submitter UUID and submitted timestamp.
- Store category, country, region/city and onboarding case correlation.
- Prevent resubmission from silently downgrading verified, rejected, suspended or otherwise reviewed records.
- Do not overwrite reviewed evidence or review history.
- Require an explicit new submission/version or reviewer-directed reopen operation for changes to a reviewed declaration.

### C. Add a dedicated evidence-attachment submission contract
The safest candidate is a new authenticated RPC that locks one exact pending category declaration and attaches evidence to that existing row rather than trying to INSERT a duplicate row through the generic capability submission RPC.
- Caller supplies only declaration/capability ID, evidence paths and bounded non-authoritative details.
- Derive user identity exclusively from auth.uid(); never accept submitter or reviewer IDs from client JSON.
- Verify active partner membership and permission for the exact organization.
- Lock the target row and require pending status, expected organization, and category/declaration state.
- Require 1–5 distinct evidence paths with exact <org>/<auth.uid()>/capability/<filename> format.
- Validate every object exists in the private krim-partner-verification bucket and is owned by auth.uid().
- Validate all evidence before any mutation; transaction rollback must leave no partial metadata.
- Preserve old evidence versions in append-only submission/audit history; do not silently replace evidence.
- Keep capability inactive/pending. Only the existing independent AAL2 admin review RPC may approve/reject.
- Add idempotency/replay protection and bounded JSON/string sizes.
- Explicitly block hazardous-goods and refrigerated activation until specialist evidence controls are implemented.

### D. Frontend compatibility
- Keep organization-level registration/insurance documents in the current onboarding flow.
- Make the Services & Capabilities evidence screen target the selected declaration ID and call the new attachment RPC.
- Do not call the current insert-oriented capability RPC for a declaration that already exists.
- Show a clear pending-evidence/review state and retain submission history.
- Do not expose admin approval actions in partner UI.
- Enumerate any additional callers before changing shared client helpers or RPC names.

## Required test matrix before any Staging deployment
1. All 13 categories, including non-transport-only onboarding, and mixed categories.
2. Each category maps to an active country/mode/service mapping; missing mapping fails atomically.
3. Category array duplicate, missing coverage, extra coverage, malformed JSON and unknown category.
4. Organization registration evidence missing, foreign, wrong owner, wrong bucket and malformed path.
5. Capability evidence missing, duplicate, wrong org, wrong user, wrong folder, wrong bucket, nonexistent object and >5 files.
6. Caller cannot forge submitter/reviewer, organization, evidence ownership or reviewed status.
7. Concurrent evidence submissions serialize safely; replay is idempotent.
8. Existing verified/rejected/suspended declaration is never silently reset or overwritten.
9. Independent admin reviewer cannot self-approve; non-owner/non-AAL2 cannot review.
10. Rejection/approval requires appropriate reason; approval requires current compliance and evidence.
11. Failed validation leaves organization case, declaration, evidence history and audit state unchanged.
12. Existing legacy caller continues to work unchanged during migration/rollback window.
13. RLS, grants, SECURITY DEFINER search_path, function ACL and advisor checks are reviewed.

## Implementation blockers
- Original source migration for the deployed multi-category wrapper remains unrecovered.
- Full repository-wide dynamic/indirect/server-side caller inventory is not yet certified; targeted 115-file partner scan found one direct caller.
- Exact schema and lifecycle for category declaration identity/history must be designed before coding.
- No local PostgreSQL test harness result or automated integration test has been run for this new contract.
- No owner-retained encrypted export artifact was available through GitHub Actions API.

## Supabase CLI caution
Supabase published a breaking CLI v3 change on 2026-11-04: database commands now default to local, and hosted changes require explicit remote targeting and confirmation; unattended CI requires --yes. Any future CI work must pin/verify the CLI version and explicitly select the Staging project. No workflow or database command was run in this checkpoint.

## Decision
DESIGN ONLY. No migration file created, no SQL mutation, no RPC invocation, no fixture provisioning, no upload, no notification, no deployment, no Production access. Phase 00 remains OPEN; Phase 01 remains unauthorized.


## 2026-11-28 live Staging function and schema recheck — critical lifecycle defect confirmed

Read-only catalog inspection retrieved the exact deployed definitions of the multi-category onboarding RPC, its delegated base RPC, capability review and revocation RPCs, together with table columns, constraints, indexes, triggers and execute ACLs.

### Confirmed defect A — repeat onboarding can downgrade a reviewed organisation

The public multi-category RPC calls `krim_submit_partner_onboarding_global_v2` on every submission. The delegated base function unconditionally updates the organisation to:
- `partner_lifecycle_status='verification_pending'`
- `partner_verification_status='pending'`
- `partner_compliance_status='pending'`
- `partner_onboarding_status='submitted'`

It also reopens/rewrites an existing open verification case. There is no guard in the multi-category wrapper that rejects an already verified/compliant organisation or routes a material change into a separately reviewed amendment. A repeat submission can therefore regress an already approved organisation's status. This must be corrected before partner onboarding is enabled for real applicants.

### Confirmed defect B — category declaration update can silently deactivate an approved capability

For each selected category, the multi-category RPC updates any existing row matching `organization_id` plus `metadata.operational_category`. That UPDATE unconditionally sets `active=false` and `verification_status='pending'`, and overwrites coverage fields. It does not restrict the row to a draft/pending/rejected state and does not create a new evidence version. A previously verified capability can therefore be silently downgraded by submitting onboarding again. The existing table has only a primary-key index on id and no unique constraint for organisation/category, so duplicate legacy rows are also possible; the current UPDATE can affect multiple matching rows.

### Confirmed defect C — onboarding-created capability declarations lack review evidence lineage

The multi-category wrapper inserts declarations with category and coverage metadata only. It does not set `metadata.submitted_by` or `metadata.evidence_paths`. The independent capability-review RPC requires a submitter and one to five existing private evidence objects under the exact organisation/user/capability path before approval. Therefore these onboarding-created declaration rows cannot pass the existing approval evidence gate until a separate evidence submission creates a distinct reviewable row or a proper evidence-attachment/version workflow is implemented.

### Existing controls that must be preserved

- Multi-category onboarding is authenticated-only (anon EXECUTE false) and requires AAL2 plus an active registered-business partner membership.
- Delegated base onboarding v2 is not executable by anon or authenticated directly; service_role only. The wrapper is the exposed entry point.
- Capability review and revocation require authenticated AAL2 platform-admin permission; anon EXECUTE false.
- Capability approval checks submitter/reviewer independence, current organisation compliance, active country and mode, evidence object ownership/path, and blocks hazardous-goods and refrigerated capabilities through the standard workflow.
- Revocation marks a verified active capability suspended/inactive and explicitly does not cancel existing assignments. This is a separate operational-impact workflow gap; do not auto-cancel assignments.

### Schema and lineage findings

- `krim_partner_capabilities` currently has no first-class submitter/evidence/version columns. Evidence lineage lives in mutable JSONB metadata.
- No unique index exists on `(organization_id, metadata->>'operational_category')`; multiple category rows can be updated by one wrapper invocation.
- Existing audit trigger records capability INSERT only, not arbitrary UPDATE. Review/revoke RPCs separately write audit events, but generic category UPDATEs have no equivalent immutable submission-version record.
- Existing organisation onboarding document-owner trigger verifies that the submitted business documents belong to the authenticated submitter; it does not protect previously approved organisation state from regression.
- The current Staging capability table is empty at the audited snapshot; no live rows were changed and no regression could be safely reproduced using production-like records.

### Required corrective design before DDL

1. Separate first-time organisation verification from capability portfolio amendments. A verified/compliant organisation must not be reset by a service-category edit. Changes to legal identity or compliance-critical fields must enter a separately versioned re-verification case with explicit impact and review.
2. In the multi-category RPC, never UPDATE a verified, suspended, expired or otherwise reviewed capability in place. Either reject the operation with a clear message or create a new pending version linked to the prior capability/version. Do not change the currently approved row until an independent reviewer approves the new version.
3. Persist every capability submission in an append-only version/history table with submitter, timestamp, request/idempotency key, submitted details, evidence object paths, evidence ownership and review decision linkage. Enforce unique version numbers and idempotency keys; deny direct client DML.
4. Bind reviewer approval to the exact immutable submission version and evidence snapshot. Approval/rejection must record reviewer, timestamp, reason, previous state and resulting state. A later submission must not rewrite historical evidence or review.
5. Add a database-level invariant or transition guard so no exposed RPC or future code path can silently change `verified/active` to `pending/inactive` without an explicit audited amendment/revocation transition.
6. Resolve legacy duplicate category rows safely before adding uniqueness; inventory and reconcile duplicates rather than selecting an arbitrary row.
7. Define revocation impact handling: enumerate affected queued/accepted/in-progress assignments, stop new matching allocations immediately, create operations exceptions for existing assignments, and require an authorised human decision for reassignment/cancellation. Preserve shipment and customer evidence.
8. Test first submission, repeat same submission, coverage amendment, evidence replacement, approved capability amendment, rejected resubmission, suspended capability, duplicate category rows, concurrent submissions, idempotent retries, cross-tenant access, AAL1/AAL2 and reviewer self-approval.

### Execution boundary

This is a confirmed source/catalog defect report, not a deployed fix. No SQL DDL/DML, RPC invocation, storage upload/deletion, onboarding submission, partner state change or production access was performed. A standard Supabase migration must be generated using the supported CLI workflow and tested in an isolated local stack before any reviewed Staging migration is applied. The connected session currently lacks that local CLI/Docker migration-generation and isolated database-test capability. Do not bypass that gate with an ad hoc migration filename or unreviewed direct DDL.
