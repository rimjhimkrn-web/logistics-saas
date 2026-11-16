# KRIM Global Operations Control Tower, Enterprise Access and Platform Governance Audit
**Date:** 16 November 2026  
**Scope:** Read-only production data counts, organization/relationship/role policies, selected operations RPC definitions and deployed source review of Operations, Enterprise and Platform Admin workspaces. No shipment, organization, membership, invitation, assignment, approval, admin role, finance or audit record was created or modified. No privileged action or business RPC was invoked.

## Executive decision
**NO-GO for describing the control tower as a fully functioning global network operations centre or the enterprise workspace as connected multi-entity visibility.** The repository contains functional read-only dashboards and several secure administrative workflows, but production has no partner assignments, dispatch authorizations, capacity resources/reservations, organization relationships, network memberships, organization invitations, organization verifications or onboarding records. There are 18 shipment records but only one shipment leg, no active route plan and no partner assignment. The workspace UI therefore has little actual operational network state to manage.

Two important authorization mismatches were found:
1. The enterprise workspace verifies enterprise membership but its shipment query is constrained by shipment RLS that does not include enterprise organization membership or organization relationships. Enterprise users therefore cannot be assumed to see customer shipments.
2. The operations snapshot RPC requires an active operations membership but then additionally checks `shipment.view` against each shipment's customer organization. That can block central operations users who have legitimate operations-wide permission but no membership in every customer organization. This differs from the direct shipment RLS policy, which explicitly allows operations organization members with `shipment.view` in their operations organization.

A further platform-admin assurance gap exists: admin actions write audit events after the primary action, but the helper does not check whether the audit insert succeeded. Privileged actions may therefore succeed without their expected audit record.

## 1. Production network baseline
| Object | Rows |
|---|---:|
| Organizations | 14 |
| Active organization memberships | 13 |
| Organization relationships | 0 |
| Organization invitations | 0 |
| Network memberships | 0 |
| Organization verifications | 0 |
| Organization onboarding records | 0 |
| Shipments | 18 |
| Shipment legs | 1 |
| Partner assignments | 0 |
| Dispatch authorizations | 0 |
| Capacity resources | 0 |
| Capacity reservations | 0 |
| Active route plans | 0 |
| Operational snapshots | 18 |
| Audit events | 203 |
| KPI snapshots | 0 |

Organization catalogue rows by type: 5 customer, 2 partner, and one each carrier, customs, enterprise, finance, operations, platform and warehouse. All 14 catalogue rows were in active status. This status alone does not mean a partner is verified, compliant, contracted or operationally approved.

Membership rows by role: 7 owners, 4 managers, 1 member and 1 driver; all 13 rows were active. No invitation or relationship records exist to demonstrate external enterprise group access or network federation.

The 18 operational snapshots show 17 `healthy` and 1 `attention`; there is one open medium shipment alert. These are event-triggered snapshots, not a live health certification. There are no shipment partner assignments or active route plans, so the snapshot labels must not be interpreted as proof of real transport execution.

## 2. Operations Control Tower
### Positive controls
- Operations pages verify a signed-in session and active membership in an active operations organization.
- The main operations command centre queries live database sources, checks response shapes, distinguishes query failure from empty results and labels visible records as permission-scoped rather than global network totals.
- Shipment control page is explicitly read-only and does not claim that its preparation form performs operational writes.
- Dispatch page calls a server-side readiness routine and describes readiness as a review state, not dispatch authorization.
- `krim_operations_dispatch_readiness` is a read-only SQL SECURITY DEFINER routine with an empty search path. It checks active partner assignment, shipment/leg state, partner verification and current compliance, warehouse dispatch handover, eligible verified driver and vehicle, payload capacity, licence evidence, vehicle documents, active route-plan linkage and current multi-leg authorization/custody conditions.
- `krim_operations_list_shipment_snapshots` requires authentication, a bounded limit and active operations organization membership.

### P1 — Operations snapshot authorization mismatch
The snapshot RPC checks for active operations membership, but its final query filters every shipment with:
`krim_has_permission(user_id, shipment.customer_organization_id, 'shipment.view')`.

The direct `krim_shipments` SELECT RLS policy separately allows an active operations member with `shipment.view` in the operations organization. The snapshot RPC does not use that same scope. An operations user who can see a shipment through the RLS operations clause may receive no corresponding snapshot because they do not also hold permission in that customer's organization.

**Remediation:** align snapshot authorization with the documented operations organization permission and enforce an explicit operations-wide scope. Preserve customer/partner scope separately. Test a user who belongs only to the operations organization, a customer-only user, a partner-only user, and an unauthorized user. Do not widen access to all authenticated users.

### Operational readiness limitations
- One shipment leg and no partner assignment means dispatch readiness cannot demonstrate a complete network dispatch journey.
- There are no capacity resources/reservations, so no physical capacity exists to allocate.
- There are no route plans or organization relationships/network memberships to support multi-partner or enterprise-group orchestration.
- Readiness output is not a dispatch authorization; final authorization still needs exact-leg partner, capacity, driver, vehicle, warehouse handover and evidence checks.
- No live end-to-end tests were executed.

## 3. Enterprise workspace access mismatch
The enterprise landing page correctly verifies the signed-in session and requires an active membership in an active enterprise organization before opening the workspace. It then queries `krim_shipments` and falls back to legacy `shipment_requests` if the first query errors.

However, the current `krim_shipments` SELECT policy allows:
- the owning customer organization;
- an active partner with a qualifying open partner opportunity and verified/current capability; or
- an authorized operations organization member.

It does not include enterprise organization membership or a verified enterprise-to-customer organization relationship. The enterprise workspace's client-side membership gate does not itself grant row access. The live organization-relationship and network-membership tables are empty.

**P1:** enterprise users may successfully enter the workspace but still see no customer shipment data, even where the business expects group-wide visibility. The fallback to legacy `shipment_requests` can also conceal a schema/query mismatch and may display a different legacy data set rather than proving the canonical `krim_shipments` path works.

**Remediation:** define an explicit, consented and revocable enterprise-to-customer organization relationship model (including scope, data categories, effective dates, approver, contract authority and audit trail). Add narrowly scoped RLS or a vetted read RPC using that relationship. Remove silent legacy fallback after a measured migration and report canonical source failures clearly. Do not grant broad enterprise-wide shipment access.

The enterprise page also presents commercial, finance, people, documents, integrations, intelligence and governance sections. The reviewed index's core data load is shipment-centric; other pages need their own source-of-truth, permission and functional workflow tests. A navigation section or visual KPI is not evidence that its underlying business process is operational. Finance remains deliberately deferred.

## 4. Platform Admin control plane
### Positive controls
The deployed `global-admin-control` Edge Function:
- Requires a bearer token, validates the user through Supabase Auth and checks AAL2 before processing.
- Uses server-side active role assignments and requires `platform_admin` or `platform_superadmin`.
- Requires `platform_superadmin` for role assignment/revocation and high-impact user disable/enable/session-revocation actions.
- Blocks self-disable.
- Bounds page size and limits supported actions.
- Uses a request ID for correlation and returns explicit authorization failures.
- Uses a service-role client only after the authenticated user and AAL2 checks.

### P1 — Audit is not fail-closed
The Edge Function's `audit()` helper inserts into `krim_audit_events` but does not inspect or propagate the insert error. Several privileged operations first mutate the target (e.g. role change, user ban/unban, session revocation, inquiry status/follow-up) and only then call this helper. A successful action can therefore return success even if its audit write failed. The control plane should not claim an audited change unless the event was durably recorded.

**Remediation:** make each privileged mutation and audit event atomic in a database RPC/transaction, or use a durable transactional outbox. Check and propagate audit failures. Include actor, target, prior state, new state, reason, request ID and idempotency key; never log credentials or unnecessary PII. Verify audit append-only/retention and independent access controls.

### P2 — Read helper hides source failures as empty arrays
The Edge Function's generic `rows()` helper logs a table query error and returns an empty array. The UI then renders "no records" rather than "source unavailable". This can mislead platform administrators during incidents. Return an explicit per-source error state and never convert a query failure into a valid empty result.

The overview count handler already returns `null` for failed counts; use the same explicit distinction throughout the control plane. Test missing table, permission denial, timeout and empty table separately.

## 5. Audit and KPI evidence
- 203 audit events exist, but this does not prove complete coverage of every privileged mutation or every business transition.
- The `krim_audit_events` authenticated SELECT policy only exposes events where `actor_user_id=auth.uid()`; platform administrators rely on the privileged control-plane path for broader audit review.
- `krim_kpi_snapshots` has zero rows. Do not represent static dashboard values as live network KPIs.
- Operational snapshots are generated by database triggers on shipment/exception/alert events and calculate health from open exceptions and alerts. A healthy snapshot means no open exception/alert was counted at that capture time; it does not validate partner, corridor, capacity, customs, driver, warehouse or shipment execution readiness.
- No actual customer/partner SLA or global service-level performance can be inferred from current row counts.

## 6. Required staging-only verification
1. Operations-only member reads authorized shipment and snapshot; verify same visible shipment set and matching permission semantics.
2. Customer-only, partner-only, enterprise-only, driver-only and revoked-member users cannot cross-read other organization shipments, alerts, snapshots or evidence.
3. Enterprise relationship: approved scope, multiple subsidiaries, denied unlinked subsidiary, revoked relationship, expired relationship, user role downgrade and audit trail.
4. Enterprise fallback: canonical table unavailable, missing legacy table, mismatched columns, empty canonical result and query error must remain distinguishable; no silent source substitution.
5. Operations readiness: every blocker independently injected; no partner, expired compliance, no capability, no handover, no capacity, no driver, expired licence, expired vehicle document, wrong leg and stale custody.
6. Snapshot function: invalid limits, missing membership, missing permission, wrong tenant, operations-only visibility, customer visibility and partner visibility.
7. Platform admin: invalid token, AAL1, non-admin, platform admin vs superadmin, role escalation, self-disable, revoked role, session revocation and concurrent admin actions.
8. Audit failure injection: simulate audit insert rejection/timeout and prove the primary mutation is rolled back or durably queued; no success response without a durable audit record.
9. Read helper: distinguish empty result from missing table, RLS denial, network error and timeout.
10. KPI/snapshot freshness: stale snapshot, duplicate trigger, alert resolution, exception resolution, event replay and recomputation.

## 7. Remediation and release order
1. Correct operations snapshot RPC scope to match the explicit operations authorization model.
2. Implement explicit enterprise relationship and scoped shipment visibility; remove silent legacy fallback after migration.
3. Make privileged admin mutations and audit events atomic/durable; fail closed when audit cannot be recorded.
4. Make all admin read paths distinguish empty data from query failure.
5. Establish canonical KPI definitions, provenance, freshness and network coverage disclaimers; do not display static placeholders as live.
6. Run nine-workspace cross-tenant staging tests and full multi-organization operational journey.
7. Only after market/corridor/partner/capacity/warehouse/customs/driver and legal release gates pass, consider a controlled pilot.

## 8. Change control and release gate
This audit was read-only. No production SQL, DDL, RLS policy, function, organization, membership, role, shipment or audit record was changed. No privileged admin action, shipment readiness RPC or customer/partner workflow was invoked. Financial collection remains deferred to the final phase.

Production migration reconciliation is still unresolved. Do not implement the above production schema/function/policy changes until the migration crosswalk and sanitized schema manifest are reconciled.

**Release status: NO-GO for unrestricted global control-tower operations, enterprise group-wide shipment visibility, or a claim of complete platform-admin audit assurance.** The core workspaces and strong safeguards exist, but operational network records are absent and authorization/audit consistency gaps require remediation and staging proof.
