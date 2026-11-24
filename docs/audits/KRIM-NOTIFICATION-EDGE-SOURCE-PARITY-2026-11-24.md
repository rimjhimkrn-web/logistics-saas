# Notification Edge Function source parity snapshot

Captured: 2026-11-24
Supabase project: `ebltviniygljwwseplph`
Purpose: version-control exact deployed source before reliability remediation. This is a source snapshot only; it is not a production deployment.

| Function | Live status | Live version | JWT verification |
|---|---|---:|---|
| `krim-notification-retry-worker` | ACTIVE | 14 | false |
| `krim-notification-provider-adapter` | ACTIVE | 18 | true |

## Scope and limitations

- Source copied from the active deployed Edge Function file `index.ts`.
- Environment variable names are retained; no secret values or credentials are included.
- No deployment, database mutation, queue claim, provider call or test message was performed.
- The retry worker currently dispatches founder inquiry/follow-up Telegram queues only.
- The provider adapter's Resend route checks credential presence and explicitly keeps sending disabled; its Telegram test route can send a founder-authorized test message.
- This snapshot must be reviewed and tested before any subsequent deployment. Do not deploy this snapshot as a remediation.

## Known live reliability gaps

1. Claimed processing rows have no expired-lease recovery path in the inspected general notification outbox functions.
2. Claim ownership uses worker identity without a per-claim fencing token in the general notification functions.
3. Provider acceptance must not be represented as recipient delivery.
4. Resend is not an implemented sending adapter.
5. The general customer/partner notification delivery path has no production evidence.

See the existing detailed audit and remediation specification in `docs/audits/` and `docs/remediation-pending/`. The live migration-history mismatch remains a separate blocker to database changes.


## Follow-up live database and UI audit (2026-11-24)

Read-only production inspection of the general notification database functions found:

- All five inspected `krim_internal` helper functions are SECURITY DEFINER and owned by `postgres`.
- Their execution ACLs permit `service_role`; the inspected functions do not permit `authenticated`.
- No database function source currently references these helper function names as a caller. The deployed retry worker also does not call them; it processes separate founder inquiry/follow-up Telegram queues.
- `claim_notification_outbox` claims only `pending` rows and sets a timestamp lease in `next_attempt_at`. It does not reclaim expired `processing` rows and returns only the outbox ID.
- `validate_notification_delivery` inserts a new delivery row on every call and does not enforce one active attempt per outbox/provider/channel.
- `complete_notification_delivery` records provider acceptance as both `sent` and `delivered`, and on failure leaves worker metadata/lease state uncleared.
- `schedule_notification_retry` has a retry delay bound but no maximum-attempt/dead-letter transition.
- Legacy `mark_notification_delivery_result` has no worker ownership/fencing argument and also marks provider acceptance as delivered.
- The outbox has a unique partial idempotency-key index, but the delivery table has no corresponding uniqueness constraint for attempt creation.
- RLS read policies exist for authenticated organization users on the outbox, delivery and retry-event tables. These policies are SELECT-only; no direct authenticated write policy was found.
- The current general outbox and delivery tables still have zero records. This means no production evidence exists for actual customer/partner dispatch.
- `public/app/notifications.html` explicitly states that delivery is not connected and that no live feed, WebSocket subscription, preferences, receipts, unread counts or recipient-level authorization is connected.

### Separation of systems

The active deployed retry worker handles founder Telegram inquiry/follow-up queues only. The general `krim_notification_outbox` / `krim_notification_deliveries` functions are a separate, currently uncalled dispatch subsystem. These must not be conflated when assessing customer/partner notification readiness.

### Required implementation design before rollout

1. Add a per-claim UUID fencing token and explicit `claimed_at` / `lease_expires_at` (or equivalent) with atomic expired-lease recovery.
2. Use token-guarded compare-and-set transitions for every claim completion/retry; stale workers must be unable to mutate a reclaimed row.
3. Make delivery-attempt creation idempotent under concurrent calls, with a database uniqueness strategy and deterministic attempt identity.
4. Distinguish `accepted/sent` from `delivered`; only a verified provider webhook/event may set `delivered_at`. Preserve provider-specific event IDs and validate webhook signatures/timestamps/replay.
5. Implement bounded exponential backoff with jitter and a terminal `dead_letter` state; retain auditable retry events.
6. Implement an actual Resend send adapter with sender-domain verification, recipient validation, rate limits, idempotency, timeout handling, webhook signature verification and suppression/bounce handling.
7. Connect domain events to required customer/partner notifications, with channel-specific consent only where legally applicable; essential transactional/service notices must not be silently disabled.
8. Connect the UI to tenant-scoped authorized feeds, unread/read state, delivery receipts and notification preferences. Until then it must remain explicitly marked not connected.
9. Test concurrent claims, lease expiry, stale worker completion, duplicate calls, provider timeout/ambiguous success, webhook replay, bounce/complaint, retry exhaustion, organization isolation and mandatory-notice delivery in staging.

No production changes were made. The migration-history baseline remains a prerequisite for new DDL.
