# Step 46 — Safe non-production environment assessment

Date: 2026-11-13
Branch: website/global-launch-readiness
Scope: read-only verification of KRIM production, the separate staging project, and Supabase development branches to choose the safest validation path for partner provisioning.

## Live environment facts verified

- Production project `logistics-saas` (`ebltviniygljwwseplph`) is ACTIVE_HEALTHY, PostgreSQL 17.6.1.165, region ap-northeast-1.
- Separate project `KRIM Logistics Staging` (`qrpcivhdxobiaofppbkl`) is ACTIVE_HEALTHY, PostgreSQL 17.11.0.018, region ap-south-1.
- Production migration ledger contains 425 applied migrations.
- Staging migration ledger contains 0 applied migrations.
- Production project has one listed development branch, `main`, with a preview project marked ACTIVE_HEALTHY and `with_data=false`. This is not an independently reconciled schema test environment; do not assume it is safe for migration validation.
- The separate staging project is currently an empty database, not a production schema clone.

## Options assessed

### Option A — Use current staging project
**Not ready.** It has no migration history or application schema. Applying the current repository migrations wholesale is unsafe because the prior audit found 12 duplicate migration version IDs, 361 production-applied versions without matching current repository files, and 201 repository migration files absent from the production ledger. Staging's PostgreSQL minor version also differs from production.

### Option B — Create a Supabase development branch from production
**Do not use yet.** A development branch applies migrations from the parent project and can incur hourly compute charges. The only listed branch is attached to production and the repository/production migration history is materially drifted. Branch creation/rebase does not resolve the source-of-truth problem and may reproduce an incomplete or inconsistent history. No branch was created.

### Option C — Reconstruct a disposable schema-only baseline
**Recommended, after prerequisite evidence.** First obtain a verified encrypted schema-only export from production with checksum and controlled custody. Recover canonical migration source/history or produce a separately reviewed baseline-reconstruction plan that maps every live object to a known definition. Restore only the schema into a disposable non-production project/database; do not copy production customer, partner, financial or identity data. Then test the partner provisioning migration/function and Edge Function with synthetic identities and negative authorization tests.

A schema-only dump is not a full Supabase project backup. Auth/Storage managed state, buckets/objects, Edge Functions, secrets, extensions and project settings need separate treatment if a complete recovery plan is required.

## Required sequence

1. Verify the repository Actions secrets for the schema export workflow without disclosing their values.
2. Run the manual export only after confirming the source is production and the encrypted artifact destination/retention.
3. Verify artifact exists, decrypt only in a controlled environment, verify checksum, inspect schema and exclude data.
4. Reconcile production's 425 migration ledger against source files and resolve duplicate IDs; if exact historical SQL cannot be recovered, document and approve a baseline reconstruction with object-level mapping.
5. Restore schema-only baseline to disposable non-production environment; verify table/function/RLS counts and extensions.
6. Implement partner provisioning there; run security advisors, authorization negatives, idempotency/concurrency and rollback/atomicity tests.
7. Review deployment plan and request explicit approval before any production change.

## Cost and production safety

No project, branch, database, migration, schema, data, function, secret or project setting was created or changed in this step. No branch creation was attempted, so no new compute cost was incurred. Do not create another project or branch until the user has reviewed any quoted cost and the migration/export prerequisites are satisfied.

## Step 46 verdict

**BLOCKED — staging is empty and production migration history is unreconciled.** Safest path is verified encrypted schema export → migration provenance reconciliation or approved baseline reconstruction → disposable schema-only validation environment. Do not replay 265 repository migrations or all 425 ledger entries blindly, and do not test partner provisioning against production.
