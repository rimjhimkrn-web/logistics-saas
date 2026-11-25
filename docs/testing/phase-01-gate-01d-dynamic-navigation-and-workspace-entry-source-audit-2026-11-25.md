# Phase 01 — Gate 01D: Dynamic navigation and workspace-entry source audit

Date: 2026-11-25
Repository: rimjhimkrn-web/logistics-saas
Immutable source baseline: 72d75a18f985ceb09e468839435ee95700e11e46
QA branch: qa/phase-00-baseline-2026-11-25
Scope: targeted read-only review of high-centrality web navigation, route construction, auth redirects, workspace menus, customer navigation and service-worker registration. This is not an exhaustive symbolic execution of every JS/TS source file.

## 1. Verdict

**PARTIAL / FAIL FOR ROUTE-READINESS CERTIFICATION.** The canonical route registry exists and several shared navigation systems are source-backed, but route construction is fragmented across multiple conventions. Root-absolute paths, relative paths, hash-only workspace navigation, hard-coded repository prefixes and origin-root service-worker registration coexist. The exact deployment artifact and browser behavior are not proven. No source edits or runtime operations were performed.

## 2. Source inventory and review boundary

The immutable baseline contains 116 non-dependency JavaScript/MJS/TypeScript/TSX source files across web, mobile, tooling and Supabase function areas. Native mobile source is outside this web-only gate. This gate inspected 27 high-centrality web/config/auth source files in detail or by targeted navigation-sink scan, including config.js, auth-core.js, core/js/auth-flows.js, core/js/portal.js, core/js/sign-in.js, core/js/site.js, core/krim-customer-workflow.js, js/guards.js, shared app runtime, brand/language/social helpers and selected auth guards.

This is a targeted review, not a claim that every source file or every generated target has been enumerated. Remaining scripts and component-specific menus require a full automated AST pass and runtime route assertions.

## 3. Navigation systems observed

| System | Source behavior | Readiness implication |
|---|---|---|
| Canonical registry | config.js exposes 27 route keys / 25 unique destinations, krimPath() and krimRoute() | Useful canonical foundation, but caller adoption is not universal |
| Auth core | Redirects to sign-in and MFA challenge using constants | Runtime session/MFA behavior not tested |
| Portal workspace | Builds hash navigation from role-specific arrays; view selection is based on location.hash | Menu item does not necessarily map to a standalone HTML route; role value and backend authorization still require independent validation |
| Sign-in return path | Allows same-origin /app/ paths and rejects external origin / sign-in self-loop | Allow-list is broad at path-prefix level; backend authorization must protect destination |
| Public site auth navigation | Sets /app/customer/ and /app/sign-in.html?portal=customer directly | Root-absolute URLs can escape the GitHub Pages /logistics-saas/ prefix |
| Customer workflow bar | Builds eight links using a hard-coded /logistics-saas/ prefix, with fallback to / | Environment-specific path behavior; hard-coded base must be centralized |
| Shared brand header | Links directly to /logistics-saas/ | Root deployment may work, but subpath and custom-domain behavior need runtime verification |
| Legacy guard | Uses path-prefix role routing and /auth/login.html redirect | Client-side session/role guard is not a backend authorization boundary; legacy path family must be mapped to actual deployed routes |
| Shared app runtime | Creates anchors dynamically; some links are relative (for example ../../auth/login.html) | Resolution depends on page nesting and deployment base |
| Service worker | Registers /service-worker.js from site runtime | Origin-root path is inconsistent with project subpath; likely fails or registers outside app scope on GitHub Pages |

## 4. Confirmed source-level route risks

### P1 — GitHub Pages project-prefix escape
The following immutable-baseline sources use origin-root paths rather than the canonical base-path helper:
- core/js/auth-flows.js: delayed redirect to /app/sign-in.html.
- core/js/portal.js: sign-in URL constructed from origin plus /app/sign-in.html; fallback redirect uses /.
- core/js/site.js: authenticated customer workspace and sign-in links use /app/customer/ and /app/sign-in.html.
- core/js/sign-in.js: fallback return destinations are /app/<portal>/.
- js/guards.js: login redirect uses /auth/login.html.
- assets/krim-global-brand.js: homepage links use /logistics-saas/.
- core/krim-customer-workflow.js: hard-coded /logistics-saas/ with root fallback.
- core/js/site.js: service-worker registration uses /service-worker.js.

These are not proven failures without the exact deployed document/script context, but they are concrete path-consistency risks under a GitHub Pages repository subpath. The prior Phase 00 PWA/base-path concern remains open.

### P1 — Multiple route authorities
The canonical registry, hard-coded path strings, legacy KRIM_CONFIG.ROUTES, relative links and hash-based portal views coexist. A change to one registry cannot be assumed to update all navigation. Build an exhaustive route manifest with source file, line, construction mechanism, resolved path, expected deployment base, route owner, auth requirement and expected workspace.

### P1 — Client-side role guard must not be trusted for authorization
js/guards.js reads a browser session object and role, then redirects by path prefix. core/js/portal.js chooses menu views from a body data attribute. Neither establishes server-side access. Protected data and mutations must be denied by backend membership, tenant, role, permission, MFA/AAL and RLS/RPC checks. This aligns with Phase 00 identity/security blockers.

### P1 — Broad return-path allow-list
core/js/sign-in.js rejects external origins and non-/app/ paths, but permits any same-origin path beneath /app/ other than the sign-in page. This is not an open external redirect in the inspected code, but destination-specific workspace authorization and safe query preservation still need negative tests.

### P1 — Hash navigation is not a route inventory
Portal menus create #overview, #shipments, #create and similar anchors from a role-specific view list. These are in-page states, not standalone HTML routes. The complete route inventory must distinguish document routes, SPA/hash states, redirect aliases, preview-only pages and workflow actions.

## 5. Evidence-based observations of incomplete workflows

The customer/field portal source contains explicit non-operational states:
- Field task updates are saved to IndexedDB as local drafts only; source states they are not sent or confirmed.
- Field proof-of-delivery UI validates a selected file but explicitly has no upload endpoint configured.
- Tracking form reports live tracking is not connected.
- Shared site registration of the service worker uses an origin-root path.

These findings are source-level observations for this portal implementation only. They must not be generalized to every separate customer, driver or partner workspace page.

## 6. Required remediation and next gates

1. Generate a complete AST-based route/navigation inventory for every in-scope web JS/TS file, including template literals, URL constructors, DOM anchor creation, event handlers, form actions, router APIs, meta refresh and service-worker registration.
2. Normalize every internal path through one deployment-aware base-path utility; explicitly support GitHub Pages subpath and future custom domain.
3. Create a route-state manifest distinguishing HTML documents, redirects, hash/SPA states, forms/actions, deep links and external URLs.
4. Map each route/state to owner ecosystem, public/authenticated/privileged status, tenant, role, permission, MFA/AAL and backend enforcement evidence.
5. Verify all redirects preserve only approved query/hash context and never leak invitation/reset tokens.
6. Later, after Phase 03 proves isolated Staging and deployment safety, run browser assertions for final URL, HTTP status, assets, hash states, menu open/close, back/forward, refresh/deep links and unauthenticated/unauthorized access.

## 7. Safety and release disposition

Read-only GitHub source inspection only. No source code, deployment, workflows, Production/Staging database, Auth, synthetic accounts, payment, notifications, Storage, provider or browser operations were performed. Phase 01 remains IN PROGRESS. Phase 00 overall release remains FAIL / BLOCKED; customer booking and operational partner/driver onboarding remain NO-GO.

## 8. Key source references

- config.js
- auth-core.js
- core/js/auth-flows.js
- core/js/portal.js
- core/js/sign-in.js
- core/js/site.js
- core/krim-customer-workflow.js
- js/guards.js
- public/app/app-runtime.js
- assets/krim-global-brand.js
- service-worker.js
