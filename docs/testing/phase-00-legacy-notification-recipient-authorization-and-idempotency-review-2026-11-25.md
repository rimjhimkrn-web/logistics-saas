# Phase 00 — Legacy notification recipient, authorization and deduplication review

**Date:** 2026-11-25  
**Environment:** Production Supabase, read-only SQL/source inspection  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Result:** Notification inbox row access is tenant/user-scoped by RLS, but several legacy trigger functions have material recipient-mapping and idempotency limitations. No runtime notification tests were performed.  
**Safety:** No data, schema, function, trigger, policy, grant or secret was changed. No external message was sent.

## 1. Notifications table access controls

Production catalog evidence:
- RLS policies:
  - SELECT: `user_id = auth.uid()`
  - UPDATE: `user_id = auth.uid()` in both USING and WITH CHECK.
- Authenticated has SELECT and UPDATE table privileges; no direct INSERT privilege was listed.
- `anon` has no table grant in the inspected grant list.
- Service role and postgres have operational privileges.
- This is a positive baseline for user-owned inbox reads and updates. It does not prove that every trigger writes the correct recipient or that the UI uses only this table safely.

## 2. Legacy partner recipient mapping

The legacy assignment, shipment-status and payout trigger functions resolve recipients through `public.partners.user_id`, based on legacy `partner_id`.

Current Production snapshot:
- 10 legacy partner rows.
- 1 has a linked Auth user.
- 9 have no linked Auth user.

Consequences:
- For a legacy partner record without `user_id`, the reviewed trigger functions skip the notification.
- The old `partners.user_id` mapping is not equivalent to the canonical KRIM organization membership and assignment model.
- A single partner user may not represent all authorized operational and finance members of a partner organization.
- No source evidence in these functions proves active membership, role scope or assignment-to-organization validation.

**Finding L-01 — Legacy partner notices can be silently skipped.** The current snapshot shows 9/10 partner rows lack a linked Auth user. The trigger code only inserts when a linked user exists.

**Finding L-02 — Recipient model is too narrow for organization workspaces.** Resolve recipients from canonical active organization memberships and shipment/assignment role relationships, not a single legacy partner user field.

## 3. Legacy admin support notification

`notify_admin_new_support_ticket()` selects the earliest row from `public.admin_users` with `ORDER BY created_at LIMIT 1`, then inserts one notification for that user.

Current Production snapshot: one admin_users row exists, so the current one-admin dataset does not demonstrate misrouting today. But the logic will continue to notify only the first admin if multiple admins/on-call roles are added. It does not select by support queue, assignment, role, on-call rotation or active platform access.

**Finding L-03 — Admin routing is single-recipient and not role/on-call aware.** Replace with a least-privilege queue/role routing contract and explicit escalation policy before scaling admin operations.

## 4. Payment notification linkage and idempotency

`notify_customer_payment_paid()` fires on transition to `paid`. It calculates a canonical shipment identifier using `COALESCE(new.krim_shipment_id, new.shipment_id)`, but the insert statement writes only `new.shipment_id` into `notifications.shipment_id` and does not populate `notifications.krim_shipment_id`.

For a KRIM-native payment where `shipment_id` is NULL and `krim_shipment_id` is set:
- The message can contain the KRIM shipment number.
- The notification row's legacy `shipment_id` is NULL.
- The notification row's canonical `krim_shipment_id` remains NULL.
- The notification cannot be reliably joined back to the canonical shipment using the dedicated column.

The duplicate check is also a query-before-insert `NOT EXISTS` using user/type/title and a shipment predicate. No unique idempotency constraint was identified on the notifications table. Concurrent payment transitions or multiple payment orders can race; and the broad `shipment_id IS NULL AND v_shipment_id IS NOT NULL` branch can treat a prior null-linked payment notice as a duplicate for a different KRIM shipment belonging to the same user.

**Finding L-04 — Canonical shipment foreign-key linkage is lost for KRIM-native payments.** The trigger computes `v_shipment_id` but does not persist it in `krim_shipment_id`.

**Finding L-05 — Payment notification deduplication is not concurrency-safe.** A `NOT EXISTS` check without a database uniqueness/idempotency key is not a concurrency guarantee.

These findings are source-level. No synthetic payment update was executed to demonstrate them in runtime.

## 5. Other legacy trigger deduplication patterns

The reviewed quote, shipment-status, partner-assignment, partner-status and payout triggers use `NOT EXISTS` checks against recipient, shipment, type and title before inserting. This helps suppress ordinary repeated updates but is not a robust idempotency boundary under concurrent transactions. Status title text is also being used as part of identity rather than a stable event key/version.

The shipment-status triggers are bound to legacy `shipment_requests` and use legacy `customer_id` / `partner_id` user linkage. The canonical shipment table is `krim_shipments`; the relationship is represented by a legacy link field in the new model, but these triggers are not proof that every canonical lifecycle transition reaches the legacy table.

## 6. Trigger function privilege observations

The selected notification trigger functions are SECURITY DEFINER trigger functions. In the inspected effective privilege query, anon and authenticated did not have direct EXECUTE privilege on these trigger functions. This is expected for trigger-only functions and reduces direct RPC exposure. It does not remove the need to review the trigger's SECURITY DEFINER body, fixed search_path and write target.

The notifications RLS policy correctly scopes authenticated SELECT/UPDATE by `auth.uid()`. No test was performed against real JWTs or multiple users, so cross-user isolation remains source/catalog-confirmed only.

## 7. Prioritized remediation plan (not applied)

1. Define one canonical notification event ID and recipient-resolution contract; persist canonical shipment, organization, partner assignment, driver assignment and source-event identifiers.
2. Replace `partners.user_id` recipient resolution with active KRIM organization membership and role-scoped recipient sets.
3. Replace first-admin routing with queue/role/on-call routing and escalation, with no sensitive support details sent to unauthorized users.
4. Fix payment notice linkage so `krim_shipment_id` is populated for KRIM-native payments and legacy `shipment_id` only for legacy shipments.
5. Use a stable unique idempotency key (for example source event ID + recipient user ID + channel + template version) enforced by a unique constraint in the canonical outbox, rather than relying on title/message text and `NOT EXISTS`.
6. Reconcile legacy and canonical shipment lifecycle triggers so a single state transition cannot generate duplicate or conflicting notices.
7. Build synthetic staging tests: one and multiple partner members; inactive/revoked membership; unlinked legacy partner; multiple admin roles; concurrent duplicate event; two payments for two shipments with legacy shipment_id NULL; canonical shipment linkage; cross-user inbox reads/updates.
8. Only after staging origin and test credentials are isolated, run end-to-end tests with a sink provider. Do not test by editing Production rows.

## 8. Release decision

- **Inbox RLS baseline:** PARTIAL PASS (policy/grant source evidence only).
- **Legacy partner recipient coverage:** FAIL for complete coverage (9/10 legacy partner rows lack Auth-user link in current snapshot; canonical organization fan-out not evidenced).
- **Admin support routing:** PARTIAL / NOT SCALE-READY (currently one admin row; function selects only earliest admin).
- **Payment notification canonical linkage:** SOURCE-LEVEL DEFECT IDENTIFIED; runtime confirmation pending.
- **Legacy deduplication:** PARTIAL / NOT RACE-SAFE by source design.
- **Unified notification delivery:** NO-GO until canonical outbox/dispatcher, recipient resolution, deduplication, delivery receipts and runtime isolation tests pass.

**No Production changes were made.**
