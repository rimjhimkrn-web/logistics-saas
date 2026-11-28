# KRIM Fast-Track Day 1 — Onboarding RPC Provenance Findings — 2026-11-28

## Additional source inspection
The exact Staging tree at commit `a2d7162f807d063ffe1bb005ee478a4c78e84379` was retrieved with `truncated=false`. Targeted migration blob reads produced these findings:

1. `supabase/migrations/20261020074510_global_partner_onboarding_location_hardening.sql` defines the base `public.krim_submit_partner_onboarding_global_v2(...)` function. It is the single-category implementation and does not define the multi-category wrapper.
2. `supabase/migrations/20261104133000_secure_partner_business_verification.sql` references both `krim_submit_partner_onboarding_global_multi_v1` and `krim_submit_partner_onboarding_global_v2`, retrieves their live definitions with `pg_get_functiondef`, and applies authorization hardening by replacing known code anchors. It does NOT create the original multi-category wrapper. This proves the wrapper existed by the time this migration was applied to the then-target project.
3. The related evidence-backed capability submission migrations `20261105153000_add_evidence_backed_partner_capability_submission.sql` and `20261105153200_persist_partner_capability_submission_details.sql` do not define either onboarding RPC.
4. `20261115111500_harden_customer_and_partner_organization_provisioning.sql` and `20261115112000_align_individual_partner_service_categories.sql` do not define either onboarding RPC.

## Staging migration ledger finding
A fresh read-only query of Staging `supabase_migrations.schema_migrations` showed the earliest returned applied migration versions begin at `20261117135137`. A separate query for versions earlier than `20261105000000` returned no rows. Thus the current Staging migration ledger does not contain the original October/early-November migration history needed to prove provenance. The code repository contains older migrations, but the deployed Staging ledger appears to start from a later baseline/snapshot.

## Current conclusion
- The multi-category wrapper existed before the 2026-11-04 authorization-hardening migration.
- The base v2 implementation is traceable to the 2026-10-20 migration.
- The original multi-category wrapper creation migration has NOT yet been identified.
- The Staging applied-migration ledger cannot independently establish its original provenance because it begins at 2026-11-17.
- Complete application call-site content enumeration remains pending. The tree identifies candidate paths, but only the confirmed onboarding page has been read in full so far.

## Required next step
Continue targeted full-content search of tracked SQL blobs for the wrapper's exact `CREATE FUNCTION` definition and application blobs for exact RPC call sites. Compare the eventual source migration with deployed `pg_get_functiondef` and note any migration-baseline drift. Do not patch or recreate the wrapper until its full current definition and all callers are reconciled.

## Safety
All database queries were read-only and Staging-only. Blob/tree reads only. No SQL write, migration, RPC invocation, onboarding submission, Storage upload, fixture, event, notification/email/provider/payment action, or deployment occurred. Production untouched. Phase 00 remains OPEN.
