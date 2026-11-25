# Phase 00 — Public shipment-tracking Edge Function security source review
Date: 2026-11-25
Branch: qa/phase-00-baseline-2026-11-25
Function source: `supabase/functions/public-shipment-tracking/index.ts`
Source blob SHA: `a2699a475005d7081c5cebb26909de30d333c7c9`
Related frontend: `tracking.html`
Method: source-only review of the QA branch. No Edge Function invocation, public tracking token lookup, service-role use by the audit, database query, or configuration change.

## Executive result
The Edge Function contains several meaningful safeguards: strict 128-bit hexadecimal token format (32 hex characters), lookup by a dedicated public token, bounded non-GPS event output, and multiple checks before exposing GPS coordinates. However, the handler is a public service-role endpoint and the inspected source contains no explicit rate limit, request-size bound, abuse telemetry, or per-token request throttle. It also validates that a driver licence number exists and the profile is verified/approved, but does not check licence expiry in this tracking authorization branch.

The frontend separately hardcodes the Production Supabase URL/key. The route therefore bypasses the QA branch's host-verified environment resolver. These issues require review before unrestricted public tracking launch.

## Positive source controls
1. Only POST and OPTIONS are accepted; other methods return 405.
2. Missing `SUPABASE_URL` or `SUPABASE_SERVICE_ROLE_KEY` fails closed with 503.
3. Input is trimmed, uppercased, optional `KRIM-` prefix removed, then validated against `^[A-F0-9]{32}$`. This is a 128-bit token representation; the source does not reveal how tokens are generated or whether uniqueness is enforced at the database level.
4. Lookup is by `krim_shipments.public_tracking_token`; no numeric shipment ID or user-supplied organization ID is accepted.
5. Query errors return a generic temporary-unavailability message. Unknown tokens return 404 without returning a shipment payload.
6. Shipment milestone query excludes GPS event types and is limited to 10 recent events.
7. GPS is suppressed for terminal shipments.
8. GPS session candidates must be active, tied to the same shipment, and include partner assignment, driver assignment, organization and user context.
9. Before GPS exposure, the function verifies:
   - partner assignment belongs to the shipment and same shipment leg/organization and has an allowed active status;
   - driver assignment belongs to same shipment, same user and organization, same leg, and is in_transit;
   - active driver membership and active organization;
   - driver profile verification status is verified/approved and licence number is non-empty;
   - platform is Android or iOS;
   - consent notice text is non-empty and its SHA-256 matches the stored 64-character hash.
10. GPS position query is scoped to the specific authorized tracking session, requires coordinates, and bounds event time to no more than 60 seconds in the future.
11. Response returns a minimized set of shipment fields, event types/times/locations and optional coordinates; no customer name, phone, email, address or raw assignment/session identifiers are returned.
12. CORS is wildcard, consistent with a public tracking endpoint; CORS is not an authorization control.

## Risks and gaps requiring verification
### High — No explicit rate limiting or abuse controls in the handler
No IP/token rate limit, request throttle, challenge, abuse counter, or rate-limit table/RPC is visible in this source. A 128-bit random token makes guessing infeasible if generation is cryptographically random and tokens are unique, but it does not prevent scraping of leaked tokens or resource-exhaustion requests. Verify token generation entropy/uniqueness, upstream platform limits, function logs/alerts and add an explicit safe throttle/abuse-control design if absent. Do not expose raw tokens in logs.

### High — Production endpoint hardcoded in public frontend
`tracking.html` hardcodes `https://ebltviniygljwwseplph.supabase.co` and a publishable key and calls `/functions/v1/public-shipment-tracking` directly. It does not use `config.js` or `window.KRIM_SUPABASE`. A Staging/preview host can therefore call the Production endpoint. Replace with shared host-verified configuration or a deliberately environment-routed URL, and fail closed when the host is unknown or no matching endpoint exists.

### Medium — Licence expiry is not checked in GPS authorization
The driver profile query selects `licence_number` and `verification_status`, but not `licence_expiry_date`; authorization requires only verified/approved status and a non-empty licence number. The separate driver readiness/vehicle verification workflow may enforce expiry, but this endpoint does not independently revalidate it. Decide whether expired credentials must terminate GPS authorization and enforce the authoritative rule server-side if required.

### Medium — Active consent session validity depends on status and stored text/hash
The function verifies non-empty consent text and hash integrity, but the inspected query does not check a consent version against the currently approved notice, explicit revoked-at timestamp, or maximum session duration. Active session status may already encode revocation/expiry, but that database lifecycle was not established by this source review. Verify session start/stop/revoke transitions, consent versioning and stale-session cleanup.

### Medium — Location/event freshness and last-known-location semantics
The handler returns `last_known_location_id` for shipment even if it is not a GPS position; the UI labels it “Last reported location”. Ensure that value is event-derived and its timestamp/freshness is represented. Do not present it as a live GPS coordinate. GPS coordinate freshness is separately bounded to 15 minutes in the response and labelled live only at 2 minutes or less.

### Medium — Query/availability observability
The handler logs selected lookup failures but does not visibly emit a structured audit record for successful public token lookup, invalid token attempts, rate-limit decisions or unusual enumeration patterns. Verify platform request logs and retention/alerting. Avoid logging tracking tokens or coordinates in plaintext.

## Frontend / backend contract
- Frontend expects `gps_sharing_status` values such as active, starting, stale, inactive, completed and unavailable.
- Backend may return delayed; frontend treats any non-live/non-active position as non-live, which is safe, but its message branches do not explicitly handle every backend status.
- Frontend shows “LIVE” only when backend freshness is live and GPS sharing status is active.
- Frontend polls every 30 seconds while visible. Polling does not create GPS; separate driver/native app consented collection must be active.
- Prior Driver audit found GPS collection disabled and zero tracking sessions/events in the inspected snapshot. Therefore this page is not evidence of a working live GPS journey.

## Required next checks (read-only first)
1. Inspect SQL/schema for `public_tracking_token` generation, entropy source, uniqueness and rotation/revocation lifecycle.
2. Inspect tracking-session create/stop/revoke functions and triggers for consent version, session expiry and revoked-session handling.
3. Inspect the driver profile/licence verification source to determine whether licence expiry is mandatory for an active tracking session.
4. Inspect deployed Production and Staging function configuration/source provenance and verify environment routing without invoking the public endpoint.
5. Review Supabase/edge gateway rate limits and observability. If not sufficient, design a bounded IP/token throttle before any public launch.
6. Only after protected Staging, synthetic data, isolated endpoint and explicit approval, run positive/negative tracking tests: valid token, invalid token, unknown token, expired/revoked consent, inactive membership, wrong partner assignment, wrong driver, wrong leg, terminal shipment, stale GPS, future-dated GPS and cross-shipment token isolation.

## Safety and evidence boundary
No Edge Function was invoked. No tracking token was generated or queried. No service-role key was read or used by this audit. No DB or function configuration was changed. This report is a static source review, not a penetration test or runtime acceptance result.

## Verdict
**Server-side GPS eligibility checks: SOURCE-OBSERVED, NOT RUNTIME-VERIFIED.**
**Public token security/rate limiting: INCOMPLETE EVIDENCE.**
**Environment isolation: FAIL — frontend hardcodes Production endpoint.**
**Live GPS: NOT VERIFIED; prior driver source/data audit says GPS collection is disabled and tracking data is empty.**
**Public tracking launch: NOT APPROVED until the above controls and runtime tests are completed.**
