# C3.52 — Global organization provisioning, onboarding, invitation, membership activation, suspension and revocation lifecycle
**Date:** 25 November 2026  
**Immutable source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**Method:** Read-only inspection of customer/partner provisioning migrations, customer/partner onboarding pages, organization invitation/acceptance/switch pages, driver invitation migrations, account-deactivation route, and dated 16–17 November organization lifecycle and onboarding audits. Historical production row counts are explicitly point-in-time snapshots. No RPC, invitation, signup, organization, membership, role, suspension, revocation, account-deactivation, file upload or production operation was executed.

## Executive verdict
**FAIL / BLOCKED — NO-GO for general external organization/team onboarding or a certified end-to-end membership lifecycle.**

KRIM has useful controlled provisioning primitives for customer and partner organizations and a materially stronger carrier-to-driver invitation path. But the organization lifecycle is fragmented: customer provisioning can create an active tenant before a full customer onboarding/verification journey; partner provisioning creates pending review state but subsequent evidence and capability stages are separate; there is no verified generic organization invitation workflow; membership role/status changes and revocation are not fully audited or coordinated with sessions; and no completed organization onboarding journey is evidenced. Driver invitations are a specific exception and must not be represented as generic team invitations.

## 1. Lifecycle coverage matrix — source and dated evidence
| Lifecycle stage | Observed implementation | Verdict |
|---|---|---|
| Customer organization provisioning | `krim_provision_customer_organization` authenticates with `auth.uid()`, validates legal name, serializes per-user creation, creates customer org + owner membership + owner role assignment + audit event transactionally. It reuses the user's first active customer/enterprise membership. | PARTIAL PASS; customer-facing onboarding and identity/commercial activation remain incomplete. |
| Partner organization provisioning | Authenticated RPC validates legal name, serializes per-user provisioning, rejects multiple active partner organizations, creates owner/partner role assignments and a pending verification case/audit event. | PARTIAL PASS; pending registration is not verification, compliance or commercial activation. |
| Partner account mode | Separate RPC sets development-test, individual-interest or registered-business mode for exactly one active partner org; commercial access remains false for non-commercial modes. | PARTIAL PASS; all mode transitions and direct action bypasses need staged verification. |
| Partner evidence and verification | Onboarding routine checks private-bucket object existence and path identity, then submits verification case and pending capability evidence; reviewer path has separate ownership/approval controls. | PARTIAL PASS; submission owner binding and cross-tenant substitution require explicit proof. |
| Generic organization/team invitation | Generic invitation table exists, but dated audit found no operational create/accept/revoke RPC lifecycle and zero invitation records. | FAIL / NOT EVIDENCED. |
| Carrier-to-driver invitation | Dedicated workflow validates eligible verified/compliant carrier, uses high-entropy token hash, expiry, confirmed email, rechecks carrier eligibility, rate-limits inviter and leaves driver verification pending. | PARTIAL PASS; not a general organization invite. |
| Membership role/status update | Core tables restrict direct authenticated DML and rely on controlled privileged paths; no complete role-change/suspend/revoke audit lifecycle was evidenced. | FAIL / BLOCKED. |
| Membership suspension/revocation and session invalidation | No complete atomic workflow proving role/membership revocation, active session coordination and immediate protected-resource denial. | NOT TESTED / BLOCKED. |
| Customer onboarding | Canonical customer onboarding page is guidance rather than a full organization/profile/team/consent/verification workflow. | FAIL for completed customer onboarding journey. |
| Organization/account deactivation | Secure account-action page scaffold exists, but no completed organization closure, membership removal, data ownership transfer, retention and session-revocation journey was proven. | NOT TESTED. |

## 2. P0 — No complete, proven lifecycle from organization creation through revocation
The baseline contains separate provisioning, verification, capability, membership, invitation and account-action pieces. There is no exhaustive state machine or tested transaction boundary proving the full sequence:
`requested → identity confirmed → organization provisioned → owner membership/role assigned → terms/consent recorded → evidence submitted → verification/compliance reviewed → capabilities approved → activated → members invited → roles changed → suspended/reinstated → revoked/closed`.

No complete event history, actor attribution, idempotency, rollback/reconciliation or downstream session invalidation evidence covers every transition. A successful organization provisioning RPC is not proof that the organization is ready to transact or receive freight. An active customer organization status is not equivalent to completed KYC/contract/consent. A partner verification case in pending state is not a verified carrier or proof of any active route, capacity or service.

**Required:** define canonical organization lifecycle states and allowed transitions; enforce them server-side with atomic guarded RPCs, immutable before/after audit records, actor/correlation IDs, idempotency and explicit recovery from partial failure. Separate identity, legal entity, membership, role, verification, compliance, capability, service area, capacity and commercial activation.

## 3. P1 — Customer provisioning can create active organization before customer onboarding is complete
`krim_provision_customer_organization` creates an organization with `status='active'`, owner membership and owner role assignment in one transaction. It returns the first active customer or enterprise organization membership if one exists. The canonical customer onboarding page is a workflow guide, not a complete profile, billing/contact, team, consent, verification or support handoff.

**Risks to resolve:** active organization status may be misread as business/customer verification; reuse of an existing enterprise membership must not silently attach the user to an unintended tenant/type; there is no demonstrated idempotent resume state for partial signup after Auth account creation.

**Required:** use explicit states such as registered/pending-profile/active or verified where applicable; do not use generic active as a commercial trust badge. Confirm organization type and explicit user selection before reusing a tenant. Add safe resume/reconciliation after Auth signup/provisioning partial failure and complete customer profile/consent setup before commercial actions.

## 4. P1 — Partner provisioning is multi-step and pending-state integrity must remain explicit
Partner signup performs Auth signup, organization provisioning and account-mode selection as separate network operations. If one step fails after Auth signup, an Auth identity can remain without completed organization/pathway setup. The UI advises sign-in and retry, but a complete recovery/reconciliation workflow was not proven.

Positive controls in the provisioning migration:
- Authenticated actor from `auth.uid()`; validated legal name; advisory lock per user.
- Rejects multiple active partner organizations; reuses one supported active partner organization.
- Creates owner and partner role assignments, pending verification case and audit event.
- Account-mode routine limits changes to exactly one active partner organization, records mode and audit, and does not grant commercial access for development-test/individual-interest.
- Verification submission requires private evidence objects and a business packet; capability rows are pending/inactive until independent review.

**P1 evidence ownership gap:** the reviewed global v2 onboarding function checks object existence and path strings containing the user/organization IDs, but does not itself explicitly compare Storage object owner metadata to the authenticated user. The reviewer path has separate ownership checks; do not assume submission-time ownership is proven. Staging must test forged paths, wrong owner, other tenant's object, duplicate packet and conflicting legal entity.

**Required:** resumable idempotent onboarding with a visible per-stage state and correlation ID; no duplicate Auth identities; server-side ownership and tenant binding for every object; separate verification/compliance/capability/service-area/capacity/contract activation gates.

## 5. P1 — Generic organization invitation lifecycle is missing
The generic `krim_organization_invitations` table has fields for organization, email, role code, token hash, status, inviter, expiry and acceptance timestamp, and organization-scoped read controls. The dated 16 November audits found zero generic invitations and no callable generic create/accept/revoke RPC lifecycle. A generic acceptance page/form exists, but its presence is not evidence of a working server endpoint or atomic membership provisioning.

The dedicated driver invitation workflow is not a substitute. The older one-argument driver invitation overload and legacy token storage/hash path differ from the newer private driver-invitation workflow; the dated audit says the legacy overload was not executable by authenticated users in its grant snapshot. Do not re-enable or mix these paths.

**Required:** implement generic invitation create/list/revoke/accept with:
- authorized inviter and exact organization scope;
- allowlisted tenant roles (never platform-global/admin roles);
- cryptographically random single-use token stored only as a strong hash;
- exact confirmed-email binding, expiry, revocation and replay resistance;
- active organization and role eligibility recheck at acceptance;
- atomic membership + role assignment + invitation consumption + audit event;
- idempotent retry and concurrency locking;
- invitation delivery status and redacted event trail;
- explicit denial for suspended organization, inviter or role.

## 6. P1 — Membership audit and revocation/session coordination incomplete
The dated membership audit found an AFTER INSERT membership audit trigger but no equivalent full UPDATE/DELETE lifecycle coverage for role change, suspension, reactivation or removal. If service-role provisioning has no authenticated JWT context, an INSERT audit event can have a null actor unless the initiating actor is passed and validated separately. RLS self-read and no direct authenticated DML are positive controls, but do not prove immediate revocation from existing sessions or caches.

**Required:** immutable before/after membership and role events with actor, reason, request ID, timestamp and target tenant; atomic authorization invalidation; revoke sessions or ensure protected backend operations validate current membership on each call; define owner-transfer and last-owner protections; notify affected organization/security contacts without leaking data. Test stale JWTs and existing browser tabs after suspension/revocation.

## 7. P1 — Driver invitation is strong but narrowly scoped
The private driver invitation flow uses a 32-byte token, SHA-256 token hash, seven-day expiry, confirmed-email binding, one-time acceptance, invitation revocation, carrier eligibility recheck, inviter permission/rate limit and audit event. Acceptance creates a driver membership/profile with verification pending and blocks development/test profiles from commercial carrier operations.

This is a useful PARTIAL PASS for carrier-to-driver onboarding only. The older public-table driver invite overload uses MD5 and a different table/hash scheme; its dated grant state made it unavailable to authenticated callers. Keep it retired after dependency and migration reconciliation. Acceptance must continue to require driver profile verification and exact assignment/dispatch checks before operational work.

## 8. Dated production evidence — not current live state
A 16 November read-only production snapshot recorded 14 organizations, 13 active memberships, zero generic organization invitations, zero organization onboarding records, zero network memberships, 17 numeric role assignments, five legacy `user_roles`, one pending/inactive partner capability, one partner verification case, zero compliance evidence/reviews, zero partner onboarding checklists, zero service areas and zero capacity commitments. These historical counts show the lack of demonstrated completed onboarding at that snapshot; they are not current counts and were not re-queried in this gate.

## 9. Remediation and acceptance criteria
### P0 before lifecycle certification
1. Define and implement a canonical organization lifecycle/state-transition graph.
2. Prove each state transition is server-side, tenant-bound, permission-checked, atomic, idempotent and audited.
3. Prove revocation/suspension immediately denies protected backend operations and coordinates existing sessions/tokens.
4. Reconcile partial Auth signup/provisioning failure without duplicate accounts or orphaned active organizations.

### P1 before real external onboarding
1. Complete customer profile, consent, support and verification workflow; clarify active-vs-verified semantics.
2. Add partner onboarding resume/reconciliation and explicit evidence object ownership validation.
3. Implement generic organization/team invitations for customer, partner, warehouse, customs, finance, operations and enterprise roles.
4. Add membership role-change/suspension/revocation/owner-transfer audit and last-owner safeguards.
5. Enforce organization verification, compliance, capability, service-area, capacity and contract gates at every commercial action.
6. Retire legacy invitation/token paths after dependency/grant reconciliation.

### Mandatory isolated-Staging tests — NOT EXECUTED
- Signup success and failure after Auth creation, after organization provisioning, after role assignment, after account-mode update and during evidence submission; retry must resume idempotently.
- Customer first signup, existing customer reuse, enterprise reuse, ambiguous multiple memberships and organization-type mismatch.
- Partner registered-business, individual-interest and development-test modes; direct RPC/URL bypass of commercial operations.
- Evidence upload path spoofing, wrong owner, other-tenant object, duplicate document, replaced object and reviewer approval.
- Generic invitation valid/wrong email/unconfirmed email/expired/revoked/replayed/parallel acceptance/wrong org/wrong role/suspended inviter/suspended org.
- Role update, owner transfer, last-owner removal, member suspension/reactivation/removal and audit actor attribution.
- Stale access token, refresh token, open tab, cached workspace and background job after membership revocation.
- Driver invitation eligible/ineligible carrier, rate limit, wrong email, token replay, revocation, pending profile verification and attempted dispatch before approval.
- Organization closure, data ownership transfer, retention, export/deletion coordination and session invalidation.

## Final decision
**C3.52 FAIL / BLOCKED.** NO-GO for general external organization/team onboarding or a certified membership activation/suspension/revocation lifecycle. Customer and partner provisioning primitives and the dedicated driver invitation flow are useful foundations, but full onboarding journeys, generic team invitations, lifecycle state enforcement, complete audit history and session-coordinated revocation remain unproven.

This was a read-only immutable-baseline and dated-evidence audit. No live Auth signup, RPC, invitation, membership, role, organization, account action, Storage upload, database mutation, provider delivery or deployment occurred. Historical production counts are not current-state claims. This is not a compliance certification.
