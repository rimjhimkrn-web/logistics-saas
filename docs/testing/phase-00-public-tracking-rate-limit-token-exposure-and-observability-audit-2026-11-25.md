# Phase 00 — Public shipment tracking abuse controls, token exposure and observability audit
Date: 2026-11-25
Branch: qa/phase-00-baseline-2026-11-25
Scope: Read-only retrieval of deployed Production `public-shipment-tracking` Edge Function source; read-only inspection of the QA-branch `tracking.html`; read-only Production database catalog for rate-limit structures/functions; read-only review of the last 24 hours of Supabase unified logs. No endpoint invocation, no token use, no database writes, no configuration changes and no secret reads.

## Executive verdict
**Public shipment tracking is not ready for unrestricted public release.** The deployed handler uses a strong opaque token and returns a minimal shipment view, but no endpoint-specific rate limit, abuse counter, challenge, or request audit event is visible in the handler. The database contains a generic API-client rate-limit subsystem, but it is not referenced by this function and is not suitable evidence of protection for anonymous public tracking.

The public tracking page also loads two third-party JavaScript resources before the tracking interaction: Tailwind CDN and the Supabase JS SDK from jsDelivr. The Supabase SDK is unused in the page's tracking code. Because third-party scripts execute in the page origin, they can technically access the entered tracking token in the DOM. This is unnecessary exposure for a bearer-reference field and should be removed or replaced with a compiled/self-hosted asset strategy and a restrictive CSP.

## 1. Deployed Production function
- Function: `public-shipment-tracking`
- Status: ACTIVE
- Version: 23
- `verify_jwt=false` (intentional public endpoint; function performs no user authentication)
- Deployed source SHA-256: `8952e857b62155fa4df8be6bcc86b086c15171ff0c5d0802e9fa054899b49158`

### Positive source controls
- Accepts POST and OPTIONS only.
- Requires server environment URL and service-role key; fails closed if missing.
- Normalizes token to uppercase and strips optional `KRIM-` prefix.
- Requires exactly 32 hexadecimal characters.
- Uses a service-role lookup by the exact `public_tracking_token`.
- Returns a generic 404 for a syntactically valid but unknown token.
- Returns a generic 503 for lookup errors and catches unexpected handler errors.
- Historical milestone query excludes GPS event rows and caps results at 10.
- GPS visibility is additionally gated by the GPS legal approval environment version, terminal shipment state, active session, matching shipment/leg assignments, active membership/org, verified driver and consent text/hash integrity.
- GPS candidates are restricted to the matching tracking session and a bounded event-time range.
- Response does not include customer name, phone, email, street address, raw assignment IDs or session IDs.
- CORS wildcard is consistent with a public endpoint; CORS is not treated as authorization.

## 2. Rate limiting and abuse controls
Source inspection found no:
- per-IP or per-token request counter;
- endpoint-specific rate-limit RPC/table call;
- token-attempt throttle or progressive delay;
- CAPTCHA/challenge or abuse score gate;
- explicit request size limit before JSON parsing;
- per-token concurrency/burst guard;
- application-level public lookup audit record.

Production database does contain `public.krim_api_rate_limit_counters` and `krim_internal.consume_api_rate_limit(...)`. The function is SECURITY DEFINER and is not executable by anon/authenticated, but it is designed around an `api_client_id` and `bucket_key`; the public tracking handler does not call it. This is not evidence that public tracking is rate-limited.

The unique token index prevents duplicates, not repeated guessing or resource exhaustion. The token's UUID-derived 32-hex format is a strong opaque reference, but high entropy does not replace abuse controls.

### Error oracle
- Malformed token returns HTTP 400.
- Well-formed unknown token returns HTTP 404.
- Existing token returns HTTP 200 with shipment details.

This distinction reveals whether a candidate has the correct format and whether it matches a shipment. High token entropy makes blind discovery difficult, but uniform public errors (e.g. same response class/body for malformed and unknown references) reduce information leakage and simplify monitoring. Do not weaken diagnostics in protected internal logs.

## 3. Tracking reference exposure
The handler returns `tracking_number: "KRIM-" + shipment.public_tracking_token` in its JSON response. The browser already has the entered token, so this echo is not necessary to render the page; it increases the number of places where the bearer reference is copied or can be captured.

The public tracking page:
- places the entered token in a JavaScript variable `activeTrackingNumber`;
- sends it in a POST JSON body to the Edge Function;
- does not put the token in a query string or URL;
- does not write the token into browser localStorage/sessionStorage in the inspected source;
- does not explicitly console-log the token;
- does not render the token in a visible DOM element after lookup;
- polls every 30 seconds while the page is visible after a successful lookup.

This is preferable to putting the token in a URL, but it remains a bearer secret in browser memory and in the request body. Ensure application/proxy diagnostics never record request bodies or tokens. Remove the unnecessary response echo unless a documented consumer requires it.

## 4. Third-party script exposure on the public tracking page
The QA-branch page loads:
- `https://cdn.tailwindcss.com` as a third-party executable script.
- `https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2` as a third-party executable script.

The page-specific tracking script uses native `fetch`; no Supabase SDK API is called in the inspected page. The Supabase SDK include appears unnecessary.

Third-party JavaScript executes in the page's origin and can inspect the input value and in-memory page state. Therefore, a compromise or unexpected change in either third-party script could access the tracking reference. Recommended remediation:
1. Remove the unused Supabase JS SDK script.
2. Replace the Tailwind CDN runtime with a locally built static CSS asset.
3. Add a Content Security Policy restricting script, connect, image, frame and object sources to the minimum required.
4. Use Subresource Integrity for any unavoidable immutable third-party script, with pinned versions; avoid floating `@2` dependencies.
5. Consider clearing the input and in-memory tracking reference when the user explicitly ends the lookup or leaves the page, while preserving a usable refresh flow.

No third-party script was executed or tested as part of this audit.

## 5. Response and browser behavior
- DOM output uses `textContent` and created elements rather than injecting API response strings with `innerHTML`, which reduces DOM-XSS risk.
- External OpenStreetMap link uses `target="_blank"` and `rel="noopener noreferrer"`.
- Coordinates are validated as finite numeric values before rendering.
- Page refreshes every 30 seconds while visible; this creates repeated anonymous API traffic. No client-side exponential backoff or 429 handling is visible.
- On quiet polling failures, the page preserves the previous display. This is useful for UX but may leave an old position visible; the displayed timestamp/freshness must remain prominent and must never be represented as live after it has aged.
- The endpoint response includes a `tracking_number` echo which is not used by the inspected page.

## 6. Observability and log review
A read-only query of the Production unified log stream for the last 24 hours found no rows matching the `public-shipment-tracking` endpoint path/name.

This means **no matching endpoint request was visible in the inspected 24-hour log window**. It does not prove that no requests occurred outside that window, that logging is complete, or that no upstream edge/WAF event exists elsewhere.

The deployed handler writes `console.error` messages for lookup failures and unexpected errors, but no successful-lookup audit event, token hash, per-IP abuse counter, rate-limit decision, or structured privacy-safe tracking request event is visible in the handler.

Recommended telemetry should record only privacy-minimized data:
- timestamp, endpoint version, coarse outcome class/status, latency;
- a keyed hash/HMAC of the tracking token (never the raw token);
- a privacy-reviewed client IP representation or trusted edge-derived abuse key;
- rate-limit decision and reason;
- request/correlation ID.
Do not log request bodies, raw tokens, shipment/customer identifiers, coordinates or full user-agent/IP indefinitely. Define retention and access controls.

## 7. Required remediation before public launch
1. Implement an endpoint-specific, atomic rate limiter using trusted gateway-derived client identity plus a keyed token fingerprint; protect both bursts and sustained abuse. Do not trust arbitrary client-supplied IP headers.
2. Apply request-body size and timeout bounds; add sensible 429 responses and Retry-After.
3. Normalize malformed and unknown token errors to reduce enumeration, while retaining safe internal reason codes.
4. Remove the tracking token from the response unless an explicit product need exists.
5. Remove the unused Supabase SDK script and eliminate runtime Tailwind CDN from this sensitive page; build local CSS and deploy a restrictive CSP.
6. Pin and integrity-protect any remaining third-party assets.
7. Add privacy-safe success/failure/rate-limit telemetry and alerts for spikes, repeated invalid references, high request volume per token/IP and anomalous geographic patterns.
8. Add a documented token rotation/revocation/expiry lifecycle and a safe compromised-link process.
9. Test rate limits, error uniformity, request-size bounds, polling/backoff, no-token-in-URL, no-token-in-logs, third-party asset isolation and token revocation in isolated Staging only.
10. Keep Production and Staging function parity and public tracking route separation as explicit deployment gates.

## Evidence boundary
The deployed function source and QA branch page source were read only. Production database catalog queries were read only. Supabase logs were queried read only for the preceding 24 hours. No public tracking endpoint was invoked, no token was submitted, no user data or secret was read, and no DB/config/code change was made in this audit.

## Verdict
- Token format and indexed lookup: **SOURCE/CATALOG PASS**.
- Shipment response minimization: **PARTIAL PASS; token echo is unnecessary**.
- Rate limiting / abuse prevention: **NOT EVIDENCED; LAUNCH BLOCKER**.
- Error enumeration resistance: **IMPROVEMENT REQUIRED**.
- Third-party script isolation: **FAIL; unnecessary executable dependencies on a bearer-token page**.
- Token in URL/local storage/console in inspected page: **NOT OBSERVED**.
- Success/failure audit telemetry: **INCOMPLETE; error logs only**.
- Last-24-hour endpoint log evidence: **NO MATCHING ROWS; NOT PROOF OF NO TRAFFIC**.
- Public tracking unrestricted launch: **NOT APPROVED**.
