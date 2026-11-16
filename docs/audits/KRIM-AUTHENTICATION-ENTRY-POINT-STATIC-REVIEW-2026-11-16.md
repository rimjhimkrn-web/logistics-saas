# KRIM Authentication Entry-Point Static Review — 2026-11-16

## Scope
Read-only source review of:
- `app/sign-in.html`
- `app/register.html`
- `auth/login.html`
- `auth/partner-signin.html`
- `app/partner/index.html`
- `core/krim-supabase.js`

No sign-in, registration, MFA, partner activation, or production mutation was executed.

## Verified observations
1. The app sign-in page loads `core/js/sign-in.js`; registration loads `core/js/auth-flows.js`. Both use shared config, platform and localization scripts.
2. The app registration page explicitly describes account creation as identity-only, with no automatic organization or workspace permissions. It requires a terms checkbox and links to Terms and Privacy.
3. A separate `auth/login.html` exists with its own inline login/MFA UI and a separate script path. It advertises MFA when policy requires it.
4. A dedicated `auth/partner-signin.html` exists and is linked from the partner gateway. The partner gateway itself checks active organization memberships and organization account types before presenting partner access.
5. `core/krim-supabase.js` is a legacy/shared wrapper that initializes Supabase from `KRIM_CONFIG`, offers basic auth methods, and contains a realtime subscription against a `shipments` table. That realtime target differs from the canonical `krim_shipments` table used in the current production architecture; this wrapper must not be assumed to be the active production data path.
6. The app sign-in, generic auth login, and partner sign-in are distinct entry points with different HTML/JS implementations. Source presence alone does not prove their redirect, MFA enforcement, email-confirmation handling, session revocation, or role-routing behaviours are consistent.

## Risks / required verification
- **P1 — Authentication route consolidation and parity:** map every public link and redirect to its intended canonical auth flow. Verify that generic, customer, partner and driver routes enforce the same required authentication assurance and cannot bypass MFA or role-specific checks.
- **P1 — Registration and consent evidence:** inspect `auth-flows.js` and the live signup/provisioning path together. A browser checkbox is not by itself proof of immutable, versioned consent capture.
- **P1 — Legacy backend wrapper:** inventory references to `KrimBackend` and confirm no current page relies on its legacy `shipments` realtime subscription instead of canonical shipment/leg event streams.
- **P2 — Route and asset-base consistency:** test all auth and recovery pages at the GitHub Pages base path and at direct nested routes; hard-coded `/logistics-saas/` references must remain intentional and consistent.
- **P2 — Recovery/session handling:** stage-test expired sessions, invalid credentials, email confirmation, password recovery, MFA challenge/cancel, sign-out, and account switching.

## Safe next steps
1. Inspect the exact auth scripts and map route callers before modifying any page.
2. Use staging/test identities only for positive and negative authentication tests.
3. Compare observed behaviour with live auth configuration and RLS/RPC checks.
4. Do not weaken MFA, email confirmation, RLS, or membership checks to make a route appear functional.

## Status
Static source review only. No confirmed exploitable authentication bypass is established by this review. The identified issue is multiple independently implemented auth entry points requiring parity and route-flow verification.
