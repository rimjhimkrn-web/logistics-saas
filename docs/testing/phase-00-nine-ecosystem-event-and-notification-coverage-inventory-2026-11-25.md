# Phase 00 — Cross-ecosystem event catalogue and notification coverage inventory

**Date:** 2026-11-25  
**Environment:** Production Supabase read-only catalog/data inspection  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Result:** Current persisted domain-event catalogue is narrow; only shipment status and shipment leg assignment events are present in the inspected event table. Six shipment lifecycle workflows are configured. Other ecosystem events and notification coverage are not yet evidenced.  
**Safety:** Read-only queries only. No rows were inserted, changed, replayed or deleted. No worker or provider was invoked.

## 1. Current event catalogue snapshot

Production `public.krim_events` contains 23 rows:

| Event type | Total | Processed | Not processed |
|---|---:|---:|---:|
| `shipment.status_changed` | 22 | 22 | 0 |
| `shipment.leg_assigned` | 1 | 1 | 0 |
| **Total** | **23** | **23** | **0** |

This is a snapshot of persisted event rows, not proof that every business event is emitted. The only public-table trigger found by catalog search whose trigger function references `krim_events` is `krim_shipment_status_event` on `krim_shipments` status updates, invoking `krim_internal_emit_shipment_status_event()`.

No evidence was found in this query set for domain events covering payment, invoice, refund, POD verification, driver milestones, warehouse inventory/QC, customs clearance, partner compliance, enterprise billing or admin security actions.

## 2. Active shipment lifecycle workflow catalogue

Six active workflow triggers are configured for `shipment.status_changed`:

| Event condition | Workflow | Configured action(s) |
|---|---|---|
| confirmed | `shipment.lifecycle.confirmed` | checkpoint; prepare_customer_notification |
| assigned | `shipment.lifecycle.assigned` | checkpoint; prepare_partner_notification |
| dispatched | `shipment.lifecycle.dispatched` | checkpoint; prepare_customer_notification |
| in_transit | `shipment.lifecycle.in_transit` | checkpoint; evaluate_delay_risk |
| delivered | `shipment.lifecycle.delivered` | checkpoint; prepare_customer_notification |
| exception | `shipment.lifecycle.exception` | checkpoint; create_exception_case; prepare_customer_notification |

The notification-preparation workflow steps are marked non-required and their configuration disables external send until a provider is ready. The live executor review previously confirmed these preparation actions do not create outbox rows or send messages.

## 3. Observed workflow action execution rows

| Action type | Succeeded rows |
|---|---:|
| `record_workflow_checkpoint` | 9 |
| `prepare_customer_notification` | 8 |
| `evaluate_delay_risk` | 1 |
| **Total** | **18** |

No `prepare_partner_notification` action execution was present in this snapshot, despite the configured partner-assignment workflow step. This is not necessarily a workflow defect without confirming whether a matching assignment event was dispatched into that trigger; it is a concrete coverage item for controlled staging testing.

## 4. Nine-ecosystem event and notification requirements matrix

The following is the minimum event coverage to design and verify. Items marked **not evidenced** are requirements/gaps, not claims that no code exists anywhere in the repository.

| Ecosystem | Required event families (minimum) | Expected recipients | Current Production evidence |
|---|---|---|---|
| Customer / Shipper | inquiry received/qualified; quote ready/expired; booking confirmed; payment status; partner assigned; pickup; dispatch; transit/ETA/delay; exception; delivery; POD available/verified; invoice/refund | authorized customer contacts for the shipment/account; billing contacts for financial events | shipment status workflow preparation exists; payment-paid legacy in-app trigger exists; generic provider delivery not configured |
| Partner / Carrier | application received; verification approved/rejected/expiring; capability/rate-card status; quote request/expiry; assignment accepted/rejected; pickup/dispatch milestones; capacity/custody handoff; POD/dispute; settlement/payout | authorized partner organization members by operational/finance role; assigned carrier | assignment preparation workflow configured; no provider-backed route/recipient/outbox evidence |
| Driver | invitation; account/credential status; assignment offered/changed/cancelled; pickup instructions; route/stop changes; milestone reminders; exception; POD accepted/rejected; safety/security alerts | authenticated driver bound to active assignment; no arbitrary client-supplied destination | no complete driver event-to-notification path evidenced |
| Warehouse | inbound appointment/ASN; gate-in; receipt; QC hold/release/reject; putaway; pick/pack; dispatch; inventory discrepancy; damage/exception | authorized warehouse staff and relevant shipment parties | no complete warehouse event-to-notification path evidenced |
| Customs | document required/missing; filing submitted; query raised; hold; inspection; duty/tax due; clearance/rejection; release | authorized customs broker/team and relevant shipment customer/partner contacts | no complete customs event-to-notification path evidenced |
| Finance | payment initiated/authorized/failed/captured; refund requested/approved/failed; invoice issued/overdue/paid; settlement calculated/held/paid; reconciliation exception | customer billing contacts, partner finance contacts, restricted KRIM finance roles | payment-paid in-app trigger and Razorpay webhook source exist; generic external delivery not configured |
| Operations Control Tower | SLA breach risk; ETA drift; route deviation; missed milestone; capacity shortfall; partner non-response; exception escalation; unresolved delivery/POD; integration outage | assigned control-tower operators, escalation owners, relevant organization contacts | shipment exception workflow creates exception case; notification is prepare-only |
| Enterprise | organization/user invitation; access/role change; contract/credit limit; shipment portfolio alerts; consolidated billing; SLA report; API/webhook failure; compliance expiry | enterprise admins, designated operations and billing contacts | no complete enterprise event-to-notification path evidenced |
| Platform Admin | privileged sign-in/MFA/session alerts; role/grant changes; partner verification decision; market activation; payment/webhook anomalies; notification queue/dead-letter; security incident; audit export | least-privilege platform admins/on-call security/finance roles | admin and operational functions exist; complete alert route and delivery not evidenced |

## 5. Mandatory notification policy requirements

The implementation must distinguish:
- **Essential transactional/service/security notices:** must not be silently disabled by marketing preferences or quiet hours where they are necessary for service, security or legal duties.
- **Optional product/marketing notices:** preference and consent controlled.
- **Channel-specific consent:** enforced at the actual send boundary where required by applicable law and channel rules.
- **Role and relationship scoping:** recipient must be derived server-side from current user identity, active membership, shipment/assignment relationship and role; never from an arbitrary client-supplied email/phone/chat ID.
- **Data minimization:** notification payloads should contain only necessary information and avoid exposing full IDs, licence numbers, financial details or document URLs.
- **Delivery truth:** queued, processing, sent/accepted, delivered (only with provider receipt), failed, retrying and dead-letter must be distinct states.

## 6. Current release decision

**Shipment status event ingestion:** PARTIAL PASS (22 of 22 persisted rows processed in snapshot).

**Shipment lifecycle workflow configuration:** PARTIAL PASS (six active status-change triggers).

**Customer notification preparation:** PARTIAL PASS (eight succeeded preparation actions; no provider delivery).

**Partner notification preparation:** CONFIGURED BUT EXECUTION NOT EVIDENCED (no corresponding action execution row in inspected snapshot).

**Other seven ecosystem event catalogues:** NOT EVIDENCED in the current `krim_events` snapshot; further repository and schema tracing required.

**End-to-end notification coverage across nine ecosystems:** NO-GO / NOT PROVEN. Generic routes/providers/recipients/outbox/delivery tables remain empty in the Production snapshot described in the preceding audit.

## 7. Next audit sequence

1. Trace all SQL functions, triggers and Edge Functions that emit business events beyond `krim_events`, including legacy event tables and direct notification inserts.
2. Inventory UI/API event producers for driver, warehouse, customs, finance, enterprise and platform admin.
3. Reconcile actual event emitters with this minimum event matrix and identify duplicates, missing events and untrusted client payloads.
4. Define canonical event names, payload schema/version, idempotency key, tenant/org binding and actor provenance.
5. Build a staging-only synthetic event and recipient fixture suite; no production event replay or external send.
6. Implement the generic recipient/outbox/dispatcher chain only after staging origin, provider credentials and sink destinations are isolated and approved.
