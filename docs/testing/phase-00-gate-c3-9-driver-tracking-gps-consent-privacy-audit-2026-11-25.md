# Phase 00 — Gate C3.9: driver tracking, GPS consent, location privacy and real-time tracking security

Date: 2026-11-25
Repository: rimjhimkrn-web/logistics-saas
Immutable source baseline: `72d75a18f985ceb09e468839435ee95700e11e46`
QA branch: `qa/phase-00-baseline-2026-11-25`
Scope: source review of driver GPS upload Edge Function, tracking-session Edge Function, mobile location collector, driver tracking read page, tracking-session schema and RLS, GPS event read-policy composition, customer tracking RPC, idle-session expiry worker and prior audit material. No GPS permission was requested, no coordinates were collected, no session was created/stopped, no tracking RPC/Edge Function was invoked, no SQL was executed, and no Production/Staging data/configuration/deployment was changed.

## 1. Executive decision

**PARTIAL PASS / BLOCKED — live GPS must remain disabled.**

The source implements multiple meaningful safeguards:
- GPS launch is independently gated by a server environment flag, legal approval version and a hard-coded unapproved-consent constant.
- Mobile collection has a second hard-coded disabled flag; the driver web page is read-only and says it does not request browser location.
- Session start and GPS upload require a verified driver, active driver membership/organization, in-transit assignment, active commercial assignment and exact driver/partner shipment-leg equality.
- GPS upload requires an active session matching user, assignment, shipment, partner assignment, organization and client platform; the archived consent text/hash/language/version must match the current server-side draft.
- Coordinates, accuracy, device timestamp, speed and heading are validated; upload response uses no-store; sessions have one-active-session-per-assignment uniqueness; idle sessions have a server-side expiry routine.

The hard launch gates are currently CLOSED in source. This is correct and should not be bypassed. The consent notice itself explicitly says it is a draft and not approved for commercial use.

Open issues before any launch:
1. No approved retention schedule, deletion process, legal-hold process or data-subject handling workflow is implemented/proven. Session inactivity expiry stops collection; it does not delete GPS coordinates.
2. Session stop is not tied to an immediate server-side revocation signal from assignment cancellation, dispatch revocation, driver membership removal or driver verification/vehicle changes. GPS update checks several of these on every upload, but active session records can remain until stop/expiry.
3. GPS rate limiting is a read-then-insert check, not an atomic per-session/per-assignment quota; concurrent requests can race. It also queries the latest GPS event by assignment without scoping to the current tracking session.
4. Customer tracking RPC validates an active consent session and exact leg but only checks that archived notice text is non-empty and its hash has 64-hex syntax; it does not compare the notice version/hash to the currently approved notice. This must be corrected before any consent-version rollover or historical-session exposure.
5. CORS allows every origin (`Access-Control-Allow-Origin: *`) on both tracking Edge Functions. Authentication remains required for data operations, so this is not itself an authentication bypass, but origin allowlisting is preferable for a location-sensitive API.
6. Device-reported mock-location flag is client-supplied metadata and cannot be treated as proof of genuine GPS. No server-side attestation or spoofing detection is proven.
7. The idle-session expiry job depends on pg_cron; Staging previously lacked pg_cron. Actual scheduling/execution and alerting are NOT TESTED.
8. No end-to-end native Android/iOS permission, foreground/background, notification, battery, offline-stop, app-kill, clock-skew or revocation tests have been run.

## 2. Positive controls found

### A. Independent launch gates and draft consent

`supabase/functions/krim-driver-gps-update/index.ts` and `supabase/functions/krim-driver-tracking-session/index.ts` both define consent notice version `2026-11-15-v1`, language `en-IN`, and `CONSENT_NOTICE_APPROVED = false`. Both also require server environment `KRIM_GPS_TRACKING_ENABLED=true` and matching `KRIM_GPS_TRACKING_LEGAL_APPROVAL_VERSION`. Upload and session-start return HTTP 503 while approval is false.

`mobile/krim-driver/src/lib/locationTracking.ts` independently defines `DRIVER_GPS_CONSENT_NOTICE_APPROVED=false` and `DRIVER_GPS_LAUNCH_ENABLED=false`; `startTripTracking` throws before requesting location permissions. This is an important defense-in-depth stop.

The notice explains assignment-specific sharing, potential visibility to operations and authorized customer, ability to decline/stop, Android background notification/permission requirements, device/network limitations and no emergency-monitoring promise. It also explicitly says retention, deletion and legal-hold terms are not yet approved.

### B. Session and identity binding

`krim_driver_tracking_sessions` stores driver assignment, partner assignment, shipment, leg, organization, user, consent version, platform, status, consent time and timestamps. A partial unique index permits only one active session per driver assignment. RLS allows authenticated users to SELECT only their own sessions; direct authenticated/anon table writes are revoked, with service_role used for controlled writes.

Session start verifies the authenticated user owns the driver assignment; active driver membership and organization; verified driver profile/licence; in-transit status; accepted/active commercial partner assignment; exact shipment/organization and exact driver/partner leg equality; Android/iOS platform; and current consent version. It stores the exact server-controlled notice text, SHA-256 and locale.

GPS upload revalidates the authenticated token, assignment ownership, in-transit status, verified profile/licence, active session exact tuple, platform, exact consent text/hash/locale/version, active driver membership, active organization and commercial assignment. It also repeats the exact shipment-leg equality check. This is a positive correction relative to the C3.8 POD wrapper issue; tracking's own code does compare the legs.

### C. Coordinate validation and response handling

The upload endpoint validates UUIDs, latitude/longitude bounds, accuracy >0 and <=250 m, device timestamp within five minutes, supported native collection method, Android/iOS platform, heading and speed ranges. Event time is server time rather than client time. Responses use `Cache-Control: no-store`. GPS updates are limited to one accepted write per 15 seconds by the current source check and a stationary filter under 15 m within 60 seconds.

### D. Driver web page

`app/driver/staging/page-09-live-tracking.html` explicitly says it is read-only, does not request device location or transmit coordinates, and native GPS collection is disabled. It reads authenticated driver assignments and tracking events only. The public legacy location-sharing route redirects to this page. No browser geolocation call was found in the reviewed page.

### E. Customer tracking RPC and row-level policy

`krim_get_shipment_tracking(text)` requires an authenticated user and customer organization or active partner assignment access. It exposes latest GPS only when shipment is non-terminal and a tracking session joins to the exact driver assignment, partner assignment, shipment, leg, organization, active driver membership, active organization, verified driver profile and current in-transit status. It only returns a position no older than 15 minutes and not more than one minute in the future. GPS status distinguishes inactive, starting, active, delayed, stale and completed.

The merged `krim_tracking_events` SELECT policy is an OR-composition of authorized partner assignment, customer organization, operations users with `tracking.view`, and driver-own-assignment access. Because this policy applies to the entire tracking event table, every branch must be treated as potentially granting access to GPS rows as well as ordinary milestone rows. This needs explicit tenant/role negative testing and documented data minimization.

## 3. Findings and required remediation

### P1 — retention, deletion and legal-hold controls absent
**Status: OPEN / LAUNCH BLOCKER.** The code itself states retention/deletion/legal-hold controls are not approved. Idle-session expiry only changes session status to stopped. It does not delete or anonymize `krim_tracking_events` coordinates or define a retention period. Approve a purpose-limited retention schedule, legal-hold exceptions, deletion/anonymization job, request workflow, audit record and proof of deletion before enabling GPS.

### P1 — consent-version validation in customer tracking RPC is weaker than upload
**Status: OPEN.** `krim_get_shipment_tracking` requires non-empty consent text and 64-character lowercase SHA-256 syntax but does not compare the session's consent version, text or digest to an approved immutable notice version. The GPS upload endpoint performs the stricter comparison. Align read eligibility with an approved consent version/hash and reject legacy or unknown notice versions. Do not treat a syntactically valid digest as proof that the stored notice is approved.

### P2 — rate limiting is non-atomic and not session-scoped
**Status: OPEN.** GPS upload reads the latest event for `assignment_id`, calculates elapsed time/distance, then inserts. Concurrent requests can both pass before either insert commits. Query does not filter by `tracking_session_id`, so an older session can influence a newly started session's initial rate-limit decision. Implement an atomic server-side quota/lock or database constraint/RPC keyed to the active session, with explicit max requests/minute/day and anomaly alerts.

### P2 — stop/revocation lifecycle and offline stop
**Status: OPEN.** The mobile client stops local collection before requesting server stop and preserves identifiers for retry if offline; this is good. However, assignment cancellation, dispatch revocation, membership removal, organization suspension, licence/driver verification changes and vehicle binding revocation should close the active session immediately through trusted server-side lifecycle events. Upload rechecks some identity/assignment conditions and rejects future points, but does not itself guarantee prompt session closure for every revocation case. Add a central revocation hook and test offline recovery/queued callbacks.

### P2 — broad CORS and request abuse controls
**Status: OPEN.** Both Edge Functions return `Access-Control-Allow-Origin: *`. Authentication is still required, so CORS is not an access-control substitute, but restrict browser origins to approved KRIM app origins. No explicit request body size cap, per-user/session IP quota, burst protection or abuse alerting is visible in the reviewed handlers. Add bounded JSON body size, request quotas and monitoring.

### P2 — GPS authenticity and sensitive telemetry minimization
**Status: OPEN.** `device_reported_mocked` is supplied by the client and is not trustworthy attestation. Document that spoofed coordinates remain possible; assess platform integrity/attestation and anomaly detection without treating device flags as proof. Review whether speed, heading and precise coordinates are all necessary for the defined purpose, and minimize fields and access.

### P2 — expiry worker operational proof
**Status: NOT TESTED / BLOCKED BY ENVIRONMENT PARITY.** `private.krim_internal_expire_stale_driver_tracking_sessions()` stops sessions after 15 minutes without GPS activity and is scheduled every five minutes using `cron.schedule`. It revokes direct execute from anon/authenticated and grants service_role. Prior Staging environment audit recorded no pg_cron extension. Do not assume the schedule exists or runs in both projects. Verify extension, job existence, last run, failures, alerting and manual recovery independently per environment before GPS launch.

### P2 — policy OR-composition and customer/partner GPS visibility
**Status: NOT TESTED.** The merged RLS policy permits access through any matching branch (partner, customer, operations, driver). Verify each role sees only GPS positions for active authorized shipments/legs and that access ceases promptly after membership, assignment, shipment or consent termination. Confirm that the customer RPC's 15-minute freshness and terminal-shipment rules align with direct table access; do not let direct SELECT provide a broader or longer-lived GPS history than the RPC intends.

## 4. Staging-only negative and lifecycle test matrix

Only after isolated Staging and schema/migration parity are independently proven:
1. Anonymous, expired token, wrong user and malformed JWT.
2. Driver A requests Driver B assignment/session; wrong shipment, organization, partner assignment or leg.
3. Assignment not in_transit; cancelled/closed shipment; partner assignment revoked; organization inactive.
4. Driver membership removed, profile unverified, licence blank/expired, vehicle/dispatch binding revoked.
5. Missing consent, wrong version, wrong language, altered notice text, altered digest, legacy session and syntactically valid but incorrect hash.
6. GPS coordinates out of range, NaN/infinity, accuracy 0/>250, stale/future timestamp, invalid heading/speed, oversized JSON and unsupported platform/method.
7. Forged `device_reported_mocked`; confirm no trust is placed in the client flag.
8. Parallel requests in the same session; prove atomic 15-second quota and burst limits.
9. New session after prior session has a recent last point; ensure rate limiter is session-scoped.
10. Driver presses stop; server stop fails/offline; reconnect/retry; verify local collection stops immediately and server session closes eventually with visible pending-stop state.
11. Assignment cancelled, dispatch revoked, membership removed, organization suspended, licence/profile invalidated during an active session; confirm immediate session revocation and no subsequent accepted points.
12. Customer A, Customer B, partner A/B, driver A/B and operations users with/without `tracking.view`; test both direct table SELECT and `krim_get_shipment_tracking`.
13. Customer/partner after assignment expiry, shipment terminal state, consent stop, membership removal and session expiry.
14. Session idle expiry job: extension present, job registered, 5-minute schedule, correct stop reason, no duplicate side effects, error alerting.
15. Retention/deletion/legal hold: expiry boundary, deletion request, legal hold, release, backup lifecycle, audit and deletion proof.
16. Android foreground/background permission, notification denial, OS permission revocation, battery optimization, app force-stop/reboot, network loss and device clock drift.
17. iOS foreground/background permission changes, app suspension/termination, background location indicator and OS throttling.
18. Browser page: no geolocation permission prompt, no location API use, no coordinate upload.
19. CORS allowed/blocked origins, preflight, auth token exposure, no-store/cache/referrer behavior.
20. Sustained and burst load under a controlled synthetic Staging environment only; no Production load tests.

Every case must capture project ref, deployed commit, actor/role, session ID, assignment/shipment/leg tuple, request/result, expected vs actual, RLS/DB audit evidence, timestamps and artifacts. Do not create test users or send real coordinates until environment isolation and parity are proven.

## 5. Gate result and release decision

| Control | Result |
|---|---|
| Server and mobile GPS launch gates | PASS at source level; deliberately CLOSED |
| Draft consent notice archived with hash/language | PARTIAL PASS; not approved |
| Driver/session/assignment/leg binding | PASS at source level |
| Coordinate validation and no-store response | PASS at source level |
| Driver browser page is read-only | PASS at source level |
| Customer tracking active-session and freshness checks | PARTIAL PASS; consent-version/hash binding gap |
| Session stop and idle expiry implementation | PARTIAL PASS; lifecycle and scheduler not runtime-proven |
| Retention/deletion/legal hold | FAIL / OPEN P1 |
| Atomic rate limiting and session scoping | FAIL / OPEN P2 |
| CORS/request abuse protections | PARTIAL / OPEN P2 |
| RLS OR-composition across all roles | NOT TESTED |
| Native Android/iOS permission/background behavior | NOT TESTED |
| Staging cron execution and revocation behavior | NOT TESTED |
| End-to-end real-time GPS tracking | BLOCKED |

**Gate C3.9: PARTIAL PASS / BLOCKED. NO-GO for live GPS collection or marketing/operational claims of real-time driver tracking.** Keep both launch flags and the consent approval constant disabled until retention/deletion/legal-hold, approved notice binding, atomic rate limits, revocation lifecycle, CORS/abuse controls and isolated Staging verification are complete.

No Production/Staging GPS, coordinates, permissions, sessions, SQL/RPC, schema, policy, grant, Edge Function, account, provider or deployment was changed.
