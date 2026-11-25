# Phase 00 — Secrets, browser configuration and environment separation audit

Date: 2026-11-25  
Repository: `rimjhimkrn-web/logistics-saas`  
Compared refs: `main` (currently deployed source branch) and `qa/phase-00-baseline-2026-11-25`  
Scope: Read-only review of shared Supabase configuration, public tracking page, shared-client module and GitHub Pages workflows. Secret values were not copied into this report. No secrets were retrieved, rotated, changed or tested.

## Executive verdict

**NOT VERIFIED for production release.** The reviewed configuration files contain browser-side Supabase publishable keys, which are expected to be public and are not equivalent to service-role/secret keys. No service-role key or Supabase secret-key marker was found in the specific files inspected. This is not a repository-wide secret scan and does not prove that no credential has ever been committed.

A critical environment-isolation bypass remains in the public tracking page: it hardcodes the Production Supabase URL and publishable key rather than using the host-verified shared environment client. This source is identical on `main` and the QA branch. The QA branch's shared config is safer, but the tracking page bypasses it.

## Files and refs inspected

- `config.js` — main SHA `991ac47ff035e0355938b9b99a06f31812bb9910`; QA SHA `4ea7a73c3eb68444c86e3238043fb5f16b65c4a1`.
- `tracking.html` — main and QA SHA `84e738f920b44fc6600bc1c2d052d96065cdd304`.
- `platform/krim-supabase.js` — main SHA `157f27dc0f132374ccdadcbe68dfaa1588875a76`; QA SHA `1c5de031c97e578fc00a97f9fc124209babb2114`.
- `.github/workflows/deploy-krim-pages.yml`.
- `.github/workflows/krim-production-smoke.yml`.

The repository code-search connector returned no indexed results for the tested secret-pattern queries, so no complete repository-wide scan is claimed.

## Findings

### 1. Browser keys are publishable, not secret — EXPECTED WITH LIMITS

The QA `config.js` defines publishable keys for Production and Staging/Development in browser code. The public tracking page also embeds a publishable key. Supabase publishable/legacy anon keys are designed to be exposed to browsers; security must come from RLS, RPC authorization, Edge Function validation, rate limits and least privilege.

No service-role key, `sb_secret_*` marker, Razorpay secret, Resend secret or Telegram bot token was identified in the specific inspected files. This is a limited source review, not proof of absence across every file, Git history, build artifact, logs or external systems.

### 2. Critical: public tracking bypasses host-based environment resolution

`tracking.html` hardcodes the Production Supabase project URL and publishable key and calls `/functions/v1/public-shipment-tracking` directly. It does not consume `KRIM_SUPABASE_CONFIG` or the shared client. The exact same file SHA is present on main and QA.

Consequences:
- A staging/preview copy of the tracking page still calls Production.
- Host-based environment isolation is bypassed for this public API path.
- Preview testing can expose real Production tracking lookup behavior and logs to test inputs.
- The page cannot be considered environment-isolated until the endpoint/key are selected through the approved host mapping or a server-side gateway.

This is a release blocker. Do not submit real or synthetic tracking tokens through the preview page until corrected.

### 3. QA config is materially safer than main, but is not deployed

QA `config.js` uses an explicit hostname allowlist, maps the GitHub Pages host to Production and staging/localhost to Staging, clears legacy globals, and creates a shared client with PKCE auth. `platform/krim-supabase.js` verifies the configured project identity.

Main's `platform/krim-supabase.js` differs from QA and does not contain the same shared-client identity assertion. The QA branch has not been merged/deployed; do not assume the public site uses its environment safeguards.

### 4. Legacy hardcoded project references remain

The public tracking page hardcodes Production in both branches. The shared config files necessarily contain approved project URLs for environment mapping; those are not secrets. A broader page/script inventory is still required to identify every remaining direct Supabase URL/key, especially legacy HTML and inline scripts.

### 5. GitHub Pages workflow does not require application secrets

The inspected deploy workflow builds static files and deploys GitHub Pages using the standard Pages deployment permissions. No application secret was referenced in the workflow source inspected. Public browser publishable keys are included in static assets by design. Do not place service-role, database password, payment secret, Resend API key or Telegram bot token in GitHub Pages artifacts or workflow logs.

### 6. Third-party GitHub Actions are tag-pinned, not commit-SHA pinned

The deploy workflow references actions by major-version tags (for example, checkout/configure-pages/upload-pages/deploy-pages). The smoke workflow similarly uses version tags. This is common but provides weaker supply-chain immutability than pinning full commit SHAs with reviewed update automation. This is a hardening recommendation, not evidence of compromise.

### 7. Supabase Edge Function secret inventory unavailable in this pass

The connected Supabase tools available for this audit exposed SQL and Edge Function inventory, but not a safe secret-name-only inventory operation. Secret values were not read. Therefore the presence, naming, rotation age and environment parity of Razorpay, Resend, Telegram, cron and other Edge Function secrets remain unverified.

### 8. Git history and external systems were not scanned

This pass did not scan all Git objects/history, deployed Pages artifacts, GitHub Actions logs, Supabase Edge Function source bundles for every function, connected provider dashboards, or external secret stores. A credential may have been exposed historically even if absent from current source. If any actual secret is ever found in a public commit, rotate/revoke it immediately; deleting the line alone is insufficient.

## Required remediation and verification

1. Replace the direct Production endpoint/key in `tracking.html` with the approved host-resolved endpoint configuration; fail closed on unknown hosts.
2. Add CI guards rejecting browser references to service-role/secret keys and unexpected hardcoded Supabase project URLs outside the central config.
3. Run a full repository and Git-history secret scan using a trusted scanner; redact findings and rotate any exposed credential.
4. Inspect GitHub Actions secrets by name/metadata only; ensure no secret is echoed or copied into static build output.
5. Obtain a Supabase secret-name-only inventory for Production and Staging; compare required names without reading values. Confirm rotation and least-privilege ownership.
6. Review every deployed Edge Function source for secret handling and ensure secrets are accessed only server-side.
7. Pin GitHub Actions to full commit SHAs with controlled update automation.
8. After the tracking fix is approved and deployed to Staging, test hostname mapping and assert no Staging page calls the Production project.

## Release decision

- Browser publishable key exposure: **EXPECTED / ACCEPTABLE by itself**.
- Service-role/secret key in the inspected files: **NOT OBSERVED (limited scope only)**.
- Repository-wide/Git-history secret exposure: **NOT VERIFIED**.
- Tracking endpoint environment isolation: **FAIL — Production hardcoded in main and QA**.
- QA shared-client environment guard: **SOURCE PASS; NOT DEPLOYED**.
- Supabase Edge Function secret inventory/rotation: **NOT VERIFIED**.
- GitHub Pages workflow secret leakage: **NOT OBSERVED in inspected workflow source**.
- Full release and real-user onboarding: **NOT APPROVED**.

No secrets, Production/Staging configuration, code or deployments were changed. NO EVIDENCE = NO PASS.
