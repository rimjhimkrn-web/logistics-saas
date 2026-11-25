# Phase 00 — Gate C3.37: Global Platform Resilience, Disaster Recovery, Backup & Business Continuity Audit

**Date:** 25 November 2026  
**Baseline:** immutable source commit `72d75a18f985ceb09e468839435ee95700e11e46`  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Method:** read-only source inspection of backup/export, schema-manifest, staging-bootstrap and Pages deployment workflows; reconciliation with dated C3.30/C3.31 and 16 November backup/continuity audits. No live project, backup, restore, DNS, provider, secret or deployment action was performed.

## Executive decision

**C3.37 FAIL / BLOCKED — NO-GO for disaster-recovery certification, real shipment execution, freight collection, or continuity/availability guarantees.**

The source contains useful encrypted schema-export safeguards, but not a recoverable production backup chain. The existing workflow exports schema only, retains its encrypted artifact for one day, and excludes business rows, Auth identities, Storage object bytes, Vault secrets, managed schemas, custom roles and provider configuration. The staging bootstrap trusts a supplied connection URI and checks schema emptiness, but does not independently prove the destination project reference/region before applying DDL. No complete restore, measured RPO/RTO, tested failover, operator/on-call response or controlled cutover evidence is present.

This gate is a source-level audit with dated historical evidence. It does not claim current live project settings or current backup status were refreshed.

## 1. Evidence inventory and limits

### 1.1 Immutable-baseline workflow inspection

Inspected:
- `.github/workflows/krim-schema-export.yml`
- `.github/workflows/krim-schema-manifest.yml`
- `.github/workflows/krim-staging-schema-bootstrap.yml`
- `.github/workflows/deploy-krim-pages.yml`

Positive controls in the schema export path:
- validates PostgreSQL URI shape without printing credentials;
- exports selected application schemas only;
- scans for executable top-level data statements and selected credential patterns;
- encrypts schema SQL with OpenSSL AES-256-CBC/PBKDF2 and uploads encrypted SQL plus checksum;
- manifest workflow validates selected artifact identity and checksum and publishes metadata rather than SQL bodies;
- staging import checks target application schemas for emptiness and applies schema DDL in one transaction.

These are schema-handling safeguards, not proof of backup completeness or recovery.

### 1.2 Explicit coverage exclusions

The export workflow runs `supabase db dump` for `public,private,krim_internal,graphql_public` and rejects row-data statements. Its own operator/reporting materials state it does not include:
- application business rows or audit history;
- Supabase Auth users, sessions, MFA/recovery factors or provider configuration;
- Storage object bytes (database metadata alone is insufficient);
- Vault contents and provider credentials;
- managed schemas/configuration such as `auth`, `storage`, `realtime`, `vault`, `cron`, `net`;
- custom database roles and all external integration configuration.

The encrypted artifact has a one-day retention setting in the workflow. A schema manifest or short-lived encrypted schema artifact is not a production data backup.

### 1.3 Historical backup evidence (16 November 2026)

The dated backup/DR audit recorded the Supabase organization on Free, Production project `ebltviniygljwwseplph` ACTIVE_HEALTHY in `ap-northeast-1` (Tokyo), and approximately 75 MB database size at that inspection. It recorded no automatic daily backups/PITR on the Free plan, no independently stored full data-bearing backup, no restore history exposed through the connected tools, no isolated full restore drill and no measured RPO/RTO. Nine Auth users and five private buckets were reported in that historical snapshot; the inspected Storage object query returned zero rows then. These figures are dated historical observations, not current counts.

The earlier audit also found nine active pg_cron jobs, but explicitly did not inspect job-run histories. A configured schedule is not evidence of successful execution, missed-run recovery, alerting or backup.

## 2. Critical findings

### P0 — No verified data-bearing Production backup and restore chain

The repository export is schema-only and cannot recover business records, operational/audit history, Auth identities, Storage bytes or secret/provider configuration. Historical Free-plan evidence found no automatic database backup/PITR and no separately stored full backup. No full isolated restore drill exists in the reviewed evidence.

**Required:** establish encrypted, data-bearing backups using supported platform procedures; separately back up Storage bytes and object metadata; define Auth/configuration/role/grant/function/cron/Edge Function reconstruction; keep encryption keys separate from backup artifacts; store multiple generations off-site and independently of Production/GitHub; verify checksums and critical record counts; complete a clean isolated restore and reconciliation before any operational launch.

### P0 — No tested restore, cutover or recovery objectives

No measured restore duration, data-loss boundary, RPO, RTO, recovery validation, write-freeze procedure, safe cutover or rollback drill was evidenced. RPO/RTO must remain **undefined / untested**.

**Required:** business-owner-approved RPO/RTO targets, isolated restore exercise, dependency reconstruction, row/FK/index/policy/grant/function/Auth/Storage verification, synthetic smoke checks, documented operator timings, write freeze, reconciliation and explicit resume approval. Do not advertise uptime or recovery guarantees until measured.

### P0 — Staging bootstrap lacks independent destination identity assertion

The baseline staging bootstrap reads `KRIM_STAGING_DB_URL`, then checks whether selected application schemas contain zero objects before applying the schema-only dump. The inspected workflow does not independently compare the connected database's project reference and region against an approved staging allowlist before DDL. An empty but wrong database could pass the emptiness test. The source export workflow is also triggered from a different branch lineage than the QA branch.

**Required:** before any future staging DDL, derive/validate the connected project identity and region from an independent trusted source; assert exact expected Staging project ref, reject Production ref, assert environment-specific secret binding, and log only non-secret identity metadata. Test this gate with wrong-ref, Production-ref and empty-wrong-target negative cases in an isolated disposable environment.

### P1 — Migration history and schema reconstruction are not deterministic

The 24 November migration reconciliation found 561 Production ledger versions versus 368 repository SQL files / 353 unique repository versions, 82 exact version matches, 479 Production versions without same-version files, 286 repository versions absent from the Production ledger, 13 duplicate-version groups and 209 same-name/different-version migration mappings. This is a historical source reconciliation, not a safe replay plan.

**Required:** freeze uncontrolled DDL; build a three-way version/name/content-hash crosswalk; recover exact historical SQL where possible; resolve duplicate version collisions and classify superseded/no-op files; build a reviewed baseline in a disposable project; compare resulting schema, functions, triggers, grants, RLS, extensions and indexes. Never blindly replay visible migration files or rewrite the Production ledger to force matching counts.

### P1 — Storage, Auth and integration recovery are not covered

Database/schema export does not preserve object bytes, identity/factor state, provider secrets, DNS/registrar access, payment webhook configuration, Telegram/email credentials or external partner integration settings. The prior audit identified no tested recovery procedures for these dependencies.

**Required:** create a versioned recovery inventory of secret *names*, owners, scopes, environment, rotation and reauthorization steps—never values in repository/report. Back up Storage object bytes independently with bucket/path/size/hash/content-type/ownership manifest. Document Auth recovery and user reauthentication/MFA reset procedures. Restore external provider configuration through controlled reauthorization, not copying live secrets into artifacts.

### P1 — Single-region and dependency failover are not proven

Historical Production evidence identified one Supabase project in Tokyo. No warm standby, tested regional database failover, DNS cutover, write-fencing/split-brain protection or multi-region recovery was demonstrated. GitHub Pages hosting and a single active backend do not establish multi-region availability.

**Required:** maintain an explicit dependency map (registrar/DNS, GitHub Pages, Supabase DB/Auth/Storage/Functions, payment provider, notification providers, operator access and partner systems); define outage modes and safe degraded behavior; design tested failover only after budget/legal review; prohibit side-channel shipment or financial writes that bypass audit controls.

### P1 — Worker, cron and webhook recovery can leave ambiguous or stuck state

C3.30 found notification jobs can remain in `processing` indefinitely after worker failure, provider acceptance can be mislabeled as delivery, and generic customer/partner delivery is not production-proven. Prior continuity review found cron schedules configured but no successful-run/lag/alert evidence. C3.25/C3.30 found the Razorpay captured-payment webhook can bypass the freight-collection kill switch.

**Required:** lease expiry and fenced reclaim, bounded retries/backoff, dead-letter queues, idempotent operation keys, durable unknown-outcome reconciliation, webhook monotonicity/replay protection and operator alerts. Preserve signed webhook evidence while freight collection remains disabled; do not create KRIM freight receipts or financial side effects while the collection gate is off. Do not automatically replay non-idempotent logistics or financial actions.

### P1 — Incident command and business continuity are not operationally evidenced

The 16 November continuity audit found the continuity UI contradicted itself by claiming server persistence while also describing browser-local preview; it found no complete incident commander/on-call, verified external communications, recovery timeline or post-incident review. No current operational exercise was performed in this gate.

**Required:** correct persistence claims; establish severity criteria, incident commander and technical/business owners, affected-service/region/tenant inventory, immutable timeline, approved customer/partner communications, verified fallback channels, recovery validation, safe-resume authority and post-incident actions. Keep a minimal offline runbook/contact tree, but never permit manual actions that bypass financial, customs, dispatch or evidence controls.

### P1 — Public status/availability claims are not evidence-backed

The immutable-baseline `public/status.html` statically asserts “All Systems Operational”, “Updated: Live”, and labels Supabase, Razorpay escrow, GPS telemetry and cryptographic ePOD as operational without a verified live status source. The copy describes global API gateway regions. This is not an uptime monitor or measured incident status.

**Required:** remove unsupported live/operational labels or replace them with a truthful, timestamped status feed backed by health checks and explicit unknown/degraded states. No 99.99%, multi-region, escrow, GPS, cryptographic immutability or availability claim without independent evidence.

## 3. Recovery acceptance plan — NOT RUN

Only after environment identity is proven and explicit authorization is granted, run synthetic tests in an isolated recovery project:

1. Restore a data-bearing DB backup and reconcile critical table counts, FK integrity, audit history, RLS, policies, grants, functions, extensions and indexes.
2. Restore Storage bytes and verify checksums, ownership/path metadata and private access boundaries.
3. Reconstruct Auth/configuration, roles, Edge Functions, cron and provider integrations without exposing secret values.
4. Prove staging wrong-project and Production-project targets are rejected before DDL.
5. Simulate DB, Edge Function, cron and provider outages; verify fail-closed behavior, idempotent recovery, queue lease reclaim and alert acknowledgement.
6. Exercise a delayed/out-of-order/duplicate webhook with freight collection disabled; prove no company-owned freight receipt or financial side effect.
7. Exercise incident declaration, commander assignment, communications approval, recovery validation, write reconciliation and safe resume.
8. Measure actual RPO/RTO and record operator steps, failures, residual gaps and retest evidence.

No item above was executed in this gate. All remain NOT TESTED.

## 4. Gate disposition

| Control | Status |
|---|---|
| Encrypted schema-only export | PARTIAL PASS (not a data backup) |
| Full data-bearing Production backup | FAIL / NOT EVIDENCED |
| Storage byte backup | NOT TESTED |
| Auth/configuration recovery | NOT TESTED |
| Isolated full restore drill | NOT TESTED |
| RPO/RTO | FAIL / UNDEFINED |
| Staging destination identity guard | FAIL / NOT PROVEN |
| Migration baseline determinism | FAIL / BLOCKED |
| Regional failover / DNS cutover | NOT TESTED |
| Worker/cron/webhook recovery | FAIL / BLOCKED |
| Incident command / on-call / continuity exercise | FAIL / BLOCKED |
| Public status accuracy | FAIL / BLOCKED |

**Final verdict: C3.37 FAIL / BLOCKED.** No live operational launch, freight collection, recovery certification, SLA/uptime promise, multi-region claim or production cutover is authorized by this audit. Limited non-binding partner discovery and internal development may continue with truthful disclosures.

## 5. Evidence references

- `docs/audits/KRIM-BACKUP-DISASTER-RECOVERY-AND-BUSINESS-CONTINUITY-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-SERVICE-CONTINUITY-OUTAGE-RESPONSE-AND-OPERATIONAL-RECOVERY-ASSURANCE-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-PRODUCTION-MIGRATION-HISTORY-RECONCILIATION-2026-11-24.md`
- `docs/testing/phase-00-gate-c3-30-shared-events-notification-provider-webhook-delivery-reliability-2026-11-25.md`
- `docs/testing/phase-00-gate-c3-31-global-infrastructure-environment-isolation-deployment-reliability-2026-11-25.md`
- `docs/testing/phase-00-gate-c3-25-finance-payments-accounting-refunds-settlement-revenue-readiness-2026-11-25.md`

## 6. Safety and evidence boundary

This is a read-only source and prior-evidence reconciliation. No Production or Staging SQL/RPC, migration, backup export, restore, project pause, DNS change, secret read/rotation, Auth/Storage action, webhook replay, provider call, notification, workflow dispatch, branch-protection change, deployment or live operational action was executed. Historical plan, region, size, object/user counts and migration counts are dated evidence and must not be represented as freshly verified current state.
