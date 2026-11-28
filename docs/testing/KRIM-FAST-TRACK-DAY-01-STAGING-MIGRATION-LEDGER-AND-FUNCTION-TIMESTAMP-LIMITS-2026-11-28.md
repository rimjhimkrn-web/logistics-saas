# KRIM Fast-Track Day 1 — Staging Migration Ledger and Function Timestamp Limits — 2026-11-28

## Scope
Read-only follow-up on provenance of `public.krim_submit_partner_onboarding_global_multi_v1` in Staging project `qrpcivhdxobiaofppbkl`.

## Authoritative Supabase migration listing
The Supabase migration-list operation returned 163 applied migration records. The first record is `20261117135137`; the latest is `20261127093019`. No earlier migration is present in the returned ledger. In particular, the repository migrations `20261020074510_global_partner_onboarding_location_hardening` and `20261104133000_secure_partner_business_verification` are absent from this Staging ledger.

This corroborates the earlier direct `supabase_migrations.schema_migrations` query. It is a statement about the current Staging ledger only, not proof of whether those migrations were applied historically in another environment or before a ledger reset/import.

## Function catalog timestamp investigation
The deployed multi-category function exists with:
- OID: 29492
- owner: postgres
- SECURITY DEFINER: true
- explicit empty search_path
- 15-argument identity signature, including `p_category_coverage jsonb`.

PostgreSQL setting `track_commit_timestamp` is `off`. The catalog row's xmin is 1420, but commit timestamp lookup is unavailable. Therefore the current database catalog cannot establish the function's creation timestamp using this method.

## Provenance disposition
Still UNKNOWN:
- original full CREATE FUNCTION source;
- original application date and deployment mechanism;
- whether initial creation was via an untracked SQL editor action, an omitted migration, a database restore, or another deployment artifact.

These are hypotheses only; none is asserted as fact.

## Safe recovery path
Request an authorized pre-hardening database backup/schema export or archived SQL deployment artifact from the system owner. Compare that source against the current Staging definition and the November 4 hardening transformation. Do not fabricate migration history, infer source from the current function body, or run the historical text-replacement migration against an unknown baseline.

## Safety
Read-only Staging migration/catalog queries and repository inspection only. No database writes, RPC calls, uploads, fixture provisioning, emails, notifications, payment calls, deployment, or Production access. Phase 00 remains OPEN and Phase 01 remains unauthorized.
