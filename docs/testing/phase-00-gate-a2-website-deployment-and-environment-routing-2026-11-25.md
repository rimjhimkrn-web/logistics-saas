# Phase 00 — Gate A2: Website deployment and environment-routing source verification

Date: 2026-11-25
Repository: rimjhimkrn-web/logistics-saas
QA branch: qa/phase-00-baseline-2026-11-25
Scope: read-only GitHub metadata and source inspection; web-origin reachability attempts only.
Safety: No workflow dispatch, merge, deployment, database operation, secret access, provider operation or environment write.

## Result

**Gate A2: BLOCKED — critical production/QA source divergence identified; live deployment binding remains unverified.**

## Evidence inspected

1. Repository metadata: public repository; default branch `main`; linked GitHub connection has repository admin-level permission.
2. Main deployment workflow `.github/workflows/deploy-krim-pages.yml`, blob SHA `7bb0d3c877f4b7083c8ae86d95a9fe6dee7a6a8a`:
   - Deploy trigger is push to `main` and manual dispatch.
   - Build copies repository content into `_site`, then deploys with GitHub Pages.
   - No Cloudflare Pages deployment step or Staging deployment job is present.
3. Main `config.js`, blob SHA `991ac47ff035e0355938b9b99a06f31812bb9910`:
   - Accepts page-injected `window.KRIM_ENVIRONMENT` or a meta tag before selecting the environment.
   - Defaults an unrecognized hostname to `production`.
   - Reuses a pre-existing `window.KRIM_SUPABASE` or `window.supabaseClient` before creating a new client.
   - Sets `KRIM_AUTH_DISABLED` true for preview.
4. QA `config.js`, blob SHA `4ea7a73c3eb68444c86e3238043fb5f16b65c4a1`:
   - Uses an explicit hostname allowlist and throws on unknown hosts.
   - Clears pre-existing global client/config values before resolving the host.
   - Maps `rimjhimkrn-web.github.io` to Production and `krim-staging.pages.dev`/subdomains plus localhost to Staging.
   - Keeps Staging Auth enabled; review mode is a read-only UI flag.
5. Attempts to open the public GitHub Pages config and candidate Staging config through available web retrieval returned inaccessible/internal errors. Independent direct HTTP/DNS check from the execution environment failed with DNS resolution unavailable. This is **inconclusive**, not evidence that either website is down.

## Findings

### F-A2-01 — Main branch environment selection is not fail-closed (P0)
The current `main` source permits page-level environment override and treats unknown hosts as Production. It also trusts a pre-existing global Supabase client. If this source is what GitHub Pages serves, a page override or injected client could defeat the hostname-to-project binding. QA branch contains a materially safer implementation, but it is not deployed by the inspected workflow.

Required remediation: review all pages for legitimate overrides/injected clients, then move the fail-closed allowlist implementation into a separately reviewed change and test with a harmless local browser harness. Do not merge/deploy under this audit.

### F-A2-02 — Staging web deployment is not configured in the inspected main workflow (P0)
The only inspected deployment workflow deploys GitHub Pages from `main`. It does not deploy `krim-staging.pages.dev`. QA config references that hostname, but no hosting project, deployment ID, deployed SHA, DNS/TLS/HTTP response or branch mapping was available in this read-only inspection.

Required evidence: identify the actual staging hosting provider/project; capture its deployment record, branch/ref and exact SHA; verify DNS, TLS and HTTP; fetch deployed `config.js` and assert it maps only to the Staging Supabase project; confirm Auth Site URL/redirect allowlist.

### F-A2-03 — Public-origin reachability remains NOT TESTED
Both public-origin fetch attempts were inconclusive due tool retrieval errors and unavailable DNS resolution in the execution environment. Do not record either origin as PASS or FAIL.

## Gate disposition

- GitHub Pages build/deploy workflow source: PASS (source inspection only).
- Main environment selection safety: FAIL (source-level design finding).
- QA environment allowlist: PASS (source inspection only; not deployed).
- Production live deployment SHA and served config: NOT TESTED.
- Staging hosting identity, deployment SHA, DNS/TLS/HTTP and served config: BLOCKED / NOT TESTED.
- Gate A2 overall: **BLOCKED**.
- No synthetic users, authenticated browser tests or staging writes are authorized.

## Exact next operator evidence

1. Provide the Staging hosting provider/project name and read-only deployment access or a deployment-record screenshot showing branch/ref, commit SHA and URL.
2. Privately verify the deployed staging `config.js` and its Supabase project ref; never share service-role keys or secrets.
3. Confirm Auth Site URL and redirect allowlist for both production and staging.
4. Approve a dedicated source change to make production environment selection fail-closed, followed by local/browser tests before any deployment.

No application source was changed. Only this QA evidence report is being committed.
