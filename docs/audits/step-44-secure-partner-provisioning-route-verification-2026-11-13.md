# Step 44 — Secure partner provisioning route verification

Date: 2026-11-13
Branch: website/global-launch-readiness
Scope: read-only inspection of the current partner onboarding and platform-admin control plane to identify a safe first-partner provisioning route.

## Result: no verified end-to-end provisioning action found

The inspected partner onboarding path and platform-admin control plane do not provide a verified safe action that creates a partner organisation and links the applicant as an active organisation member.

### Evidence

1. `public/partner/partner-onboarding.html` is an application/onboarding interface; prior workflow audit established that the partner verification process expects an existing active organisation linked to the signed-in account. A signup/login is not proof of organisation creation or membership.
2. `app/platform-admin/partner-verification.html` is a review queue for already-created organisation verification cases. It records identity-verification decisions; it is not an organisation provisioning form.
3. `app/platform-admin/partner-compliance.html`, `partner-capabilities.html`, and `partner-service-areas.html` review separate compliance, capability and service-area submissions for existing organisations. They do not create the organisation/member relationship.
4. `supabase/functions/global-admin-control/index.ts` exposes an `organizations` action that lists existing organisations. Its `assign_role` action inserts/updates `krim_user_role_assignments`; it does not create a `krim_organizations` row or an `krim_organization_members` row. Assigning a platform/security role is not a substitute for an organisation membership and must not be used to simulate one.
5. The control-plane Edge Function is MFA-gated and platform-admin-gated, but that alone does not make an unrelated role-assignment action a valid partner provisioning workflow.

## Safe decision

Do not provision a partner by direct production SQL, by assigning a broad platform role, by editing membership tables manually, or by reusing customer signup. Do not create placeholder organisations or fake partner evidence.

The current safe route is **founder/admin-assisted but only through a purpose-built, audited provisioning workflow** after its database invariants and authorization model have been reviewed. The workflow must, at minimum:

- Require a confirmed existing Auth user and verified applicant identity/contact.
- Require a registered-business application for commercial partner status; individual-interest and development-test pathways must remain non-commercial.
- Create the partner organisation and its initial membership atomically, with explicit member role, active/inactive state and audit event.
- Enforce platform-admin + AAL2 authorization server-side; prevent self-approval and unauthorized cross-tenant membership changes.
- Start with identity verification pending, compliance pending, no approved capability, no approved service area and no commercial activation.
- Keep identity, compliance, capability, service-area and final commercial activation as separate reviewer-controlled gates.
- Be idempotent, reject duplicate organisation/user links, validate country and organisation type, and log request/reviewer/reason.
- Include negative tests for non-admin, non-AAL2, wrong tenant, duplicate request, self-approval and invalid account mode.

## Why implementation is not being pushed into production now

Production has 425 applied migrations, staging has zero, and repository migration history is materially unreconciled (Step 36). A new production table/function migration or service-role Edge Function change without a trustworthy non-production validation path would add avoidable risk. The existing `global-admin-control` function is a broad privileged control plane; adding partner creation there without a separately reviewed narrow action and tests is not safe.

## Next implementation prerequisite

Recover/verify canonical migration history or approve a separately designed disposable non-production baseline. Then implement a narrowly scoped partner-provisioning RPC/Edge Function and a small admin screen; test authorization, atomicity, audit trail and lifecycle defaults before any production rollout.

## Verdict

**BLOCKED — no existing safe partner organisation + membership provisioning action verified.** This is the immediate operational blocker to onboarding the first commercial partner. No production records, schema, functions, secrets, roles, memberships, partner approvals, merge or deployment were changed.
