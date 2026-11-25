# Phase 00 — Workspace notification inbox and support-feed source audit

**Date:** 2026-11-25  
**Environment:** QA-branch source inspection; no browser session or authenticated runtime was exercised  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Result:** Workspace implementations are inconsistent. Driver has a real authenticated legacy inbox; customer/global centre is explicitly disconnected; partner page is a local-only preview; warehouse page is a facility-scoped operational attention view, not a notification inbox; central dispatch page is readiness-only.  
**Safety:** Static source inspection only. No sign-in, row mutation, support-ticket creation/reply, notification mark-read, worker invocation or external send was performed.

## 1. Customer / general Notifications Centre

File: `public/app/notifications.html`

The page explicitly states:
- No live user notification feed is connected.
- No WebSocket subscription is connected.
- No notification rows are loaded or marked read.
- Unread counts, preferences, delivery receipts and recipient authorization are not connected.

**Status: NOT CONNECTED.** The route is a truthful non-operational placeholder, not a usable customer notification inbox.

## 2. Driver Notifications & Support

File: `app/driver/module-15-notifications-support.html`

Source-confirmed controls:
- Requires an authenticated Supabase session.
- Requires exactly one active organization membership with role `driver`.
- Checks that the linked organization is active.
- Loads up to 100 `notifications` rows filtered by `user_id = session.user.id`.
- Computes unread count from `is_read`.
- Marks a row read with both notification ID and current user ID filters.
- Loads support tickets filtered by current user ID.
- Loads only non-internal support messages.
- Uses an RPC for customer-style support replies.
- Creates support tickets with current user ID and active organization ID.
- Explicitly warns that inbox records do not prove external delivery.

Limitations:
- No real-time subscription; refresh is manual.
- Notification list is capped at 100, with no pagination or explicit “older records” path.
- No visible delivery state/provider message ID/channel status in the inbox query.
- No per-notification server-authoritative receipt acknowledgement beyond setting `is_read`.
- It uses the legacy `notifications` table, not the canonical notification outbox/delivery tables.
- It requires exactly one active driver organization, which may be a deliberate safety restriction but needs multi-membership product policy.
- The UI's mark-read action is filtered by both row ID and user ID; RLS is a second protection layer. Runtime cross-user denial still needs tests.

**Status: SOURCE-CONFIRMED LEGACY IN-APP INBOX, PARTIAL.** No runtime session, query, read-state or cross-user test was performed.

## 3. Partner Notifications & Support

File: `public/partner/notifications-support.html`

The page explicitly identifies itself as a communications preview:
- illustrative content only;
- no live messages or support records;
- local-only interactions;
- does not send email, SMS, WhatsApp or push;
- does not change account preferences or create support tickets.

**Status: PREVIEW ONLY / NOT AN OPERATIONAL PARTNER INBOX.**

## 4. Warehouse Alerts & Queue

Files: `public/warehouse/notifications.html` and `app/warehouse/staging/page-15-warehouse-alerts-queue.html`

The public warehouse notifications route is backed by authenticated queries:
- requires a session;
- loads warehouse tasks through `krim_warehouse_list_tasks`;
- loads inventory rows with pending/hold/rejected quality status;
- loads evidence through `krim_warehouse_list_evidence`;
- builds a task/quality/evidence attention view;
- states that it does not send external notifications.

The staging triage page says acknowledgement, assignment, escalation and resolution are unavailable until a verified server-side warehouse alert contract exists.

This is an operational attention queue, not a user notification feed. It does not prove alert recipients, unread/read status, delivery, or escalation.

**Status: PARTIAL OPERATIONAL ATTENTION VIEW; NOT A NOTIFICATION INBOX.**

## 5. Central Support / Notification Dispatch

Files: `public/support/notifications-dispatch.html`, `public/support/support-runtime.js`

The dispatch page explicitly says live delivery streams and delivery receipt verification are not connected. It says the Resend adapter is readiness-only and sending is disabled; SMS and WhatsApp are unverified.

The support runtime does have authenticated customer support-ticket paths:
- `auth.getSession()` gate;
- ticket list scoped by `user_id = session.user.id`;
- customer-visible messages filtered with `is_internal = false`;
- customer reply uses `krim_customer_reply_support_ticket` RPC.

These are support-ticket conversations, not a notification dispatch system. The static source audit did not prove ticket RLS behavior or runtime role isolation.

**Status: SUPPORT TICKET HISTORY PARTIAL; OMNICHANNEL DISPATCH NOT CONNECTED.**

## 6. Cross-workspace comparison

| Workspace | Authenticated source | Feed source | Read/unread | Live refresh | Delivery receipts |
|---|---|---|---|---|---|
| Customer / general | Not connected on notification centre | None | None | None | None |
| Partner | Preview only | Illustrative/local only | None | None | None |
| Driver | Session + active driver membership + active org | Legacy `notifications` by current user | `is_read`, mark-read update | Manual refresh | Not shown |
| Warehouse | Session; protected RPC/query sources | Tasks, inventory holds, evidence | No notification read state | Manual refresh | Not applicable / not shown |
| Customs | Not yet source-verified in this inbox pass | Not established | Not established | Not established | Not established |
| Finance | Not yet source-verified in this inbox pass | Not established | Not established | Not established | Not established |
| Operations Control Tower | Not yet source-verified in this inbox pass | Exceptions/workflow signals elsewhere | Not established | Not established | Not established |
| Enterprise | Not yet source-verified in this inbox pass | Not established | Not established | Not established | Not established |
| Platform Admin | Support and alert pages exist; this pass did not establish a unified inbox | Not established | Not established | Not established | Not established |

“Not yet source-verified” means this pass did not inspect every page/API for that workspace; it is not a claim that no code exists.

## 7. Priority gaps

1. Implement one authenticated notification-feed API/RPC with recipient resolution server-side and strict organization/role scope.
2. Bridge legacy notification records and canonical outbox/delivery receipts, with a migration strategy that prevents duplicates.
3. Expose clear lifecycle states: queued, processing, provider accepted, delivered (only on provider receipt), failed, retrying, dead-letter.
4. Add pagination, unread count, mark-read/mark-all-read with server-side ownership checks, and real-time refresh or reliable polling.
5. Add role-specific feeds for customer, partner, driver, warehouse, customs, finance, control tower, enterprise and platform admin.
6. Keep essential service/security notices distinct from optional marketing preferences.
7. Add multi-user staging tests for same-organization and cross-organization access, revoked membership, multiple roles, duplicate event, pagination, read-state mutation, reconnect and missed-update recovery.
8. No external dispatch test until isolated staging sink/provider credentials and approved recipient allowlist are proven.

## 8. Release decision

- Customer notification centre: **NOT CONNECTED**.
- Partner notification page: **PREVIEW ONLY**.
- Driver inbox: **PARTIAL SOURCE PASS; RUNTIME NOT TESTED**.
- Warehouse attention view: **PARTIAL OPERATIONAL VIEW; NOT A NOTIFICATION FEED**.
- Support ticket conversations: **PARTIAL SOURCE PASS; RUNTIME NOT TESTED**.
- Generic dispatch and delivery receipts: **NOT CONNECTED / NOT VERIFIED**.
- Complete nine-ecosystem notification inbox: **NO-GO**.

**No Production changes, database writes, user communications or provider calls were made.**
