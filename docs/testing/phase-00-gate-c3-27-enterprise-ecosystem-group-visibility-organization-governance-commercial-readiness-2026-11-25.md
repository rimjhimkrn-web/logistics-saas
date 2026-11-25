# Phase 00 Gate C3.27 — Enterprise ecosystem, group visibility, organization governance and commercial readiness

**Date:** 2026-11-25  
**Immutable source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**Method:** Read-only source inspection and reconciliation with prior Production audit reports dated 2026-11-16 and 2026-11-11. Production counts are historical snapshots from those audits, not refreshed in this gate. No SQL/RPC, invitation, membership change, role change, organization relationship, contract, shipment, billing, payment, export, notification or deployment operation was executed.

## Executive decision

**FAIL / BLOCKED — NO-GO for enterprise group-wide shipment visibility, self-service subsidiary/team administration, consolidated enterprise finance certification, binding enterprise contracting, or broad enterprise customer onboarding.**

KRIM has a credible enterprise workspace shell and useful read-only governance surfaces. The canonical enterprise home checks authenticated identity and active membership in an active enterprise organization. Several modules are explicitly read-only and state that RLS remains authoritative. Enterprise shipments distinguish query failure from an empty result. Finance visibility is read-only and no payout/ledger mutation is exposed from that page. Existing customer/partner quote and booking workflows contain meaningful server-side checks and distinguish quote award from completed booking.

However, enterprise identity is not yet connected to a verified group-wide customer organization graph. The enterprise shipment query relies on RLS that does not include enterprise membership or a verified enterprise-to-customer relationship; the enterprise shipment child page checks for any active organization membership rather than specifically an enterprise membership. Organization/team management remains a shell. Generic organization invitations, onboarding and relationship records were empty in the prior Production snapshot. Role authority is split across three models. Membership audit does not cover update/revocation. Finance and enterprise live modules rely on broad organization-ID lists and RLS, without a proven parent/subsidiary relationship contract. Contracts, SLAs, claims, disputes and payment terms are not operationally executed.

**No P0 enterprise-specific exploit was established by this source review.** The following P1 findings are release blockers. Existing global P0 issues in the nine-workspace authorization and dispatch audits remain separately open.

## Scope and evidence reviewed

### Enterprise source surfaces
- `app/enterprise/index.html` — canonical Enterprise Command workspace and its membership gate / shipment visibility.
- `app/enterprise/dashboard.html` — executive overview shell.
- `app/enterprise/organization.html` — organization and people shell.
- `app/enterprise/shipments.html` — read-only shipment list.
- `app/enterprise/finance.html` — invoices, settlements, payables, transactions, ledger, reconciliation, approvals and monitoring reads.
- `app/enterprise/enterprise-live.js` — reusable read-only enterprise data modules.
- `app/enterprise/analytics.html`, `commercial.html`, `approvals.html`, `documents.html`, `integrations.html`, `risk-compliance.html`, `ai-governance.html`, `automation.html`, `institutional-memory.html`.

### Prior audits
- `docs/audits/KRIM-OPERATIONS-CONTROL-TOWER-ENTERPRISE-ACCESS-AND-PLATFORM-GOVERNANCE-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-NINE-WORKSPACE-AUTHORIZATION-ROLE-MAPPING-AND-TENANT-ISOLATION-DEEP-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-ORGANIZATION-MEMBERSHIP-INVITATION-ROLE-AND-REVOCATION-LIFECYCLE-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-ORGANIZATION-ONBOARDING-INVITATION-MEMBERSHIP-AND-ROLE-PROVISIONING-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-CUSTOMER-PARTNER-CONTRACTS-AGREEMENTS-AND-COMMERCIAL-TERMS-INTEGRITY-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-SAAS-BILLING-ACCESS-AND-AUDIT-CONTROLS-2026-11-11.md`
- `docs/audits/KRIM-PAGE-78-ENTERPRISE-DASHBOARD-REVIEW-2026-11-16.md`
- `docs/audits/KRIM-PAGE-79-ORGANIZATION-AND-TEAM-MANAGEMENT-REVIEW-2026-11-16.md`
- `docs/testing/KRIM-NINE-WORKSPACE-AUTHORIZATION-AND-TENANT-ISOLATION-TEST-MATRIX-2026-11-16.md`
- `docs/architecture/tenant-isolation-model.md`

## Positive controls confirmed

1. **Canonical Enterprise Command gate:** `app/enterprise/index.html` verifies the signed-in user and queries active memberships joined to organizations; it admits only active memberships in active organizations whose type is `enterprise`. Membership query errors fail closed.
2. **Dashboard and people pages do not pretend to be complete:** prior page audits found dashboard and organization/team pages were shells, not live KPI or member-management systems. Their copy states that RLS/fine-grained permission checks remain authoritative and that invitations, role changes and member suspension are not connected.
3. **Read-only enterprise modules:** `enterprise-live.js` describes read-only data views, queries the configured tables using the current Supabase session, distinguishes source query failures from empty results, and does not expose role changes, approvals, payment movements, integration secrets, document URLs or emergency commands.
4. **Enterprise shipment child page separates query failure from empty data:** it requires a session and at least one active membership before querying canonical `krim_shipments`; on query error it displays unavailable rather than a false empty state. No write action is exposed.
5. **Finance page is read-only:** the page gathers organization IDs from the signed-in user's active memberships and reads invoices, settlements, payables, financial transactions, ledger transactions, reconciliations, approval requests and monitoring alerts. It exposes no payment, payout or ledger mutation from this page.
6. **Core membership table baseline is restrictive:** prior audit found authenticated self-read on membership/role data and no direct authenticated INSERT/UPDATE/DELETE on the reviewed core membership/role tables. Mutations are expected through controlled backend paths.
7. **Customer/partner provisioning has useful controls:** prior audit found authenticated provisioning, per-user advisory transaction lock and duplicate-active-organization reuse. Partner provisioning creates pending verification/compliance state rather than falsely approving a partner.
8. **Driver-specific invitation path is comparatively mature:** it uses partner permission, carrier eligibility, email confirmation, one-time token hash, expiry and revocation checks. It is not a general enterprise or organization invitation system.
9. **Commercial quote controls:** customer quote award and acceptance are separate, server-authorized steps; partner eligibility, quote validity, shipment state, accepted partner quote and assignment are checked. The customer-facing flow warns that quote acceptance alone is not proof of final booking, payment collection or delivery.
10. **Financial separation:** prior finance audit and current page copy preserve read-only visibility and do not turn an enterprise dashboard into a payout, escrow or freight collection authority.

## P1 findings

### ENT-01 — Enterprise-to-customer group relationship is missing

Prior Production audit found zero organization relationships and zero network memberships. The Enterprise Command gate proves only that the user belongs to an enterprise-type organization. It does not establish which customer organizations, subsidiaries, legal entities, business units or controlled affiliates the enterprise is authorized to view.

The prior tenant-isolation audit found that shipment RLS did not include enterprise membership or a verified enterprise-to-customer organization relationship. Therefore an enterprise user may enter the workspace but cannot be assumed to see the customer shipments expected by the commercial group model. A generic enterprise membership must not imply access to every customer organization.

**Required:** create a governed relationship model with exact parent enterprise, child/customer organization, relationship type, data categories, service scope, legal authority/contract reference, approver, effective dates, expiry, revocation and audit history. Read access must be granted through a narrow server-side RLS predicate or vetted read RPC that validates both the enterprise membership and the active relationship. Revocation must remove access on the next authorized request and stale-session tests must verify it.

### ENT-02 — Enterprise shipment child page checks any active membership, not enterprise membership

`app/enterprise/shipments.html` checks that the user has at least one active row in `krim_organization_members`; it does not itself filter membership to an active enterprise organization. It then queries the canonical shipment table and relies on RLS for the actual row set. RLS remains the real security boundary, so this is not proof of cross-tenant data exposure. But the UI admission contract is inconsistent with the canonical Enterprise Command page and can admit a user whose only active membership is a customer, partner or other organization into an enterprise-labelled shell.

The older Enterprise Command shipment query also attempts a fallback to legacy `shipment_requests` after a canonical `krim_shipments` query error. This can obscure a canonical schema/RLS failure and risks presenting a different legacy dataset as though it were the canonical enterprise shipment portfolio.

**Required:** standardize enterprise entry checks across all enterprise routes; verify active enterprise organization membership and selected tenant context before any enterprise data read. Remove silent legacy shipment fallback from enterprise reporting; show canonical query failure as unavailable with diagnostic correlation. Keep RLS as the final authorization boundary.

### ENT-03 — Organization and team management is not implemented as an operational lifecycle

`app/enterprise/organization.html` is a shell. Prior audit confirmed it does not load organization profiles, members, roles, invitations or access history. It does not connect team invitation, role change, member suspension or organization update. Page 79's session gate was improved to require active membership, but that is not permission to administer the organization.

**Required:** separate read-only member directory from administration. For every operation require organization-scoped owner/admin permission, role allowlist, least privilege, AAL2 for privileged changes, maker-checker where appropriate, reason, idempotency and durable audit. Never let a member grant themselves enterprise owner, finance approver, platform admin or superadmin.

### ENT-04 — Generic organization invitation and onboarding lifecycle is absent

Prior Production snapshot:
- 14 organizations; 13 active organization memberships.
- 0 generic organization invitations.
- 0 organization onboarding records.
- 0 network memberships.
- 0 partner onboarding checklists.
- 0 private driver invitations.
- 17 numeric RBAC assignments and 5 legacy `user_roles` rows.

The generic invitation table has fields for organization, email, role code, token hash, status, inviter and expiry, but the prior callable-function inventory found no generic create/accept/revoke RPC. Driver invitations are a distinct workflow and cannot be treated as enterprise subsidiary or team invitations.

**Required:** implement and test exact organization-bound, normalized-email-bound, role-allowlisted invitations with random one-time token hashing, expiry, revoke, atomic acceptance and membership provisioning, email delivery evidence, replay/race protection and immutable audit. Enterprise subsidiaries must not be implicitly created or linked by an invitation.

### ENT-05 — Membership change and revocation audit is incomplete

Prior membership audit found only an AFTER INSERT trigger on `krim_organization_members`, with no equivalent UPDATE/DELETE audit trigger for role changes, suspension or revocation. The trigger records the organization ID as entity ID rather than the membership row ID; 13 of 25 historical organization/membership audit events had a null actor.

**Required:** route membership changes through a transactionally audited state-transition function or complete trigger coverage. Record membership row ID, organization, subject user, previous/new role and status, actor, reason, request/session context and timestamp. A successful change must not be reported if its audit record cannot be committed. Verify revocation against active and stale sessions.

### ENT-06 — Role authority is split across three models

Prior audit identified three coexisting authorities:
1. `krim_organization_members.role` (organization-scoped text role);
2. `krim_user_role_assignments` linked to `krim_security_roles` (numeric RBAC, nullable organization scope);
3. legacy `user_roles` (global text role).

The precedence and synchronization contract is not proven. Numeric RBAC allows nullable organization scope, which requires explicit separation of platform-global and tenant roles. Enterprise UI membership checks alone do not prove permission resolution.

**Required:** define one canonical authorization decision model and a migration/compatibility map. Enforce tenant-vs-platform scope invariants, unique global-role semantics, role allowlists, permission evaluation precedence and fail-closed behavior. Retire legacy roles only after dependency tracing and regression tests.

### ENT-07 — Finance and live enterprise module queries rely on RLS without a proven group relationship contract

The finance page constructs a list of every active organization ID for the user, then issues multiple direct table queries using those IDs and OR filters. `enterprise-live.js` reads configured tables directly and relies on the current session and RLS. This is an acceptable read-only pattern only if the underlying policies precisely scope each table by role, tenant, relationship and record purpose. It does not itself establish enterprise parent/subsidiary visibility.

The prior enterprise/tenant audit found the group relationship/network membership tables empty. No cross-tenant adversarial test was run. A broad list of a user's memberships is not equivalent to a legal group consolidation scope.

**Required:** define an approved tenant context and explicit per-module relationship rules. Use narrow views/RPCs or table RLS with exact row scope. Verify invoice issuer, customer, supplier, partner, settlement, payable, ledger and transaction visibility independently. Never infer consolidated financial totals across organizations solely because a user has memberships in multiple organizations.

### ENT-08 — Enterprise executive dashboard is a shell, not a live executive dashboard

Prior Page 78 audit found `app/enterprise/dashboard.html` did not query shipment, finance, service-risk or governance metrics. The membership gate was strengthened and the page labels itself a shell with no live data query. It must not be marketed as a real consolidated executive dashboard or global group KPI view.

**Required:** establish governed metric definitions, tenant relationship scope, data lineage, source timestamps, freshness SLOs, currency conversion basis, exclusion rules and drill-through authorization before displaying group-level metrics. Every figure must identify the legal entities and periods included.

### ENT-09 — Contracts, SLA and disputes are not a complete binding enterprise commercial lifecycle

Prior Production snapshot in the contract integrity audit:
- 0 service contracts.
- 0 service-contract SLA rows.
- 0 payment terms.
- 0 quote acceptances and quote events/versions in that snapshot.
- 7 quote rows and 3 partner opportunities.
- 0 partner quote rows.
- 0 claims, claim events/evidence, disputes, dispute cases, appeals, decisions, evidence links and investigations.
- 0 refund requests and 0 invoices.

The quote/booking workflow has positive controls but is not proof of a fully executed master agreement, service schedule, enterprise purchasing authority, counterparty signature, service-level schedule, liability allocation or dispute lifecycle. The legal terms audit explicitly treated partner agreement materials as negotiation frameworks rather than completed signed agreements.

**Required:** enterprise procurement and booking must bind the exact legal entities, authorized signatories, master agreement and schedule versions, service/territory/cargo scope, rate and tax basis, liability/insurance, SLA, payment terms, cancellation/claims notice, jurisdiction and dispute process. Capture document hash, version, language, timestamp, actor, authority and acceptance method. Do not treat a quote, checkbox or shipment status as universal contract execution.

### ENT-10 — Consolidated billing and credit/treasury features are not proven operational

Enterprise pages include finance visibility and navigation for billing, budgets, cost centres, working capital, credit risk, tax, reconciliation, approvals and treasury-related modules. Read-only display does not establish production billing, credit underwriting, payment terms, tax invoice readiness or legally permitted collection. Prior finance audit found no invoice, partner payable, ledger journal or reconciliation run in its historical snapshot and identified outstanding finance controls. KRIM's safe interim model remains partner-direct freight payment with any KRIM fee handled separately under its own reviewed contract.

**Required:** keep enterprise finance modules read-only until finance Phase C3.25 remediation and later controlled financial testing pass. Separate customer freight funds from KRIM service fees; do not activate credit, escrow, consolidated invoicing, automatic split, partner settlement or payout based on UI presence.

### ENT-11 — Data export and document governance need adversarial verification

Enterprise live modules include CSV exports of records returned to the session; the enterprise document directory intentionally avoids exposing private file contents and URLs. These are sensible boundaries, but exports still require verified row scope, field minimization, download audit, retention and prevention of cross-entity leakage. No export authorization or data-loss-prevention adversarial test was executed in this gate.

**Required:** export only rows already authorized under a clearly selected tenant/group scope; exclude secrets and unnecessary personal/sensitive fields; audit actor, organization, filters, columns, row count and timestamp. Document access must remain separately governed by object-level authorization, retention and legal hold.

### ENT-12 — Enterprise integration, automation and AI governance pages are not proof of connected enterprise systems

The enterprise live script includes integration registry/sync run, AI action, workflow run, claims, approvals, document and operational datasets. The UI correctly states that configuration alone does not prove a healthy integration and that no secrets or raw sensitive payloads are shown. However, source visibility is not proof of live ERP/EDI/TMS integration, successful synchronization, AI governance approval or automation reliability. These require provider-specific connection, freshness, error and audit evidence.

**Required:** certify each integration separately with tenant-bound credentials in secret storage, least-privilege scopes, verified webhook signature, idempotent sync, error/retry/dead-letter handling, last successful sync and customer-visible status. AI actions must preserve human approval and tenant-bound data controls.

## Historical Production baseline (not refreshed in this gate)

Prior 2026-11-16 organization audit recorded 14 organizations and 13 active memberships, distributed across five customer, two partner, one individual-driver carrier, one customs, one enterprise, one finance, one operations, one platform and one warehouse organization. It also recorded zero generic invitations, zero onboarding records and zero network memberships. The 2026-11-16 enterprise/control-tower audit recorded no organization relationships or network memberships and no active partner assignments, dispatch authorizations, capacity resources/reservations or multi-leg route plan. The 2026-11-16 contract audit recorded the empty contract/claims/disputes/invoice counts listed above. These figures are historical snapshots only and were not refreshed or re-queried in C3.27.

## Readiness matrix

| Enterprise capability | Result | Boundary |
|---|---|---|
| Enterprise Command admission | PARTIAL PASS | Active enterprise membership gate in canonical home; no runtime test |
| Enterprise dashboard | NOT READY | Shell; no governed KPI data |
| Enterprise-to-customer group relationships | FAIL / BLOCKED | No verified relationship/network membership model evidenced |
| Enterprise shipment visibility | FAIL / BLOCKED | RLS lacks proven enterprise relationship scope; child gate checks any active membership |
| Organization profile and team directory | NOT READY | Shell; no live management lifecycle |
| Generic enterprise invitations | FAIL / BLOCKED | No generic create/accept/revoke workflow evidenced |
| Membership revocation audit | FAIL / BLOCKED | Update/delete audit incomplete in prior review |
| Canonical role authority | FAIL / BLOCKED | Three competing role models; precedence unresolved |
| Enterprise finance visibility | PARTIAL PASS / BLOCKED | Read-only queries; group/legal-entity scope not proven |
| Consolidated billing/credit/treasury | NOT READY | No operational financial certification |
| Contracts, payment terms and SLA | FAIL / BLOCKED | No complete executed agreement lifecycle |
| Claims/disputes/appeals | NOT TESTED / BLOCKED | Historical registers empty |
| Enterprise data export | PARTIAL PASS / BLOCKED | CSV export exists; scope/DLP/audit not adversarially tested |
| ERP/EDI/integrations and automation | NOT TESTED / BLOCKED | Registry UI is not connection proof |
| Cross-tenant and subsidiary isolation | NOT TESTED / BLOCKED | No adversarial staging matrix executed |

## Required remediation and controlled test order

1. Reconcile Production migration history and deployed schema/function/policy definitions against repository migrations before any database changes. Prior audits flagged migration-history and role-model drift; do not replay, baseline, squash or apply migrations while reconciliation is unresolved.
2. Specify the enterprise group model: parent, subsidiary, customer legal entity, business unit, relationship type, data categories, authority/contract, approver, effective dates, expiry and revocation.
3. Implement exact enterprise relationship-based shipment/document/finance read authorization; standardize all enterprise page gates and remove silent legacy shipment fallback.
4. Establish one canonical tenant-aware role/permission authority and migrate/retire legacy role sources only with dependency evidence.
5. Implement generic organization invitation, onboarding, acceptance, membership lifecycle, revocation and durable audit. Require AAL2 and maker-checker for privileged role/admin actions.
6. Build the enterprise executive dashboard only after metrics, currency basis, lineage, freshness and relationship scope are defined.
7. Keep finance read-only until finance P0/P1 remediation, partner-direct commercial boundaries and later controlled financial tests pass.
8. Implement signed/versioned enterprise contracts, schedules, SLAs, payment terms, cancellation and claims/dispute process with legal review for applicable jurisdictions.
9. In isolated Staging, create synthetic parent enterprise + two child legal entities + unrelated tenant. Test positive approved relationship, missing relationship, expired/revoked relationship, wrong data category, cross-entity query, export, stale session, role change, suspended member, subsidiary invitation replay, self-escalation and audit failure.
10. Test finance records separately for issuer/customer/supplier/partner and ensure no cross-entity invoice/payable/ledger visibility without explicit authority.
11. Run a full synthetic enterprise journey only after the above: enterprise admission → authorized subsidiary relationship → invitation → member role → scoped shipment visibility → quote/contract acceptance → partner execution evidence → invoice visibility → export audit → relationship revocation and session/access revalidation.

## Safety and release boundary

This was a read-only source/prior-audit review. No Production or Staging SQL/RPC, organization relationship, invitation, membership, role, contract, shipment, finance record, payment, invoice, export, email, external notification or deployment action was executed. Historical counts were not refreshed. No cross-tenant adversarial runtime test was performed.

**Gate C3.27: FAIL / BLOCKED — NO-GO for enterprise group-wide visibility, self-service team administration, consolidated enterprise finance certification or binding enterprise contract lifecycle.**
