# KRIM Fast-Track Day 1 Addendum — Exact Staging Tree Retrieved — 2026-11-28

## Branch tree access resolved
The exact Staging branch tree is now retrievable by using the known Staging commit SHA as the Git Trees API target, avoiding the slash-containing branch URL problem.

Tree request target commit: `a2d7162f807d063ffe1bb005ee478a4c78e84379`
- Git tree response: `truncated=false`
- Total entries: 2,583
- Blob/file entries: 2,372
- SQL migration/files: 508
- HTML/JS/TS/TSX/JSX files: 1,210

This is a complete Git tree response for that commit, not a complete source-content search. The exact tree is available for further targeted blob retrieval.

## Relevant paths identified
- `public/partner/partner-onboarding.html`
- `supabase/migrations/20261020074510_global_partner_onboarding_location_hardening.sql`
- `supabase/migrations/20261105153000_add_evidence_backed_partner_capability_submission.sql`
- `supabase/migrations/20261105153200_persist_partner_capability_submission_details.sql`
- `supabase/migrations/20261115112000_align_individual_partner_service_categories.sql`
- `supabase/migrations/20261115111500_harden_customer_and_partner_organization_provisioning.sql`

Targeted blob inspection:
- `20261020074510_global_partner_onboarding_location_hardening.sql` defines the base `krim_submit_partner_onboarding_global_v2` function; it does not define the multi-category wrapper.
- `20261115112000_align_individual_partner_service_categories.sql` does not define either onboarding RPC.
- `20261115111500_harden_customer_and_partner_organization_provisioning.sql` does not define either onboarding RPC.
- The evidence-backed capability submission migrations are separate capability submission/review paths and do not define the multi-category onboarding wrapper.

## Updated Day 1 disposition
The tree-access blocker is RESOLVED. Exact source migration provenance for `krim_submit_partner_onboarding_global_multi_v1` and exhaustive content-level caller enumeration are still OPEN. The repository tree alone does not prove every file's content.

The deployed wrapper may have been introduced by a migration with a generic filename, a direct SQL change not represented in the tracked migration directory, or a later migration not yet content-scanned. Do not infer which is true.

## Next safe step
Search all tracked SQL blobs for the exact function definition and all application blobs for exact call references, using the retrieved tree's blob SHAs. Compare any matching migration with the deployed Staging definition and the migration ledger. No database or application mutation until this provenance and caller inventory is reconciled.

## Safety
Read-only Staging DB queries and GitHub tree/blob reads only. No SQL writes, RPC invocation, onboarding submission, Storage upload, fixture creation, event insertion, queue claim, notification/email/provider/payment action, or deployment. Production untouched. Phase 00 remains OPEN; Phase 01 remains gated.
