# KRIM shipment in-app notification handoff implementation — 2026-11-24

## Implementation in PR #245 (draft)
- Added an idempotent event/user/type key to the legacy `public.notifications` feed through a proposed nullable `event_id` column and partial unique index.
- Preserved the current workflow executor as a compatibility function and added a wrapper that runs the legacy action plus durable in-app handoff in one database transaction.
- Handoff accepts only the five explicitly mapped shipment lifecycle/action pairs; it uses the verified identity-only recipient resolver and fails closed for unknown mappings.
- Customer/partner in-app notification rows are inserted only for resolved user IDs. Duplicate event/user/type notifications are suppressed by the unique index.
- No-recipient outcome is recorded in the action response and workflow step result as `no_eligible_recipients`; it is not represented as delivered.
- Notification Centre now reads the authenticated user's `public.notifications` rows, scopes queries and read-state updates by the signed-in user ID, escapes rendered content, and provides an explicit Refresh action.
- Shared application Supabase client is exported from `public/app/app-store.js`; no service-role credential is exposed.

## CI validation at head 5bd79b1aaac92e1d6a4069cbd6a52b4af9e20e30
All six checks passed:
1. KRIM production smoke checks.
2. KRIM static link audit.
3. Notification recipient resolver isolated PostgreSQL 16 tests.
4. Workflow action batch isolated PostgreSQL 16 tests: success, retry, max-attempt dead-letter and stale-worker lease replacement.
5. Shipment in-app handoff isolated PostgreSQL 16 tests: customer recipients, partner recipient, duplicate event idempotency, explicit no-recipient outcome.
6. Cloudflare Pages preview build/deployment check.


- Fixed a critical environment-isolation gap in the shared app store: it now selects the isolated staging Supabase project on all `.krim-staging.pages.dev` hosts and local/preview hosts, and production only on the canonical GitHub Pages production host (unless an already initialized shared client is supplied). The production smoke suite executes the actual bootstrap against five synthetic hostnames; all cases passed.
- Latest Cloudflare Pages preview build succeeded at commit `df6ee404ad133cc2c901accb105e8c60b7a09163`. Branch preview: `https://feat-notification-recipient.krim-staging.pages.dev`.

## Production compatibility evidence (read-only)
- `public.notifications` currently has 5 rows and 0 null user IDs.
- `public.notifications.event_id` does not yet exist in production.
- Exactly one current overload of `public.krim_internal_execute_workflow_action(bigint)` exists.
- Catalog dependency query found no function-level dependents on that executor.
- The live batch currently calls the one-argument executor, so the wrapper preserves that signature. The separate proposed batch replacement passes the claim lease/worker values into the fenced bridge.

## Hard limitations / release gates
- All new SQL tests run against synthetic PostgreSQL fixtures. They prove compilation and selected behavior, not complete production-schema parity.
- The production migration ledger is still under reconciliation. Do not apply either proposed migration to production until the full migration sequence is reconciled and a disposable database with the complete workflow/auth/notification schema validates the combined migrations.
- Production recipient readiness is not established: current customer identity links, customer acquisition profiles, partner shipment assignments and communication recipient rows were zero at the last read-only audit.
- Communication intents, routes and providers are also unconfigured; provider credentials/readiness are absent. This implementation creates durable **in-app** notifications only. It does not send email, SMS, WhatsApp, Telegram or push notifications.
- The Notification Centre can query the legacy feed today, but new event-linked records will only be created after the proposed SQL is safely deployed and eligible verified recipients exist.
- Realtime publication status has not been verified; polling/Refresh remains the fallback.
- No production database, secret, provider setting, cron job or external message was changed.

## Release decision
PR remains draft and must not be merged/applied to production yet. Required next: full-schema migration integration test, inspect migration ordering/ACLs with Supabase advisors, confirm recipient identity provisioning, then configure provider routes and perform an explicitly approved test send.
