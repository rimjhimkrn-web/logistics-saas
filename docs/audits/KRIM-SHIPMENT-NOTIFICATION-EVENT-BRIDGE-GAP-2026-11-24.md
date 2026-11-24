# KRIM shipment notification event-bridge gap review

**Date:** 2026-11-24  
**Environment:** Production catalog/source inspection, read-only  
**Result:** Partial legacy notification behavior exists; the new KRIM shipment event pipeline does not yet deliver customer/partner messages.  
**Changes:** No production rows, functions, triggers, policies, Edge Functions, or schedules changed.

## 1. Corrected picture: legacy notifications do exist

The legacy `shipment_requests` table has four notification trigger paths:

- Customer quote-status changes.
- Customer shipment-status changes.
- Partner assignment changes.
- Partner shipment-status changes.

The `payment_orders` table has a customer payment-paid trigger.

These functions insert rows into the legacy `public.notifications` table. The inspected partner notification functions resolve a linked partner auth user through the legacy `partners` table. The customer functions use the legacy customer user ID on the shipment/payment record.

The legacy notification table currently contains **5 rows**. This is not evidence that the new `krim_shipments` event pipeline or provider delivery is working. The legacy triggers are attached to legacy tables, not to the new shipment aggregate.

## 2. New KRIM shipment status event

The `public.krim_shipments` table has an AFTER UPDATE OF status trigger:

- Trigger: `krim_shipment_status_event`
- Function: `public.krim_internal_emit_shipment_status_event()`

On an actual status change, the function inserts a `shipment.status_changed` row into `public.krim_events` with shipment ID, shipment number, previous status, new status, customer organization ID, and actor user ID. The event starts in `pending` state.

This is a useful event foundation, but it is not itself a customer/partner notification.

## 3. Workflow definitions are present, but notification actions are prepare-only

The live workflow catalogue has six active `shipment.status_changed` triggers:

- Confirmed lifecycle → `prepare_customer_notification`
- Assigned lifecycle → `prepare_partner_notification`
- Dispatched lifecycle → `prepare_customer_notification`
- In-transit lifecycle → `evaluate_delay_risk`
- Delivered lifecycle → `prepare_customer_notification`
- Exception lifecycle → `create_exception_case` and `prepare_customer_notification`

The live SQL action executor explicitly handles both notification action types by marking the workflow step prepared and recording:

`external_send = blocked_until_provider_and_recipient_ready`

It does not create an outbox row, resolve recipient destinations, invoke the provider adapter, or confirm delivery. A successful workflow action therefore means “prepared”, not “notification delivered”.

## 4. Runtime inventory and live queue snapshot

The production Edge Function inventory includes the founder-focused notification retry worker and provider adapter. It does not include a dedicated generic customer/partner notification-outbox consumer. The database does have a workflow runtime batch function, but its notification action executor remains prepare-only; this audit did not find evidence of a scheduled invocation that turns these prepared actions into customer/partner deliveries.

At the time of the read-only count:

| Queue/table | Rows |
|---|---:|
| Pending domain events | 0 |
| Failed domain events | 0 |
| Queued workflow dispatches | 0 |
| Queued workflow actions | 0 |
| Workflow actions in retry wait | 0 |
| Dead-lettered workflow actions | 0 |
| Generic notification outbox | 0 |
| Legacy notifications | 5 |

These are point-in-time counts, not historical delivery guarantees.

## 5. Required bridge to complete

1. Preserve the legacy notification behavior until the new pipeline is proven and migration/cutover is explicitly planned.
2. Define authoritative recipient resolution for customer organization members, partner organization members, assigned drivers, and other intended recipients. Respect role, membership, shipment-party scope, and consent/mandatory-service-notice rules.
3. Turn prepared notification actions into durable, idempotent outbox records using the correct recipient and channel. Do not send to arbitrary client-supplied addresses.
4. Configure and verify a provider/channel route and credentials before sending. Provider absence must leave a visible blocked/failed state, not silently mark a notice delivered.
5. Add a dedicated, observable outbox consumer or a verified scheduled invocation with safe leases, fencing, bounded retry, dead-letter handling, and duplicate prevention.
6. Keep `sent` (provider accepted) distinct from `delivered` (provider callback confirms delivery).
7. Add authenticated customer/partner feeds and delivery status, then run E2E tests for quote, assignment, payment, shipment transitions, duplicate events, missing recipient, provider outage, webhook replay, and authorization isolation.

## 6. Release decision

**NO-GO for claiming new KRIM customer/partner notifications are operational.**

The platform has legacy notification inserts and a newer domain-event/workflow foundation. The missing piece is the verified bridge from new shipment events and prepared workflow actions to recipient-resolved, provider-backed delivery and authenticated notification feeds.

No production changes or paid services were used.