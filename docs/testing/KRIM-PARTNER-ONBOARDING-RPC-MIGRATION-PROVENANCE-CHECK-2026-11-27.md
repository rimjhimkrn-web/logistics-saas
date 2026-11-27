# KRIM Partner Onboarding RPC Migration Provenance Check — 2026-11-27

## Scope
Staging Supabase project `qrpcivhdxobiaofppbkl` only. Read-only query of `supabase_migrations.schema_migrations`. No Production access, SQL writes, RPC calls, onboarding submissions or deployments.

## Results
The migration-history query searched names containing partner, capability, onboarding, multi-category and global-partner terms.

Recent partner-related migrations include:
- `20261127051523 phase00_enforce_partner_onboarding_document_owner`
- `20261127051546 phase00_scope_partner_document_owner_trigger`
- `20261127051703 phase00_restrict_partner_verification_document_reads`
- `20261127062935 phase00_harden_scoped_partner_evidence_rpc`
- `20261127064338 phase00_harden_partner_verification_admin_read_rpc`
- `20261127071935 phase00_add_partner_capability_revocation`
- `20261127072018 phase00_add_partner_service_area_revocation`

The targeted migration-name search did not return an obvious source migration for `krim_submit_partner_onboarding_global_multi_v1`. This is not sufficient evidence that no source migration exists: the migration may have a generic name, may predate the queried naming patterns, or the deployed schema and repository migration history may have drifted.

## Caller inventory disposition
- Confirmed caller: `public/partner/partner-onboarding.html`, Staging branch `staging/phase00-env-isolation`.
- The caller sends general registration paths and category coverage only; no category evidence map.
- Complete all-repository caller enumeration is still OPEN. GitHub code search is indexed against the default branch, so it cannot certify all callers on the Staging branch. The inspected file alone must not be represented as a complete inventory.
- Exact migration source provenance is OPEN. Do not create a replacement migration by guessing the original definition or assuming the history table is complete.

## Safe next step
Obtain a recursive tree for the exact Staging branch head and enumerate all tracked SQL/HTML/JS/TS callers; then compare migration files with the deployed function definition and migration history. Only after exact source and all callers are known should a versioned RPC and frontend update be authored together.

## Disposition
P1 remains OPEN. No implementation change is authorized by this provenance check. No Production changes.
