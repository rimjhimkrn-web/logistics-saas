# Phase 00 — Gate A3: Authentication redirect and client-initialization source audit

Date: 2026-11-25
Repository: rimjhimkrn-web/logistics-saas
Branch: qa/phase-00-baseline-2026-11-25
Scope: read-only source inspection of main and QA branch.
Safety: No Auth settings read or changed; no secrets accessed; no user sessions, emails, redirects, deployments or database operations initiated.

## Disposition

**Gate A3: BLOCKED — authentication redirect configuration is not verified, and the main-branch auth client bypasses the shared environment resolver.**

## Evidence

### Main branch
- `config.js` blob `991ac47ff035e0355938b9b99a06f31812bb9910`.
- `auth-core.js` blob `cbdc4d235c3758c5990c6168dbc5f39e437c4f88`.
- Main `config.js` resolves the hostname but permits page/meta environment overrides, treats unknown hosts as Production, and reuses pre-existing global Supabase clients.
- Main `auth-core.js` independently imports Supabase JS from a floating jsDelivr `@2/+esm` URL and hardcodes the Production Supabase URL and publishable key. It creates a second client instead of using the hostname-verified shared client.
- Main auth-core has PKCE, persistent sessions, token refresh and URL session detection configured. These settings alone do not prove correct Site URL, redirect allowlist, deployed callback routes or end-to-end recovery.
- The inspected main deployment workflow deploys GitHub Pages only from main.

### QA branch
- `config.js` blob `4ea7a73c3eb68444c86e3238043fb5f16b65c4a1`.
- `auth-core.js` blob `2cd5fb070ebfbaf2e712eef25dba8fc185e7f20f`.
- `platform/krim-supabase.js` inspected and verifies the shared client's project ref and URL against the allowlisted Production/Staging refs.
- QA auth-core imports that shared client rather than constructing a Production-only client.
- QA config enforces hostname allowlisting, clears pre-existing client globals, and maps the candidate Staging host to the Staging Supabase project.
- These are source-level controls only; QA is not deployed by the inspected Pages workflow.

### Redirect route discovery
The guessed paths `auth/login.js`, `auth/callback.js`, and `supabase/config.toml` do not exist at those exact repository paths in either inspected ref. This is not proof that callback handling or redirects are absent; actual HTML entry points, scripts and Supabase Auth settings must be inventoried.

## Findings

| ID | Severity | Finding | Status |
|---|---|---|---|
| A3-01 | P0 | Main auth-core creates an independent Production-only Supabase client, bypassing environment selection and risking Production Auth/session use on non-production hosts. | FAIL — source |
| A3-02 | P0 | Main config accepts page/meta override, unknown-host Production fallback and pre-existing global client reuse. | FAIL — source; repeated from A2 |
| A3-03 | P0 | QA shared client enforces project-ref/URL identity, but this safer source is not deployed. | PASS — source only |
| A3-04 | P0 | Supabase Auth Site URL and redirect allowlist for both projects have not been inspected. | NOT TESTED |
| A3-05 | P1 | Actual login, signup, email confirmation, password recovery, invitation and MFA callback destinations have not been exhaustively mapped and runtime tested. | NOT TESTED |
| A3-06 | P1 | Main auth-core imports a floating Supabase JS v2 CDN URL; exact resolved dependency version is not pinned in that import. | FAIL — source hygiene |

## Required acceptance evidence

1. Privately inspect Auth URL configuration for Production and Staging: Site URL, exact redirect allowlist entries, wildcard scope, localhost entries, and environment-specific callback destinations. Do not share keys or tokens.
2. Inventory every auth flow's actual page URL and redirectTo parameter: sign-in, signup/email confirmation, recovery, invitation, MFA enrollment/challenge and logout.
3. Ensure every frontend auth flow imports one shared environment-bound client; remove any direct Production-only client creation in non-production contexts.
4. Pin Supabase JS to an exact tested version and use a controlled dependency strategy.
5. After Gate A deployment binding and Staging acceptance, run isolated Playwright Auth tests for wrong-host fail-closed, correct project identity, PKCE callback, expired/invalid links, open-redirect attempts, logout/session cleanup and MFA AAL transitions.

## Final status

- Main Auth client environment binding: **FAIL**.
- QA shared-client project identity guard: **PASS — source only**.
- Supabase Auth redirect allowlists: **NOT TESTED**.
- Deployed Auth flows: **NOT TESTED**.
- Gate A3: **BLOCKED**.
- No deployment, Auth configuration change, user creation, email dispatch, database write or secret access occurred.
