# KRIM notification runtime readiness — production read-only audit

**Audit date:** 2026-11-24  
**Environment:** Supabase production project, read-only inspection  
**Result:** NOT READY for customer/partner notification activation  
**Changes made:** None to production schema, data, Edge Functions, grants, or policies.

## 1. Live row counts

| Table | Rows |
|---|---:|
| `notifications` (legacy user feed) | 5 |
| `krim_notification_outbox` | 0 |
| `krim_notification_deliveries` | 0 |
| `krim_notification_preferences` | 0 |
| `krim_communication_intents` | 0 |
| `krim_communication_routes` | 0 |
| `krim_communication_providers` | 0 |
| `krim_communication_recipients` | 0 |
| `krim_communication_suppressions` | 0 |

The five legacy notification rows do not demonstrate that the new outbox/provider delivery pipeline is active.

## 2. Table access posture

All nine inspected communication/notification tables have RLS enabled. The inspected policies are SELECT-only for authenticated application users, scoped to the applicable organization or self. The legacy `notifications` table has own-row SELECT and UPDATE policies.

This inspection did not test every policy predicate or every RPC execution path. No policy or grant changes were made.

## 3. Existing database workflow findings

### `krim_internal.enqueue_communication_intent(...)`

- Requires a non-empty idempotency key.
- Requires an active communication intent.
- Returns an existing outbox ID for a matching idempotency key.
- Selects only the first active route by route order.
- Inserts one pending outbox record.
- Does not resolve or iterate recipient records in the inspected function body.
- Does not apply fallback routes or route retry limits in this function.

Because intent, route, provider, and recipient tables currently have zero rows, this function cannot currently enqueue a configured communication intent; it will raise `active_intent_not_found` or `communication_route_not_configured` before creating an outbox row.

### `krim_internal.resolve_notification_provider(...)`

- Looks up an active provider matching the outbox provider and channel.
- Requires a credential reference.
- Returns provider configuration metadata when configured.
- The live provider configuration table currently has zero rows.

### `krim_internal.start_notification_run(...)`

- Creates an idempotent operational notification run and a queued run event.
- The existence of this run-tracking function does not itself deliver messages or populate recipient/outbox records.

### Legacy unread counter

`public.get_unread_notification_count()` counts unread rows only where `user_id = auth.uid()`. It is not evidence of a functioning end-to-end notification delivery pipeline.

## 4. Edge Function source inspection

- `krim-notification-retry-worker` is active at deployed version 14. Its inspected source claims and retries founder inquiry/follow-up Telegram queues. It does not process the generic customer/partner notification outbox.
- `krim-notification-provider-adapter` is active at deployed version 18. Its inspected source exposes a founder-authorized Telegram test route and reports Resend credential presence while explicitly keeping email sending disabled.
- No production test message was sent during this audit.

## 5. Required implementation gates

1. Seed and review a minimal, explicit catalogue of transactional notification intents and route definitions. Do not invent recipients or enable unverified providers.
2. Configure providers only after credentials, sender identity, verified domains, channel ownership, and provider callback/webhook behavior are validated.
3. Implement recipient resolution against authoritative user/organization membership and destination records. Do not accept arbitrary client-supplied destinations.
4. Enforce mandatory transactional notices independently of optional marketing preferences and quiet hours, subject to applicable legal requirements.
5. Add event-to-intent wiring for customer and partner lifecycle events, with idempotency at event, recipient, channel, and provider boundaries.
6. Fix the generic worker contract before activation: expired-lease recovery, fencing tokens, bounded retries/dead-letter handling, duplicate-delivery prevention, and correct distinction between provider acceptance (`sent`) and confirmed delivery (`delivered`).
7. Add provider callback verification and delivery-state reconciliation.
8. Add authenticated customer/partner notification feeds, unread counts, preferences, and delivery receipts with tenant/recipient isolation.
9. Test positive and negative authorization, duplicate events, provider timeouts, throttling, retries, dead letters, webhook replay, and failure recovery in a non-production test environment.
10. Activate only after end-to-end tests pass and an operational rollback plan is documented.

## 6. Release decision

**NO-GO for customer/partner notification production activation.**

This is a verified readiness gap, not a claim that every notification-related database object is absent. The production objects and helper functions exist, but the configuration tables are empty and the currently deployed retry worker is not the generic outbox worker.

No paid infrastructure was created or used for this audit.