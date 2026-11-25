# Phase 00 — Browser security headers, storage and DOM injection audit

Date: 2026-11-25  
Repository: `rimjhimkrn-web/logistics-saas`  
Ref reviewed: `qa/phase-00-baseline-2026-11-25`  
Scope: Read-only source inspection of deployment header configuration, shared Supabase auth configuration, tracking, booking, partner onboarding and account-action pages. No browser session, user data, storage, production headers or live endpoint was accessed or modified.

## Executive verdict

**NOT VERIFIED for production security readiness.** No repository-level header configuration file was found at the common hosting paths checked, and sampled HTML pages contain no CSP meta policy. This does not prove which headers GitHub Pages currently serves: live response headers could not be fetched/verified in this pass. The sampled pages also contain inline JavaScript, inline event handlers, and DOM `innerHTML` writes. Some booking-page writes are correctly escaped or use fixed markup, but a site-wide XSS review and runtime tests remain outstanding.

## Files and evidence

- `config.js` — QA shared auth config, inspected around Supabase client creation.
- `tracking.html` — SHA `84e738f920b44fc6600bc1c2d052d96065cdd304`.
- `public/shipper/booking-request.html` — SHA `74ccaaeba9453b518526ef58956314f504f7a5e3`.
- `public/partner/partner-onboarding.html` — SHA `59c5e0c6f3d909bb1f6903bb97d3f0c167260b47`.
- `auth-core.js` — SHA `2cd5fb070ebfbaf2e712eef25dba8fc185e7f20f`.
- `auth/krim-account-actions.js` — SHA `a276dd647451e223816e691fb4cdbe107298b05d`.

Common hosting header/config paths checked and not found: `_headers`, `public/_headers`, `static.json`, `netlify.toml`, `wrangler.toml`, `firebase.json`, `vercel.json`.

## Findings

### 1. CSP and security response headers — NOT EVIDENCED

No CSP meta policy was found in the sampled pages. No repository header configuration file was found at the common paths above. The live GitHub Pages response headers were not verified, so this is **not** a claim that the deployed origin definitely lacks every header.

Headers that must be measured on real responses for HTML, JS, CSS, images, redirects and error pages:
- `Content-Security-Policy` (prefer response header; start with Report-Only and review violations).
- `X-Content-Type-Options: nosniff`.
- `Referrer-Policy`.
- `Permissions-Policy`.
- `Strict-Transport-Security` (only after confirming HTTPS-only coverage and correct host/subdomain scope).
- `frame-ancestors 'none'` in CSP and/or `X-Frame-Options: DENY` if no legitimate embedding use case exists.

GitHub Pages may limit custom response headers. If required headers cannot be configured at the origin, assess a supported CDN/proxy in front of Pages. A meta CSP can cover some resource restrictions but cannot provide `frame-ancestors` and other header-only protections. Do not add an untested strict CSP: the current pages use inline scripts, inline event handlers, CDN scripts, Google Fonts and API calls, so a naive policy could break login and onboarding.

### 2. Inline JavaScript and inline event handlers complicate strict CSP — HIGH

The sampled tracking, booking and partner onboarding pages contain inline script blocks. The partner onboarding sample also contains inline event handler attributes. A strict nonce/hash-based CSP cannot be switched on safely without first externalizing scripts/handlers or computing and maintaining hashes for exact static content.

The earlier supply-chain audit already identified CDN-hosted scripts on these pages. CSP allowlists must be based on a complete resource inventory, not a blanket wildcard or broad `unsafe-inline`.

### 3. DOM HTML sinks — NEEDS REVIEW, no confirmed exploit in this sample

- Booking page has multiple `innerHTML` assignments.
- The visible dynamic place labels are passed through an `escapeHtml` helper before insertion, and empty/loading markup is fixed constant text.
- The page builds result elements using DOM APIs and uses `textContent` for several user-visible values.
- `auth-core.js` has one `innerHTML` assignment used to build an organization switcher; its data provenance and escaping were not fully traced in this pass.
- The tracking page sample did not show an `innerHTML` assignment.

These are candidate sinks requiring data-flow review, not confirmed XSS vulnerabilities. Prefer `textContent`, DOM node creation and safe attribute assignment over HTML-string concatenation. Any intentional HTML templating must have reviewed context-specific escaping/sanitization and adversarial test cases.

### 4. Browser storage — MEDIUM/HIGH

The QA `config.js` creates the Supabase client with `persistSession: true`, `detectSessionInUrl: true` and PKCE flow. It does not specify a custom storage adapter. Supabase JS therefore uses its browser default persistent session storage in a browser environment; verify actual storage keys and logout cleanup in a controlled test browser before release.

The booking page separately stores a random UUID request id in `sessionStorage` for retry/idempotency continuity, and clears it after successful shipment creation. This is not an authentication secret, but it is still browser state. The account workflow stores a selected organization id in `sessionStorage`; the source explicitly says this selection does not grant access and backend RLS/RBAC remains authoritative.

No `localStorage`, `document.cookie` or `sessionStorage` usage was found in the sampled tracking page. The sample is not a complete site-wide storage inventory.

**Required:** ensure access/refresh tokens are never copied into URLs, DOM, logs or analytics; keep authorization server-side; clear relevant browser state on logout; consider a BFF/HttpOnly Secure SameSite cookie architecture for higher-risk authenticated workspaces. Do not treat a selected organization id from storage as authorization.

### 5. URL/referrer leakage — NOT FULLY VERIFIED

The booking page preserves `location.pathname + location.search` in a login redirect parameter and builds a coverage-review URL with origin/destination place labels, route type, mode and weight. It does not visibly place an access token in that URL in the reviewed source. The full redirect destination validation and Referrer-Policy behavior were not tested. Avoid putting sensitive shipment, identity or authentication data in query strings; validate internal redirect targets and use an appropriate referrer policy.

### 6. Clickjacking and browser capability restrictions — NOT EVIDENCED

No `frame-ancestors` or `X-Frame-Options` policy was found in sampled source/config. No live header verification was possible. Confirm whether KRIM pages are ever embedded by a legitimate partner portal before setting policy; otherwise deny framing. Restrict unused browser capabilities such as camera, microphone, geolocation and payment through Permissions-Policy. Driver GPS permissions should be narrowly scoped to the required origin and explicit user action.

### 7. HTTPS / HSTS — NOT VERIFIED

The inspected canonical/external references are HTTPS, but that does not prove all HTTP requests redirect to HTTPS or that HSTS is active. Test HTTP-to-HTTPS redirects and response headers on the public origin, subpaths and error pages. Avoid enabling broad HSTS preload/includeSubDomains until every affected subdomain is known to support HTTPS.

## Required remediation and verification

1. Obtain actual HTTP response headers for representative public, authenticated, redirect, static-asset and error routes. Capture evidence without exposing tokens or personal data.
2. Determine whether GitHub Pages can serve required headers; if not, choose a supported fronting CDN/proxy or documented compensating controls.
3. Build a complete DOM sink and untrusted-input-to-sink inventory for all project-owned HTML/JS; replace avoidable `innerHTML` with safe DOM APIs.
4. Externalize inline scripts and event handlers, remove unnecessary CDN scripts, then introduce CSP in Report-Only mode and review violations before enforcement.
5. Add `frame-ancestors`, `object-src 'none'`, `base-uri 'none'`, restrictive `default-src`, and narrowly scoped resource directives after the dependency inventory is complete.
6. Verify Supabase auth storage behavior in a controlled Staging browser, including session persistence, token visibility, logout cleanup, cross-tab behavior and no token leakage to URLs/logs.
7. Add XSS test cases for place search values, organization names, server error strings, query parameters, partner evidence metadata and all rendered notification content. Use harmless inert payloads only in an isolated test fixture.
8. Verify redirect target allowlisting and Referrer-Policy.
9. Verify HTTPS redirect/HSTS and Permissions-Policy on deployed responses.

## Release decision

- CSP enforcement: **NOT EVIDENCED in sampled source; live header unknown**.
- Clickjacking protection: **NOT VERIFIED**.
- MIME-sniffing/referrer/permissions headers: **NOT VERIFIED**.
- HTTPS/HSTS: **NOT VERIFIED**.
- DOM XSS: **candidate sinks found; no exploit confirmed; full audit pending**.
- Supabase auth persistence: **source indicates persistent session; runtime storage verification pending**.
- Booking retry and selected-org session storage: **source-observed; not authorization credentials**.
- Production browser security readiness: **NOT VERIFIED**.

No code, browser state, user records, headers, secrets or deployments were changed. NO EVIDENCE = NO PASS.

## Reference guidance

- OWASP Content Security Policy Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html
- OWASP HTTP Headers Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Headers_Cheat_Sheet.html
- OWASP Clickjacking Defense: https://cheatsheetseries.owasp.org/cheatsheets/Clickjacking_Defense_Cheat_Sheet.html
- OWASP HTML5 Security / Storage APIs: https://cheatsheetseries.owasp.org/cheatsheets/HTML5_Security_Cheat_Sheet.html
- OWASP Web Security Testing Guide — CSP: https://wstg.owasp.org/latest/06-Configuration_and_Deployment_Management/10-Content_Security_Policy/
