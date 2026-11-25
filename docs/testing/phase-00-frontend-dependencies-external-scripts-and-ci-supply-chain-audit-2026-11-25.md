# Phase 00 — Frontend dependencies, external scripts and CI supply-chain audit

Date: 2026-11-25  
Repository: `rimjhimkrn-web/logistics-saas`  
Ref reviewed: `qa/phase-00-baseline-2026-11-25`  
Scope: Read-only inspection of root dependency manifests, selected critical HTML pages, external resource references and three GitHub Actions workflows. No dependency install, package execution, deployment or workflow mutation was performed.

## Executive verdict

**NOT VERIFIED for production supply-chain readiness.** The repository root has no `package.json` or standard Node lockfile at the inspected ref. The site is largely static HTML/JavaScript, but important browser pages load executable dependencies from mutable CDN version references. The tracking page loads Tailwind's browser CDN and an unused Supabase JS SDK script. CI currently uses GitHub-maintained `actions/*` actions on version tags; workflow permissions are mostly explicit and appropriately narrow. This is a focused sample, not a complete scan of every HTML file, script or nested project.

## Scope and evidence

### Root dependency manifests
The following root paths were checked and returned not found:
- `package.json`
- `package-lock.json`
- `pnpm-lock.yaml`
- `yarn.lock`
- `bun.lockb`
- `deno.json`
- `deno.jsonc`

This indicates no root-managed Node dependency graph was found at those paths. It does not prove there are no nested package manifests or vendored libraries elsewhere in the repository.

### Critical HTML pages sampled
- `tracking.html` — SHA `84e738f920b44fc6600bc1c2d052d96065cdd304`
- `public/shipper/booking-request.html` — SHA `74ccaaeba9453b518526ef58956314f504f7a5e3`
- `public/partner/partner-onboarding.html` — SHA `59c5e0c6f3d909bb1f6903bb97d3f0c167260b47`

### Workflows inspected
- `.github/workflows/deploy-krim-pages.yml`
- `.github/workflows/krim-production-smoke.yml`
- `.github/workflows/krim-static-link-audit.yml`

## Findings

### 1. Tracking page loads unpinned browser dependencies — HIGH

`tracking.html` loads:
- `https://cdn.tailwindcss.com`
- `https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2`

The Supabase JS SDK script is not used by the reviewed tracking-page logic, which calls the public tracking Edge Function using fetch. It is therefore an unnecessary executable third-party dependency on a page handling bearer tracking tokens. Remove it after confirming no dynamic dependency elsewhere in the page.

The Tailwind browser CDN is a runtime script rather than a locally built, pinned CSS artifact. This expands the page's runtime supply-chain and availability dependency. Replace it with locally generated static CSS.

Neither external script tag in the sampled page uses Subresource Integrity (SRI). SRI is not a complete solution for mutable version URLs; use immutable versioned assets and/or self-hosted build artifacts, with CSP as an additional control.

### 2. Supabase JS SDK uses a floating major-version CDN reference — HIGH

The sampled booking and partner onboarding pages also load `@supabase/supabase-js@2` from jsDelivr. The major-version range can resolve to a newer package release without a corresponding reviewed source change in this repository. No package lock or integrity hash accompanies these browser references.

**Required:** centralize and pin an exact reviewed SDK version, preferably through a controlled local build/vendor artifact with integrity verification. Keep a documented update process and test the upgrade before release.

### 3. Google Fonts is an external privacy/availability dependency — MEDIUM

The booking and partner onboarding pages load Google Fonts CSS and `fonts.gstatic.com` resources. This is not an executable JavaScript supply-chain risk in the same class as CDN scripts, but it creates third-party availability and visitor IP/request metadata exposure. Self-host approved font files if privacy, uptime and consistent rendering are priorities.

### 4. External link is not the same as external executable code

The tracking page links to OpenStreetMap for a map location. In the sampled source, this is a navigation link, not a script import. Treat it as a third-party destination rather than a runtime code dependency. Existing `target=_blank` links should retain `rel=noopener noreferrer`.

### 5. GitHub Actions references are official GitHub-maintained actions, not arbitrary third-party actions

The three inspected workflows use:
- `actions/checkout@v4`
- `actions/configure-pages@v5`
- `actions/upload-pages-artifact@v3`
- `actions/deploy-pages@v4`
- `actions/setup-node@v20/v22`
- `actions/upload-artifact@v4`

These are under the official `actions/*` organization. No third-party Marketplace action or reusable workflow was observed in these three files. The refs are version tags rather than immutable commit SHAs, so they can move. For stronger reproducibility and supply-chain assurance, use full SHA pins or GitHub's workflow dependency lockfile feature where supported, with reviewed Dependabot updates. This is hardening, not evidence that the current actions are compromised.

### 6. Workflow permission boundaries are generally explicit

- Pages deploy workflow declares `contents: read`, `pages: write`, `id-token: write`; the deploy job requires the build job and uses the GitHub Pages environment.
- Production smoke and static-link audit workflows declare `contents: read`.
- No application secrets are passed into the inspected workflow steps.
- The deploy workflow runs on `main` push and manual dispatch; QA changes do not deploy Pages through this workflow.

These are positive source observations. Repository/environment settings, branch protection, required reviewers and actual token permissions were not independently verified.

### 7. Static audit workflow has a non-failing intermediate command

The static-link audit runs `node scripts/audit-krim-links.mjs ... || true`, so that step itself cannot fail on a nonzero exit. A later enforcement step checks `broken_local_references` and fails if the count is positive. This still enforces the specific broken-reference count, but other script failures or malformed output should be checked to ensure they cannot be masked or converted into a misleading report.

### 8. No complete repository-wide external script inventory

The GitHub code-search connector returned no indexed matches for tested terms. This is not proof that matching code is absent. Only the sampled HTML pages and selected workflow files are evidence for this report. The prior static scan counted 1,017 HTML source files, so a full script/CSS/font/iframe/CDN inventory should be generated by a repository-local scanner and saved as a CI artifact.

## Required remediation and verification

1. Remove the unused Supabase JS SDK script from `tracking.html`; remove Tailwind browser CDN and compile static CSS.
2. Pin Supabase JS to an exact reviewed version; avoid floating `@2` CDN URLs.
3. Inventory all HTML/JS/CSS external resources across all project-owned pages, including scripts, stylesheets, fonts, iframes, imports, workers and dynamically constructed URLs.
4. Add CI rules for unapproved external scripts, missing exact versions/integrity, and unexpected CDN origins.
5. Introduce a restrictive Content Security Policy after inventorying required origins; avoid broad `unsafe-inline`/wildcard policies where feasible.
6. Consider self-hosting Google Fonts for privacy and uptime.
7. Pin GitHub Actions to verified full commit SHAs or adopt a workflow dependency lockfile; keep automated dependency updates reviewed.
8. Make the static audit fail closed on scanner execution/parsing errors, not only the broken-link count.
9. Run a browser smoke test with network request capture and verify the final page loads only approved resources.

## Release decision

- Root package manifest/lockfile: **NOT PRESENT at inspected root paths**.
- Tracking page external runtime dependencies: **FAIL — unnecessary SDK and Tailwind CDN present**.
- Supabase SDK exact version/integrity: **FAIL — floating major version used in sampled pages**.
- Google Fonts external dependency: **MEDIUM hardening item**.
- GitHub Actions third-party Marketplace actions: **NONE OBSERVED in the three inspected workflows**.
- Workflow permissions: **SOURCE PASS (runtime/repository settings not verified)**.
- Full site external resource inventory: **NOT COMPLETED**.
- Browser network/SRI/CSP runtime verification: **NOT TESTED**.
- Production supply-chain readiness: **NOT VERIFIED**.

No source files, workflows, dependencies, secrets or deployments were changed. NO EVIDENCE = NO PASS.
