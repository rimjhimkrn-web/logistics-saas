# KRIM Customer Shipment Visibility, Tracking Access, Shared References, Notifications and Privacy Boundary Audit
Date: 2026-11-16
Repository: rimjhimkrn-web/logistics-saas
Supabase project: ebltviniygljwwseplph
Scope: read-only production function/catalog inspection, aggregate row counts, policy presence, and static review of customer tracking and public tracking Edge Function. No business RPCs were invoked. No production data, schema, policies or functions were changed.

## Executive decision

**NO-GO for unrestricted public shipment visibility, live GPS promises or customer notification delivery claims.** KRIM has useful authenticated tracking and a secure-reference public tracking design, including tenant authorization, separation of GPS from historical events, and consent/session validation. However, public token abuse controls, notification delivery evidence, consent lifecycle, and cross-workspace privacy tests remain unverified.

## Production evidence snapshot

| Object | Rows |
|---|---:|
| krim_tracking_events | 1 |
| krim_driver_tracking_sessions | 0 |
| krim_notification_deliveries | 0 |
| krim_notification_outbox | 0 |
| krim_notification_preferences | 0 |
| krim_customer_consents | 0 |
| krim_user_consent_events | 0 |
| krim_pod_records | 0 |

The inspected tracking, driver-session, notification, consent and POD tables each have at least one SELECT policy (user-consent events and notifications have two). Policy presence alone does not establish that predicates correctly enforce tenant boundaries; full policy-body and actor-matrix review remains required.

## Positive controls observed

1. Authenticated tracking RPC rejects anonymous callers, validates shipment-reference length, and returns the same not-found/access-denied message for missing and unauthorized shipments.
2. Access is granted to a customer organization with access to the shipment, or an active member of a partner organization with an accepted/active/in-progress/assigned partner shipment assignment.
3. Generic tracking history excludes GPS events and returns only a bounded latest 100 events and 100 milestones.
4. GPS disclosure is separately gated on active driver tracking session, exact shipment/leg/partner assignment linkage, active driver membership and organization, verified driver profile/licence, native Android/iOS platform, non-empty notice and SHA-256 notice integrity. Only the latest position is returned, and only within the freshness window.
5. Public tracking Edge Function uses a 32-hex-character secure token, strips an optional KRIM- prefix, returns no-store responses, excludes GPS from ordinary events, and independently validates driver/partner assignment, membership, organization, profile and consent notice hash before returning a session-scoped GPS point.
6. The customer shipment details frontend loads shipment records only within active customer/shipper/enterprise organizations and labels tracking as recorded-event visibility rather than live GPS.
7. The legacy tracking-sharing page redirects to the secure tracking lookup and explicitly avoids claiming disconnected GPS/AIS/flight/sensor feeds.

## Findings and severity

### P1 — Public tracking token endpoint has no visible application-level abuse control
File: supabase/functions/public-shipment-tracking/index.ts. The function accepts unauthenticated POST requests, performs token lookup using the service-role client, and performs multiple database lookups for valid tokens. The source reviewed shows input-shape validation and generic errors but no per-IP/per-token rate limit, progressive delay, abuse telemetry, or challenge mechanism. A 128-bit token is difficult to guess, but token leakage and automated probing still require controls. Add edge/WAF rate limits, bounded request-body size, request throttling, abuse metrics and a revocation/rotation process. Do not weaken the token entropy or expose shipment IDs.

### P1 — Authenticated tracking RPC's can_record field is broader than a write authorization decision
Function: public.krim_get_shipment_tracking(text). The returned can_record boolean checks for an active member of a partner organization attached to an eligible assignment, but does not itself establish the precise role/permission or event-specific write authorization. Treat this field as a coarse UI hint only. Every event-write RPC must independently enforce assignment, organization, role, event type, current lifecycle state and exact leg authorization. Frontends must not interpret can_record=true as permission to record every event.

### P1 — Customer consent evidence is absent in production and consent granting is not a complete lifecycle
Production krim_customer_consents and krim_user_consent_events are empty. The grant RPC supports terms, privacy, data_processing, communications and referral, but writes/refreshes a granted state by customer profile/type/version. The audited grant path alone does not demonstrate granular purpose-specific notice capture, withdrawal, suppression propagation to marketing/notification queues, retention, or proof that a user actively selected each purpose. Do not treat terms/privacy acceptance as marketing or location-tracking consent. Require a purpose-specific consent/withdrawal matrix and independent tests before communications or GPS activation.

### P1 — Notification pipeline has no production evidence of accepted or delivered messages
Notification outbox, delivery, and preference tables are empty. No end-to-end provider delivery, retry, suppression, duplicate, bounce, invalid-recipient, consent-withdrawal or dead-letter evidence is present in the production snapshot. A provider API acceptance must not be presented as final delivery. Customer shipment status must remain available in the authenticated application even if notification delivery fails.

### P2 — Tracking result includes shipment and location metadata requiring explicit audience review
Authenticated tracking returns goods description, total weight, transport mode, route labels, estimated/actual delivery timestamps, event type/time/source, and milestone notes. Public token tracking selects a narrower shipment projection and event projection. Review every field against customer, partner, enterprise, driver and public-token audiences; ensure free-text notes cannot expose names, phone numbers, addresses, commercial pricing, sensitive cargo, or security-sensitive route details.

### P2 — Public token lifecycle is not demonstrated
Static Edge Function review confirms lookup by public_tracking_token but does not establish token entropy at creation, unique constraint, expiration, rotation, revocation, recipient-sharing controls, or safe invalidation after shipment cancellation/closure. Verify these controls from the full schema and creation/revocation functions before production public-link rollout.

### P2 — No authenticated browser/role-matrix privacy tests were executed
This audit did not execute customer, shipper, enterprise, assigned-partner, unassigned-partner, driver, revoked-member, anonymous, or expired-token scenarios. It also did not test link forwarding, token rotation, notification suppression, or consent withdrawal propagation.

## Required remediation sequence

1. Add and verify public tracking abuse controls: rate limits, body-size bounds, abuse monitoring, token rotation/revocation and appropriate expiry.
2. Treat can_record as advisory only; confirm every event-write path enforces precise event authorization server-side.
3. Review complete tracking and milestone note schemas for personal/commercial data exposure and apply audience-specific projections.
4. Define a purpose-specific consent ledger for privacy notice, operational notifications, marketing/referral communications and driver location. Implement withdrawal and suppression propagation.
5. Complete notification provider delivery/retry/dead-letter tests in staging; distinguish queued, provider-accepted, delivered, bounced, suppressed and failed.
6. Add isolated staging tests for customer/partner/enterprise access, unauthorized partner, unrelated tenant, revoked membership, anonymous access, valid/expired/revoked tracking token, GPS inactive/active/stale/terminal, and forwarded token.
7. Reconcile production migration history before any production schema/function/policy change.

## Test boundaries and limitations

- Read-only production function definitions, policy-presence metadata, aggregate counts and static source review only.
- No notification was sent; no token was generated or exercised; no customer/driver consent was granted or withdrawn; no tracking session or event was created.
- No authenticated browser test or external provider delivery was performed.
- This report does not authorize public rollout, GPS collection, marketing outreach or production changes.

## Release gate

**NO-GO** for unrestricted public tracking, live-GPS claims, marketing notification activation or customer delivery guarantees. Reassess after token-abuse controls, consent lifecycle, notification delivery evidence, migration reconciliation and nine-workspace tenant/privacy staging tests are complete.
