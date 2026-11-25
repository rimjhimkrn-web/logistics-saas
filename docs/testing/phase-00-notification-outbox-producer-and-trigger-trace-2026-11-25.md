# Phase 00 — Notification outbox producer and trigger trace

Date: 2026-11-25  
Branch: `qa/phase-00-baseline-2026-11-25`  
Environments: Production `ebltviniygljwwseplph`; Staging `qrpcivhdxobiaofppbkl`  
Method: read-only PostgreSQL catalog/function-definition inspection. No functions invoked; no rows or schema changed; no provider operations.

## Executive result

The producer trace confirms **two distinct notification systems** and a very small number of canonical outbox producers. Most legacy trigger-based notifications still write only to `public.notifications`, not to the communication delivery pipeline.

The inspected producer functions do not establish a unified event-to-outbox-to-delivery flow for all nine ecosystems.

**Status: incomplete producer coverage; notification readiness remains NO-GO.**

## Canonical outbox producers

### Present in both Production and Staging

1. `krim_submit_public_contact_inquiry(text,text,text,text,text)`
   - Writes a customer inquiry and associated acquisition records.
   - Enqueues a founder-facing Telegram notification in `krim_notification_outbox`.
   - This is a founder alert, not a customer acknowledgement or customer lifecycle notification.
   - Function is SECURITY INVOKER in the inspected catalog; ACL output shows only postgres/service_role explicit EXECUTE entries (default ACL behavior must be considered separately).

2. `krim_internal_queue_due_inquiry_followup_reminders(integer)`
   - Creates a private/internal `krim_events` follow-up event and a founder-only Telegram outbox row.
   - Uses a NOT EXISTS idempotency lookup on `inquiry-followup-reminder:<followup_id>`; concurrency safety depends on a matching unique constraint, not proven in this trace.
   - Explicitly records `customer_contact_sent=false`; it does not notify the customer.
   - SECURITY DEFINER; explicit ACL output is service_role-only.

### Staging-only producer

3. `krim_admin_request_partner_verification_information(bigint,text)`
   - Staging catalog indicates writes to `krim_notification_outbox`, `krim_notification_deliveries`, and legacy `notifications`.
   - This is currently a staging-only function difference in the inspected function inventory; no equivalent producer was found in Production by this exact name.
   - It is associated with partner verification information requests and appears to be the one inspected function creating an outbox + delivery pair.
   - Function is SECURITY DEFINER and authenticated-executable in the ACL output. Its complete authorization, recipient-resolution, idempotency and route logic must be reviewed before runtime tests. No invocation was made.

## Legacy trigger-based producers — both environments

Eight enabled triggers were found, with identical names and source-table mapping in Production and Staging:

| Source table | Trigger function | Destination |
|---|---|---|
| `partner_payouts` | `notify_partner_payout_paid()` | Legacy `notifications` |
| `payment_orders` | `notify_customer_payment_paid()` | Legacy `notifications` |
| `shipment_requests` | `notify_customer_quote_status()` | Legacy `notifications` |
| `shipment_requests` | `notify_customer_shipment_status()` | Legacy `notifications` |
| `shipment_requests` | `notify_partner_assignment()` | Legacy `notifications` |
| `shipment_requests` | `notify_partner_shipment_status()` | Legacy `notifications` |
| `support_tickets` | `notify_admin_new_support_ticket()` | Legacy `notifications` |
| `support_tickets` | `notify_customer_support_status()` | Legacy `notifications` |

These trigger functions do not appear in the canonical outbox writer list. They provide selected in-app notification records, not provider-backed email/SMS/WhatsApp/push delivery.

An additional SECURITY DEFINER function, `krim_report_operational_exception(bigint,text,text,text)`, writes to legacy notifications as part of its exception flow. It is not a trigger.

## Worker and delivery-path implications

- Production founder Telegram retry claim/finish functions operate on founder-only outbox rows.
- Staging additionally contains Resend claim/finish functions and the partner-verification request producer.
- The Resend claim path joins outbox and delivery rows and only targets `partner_verification_information_requested`; it is not a generic all-workspace dispatcher.
- No function in the inspected writer inventory directly inserts into `krim_communication_delivery_events`.
- The presence of a delivery-event table therefore does not prove callback ingestion or delivery-status updates are wired.
- No nine-workspace universal outbox producer/dispatcher was evidenced in this trace.

## Nine-ecosystem coverage conclusion

The producer inventory does not establish complete event/notification coverage for Customer, Partner, Driver, Warehouse, Customs, Finance, Operations Control Tower, Enterprise and Platform Admin. Existing legacy triggers cover selected customer/partner/payment/support cases only. Founder inquiry alerts and a staging-only partner-verification email path are not substitutes for mandatory user journey notifications.

## Required next verification

1. Read the full Staging-only partner-verification producer definition, including auth, AAL2/role checks, recipient membership checks, consent/mandatory classification, deduplication and transaction behavior.
2. Inspect every `krim_notification_outbox` and `krim_notification_deliveries` constraint/index separately, especially unique idempotency keys and one-delivery-per-route rules.
3. Trace the shipment workflow action runner and prove whether any action creates a canonical outbox row or only marks itself prepared.
4. Review all legacy trigger bodies for canonical shipment linkage, recipient correctness and duplicate/concurrency behavior.
5. Build a staging-only, synthetic-recipient test harness with external sends disabled before any runtime writes.
6. Do not copy the Staging-only partner-verification function to Production without a deliberate parity/security review.

## Evidence boundary

This is a source/catalog trace, not a runtime test. No producer was invoked, no synthetic user was created, no notification was queued, no email or Telegram message was sent, and no Production or Staging data/configuration was changed.
