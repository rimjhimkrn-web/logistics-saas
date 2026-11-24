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
