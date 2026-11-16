# KRIM Organization Onboarding, Invitations, Membership Lifecycle and Role Provisioning Audit
**Date:** 16 November 2026  
**Scope:** Read-only production review of organization invitation/onboarding/membership/role data, RLS policies and table grants, selected invitation and partner-onboarding function definitions, and available audit triggers. No invitation was issued or accepted, no member/role was changed, no onboarding submission was made, no evidence was uploaded, and no production RPC was invoked.

## Executive decision
**NO-GO for broad external organization onboarding and self-service team administration.** The database contains 14 organizations and 13 active organization memberships, but zero generic organization invitations, zero organization onboarding records, zero network memberships and zero partner onboarding checklists. The available invitation implementation is specifically for carrier drivers; a complete organization-level invitation and approval lifecycle for customers, partners, warehouses, customs brokers, finance, enterprise and operations is not evidenced.

The authorization baseline is comparatively restrictive: organization membership, user-role assignment, legacy role and permission tables expose authenticated SELECT only, with self-scoped membership/role reads or platform-admin permission reads. No direct authenticated INSERT/UPDATE/DELETE grants were found on the reviewed core membership and role tables. That is positive, but the actual organization onboarding and membership workflows still need staged proof and a canonical role model.

## 1. Production record baseline
| Object | Rows |
|---|---:|
| Organizations | 14 |
| Organization memberships | 13 |
| Organization invitations (generic table) | 0 |
| Organization onboarding records | 0 |
| Network memberships | 0 |
| User role assignments | 17 |
| Legacy user roles | 5 |
| Role-permission mappings | 155 |
| Security permission definitions | 23 |
| Partner onboarding checklists | 0 |

All 13 organization membership rows are active. All 17 user-role assignments are organization-scoped (none global). The five legacy user-role rows include 2 customer, 2 admin and 1 partner role. The legacy role table is therefore still populated alongside the organization membership and role-assignment systems; the exact precedence and compatibility behavior must remain explicit and tested.

There are no invitation, onboarding or network-membership rows from which to verify an actual external organization joining KRIM, completing its verification, receiving a role, and later having access revoked.

## 2. Core membership and role data protection
Positive controls:
- `krim_organization_members` RLS allows authenticated users to read only their own membership rows.
- `krim_user_role_assignments` and legacy `user_roles` are self-read scoped.
- `krim_organization_invitations`, `krim_organization_onboarding` and `krim_network_memberships` are readable only through organization access policies.
- `krim_role_permissions` and `krim_security_permissions` are readable only to a user with `admin.platform` permission in platform organization 1.
- The reviewed core tables grant authenticated SELECT but no direct authenticated INSERT, UPDATE or DELETE. Mutations are expected to pass through privileged RPCs or controlled service paths.
- An AFTER INSERT trigger on organization membership calls `krim_log_organization_membership` to create an audit event.

Limitations:
- The membership audit trigger records `auth.uid()` as actor. If membership is inserted through a service-role process with no authenticated JWT context, the audit actor may be null; service-driven membership provisioning should carry an explicit, validated initiating actor and request/correlation ID.
- The trigger covers INSERT only; no equivalent membership role-change, suspension, revocation or removal audit trigger was found on the membership table.
- RLS self-read does not prove correct role-to-permission resolution or that a revoked user loses access immediately from active sessions/cached UI.

## 3. Driver invitation lifecycle
The current supported driver invite path has meaningful safeguards:
- The two-argument `krim_create_driver_invitation(organization_id,email)` requires authentication and `partner.manage` for the exact organization.
- It verifies the organization is active, registered-business, verified, active in partner lifecycle, compliant, and has an active verified transport capability.
- It validates the email, rejects an already-active driver, revokes earlier unaccepted invitations for the same email, and limits the inviter to ten invitations per hour.
- It generates a 32-byte random token, stores a SHA-256 token hash in the private driver-invitation table, and returns a seven-day invitation URL.
- Acceptance requires a confirmed auth email matching the invited email, a valid unexpired unrevoked unused token, and rechecks carrier eligibility.
- Acceptance creates/activates a driver organization membership and a pending driver profile; it does not auto-verify the driver.
- It blocks development/test driver profiles from joining commercial operations.
- Invitation listing and revocation require `partner.manage` in the exact organization; acceptance and revocation write audit events.

**Important scope limitation:** this is a carrier-to-driver invitation, not a generic organization/team invitation. There is no evidence here of a complete customer team, enterprise subsidiary, warehouse operator, customs broker, finance user or admin invitation lifecycle.

### Legacy overload mismatch (contained but requires cleanup)
A one-argument overload `krim_create_driver_invitation(email)` writes a token hash to the public `krim_organization_invitations` table using MD5, while `krim_accept_driver_invitation(token)` looks up the private driver-invitation table using SHA-256. The one-argument overload is not executable by authenticated users in the current grant snapshot, so this is not established as a live callable bypass; it is a legacy dead path with incompatible storage/hash behavior. Remove or retire it only after migration reconciliation and dependency review. Do not re-enable it.

## 4. Partner onboarding lifecycle
The current global v2 partner onboarding routine:
- Requires authentication, validated legal name, incorporation and operating country codes, authority ID, supported operational category, registered address/city and bounded optional location/website fields.
- Requires one or two registration/insurance evidence paths under the caller's organization/user folder, and requires the storage objects to exist in the private partner-verification bucket.
- Requires an active membership in a registered-business partner organization.
- Uses an advisory transaction lock to serialize onboarding for the caller.
- Changes organization lifecycle/verification/compliance to pending, records submitted business metadata, creates or updates a partner verification case and writes an audit event.
- The multi-category v1 wrapper validates unique categories and category coverage, requires active catalogue countries, and creates capability rows as pending/inactive pending independent review.

**P1 evidence ownership assurance gap:** v2 checks that each storage object exists in the private bucket and that its path text contains the caller's user ID, but the inspected function does not explicitly compare the storage object's owner/owner_id to `auth.uid()`. Folder-path matching and bucket privacy are useful controls but are not a substitute for verifying object ownership. The partner verification storage policy and object owner metadata must be inspected and tested before accepting real evidence. This audit does not establish that another user can exploit the gap; it is a control gap requiring verification.

**P1 organization identity binding:** v2 derives the target organization ID from the first path segment and checks active membership and registered-business mode. Staging must prove that every submitted document belongs to that same organization, is owned by the submitting user, and cannot be substituted from another tenant. It should also reject conflicting legal-entity submissions and enforce one canonical active verification case per organization.

## 5. Generic organization invitation and onboarding gap
The generic `krim_organization_invitations` table stores organization, email, role code, token hash, status, inviter, expiry and acceptance timestamp. However:
- It has zero rows.
- No generic create/accept/revoke organization invitation RPC was found in the reviewed public function inventory.
- The public table has authenticated SELECT through organization-access RLS, but no authenticated DML grant.
- The supported driver invitation path has moved to a private driver-specific invitation table and does not use the generic table for the currently granted two-argument flow.
- `krim_organization_onboarding` has zero rows and a scoped read policy, but no active organization onboarding workflow was evidenced in the reviewed functions.
- `krim_network_memberships` has zero rows and a scoped read policy; network affiliation, cross-organization authority and enterprise relationship consent are not live.

**Conclusion:** the database has data structures for generic onboarding and invitations, but a complete, usable and verified generic lifecycle is not established. Avoid showing a customer-facing "invite team" or "join network" capability as live until its server-side workflow, identity proofing, email delivery, expiry, revocation, audit and role restrictions are complete.

## 6. Role and permission model consistency
- Organization memberships contain a free-text role field; user-role assignments use numeric role IDs; legacy `user_roles` uses text roles; and role-permission mappings bind role IDs to permission IDs.
- There are 17 organization-scoped role assignments and 5 legacy roles, but the reviewed snapshot did not establish a single canonical role registry or prove that every role source is reconciled.
- The nine workspace roles need an explicit mapping to the canonical organization type, membership role, role assignment, permission set and workspace route. The UI must not infer authority from a local role label or user metadata.
- All permission checks for sensitive actions must be server-side, organization-scoped, current-membership-aware and AAL2 where appropriate.
- Admin role changes should remain separate from ordinary organization membership changes and require independent high-privilege authorization, reason, durable audit and immediate revocation semantics.

## 7. Required staging-only verification
1. Generic invitation: create, email match, confirmed email, expiry, revoke, reuse, duplicate, wrong organization, invalid role code, role escalation and resend rate limit.
2. Driver invitation: token entropy, hash format, email mismatch, unconfirmed email, revoked/expired/reused token, concurrent acceptance, duplicate active driver, carrier compliance revoked between invite and accept, capability revoked, and membership audit.
3. Organization creation/onboarding: duplicate legal identity, wrong organization type, unsupported country, evidence missing, evidence owned by another user, path spoofing, cross-tenant document, expired document, resubmission and independent review.
4. Membership lifecycle: add, role change, suspend, revoke, rejoin, remove, organization deactivation, active session, cached UI, service-role provisioning and audit actor attribution.
5. Role consistency: test all nine workspaces against canonical role assignment, legacy role compatibility, direct table grants, RPC permissions, AAL1/AAL2 and revoked roles.
6. Enterprise/network: explicit organization relationship approval, scope, effective dates, revocation, subsidiary access and no implicit access to linked organizations.
7. Invitation delivery: queued, provider accepted, delivered/bounced, retry, duplicate send, link redaction from logs and secure token storage.
8. Evidence: private bucket policy, owner_id, user folder, organization folder, MIME/size, signed URL expiry, revocation and retention/deletion.
9. Concurrency: two simultaneous accepts, simultaneous role revocation/action, invitation resend and duplicate onboarding submissions.
10. Negative tests: anonymous, wrong tenant, unconfirmed email, inactive organization, unverified partner, missing permission, wrong workspace role and stale AAL.

## 8. Remediation and release order
1. Define and document one canonical role/membership/permission authority and migration plan for legacy roles.
2. Build a generic organization invitation lifecycle with secure token hashing, email binding, expiry, revocation, one-time acceptance, role allowlist and immutable audit.
3. Implement organization onboarding stages with evidence ownership/tenant validation and independent review; never auto-activate a partner from submitted data.
4. Add audited membership role-change/suspension/revocation events and ensure service-created records preserve actor/request provenance.
5. Verify storage owner_id and exact organization/user binding for partner evidence.
6. Retire incompatible legacy invitation overloads only after migration reconciliation.
7. Run all nine-workspace staging access and invitation lifecycle tests before opening external registration.

## 9. Change control and release gate
Read-only audit only. No production invitation, onboarding submission, membership, role or permission was created or changed. No email or notification was sent. No schema, RLS policy, function or storage policy was modified. Financial collection remains deferred to the final phase.

Production migration reconciliation remains unresolved. Do not implement production schema/function/policy changes or retire legacy RPCs until the production/repository migration crosswalk and sanitized schema manifest are reconciled.

**Release status: NO-GO for broad self-service organization onboarding, team invitations, network federation or enterprise membership provisioning.** Core self-read and organization-scoped authorization controls are present, and the driver invite path is substantially guarded, but generic organization lifecycle workflows are not evidenced and partner evidence ownership needs further verification.
