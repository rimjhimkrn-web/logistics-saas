# KRIM User-Role and Workspace Journey — Live Readiness Audit
**Date:** 2026-11-16  
**Scope:** Read-only production inspection of role/permission catalogue, role mappings, user-role assignments, organisations, memberships, invitations, onboarding and role-specific workspace profile records.

## Executive result
KRIM has a defined RBAC catalogue (11 roles, 23 permissions, 155 role-permission mappings) and records representing all nine broad user categories. However, this is not evidence that each role has a complete, usable end-to-end workspace. Live activation and onboarding evidence is sparse: 9 auth users, 14 organisations, 13 organisation-membership rows, 17 active user-role assignments, and zero rows in the inspected invitation, organisation-onboarding, customer-workspace-profile, driver-profile and partner-onboarding-checklist tables.

## Live production snapshot
| Object | Rows |
|---|---:|
| Auth users | 9 |
| Organisations | 14 |
| Organisation memberships | 13 |
| Active user-role assignments | 17 |
| Security roles | 11 |
| Security permissions | 23 |
| Role-permission mappings | 155 |
| Network memberships | 0 |
| Organisation invitations | 0 |
| Organisation onboarding records | 0 |
| Customer workspace profiles | 0 |
| Driver profiles | 0 |
| Partner onboarding checklist rows | 0 |

All 14 organisation records currently have status `active`. Types represented: customer 5, partner 2, carrier/driver-individual 1, warehouse 1, customs 1, finance 1, operations 1, enterprise 1, platform 1. These are database labels, not independent proof of legal verification, operational capability, partner approval or workspace readiness.

## RBAC catalogue
The 11 role codes are:
- customer_user — 10 permission mappings
- partner_user — 11
- dispatcher — 9
- operations_manager — 15
- finance_manager — 7
- compliance_manager — 8
- organization_admin — 21
- organization_owner — 22
- viewer — 7
- platform_admin — 22
- platform_superadmin — 23

The role catalogue is a useful foundation. A permission mapping count does not establish that each permission is least-privilege, correctly scoped to the active organisation, consistently enforced across every RPC/page/API, or tested against cross-tenant access.

## Material gaps and risks
1. **Role catalogue is not the same as the nine user journeys.** The nine business personas are customer/shipper, partner/carrier, driver, warehouse, customs, finance, operations control tower, enterprise and admin. They need explicit workspace-to-role mapping, with clear distinctions between platform-admin roles and organisation roles. Avoid granting broad platform roles to ordinary organisation members.
2. **No onboarding evidence in inspected tables.** Zero organisation-onboarding, invitations, customer workspace profiles, driver profiles and partner onboarding checklist rows. Some legacy or alternate workflows may exist elsewhere; this snapshot does not prove none exist. It does show these canonical tables are not currently carrying operational onboarding evidence.
3. **Membership and role-assignment counts differ.** There are 13 organisation membership rows and 17 active rows in the separate user-role assignment table. The relationship between these systems, precedence rules, revocation propagation and stale assignment handling must be documented and tested. Do not assume one is authoritative without reviewing every relevant policy and RPC.
4. **Active organisation status is not activation clearance.** Partner lifecycle, identity, business, compliance and operating capability must remain separately gated. Customer, warehouse, customs and finance workspace status must also not imply regulatory or service readiness.
5. **No live workflow proof.** Counts do not establish successful invitation acceptance, MFA enforcement, email confirmation, consent ledger capture, role switching, organisation switching, permission denial, member offboarding, or audit logging for all role journeys. Earlier customer activation audit identified canonical customer accounts/workspace profiles/consent/activation records absent and a signup flow concern: org/member owner provisioning may occur before MFA, while checkbox consent is stored in user-editable metadata rather than a canonical consent ledger.
6. **Do not infer driver readiness from an organisation record.** The dedicated driver profile table is empty in this snapshot; prior dispatch readiness also found no verified driver evidence supporting real dispatch.
7. **Do not infer partner readiness from partner organisation records.** Earlier due-diligence audit found no verified operational partner, no accepted assignment and no confirmed capability/capacity.

## Required acceptance tests before launch
- Enumerate every page, route, RPC and storage object for each of the nine personas.
- Build a canonical matrix: persona → organisation type → role → permission → resource scope → MFA/AAL requirement → audit event.
- Test two-tenant isolation for every read/write, including object IDs supplied by a different organisation.
- Test role invitation, acceptance, expiry, duplicate acceptance, revocation, membership removal and token/session refresh.
- Test role changes and organisation switches invalidate stale permissions; ensure no user-editable metadata is trusted for authorization or consent.
- Verify platform-admin and superadmin are unavailable to ordinary tenant admins and require strong authentication.
- Test driver, warehouse, customs, finance and operations separation of duties, including maker-checker restrictions.
- Verify disabled/suspended organisations and members lose access immediately or within a documented bounded token-refresh window.
- Ensure every blocked journey gives a clear, safe next step without implying the user is verified or operationally active.

## Change-control boundary
This is a read-only production audit. No user, organisation, role, permission or onboarding records were changed. Production schema changes and permission repairs remain blocked pending full production schema/migration reconciliation. Do not replay/baseline migrations or broaden grants to make a workspace appear functional.

## Related reports
- `docs/audits/KRIM-CUSTOMER-REGISTRATION-ORGANISATION-ACTIVATION-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-PARTNER-WORKSPACE-CLAIMS-AND-FINANCE-GATING-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-PARTNER-OPERATIONAL-MODULES-AND-CLAIMS-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-AUTHENTICATED-PRIVILEGED-FUNCTION-JOURNEY-REVIEW-2026-11-16.md`

## Verification note
Snapshot taken from live Supabase production on 2026-11-16. Counts may change. This report is not a penetration test or evidence of successful user acceptance testing.
