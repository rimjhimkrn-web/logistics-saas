# KRIM Fast-Track Day 1 — Multi-Category RPC Provenance Reconciliation Addendum — 2026-11-28

## Executive result
The original creation source for deployed Staging function `public.krim_submit_partner_onboarding_global_multi_v1` remains unidentified. We now have a concrete repository and Staging migration-history gap. Do not reconstruct or replace this function by guessing.

## Repository chronology established
1. Tracked migration `supabase/migrations/20261020074510_global_partner_onboarding_location_hardening.sql` creates the base single-category function `krim_submit_partner_onboarding_global_v2`. It does not create the multi-category wrapper.
2. Commit `aa9e5d25a319c5d5ce638fae113bdfaa1da99b96` (2026-11-02) changes `public/partner/partner-onboarding.html` from a single category selector/base RPC call to a multi-category selector and call to `krim_submit_partner_onboarding_global_multi_v1`. That commit contains only the HTML file, no SQL migration.
3. Tracked migration `supabase/migrations/20261104133000_secure_partner_business_verification.sql` locates the already-existing multi-category function using `pg_get_functiondef`, then applies a text replacement to harden authorization. It does not contain the original complete CREATE FUNCTION definition.
4. The Staging deployed function exists and has been read directly from `qrpcivhdxobiaofppbkl`; it is not a reconstructed definition.

## Staging migration-history finding
Read-only query of `supabase_migrations.schema_migrations` returned:
- 163 migration rows.
- Oldest recorded version: `20261117135137`.
- Newest recorded version: `20261127093019`.
- Zero recorded October 2026 versions.
- Zero recorded `20261104` versions.
- The exact `20261020074510` base-function migration and `20261104133000` hardening migration are not present in this Staging history result.

This means the current Staging migration ledger does not provide provenance for the older deployed function lineage. It does NOT establish that those migrations were never applied: the ledger may have been reset, imported, truncated, or the function may have been applied outside normal migration tracking. No such explanation is assumed.

## Implications
- Repository source has a base v2 function migration, but no identified full wrapper creation migration.
- The frontend call to the wrapper is proven in a Nov 2 commit.
- The Nov 4 tracked migration assumes the wrapper already exists and edits it in place.
- Staging has the deployed wrapper, but its recorded migration history begins Nov 17.
- The exact original wrapper definition, initial application date, and deployment method cannot currently be proven from the available tracked source and Staging migration ledger.

## Required recovery before implementation
1. Obtain a trusted database backup/schema dump or Supabase migration/deployment artifact from before the Nov 4 hardening change, if available.
2. Reconcile the migration ledger against repository migration files and any historical Supabase CLI/deployment records; do not manually insert migration-history rows.
3. Retrieve the exact pre-hardening and current function definitions from an authorized backup or archived deployment output, then compare them.
4. Write a new versioned migration from a verified source baseline with explicit rollback and tests; do not use text replacement against an unknown baseline.
5. Only then coordinate the new API with the frontend and test the pending-record/evidence handoff on isolated Staging fixtures.

## Safety
Read-only GitHub and Staging catalog/migration-ledger queries only. No SQL writes, RPC invocation, partner onboarding, storage upload, fixture creation, notifications, emails, payment calls, deployment or Production access occurred. Phase 00 remains OPEN; Phase 01 remains unauthorized.
