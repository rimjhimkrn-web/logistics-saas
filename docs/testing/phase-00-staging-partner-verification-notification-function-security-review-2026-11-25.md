# Phase 00 — Staging partner-verification notification function security review

Date: 2026-11-25  
Branch: `qa/phase-00-baseline-2026-11-25`  
Scope: read-only inspection of `krim_admin_request_partner_verification_information(bigint,text)` in Staging, Production existence check, and related outbox/delivery indexes and preference RLS. No function invoked; no data or schema changed; no email sent.

## Executive result

The Staging-only function has several good safeguards: authenticated identity, AAL2, platform-admin permission, bounded request text, row locks, registered-business restriction, audit event, confirmed-email check, preference check, and a unique outbox idempotency key.

However, this is a **single partner-verification workflow**, not a general notification dispatcher. Its runtime behavior and end-to-end delivery remain untested.

**Status: source review partially positive; runtime NO-GO.**

## Environment parity

- Staging contains `public.krim_admin_request_partner_verification_information(bigint,text)`.
- The same exact signature is absent from Production.
- Do not promote/copy it without separate review of the full production schema dependencies, migration provenance, authorization and operational readiness.

## Authorization and state integrity

The function:
1. Requires `auth.uid()`.
2. Requires JWT AAL2.
3. Checks `private.krim_has_permission(user_id, 1, 'admin.platform')`.
4. Validates case ID and request text (10–1000 characters).
5. Locks the verification case and organization rows.
6. Requires the case to be open, in review, or pending information.
7. Requires `partner_account_mode = registered_business`.
8. Updates case and organization review states and writes an audit event.

It is SECURITY DEFINER with an empty search_path. The catalog ACL explicitly includes authenticated EXECUTE. This is an exposed privileged RPC, but its body has explicit auth, AAL2 and permission checks. It must receive negative JWT tests (anonymous, AAL1, non-admin, wrong organization/role, invalid/closed case) before any readiness claim.

## Recipient and channel behavior

- Recipient is `krim_partner_verification_cases.submitted_by`, not an independently resolved current active organization member.
- In-app notification is inserted for that user when present.
- Email is queued only if the Auth email is confirmed.
- An explicit disabled email preference suppresses the email queue row.
- No email queue row is created if email is unconfirmed.
- The function does not prove recipient remains an active member of the partner organization at send time.
- No fallback route is created if email is unavailable or suppressed.
- The in-app notification is inserted before the email preference check and is not suppressed by that email preference, which is appropriate for a mandatory service-status update but should be explicitly classified in the notification policy.

The email body contains a generic instruction to sign in; the detailed request is in the in-app notification and outbox payload. The function stores a workspace path in metadata.

## Idempotency and delivery integrity

- Outbox has a partial unique index on `idempotency_key WHERE idempotency_key IS NOT NULL`.
- Function key is `partner-verification-info:<case_id>:<md5(request)>`.
- Repeated same request is deduplicated at outbox level.
- A changed request intentionally generates a new outbox key.
- The function inserts a delivery row only when a new outbox row was inserted.
- Delivery table has an index on `outbox_id`, but no unique constraint/index on outbox_id was found in the inspected constraints/indexes. A concurrent or later alternate producer could create multiple delivery rows for one outbox; the current function avoids this for its own duplicate call path by relying on outbox insert RETURNING.
- Delivery status check allows queued/sending/sent/delivered/failed/cancelled. Outbox status has pending/processing/sent/failed/cancelled/dead_letter. State transition consistency between the two tables is not proven.
- No database constraint was found that guarantees a delivery row exists for every outbox row, or exactly one delivery per outbox/channel/provider.

## RLS and preferences

- The notification-preferences table has an authenticated SELECT policy scoped to `user_id = auth.uid()`.
- The function uses a read-only preference check under SECURITY DEFINER.
- No preference write policy or user preference mutation path was assessed in this focused task.
- No runtime cross-tenant or recipient-isolation tests were run.

## Required tests before accepting this workflow

1. Anonymous invocation rejected.
2. Authenticated AAL1 rejected.
3. AAL2 user without `admin.platform` rejected.
4. Platform admin succeeds only for a valid registered-business case.
5. Closed/missing case and invalid request lengths rejected with no partial writes.
6. Case submitted_by is no longer active member / user disabled: verify safe recipient handling.
7. Confirmed email + enabled preference: exactly one outbox and one delivery.
8. Unconfirmed email: in-app notification only; ensure case action still succeeds and status is visible.
9. Email preference disabled: mandatory in-app notification remains; no email outbox.
10. Repeated identical request: no duplicate outbox/delivery.
11. Concurrent identical requests: exactly one outbox and no duplicate delivery.
12. Changed request: a new outbox key is created and prior request history remains auditable.
13. Provider timeout, 4xx/5xx, crash after claim, and callback duplicate: no loss or duplicate external message.
14. Confirm delivery state transitions and eventual recovery/dead-letter semantics.

All runtime tests must use synthetic Staging identities and an isolated recipient sink after staging send-safety controls are installed. Do not invoke the current live-capable Resend worker.

## Evidence boundary

Source and catalog inspection only. The function was not invoked; no test users, cases, notifications, outbox rows or delivery rows were created; no provider was contacted; Production remains unchanged.
