# KRIM Staging Edge Function and Notification Worker Safety Audit — 2026-11-27

## Scope and boundary
Read-only review of deployed Edge Function source and database routines in Staging project `qrpcivhdxobiaofppbkl`. No invocation, no email sent, no notification claim, no test invitation, no organisation provisioning, no DB writes, no Production access.

## 1. `krim-resend-email-worker` — ACTIVE v1, verify_jwt=false
The function does not accept anonymous work merely because JWT verification is off. It requires POST and a custom `x-krim-cron-secret` matched against `KRIM_NOTIFICATION_CRON_SECRET`; secret must be at least 32 characters and comparison is constant-time over SHA-256 digests. It then uses service role to claim a batch and calls Resend.

Critical safety finding:
- The worker is a real external email sender, not a harmless staging simulator.
- It sends to confirmed Auth users and calls `https://api.resend.com/emails`.
- Its database claim function only selects `partner_verification_information_requested` Resend email records in pending/failed state, up to 25; it has no explicit `runtime_lane='test'` or fixture-run exclusion.
- Therefore invoking it for workflow testing could send real transactional email and mutate the shared notification outbox/delivery state.
- The worker must remain uninvoked during Phase 00 workflow fixture testing. Before any activation, verify the staging secret/provider configuration and prove queue isolation. Prefer a dry-run/sink provider for tests.

The finish routine updates shared notification outbox/delivery rows and retry-event history. It is SECURITY DEFINER with empty search_path. This is not a workflow worker and must be separately isolated.

## 2. `owner-testing-authorize` — ACTIVE v5, verify_jwt=true
- Requires POST, explicit allowlisted origin, bearer token, valid Auth user, confirmed email and signed AAL2 claim (the token is validated by `auth.getUser(token)` before the AAL claim is read).
- Uses service role to verify exactly one active `platform_superadmin` assignment and that it belongs to caller.
- This is an authorization check only; it does not provision fixtures or execute workflow actions.
- Exact project-ID guard is not hard-coded in this function; it relies on deployed `SUPABASE_URL`/keys. For high-risk owner tooling, add an exact Staging project guard before future changes.

## 3. `global-admin-control` — ACTIVE v2, verify_jwt=true
- Validates bearer user with Auth and requires current MFA AAL2.
- Uses service role to read active role assignments and permits platform_admin/platform_superadmin.
- Includes owner-testing authorization branch that checks single designated superadmin.
- Also contains privileged admin operations (role assignment/revocation, user disable/enable, session revocation) and audit writes. It is not a workflow test runner.
- CORS is wildcard. Authentication and role checks are the security boundary, but origin restriction and an exact Staging project guard should be considered for privileged browser-facing admin operations.
- Do not invoke administrative mutation actions as part of workflow tests.

## 4. Fixture management functions
- `krim-phase00-test-user-invites` — ACTIVE v3, verify_jwt=true. Exact Staging project ID guard, allowlisted origins, confirmed user + AAL2, single owner check, four distinct role-labelled emails and run UUID. It can send real Auth invitations; no invocation was made.
- `krim-phase00-provision-test-organizations` — ACTIVE v2, verify_jwt=true. Exact Staging project ID guard, owner + AAL2, verifies four fixture identities are confirmed and marked for the run, then provisions organizations via a private fixture RPC. It creates persistent test organization/membership records; no invocation was made.

These two functions are not event/workflow test ingress and should not be used to simulate workflow events.

## 5. Notification DB worker routine
`krim_internal_claim_resend_email_batch(integer)` selects pending/failed Resend deliveries for exactly `partner_verification_information_requested`, increments attempts, and changes outbox/delivery rows to processing/sending. It has no fixture-run or runtime-lane filter. `krim_internal_finish_resend_email(...)` marks sent/failed/dead_letter and writes retry history. Both routines must be included in notification side-effect isolation; do not test by invoking the email worker.

## 6. Required remediation/design before any test-runner activation
1. Keep Resend worker disabled from all test workflows; do not send test data to a live provider.
2. Add explicit test-lane exclusion to the email claim routine and worker contract, or use a separate test notification sink/queue.
3. Add exact project-ID checks to privileged owner/admin tooling in a future reviewed change.
4. Review all privileged actions in `global-admin-control` for explicit allowlists and confirm no client route exposes destructive actions unintentionally.
5. Verify whether the custom cron secret is configured without revealing it; never log or return it.
6. Inventory repository callsites for these functions and external scheduler/cron configuration; deployed source alone does not establish who invokes them.
7. Only then finish the complete call graph and draft the workflow isolation migration.

## 7. Status
- Edge source reviewed for all five deployed Staging functions.
- Email worker has a real external delivery path and unfiltered shared queue claim with respect to fixture lane.
- No functions invoked, no emails/invitations sent, no organization fixtures provisioned.
- No SQL migration or DML.
- Production untouched.
- Phase 00 remains OPEN — NOT APPROVED; Phase 01 is not authorized.
