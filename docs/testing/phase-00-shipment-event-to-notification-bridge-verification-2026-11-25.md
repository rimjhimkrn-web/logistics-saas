# Phase 00 — Shipment event-to-notification bridge verification

**Date:** 2026-11-25  
**Environment:** Production Supabase read-only SQL and deployed-source inspection  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Result:** Event ingestion/workflow execution exists; customer/partner notification bridge remains unimplemented or unconfigured in the inspected path.  
**Safety:** Read-only queries only. No event was inserted, replayed or processed manually. No notification queue was claimed. No external provider was contacted.

## 1. Fresh Production database snapshot

| Object | Rows |
|---|---:|
| `krim_events` | 23 |
| `krim_notification_outbox` | 0 |
| `krim_notification_deliveries` | 0 |
| `krim_communication_intents` | 0 |
| `krim_communication_routes` | 0 |
| `krim_communication_providers` | 0 |
| `krim_communication_recipients` | 0 |
| `krim_operational_notification_runs` | 0 |
| Legacy `notifications` | 5 |

The 23 domain events are all processed: 22 `shipment.status_changed` and 1 `shipment.leg_assigned`. There are no pending or failed events in this snapshot. This is evidence that the domain event processor has processed events, not evidence that notifications were delivered.

## 2. Active shipment lifecycle workflow definitions

Six active workflow triggers exist for `shipment.status_changed`:

| Workflow | Condition |
|---|---|
| Shipment Confirmed Lifecycle | `new_status = confirmed` |
| Shipment Assigned Lifecycle | `new_status = assigned` |
| Shipment Dispatched Lifecycle | `new_status = dispatched` |
| Shipment In Transit Lifecycle | `new_status = in_transit` |
| Shipment Delivered Lifecycle | `new_status = delivered` |
| Shipment Exception Lifecycle | `new_status = exception` |

The previously reviewed workflow action definitions include:
- confirmed → prepare customer notification
- assigned → prepare partner notification
- dispatched → prepare customer notification
- in_transit → evaluate delay risk
- delivered → prepare customer notification
- exception → create exception case + prepare customer notification

## 3. Critical executor behavior confirmed from live Production SQL source

The live `krim_internal_execute_workflow_action(bigint)` function handles both `prepare_customer_notification` and `prepare_partner_notification` by completing the workflow step with:

`status = prepared`  
`external_send = blocked_until_provider_and_recipient_ready`

It does not:
- create a `krim_notification_outbox` row;
- resolve a customer/partner/driver recipient;
- select a channel/provider route;
- create a delivery attempt;
- call an email, Telegram, SMS or WhatsApp provider;
- create a customer/partner delivery receipt.

Therefore, a workflow action marked `succeeded` means only that notification preparation was recorded. It must not be interpreted as notification sent or delivered.

The active database cron job `krim-workflow-runtime-minute` runs the workflow runtime batch every minute. That runtime can process domain events and complete the prepare-only notification actions. It is not a generic notification sender.

## 4. Recipient/event bridge status

| Journey event | Workflow preparation | Recipient resolution | Provider-backed delivery |
|---|---|---|---|
| Shipment confirmed | Present | Not proven | Not proven |
| Partner assignment | Present | Not proven | Not proven |
| Shipment dispatched | Present | Not proven | Not proven |
| Shipment in transit | Delay-risk evaluation only | Not applicable to current action | Not proven |
| Shipment delivered | Present | Not proven | Not proven |
| Shipment exception | Exception case + preparation | Not proven | Not proven |
| Payment paid | Legacy in-app trigger exists | Legacy user mapping only | External delivery not proven |
| Driver pickup / milestone | Not yet traced to a complete notification bridge | Not proven | Not proven |
| POD verified | Not yet traced to a complete notification bridge | Not proven | Not proven |
| Invoice / settlement | Not yet traced to a complete notification bridge | Not proven | Not proven |

## 5. Release interpretation

**Domain event ingestion:** PARTIAL PASS (22 status-change events and one leg-assigned event have processed in the current database snapshot).

**Workflow orchestration:** PARTIAL PASS (active lifecycle workflows and a scheduled runtime exist).

**Customer/partner notification preparation:** PARTIAL PASS (prepare actions execute and explicitly block external send).

**Recipient resolution and generic provider delivery:** FAIL / NOT CONFIGURED in the inspected live path (zero intents, routes, providers, recipients, outbox and delivery records).

**End-to-end mandatory journey notifications:** NO-GO. The customer/partner event-to-recipient-to-provider bridge is not complete or not configured. No evidence supports onboarding claims that these notifications are operational.

## 6. Next implementation/review sequence

1. Inventory every domain event and action type for all nine KRIM user ecosystems, not just shipment status.
2. Define authoritative recipient resolution from verified user, active organization membership, shipment party, assigned partner/driver, and role scope. Do not accept arbitrary client-supplied destinations.
3. Separate essential transactional/security/service notices from optional marketing preferences and quiet hours, while enforcing applicable channel consent and legal requirements.
4. Specify the idempotent event → intent → recipient → channel → outbox key and provider correlation.
5. Implement a generic dispatcher only after provider configuration and staging isolation are proven. Add lease fencing, stale-claim recovery, bounded retries, dead-letter, ambiguous-outcome reconciliation and verified delivery callbacks.
6. Connect authenticated customer/partner/driver notification feeds and unread/read status.
7. Add synthetic staging tests for every journey, duplicate events, missing recipients, cross-organization isolation, provider timeout, callback replay, retries and dead-letter.
8. Keep Production unchanged until migration history is reconciled and a reviewed deployment plan is approved.

**No Production schema, data, policy, grant, Edge Function, secret or cron configuration was changed.**
