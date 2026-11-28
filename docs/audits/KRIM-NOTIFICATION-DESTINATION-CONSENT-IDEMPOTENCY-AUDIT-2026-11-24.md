# KRIM notification destination, consent and idempotency follow-up — 2026-11-24

**Status: read-only schema audit. No production data or schema changed.**

## What the live schema supports
- `krim_customer_consents` records consent per acquisition profile and version. Types include `terms`, `privacy`, `communications`, `data_processing`, and `referral`; statuses are `pending`, `granted`, `withdrawn`, and `expired`.
- `krim_user_consent_events` records `marketing_email`, `product_analytics`, `personalization`, and `terms_and_privacy`. It is not a channel-specific transactional delivery permission registry.
- `krim_notification_preferences` supports `in_app`, `email`, `webhook`, `sms`, and `push`, keyed by user, organization, notification type and channel. It has no Telegram or WhatsApp preference channel.
- `krim_communication_suppressions` supports `email`, `sms`, `push`, and `webhook`; suppression is keyed by channel + destination hash + effective period. It has no organization/user uniqueness constraint and no Telegram/WhatsApp channel.
- `krim_organization_contacts` stores operational contact details but does not link a contact row to a verified auth user identity. It must not be used as an automatic destination for shipment messages without a separate authorization/verification process.
- `auth.users` email/phone confirmation metadata is the likely account-destination source for authenticated user delivery, but a channel-specific destination resolver still needs explicit review and must never return raw destinations to the browser.

## Idempotency and delivery data integrity
- `krim_notification_outbox` has a partial unique index on `idempotency_key` where non-null. This can enforce per-outbox event idempotency when callers construct a stable key.
- `krim_notification_deliveries` currently has only a non-unique index on `outbox_id`; repeated validation/worker attempts can create multiple delivery rows for one outbox item unless code/function logic prevents it.
- `krim_communication_recipients` has a primary key and an intent/status lookup index, but no unique key preventing duplicate user/intent recipient rows.
- Existing suppression lookup index is non-unique; active suppression must be checked by destination hash, channel, and effective time at send time.

## Required behavior before any external delivery
1. Resolve only verified auth-user email/phone values from the server side; require the corresponding auth confirmation timestamp for the channel.
2. Do not use free-text organization contact email/phone as a user destination. A future contact flow needs its own verification and authorization evidence.
3. Treat marketing separately: require applicable explicit marketing consent and honor withdrawal/suppression. Do not let marketing preference disable essential transactional/service notices. Do not send marketing through an account contact merely because it exists.
4. For essential shipment/service notifications, maintain the in-app feed as the mandatory durable channel; apply legal channel restrictions and verified destination rules to external channels. Record failures visibly rather than silently dropping the event.
5. Use a stable idempotency key derived from event ID + recipient user ID + channel + template/version. Rely on the existing outbox unique index; handle unique-conflict by loading the existing row.
6. Add a unique delivery-row strategy (or make delivery attempt records explicitly append-only with a separate unique active-delivery key) before calling validation more than once.
7. Re-check suppression and channel eligibility immediately before provider call. Do not mark provider acceptance as `delivered`; reserve that state for provider callback/receipt.
8. Resolve channel/provider mismatch: provider table supports email/sms/push/webhook while outbox additionally supports whatsapp/telegram/in_app/other. No route may be enqueued until its provider/channel pair is explicitly supported and active.

## Data limitation
Previously verified live counts for customer acquisition profiles, customer identity links, customer workspace profiles, partner shipment assignments, and communication recipients were all zero. Therefore this audit does not claim that any real customer/partner recipient can currently be resolved or tested.

## Gate
No production migration, outbox insertion, provider call, customer/partner message, or credential change was performed. This is a design and schema-evidence artifact only.
