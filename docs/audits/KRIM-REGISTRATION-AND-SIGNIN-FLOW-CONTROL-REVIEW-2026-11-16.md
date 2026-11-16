# KRIM Registration and Sign-in Flow Control Review — 2026-11-16

## Scope
Static source review of the current default-branch authentication scripts and routes:
- `core/js/auth-flows.js`
- `core/js/platform.js`
- `core/js/sign-in.js`
- `auth/signup.html`
- `auth/partner-signin.html`

No credentials were used. No accounts were created. No authentication or provisioning RPC was executed.

## Findings

### P1 — Separate generic app sign-in does not visibly enforce an MFA step
`app/sign-in.html` loads `core/js/sign-in.js`. That handler calls `window.KRIM.auth.signIn()` and immediately redirects to a sanitized same-origin `/app/...` path after password authentication. The handler does not itself check MFA assurance or force an MFA challenge. This does not prove a bypass if the destination page independently gates sensitive data/actions, but it is a material parity gap against the separate `auth/login.html` and partner sign-in MFA flows. Verify backend/RPC assurance requirements and enforce a single canonical route before treating app sign-in as production-ready.

### P1 — Partner sign-in can invoke organization provisioning based on user metadata
`auth/partner-signin.html` signs in, looks for active membership, and if none exists and user metadata says `krim_account_type=partner` with a non-empty `company_name`, calls `krim_provision_partner_organization`. It then re-queries active membership and checks partner organization type/status, verification/lifecycle flags, and MFA.
The function body and production grants must be reviewed to confirm caller-bound identity, non-self-approval, pending-by-default status, duplicate protection and strict separation between organization creation and operational approval. This audit does not establish whether the RPC is exploitable or whether it grants commercial authority.

### P1 — Consent is carried as editable user metadata, not proven canonical consent evidence
The generic registration handler checks that the form checkbox is set and passes `termsAccepted: true` plus a fixed version to the client wrapper. `core/js/platform.js` writes `terms_accepted` and `terms_version` into Supabase auth user metadata. User metadata is not a canonical immutable consent ledger. The separate legacy customer signup page must be reviewed independently. Do not treat a checkbox or auth metadata as proof of durable, versioned consent.

### P1 — Legacy generic signup path is separate from the canonical identity-only registration page
`auth/signup.html` is a separate page from `app/register.html`; it collects organization/business name and personal name in addition to email/password. Its inline handler must be reconciled with the canonical customer provisioning architecture and the existing customer-registration audit before any route is advertised. Duplicate entry points increase the risk of inconsistent onboarding and consent behaviour.

### P2 — Password sign-in and password recovery redirect bases need deployment testing
The generic wrapper constructs absolute redirects from `location.origin` and fixed `/app/...` paths. The site is hosted under the GitHub Pages repository base path `/logistics-saas/`. Confirm email-confirmation and recovery callbacks preserve the repository base path and do not send users to a non-existent root route.

### P2 — Auth failure messaging differs
The generic app flow intentionally returns generic failure messaging, while partner sign-in may display backend error text. Review messages for accidental disclosure of sensitive internal details, while retaining useful reference codes for support.

## Required staging tests
1. New user, email confirmation on/off, duplicate email, expired confirmation link.
2. Generic password sign-in with no MFA factor, verified factor, AAL1 and AAL2.
3. Directly opening every protected workspace URL without a session and with insufficient assurance.
4. Partner signup with metadata spoofed, no membership, pending membership, inactive organization, unverified organization and approved organization.
5. Verify organization provisioning is strictly caller-bound, pending by default, idempotent and cannot self-approve.
6. Password reset callback on GitHub Pages base path, expired link, already-used link and post-reset session.
7. Consent versions and policy updates, with server-side durable evidence and actor/timestamp.

## Release decision
Do not consolidate routes by redirecting blindly, do not change MFA policy, and do not call provisioning functions in production as tests. Reconcile migration history first, inspect exact production function definitions/grants, then implement one canonical authentication and consent flow with staging tests.

## Evidence boundary
All findings above are source-code observations. No successful authentication, unauthorized access, MFA bypass, account provisioning or consent-write behaviour was dynamically demonstrated.
