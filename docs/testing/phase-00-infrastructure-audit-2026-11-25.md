# KRIM Phase 00 — Infrastructure Audit Baseline

**Audit date:** 2026-11-25  
**Scope:** Web platform only. Native/mobile applications are explicitly excluded from this programme.  
**Audit mode:** Read-only discovery. No production data, schema, configuration, payment settings, or user accounts were modified.  
**Repository baseline:** `main` at `4320d74076de30e80e4e5a85e398a9c99cc13024`.

## Executive status

**Phase 00: IN PROGRESS — baseline discovery completed; reconciliation and runtime evidence remain outstanding.**

This report records observed facts, not a production-readiness approval. No live customer or partner onboarding decision should be based on this baseline alone.

## 1. Connected systems

| Component | Observed |
|---|---|
| GitHub repository | `rimjhimkrn-web/logistics-saas` |
| Default branch | `main` |
| Production Supabase | `ebltviniygljwwseplph` — ACTIVE_HEALTHY |
| Staging Supabase | `qrpcivhdxobiaofppbkl` — ACTIVE_HEALTHY |
| Production database engine | PostgreSQL 17.6 |
| Staging database engine | PostgreSQL 17.11 |
| Production region | `ap-northeast-1` |
| Staging region | `ap-south-1` |

## 2. Repository and web inventory

- Git tree entries: 2,179.
- Repository files excluding `node_modules`: 2,000.
- HTML files excluding `node_modules`: 1,017.
- The repository contains public pages, authentication routes, all nine role/workspace areas, shared platform files, Supabase migrations/functions, scripts, legal pages and documentation.
- HTML inventory is a source-tree count, not a count of unique public routes or deployed working pages. Redirects, duplicate variants, staging previews and non-public pages must be classified before route coverage is calculated.
- No dedicated web E2E test directory or Playwright/Cypress/Vitest/Jest configuration was found outside vendored dependencies during the initial tree scan. This is a preliminary source-tree finding, not proof that no tests exist elsewhere.
- Existing scripts include `scripts/krim-production-smoke.mjs`, `scripts/krim-complete-static-audit.mjs`, and `scripts/audit-krim-links.mjs`.

## 3. Deployment and existing CI evidence

At the audited `main` commit, the following GitHub Actions runs completed successfully on 2026-11-24:

| Workflow | Run ID | Result |
|---|---:|---|
| Deploy KRIM website and Customer OS | 45375792608 | SUCCESS |
| KRIM static link audit | 45375793107 | SUCCESS |
| KRIM production smoke checks | 45375793045 | SUCCESS |

The production smoke workflow ran the repository's critical-workflow source checks and repository-wide static audit, and uploaded a `krim-complete-static-audit` artifact. The static-link workflow ran local link/asset and static page/redirect audits.

**Interpretation:** these are useful CI and source-level checks. They do not prove real browser interactions, authenticated user journeys, RLS behavior for each role, payment settlement, notification delivery, full ecosystem transactions, performance under load, or recovery under faults.

A separate pull-request workflow run for warehouse RPC ACL isolated SQL testing (run 45549549388, PR #245, commit `90a2b90aef7adbbedbd7d8820a734412f2a3936d`) also reported SUCCESS on 2026-11-25. It is a PR-head result, not evidence that the tested changes are already on `main`.

## 4. Production and staging database comparison

Read-only metadata queries observed:

| Metadata | Production | Staging | Comparison |
|---|---:|---:|---|
| Public tables | 391 | 391 | Same table-name fingerprint |
| Public columns | 4,964 | 4,964 | Same column metadata fingerprint |
| Public RLS policies | 412 | 412 | Same policy-definition fingerprint |
| Public SQL functions | 366 | 376 | Different |
| Public triggers | 161 | 163 | Different |
| Supabase Edge Functions | 22 | 3 | Different |
| Supabase migration ledger entries | 561 | 34 | Different |

The table/column fingerprint covers table names and column names, data types, nullability and defaults. The policy fingerprint covers policy names, commands, roles, USING and WITH CHECK expressions. The function fingerprint comparison covers function names, identity arguments, return types and SECURITY DEFINER flags; it does **not** compare function bodies. Trigger fingerprints include trigger event/timing/action metadata.

### Staging isolation design

The repository's `KRIM-STAGING-OWNER-TESTING.md` documents that staging was intentionally created as an isolated schema-only environment: no production Auth users, table rows, Storage objects, provider credentials or production webhook configuration were copied. It documents restricted client privileges and only three deployed staging Edge Functions, including `owner-testing-authorize`.

The same document says the first staging owner account has not yet been created/assigned, so interactive owner access is unavailable. Therefore staging is **not yet a ready end-to-end test environment**.

**Important:** the migration-ledger difference must not be “fixed” by blindly copying production data or marking migrations applied. First reconcile the intended schema baseline, migration provenance, function bodies, trigger definitions, environment configuration and staging isolation policy. No reset, migration replay, production-to-staging data copy or destructive operation was performed.

## 5. Supabase security and performance advisor baseline

### Security findings

| Finding | Production | Staging | Initial interpretation |
|---|---:|---:|---|
| RLS enabled, no policy (INFO) | 29 | 30 | Some private tables may intentionally have no client policies; each finding still requires schema/consumer review. |
| Authenticated can execute SECURITY DEFINER function (WARN) | 151 | 45 | Review every exposed RPC for deliberate grants, authentication/authorization checks, safe search_path and tenant scoping. Not every finding is automatically exploitable. |
| Leaked-password protection disabled (WARN) | 1 | 1 | Auth hardening item to assess and enable after confirming environment settings and impact. |

### Performance findings

| Finding | Production | Staging |
|---|---:|---:|
| Unindexed foreign keys (INFO) | 37 | 37 |
| Unused indexes (INFO) | 701 | 855 |
| Duplicate index (WARN) | 0 | 1 |

Unused-index notices need workload-aware review; they are not a reason to drop indexes automatically. Staging has one duplicate-index warning on `public.krim_shipment_leg_activations` for `uq_krim_leg_activation_idempotency` and `uq_krim_leg_activation_request_key`. No index changes were made.

## 6. Known release-readiness blockers / open questions

1. Staging owner activation and controlled test-user access are not complete.
2. Production/staging migration history differs substantially and needs provenance-aware reconciliation.
3. Production and staging differ in public function metadata, trigger metadata and deployed Edge Function inventory; function bodies and configuration still need comparison.
4. SECURITY DEFINER RPC exposure requires a function-by-function authorization review and negative tests.
5. RLS-enabled/no-policy findings require classification by schema and intended access model.
6. Leaked-password protection is reported disabled.
7. Existing successful CI checks are static/source-level checks, not full browser or multi-role end-to-end proof.
8. Complete route classification is still required: 1,017 HTML files are not necessarily 1,017 distinct production routes.
9. Notification, payment, webhook and external-provider behavior must be tested with safe sandbox/mock integrations, not live money or uncontrolled recipients.
10. No performance, destructive fault-injection, or long-duration tests were run during this read-only baseline.

## 7. Safety controls observed and retained

- This audit was read-only.
- Production remains outside the synthetic-user and destructive-test scope.
- Staging's documented isolation boundary must be preserved.
- Do not copy production identities, payment secrets, webhook credentials or customer records into staging.
- Do not run load, destructive, payment, refund, email/SMS/Telegram or webhook tests against production.
- No production schema or data was changed.

## 8. Phase 00 next actions

1. Build a classified route inventory from the repository and sitemap, separating production routes, staging previews, redirects, aliases, mobile app sources and internal-only pages.
2. Inspect existing static audit artifacts and test scripts; distinguish assertions from mere file-presence checks.
3. Complete production/staging schema and function/trigger definition reconciliation without mutating either environment.
4. Review all Edge Function names, JWT settings, source code and external side effects.
5. Establish the documented staging owner access path and safe synthetic-data plan; do not create accounts or change permissions without a reviewed procedure.
6. Publish a Phase 00 gap register and obtain a verified baseline before Phase 01 functional test design.

## Evidence status

- PASS: both Supabase projects reported ACTIVE_HEALTHY at audit time.
- PASS: main-branch deploy, static-link audit and production smoke CI runs listed above completed successfully.
- PASS: public table, column and policy metadata fingerprints match between production and staging.
- FAIL / DIFFERENCE REQUIRING REVIEW: public function and trigger metadata fingerprints differ; Edge Function inventories differ.
- BLOCKED: staging interactive owner testing pending owner account activation.
- NOT TESTED: complete browser journeys, per-control UI tests, role isolation, live provider sandbox journeys, performance/load, resilience/recovery and sustained reliability.

**Release decision:** NOT READY TO DECLARE. This is an audit baseline only; continue Phase 00 and resolve/record blockers before moving to full execution testing.
