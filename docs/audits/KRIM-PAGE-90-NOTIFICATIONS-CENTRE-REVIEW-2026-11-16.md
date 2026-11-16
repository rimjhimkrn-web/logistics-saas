# Page 90 — Notifications Centre Review
Date: 2026-11-16

## Canonical route
- `public/app/notifications.html`

## Findings and change
- The former page displayed fictional customs hold, e-POD and vessel departure alerts and claimed active WebSocket subscriptions without a connected notification data source.
- Removed sample alerts, false live-stream status and fake mark-all-read action.
- Replaced with a clear not-connected state and documented the missing requirements: authenticated user feed, recipient/tenant authorization, preferences, unread state, delivery receipts and freshness.

## Safety / limits
- No notification was marked read, sent, retried or modified.
- Existing notification worker/outbox is a separate backend component; its deployment alone does not establish user-facing inbox delivery or delivery receipts.

## Commit
- `eafd241101260e494f4fa0793aa6f57df11d071f`
