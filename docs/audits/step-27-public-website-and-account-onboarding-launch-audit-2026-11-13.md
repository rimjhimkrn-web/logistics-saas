# Step 27 — Public website and account-onboarding launch audit

Date: 2026-11-13
Branch: `website/global-launch-readiness`
PR: #65 (draft, unmerged, undeployed)

## Scope inspected

Reviewed the homepage, customer/partner/driver signup pages, partner onboarding entry points, shared authentication helper, site shell script, legal notice, grievance disclosure, PWA manifests and service-worker implementation.

## Fixes committed

### 1. Authentication redirect base-path handling
`core/js/platform.js` previously built email-confirmation and password-reset redirect URLs from origin-root paths (`/app/sign-in.html` and `/app/reset-password.html`). On GitHub Pages project hosting, those paths omit `/logistics-saas` and can send users to the wrong location.

Updated both redirects to use the existing `window.krimPath()` base-path helper when available, while preserving root-domain behavior on a custom domain.

### 2. Unsafe service-worker registration disabled
`core/js/site.js` attempted to register `/service-worker.js` at the domain root. The worker itself also contains origin-root cache paths such as `/index.html` and `/app/customer/index.html`. This is incompatible with the current GitHub Pages project path and could create incorrect cache scope/asset behavior if enabled on a root-hosted deployment.

Removed the unsafe registration and documented that offline caching remains disabled until the worker and every cached route are rewritten and tested against the deployment base path.

Commits:
- `d3b7641eac97630cb44891c16384fbf112bc2f36` — auth redirects respect project base path.
- `78f31528583889afc326aef72be3cc242a30abf3` — disable unsafe root-scoped worker registration.

Both files were re-fetched after editing to verify the replacements. This is source-level verification only.

## Onboarding findings

- Customer, partner and driver signup pages use relative auth callback paths, so their callback URL construction is compatible with the current project path.
- Partner registration separates registered business, individual interest and development/test pathways and explicitly states that account creation does not approve commercial service.
- Partner verification asks for business registration/operating authority evidence and service-specific documents before activation.
- Driver signup states that licence verification and shipment assignment remain separate.
- No real account, email, document upload, SMS, MFA, or production notification was submitted during this audit. End-to-end onboarding remains untested.

## Remaining public launch blockers

1. `legal-notice.html` explicitly states that verified proprietor/legal operator name, principal business address, customer-care particulars and other required operator disclosures are not yet published. These must be confirmed and published before public commercial marketplace activity.
2. `grievance.html` explicitly states that a named Grievance Officer, designation, dedicated contact details and formal appointment have not yet been verified/published. Complete this disclosure and confirm the applicable legal requirements before commercial launch.
3. PWA metadata is inconsistent: root `manifest.json` points its start URL to the older `public/index.html`; `public/manifest.json` and `public/manifest.webmanifest` use origin-root paths; the referenced `icon-192.png` and `icon-512.png` files were not found in the repository tree. PWA installability should not be represented as production-ready until manifests, icons, base path and offline behavior are reconciled and tested.
4. No production signup journey was exercised. A controlled test matrix is still required for email confirmation, expired/duplicate signup, password recovery, MFA enrollment/recovery, organization provisioning retry, partner document upload/review, and driver membership checks.

## CI status

The latest source changes were re-read and confirmed. GitHub combined commit status returned no status entries and the PR-triggered workflow-run lookup returned no runs for commit `78f31528583889afc326aef72be3cc242a30abf3` at audit time. Therefore no CI PASS is claimed for these latest edits.

## Safety

- No production/staging database changes.
- No real account creation, notification, email, document upload or provider action.
- No secret access or modification.
- No deployment or merge.
- Existing payment/partner-direct restrictions unchanged.

## Result

Step 27 completed as a source audit with two code corrections. The site remains unmerged and undeployed. Public legal identity/grievance disclosures and end-to-end onboarding verification remain launch gates. This step does not establish commercial, legal, global or operational launch eligibility.
