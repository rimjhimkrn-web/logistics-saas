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
