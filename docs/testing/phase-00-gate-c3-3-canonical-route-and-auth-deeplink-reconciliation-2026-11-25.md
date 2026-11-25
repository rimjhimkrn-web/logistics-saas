# Phase 00 — Gate C3.3: canonical route registry and authentication/email deep-link reconciliation

Date: 2026-11-25
Repository: rimjhimkrn-web/logistics-saas
Immutable source baseline: `72d75a18f985ceb09e468839435ee95700e11e46`
Scope: compare the 89 zero-inbound candidates with `config.js` canonical route registry, representative auth entry pages and existing authentication follow-up audit evidence. Static/source-only; no email was sent and no Auth settings were changed.

## 1. Canonical route registry

`config.js` declares 27 canonical routes in `window.KRIM_ROUTES`. Its route helper `window.krimRoute()` resolves names through this object and throws for unknown route keys. Only **one** of the 89 zero-inbound candidate paths is explicitly present as a canonical route:

- `app/driver/module-01-assignment-inbox.html` — `driverAssignments`.

This route is therefore registry-connected even though it has zero inbound literal HTML edges. This demonstrates why zero-inbound cannot be equated with orphaned.

The remaining 88 candidates are not explicitly represented in the 27-key canonical registry. That alone does not prove they are disconnected: authentication callbacks, reset links, email links, direct-entry pages, test fixtures and internal shells may intentionally be outside the main product route registry.

The 27-route registry is a core product entry registry, not a complete catalogue of all 1,018 HTML files.

## 2. Authentication and email deep-link paths verified in source

| Flow | Source evidence | Target | Static assessment |
|---|---|---|---|
| Customer signup confirmation | `auth/signup.html` calls `auth.signUp` with `emailRedirectTo: new URL("auth-callback.html", location.href)` | `auth/auth-callback.html` | Direct email callback path exists and is intentionally outside ordinary HTML navigation. |
| Email confirmation callback | `auth/auth-callback.html` exchanges the code, retains a validated driver invite token, then routes by account type to role-specific sign-in | Driver sign-in, partner sign-in, customer login, enterprise login | Source shows no direct workspace grant; role/membership/MFA checks are deferred to sign-in. |
| Password recovery request | `auth/forgot-password.html` calls `resetPasswordForEmail` with redirect target `auth/reset-password.html` | `auth/reset-password.html` | Direct email reset destination exists. The root `forgot-password.html` candidate is not the linked canonical recovery form in the inspected login page. |
| Email verification OTP | `auth/verify-email.html` calls `verifyOtp` with type `signup`; resend uses `auth/auth-callback.html` | `auth/verify-email.html` / callback | Alternate manual OTP route exists, but inspected customer signup uses the callback-code flow rather than this page. Whether this page is an active supported flow is unresolved. |
| Driver invitation | Callback accepts a 64-hex invite query value into sessionStorage; `auth/driver-signin.html` later calls `krim_accept_driver_invitation` and clears the token after success | `auth/auth-callback.html?invite=...` → driver sign-in | Source supports a direct invite-token path; actual invitation email template/issuer, token expiry and replay behavior are not established here. |
| Organization invitation | `auth/organization-invitation-acceptance.html` presents a token field and `auth/krim-account-actions.js` describes server-validated token requirement | `auth/organization-invitation-acceptance.html` | A UI entry exists, but an active invitation email sender/template and completed acceptance backend flow were not established in this source pass. |
| Partner redirect | `auth/partner-redirect.html` checks session and routes to partner entry; however inspected `auth/partner-signin.html` routes through the partner workspace path | `app/partner/index.html` | No inbound reference from the inspected sign-in page was found. Direct-link or legacy use remains unproven. |

## 3. Candidate classifications updated by stronger source evidence

### 3.1 Confirmed intentional direct-entry or system routes (source-backed)

- `auth/auth-callback.html` — customer signup confirmation callback; driver invite token handoff; role-specific sign-in routing.
- `auth/reset-password.html` — password reset email destination.
- `auth/verify-email.html` — manual OTP verification/resend page exists; active use in current signup flow is not proven.
- `auth/organization-invitation-acceptance.html` — explicit token-gated invitation entry UI exists; actual invitation issuance/acceptance is not proven.
- `app/driver/module-01-assignment-inbox.html` — explicitly present in canonical route registry.
- `public/404.html`, `public/offline.html` — system fallback candidates.
- `scripts/browser-environment-smoke.html` — test fixture, not a customer route.
- `templates/krim-connected-page.html` — template scaffold, not a customer route.

These should not be retired solely because they have zero inbound static HTML edges.

### 3.2 Likely legacy, duplicate or unconfirmed candidates — manual owner decision required

- `app/reset-password.html` — a second reset-password candidate; the inspected active recovery request points to `auth/reset-password.html`.
- Root `forgot-password.html` — the inspected login page links to `auth/forgot-password.html`; root variant is not established as canonical.
- `auth/partner-redirect.html` — no inbound from inspected partner sign-in; route usage unresolved.
- `auth/organization-invitation-acceptance.html` — token UI exists but the live sender/template and backend acceptance behavior are not proven.
- `home-v2.html`, `public/about.html`, root `about.html`, `public/partners.html`, root `partners.html` — canonical/duplicate content ownership requires product decision.
- `app/index.html` — previous workspace audit identifies a legacy customer workspace with weaker organization-type validation than `app/customer/index.html`; do not promote as canonical without remediation.
- `app/field/index.html`, `src/*`, `platform/krim-platform-shell.html` — shell/prototype ownership and routing not proven.
- `public/testing/chaos-resilience.html` — testing surface should not be treated as ordinary customer navigation; confirm safe access boundary.
- `auth/owner-testing-mfa.html`, `auth/owner-testing-reset-password.html` — owner-only test paths need verified owner gate and deployment policy; no claim of protection from path naming alone.

The remaining public analytics, developer, operations, growth, compliance and partner routes need route-owner decisions and route registry/navigation policy; no blanket addition to public navigation is recommended.

## 4. Authentication security caveats from prior source audit

The existing 2026-11-17 auth follow-up records that a previous callback bypassed role-checked sign-in by provisioning organizations and routing directly to workspace. That was corrected in source: callback now routes to role-specific sign-in and does not grant workspace access based on email confirmation alone. The audit also records driver MFA AAL2 enforcement and partner organization ambiguity handling improvements.

However, the same follow-up explicitly leaves live Supabase Auth Site URL, redirect allowlist, email templates, password policy, leaked-password protection, rate limits, session lifetime, refresh-token rotation and MFA assurance policy unverified. No actual confirmation/reset/invitation email, MFA challenge, invite acceptance, or session revocation was executed.

The prior nine-workspace route guard audit also found:
- Legacy `app/index.html` customer workspace accepts any active organization membership without validating customer organization type; newer `app/customer/index.html` is the stronger canonical candidate.
- Operations page-level permission consistency and Enterprise explicit permission checks require further review.
- Workspace entry pages do not replace backend RPC/RLS authorization.

## 5. Negative evidence and limits

- GitHub repository search for `emailRedirectTo`, `resetPasswordForEmail`, `inviteUserByEmail`, `window.KRIM_ROUTES` and `auth-callback.html` returned no indexed results. This is treated as inconclusive because code search indexing can be incomplete; direct file inspection is the evidence used above.
- Supabase email templates and redirect allowlist are external project settings and were not retrieved in this task.
- No provider configuration or secrets were read.
- No auth calls, test emails, token acceptance, user creation, sign-in, MFA, or session revocation were performed.
- This pass does not inspect all 89 files' complete content; the categorization remains a static triage.
- No HTTP requests, browser redirects or query/hash behavior were executed.

## 6. Gate disposition

| Check | Status |
|---|---|
| Canonical route registry read and 27 targets enumerated | PASS |
| 89 zero-inbound candidates reconciled against registry | PASS (one exact registry match; 88 require other route evidence/owner review) |
| Signup confirmation callback path source-confirmed | PASS |
| Password recovery email redirect source-confirmed | PASS |
| Driver invitation token handoff source-confirmed | PARTIAL PASS |
| Organization invitation sender/template and acceptance | NOT TESTED |
| Supabase Auth Site URL/redirect allowlist/email templates | NOT TESTED |
| All 89 candidate pages fully source-reviewed | NOT TESTED |
| Runtime email delivery and browser deep-link behavior | NOT TESTED |
| Staging auth flow tests | BLOCKED by Staging identity/deployment gate |

**Gate C3.3: PARTIAL PASS / BLOCKED.** We identified real direct-entry routes and several duplicate/unconfirmed candidates, but there is insufficient evidence to delete or retire any page. No application source or live environment was changed.
