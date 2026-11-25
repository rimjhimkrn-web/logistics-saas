# Gate C3.18 — Customer experience, shipment visibility, tracking accuracy, communication and service reliability

**Programme:** KRIM GLOBAL PLATFORM — AI QUALITY ASSURANCE, SIMULATION & RELIABILITY PROGRAMME  
**Gate:** Phase 00 / C3.18  
**Source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**QA branch:** `qa/phase-00-baseline-2026-11-25`  
**Review date:** 2026-11-25  
**Disposition:** **PARTIAL PASS / BLOCKED — NO-GO for continuous live tracking, guaranteed ETA, universal notification delivery or live multimodal telemetry claims.**

## 1. Scope and method

Read-only source review of customer shipment detail, route plans/legs, timeline, authenticated tracking map, public token-based shipment tracking Edge Function, visibility runtime, driver tracking consent/session migrations, idle session expiry, ETA Intelligence page, customer notification/alert preference route, notification provider adapter and retry worker, plus existing POD/milestone completion controls.

Source baseline fixed at `72d75a18f985ceb09e468839435ee95700e11e46`. This is a static source audit. No customer account, shipment, location, event, GPS coordinate, consent session, notification preference, ETA request or delivery evidence was queried from a live environment or changed. No tracking token was used; no public Edge Function, RPC, provider, cron job, map tile, SMS, email, Telegram or notification was invoked. No Production or Staging data was accessed or changed.

## 2. Positive source controls

1. **Customer shipment access is scoped to active customer organizations.** Shared shipment operations code requires an authenticated session, active membership, active organization and customer/shipper/enterprise organization type; shipment details are selected by shipment ID and permitted customer organization IDs. The UI reports when the record is not available rather than revealing an outside-organization shipment.
2. **Shipment status is sourced from KRIM records.** Details show stored shipment status and recorded timestamps. The page explains that quote, partner assignment, payment and delivery evidence are separate lifecycle records.
3. **Timeline combines actual records without inventing progress.** It loads status history, tracking events and milestone rows for the authorized shipment, sorts them into an event stream, and displays timestamps in a saved or device IANA time zone. It explicitly distinguishes planned milestones from completed milestones and warns when event sources are unavailable.
4. **Tracking map is honest about source and freshness.** It requires an authenticated customer/shipper/enterprise organization and an authorized shipment. It draws markers only from recorded coordinate-backed events, validates latitude/longitude ranges, shows event time/source where available, and explicitly says a map marker is a historical report rather than guaranteed current vehicle location. It does not invent route geometry or missing GPS positions.
5. **Tracking freshness is communicated.** Shared customer shipment code warns when the last recorded event is older than 24 hours and explicitly states that event visibility is not live GPS or a delivery SLA.
6. **Public tracking uses a high-entropy token shape and minimal event disclosure.** The public Edge Function accepts a 32-character hexadecimal secure tracking reference, returns a generic 404 for unknown tokens, disables caching, limits non-GPS events to the latest 10, and does not return customer organization IDs, cargo description or event coordinates in the public event list.
7. **Public GPS disclosure is guarded by current operational context.** The Edge Function excludes terminal shipments; checks active tracking sessions, partner assignment and driver assignment on the same shipment and leg, active driver membership and organization, verified driver profile/licence, native Android/iOS platform and consent text/hash integrity; GPS is session-scoped and only returned when the position is within 15 minutes, with a 2-minute live/recent distinction.
8. **Tracking sessions have explicit idle expiry logic.** The migration defines a private function to stop active sessions after 15 minutes without a session-specific GPS event and schedules it every five minutes. This is intended source behavior; actual cron installation/execution is not proven.
9. **ETA Intelligence avoids fabricated results.** The page states no live prediction is available until backend connection, data source and authorization are verified. It says requests are not sent unless a supported service is configured.
10. **Notification provider adapter is admin-gated and conservative.** It requires a valid authenticated session and `admin.platform`; Resend reports sending disabled even if credentials are available. Telegram path is explicitly a founder-authorized test, not customer/partner delivery.
11. **Notification retry worker is narrowly scoped.** It requires a sufficiently long cron secret or platform-admin authorization and processes founder Telegram enquiry/follow-up queues only. It does not establish a generic customer shipment notification service.
12. **POD/delivery lifecycle has independent review foundations.** Earlier audited migrations separate driver POD submission, platform review and delivery authorization; customer POD reads are restricted to verified evidence. This does not by itself prove customer notification or continuous visibility.

## 3. Findings and release risks

### P1 — Public tracking endpoint is a bearer-token API without demonstrated rate limiting or token lifecycle controls
The public Edge Function uses a service-role client after validating the 32-hex tracking token. The reviewed handler does not show per-IP/per-token throttling, abuse monitoring, request-body size limits, token expiry, token revocation/rotation, access logs suitable for customer privacy review or a customer-controlled disable/regenerate workflow. CORS is wildcard, which is not an authorization boundary. Possession of the token is sufficient to retrieve shipment reference, status, route endpoints, last-known location label, ETA/delivery timestamps and recent event labels.

**Impact:** A leaked or brute-forced token may expose shipment metadata. Keep tracking references confidential and implement rate limits, revocation, expiry/rotation and privacy-minimized public fields before broad public rollout.

### P1 — Driver GPS collection must remain disabled pending previously identified consent and privacy gaps
The public tracking function validates that consent text is non-empty and that its hash matches the text, but it does not prove that the notice version/hash is currently approved by legal/privacy governance. Prior C3.9 found no approved retention/deletion/legal-hold controls, and the server/mobile GPS launch gates were hard-disabled. Native background/location permission behavior was not runtime tested.

**Impact:** A mathematically valid hash does not prove valid informed consent or legal approval. Keep server and mobile GPS collection flags disabled. Do not claim active real-time GPS tracking. If GPS is enabled in future, require approved notice version/hash, purpose, language, retention/deletion, revocation stop, platform permission and runtime verification.

### P1 — Public GPS session authorization does not explicitly bind the driver assignment's partner assignment and vehicle tuple
The public Edge Function checks partner assignment and driver assignment independently against the same shipment and leg, and validates driver membership/profile. The inspected handler does not explicitly compare the driver's assignment's partner_assignment_id to the session's partner_assignment_id, nor validate the exact vehicle binding/current vehicle eligibility in the public read authorization path. Earlier C3.7–C3.8 also found assignment/POD tuple-binding gaps.

**Impact:** Public GPS release must be tied to one canonical assignment tuple: shipment + leg + partner assignment + driver assignment + driver + organization + current eligible vehicle + active consent session. Resolve and test exact tuple linkage before any live GPS use.

### P1 — Public tracking and authenticated tracking have different disclosure and data-quality semantics
The public Edge Function returns shipment metadata and public event labels through a token. The authenticated map uses organization authorization and can display coordinate-backed tracking history. The public route has no visible disclosure policy/version or explicit customer-selected sharing scope in the reviewed handler. The two routes need a common field-level privacy contract, clear customer consent/choice and consistent terminal-state behavior.

### P1 — Customer notification experience is not a complete shipment lifecycle delivery service
Customer pages link to notification and shipping preferences, but the reviewed customer alert-preferences legacy page redirects to secure tracking rather than presenting a functioning preference manager. The provider adapter explicitly keeps Resend sending disabled; Telegram is founder-only. The retry worker only handles founder Telegram queues. No generic customer shipment outbox, channel selection, provider receipt, retry/dead-letter, delivery status, mandatory service-notice policy, acknowledgement and fallback escalation across booking, quote, payment, assignment, pickup, milestone, delay, exception, POD, delivery and cancellation was established.

**Impact:** A status record or in-app timeline does not prove the customer was notified. Essential service notifications must remain mandatory where legally required and cannot silently be made optional; marketing preferences must be separate from transactional notices.

### P1 — ETA and delay prediction are not operationally connected
ETA Intelligence explicitly says automation is unconfirmed and no live result is available until a supported service is verified. No calibrated route/mode/partner historical model, source provenance, confidence interval, prediction timestamp, model version, drift monitoring or customer-facing delay alert was established. Stored `estimated_delivery_at` values alone do not prove a prediction is current or reliable.

**Impact:** Do not advertise AI ETA accuracy, proactive delay detection or guaranteed delivery windows. Show the source, last calculation time and uncertainty for any future ETA.

### P2 — Current-location field and event stream can diverge
Authenticated details use `krim_shipments.last_known_location_id`, while the timeline/map use event rows. The reviewed client code does not prove that every event append and last-known-location update occur atomically or that stale/replayed/out-of-order events cannot move the current-location pointer backwards. Public tracking returns the shipment last-known-location label independently from the session-scoped GPS row.

**Impact:** The customer may see a last-known label that is older than the newest event or not equivalent to current GPS. Define canonical projection rules and timestamp/source provenance for every location field.

### P2 — Milestone completeness and freshness are not enforced at the customer presentation layer
Timeline accurately displays stored milestones and missing records, but the reviewed page does not calculate which milestones are expected for the active route plan, identify overdue/unreported milestone gaps, or distinguish a partner's late report from a verified physical event in a standardized trust label. This is an observability gap, not evidence that every mode has live telemetry.

### P2 — Multimodal visibility is not connected to real external feeds
The inspected `public/visibility/visibility-runtime.js` contains a hard-coded sample shipment reference and mock “connected” telemetry event. ETA Intelligence explicitly says automation is unconfirmed. Legacy alert preferences redirect to secure tracking; legacy road/rail/air/ocean visibility pages should not be represented as connected AIS, IoT, flight, rail, temperature or geofence feeds unless the relevant source and contract are verified.

**Impact:** Keep demo runtime isolated and visibly labelled; do not claim live AIS, flight, rail, container, temperature, geofence or telematics coverage without connected and validated provider evidence.

### P2 — Tracking session expiry and stop behavior are not runtime verified
A five-minute cron schedule is defined for a 15-minute idle timeout. The review did not verify that pg_cron is installed, the job is active, stale sessions are stopped, revocation is immediate, or job failures alert an owner. A scheduled migration statement is not proof of a running job.

### P2 — Customer preferences, localization and consent boundaries need completion
Timezone preference is read from the authenticated user's app preferences with a device-timezone fallback. The legacy customer alert-preferences route does not expose a real preference center. Notification language, channel consent, contact verification, mandatory transactional vs optional marketing categories, quiet hours, accessibility and preference audit were not established end-to-end.

### P2 — No end-to-end customer experience reliability evidence
No runtime evidence exists for page load and authorization across nine workspaces, delayed/out-of-order event ingestion, duplicate events, network outage, provider outage, tracking-token leak, timezone/DST boundaries, stale location handling, notification receipt, customer support fallback, or delivery/POD visibility after independent verification.

## 4. Required remediation before release

1. Protect public tracking tokens as credentials: rate-limit by token and network, add abuse detection, request size limits, token expiry/revocation/rotation, access audit, and a customer-controlled share/disable flow. Minimize fields returned to public viewers and avoid revealing exact locations unless explicitly authorized.
2. Define a versioned public-tracking privacy contract and customer-controlled sharing scope. Distinguish public bearer-token access from authenticated organization access; provide revocation and audit.
3. Keep GPS disabled until approved consent notice/version/hash, legal purpose, language, retention/deletion/legal hold, revocation stop, native permission behavior and incident response are approved and Staging-tested.
4. Enforce canonical GPS assignment tuple at every write and read boundary: shipment, leg, partner assignment, driver assignment, partner organization, driver user, vehicle binding/eligibility, consent session and source event. Add uniqueness and replay protections.
5. Verify idle expiry and session revocation in isolated Staging, including cron installed/active, 15-minute stop, job failure, restart, revoked membership, expired licence, terminal shipment and assignment cancellation.
6. Implement a generic customer notification outbox for all nine workspaces with event taxonomy, transactional vs marketing classification, verified recipients/channels, language, provider receipts, retries, dead-letter, acknowledgement distinct from read state and escalation/fallback. Keep essential service notices mandatory where required; make only optional marketing categories opt-out.
7. Complete customer preference center for verified email/phone/push endpoints, language, IANA timezone, optional channels and marketing consent; preserve mandatory transactional service delivery and preference audit.
8. Build ETA service with verified carrier/mode/source data, route-specific calibration, confidence interval, model/version, freshness timestamp, drift monitoring and explicit unavailable state. Never fabricate a prediction.
9. Establish canonical event ingestion ordering/idempotency, source authority, event-time vs received-time, immutable audit and atomic current-location projection. Prevent stale/replayed events from regressing last-known location.
10. Add expected milestone matrix by mode/route/leg and overdue reporting with evidence/source labels. A missing milestone must be shown as unknown/unreported, not assumed complete.
11. Remove or visibly isolate mock telemetry runtime and sample shipment references; no demo feed may appear as connected production telemetry.
12. Run isolated Staging synthetic tests: public token invalid/expired/revoked/rate-limited; cross-tenant authenticated shipment ID; exact GPS assignment tuple mismatch; driver licence/membership/vehicle revoked; stale/future GPS; terminal shipment; event replay/out-of-order; timezone/DST; missing milestone; ETA provider outage; notification provider failure/retry/dead-letter; mandatory vs marketing preferences; and verified-only ePOD access. Do not run load tests against Production.

## 5. Verification matrix

| Check | Result | Evidence / limitation |
|---|---|---|
| Customer shipment detail active membership/org scope | SOURCE PASS | Authenticated customer/shipper/enterprise membership and shipment organization filter. |
| Timeline uses stored status/tracking/milestone records | SOURCE PASS | Queries history, tracking events and milestones; no fabricated events. |
| Planned vs actual milestone distinction | SOURCE PASS | Explicit customer-facing accuracy disclaimer. |
| Authenticated tracking map organization scope | SOURCE PASS / PARTIAL | Active customer org and shipment filter; RLS/cross-tenant runtime tests not run. |
| Map markers only from valid recorded coordinates | SOURCE PASS | Coordinate bounds and no-marker empty state. |
| Stale event/freshness warning | SOURCE PASS | 24-hour warning; explicitly not a live GPS/SLA claim. |
| Public tracking token validation/cache control | SOURCE PASS / PARTIAL | 32-hex token, generic unknown response, no-store; rate limiting/revocation not established. |
| Public GPS active-session checks | SOURCE PASS / PARTIAL | Partner/driver/organization/membership/profile/native platform/consent hash and session-scoped event checks. |
| Exact driver-to-partner assignment and vehicle tuple | BLOCKED | Exact tuple linkage/current vehicle eligibility not fully asserted in public read handler. |
| Driver GPS consent legally approved | BLOCKED | Text/hash verified; approved notice version/retention/revocation not proven; GPS flags remain disabled. |
| Idle GPS session expiry | SOURCE PASS for code / NOT TESTED runtime | Five-minute cron definition; actual job execution not verified. |
| ETA prediction integration/accuracy | FAIL / BLOCKED | Page explicitly says automation unconfirmed and no live result. |
| Generic mandatory customer shipment notifications | BLOCKED | Resend sending disabled; Telegram founder-only; no nine-workspace customer delivery pipeline established. |
| Customer alert preference center | FAIL / BLOCKED | Legacy route redirects; full channel/consent manager not established. |
| Multimodal AIS/IoT/rail/air/temperature feed | FAIL / NOT ESTABLISHED | Visibility runtime includes mock telemetry; no verified live feed. |
| Current-location projection/event ordering | NOT TESTED | Atomicity, idempotency, replay and stale-event ordering not verified. |
| Customer support/fallback and end-to-end reliability | NOT TESTED | Requires isolated Staging synthetic scenarios. |

## 6. Change and safety record

- No Production or Staging SQL, RPC, Edge Function, cron job, table, row, account, secret, provider, deployment, GPS session, notification preference, shipment or tracking event was changed or invoked.
- No tracking token was used and no customer/partner/driver was contacted.
- No location was collected, disclosed or transmitted.
- No notification or ETA request was sent.
- Documentation-only QA branch change.

**Gate C3.18 result: PARTIAL PASS / BLOCKED.** KRIM has a careful source-level customer shipment timeline and tracking presentation that avoids fabricated progress and clearly labels historical location data. Public tracking has meaningful token and GPS-session checks, but token lifecycle/abuse protection, exact GPS assignment tuple, approved consent, customer notifications, ETA prediction, customer preference management and live multimodal feeds remain unproven. Keep GPS collection, public real-time tracking claims, AI ETA claims and universal notification delivery claims disabled until remediated and independently tested in isolated Staging.
