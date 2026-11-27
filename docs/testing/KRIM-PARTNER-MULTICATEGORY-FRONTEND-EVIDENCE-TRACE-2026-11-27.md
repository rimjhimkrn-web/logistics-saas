# KRIM Partner Multi-Category Evidence Frontend Trace — 2026-11-27

## Scope and safety
Read-only inspection of `public/partner/partner-onboarding.html` on `staging/phase00-env-isolation`. No code, database, Storage, deployment, onboarding submission, or Production action was performed.

## Confirmed frontend behavior
- The registered-business form collects selected operational categories and renders one card per category in `renderCategoryCoverage()`.
- Each card currently contains only:
  - country selector;
  - state/region text field;
  - city text field;
  - a category-specific evidence guidance list (examples of documents to prepare).
- The category card renderer does not create a file input, upload control, or evidence-path field.
- The submit handler constructs `categoryCoverage` as objects with only `category`, `country_code`, `region`, and `city`.
- The handler uploads the business registration certificate and optional insurance certificate through `uploadPartnerDocument()`. The path format is `<organization_id>/<authenticated_user_id>/<uuid>.<extension>`; these are general organization verification documents, not capability-folder evidence.
- The RPC call to `krim_submit_partner_onboarding_global_multi_v1` passes `p_operational_categories`, `p_category_coverage`, and `p_document_paths`. It does not pass category-specific evidence.
- The current UI therefore has evidence guidance but no category-specific evidence collection. The database API gap is mirrored by the frontend; adding metadata in the RPC alone would not repair the actual submission path.

## Required implementation sequence
1. Add one required evidence uploader per selected category (1–5 files per category; enforce file count, type, size, and no empty files client-side for usability).
2. Upload each file into the private `krim-partner-verification` bucket using the server-required capability convention `<organization_id>/<authenticated_user_id>/capability/<filename>`; use unique names and never accept a client-supplied owner identity.
3. Preserve upload paths grouped by category and pass a strict category-to-evidence map to a versioned RPC contract.
4. In the RPC, derive user identity from `auth.uid()`; validate exact category set, path prefix, storage object existence, and ownership before any writes; reject missing, duplicate, extra, foreign-owner, malformed, or wrong-folder entries.
5. Persist `submitted_by`, `submitted_at`, evidence paths, category, and onboarding-case correlation as server-generated capability submission metadata. Keep capability status pending/inactive; retain prior reviewed evidence/history.
6. Update the caller and add contract tests together. Test all 13 supported categories, multiple categories, resubmission, existing capability rows, malformed maps, path/owner violations, transaction rollback, and independent admin approval.
7. Keep the old caller fail-closed or explicitly version/deprecate it. Do not loosen the admin evidence review or approval requirements.

## Current disposition
**P1 OPEN — implementation not started.** The precise frontend caller and upload helper have now been located. This is an actionable cross-layer change, but the exact current database function definition and storage ownership policy must be revalidated against Staging before drafting the migration. No migration or frontend patch is made in this trace.

## Evidence location
- Branch: `staging/phase00-env-isolation`
- Frontend: `public/partner/partner-onboarding.html`
- RPC: `krim_submit_partner_onboarding_global_multi_v1`
- Bucket: `krim-partner-verification`
- Upload helper: `uploadPartnerDocument()`
- Category renderer: `renderCategoryCoverage()`
