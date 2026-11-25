# KRIM Phase 00 — Reconciliation Checkpoint 02

**Date:** 25 November 2026  
**Scope:** Web platform only. Native/mobile apps are excluded.  
**Mode:** Read-only GitHub and Supabase inspection, plus documentation-only change on the QA branch.  
**Production changes:** None. No production data, schema, credentials, payment settings, users, or provider configuration were modified.

## 1. Repository and route inventory

- Repository: `rimjhimkrn-web/logistics-saas`
- Default branch: `main`
- Audited main commit: `4320d74076de30e80e4e5a85e398a9c99cc13024`
- Main tree: 2,386 entries; recursive tree was not truncated.
- HTML files repository-wide: 1,023.
- HTML files under `app/`: 230.
- `app/` HTML files under explicit staging folders: 103.
- `app/` HTML files outside explicit staging folders: 127 candidate paths.

The 127 paths are not yet certified as 127 live routes. A Git file may be an embedded page, legacy page, internal tool, redirect, or unreachable page. The candidate inventory is recorded in `phase-00-application-route-inventory-2026-11-25.md`. The next route step is to reconcile paths against the live Pages deployment, internal navigation, redirects, and auth/role guards.

## 2. Existing main-branch CI evidence

The following latest main-branch runs on 24 November completed successfully:

| Workflow | Run ID | Result |
|---|---:|---|
| Deploy KRIM website and Customer OS | 45375792608 | Success |
| KRIM static link audit | 45375793107 | Success |
| KRIM production smoke checks | 45375793045 | Success |

The deploy run had successful build and deploy jobs. The static-link workflow had a successful audit job. The smoke workflow had a successful smoke-check job.

These results prove those specific CI jobs passed for their commit. They do not prove every page control, authenticated workflow, API, database mutation, payment, notification, tenant boundary, or end-to-end logistics journey works.

Additional successful isolated SQL test workflows were observed on a pull-request branch on 25 November. They are isolated fixture tests, not a full production end-to-end certification.

## 3. Production and staging database snapshots

Projects:
- Production: `ebltviniygljwwseplph` — ACTIVE_HEALTHY, PostgreSQL 17.6.
- Staging: `qrpcivhdxobiaofppbkl` — ACTIVE_HEALTHY, PostgreSQL 17.11.

Read-only catalog comparison:

| Catalog item | Production | Staging |
|---|---:|---:|
| Public base tables | 391 | 391 |
| Private base tables | 6 | 6 |
| Public views | 1 | 1 |
| Public functions | 366 | 376 |
| Private functions | 56 | 59 |
| `krim_internal` functions | 82 | 82 |
| Non-internal triggers | 128 | 127 |
| RLS-enabled application tables | 424 | 423 |
| Policies | 440 | 415 |
| Extensions | 7 | 5 |
| Migration ledger entries | 561 | 34 |
| Deployed Edge Functions | 22 | 3 |

Stable non-system schemas:
- Production: `auth, cron, extensions, graphql, graphql_public, krim_internal, net, pgbouncer, private, public, realtime, storage, supabase_migrations, vault`.
- Staging: `auth, extensions, graphql, graphql_public, krim_internal, pgbouncer, private, public, realtime, storage, supabase_migrations, vault`.

The production and staging public table counts being equal does not mean the environments are functionally equivalent. Function definitions, triggers, policies, extensions, migrations, schemas, and deployed Edge Functions differ.

## 4. Staging purpose and limitation

The repository's `KRIM-STAGING-OWNER-TESTING.md` explicitly describes staging as a schema-only, isolated owner-testing environment:
- Production Auth users, table rows, Storage objects, provider credentials, and webhook configuration were not copied.
- Client-role table/function privileges were revoked in application schemas.
- Only a small owner-testing function set is deployed.
- Payment, refund, webhook, SMS, email, Telegram, AI and general notification Edge Functions are intentionally absent.
- The owner account, confirmed email, MFA AAL2 enrollment, and staging-only `platform_superadmin` assignment are still required.
- The owner preview is static/read-only and is not an end-to-end staging app.

Therefore, staging is safely isolated but is not yet ready to run the complete functional test suite. We must design and provision a controlled synthetic-data test harness, with only the minimum reviewed functions and services required. Do not weaken staging's isolation wholesale and do not copy production user/customer data.

## 5. Security advisor findings — open investigation items

| Advisor | Production | Staging |
|---|---:|---:|
| RLS enabled, no policies (INFO) | 29 | 30 |
| Authenticated can execute SECURITY DEFINER function (WARN) | 151 | 45 |
| Leaked-password protection disabled (WARN) | 1 | 1 |

The RLS-without-policy findings include private and public schemas. These must be reviewed table-by-table against intended access and grants; an RLS table without policies is not automatically a public exposure, particularly where client privileges are revoked. SECURITY DEFINER findings require per-function review of caller, authorization, search_path, grants, tenant scope, and intended exposure. No blanket revocations or policy changes were made.

## 6. Performance advisor findings — open investigation items

| Advisor | Production | Staging |
|---|---:|---:|
| Foreign keys without covering indexes (INFO) | 37 | 37 |
| Unused-index notices (INFO) | 701 | 855 |
| Duplicate-index warning | Not reported | 1 |

Unused-index notices must be interpreted against actual workload and observation period; do not drop indexes automatically. The duplicate-index warning is staging's `krim_shipment_leg_activations` pair `uq_krim_leg_activation_idempotency` and `uq_krim_leg_activation_request_key`. Confirm equivalent constraints and dependencies before any remediation.

## 7. Phase 00 gap register

| ID | Finding | Severity / priority | Required next action |
|---|---|---|---|
| P00-01 | Candidate app HTML paths have not been reconciled to deployed live routes | High | Build route map from deployment, navigation, redirects, and guards |
| P00-02 | Staging is schema-only and lacks general Edge Functions and synthetic identities | Blocker for full E2E | Design least-privilege synthetic test harness and staging fixtures |
| P00-03 | Production/staging migration ledgers differ substantially | High | Reconcile migration source, naming collisions, ordering and actual schema state; never blindly replay |
| P00-04 | Public function catalog differs (366 vs 376) | High | Compare signatures, definitions, grants, owners, security mode and search_path |
| P00-05 | Trigger counts differ (128 vs 127) | High | Compare trigger definitions and dependent functions |
| P00-06 | Policy counts differ (440 vs 415) | High | Compare policy definitions and effective grants by role |
| P00-07 | Edge Function inventory differs (22 vs 3) | Blocker for full E2E | Inventory callers, source parity, secrets requirements, JWT mode and safe staging deployment plan |
| P00-08 | 151 production / 45 staging SECURITY DEFINER execution warnings | Critical review | Per-function authorization review; no blanket grant/revoke |
| P00-09 | Leaked-password protection disabled in both projects | High | Confirm desired Auth policy and plan controlled configuration change |
| P00-10 | 37 unindexed foreign keys in each environment | Medium | Prioritize with query plans and workload evidence |
| P00-11 | Staging duplicate index warning | Medium | Validate duplicate constraint/index semantics before correction |
| P00-12 | Main CI checks pass but do not cover full functional journeys | High | Add browser, API, database, integration and regression suites |

## 8. Decisions and safeguards

1. Keep all destructive, synthetic-user, load, payment and notification tests out of production.
2. Keep the current staging isolation boundary; do not copy production data or enable all production integrations.
3. Do not treat file counts, matching table counts, successful deployments, smoke checks, or static-link checks as functional proof.
4. Do not remediate security/performance advisor findings by bulk changes.
5. Every test result must be tied to a commit, environment, test ID, timestamp and retained evidence.
6. No full E2E test has been claimed as passed in this checkpoint.

## 9. Phase status

**PHASE 00 — IN PROGRESS.**

Completed in this checkpoint:
- Re-read main repository tree.
- Created a current application HTML candidate-path inventory.
- Rechecked production and staging project health and catalog counts.
- Rechecked Edge Function inventories and advisor summaries.
- Verified latest main-branch deployment, static-link and smoke workflow results.
- Confirmed staging's documented schema-only purpose and owner-activation prerequisites.

Still outstanding:
- Route-to-deployment/navigation/guard reconciliation.
- Full SQL definition/grant/trigger/policy diff.
- Complete Edge Function source/caller/secret/JWT mapping.
- Existing tests and artifact inventory.
- Safe synthetic-test harness design and staging readiness plan.

**Release decision:** No production-readiness approval is issued by this checkpoint.