# Phase 7 — Tracking, Timeline & Notifications Audit

**Date:** 2026-10-23  
**Status:** SOURCE IMPLEMENTATION UPDATED — AUTOMATED / DEPLOYED ACCEPTANCE NOT YET VERIFIED  
**Canonical customer routes:**
- `public/customer-os/customer-services/shipment-timeline.html`
- `public/customer-os/customer-services/tracking-map.html`
- `public/customer-os/customer-services/shipping-preferences.html`

## Scope and changes

- Reused the existing customer shipment timeline and tracking page; no second customer tracking page was created.
- Kept the shared `public/customer-os/assets/shipment-operations.js` data path and its authorized shipment lookup.
- Timeline continues to read persisted `krim_shipment_status_history`, `krim_tracking_events` and `krim_shipment_milestones` records for the authorized shipment.
- Tracking continues to read persisted `krim_tracking_events` and only displays coordinates recorded on those events. The UI does not invent a live GPS location.
- Event timestamps now use the signed-in user's saved IANA time-zone preference from `krim_user_app_preferences.preferences.customer_localization.timezone`, falling back to the device time zone when no valid saved preference is available.
- Tracking visibility states that it is recorded-event visibility, not live GPS, and warns when the latest recorded event is older than 24 hours. This is a freshness warning only, not a delivery SLA or proof that a shipment is delayed.
- Reused the existing `shipping-preferences.html` page to save channel/event preferences under the signed-in user's `krim_user_app_preferences` record. The page clearly states that preferences do not prove actual message delivery.
- Added navigation from the tracking page, timeline and Customer Operations hub to the existing preferences page.
- Applied the shared `core/krim-global-interface.css` and `krim-global-shell` to the customer-facing pages touched in this phase.

## Trust and security boundaries

- A tracking event or location is only as fresh and reliable as the persisted source record; no GPS telemetry source was verified in this phase.
- Saved notification preferences are not proof of an event-triggered delivery system. This audit does not certify email/SMS/push provider configuration, outbox delivery, retry deduplication, or end-to-end notification delivery.
- Customer shipment access continues to rely on authenticated session, active customer organization membership, organization-scoped shipment lookup and backend RLS. Live cross-organization negative testing remains required.
- Customer-visible status, payment, carrier assignment, pickup and delivery remain separate states.

## Verification checklist

- [ ] Run production smoke checks and confirm all Phase 7 assertions pass.
- [ ] Confirm GitHub Pages deployment completed for the same source commit.
- [ ] Sign in as a customer and open a real shipment from the canonical shipment register.
- [ ] Confirm the timeline shows only persisted events, newest first, in the saved time zone.
- [ ] Confirm no-event, old-event, future-event and backend-error states are clearly distinguished.
- [ ] Confirm the tracking page labels recorded-event visibility and does not imply live GPS.
- [ ] Confirm notification preferences load/save for the signed-in user and survive reload.
- [ ] Confirm a second organization cannot access the first organization's shipment details, events or tracking.
- [ ] Confirm actual notification delivery only after provider/outbox/retry logs and event-triggered tests are available.

## Exit decision

Phase 7 is **IMPLEMENTED — UNVERIFIED** until automated results, deployment, authenticated browser acceptance, cross-organization access tests, and notification-delivery evidence are reviewed. Saved preferences alone do not close the notification-delivery acceptance gate.
