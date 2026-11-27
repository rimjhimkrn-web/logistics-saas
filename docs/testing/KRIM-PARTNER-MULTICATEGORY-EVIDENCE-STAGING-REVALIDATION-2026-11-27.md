# KRIM Partner Multi-Category Evidence Contract — Staging Revalidation — 2026-11-27

## Scope
Read-only SQL inspection on Staging Supabase project `qrpcivhdxobiaofppbkl`, plus current Supabase Storage documentation. Production project was not accessed. No schema, Storage, or application changes were made.

## Deployed RPC contract confirmed
Current function:
`public.krim_submit_partner_onboarding_global_multi_v1(text,text,text,text[],text[],text,text,text,text,text,text,text,text,text,jsonb)`

- SECURITY DEFINER, empty search_path.
- Requires authenticated caller and AAL2.
- Requires active registered-business partner organization membership matching the first general document path.
- Accepts 1–13 unique categories and a coverage JSON array; checks category/country uniqueness and active country catalogue.
- Calls the base onboarding RPC, then updates/inserts category capability rows.
- Does not accept per-category evidence paths.
- New capability rows only store category/coverage/submission-source metadata; no capability `submitted_by`, `submitted_at`, or `evidence_paths`.
- Existing matching capability rows are reset to `active=false` and `verification_status='pending'` while metadata is merged. This can downgrade an already reviewed capability and must be addressed explicitly in the replacement contract; do not silently overwrite reviewed/active evidence or status.

## Storage configuration and policies confirmed
Bucket `krim-partner-verification`:
- Private.
- 10 MiB object limit.
- Allowed MIME types: PDF, JPEG, PNG.

Current relevant policies:
- Authenticated INSERT requires bucket match, AAL2, second path segment equals `auth.uid()`, and an active membership in the first-segment partner organization.
- Authenticated SELECT allows owner/authorized partner manager or platform AAL2 administrator.
- The INSERT policy checks the second path segment but does not require a third segment named `capability`; the RPC must enforce the capability-specific folder convention.
- Current general registration upload helper uses `<org>/<user>/<uuid>.<ext>`. Capability evidence must use a distinct `<org>/<user>/capability/<unique-file>.<ext>` convention.

Supabase Storage documentation confirms private bucket access is controlled by RLS on `storage.objects`, and object ownership is represented by `owner_id` (legacy `owner` is deprecated). The new RPC should validate the actual object row and `owner_id`, not trust a client-supplied path or metadata claim.

## Required safe replacement
1. Introduce a versioned RPC rather than changing a function signature in place without auditing callers.
2. Add a strict JSONB map with exactly one entry per selected category and 1–5 unique paths per category.
3. Validate all categories, paths, object existence, private bucket ID, exact `<org>/<auth.uid()>/capability/` prefix, allowed extension/MIME/size, and `storage.objects.owner_id = auth.uid()::text` before calling the base onboarding writer.
4. Keep user identity derived from `auth.uid()`; never accept submitter/reviewer identity from JSON.
5. Store server-generated `submitted_by`, `submitted_at`, evidence paths, category, and onboarding-case correlation.
6. Preserve existing review evidence/history. If a capability is already active/reviewed, create a new submission version or require an explicit resubmission workflow; do not automatically downgrade or replace approved evidence.
7. Keep new/changed submissions pending and inactive. Independent AAL2 admin review remains mandatory.
8. Update the actual frontend caller and category card uploader together. Keep general registration documents in the existing general folder; capability files go in the capability folder.
9. Add database and frontend tests for all 13 categories, multi-category submissions, missing/extra/duplicate categories, 1/5/6 file boundaries, wrong bucket/folder/owner, missing objects, unsupported MIME/size, resubmission/history, active capability preservation, and transaction rollback.
10. Revoke/deprecate old callable entry points only after every caller is identified and migrated. Do not loosen Storage policies or approval checks to make the UI pass.

## Disposition
**P1 remains OPEN.** Contract and policy evidence is now sufficient to design the cross-layer change, but implementation should wait until the exact migration history and all callers of the old RPC are enumerated. No test identities, uploads, onboarding submissions, or approval RPCs were invoked. No external notification, email, payment, or Production operation occurred.
