# KRIM SaaS trial request workflow — implementation contract (draft)

**Status:** design only. No production schema, Edge Function, trial or entitlement was changed by this document.

## User journey
1. An organisation owner or authorised organisation admin opens the Plans page and chooses **Request a 30-day guided evaluation**.
2. The authenticated app asks the server to create a trial request for the organisation selected from the user's active memberships. The browser must not be trusted to assert organisation ownership, plan eligibility, trial length, approval state, expiry or entitlements.
3. Server checks: authenticated user; active organisation membership; owner/admin permission; published plan; no current trial/paid/grace subscription; no prior trial if KRIM adopts one-trial-per-organisation; required contact/acceptance fields; rate limit and duplicate request.
4. Server creates a subscription request in `pending_approval`, records `requested_by`, chosen plan/version and immutable request metadata, but grants **zero entitlements**.
5. The platform admin reviews it in a restricted admin queue. Approval requires fresh AAL2 and platform-admin role; approver cannot be the requester. Rejection requires a reason and audit event.
6. Approval starts the 30-day period using database time, creates plan-version-pinned entitlements and returns the actual expiry. The customer sees the exact start/end and evaluation scope.
7. Entitlement resolution checks membership, active status and current time on every protected server action. At expiry, access fails closed; the expiry worker updates the status and audit trail. There is no automatic paid conversion.
8. At expiry, the organisation can request a separate paid quote or remain on free/basic access. Payment checkout is not part of this workflow.

## API contract (proposed; not wired)
### Customer request
`POST /functions/v1/krim-saas-control`
```json
{
  "action": "request_trial",
  "organization_id": 123,
  "plan_code": "partner_professional",
  "plan_version": 1,
  "accept_evaluation_terms": true,
  "request_id": "client-generated-uuid"
}
```
Response: `{ ok, request_id, subscription_request_id, status: "pending_approval" }`.
The server must resolve the caller's membership and validate plan publication. A duplicate request ID with the same actor/action/payload returns the original result; reuse with a different payload is rejected. Never return internal admin notes.

### Admin queue
`POST /functions/v1/krim-saas-control` action `list_trial_requests`.
Only AAL2 platform admin/superadmin. Return minimal fields: request ID, organisation display name, requested plan/version, requester identity, submitted time, status. Do not expose billing profiles, unrelated users or private organisation records.

### Admin decision
Actions `approve_trial` and `reject_trial`. Approval must call the reviewed database RPC; browser cannot set `trial_started_at`, `trial_ends_at`, subscription status or entitlements. Rejection requires a bounded reason. Both actions require AAL2, platform role, no self-approval, idempotency key and audit record.

## Data and security invariants
- Trial request is not an active trial and grants no product access.
- One live subscription per organisation; enforce in database under concurrent requests.
- Trial duration is fixed at 30 days, calculated with database time.
- Plan version is pinned at approval; later catalogue edits do not silently alter an existing trial.
- No client INSERT/UPDATE/DELETE to subscription, entitlement, admin request ledger or audit tables.
- Public catalogue may be read-only; subscription and entitlement rows must never be public.
- Any privileged function belongs in a non-exposed schema where practical, has explicit EXECUTE grants, fixed search_path, auth.uid() checks, and least-privilege ownership.
- Use SECURITY INVOKER by default. Any SECURITY DEFINER exception requires separate review because it bypasses RLS.
- Admin queue and decision endpoints must enforce role and AAL2 on the server, not merely hide UI.
- Audit log must be append-only at database level; normal app and admin roles cannot update/delete/truncate.
- Do not store payment credentials or sensitive identity documents in trial metadata.
- Trial end blocks access even if the scheduled expiry worker fails. Never auto-convert to paid.

## Required acceptance tests before staging sign-off
1. Anonymous request rejected.
2. Authenticated user with no active membership rejected.
3. Member without owner/admin permission rejected.
4. Client-supplied organisation ID not in active membership rejected.
5. Draft/retired plan and invalid version rejected.
6. Repeated request ID with identical payload is idempotent.
7. Reused request ID with changed payload rejected.
8. Concurrent duplicate requests cannot create multiple live trials.
9. Existing trial/paid/grace subscription blocks another trial.
10. Prior-trial rule behaves as the approved commercial policy specifies.
11. Pending request grants zero entitlements.
12. Non-AAL2 admin cannot list/approve/reject.
13. Non-platform-admin cannot list/approve/reject.
14. Requester cannot approve their own request.
15. Client cannot choose trial start/end, status, approver or entitlements.
16. Approval creates exactly 30 days from database time.
17. Repeated approval does not duplicate entitlements or audit events.
18. Rejection requires a reason and creates an audit event.
19. Cross-organisation reads are denied.
20. Revoked membership loses entitlement visibility immediately.
21. Expired trial is denied even before expiry worker runs.
22. Expiry worker transitions once and writes one audit event.
23. No automatic charge, paid conversion or freight booking is triggered.
24. Audit update/delete/truncate attempts are denied.
25. Admin endpoints return no private notes or unrelated organisation data.

## Dependencies / blockers
- Reconcile 425 production migration history entries against 263 repository migrations at SQL-body/hash level; metadata suffix matching is not sufficient.
- Establish a disposable/staging schema baseline and deploy there first.
- Review the existing subscription foundation and RPC drafts for actual role table types, security-definer ownership, default EXECUTE grants, idempotency enforcement, plan-version constraints and immutable audit enforcement.
- Explicitly review Data API exposure and table/function grants. Supabase's 30 October 2026 change means new public-schema tables/functions must not be assumed exposed; grant only what each role needs.
- Implement dedicated SaaS tables and Edge Function only after the above gates.
- No live checkout until payment-provider SaaS eligibility, tax treatment, refunds and billing lifecycle are verified.

## Existing admin enquiry follow-up workflow — production read-only check
On 11 November 2026, read-only catalog inspection confirmed `public.krim_inquiry_followups` exists with RLS enabled and service-role table grants. No policies were returned for the table, so browser users do not have a direct policy-based route to its private notes. The existing `global-admin-control` Edge Function contains both `inquiry_followups` and `add_inquiry_followup` actions and already enforces authenticated platform role plus AAL2 before dispatch. The admin page calls those actions. This confirms the missing-action concern in an earlier audit note is resolved in the current main-branch code; actual live UI interaction still requires an authorised admin session and should be smoke-tested manually. Do not expose this table directly to the client.
