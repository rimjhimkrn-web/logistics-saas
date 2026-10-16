# KRIM Canonical Route Registry

This is the canonical route map for the first functional public-to-workspace journeys. Static HTML links should be relative or use `window.krimPath()` from `config.js`; avoid root-absolute paths because GitHub Pages hosts this repository under `/logistics-saas/`.

| Capability | Canonical file | Status |
|---|---|---|
| Public homepage | `index.html` | Entry point; key links statically checked |
| Public directory/resources | `public/index.html` | Existing; review whether it should remain a secondary directory |
| Get Started / account-type choice | `public/get-started.html` | Existing; shipper and partner routes checked |
| Shipper registration | `auth/signup.html` | Connected to Supabase Auth and customer-organization RPC; browser test pending |
| Partner registration | `auth/partner-signup.html` | Connected to Supabase Auth and partner-organization RPC; browser test pending |
| Sign in | `auth/login.html` | Role-aware organization provisioning and routing; browser/MFA test pending |
| Email verification callback | `auth/auth-callback.html` | Repaired broken import; role-aware organization provisioning; redirect allowlist pending |
| Customer workspace entry | `app/customer/index.html` | Existing entry page; full backend lifecycle not yet verified |
| Partner workspace entry | `app/partner/index.html` | Existing entry page; full backend lifecycle not yet verified |
| Partner KYC/onboarding | `public/partner/partner-onboarding.html` | Connected to private Storage bucket and onboarding RPC; browser/storage/RLS test pending |
| Quote entry | `public/quote.html` | Existing; currently directs signed-out users to workspace; quote creation workflow needs completion |
| Secure checkout | `public/quote-result.html` | Loads accepted quote and invokes order creation/payment verification functions; contract and test-mode E2E verification pending |
| Customer shipment list | `public/shipper/active-shipments.html` | Existing; backend data/actions require E2E verification |
| Shipment tracking | `public/tracking.html` | Existing; public disclosure/privacy model needs review |
| Privileged control | Existing admin/control-centre files | Must remain absent from public customer navigation and enforce server-side admin checks |

## Routing rules
1. Keep one canonical route per user action. Legacy alternatives must link to the canonical route rather than implementing a second copy.
2. Preserve relative paths for static GitHub Pages routes.
3. A page guard is usability only; Supabase RLS/RPC/Edge Function authorization remains authoritative.
4. No fake user, organization, payment, shipment, quote, partner, or notification data may be presented as live operational truth.
5. Registration success means only that account creation succeeded. It does not mean partner verification, payment, shipment creation, or payout succeeded.
6. After an action, display success only when the server confirms the expected state.
7. Update this file whenever a canonical route changes; add a link-integrity test for every new critical journey.

## Current unresolved route/platform issues
- The repository contains 625 files and multiple historical page families; a complete all-site duplicate and broken-link audit remains pending.
- Some non-critical pages still contain root-absolute paths.
- The static site needs an explicit production deployment model and a separate local/preview environment.
- The Supabase Auth redirect allowlist must include the exact production and approved preview callback URLs before email verification can be considered ready.
