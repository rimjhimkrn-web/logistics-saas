# Phase 00 — Legacy notification producers and secondary event-path reconciliation

**Date:** 2026-11-25  
**Environment:** Production Supabase read-only catalog/source inspection and QA-branch application source review  
**Result:** The earlier event coverage inventory is refined: Production contains legacy in-app notification triggers and a separate financial-event orchestrator in addition to the newer shipment workflow/event bridge. These paths are fragmented and do not establish a unified nine-ecosystem delivery system.  
**Safety:** Read-only queries and source inspection only. No events or notifications were created, no trigger was invoked, and no provider was contacted.

## 1. Correction to the prior inventory

The prior report stated that other ecosystem event families were not evidenced in the current `krim_events` table. That statement is correct for the persisted rows in that table, but it must not be read as proof that no other event producers exist elsewhere.

This review identified:
- Legacy database triggers writing directly to `public.notifications`.
- A financial event orchestrator for selected financial event types.
- Operational exception signal bridging.
- Audit-event producers for documents and tracking.
- Legacy shipment-request quote, shipment status, partner assignment and payout notifications.

These are distinct event/notification paths and have not been demonstrated as a single canonical event-to-delivery architecture.

## 2. Legacy in-app notification trigger families

Live Production trigger catalog/source review identified these direct `public.notifications` writers:

| Source table / transition | Trigger function | Intended recipient | Delivery type |
|---|---|---|---|
| `shipment_requests.quote_status` update | `notify_customer_quote_status` | Customer user linked to shipment request | In-app row |
| `shipment_requests.status` update | `notify_customer_shipment_status` | Customer user linked to shipment request | In-app row |
| `shipment_requests.partner_id` update | `notify_partner_assignment` | Partner user linked to legacy partner record | In-app row |
| `shipment_requests.status` update | `notify_partner_shipment_status` | Partner user linked to legacy partner record | In-app row |
| `partner_payouts.status` → paid | `notify_partner_payout_paid` | Partner user linked to payout | In-app row |
| `payment_orders.status` → paid | `notify_customer_payment_paid` | Customer user bound to payment order | In-app row |
| `support_tickets` insert | `notify_admin_new_support_ticket` | First user in legacy `admin_users` table | In-app row |
| `support_tickets.status` update | `notify_customer_support_status` | Ticket owner | In-app row |

Source inspection confirms these functions insert into the legacy `notifications` table. They do not prove external email, SMS, WhatsApp, push or Telegram delivery. Some functions rely on legacy `partners`, `shipment_requests` and `admin_users` records, so their linkage to the canonical KRIM organization/shipment model needs verification before relying on them.

The driver notification page reads the legacy `notifications` table filtered by the authenticated user's `user_id`; its own copy correctly warns that external channel delivery is not inferred. The warehouse alerts staging page explicitly describes its alert queue as a workflow definition, not live records, and keeps live alert actions unavailable pending a verified warehouse alert contract.

## 3. Separate financial-event orchestrator

Production source contains `krim_internal_orchestrate_financial_event(uuid)`. It recognizes:
- `payment.paid` → customer payment posting
- `invoice.revenue_recognized` → revenue recognition
- `partner.settlement.completed` → partner settlement posting

It records a `krim_financial_posting_events` row, uses an event uniqueness constraint/idempotent lookup, validates amount/currency/organization presence, and delegates to the internal financial posting routine. Unsupported event types are marked skipped; incomplete payloads fail.

This is a ledger-posting path, not a customer/partner notification dispatcher. The current 23-row `krim_events` snapshot did not contain any of these financial event types, so no persisted evidence shows this orchestrator has processed a real financial event in the inspected snapshot.

## 4. Other operational/audit event bridges

- `krim_exceptions` has a trigger that maintains `krim_exception_signal_bridges` with a dedupe key and state mapping. This creates an operational signal, not a user notification.
- `krim_documents` inserts `document_created` audit events into `krim_audit_events`.
- `krim_tracking_events` writes tracking audit events into `krim_audit_events`.
- Shipment route, partner assignment, financial transaction, integration, organization and related tables have audit triggers. Audit records are not automatically notification records.

No equivalent complete provider-backed notification chain was established for driver assignment/pickup/POD, warehouse QC/dispatch, customs clearance, enterprise billing/access, or platform security alerts.

## 5. Architecture reconciliation

KRIM currently has at least four distinct mechanisms:

1. **Canonical domain events:** `krim_events` → workflow dispatch/runtime → workflow actions. Notification actions are prepare-only and external send is blocked until provider and recipient are ready.
2. **Legacy in-app notifications:** direct triggers insert into `public.notifications` for selected customer, partner, finance and support events.
3. **Financial posting events:** selected `krim_events` can be orchestrated into financial ledger postings.
4. **Audit and operational signals:** `krim_audit_events` and `krim_exception_signal_bridges` capture evidence/signals but do not deliver user notifications by themselves.

The legacy in-app notification table and the new generic outbox/provider model are not yet proven to be bridged or reconciled. This creates a risk of fragmented coverage, duplicate notices, stale identity bindings and inconsistent user-visible status if both are activated without a canonical routing contract.

## 6. Updated ecosystem coverage assessment

| Ecosystem | Newly identified evidence | Remaining gap |
|---|---|---|
| Customer | Legacy quote, shipment, payment, support in-app triggers | Canonical shipment linkage, recipient correctness, dedupe, live feed and external delivery |
| Partner | Legacy assignment, shipment status and payout in-app triggers | Canonical org membership/assignment mapping and external delivery |
| Driver | Driver workspace reads authenticated user's legacy inbox | Event producers for driver-specific assignment/milestone/POD; server-side feed population and delivery |
| Warehouse | Staging alert page defines queues; warehouse task/event data exists | Verified facility-scoped alert event contract and feed |
| Customs | Customs workspace and audit/domain data exist | Clearance/document/query event → authorized broker/customer recipient → notification |
| Finance | Payment-paid in-app trigger; financial event ledger orchestrator | Invoice/refund/settlement event completeness and partner/customer notification delivery |
| Operations Control Tower | Exception signal bridge and shipment workflow exception case | Escalation recipient routing and delivery acknowledgement |
| Enterprise | Enterprise workspace reads audit/operational datasets | Enterprise role-scoped billing, SLA and integration alert feed |
| Platform Admin | Support ticket in-app alert to first legacy admin user | Role/on-call routing, no single-first-admin assumption, security event and dead-letter alert delivery |

## 7. Release decision

**Legacy in-app notification producers:** SOURCE-CONFIRMED for selected legacy shipment, payment, payout and support transitions. Runtime writes and recipient linkage not tested.

**Financial event posting orchestrator:** SOURCE-CONFIRMED for three event types. No matching financial events in the inspected event-table snapshot; runtime posting not tested.

**Operational exception bridge and audit events:** SOURCE-CONFIRMED as signal/audit records, not user notifications.

**Unified nine-ecosystem notification coverage:** NOT PROVEN / NO-GO. Generic outbox configuration and delivery records remain empty in the inspected Production snapshot; provider dispatcher and verified user feed delivery remain unproven.

## 8. Required next work

1. Map each legacy notification trigger to the canonical shipment/order/organization/partner identity model and prove the recipient is active and authorized.
2. Inspect the full legacy notification function definitions for NULL recipient handling, duplicate races, message content minimization and status-transition edge cases.
3. Determine whether legacy and canonical shipment models can both write notifications for the same business action; prevent double delivery with one canonical event/idempotency contract.
4. Trace driver assignment, pickup, milestone, POD, warehouse QC/dispatch, customs clearance, invoice/refund/settlement and enterprise/admin security producers.
5. Keep the generic provider dispatcher disabled until staging isolation, delivery worker design, lease fencing, retry/dead-letter and provider receipts are addressed.
6. Implement synthetic staging tests for recipient mapping, cross-organization isolation, duplicate event, event ordering, missing recipient, provider failure and notification-feed read/mark-read authorization.

**No Production schema, data, trigger, function, grant, Edge Function, secret or cron configuration was changed.**
