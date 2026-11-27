# KRIM Partner Multi-Category Onboarding Caller and Evidence Path Trace — 2026-11-27

## Scope and environment
- Repository: `rimjhimkrn-web/logistics-saas`
- Branch: `staging/phase00-env-isolation`
- Frontend file inspected: `public/partner/partner-onboarding.html`
- Deployed database inspected: Staging Supabase project `qrpcivhdxobiaofppbkl`
- Production was not accessed.
- This is a source/catalog audit only. No SQL mutation, RPC invocation, upload, onboarding submission, or deployment occurred.

## Confirmed frontend call path
The registered-business submission in `public/partner/partner-onboarding.html`:
1. Reads selected operational categories from `#partner-categories`.
2. Builds `categoryCoverage` from category cards with country, region and city only.
3. Validates and uploads one required business-registration document and an optional insurance document.
4. Calls `krim_submit_partner_onboarding_global_multi_v1` with `p_operational_categories`, `p_category_coverage`, and `p_document_paths`.
5. It does not submit a category-to-evidence map or category-specific capability evidence paths.

The only uploader helper found in this inspected file, `uploadPartnerDocument`, writes to:
`<organization_id>/<authenticated_user_id>/<uuid>.<extension>`
in the private `krim-partner-verification` bucket. It does not use the required capability subfolder.

The UI text directs the applicant to submit separate capability evidence later through Services & Capabilities. This confirms that the onboarding page is intentionally only collecting organization-level documents today; it cannot satisfy the capability-review evidence contract during multi-category onboarding.

## Deployed database contract
The live Staging function signature is:
`krim_submit_partner_onboarding_global_multi_v1(text,text,text,text[],text[],text,text,text,text,text,text,text,text,text,jsonb)`

Its current arguments include operational categories, general document paths and category coverage. There is no category-specific evidence argument.

The function:
- Requires authenticated AAL2.
- Checks active registered-business partner membership matching the organization ID in the first general document path.
- Validates 1–13 unique supported categories and one coverage entry per category.
- Calls the base organization-level onboarding RPC.
- Updates or inserts category capability rows as inactive/pending.
- Does not attach capability-specific `submitted_by`, `evidence_paths`, or a category evidence submission record.

## Confirmed resubmission state regression
For an existing category capability row, the current function unconditionally sets:
- `active = false`
- `verification_status = 'pending'`

It also updates the category's coverage fields. Thus a re-submission can downgrade an already reviewed/approved capability to pending/inactive without preserving the previous review decision as an immutable historical version. This is a separate P1 defect from missing evidence.

## Scope limits
- This confirms the caller in the inspected onboarding page and the live RPC contract. It is not a proof that no other caller exists elsewhere in the repository.
- The database function definition is direct deployed Staging evidence. The deployed migration-history list was inspected, but it does not identify the original migration by an obvious multi-category-specific migration name; exact source migration provenance remains to be resolved.
- Storage object existence in the base function is not equivalent to proving the category-specific evidence path or immutable review lineage.

## Required correction before implementation
1. Enumerate all repository callers on the Staging branch and resolve the original migration/source history.
2. Add a versioned RPC contract accepting an exact category-to-evidence map; preserve old callers only if they are safely deprecated or fail closed.
3. Validate all category entries and evidence paths before any organization/capability mutation; enforce authenticated owner, exact organization/user/capability folder, private bucket, object existence, file constraints and one-to-five paths per category.
4. Record server-derived submitter, timestamp, evidence version and onboarding-case correlation.
5. Preserve approved capability state and prior evidence/reviewer decision history on resubmission; do not silently reset an approved row.
6. Add matching category-specific upload controls and caller changes in the same Staging release.
7. Add tests for all 13 categories, multiple categories, first submission, approved/rejected resubmission, missing/duplicate/extra/foreign/wrong-owner evidence, malformed input and atomic rollback.
8. Keep all submitted capabilities pending until independent AAL2 review; no activation from applicant submission.

## Disposition
P1 remains OPEN. Do not invoke the current RPC for test data, do not insert synthetic capabilities, and do not deploy a partial frontend-only or database-only correction. Production remains untouched.
