# KRIM Organization, Membership, Invitation, Role Assignment and Revocation Lifecycle Audit
**Date:** 16 November 2026  
**Project:** Supabase `ebltviniygljwwseplph`; repository `rimjhimkrn-web/logistics-saas`  
**Method:** Read-only PostgreSQL function definitions, constraints, RLS policies, triggers, aggregate row counts and prior static onboarding/authentication findings. No membership, invitation, role, organization or account record was created, changed or revoked. No RPC was invoked.

## Executive decision
**NO-GO for general external organization/team onboarding and certified membership lifecycle.** KRIM has strong foundations for limited self-provisioning and a comparatively well-controlled driver invitation path. However, the generic organization invitation table has no verified create/accept/revoke API, membership audit only fires on INSERT, role authority is split across three models, and a driver organization provisioning gate trusts user-editable metadata.

## 1. Production baseline
| Resource | Rows |
|---|---:|
| Organizations | 14 |
| Organization memberships | 13 |
| Generic organization invitations | 0 |
| Organization onboarding records | 0 |
| Numeric RBAC role assignments | 17 |
| Legacy `user_roles` | 5 |
| Private driver invitations | 0 |
| Active memberships | 13 |

Organization distribution observed: 5 customer, 2 partner, 1 individual driver carrier, 1 customs, 1 enterprise, 1 finance, 1 operations, 1 platform and 1 warehouse organization. One of the two partner organizations has no membership. These are record counts, not evidence that organizations are fully verified or operationally activated.

Numeric RBAC assignments include 6 organization_owner, 2 partner_user, 2 customer_user, 2 platform_admin, 1 platform_superadmin, 1 operations_manager, 1 finance_manager and 1 compliance_manager. This coexists with free-text organization membership roles and 5 legacy `user_roles` rows.

## 2. Positive controls
- `krim_organization_members` is unique on (organization_id,user_id); member roles and statuses are constrained to known values.
- Organization membership and role assignment tables have authenticated self-read policies only in the inspected policy snapshot; no client INSERT/UPDATE/DELETE policy was present.
- Membership SELECT is scoped to the authenticated user's own rows. Organization SELECT is scoped to active membership, with an AAL2/platform permission exception.
- Customer/partner provisioning requires `auth.uid()`, validates legal-name length, takes a per-user advisory transaction lock and returns an existing active organization rather than creating duplicates.
- Partner self-provisioning creates pending verification/compliance/onboarding state and an open verification case. It does not mark partner verification, capability or compliance as approved.
- Driver invitation create requires `partner.manage`, a registered active verified compliant transport carrier, active verified transport capability, valid email, rate limit and a random 32-byte token stored only as SHA-256 hash in a private table.
- Driver invitation acceptance requires authenticated, email-confirmed user, matching invited email, valid/unexpired/unrevoked one-time token, still-eligible carrier and a non-development driver profile. It creates/updates a driver membership but leaves driver verification pending.
- Driver invitation revoke and list functions require `partner.manage`; list is bounded to 100 rows.
- Organization and membership insert triggers write audit events.

## 3. P0/P1 findings
### ORG-01 — P1: Generic organization invitations are not an operational workflow
`krim_organization_invitations` has fields for organization, email, role code, token hash, status, inviter and expiry, with a unique token hash and status constraint. Its RLS is organization-access SELECT only. No generic create, accept or revoke RPC was found in the reviewed callable-function inventory, and the table has zero rows.
**Impact:** a general customer/enterprise/warehouse/customs/finance/operations team invitation lifecycle is not evidenced. Driver-specific invitations do not solve general organization onboarding.
**Required:** define role allowlists, authorized inviter permissions, one-time random token hashing, email binding, expiry, revoke, acceptance with current account verification, atomic membership/role provisioning and immutable audit events. Do not let invitees select privileged roles or platform roles.

### ORG-02 — P1: Membership audit does not cover updates or revocations
Only an AFTER INSERT trigger exists on `krim_organization_members`. No UPDATE/DELETE audit trigger was found. A status change from active to inactive/suspended or a role change therefore has no equivalent trigger-backed audit event in this table.
The trigger records `entity_id = NEW.organization_id` rather than the membership row ID, which makes it harder to identify a specific membership change. It uses `auth.uid()`; 13 of 25 existing membership/organization audit events have a null actor.
**Required:** audit insert/update/delete or a controlled membership state-transition RPC; record membership row ID, organization, subject user, prior/new role/status, actor, reason, request/session context and timestamp. Define actor attribution for service-role jobs.

### ORG-03 — P1: Driver self-provisioning relies on user-editable user_metadata
`krim_provision_driver_organization()` checks `auth.uid()` and then permits provisioning only when `auth.users.raw_user_meta_data.krim_account_type = 'driver'`. Supabase user metadata is user-editable, so this is not a trustworthy authorization attribute. The function can create a driver-individual carrier organization and active driver membership.
**Impact:** a user may be able to self-create a driver organization by changing their own metadata and calling the exposed RPC. This does not by itself approve a licence or grant shipment access, but it bypasses intended account classification/onboarding and can create misleading driver identities.
**Required:** replace metadata gate with a trusted invitation, approved onboarding state or server-managed claim; keep profile/identity verification and assignment authorization independent. Test forged metadata in staging.

### ORG-04 — P1: Three role authorities coexist without proven precedence
The system has:
1. `krim_organization_members.role` (text, organization-scoped),
2. `krim_user_role_assignments` linked to `krim_security_roles` (numeric RBAC, organization nullable),
3. legacy `user_roles` (global text role).
The tables contain 13, 17 and 5 rows respectively. No canonical precedence/consistency contract was established by this audit.
**Required:** declare one authoritative organization-scoped role/permission model; define migration/compatibility mapping; prove legacy rows cannot elevate access or contradict current membership. Keep platform roles separate from tenant roles.

### ORG-05 — P1: Role assignment schema permits nullable organization scope
`krim_user_role_assignments.organization_id` is nullable, and the unique key includes that nullable column. PostgreSQL unique constraints permit multiple rows where a key component is NULL. This may be intentional for platform-global roles, but global-vs-tenant role semantics and duplicate prevention need explicit constraints/policy.
**Required:** separate platform-global assignments from organization-scoped assignments or enforce explicit scope invariants; verify no tenant role can be granted globally and vice versa.

### ORG-06 — P1: Organization status and partner lifecycle state are separate gates
Partner provisioning creates the organization with generic `status='active'` while partner lifecycle is `verification_pending`, verification/compliance pending and onboarding in progress. This is acceptable only if every operational action checks the partner-specific eligibility fields/capability. The partner/capacity/dispatch audits found such gates in reviewed critical paths, but complete enforcement across all partner actions remains unverified.
**Required:** keep partner operational eligibility derived from current verification, compliance, capability and active-market/corridor controls—not generic organization status alone. Make UI labels distinguish account created from approved/operational partner.

### ORG-07 — P2: Organization onboarding state table is empty and not fully connected
`krim_organization_onboarding` contains 0 rows and is readable by organization members. No generic organization onboarding workflow was proven to initialize/update it for customer/enterprise/customs/warehouse/finance/operations. Partner-specific state lives partly on organization fields and separate verification/capability tables.
**Required:** decide which org types need formal onboarding; connect a canonical state machine and auditable checklist where appropriate. Do not create fake onboarding rows to make dashboards look complete.

### ORG-08 — P2: Legacy driver invitation implementation remains
A one-argument legacy `krim_create_driver_invitation(email)` routine exists but is not executable by authenticated users in the inspected privilege snapshot. It uses an older public invitation path and does not match the private SHA-256 invitation table used by current acceptance. It is not a proven live bypass, but it is confusing dead/legacy surface.
**Required:** trace dependencies and retire it after migration reconciliation; ensure the old acceptance route cannot be revived accidentally.

## 4. Driver invitation workflow assurance
| Step | Observed control | Remaining test |
|---|---|---|
| Create | `partner.manage`, eligible carrier, verified transport capability, rate limit, 32-byte random token, SHA-256 hash, 7-day expiry | Wrong org, wrong role, rate limit, duplicate invite, token entropy |
| Accept | Authenticated, email confirmed, email match, one-time token, expiry/revocation, carrier recheck | Replay, race, concurrent accept/revoke, changed email, suspended carrier |
| Membership | Driver membership upserted; profile verification remains pending | Existing inactive membership role/status reactivation review |
| Revoke | Partner permission; only pending/unaccepted invitation | Concurrent accept/revoke and stale invite URL |
| List | Permission-scoped, bounded 100-row list | Cross-tenant and PII visibility |
| Audit | Create/accept/revoke events | Atomic audit failure, actor attribution, token never logged |

No invitation test was executed. No real driver invitation was sent.

## 5. Nine-workspace membership requirements
- Customer/Shipper: customer organization owner/admin/member roles; no customer account may self-assign enterprise or platform roles.
- Partner/Carrier: organization owner/admin/operator; partner approval remains independent from membership.
- Driver: carrier invitation or controlled individual-driver onboarding; verified driver identity and accepted assignment required for work.
- Warehouse: active member plus verified warehouse capability/facility and task permission; a partner membership alone is insufficient.
- Customs: licensed customs organization membership, jurisdiction scope and current licence; internal review is not government authority.
- Finance: finance membership and legal-entity binding; privileged actions AAL2 and finance remains deferred.
- Operations: operations organization membership and explicit operations permissions; not inferred from a generic active membership.
- Enterprise: enterprise membership plus explicit customer/network relationship for data access.
- Admin: separate platform identity/role, AAL2, least privilege, independent approval and durable audit.

## 6. Required staging acceptance tests
1. User-editable metadata cannot provision privileged or unapproved organization types.
2. Customer/partner provisioning is idempotent under concurrent requests and does not cross-link users.
3. Driver provisioning fails for forged metadata and succeeds only through approved onboarding.
4. Generic invitation cannot assign platform_admin, superadmin, finance approver or other prohibited role.
5. Invitation is bound to exact normalized email, organization and role; expired/revoked/replayed token fails.
6. Concurrent accept/revoke has exactly one valid outcome.
7. Revoked/suspended membership loses workspace and backend access, including stale sessions.
8. Role change is audited with prior/new values and correct actor.
9. Service-role membership changes have explicit actor attribution or controlled system identity.
10. Wrong-tenant inviter cannot create/list/revoke invitation.
11. Role models cannot conflict to elevate permissions.
12. Partner membership never implies verified capability, route access or dispatch authority.
13. Driver membership never implies licence verification, vehicle verification or assignment.
14. Organization suspension/closure revokes all affected user actions and active sessions according to policy.

None of these staging tests were run during this read-only audit.

## 7. Safe remediation sequence
1. Complete production/repository migration reconciliation before any DDL or grant changes.
2. Remove the user_metadata gate from driver provisioning and replace it with a trusted, explicit onboarding authorization path.
3. Specify canonical role authority and tenant/global scope.
4. Add auditable membership state transitions and correct audit subject identifiers.
5. Implement generic organization invitation lifecycle only after role allowlist, email delivery, consent and recovery are ready.
6. Connect formal onboarding state for org types that require it.
7. Retire legacy invite/role paths after proving no dependency.
8. Run isolated staging negative tests and nine-workspace regression suite.

## Release decision
**NO-GO for unrestricted external team onboarding and membership lifecycle certification.** Limited customer/partner self-provisioning and driver invitations have meaningful controls, but general team invites, full membership revocation audit, canonical role precedence and trusted driver provisioning need work.

## Change boundary
Read-only Supabase schema/function/policy/trigger/count inspection and repository/prior-audit context only. No production DDL/DML, membership/role/invitation changes, account changes, emails, invitations or provider actions were performed.
