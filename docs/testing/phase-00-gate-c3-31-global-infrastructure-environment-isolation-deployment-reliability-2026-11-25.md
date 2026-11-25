# C3.31 — Global Infrastructure, Environment Isolation & Deployment Reliability Audit

**Date:** 25 November 2026  
**Programme:** KRIM Global Platform — Phase 00  
**Baseline:** `72d75a18f985ceb09e468839435ee95700e11e46` (immutable main/source baseline)  
**QA branch:** `qa/phase-00-baseline-2026-11-25`  
**Method:** Read-only GitHub repository/tree/workflow/source inspection and reconciliation with existing staging, migration, backup and recovery audits. No workflow dispatch, deployment, database write, secret read, restore, or provider operation was performed.

## Executive verdict

**FAIL / BLOCKED — NO-GO for production release certification, disaster-recovery claims, or unrestricted real-user onboarding.**

The source tree confirms a GitHub Pages deployment pipeline and a separately gated schema-only staging bootstrap. It does not establish a verified production infrastructure inventory, independent data backup, tested restore, environment-specific frontend configuration, controlled release promotion, or tested rollback. Several repository UI artefacts make production-grade infrastructure claims (multi-region Kubernetes, 99.99% SLA, frozen release) that the runtime explicitly does not enforce.

This is a source/configuration audit. It does not claim the public site, Supabase projects, GitHub Pages deployment, DNS/CDN, secrets, backups, or workflow executions were runtime-tested in this gate.

## Evidence inspected

- `.github/workflows/deploy-krim-pages.yml`
- `.github/workflows/krim-production-smoke.yml`
- `.github/workflows/krim-staging-schema-bootstrap.yml`
- `.github/workflows/krim-schema-export.yml`
- `platform/krim-config.js` (repository baseline)
- `public/production/production-runtime.js`
- `public/production/deployment-manifest.html`
- `scripts/krim-production-smoke.mjs`
- `docs/KRIM-STAGING-BASELINE-ASSESSMENT-2026-11-07.md`
- `docs/KRIM-STAGING-MIGRATION-RECONCILIATION-2026-11-07.md`
- `docs/audits/KRIM-BACKUP-DISASTER-RECOVERY-AND-BUSINESS-CONTINUITY-AUDIT-2026-11-16.md`
- `docs/KRIM-PRODUCTION-READINESS-MASTER-REGISTER.md`
- GitHub repository tree at immutable baseline (2,180 blobs; tree not truncated), branch metadata and workflow configuration.

## Positive controls observed

1. GitHub Pages deployment is limited by workflow trigger to pushes on `main` or manual dispatch; it assembles a static site, checks key homepage/customer-OS files, uploads a Pages artifact and deploys it.
2. The Pages workflow declares limited GitHub token permissions: contents read, Pages write and OIDC id-token write.
3. A concurrency group serializes Pages deployments and cancels an in-progress deployment when a newer run starts.
4. A smoke workflow exists for pushes, pull requests targeting `main`, and manual dispatch. It runs a Node smoke script and repository static-link audit and retains an audit artifact for 30 days.
5. The staging schema bootstrap requires a successful named schema-export workflow run on the `mobile/krim-partner-app` branch, checks for a staging DB secret, verifies encrypted artifact checksum and decrypts only within the runner.
6. The staging bootstrap attempts to reject row-data statements and selected credential patterns, checks application schemas are empty, applies DDL in one transaction, and reports object counts.
7. The schema export workflow encrypts schema-only SQL, scans for selected credential patterns and uploads an encrypted artifact with one-day retention.
8. The historical staging baseline and migration reconciliation correctly warn that empty staging advisor results are not security sign-off and that blind replay of the visible migration directory is unsafe.

## P0 — release and recovery blockers

### P0.1 — No proven recoverable production backup or restore

The prior backup audit records Supabase Free plan, no automatic daily database backups/PITR, no independent full data-bearing backup, no completed isolated restore drill, and no tested RPO/RTO. The current repository export is explicitly schema-only: it excludes business rows, Auth users, Storage object bytes, Vault secrets, provider credentials and managed service state. One-day retention of an encrypted schema artifact is not a business continuity backup.

**Impact:** loss/corruption of the production database or Storage objects could not be shown recoverable. No live operational launch or customer data commitment should rely on this recovery posture.

### P0.2 — Environment separation is not proven end-to-end

The staging baseline records a distinct Staging project (`qrpcivhdxobiaofppbkl`) and Production project (`ebltviniygljwwseplph`), but the staging project historically had zero application tables and zero application routines. The frontend configuration and deployment mapping have not been verified as environment-isolated in the deployed artefacts. Prior C3.6 review found GitHub Pages source defaults to Production Supabase while a preview hostname resolves to Staging in source; deployment/host binding remains unverified.

The staging bootstrap trusts the configured `KRIM_STAGING_DB_URL` secret as its target and checks that selected application schemas are empty. The workflow does not independently assert the target Supabase project ref/region against an allowlisted staging identity before executing DDL. Empty-schema detection is a useful guard, but not a complete target identity control.

**Impact:** an incorrect or misconfigured secret could point a nominal staging operation at an unintended database. No staging application runtime parity or isolation certification exists.

### P0.3 — Production deployment path lacks verified release promotion controls

The Pages workflow deploys on any push to `main` and supports manual dispatch. Repository branch metadata at the inspected point reports `main` and the QA branch as unprotected (protection disabled; no required status checks). The smoke workflow runs for PRs to `main`, but the available configuration does not establish that its result is required before merge. The deployment workflow itself does not depend on a passing smoke workflow, explicit release approval, signed release manifest, immutable artifact promotion, or rollback gate.

**Impact:** a commit may reach the deployment path without demonstrated mandatory quality/security gate completion. QA documentation is kept on a separate QA branch, but source-level separation alone does not establish a controlled release process.

## P1 — major infrastructure and reliability gaps

1. **No infrastructure-as-code proof.** No authoritative Terraform/Kubernetes/region/replica/ingress configuration was established from the inspected deployment pipeline. The deployment-manifest page's multi-region Kubernetes, 12-pod, Terraform lock, 99.99% SLA and GA/frozen labels are not backed by the inspected workflow. The runtime helper explicitly states that it does not calculate a release hash, verify telemetry, or enforce a cryptographic freeze.
2. **No verified deployed-version provenance.** The workflow creates a Pages artifact but the reviewed evidence does not provide a signed artifact digest, environment-bound release record, source-to-deployed-content attestation, or independent post-deployment smoke result.
3. **Rollback is not evidenced.** Concurrency controls are not rollback. No tested previous-artifact redeployment, DB compatibility rollback, feature-flag rollback, or incident cutover procedure was established.
4. **Staging bootstrap source/target assurance is incomplete.** The workflow is triggered from a workflow_run event and validates branch name/conclusion, but does not establish a reviewed immutable source commit allowlist, a signed schema artifact provenance statement, or independent project-ref validation before applying DDL. The empty-target test can also pass for a wrong empty project.
5. **Staging is not yet a usable test environment.** Historical staging assessment reports zero application tables/routines/policies and no migrations applied. Migration reconciliation records 422 production migration ledger entries versus 257 visible migration files on the reviewed branch; only 64 filename timestamps match and 358 ledger entries lack same-version files. This mismatch prevents safe blind migration replay and means application parity is unproven.
6. **Secrets/configuration inventory and rotation are not evidenced.** The workflows refer to repository secrets, but no complete inventory of secret names, owners, scopes, rotation, recovery, environment binding, or least-privilege review was verified. Secret values were not accessed.
7. **Backup scope omits Storage/Auth/Vault and recovery coordination.** Schema-only export is not enough; object bytes, Auth identities/factors, database data, audit history, edge-function/configuration state and reauthorization steps need independently protected recovery procedures.
8. **No verified availability/observability contract.** No current multi-region failover, CDN origin health, database failover, queue lag, uptime measurement, alert ownership, incident on-call acknowledgement or status-page process was demonstrated by this source audit.
9. **Workflow supply-chain controls need hardening.** Actions are referenced by mutable major tags (for example checkout/setup/upload/deploy/configure-pages and Supabase setup) rather than immutable commit SHAs in the reviewed workflow files. No complete dependency provenance/SBOM or signed build attestation was established.
10. **Static smoke is not runtime smoke.** The smoke workflow validates repository code and static links. It does not itself establish successful authentication, tenant isolation, database connectivity, partner/customer journey, payment safety, provider callbacks, browser/device compatibility or production health.

## Environment and deployment disposition

| Layer | Evidence status | Gate disposition |
|---|---|---|
| GitHub Pages source workflow | Source inspected | PARTIAL PASS |
| Main/QA branch protection | Branch API reports protection disabled | FAIL |
| Required CI before production deploy | Not established | BLOCKED |
| Deployed artifact provenance | Not established | NOT TESTED |
| Public site runtime/host health | Not tested in this gate | NOT TESTED |
| Production Supabase | Prior read-only audits only; no current runtime probe | BLOCKED |
| Staging Supabase application schema | Historical snapshot empty | FAIL / BLOCKED |
| Production-to-staging parity | Migration drift and config isolation unresolved | FAIL / BLOCKED |
| Full data backup | No evidence | FAIL |
| Isolated restore drill | No evidence | NOT TESTED |
| RPO/RTO | Undefined / untested in prior audit | FAIL |
| Multi-region failover / 99.99% SLA | No infrastructure evidence | NOT TESTED |
| Rollback / disaster cutover | No completed drill | NOT TESTED |

## Required remediation sequence

1. Keep all live shipment, freight-collection, automated payout and operational execution gates disabled.
2. Define and independently verify Production/Staging project identities, region, URL/key injection, hostname mapping and per-environment secrets. Add an explicit staging project-ref assertion before any staging DDL.
3. Reconcile production migration history and repository source before building staging. Do not blindly replay the visible migration directory.
4. Establish a data-bearing encrypted backup covering database business rows and audit history, with separately protected Storage object bytes and documented Auth/configuration recovery. Store off-site outside the production project and repository.
5. Set business-approved RPO/RTO and run a complete isolated restore drill; reconcile row counts, constraints, policies, grants, object bytes/metadata, Auth identities and audit history.
6. Protect `main` with required reviews/status checks; require smoke/security checks before deployment; add explicit release approval and immutable build/artifact provenance.
7. Pin third-party GitHub Actions to reviewed commit SHAs; add least-privilege workflow permissions, secret scope/rotation, dependency/SBOM and artifact attestation.
8. Create tested rollback for static artifact and database-compatible application release; document incident command and customer communications.
9. Add post-deployment environment-aware health checks and monitored alerts, then perform controlled staging browser/API and recovery tests before any production canary.
10. Replace unsupported infrastructure/SLA/GA/frozen claims in production-facing UI with truthful current status until evidence exists.

## Gate decision

**C3.31 FAIL / BLOCKED.** The code contains useful deployment and schema-only staging safeguards, but there is no verified production-grade infrastructure/release-control/backup/restore posture. No evidence in this gate authorizes live operations, a 99.99% availability claim, a multi-region deployment claim, or a production release certification.

**Safety record:** No Production or Staging SQL/RPC, migration, secret read, workflow dispatch, GitHub Pages deployment, restore, backup export, provider call, Auth action, external communication, or live operational action was executed. Findings about project plan, staging schema, migration drift and backup posture are historical evidence from the cited prior audits, not newly refreshed live measurements.
