# Phase 00 — Legacy notification trigger-function audit

Date: 2026-11-25  
Branch: `qa/phase-00-baseline-2026-11-25`  
Scope: read-only function/trigger source and catalog review in Production and Staging. No trigger fired intentionally; no records changed; no external provider called.

## Executive result

Eight enabled legacy triggers exist in both Production and Staging, with identical trigger definitions and identical function-definition MD5 fingerprints. They write only to `public.notifications` (in-app legacy inbox). They do not create canonical notification outbox/delivery records or provider deliveries.

**Result: partial in-app notification coverage; no complete or concurrency-safe notification pipeline.**

## Trigger inventory and findings

| Trigger / source | Recipient and trigger condition | Main findings |
|---|---|---|
| `payment_orders` → `notify_customer_payment_paid` | `customer_id`; transition into `paid` | Resolves shipment as `COALESCE(krim_shipment_id, shipment_id)` for message text, but inserts only legacy `shipment_id` into notification. For KRIM-native payment with old ID null, canonical shipment linkage is lost. Duplicate check is based on user/type/title and a broad shipment-null predicate, not a unique payment/event ID; concurrent updates can race. |
| `shipment_requests.quote_status` → `notify_customer_quote_status` | `customer_id`; quote status change | Inserts by legacy `shipment_requests.id`; duplicate check uses user, shipment, type and title. No unique event key; concurrent race possible. |
| `shipment_requests.status` → `notify_customer_shipment_status` | `customer_id`; shipment status change | Inserts by legacy shipment request ID. Duplicate check uses user, shipment, type and title; concurrent race possible. Does not establish canonical `krim_shipment_id` linkage. |
| `shipment_requests.partner_id` → `notify_partner_assignment` | `partners.user_id` for newly assigned legacy partner ID | Depends on legacy partner row having linked Auth user; no canonical organization membership resolution. Duplicate check is non-atomic `NOT EXISTS`. |
| `shipment_requests.status` → `notify_partner_shipment_status` | `partners.user_id` for current legacy partner ID; status change | Same legacy partner-user dependency; no current active org membership/role check. Duplicate check is non-atomic. |
| `partner_payouts.status` → `notify_partner_payout_paid` | `partners.user_id`; payout transitions to paid | Legacy partner-user lookup; notification identifies legacy `shipment_id`. Duplicate check is non-atomic. This records an in-app alert only; it is not proof of a real payout or payout settlement. |
| `support_tickets` INSERT → `notify_admin_new_support_ticket` | Earliest row in `admin_users` by `created_at` | Routes each new ticket to one earliest admin only; no role/on-call/team routing, no fan-out or fallback, no dedupe key. |
| `support_tickets.status` → `notify_customer_support_status` | `support_tickets.user_id`; status change | Uses user ID and status/title/message to suppress apparent duplicates. No unique event key; concurrent race possible. |

## Security and environment parity

- All eight functions are SECURITY DEFINER trigger functions.
- Catalog ACLs list only `postgres` and `service_role`; no direct anon/authenticated EXECUTE grant was present in the inspected ACL output. Trigger execution does not require callers to have direct EXECUTE.
- Functions use either empty search_path or `search_path=public`. Referenced objects in the reviewed bodies are schema-qualified. Continue to prefer empty search_path and full qualification for SECURITY DEFINER functions.
- All eight trigger definitions and function MD5 fingerprints match between Production and Staging. This establishes source parity for these specific objects only.
- This review does not prove the trigger table writes are safe under all callers or all RLS contexts.

## Cross-cutting correctness gaps

1. **Legacy data model:** shipment triggers are attached to `shipment_requests`, not the canonical `krim_shipments` event/outbox pipeline.
2. **Recipient drift:** partner alerts depend on `partners.user_id`, not current active `krim_organization_members` membership and role/permission checks.
3. **Duplicate race:** several functions use `IF NOT EXISTS` followed by INSERT without a unique event/idempotency constraint. Two concurrent transactions can both pass the predicate and insert duplicates.
4. **Missing canonical linkage:** payment function computes canonical shipment ID but writes only the legacy ID to the notification row. Other legacy shipment functions also write legacy `shipment_id` only.
5. **Incomplete admin routing:** support ticket alert is assigned to the earliest admin row, not an operational queue or all authorized support staff.
6. **Channel limitation:** all these functions insert legacy in-app notifications only. No email/SMS/WhatsApp/push/Telegram/provider delivery is performed.
7. **No delivery receipt:** no provider message ID, delivery attempt, bounce/complaint callback, or delivery state is recorded by these functions.

## Remediation priorities

- Replace legacy shipment triggers with canonical domain-event producers and a single idempotent notification intent/outbox pipeline.
- Use canonical shipment identifiers consistently.
- Resolve partner recipients from active organization membership and authorized roles at event time and again before delivery.
- Add durable unique idempotency keys based on source event/entity transition, not title/message text.
- Route support alerts through a role-aware queue with on-call/fallback behavior.
- Preserve mandatory service updates independently from optional marketing preferences.
- Add synthetic staging tests for recipient isolation, status transitions, concurrent duplicate updates, missing Auth links, multiple partner memberships, support routing, and canonical ID mapping.
- Keep external sends disabled until staging sink/allowlist/dry-run and worker recovery are proven.

## Evidence boundary

Read-only catalog and function-definition inspection. No test updates or trigger-producing writes were made. No synthetic users or tickets were created. No provider or external messaging call occurred. Production and Staging remained unchanged.
