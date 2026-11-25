# KRIM Global Platform — Phase 00 Gate C3.29
## Cross-Ecosystem Integration, Shared Identity, Data Ownership and Workflow Handoff Audit
**Audit date:** 25 November 2026  
**Baseline:** immutable source commit `72d75a18f985ceb09e468839435ee95700e11e46`  
**Documentation branch:** `qa/phase-00-baseline-2026-11-25`  
**Method:** read-only static source and prior-audit reconciliation

## 1. Executive verdict

**Gate C3.29: FAIL / BLOCKED — NO-GO for a complete cross-workspace operational journey or unrestricted production onboarding.**

KRIM has meaningful backend-connected components across its nine workspaces. The source shows useful safeguards: organization-scoped permission checks, authenticated partner and customer gateways, private evidence handling, exact-leg partner assignment controls, warehouse allocation/handover primitives, and dedicated finance/customs/operations/admin boundaries.

However, the nine workspaces do not yet form one proven, consistent, end-to-end operating system. Authorization authorities and assurance rules differ by workspace; canonical and legacy shipment models coexist; multiple critical handoffs have independently identified P0 blockers; enterprise and operations can present incomplete or fallback data; and no controlled end-to-end staging evidence proves the complete customer → partner → warehouse/customs/driver → operations → delivery → finance chain. This gate does not claim that every finding was newly introduced in C3.29: it consolidates and tests the cross-workspace implications of C3.20–C3.28 findings against the immutable baseline and earlier audits.

**Evidence classification:** source-level controls are not runtime proof. Historical Production counts cited below are explicitly prior snapshots and were not refreshed for this gate.

## 2. Scope and evidence inspected

Reviewed the immutable baseline tree and relevant source/audit evidence for:
- nine workspace entry points and their connected dashboard/runtime paths;
- cross-workspace permission policies and the `private.krim_has_permission` helper;
- customer quote acceptance and accepted partner assignment dependency;
- shipment state machine, legacy shipment model, status history and event generation;
- warehouse shipment allocation, picking, dispatch handover and leg dispatch dependencies;
- operations dispatch readiness and privileged dispatch paths;
- enterprise shipment-source fallback and finance/operations visibility surfaces;
- prior focused audits for partner, customer, driver, warehouse, customs, finance, operations, enterprise and admin ecosystems;
- prior edge-function/source-parity and authentication/RBAC audits.

Key inspected source:
- `supabase/migrations/20261105081710_scope_cross_workspace_read_policies_to_permissions.sql`
- `supabase/migrations/20261105084623_require_active_membership_for_permission_checks.sql`
- `supabase/migrations/20261111120000_secure_global_quote_acceptance_partner_assignment.sql`
- `supabase/migrations/20261116026000_warehouse_shipment_inventory_allocation.sql`
- `supabase/migrations/20261116027000_require_picked_allocations_before_dispatch_handover.sql`
- `supabase/migrations/20261116028000_require_warehouse_handover_before_leg_dispatch.sql`
- `app/customer/index.html`, `app/partner/index.html`, `app/driver/dashboard.html`, `app/warehouse/index.html`, `app/customs/index.html`, `app/finance/index.html`, `app/operations/index.html`, `app/enterprise/index.html`, `app/platform-admin/index.html`
- prior audit: `KRIM-NINE-WORKSPACE-INTEGRATION-AND-PERMISSION-CONSISTENCY-AUDIT-2026-11-16.md`
- prior audit: `KRIM-FRONTEND-TO-BACKEND-WORKFLOW-INTEGRATION-COVERAGE-AUDIT-2026-11-16.md`
- prior audit: `KRIM-SHIPMENT-LIFECYCLE-STATE-MACHINE-AND-EVENT-CONSISTENCY-P0-P1-AUDIT-2026-11-16.md`

No browser-authenticated journey was executed. No Production or Staging RPC/SQL, database mutation, Auth operation, shipment, inventory, customs, finance, dispatch, provider, notification, external contact or deployment action was performed.

## 3. Cross-workspace identity and authorization contract

### Positive source controls
- `private.krim_has_permission` requires an active role assignment, granted role-permission mapping, active organization membership and active organization. Its `auth.uid()` comparison prevents an authenticated caller from simply supplying another user's identity.
- The cross-workspace read-policy migration scopes exceptions, invoices, settlements, alerts, customs data and milestones to named permissions and organization/shipment relationships.
- Customer quote acceptance checks the authenticated user's customer-organization access and `shipment.update`, verifies the quote/shipment customer organization match, requires an eligible linked partner quote, checks amount/currency consistency, and requires an accepted partner assignment before customer acceptance.
- Partner, customer, customs, finance and admin gateways contain stronger server/backend checks than a navigation-only role guard.
- Warehouse allocation and handover functions use server-side operator/facility checks and exact shipment/leg/partner relationships. The handover/dispatch chain checks picked allocation state and private dispatch proof.

### P0 — no single workspace/action authorization contract is proven
The prior nine-workspace audit found inconsistent entry gates: Customer can load read-only dashboard data while AAL2 is absent; Customs explicitly requires AAL2; Operations and Warehouse rely more heavily on backend RPC/policy checks without a consistent visible workspace permission decision; Enterprise checks active enterprise membership but does not consistently apply a named enterprise permission at the entry layer. The Admin and other privileged workflows apply different server-side patterns.

The database must remain the authorization boundary, but the product currently lacks one documented, versioned action-to-assurance and workspace-access contract that all pages and server endpoints demonstrably implement. This compounds the competing role sources (organization membership role, role assignment/permission catalogue, and legacy client metadata/session paths) identified in earlier audits.

**Required:** define a single server-authoritative workspace/action decision contract returning allow/deny, organization scope, safe reason code, required AAL, policy version and data-scope identifier. Use it consistently for entry UX while retaining endpoint-specific resource/state checks. Do not let the shared decision replace exact tenant/resource checks. Remove editable metadata/localStorage from authorization paths and define revocation freshness for stale JWTs.

### P0 — broad role grants undermine workspace separation of duties
The earlier live role catalogue snapshot showed broad generic grants: organization owner/admin roles included finance/compliance management and dispatch-related powers; partner_user held generic shipment.assign/dispatch permissions; platform_admin held broad business permissions. These permissions must be constrained by exact organization, shipment/leg, partner assignment, jurisdiction, state and independent reviewer. The role catalogue is not a valid substitute for resource-specific authorization.

**Required:** split operational, finance, compliance, platform and tenant administration privileges; establish an action-to-role/AAL/approval matrix; test direct RPC calls and wrong-tenant/wrong-leg identities, not just workspace routes.

## 4. Cross-workspace shipment lifecycle and data model

### Positive source controls
- `krim_shipments` is the canonical shipment model used by the newer quote/leg/dispatch path.
- Customer quote acceptance is linked to a live partner offer and accepted partner assignment, not merely a customer button click.
- The canonical shipment state machine uses a controlled transition registry and status history; direct authenticated table mutation is restricted in the earlier live catalog audit.
- Specialized driver/leg execution is intended to own pickup/transit/delivery events rather than generic shipment transitions.
- Status-history/domain-event creation is distinct from customer/partner notification delivery.

### P0 — canonical and legacy shipment models remain mixed
The shipment lifecycle audit identified coexistence of `krim_shipments` and legacy `shipment_requests`, with different status vocabularies and a legacy transition trigger still attached to the older model in the earlier Production audit. Enterprise's source path also falls back to `shipment_requests` when the canonical `krim_shipments` query errors. A permission error, schema drift or transient canonical-source failure can therefore be hidden as a legacy-data success.

**Impact:** different workspaces or integrations may display different lifecycle truths, or legacy states may be mistaken for canonical shipment state.

**Required:** declare `krim_shipments` plus shipment legs as the only canonical new-work model; inventory every remaining legacy caller; remove silent fallback; surface source-unavailable states; version and reconcile any compatibility adapter before legacy retirement. Never map legacy statuses into canonical status without an explicit, tested transition contract.

### P1 — event creation is not event delivery or shared-state confirmation
The canonical transition path can append history and emit domain events, but earlier lifecycle and notification audits found no proven complete outbox delivery/retry/provider receipt path. An event row, Edge Function response or provider acceptance is not proof that a customer, partner, driver, warehouse or operator received the update. Workspace-specific data reads can also have different freshness windows.

**Required:** define event ownership, event ID, aggregate ID/version, source workspace, actor, tenant, idempotency key, occurred-at timestamp, processing status and delivery receipt. Use a durable outbox, retry/dead-letter and reconciliation. Expose freshness and PARTIAL/UNAVAILABLE states in every cross-workspace dashboard.

## 5. Physical fulfilment handoffs

### Positive source controls
- Warehouse allocation is shipment/leg linked and checks partner/facility/operator authorization.
- A dedicated linked handover path exists; a trigger requires exact-leg picked allocations and rejects outstanding reserved/unpicked allocations.
- The newer leg dispatch authorization checks accepted assignment, capacity reservation/binding, driver eligibility and a completed exact-leg warehouse handover with current private dispatch proof.
- Driver events are scoped to driver/assignment and exact leg; POD is intended to remain independently reviewed.
- Customs internal document/broker review is separated from official government release.

### P0 — warehouse stock reservation/pick integrity remains blocked
C3.23 identified that transfer checks on-hand stock without subtracting active shipment reservations, and generic/linked picking can bypass exact shipment allocation consumption. This means separate workspace views may each show locally valid stock while their combined handoff can overcommit the same physical inventory. The migration-history mismatch also blocks safe implementation until schema history is reconciled.

**Required:** one authoritative available-to-promise formula that subtracts active reservations under concurrency-safe locks; exact allocation consumption for every shipment-linked pick/transfer; idempotent cancellation/reversal; exact item/lot/quantity reconciliation through receipt, QC, pick, handover and return. Verify with concurrent staging reservations and transfers before live warehouse use.

### P0 — legacy dispatch entry can bypass newer cross-workspace readiness
C3.26 identified privileged `krim_dispatch_shipment` as selecting the first assigned leg and transitioning shipment state without the current exact-leg authorization, confirmed physical reservation/binding and complete ROAD driver/vehicle/document checks. The single-leg pickup/transit path also lacked the newer exact-leg helper check. This is a critical boundary between Operations, Partner, Warehouse and Driver workspaces.

**Required:** retire/revoke the legacy privileged dispatch path only after dependency and migration-history reconciliation; route every dispatch and driver milestone through one exact-leg authorization decision; enforce capacity, warehouse handover, driver/vehicle/licence, assignment and custody at the point of action. Add negative tests for wrong leg, stale/revoked authorization, missing stock handover and absent driver readiness.

### P1 — no verified physical execution chain exists
The latest individual ecosystem audits report no complete, independently evidenced operational footprint: verified active partner capability/service areas and capacity commitments are absent in the historical partner snapshot; driver assignments/vehicles/events/POD absent in the historical driver snapshot; warehouse facilities/inventory/allocations/handover absent in the historical warehouse snapshot; and prior shipment lifecycle counts did not demonstrate a complete delivery chain. These are dated snapshots, not fresh counts.

**Required:** keep every route/service ineligible until a real partner, exact capability, approved service area/corridor, capacity, commercial agreement and physical execution evidence are independently verified. Do not interpret synthetic or draft records as operating network capacity.

## 6. Customs and regulatory handoff

### P0 — zero-check customs evaluator can return clear
C3.24 found that the compliance evaluator returns `clear` when there are zero checks, and the prior snapshot had zero rules/checks with six clear gate rows whose checked_by was NULL. It also identified broad authenticated direct SELECT/INSERT/UPDATE and broad ALL policy on shipment compliance gates without the required trusted reviewer/worker restriction. India requirement rows were research_pending, inactive and lacked effective dates.

**Impact:** a missing rule set or unconfigured jurisdiction could be interpreted as a positive compliance clearance when no substantive checks were performed. This is a dangerous cross-workspace handoff because Operations/Enterprise/Customer may consume the gate as a clearance state.

**Required:** zero applicable checks must yield `not_evaluated` or `blocked`, never `clear`; require a non-empty effective jurisdiction rule set, source/version/effective dates and accountable independent reviewer; deny client direct mutation of authoritative compliance gates; represent official authority release separately from internal review. No shipment may pass a customs-required route on internal document review alone.

## 7. Finance and commercial handoff

### P0 — captured-payment webhook bypasses disabled freight-collection gate
C3.25 found that the Razorpay captured/order-paid webhook path does not check the freight-collection enable/version flag and may mark an order paid and invoke company-owned reconciliation even while checkout/manual verification collection are disabled. This is inconsistent with the partner-direct non-custodial commercial boundary.

**Required:** ensure every webhook and reconciliation path independently enforces the same collection kill-switch/version policy before financial state mutation. Do not rely on checkout UI or order creation controls. Keep freight collection, escrow, automatic split, partner payout and refund execution disabled until reviewed, reconciled and explicitly authorized.

### P1 — workspace-level commercial states are not one reconciled transaction lifecycle
Customer quote acceptance, partner assignment, finance order/payment records, invoices, settlements and platform fee records are separate components with unresolved tenant-scope, approval, idempotency, reconciliation and tax constraints. The safe current model remains partner-direct: customer contracts with and pays the verified logistics partner; KRIM separately invoices only its own contractually agreed fee after legal/tax review. A quote accepted, webhook captured, shipment closed or partner payable row does not independently prove KRIM revenue or completed partner settlement.

**Required:** publish one financial event contract with distinct customer-to-partner freight, KRIM service fee, invoice, payment, refund, payable, settlement and bank/provider reconciliation states. Bind every record to exact organization/contract/currency/shipment/partner and require independent approvals and durable audit. Do not perform live-money tests in this phase.

## 8. Enterprise, Operations and Admin information integrity

- Enterprise shipment child pages were found to use any active organization membership rather than a dedicated enterprise-membership check; canonical home silently falls back to legacy shipment data on canonical query error.
- Operations can show successful portions of its dashboard while other domain reads fail; individual error messages exist, but a single overall PARTIAL/UNAVAILABLE state and consistent freshness contract were not proven.
- Admin list helpers can convert read errors into empty arrays, and privileged mutations may succeed when audit persistence fails. Admin action success therefore cannot be treated as cross-workspace audit completion.
- Data export exists in multiple workspaces; consistent row-level export authorization, data-loss prevention, purpose limitation and durable export audit are not established.
- Integration/health panels are not proof of connector uptime, webhook delivery, ERP/EDI execution, provider receipt or real-time telemetry.

**Required:** each shared dashboard must show source, tenant scope, last successful refresh, freshness threshold, row count, error state and whether export is disabled due to incomplete data. Exports must preserve server-side filters and have purpose, actor, tenant, fields, row count, request ID and audit outcome. No data from one legal entity or organization may be aggregated without an explicit relationship and permission.

## 9. Cross-workspace handoff matrix

| Handoff | Source → receiving workspace | Required immutable binding | Current gate |
|---|---|---|---|
| Customer request / quote | Customer → Partner | customer org, shipment ID, route/mode, quote version, partner org, currency/validity | BLOCKED — no complete staging E2E; capability/corridor/contract gaps |
| Partner acceptance | Partner → Customer / Operations | exact partner quote, shipment, leg, accepted assignment, capacity | PARTIAL — quote acceptance checks accepted assignment; live capacity/coverage proof absent |
| Warehouse fulfilment | Warehouse → Operations / Driver | facility, item/lot, reservation, allocation, pick, exact leg, handover, private proof | FAIL — stock reservation/transfer/pick P0 |
| Customs readiness | Customs → Operations / Customer | jurisdiction, effective rule pack, broker licence, case, documents, authority release | FAIL — zero-check clear and gate ACL P0 |
| Driver execution | Partner / Operations → Driver | accepted assignment, exact leg, verified driver/vehicle, current dispatch authorization | BLOCKED — legacy dispatch bypass and no operational footprint |
| Shipment events | Driver / Operations → Customer / Partner / Enterprise | canonical aggregate/version, event ID, actor, consent/preferences, delivery receipt | BLOCKED — event creation ≠ notification delivery; GPS disabled |
| Delivery evidence | Driver → Operations / Customer | assignment, leg, POD evidence, reviewer identity, decision, immutable custody | BLOCKED — tuple binding/integrity/runtime gaps |
| Finance | Partner / Customer / Provider → Finance | contract, org, shipment/quote, currency, provider event, invoice, ledger, settlement | FAIL — webhook kill-switch bypass and finance controls |
| Enterprise visibility | All authorized domains → Enterprise | enterprise-to-legal-entity relationship, child org, permission, freshness | FAIL — relationship and scope incomplete |
| Platform governance | All workspaces → Admin | actor, target, org, action, before/after, reason, durable audit | FAIL — audit atomicity and role/session lifecycle gaps |

## 10. Required remediation order

1. Reconcile Production migration history against repository before any schema/trigger/RPC repair; do not run migrations or DDL from this audit.
2. Close P0 cross-workspace bypasses: legacy dispatch, warehouse reservation/pick integrity, customs zero-check clear/direct gate writes, Razorpay captured-webhook collection gate.
3. Remove silent canonical-to-legacy shipment fallback and enumerate/retire legacy shipment callers safely.
4. Establish canonical identity, membership, role, permission, workspace/action and AAL contract; remove editable metadata/localStorage authorization paths; narrow generic role grants.
5. Create a versioned canonical shipment/leg/event/financial state contract used by every workspace and integration.
6. Implement durable event outbox and notification delivery receipts; distinguish internal event, provider acceptance and recipient delivery.
7. Add enterprise-to-legal-entity relationship and tenant-aware aggregation; prevent any-membership shortcuts.
8. Add freshness/partial-data and source provenance contract to Operations, Enterprise, Finance and Admin.
9. Complete export authorization, audit and data-minimization checks across all workspaces.
10. In isolated Staging only, execute synthetic end-to-end journeys with one identity per workspace, wrong-tenant/wrong-leg attempts, duplicate requests, concurrent stock reservations, stale/revoked sessions, network interruption, event retry/dead-letter, customs zero-rule case and provider kill-switch bypass. Record before/after rows, audit events, request IDs, timestamps and exact expected/actual state.
11. Only after every required stage passes, consider a tightly scoped partner-direct pilot for one exact verified route/service. No broad network, global coverage, dispatch, customs clearance, real-time GPS or finance certification claims.

## 11. Acceptance criteria for a future cross-workspace E2E test

A test is PASS only when all are evidenced in isolated Staging:
- one synthetic customer tenant creates a canonical shipment;
- only an eligible partner tenant sees and quotes the exact opportunity;
- quote amount/currency/validity and accepted partner assignment reconcile;
- capacity and route eligibility are current and bound to the exact leg;
- warehouse receipt/QC/allocation/pick/handover preserve exact item/lot/quantity without oversell;
- customs-required routes have non-empty effective rules, licensed broker, independent review and separate official authority release;
- only the assigned verified driver can execute the exact leg with current dispatch authorization;
- ordered trip events, custody transfers and verified POD bind to the same shipment/leg/partner;
- Operations, Customer, Partner and Enterprise show the same canonical lifecycle/version with freshness metadata;
- notifications are independently evidenced through provider delivery receipts and user preferences;
- Finance remains read-only/partner-direct and reconciles only explicitly authorized fee/payment states;
- every denial, mutation, approval and export has correct actor/tenant/resource scope and durable audit;
- duplicate, replay, retry, stale session, wrong tenant, wrong leg and injected dependency failure cases fail safely.

No E2E journey was executed in this gate; all criteria above remain NOT TESTED.

## 12. Readiness matrix

| Domain | Gate result | Reason |
|---|---|---|
| Shared identity / workspace authorization | FAIL / BLOCKED | Competing role authorities, uneven AAL/action checks, broad generic grants |
| Customer ↔ Partner quote/assignment | PARTIAL / BLOCKED | Good acceptance guards; no complete staging proof or live verified network |
| Canonical shipment and events | FAIL / BLOCKED | Legacy/canonical coexistence, silent fallback, no delivery proof |
| Warehouse ↔ Operations ↔ Driver | FAIL / BLOCKED | Reservation/pick integrity and legacy dispatch P0s |
| Customs ↔ Operations | FAIL / BLOCKED | Zero-check evaluator and direct gate-write P0s |
| Finance ↔ provider ↔ commercial | FAIL / BLOCKED | Captured-webhook collection-gate bypass |
| Enterprise aggregation | FAIL / BLOCKED | Organization relationship and tenant scope incomplete |
| Admin audit and export governance | FAIL / BLOCKED | Audit persistence not atomic; error-as-empty and export assurance gaps |
| End-to-end staging verification | NOT TESTED | No synthetic cross-workspace E2E was run |

## 13. Safety and release boundary

This gate was read-only. No Production or Staging SQL/RPC/function invocation, account or membership operation, role change, shipment/quote/assignment, warehouse stock/transfer/return, customs case/release, dispatch, driver event/POD, payment/refund/payout, provider webhook, notification, external communication, export or deployment was executed. Historical live counts were not refreshed. Static inspection does not establish the deployed function version or current runtime behavior.

**Final: C3.29 FAIL / BLOCKED.** KRIM should remain in controlled preparation and isolated verification mode. Do not onboard users into workflows represented as operationally complete, and do not claim a verified end-to-end logistics service until the exact route/service has passed the above acceptance criteria with real verified partners and lawful operational permissions.
