# KRIM Partner Multi-Category Evidence Contract — Implementation Gate
**Date:** 27 November 2026  
**Environment:** Staging database `qrpcivhdxobiaofppbkl` read-only inspection  
**Production:** Not accessed

## Finding carried forward
The deployed Staging function `public.krim_submit_partner_onboarding_global_multi_v1(...)` creates or updates category capability rows without writing capability-level `submitted_by` and `evidence_paths`. The admin review function `public.krim_admin_review_partner_capability(bigint,text,text)` requires both and validates each evidence object in the private `krim-partner-verification` bucket against the original submitter.

## Additional inspection: evidence contract
The multi-category RPC currently accepts:
- business/legal registration fields;
- `p_document_paths text[]` for the parent partner onboarding registration documents;
- `p_category_coverage jsonb` containing category, country, region and city.

It does **not** accept category-specific capability evidence paths or a per-category evidence map.

The base onboarding function validates the parent document path structure and existence, and stores those paths on organization/verification-case metadata. The capability review RPC, however, requires capability evidence paths matching the category evidence folder convention:
`<organization_id>/<submitter_user_id>/capability/<filename>`
and checks storage ownership against the submitter.

Therefore the parent registration documents cannot safely be copied into capability `evidence_paths`: they do not satisfy the capability evidence path convention and are not proven to be category-specific evidence.

## Implementation contract required
A safe fix requires an explicit per-category evidence input, not a metadata-only patch:
1. Extend the multi-category submission contract with a JSONB array/map keyed by each selected category, each containing one to five evidence paths.
2. Require exactly one evidence entry for every selected category; reject duplicates, missing categories, extra categories, empty arrays and malformed JSON types.
3. Derive submitter from `auth.uid()`; never accept submitter/reviewer identity from caller JSON.
4. Validate every path is in the exact organization/user capability folder, exists in the private verification bucket, and is owned by the authenticated submitter (`storage.objects.owner_id` / current schema owner column as confirmed).
5. Validate all categories and all evidence before mutating the parent onboarding case or capability rows; transaction rollback must leave no partial submission.
6. Store `submitted_by`, `submitted_at`, `evidence_paths`, category and onboarding-case correlation in each capability's server-generated metadata for both insert and update branches.
7. Preserve prior evidence/audit history or explicitly create a new submission version; do not silently overwrite a reviewed or active capability.
8. Keep new capability rows inactive/pending. Approval remains a separate AAL2 admin action with independent evidence review.
9. Update the actual frontend caller, upload flow and form validation to collect category evidence and pass the new contract. Keep a compatibility strategy for older callers (fail closed or explicitly deprecate); do not silently treat generic registration documents as capability evidence.
10. Add database and UI regression tests: all 13 categories; multiple categories; first submission; resubmission; pre-existing category row; missing/duplicate/foreign evidence; wrong owner; malformed JSON; transaction atomicity; reviewer self-approval; approved and rejected review paths.

## Why no code/schema change was made in this checkpoint
The currently deployed function signature and available payload do not contain category-specific evidence. Adding only `submitted_by` would still fail the evidence gate; copying parent registration documents would violate the capability evidence path/ownership contract. A correct fix must change the database API and its real frontend caller together. The Staging branch source path for the active caller was not independently resolved during this read-only pass, so changing the RPC alone would risk breaking onboarding.

## Status
- Confirmed P1 defect: **OPEN**.
- Safe patch: **NOT APPLIED**.
- Required next step: locate and inspect the exact frontend caller and upload implementation on `staging/phase00-env-isolation`, then implement the DB contract and UI atomically on Staging.
- No RPC invocation, upload, onboarding submission, approval/rejection, test fixture, notification, email/provider/payment operation or Production access occurred.
