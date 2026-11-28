# KRIM workflow-to-notification outbox bridge — live execution audit

**Date:** 2026-11-24  
**Status:** read-only audit; no production changes.

## Executive finding
The shipment workflow currently records customer/partner notification actions as successful after marking them "prepared". It does not enqueue a durable notification. This is a confirmed implementation gap, not a provider outage.

## Live executor behavior
The live function `public.krim_internal_execute_workflow_action(bigint)` currently handles:
- `prepare_customer_notification` and `prepare_partner_notification`: completes the workflow step and action with response `status=prepared`, `external_send=blocked_until_provider_and_recipient_ready`.
- It does not call `krim_internal.resolve_shipment_notification_recipients`.
- It does not call `krim_internal.enqueue_communication_intent`.
- It does not insert `krim_notification_outbox` rows.
- It then allows the workflow run to complete once all steps are completed.

Therefore "workflow action succeeded" currently means only "notification preparation placeholder completed", not "durably queued" and certainly not "delivered".

## Communication configuration
Live read-only query on 2026-11-24 found:
- `krim_communication_intents`: 0 rows.
- `krim_communication_routes`: 0 rows.
- `krim_communication_providers`: 0 rows.
Thus the existing enqueue helper cannot currently enqueue a real notification: it requires an active intent and active route, and neither is configured.
- `krim_communication_recipients`: 0 rows.
- `krim_notification_outbox`: 0 rows (previous point-in-time audit).
- Customer acquisition profiles, identity links, workspace profiles, and partner shipment assignments were also previously verified at zero rows.

## Safe integration design
Do not patch the live function until the migration ledger is reconciled and the replacement is tested in a disposable database. Proposed behavior:
1. Validate the action is one of the two notification action types and obtain the event ID, shipment ID, organization ID and run-step ID from the locked workflow records.
2. Map the event/action to a configured active intent using a stable explicit mapping; do not infer arbitrary intent codes from user-supplied payload fields.
3. Resolve eligible recipient user identities through the service-only resolver; fail closed if no eligible identity exists.
4. Resolve only confirmed server-side destinations for supported channels. Never use unverified organization free-text contact fields.
5. Evaluate channel-specific preferences, legal consent, current suppression, and required in-app notification behavior. Marketing consent must not gate essential service notices; marketing must be separate.
6. Validate the route's channel/provider pair, active provider, credential reference, and configured template. Current provider schema supports email/sms/push/webhook, while outbox also accepts whatsapp/telegram/in_app/other; do not enqueue mismatched pairs.
7. Insert one outbox row per event + recipient + channel using stable idempotency key. Existing unique partial index on outbox idempotency_key is suitable for deduplication; handle unique conflict by reading the existing row.
8. Only mark the workflow action/step as "queued" (or a dedicated durable-enqueue state) after the outbox insert succeeds in the same database transaction. If recipient/provider configuration is absent, mark a visible blocked/retryable state; do not mark the notification action succeeded.
9. Keep delivery lifecycle independent: provider acceptance => sent; provider callback/receipt => delivered. Retain failures and retry/dead-letter state.
10. Add an authenticated in-app feed entry as a durable user-visible service notification; do not silently suppress essential operational notices.

## Required tests
- Customer shipment events target only verified customer identity + active workspace/account + same-organization active member.
- Partner assignment events target only members of the assigned, active, verified, compliant partner organization.
- No recipient / inactive recipient / mismatched organization => no external destination and visible blocked state.
- Missing intent, route, provider, template, credential, or unsupported channel => action is not reported as durably queued.
- Duplicate executor invocation for same action/event/recipient/channel creates one outbox row.
- Two concurrent workers cannot create duplicate outbox rows.
- Outbox insert and workflow state update are atomic.
- Outbox conflict returns existing row idempotently.
- Provider acceptance does not set delivered_at.
- Only verified provider delivery callback sets delivered_at.
- Provider timeout, process crash, expired lease, stale worker token, retry exhaustion and dead-letter transitions.
- RLS / execute grants: no anon/authenticated ability to invoke internal resolver/enqueue/worker functions.
- No tests send real messages; use mocked provider adapter and synthetic fixtures.

## Immediate release gate
**NO-GO for live customer/partner external notification delivery.** No active intent, route, provider, recipient, or verified test fixture is currently configured. No production changes or messages were made in this audit.
