# KRIM Nine-Persona Role and Workspace Journey Readiness Audit
**Date:** 2026-11-16  
**Method:** Read-only production database counts, role-permission mapping inspection and repository page inventory. No user data was exported, no role changes were made, and no business RPCs were executed.

## Executive conclusion
KRIM has a broad workspace/page footprint and a central role-permission model, but the nine intended user journeys are not yet proven end-to-end. The database currently has 11 generic security roles, 23 permissions and 155 role-permission mappings. Only 17 active user-role assignment rows exist. Several role-specific onboarding/profile/invitation records are empty. A page existing in GitHub is not evidence that its route, authorization, data binding and task completion work in production.

## Live role and permission snapshot
| Metric | Count |
|---|---:|
| Security roles | 11 |
| Security permissions | 23 |
| Role-permission mapping rows | 155 |
| Active user-role assignments | 17 |
| Network memberships | 0 |
| Organization invitations | 0 |
| Organization onboarding records | 0 |
| Customer workspace profiles | 0 |
| Driver profiles | 0 |
| Partner onboarding checklist rows | 0 |

### Role allocation
| Role | Granted permission mappings | Active assignments |
|---|---:|---:|
| Compliance Manager | 8 | 1 |
| Customer User | 10 | 2 |
| Dispatcher | 9 | 0 |
| Finance Manager | 7 | 1 |
| Operations Manager | 15 | 1 |
| Organization Admin | 21 | 1 |
| Organization Owner | 22 | 6 |
| Partner User | 11 | 2 |
| Platform Admin | 22 | 2 |
| Platform Super Admin | 23 | 1 |
| Viewer | 7 | 0 |

Counts describe configured mappings and assignments, not proof that every permission is safe, least-privilege, fresh or correctly enforced across all routes and RPCs. The privileged-role and function reviews remain necessary.

## Nine intended personas — journey status
| Persona | Repository workspace evidence | Live journey evidence | Assessment |
|---|---|---|---|
| Customer / Shipper | Customer workspace and customs-document pages | 5 customer orgs historically, but 0 canonical customer accounts, 0 customer workspace profiles, 0 onboarding and 0 consent-ledger rows | Incomplete activation |
| Partner / Carrier | Partner business, carrier, forwarder, multimodal, first/last-mile, individual and development workspaces | No verified operational partner; partner capability and verification evidence remain sparse; 0 onboarding checklist rows | Not operationally activated |
| Driver | Driver portal and 17 module pages | 0 driver profiles; earlier audit found no accepted driver assignments or dispatch | Not activated |
| Warehouse | Warehouse portal, allocation and reverse-logistics pages | 0 facilities, inventory rows, allocations, tasks and transfers | Not operationally activated |
| Customs | Customs workspace and customer customs-document pages | 0 customs cases, broker licences, assignments and document submissions | Not operationally activated |
| Finance | Finance workspace, invoicing, receivables, payables, refunds and settlements pages | Finance data is present structurally, but referral/commission proof and settlement populations remain empty; sensitive writer paths require reconciliation and review | Restricted / not commercially proven |
| Operations Control Tower | Admin/control-centre and operations coordination pages | No dispatches, assignments or orchestration runs in prior live snapshot; no evidence of a completed control-tower journey | Not proven |
| Enterprise | Enterprise dashboard, shipments, finance, integrations, analytics and governance pages | 1 enterprise organization historically, but 0 canonical workspace profiles and no invitation/onboarding rows | Incomplete activation |
| Admin | Admin and platform-admin workspaces | 11 roles and privileged functions exist; several AAL2/admin gates are documented, but broad SECURITY DEFINER and direct-write findings remain under review | Exists, high-risk review required |

## Key findings and risks
1. **Workspace breadth exceeds operational proof.** Numerous persona-specific HTML pages exist, but live data does not show a completed journey for most personas. Treat these as interface surfaces, not operational capabilities.
2. **Identity and activation are fragmented.** The prior customer registration audit recorded auth users and organizations but zero canonical customer accounts, customer workspace profiles, identity links, consent rows, activation checks, onboarding rows and invitations. This audit reconfirms the workspace-profile/onboarding/invitation gaps.
3. **No invitations or network memberships.** Partner/customer/enterprise teams cannot be assumed to have a proven invite-acceptance and membership lifecycle from zero live invitation and network-membership records.
4. **Driver and warehouse are unpopulated.** Zero driver profiles and zero warehouse facilities/inventory/tasks/allocations means these roles cannot yet complete genuine operating work.
5. **Customs journey is not active.** Customs tables and controlled workflow functions exist, but the live operational population is zero. Country/corridor activation controls are blocked.
6. **Finance needs a deliberate launch boundary.** Keep customer freight payment collection, partner payouts, settlements, escrow/custody and automatic freight-margin recognition disabled. Initial referral/coordination revenue must be separately contracted and evidenced; shipment GMV is not KRIM revenue.
7. **Role-to-persona mapping is not one-to-one.** The current 11-role taxonomy does not explicitly provide a dedicated role code for each of the nine personas. A single persona may require scoped organization roles and membership; do not create broad new roles merely to match page labels.
8. **Role mapping counts are not authorization tests.** Validate route guards, RPC authorization, RLS, AAL2, organization boundaries, actor separation, invitation expiry/replay, role revocation and token freshness in staging with separate test identities.
9. **Admin privilege surface remains a blocker.** Prior review found 332 SECURITY DEFINER functions and 150 authenticated-callable functions; 8 authenticated-callable functions place public first in search_path. These are a review queue, not proof of exploitability, but require full function-body and authorization review.

## Required completion sequence
1. Establish canonical identity, organization membership, consent and activation state; reconcile the existing signup callback and generic registration paths.
2. Define a documented persona-to-role/permission matrix for the nine personas, including organization scoping and separation of duties.
3. Stage-test invitation creation, expiry, replay, acceptance, revocation and role change with distinct users and organizations.
4. Test each workspace's route guard and every write action against both allowed and denied roles; verify RLS and function-level authorization.
5. Activate one real partner and one real customer only after due diligence, contracts, service area, compliance and capacity are verified.
6. Populate driver, warehouse and customs journeys only when the real service is being offered and its prerequisites are approved.
7. Keep finance features limited to contracted KRIM service fees until tax, provider and legal reviews permit additional functionality.
8. Run complete persona-based staging journeys with screenshots/log evidence, then controlled production smoke checks that do not create real bookings or financial postings.

## Related audit reports
- `docs/audits/KRIM-CUSTOMER-REGISTRATION-ORGANISATION-ACTIVATION-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-FOUNDER-ADMIN-ACQUISITION-WORKSPACE-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-PARTNER-WORKSPACE-CLAIMS-AND-FINANCE-GATING-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-PARTNER-OPERATIONAL-MODULES-AND-CLAIMS-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-GLOBAL-COMPLIANCE-COUNTRY-ACTIVATION-CUSTOMS-AND-CORRIDOR-CONTROLS-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-AUTHENTICATED-PRIVILEGED-FUNCTION-JOURNEY-REVIEW-2026-11-16.md`

## Change-control boundary
Production DDL, grants, policy changes, role reassignment, trigger changes and migration replay remain prohibited until the full production schema/migration reconciliation is complete. All authorization corrections and end-to-end persona tests must first be prepared and validated in staging. No external partner/customer outreach or account changes were performed.
