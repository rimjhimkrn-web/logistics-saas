# Phase 00 — Driver GPS session, consent, token lifecycle and Staging parity audit
Date: 2026-11-25
Branch: qa/phase-00-baseline-2026-11-25
Scope: Read-only comparison of Production and Staging database catalogs/data counts; read-only retrieval of deployed Production Edge Function source for `krim-driver-tracking-session` and `krim-driver-gps-update`; correlation with public tracking function source. No Edge Function invocation, no user/device GPS collection, no writes, no secret reads and no configuration changes.

## Executive verdict
**GPS collection is intentionally and effectively disabled in Production.** Both deployed driver GPS Edge Functions are active, but the session-start and GPS-upload handlers contain two hard gates: `CONSENT_NOTICE_APPROVED = false` in source and a required environment approval flag/version. The start handler returns 503 before it can create a session; the GPS update handler returns 503 before authentication or insertion. The stop action remains available for an existing active session.

The exact consent notice is explicitly a draft and says GPS remains disabled pending approved retention, deletion and legal-hold terms. This is a positive safety control, not a defect to bypass.

**Staging does not have either of these two driver GPS Edge Functions deployed.** Its database tables and read policies exist, but the two runtime entry points are absent from the Staging Edge Function inventory. The prior 0-row snapshot is confirmed: Production has zero tracking sessions and zero GPS points; Staging has zero tracking sessions and zero tracking events.

## 1. Production deployed Edge Function inventory and source provenance
Production Edge Function inventory reports:
- `krim-driver-tracking-session`: ACTIVE, version 7, `verify_jwt=true`, source SHA-256 `fe6a122f42d85042043f37cc45a74f03301876dbc8b50719087f48dcb59036e9`.
- `krim-driver-gps-update`: ACTIVE, version 9, `verify_jwt=true`, source SHA-256 `e75ced7cbf3fc75e51fff0810146331efe95d7d75657533f2f5b0cb1eabd03bd`.
- `public-shipment-tracking`: ACTIVE, version 23, `verify_jwt=false`, source SHA-256 `8952e857b62155fa4df8be6bcc86b086c15171ff0c5d0802e9fa054899b49158`.

Staging Edge Function inventory contains only:
- `global-admin-control`
- `krim-resend-email-worker`
- `owner-testing-authorize`

Neither driver GPS function nor public shipment tracking function is present in the Staging inventory. This is a clear deployment-parity gap; it does not justify copying Production functions to Staging without a separate review and isolated test design.

## 2. Consent notice and launch gate
Both Production driver functions embed:
- Consent notice version: `2026-11-15-v1`
- Language: `en-IN`
- `CONSENT_NOTICE_APPROVED = false`
- A draft notice explicitly stating that GPS collection remains disabled until the approved notice, retention period, deletion process and legal-hold terms are published and the legal launch gate is opened.

Both functions additionally require:
- `KRIM_GPS_TRACKING_ENABLED=true`
- `KRIM_GPS_TRACKING_LEGAL_APPROVAL_VERSION=2026-11-15-v1`

The source-level boolean remains false, so the environment flags alone cannot enable collection. No secret values were read. No claim is made about the current environment variable values.

### Start/stop function behavior
- Requires POST and a Bearer access token; validates the user with Supabase Auth `getUser`.
- Accepts only `start` or `stop` and a UUID assignment ID.
- For `start`, returns 503 while either hard gate is closed, before creating a session.
- If later approved, it validates assignment ownership, shipment and driver assignment both `in_transit`, active driver membership and organization, verified driver profile with non-empty licence, active linked partner assignment and matching shipment leg, native Android/iOS platform, and exact current consent version.
- It computes SHA-256 of the exact embedded notice and stores notice text, hash, version, language and platform with the session.
- Enforces one active session per driver assignment through a partial unique database index; also handles a concurrent insert by re-reading the active session.
- `stop` is handled before the GPS launch gate and updates the driver's own active session to `stopped`, with timestamp and reason `driver_stopped`.
- The function does not check licence expiry in its profile query; it only checks verified/approved status and a non-empty licence number. The separate driver verification lifecycle must be reviewed to decide whether an expired licence can remain verified.

### GPS update function behavior
- Returns 503 immediately while either hard gate is closed; it does not authenticate or write in this disabled state.
- If later approved, requires valid authenticated user, matching assignment/session, active shipment and driver assignment in transit, verified driver profile with licence, active session bound to the exact assignment/shipment/partner/org/user, matching platform and exact consent version/text/hash/language.
- Validates latitude/longitude ranges, accuracy >0 and <=250m, device timestamp within five minutes, native collection method and Android/iOS platform, optional heading and speed bounds.
- Applies a 15-second minimum interval and a 15m stationary filter with a 60-second window.
- Writes GPS event with session ID, consent hash, accuracy, device timestamp, collection method and platform in metadata.
- Does not check licence expiry in its driver profile query.
- The updater queries the latest event by partner assignment ID rather than session ID before rate/stationary filtering. The inserted row is tagged with the session ID; review whether the pre-insert query should also be session-scoped so a new session cannot inherit an older session's throttling state.

## 3. Database session schema, permissions and constraints
Production and Staging both contain `public.krim_driver_tracking_sessions` with:
- UUID primary key and required driver assignment, partner assignment, shipment, organization, user, consent version, platform, status, consented_at and started_at.
- Optional shipment leg, stopped_at, stop_reason, consent notice text and SHA-256, plus required language defaulting to `en-IN`.
- Status check restricts values to `active` or `stopped`.
- Stop-state check requires active sessions to have no stopped_at and stopped sessions to have stopped_at.
- Consent notice pair check allows either both text/hash NULL or non-empty text plus a 64-character lowercase SHA-256. It does **not** itself require notice/hash for every active row; the Edge Function performs that check on the enabled path.
- Platform check allows `android`, `ios`, `web`; Edge Function only starts Android/iOS.
- Partial unique index `krim_driver_tracking_one_active_session_per_assignment` permits at most one active session per driver assignment.
- Additional indexes support organization, partner assignment, shipment and user lookups.

Authenticated direct table privilege is SELECT only in Production; no authenticated INSERT/UPDATE/DELETE grant was found. Staging has no authenticated table grant for this table. The policy `Drivers read own tracking consent sessions` allows authenticated SELECT only where `user_id = auth.uid()`. Session creation and stop are therefore expected to use the trusted Edge Function/service role, not direct browser table writes.

The tracking-events table has scoped authenticated SELECT policies in both environments. The reviewed table grants do not show authenticated INSERT/UPDATE/DELETE, consistent with GPS event writes being routed through the trusted Edge Function.

## 4. Automatic stale-session expiry
Production contains private SECURITY DEFINER function `private.krim_internal_expire_stale_driver_tracking_sessions()`. It:
- selects active sessions whose latest matching GPS event (same shipment, assignment and session ID in metadata) is at least 15 minutes old;
- falls back to session started_at if no matching GPS point exists;
- changes status to stopped, sets stopped_at and stop_reason `inactivity_timeout`.

Production cron catalog confirms active job:
- Name: `krim-driver-tracking-session-idle-expiry`
- Schedule: every 5 minutes (`*/5 * * * *`)
- Command: `SELECT private.krim_internal_expire_stale_driver_tracking_sessions();`

The Staging SQL endpoint did not expose the `cron.job` relation, so no Staging cron parity conclusion is made from that query.

## 5. Public tracking token generation and lifecycle
Production schema:
- `krim_shipments.public_tracking_token` is NOT NULL.
- Default: `replace(gen_random_uuid()::text, '-', '')`.
- Unique index: `krim_shipments_public_tracking_token_uidx`.
- Production snapshot: 18 shipments, 18 distinct tokens, zero NULL or malformed tokens.
- Staging snapshot: zero shipments, so token generation is not exercised there.

The default is based on a random UUID (UUID v4-style generation, normally 122 random bits after UUID version/variant bits), represented as 32 lowercase hexadecimal characters. This is a strong opaque reference if generated by the database's cryptographic UUID generator; uniqueness is enforced by the unique index.

No expiry, revoked-at, rotated-at or token-version column was found on `krim_shipments`. No token rotation/revocation function or trigger was found in the reviewed tracking-related function/trigger inventory. Thus the token behaves as a long-lived bearer reference until a separate update changes it or the shipment is removed; no formal expiry/revocation lifecycle is evidenced. Public tracking access must be treated like possession of a secret link. Do not publish tokens in analytics, logs, screenshots or support messages.

## 6. Public tracking handler and consent/session contract
The Production public tracking function checks the supplied 32-hex token, then queries the shipment by `public_tracking_token`. GPS output is further gated by:
- active session;
- matching driver assignment and partner assignment on same shipment and leg;
- active driver membership and organization;
- verified/approved driver profile with non-empty licence;
- Android/iOS platform;
- non-empty consent text and matching SHA-256.

It returns no GPS points through the generic historical event list and only returns a GPS position tied to the authorized session. It does not check licence expiry. The handler's token lookup is a public service-role operation; explicit IP/token rate limiting is not visible in the inspected source. That remains a public endpoint abuse-control review item.

## 7. Data snapshot — no real GPS journey evidence
Production:
- Shipments: 18; valid distinct public tracking tokens: 18.
- Driver tracking sessions: 0 total, 0 active, 0 stopped.
- Tracking events: 1 total, 0 GPS points, 0 tracking-session references.

Staging:
- Shipments: 0.
- Driver tracking sessions: 0.
- Tracking events: 0.

No tracking session has been created in the inspected Production snapshot, and no GPS point has been stored. No end-to-end journey, driver consent acceptance, device permission, background collection, GPS delivery, public tracking rendering or inactivity stop was runtime-tested.

## 8. Required remediation and verification gates
1. Keep the current GPS hard gate closed. Do not change `CONSENT_NOTICE_APPROVED` or environment flags in this phase.
2. Complete legal/privacy review of exact notice, purposes, visibility, retention duration, deletion, legal hold, consent withdrawal and background location behavior; version and publish the approved text.
3. Decide and enforce licence-expiry eligibility in both start and update handlers, and public tracking authorization.
4. Review session lifecycle: explicit stop, revocation, assignment cancellation, shipment terminal state, organization/membership deactivation, app uninstall and stale-session expiry.
5. Review the updater's cross-session rate-limit query and ensure throttling is correctly scoped to the current session/assignment.
6. Add or verify public tracking rate limiting, abuse telemetry, token redaction and response enumeration protections.
7. Define token expiry/rotation/revocation and a safe process for a compromised tracking link.
8. Build an isolated Staging deployment for both GPS Edge Functions and a public tracking endpoint only after the approved consent contract and test sink exist. Confirm environment-specific secrets/config without copying Production settings blindly.
9. Only after explicit approval and synthetic fixtures, test positive/negative flows: unauthenticated, wrong user, wrong assignment, inactive membership, wrong org/leg, unverified driver, expired licence, non-transit shipment, consent mismatch, start idempotency, duplicate active session, explicit stop, stale expiry, wrong session GPS update, invalid coordinates/accuracy/time, rate-limit behavior, terminal shipment, token invalid/unknown/rotated and cross-shipment isolation.

## Evidence boundary
All database queries were catalog/data-count reads. Production Edge Function source was retrieved but never invoked. No tokens were displayed or used. No secrets were read. No location permission was requested. No GPS point, session, shipment or other record was created or changed. This is a source/catalog review, not a runtime acceptance test or legal approval.

## Verdict
- Consent and GPS launch hard gate: **PASS — COLLECTION BLOCKED IN SOURCE UNTIL APPROVED**.
- Session creation/stop code: **SOURCE-OBSERVED; START CURRENTLY BLOCKED; STOP PATH PRESENT**.
- GPS upload code: **SOURCE-OBSERVED; CURRENTLY BLOCKED**.
- Idle-session expiry: **PRODUCTION CRON SOURCE/CATALOG CONFIRMED; NOT EXECUTED BY AUDIT**.
- Token entropy/uniqueness: **STRONG DEFAULT + UNIQUE INDEX; FORMAL EXPIRY/REVOCATION NOT EVIDENCED**.
- Staging parity: **FAIL — DRIVER GPS AND PUBLIC TRACKING FUNCTIONS ABSENT FROM INVENTORY**.
- Real GPS journey: **NOT VERIFIED; ZERO SESSIONS AND ZERO GPS POINTS**.
- Commercial GPS launch: **NOT APPROVED**.
