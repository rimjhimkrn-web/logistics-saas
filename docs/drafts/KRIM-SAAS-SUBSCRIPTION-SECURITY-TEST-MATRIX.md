# KRIM SaaS Subscription Foundation — Security Test Matrix
Date: 11 November 2026
Applies to: `docs/drafts/KRIM-SAAS-SUBSCRIPTION-FOUNDATION-DRAFT.sql`
Execution status: test design only. These cases have NOT been executed against production.

## Release-blocking test cases

| ID | Scenario | Expected result |
|---|---|---|
| SAAS-001 | Anonymous user reads published public product/plan/features | Only published, public catalogue rows returned |
| SAAS-002 | Anonymous user reads subscriptions, entitlements or audit events | Denied |
| SAAS-003 | Authenticated member of Org A reads Org A subscription | Allowed read only |
| SAAS-004 | Authenticated member of Org A reads Org B subscription | Zero rows / denied |
| SAAS-005 | Org A member has membership revoked | Access immediately denied |
| SAAS-006 | Inactive organization membership | Access denied |
| SAAS-007 | Inactive organization | Access denied |
| SAAS-008 | Authenticated client inserts subscription | Permission denied |
| SAAS-009 | Authenticated client changes subscription status/trial end | Permission denied |
| SAAS-010 | Authenticated client inserts/updates entitlement | Permission denied |
| SAAS-011 | Authenticated client inserts audit event | Permission denied |
| SAAS-012 | Draft or retired plan queried from public catalogue | Not returned |
| SAAS-013 | Trial reaches exact expiry timestamp | Entitlement resolver returns no trial entitlement |
| SAAS-014 | Trial has expired but status still says trialing | Fail closed; no access |
| SAAS-015 | Two concurrent trial approval requests for same organization | At most one live subscription/trial |
| SAAS-016 | Second trial request after an expired/cancelled trial | Denied unless explicit policy permits and audited |
| SAAS-017 | Non-platform admin attempts trial approval | Denied |
| SAAS-018 | Platform admin without AAL2 attempts trial approval | Denied |
| SAAS-019 | Requester attempts to approve their own trial | Denied |
| SAAS-020 | Duplicate admin request / retry | Idempotent; no duplicate subscription or audit side effect |
| SAAS-021 | Direct browser redirect claims payment success | No entitlement change |
| SAAS-022 | Forged or duplicate provider webhook | Signature rejection or idempotent no-op |
| SAAS-023 | Provider event arrives out of order | Cannot downgrade a later confirmed state |
| SAAS-024 | SaaS subscription request tries to write freight payment tables | No cross-domain write path |
| SAAS-025 | User changes client-side organization_id to another tenant | Server derives/validates scope; no cross-tenant access |
| SAAS-026 | Audit row UPDATE or DELETE attempted by authenticated/service workflow | Denied; immutable audit history retained |
| SAAS-027 | Trial end timestamp is submitted by client | Ignored; server computes fixed duration using database time |
| SAAS-028 | Plan feature removed or plan retired while subscription exists | Existing entitlement behavior follows explicit versioned policy; no silent mutation |

## Test harness requirements
- Use an isolated Supabase staging project with representative Org A / Org B, owner, admin, finance and ordinary member accounts.
- Run as anon, authenticated and service-role contexts separately. Never paste service-role credentials into client-side tests.
- Test SQL grants and RLS independently: RLS does not compensate for an unsafe SECURITY DEFINER function or overly broad grants.
- Capture SQLSTATE / HTTP status, returned row counts, audit records and before/after snapshots.
- Include transaction rollback for database-only negative tests. Do not create test rows in production.
- Run concurrency tests with two independent database sessions.
- Verify no trial or entitlement is created by an unauthenticated request, browser redirect, unverified webhook or client-supplied timestamp.

## Outstanding design changes before implementation
1. Enforce audit immutability with database privileges and/or a trigger, including service-role pathway review.
2. Define whether subscription summaries are visible to every active organization member or only a billing administrator. Default recommendation: billing-only access.
3. Create a dedicated billing permission after reviewing existing role/permission seed conventions; do not reuse `finance.manage` without explicit approval.
4. Design an idempotent server-only trial approval operation, 30 calendar days from database timestamp, no automatic paid conversion, no payment method required.
5. Design entitlement resolution as a server-side function that checks active subscription status and effective period; no direct client-side trust.
6. Keep paid checkout disabled until legal/tax and payment provider eligibility are signed off.
