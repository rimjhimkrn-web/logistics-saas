# KRIM SaaS trial RPC security review — 11 November 2026

## Scope
Read-only review of the SaaS subscription foundation SQL draft and trial approval/entitlement RPC draft, plus live catalog inspection of existing KRIM role and organisation structures. No production schema or data was changed.

## Confirmed production structure
- `krim_organizations.id` is bigint.
- `krim_user_role_assignments.organization_id` is nullable bigint; `user_id` is uuid; `role_id` is bigint; `is_active` is boolean.
- Global platform role assignments use a nullable organisation scope; the existing admin Edge Function independently validates the user's JWT, AAL2 and platform role.
- `private.krim_has_organization_access(uuid,bigint)` exists and checks active membership and active organisation. It is SECURITY DEFINER with a fixed search_path.
- No SaaS subscription foundation tables currently exist in production. The new tables/RPCs remain drafts.
- The existing `krim_inquiry_followups` table exists with RLS enabled and no returned client policies; service_role has table privileges. This is consistent with keeping private follow-up notes behind the AAL2 admin Edge Function.

## Security correction made to the draft
The initial trial approval draft proposed a SECURITY DEFINER function in public with authenticated EXECUTE. That is too broad for a privileged state transition. The draft has been revised:
- `krim_saas_approve_trial(uuid,uuid,uuid)` is now intended for the trusted Edge Function's service-role client only.
- EXECUTE is explicitly revoked from PUBLIC, anon and authenticated, and granted only to service_role.
- The Edge Function must validate the caller's JWT, AAL2, platform-admin role and no-self-approval before passing the actor UUID.
- The database function rechecks the actor's platform role assignment and calculates the trial start/end using database time.
- The entitlement resolver is explicitly SECURITY INVOKER so the caller's table grants and RLS remain in force.

## Remaining blockers — do not deploy yet
1. The service-role-only RPC must be integrated only after an Edge Function implementation is written and tested; the actor UUID must never be accepted directly from a browser request.
2. The approval RPC's `p_request_id` is currently recorded but not yet enforced through the request ledger. Implement payload-hash idempotency and same-key/different-payload rejection before release.
3. The expiry-worker draft creates a ledger table but does not yet use it; the worker needs a monitored invocation path and one-event-only behavior under concurrent runs.
4. The audit table is not yet database-enforced append-only. Add a safe trigger and verify table/sequence privileges, including service_role and table-owner paths.
5. The foundation draft currently allows all active organisation members to read subscription summaries and audit events. Decide and enforce owner/billing-manager access rather than treating membership alone as billing authorization.
6. Add plan-version pinning, prior-trial policy, cancellation/rejection lifecycle and approval reason requirements.
7. Confirm all referenced columns and constraints against the final reviewed migration; these drafts are not a migration set.
8. Resolve migration history drift and create a staging baseline. Do not apply any of these drafts to production.
9. Run Supabase security/performance advisors and the complete security test matrix against isolated staging.
10. Complete legal/tax/payment-provider review before enabling paid subscriptions.

## Next implementation sequence
1. Finalise a versioned schema and immutable audit design.
2. Implement a dedicated Edge Function with request/list/approve/reject actions; no browser writes.
3. Add idempotency ledger enforcement and concurrency-safe database transitions.
4. Deploy only to isolated staging after migration-source reconciliation.
5. Execute all security matrix cases, including tenant isolation, non-AAL2, self-approval, replay, concurrent approvals and expiry.
6. Keep live checkout disabled until provider, tax, refund and billing lifecycle sign-off.

## Verification status
- Read-only production catalog inspection completed.
- Draft security revision committed to GitHub.
- No production DDL, migration repair, trial activation, payment or customer billing performed.
