# Phase 00 — Gate C3.62: Global infrastructure, environment configuration, deployment and integration readiness

**Audit date:** 25 November 2026  
**Evidence baseline:** immutable source commit `72d75a18f985ceb09e468839435ee95700e11e46`; read-only workflow, configuration, PWA and integration source review plus dated 24 November notification parity snapshot.  
**Verdict:** **FAIL / BLOCKED — NO-GO for declaring production deployment, isolated Staging parity, global availability, disaster recovery or integrations launch-ready.**

## Scope and method
Reviewed GitHub Pages build/deploy workflow, static smoke workflow, encrypted schema export and Staging bootstrap workflows, environment examples, PWA manifests/service worker, repository static audit script, deployment-manifest page and dated notification Edge Function parity audit. No workflow was dispatched; no deployment, environment inspection, secret access, database connection, schema export/import, provider call, live browser probe, DNS/CDN test or infrastructure mutation was performed.

## Positive controls observed
1. GitHub Pages deployment is explicit on pushes to `main`, uses limited workflow permissions, a build/deploy job boundary, Pages artifact upload and deployment action.
2. A separate smoke workflow runs critical-path and repository-wide static checks and stores an audit artifact. This is static/source validation, not live production smoke testing.
3. Schema export is designed to be schema-only, encrypted with AES-256-CBC/PBKDF2, SHA-256 checked, credential-pattern scanned and uploaded as an encrypted artifact. Bootstrap rejects SQL data statements/credential-like strings, checks target application schemas are empty and imports in one transaction.
4. Bootstrap states that production rows, Auth users, Storage objects, Vault secrets and provider credentials are not copied.
5. Mobile environment examples use project URL and publishable-key placeholders, not service-role keys.
6. Dated 24 Nov notification parity audit preserves two deployed function source snapshots without secret values and distinguishes founder Telegram queues from the general notification subsystem.

## P0 — Release-blocking evidence gaps

### INF-01 — No current deployment/hosting evidence
No GitHub Pages deployment history, live artifact, deployed commit, custom domain/DNS, TLS, cache headers, CDN, uptime, regional availability or actual route response was inspected. A workflow or deployment-manifest page is not proof of a running multi-region Kubernetes/CDN architecture. The reviewed deployment-manifest page claims three Kubernetes regions, 99.99% SLA and a frozen production cluster, but repository evidence does not substantiate those claims.
**Required:** establish actual hosting topology/provider ownership; verify deployed commit/artifact; test critical routes, DNS/TLS/headers/cache and remove or relabel unsupported infrastructure/SLA claims.

### INF-02 — Staging isolation and schema parity unproven
The Staging bootstrap can automatically apply a schema-only dump sourced from Production after the encrypted export workflow completes from its configured branch and required secrets exist. It checks target schemas are empty, but does not independently assert that the connection URL identifies the intended Staging project or prove isolation from Production external services. Schema DDL can include functions, policies, grants and provider-facing code. Workflow was not executed.
**Required:** pin/assert exact Staging project ref/host against allowlist; require protected environment approval and manual operator gate; prove separate Auth, Storage, Vault, Edge Function secrets, payment/email/Telegram endpoints and redirects; review DDL and migration fingerprint. Do not run bootstrap until approved.

### INF-03 — No release-to-runtime evidence chain
Pages deployment does not invoke the separate smoke/static-audit workflow as a required pre-deploy dependency. The smoke workflow checks repository files/scripts, not the deployed website or live Supabase APIs. No immutable release manifest binds source commit, artifact digest, migrations, Edge Function versions, configuration and post-deploy smoke evidence.
**Required:** require CI checks before release; record artifact checksum/source commit/deployed artifact; run post-deploy non-mutating smoke checks and rollback verification; prevent QA branch deployments absent explicit authorization.

## P1 — Material configuration and reliability risks

### INF-04 — Deployment package is overly broad
Deploy workflow rsyncs almost the entire repository into `_site`, excluding only `.git`, `.github` and `_site`, then adds customer-os pages. The baseline tree includes `node_modules`; unnecessary build material and internal files can inflate or contaminate the public artifact.
**Required:** explicit public-site allowlist; exclude node_modules, private exports, tests, audit internals, env files and build artifacts; scan final artifact for secrets/unintended files.

### INF-05 — GitHub Pages base-path and PWA paths inconsistent
Site is hosted at `/logistics-saas/`. Root `manifest.json` uses project-scoped start URL/scope, but `public/manifest.webmanifest` uses root-absolute `/index.html` and `/assets/icon-192.png`. Root `service-worker.js` precaches origin-root paths such as `/index.html`, `/app/customer/index.html`, `/config.js`; route allowlist also uses origin-root paths. These do not automatically map to the Pages project subpath. Deploy copies `public/` under Pages root and copies `public/customer-os/` again under `customer-os/`; no canonical manifest/service-worker registration and deployed offline/install test was demonstrated.
**Required:** standardize one base-path-aware manifest/service-worker strategy; verify install, update, cache invalidation, offline fallback and authenticated route non-caching in Android Chrome and desktop.

### INF-06 — Staging bootstrap trust/approval needs hardening
Workflow uses `workflow_run` after schema export and branch-filters to `mobile/krim-partner-app`; it can perform DDL on configured Staging DB without a separate protected-environment approval step in reviewed YAML. It relies on a repository secret URL and checks emptiness, not project identity. Do not treat it as a proven safe Staging process.
**Required:** protected GitHub Environment reviewers, exact project-ref assertion, least-privilege credentials, explicit manual approval, branch/artifact SHA binding and dry-run review artifact.

### INF-07 — Supabase project/migration deployment contract incomplete
No `supabase/config.toml` was found in the immutable baseline tree. Repository evidence did not establish reproducible CLI configuration, migration ordering, project-link discipline, migration-history reconciliation, Edge Function deployment manifest, Auth redirect allowlist or environment-variable inventory. Prior audits record Production migration-history mismatch. Missing config in this baseline does not prove dashboard settings are absent.
**Required:** document non-secret project refs, CLI version, migration parity, function versions, Auth settings, Storage policies, Vault secret names (never values), redirects, cron/queues and rollback procedure. Resolve history mismatch before schema changes.

### INF-08 — Runtime integrations not proven
Dated 24 Nov notification parity audit says active retry worker handles founder inquiry/follow-up Telegram queues only; Resend route checks credential presence but sending remains disabled; general customer/partner outbox has zero records and no production dispatch evidence. General functions have lease recovery/fencing, bounded retry/dead-letter, delivery-attempt idempotency and provider-acceptance-vs-delivery gaps.
**Required:** keep Resend/customer/partner notifications unavailable until isolated tests prove sender domain, recipient policy, provider response, signed webhooks, bounce/complaint handling, idempotency, retry, dead-letter and tenant authorization. Founder Telegram test separately requires approval.

### INF-09 — Secrets/environment separation not independently certified
No GitHub/Supabase secret configuration was inspected and no deployment artifact scan was run. Schema export/bootstrap depend on Production DB URL, Staging DB URL and export passphrase repository secrets. Separation, scope, rotation and least privilege are not evidenced. No secrets were read.

### INF-10 — Backup/restore, disaster recovery and monitoring unproven
No backup schedule/retention, PITR entitlement, restore drill, RPO/RTO, alert routing, on-call runbook, connection pool limits, edge quotas, regional failover, incident response or outage tests were verified. NFR latency/availability targets are requirements, not measured SLOs.

## Required controlled verification (not executed)
1. Confirm hosting provider, Pages site, domain/DNS/TLS, deployed commit and artifact checksum.
2. Validate public artifact allowlist; block environment files, secrets, test artifacts and private reports.
3. Validate branch protection, required checks, environment approvals and workflow permissions.
4. Prove Staging identity/isolation; compare schema/migration/function fingerprints; no automatic bootstrap until approval.
5. Verify Auth redirects, email URLs, Storage policies, Edge Function JWT settings, secret separation and provider endpoints.
6. Test PWA manifest/start URL/icons/service-worker scope under `/logistics-saas/`, cache update/offline behavior and ensure auth/API/private responses are never cached.
7. Run real browser route smoke tests on mobile Chrome/desktop; inspect deployed assets, 404s and console errors.
8. Test notification, Razorpay sandbox, Telegram and Resend only after separate authorization and isolated test configuration.
9. Verify backup restoration and incident runbooks before reliability claims.
10. Establish performance baselines and staged load gates only after isolation and functional/security gates pass.

## Evidence classification
- **Immutable source:** Pages deployment YAML; CI smoke workflow; encrypted schema export/bootstrap YAML; PWA manifests/service worker; mobile env examples; static audit script; deployment-manifest claims.
- **Historical snapshot:** 24 Nov notification source-parity audit; not current runtime proof.
- **Runtime:** NOT TESTED. No workflow, deployment, DB connection, schema export/import, live browser, DNS/TLS, provider, restore or load test performed.

## Decision
**FAIL / BLOCKED.** Useful deployment and schema-safety automation exists, but hosting claims, Staging identity/isolation, artifact hygiene, Pages base-path PWA behavior, deployment-to-runtime evidence, notification integrations and disaster recovery are not certified. Do not claim multi-region availability, 99.99% SLA, disaster recovery readiness or production integration readiness.

## Safety boundary
Read-only immutable-source inspection and review of dated notification audit only. No workflow dispatch, secret read, deployment/rollback, Production/Staging DB connection or DDL/DML, provider call, test notification, DNS/configuration change or secret rotation.
