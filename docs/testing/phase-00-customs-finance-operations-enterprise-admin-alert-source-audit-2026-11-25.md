# Phase 00 — Customs, Finance, Operations, Enterprise and Admin alert-source audit

**Date:** 2026-11-25  
**Environment:** QA-branch application source review; no authenticated browser/runtime tests  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Result:** These workspaces contain useful secured operational registers and audit/exception records, but this pass did not establish a unified user notification inbox, recipient fan-out, unread/read lifecycle or provider-backed delivery for any of the five ecosystems.  
**Safety:** Static source inspection only. No user session was created, no records were changed, no support replies/acknowledgements were submitted, and no provider or worker was invoked.

## 1. Customs

### Protected live-workspace access gate
File: `app/customs/secure-workspace.js`

Source-confirmed access sequence:
- Supabase session required.
- AAL2 MFA assurance required.
- Active organization membership queried for current user.
- Organization type must be `customs` and organization status active.
- `krim_has_permission(..., 'compliance.view')` must return true for at least one eligible organization.
- The page exposes only the verified user and eligible organization IDs to the customs workspace.

This is a strong access-gate source pattern. It is not a notification path.

### Customs case preview
File: `app/customs/staging/cases.html`

The staging case page explicitly says no sign-in, no live customs data and no customer records. It is a design/navigation preview. The protected customs workflows use a separate gate.

### Finding C-01
Customs case, declaration, broker, document and audit workflows exist, but no source evidence in this pass shows customs query/hold/document-required/clearance events being routed to authorized broker, customer or operations recipients and delivered through a notification feed/provider.

**Status:** Protected workspace access source-confirmed; alert/notification delivery NOT EVIDENCED.

## 2. Finance

### Finance command centre
File: `app/finance/index.html`

The page describes itself as a controlled, read-only finance workspace. It states the current partner-direct launch model: customers pay the contracting logistics provider directly; KRIM does not collect freight funds, hold escrow, split settlements or execute partner payouts. It also warns that unmatched/unprocessed provider webhooks must be reconciled before any future provider enablement.

The workspace loads finance records for authorized users, but no notification feed, unread/read lifecycle or real-time finance alert subscription was identified in this page/source pass.

### Partner settlements
File: `app/finance/partner-settlements.html`

The partner payable register is explicitly temporarily unavailable while partner-only visibility and finance-role authorization are corrected at database level.

### Finding F-01
Financial records and event-posting orchestration exist elsewhere, but invoice issued/overdue, refund decision, payment failure, settlement hold/paid and reconciliation exception events have not been shown to produce role-scoped user notifications with delivery receipts.

**Status:** Finance data workspace is controlled/read-only by source statement; partner settlement register unavailable; finance notifications NOT EVIDENCED.

## 3. Operations Control Tower

### Exception management
File: `app/operations/exception-management.html`

Source-confirmed:
- Authenticated session required.
- Active organization membership queried and restricted to active Operations organizations.
- Reads `krim_exceptions` and `krim_exception_escalations` for authorized organization scope (the page relies on database policies/RPCs for final scope).
- Acknowledgement calls a server RPC and requires a factual review note.
- Resolution is deliberately disabled until backend closure controls prove evidence, corrective actions and escalation timers.
- The page explicitly states notifications remain subject to verified delivery configuration.
- Operational preparation form validates browser fields only and does not save records.

This is a live operational exception/escalation register, not a notification inbox. No real-time channel, unread state, recipient routing or provider delivery is established.

### Finding O-01
Exception/escalation records and acknowledgement workflow are present, but a notification to the assigned owner/on-call operations team and escalation delivery/acknowledgement SLA are not proven.

**Status:** Operational register source-confirmed; notification routing/delivery NOT EVIDENCED.

## 4. Enterprise

### Enterprise live data workspace
File: `app/enterprise/enterprise-live.js`

The workspace provides authenticated database-backed views, including organization membership, quote, shipment and audit-event datasets. Its institutional-memory view is described as audit-event summaries and suppresses raw metadata/sensitive snapshots.

### Financial approvals
File: `app/enterprise/approvals.html`

Source-confirmed:
- Requires a signed-in user.
- Queries active organization memberships.
- Requires an Enterprise organization.
- Loads financial approval requests scoped to those organization IDs.
- Loads related approval event history by request IDs.
- This page is an approval register/event history, not a notification feed.

No source evidence in this pass established invitation, role change, approval pending/decided, consolidated billing or SLA events being routed to enterprise administrators/operations/finance contacts through a live notification channel.

### Finding E-01
Enterprise governance and approval history are present, but actionable notifications and delivery status for enterprise roles are NOT EVIDENCED.

**Status:** Enterprise registers source-confirmed; notification inbox/dispatch NOT EVIDENCED.

## 5. Platform Admin

### Support desk
File: `app/platform-admin/support-desk.html`

Source-confirmed:
- Requires an authenticated session.
- Loads support queue via `krim_admin_list_support_tickets`.
- Loads a ticket thread via `krim_admin_get_support_ticket_thread`.
- Replies and transitions status through dedicated admin RPCs.
- Supports internal replies/notes.

This is an operational support queue. It does not establish a notification inbox, admin on-call routing, unread state or delivery receipts.

### SIEM page
File: `public/admin/siem-audit-logs.html`

The page explicitly states that no verified SIEM event stream or immutable hash validation is connected, and that no event rows, actor identities, source IPs, timestamps, severity classifications, integrity proofs or forensic exports are available from the page.

### Finding A-01
Admin support operations exist, but security-event alert routing and verified SIEM/on-call notification delivery are not connected in the inspected source. The earlier database finding that support ticket creation notifies only the earliest legacy admin remains a separate legacy in-app path and is not equivalent to modern role/on-call routing.

**Status:** Support queue source-confirmed; SIEM event stream explicitly disconnected; unified admin alert delivery NOT EVIDENCED.

## 6. Five-ecosystem coverage matrix

| Ecosystem | Secured operational data source | Alert/inbox source | Recipient routing | Provider-backed delivery |
|---|---|---|---|---|
| Customs | Protected AAL2 customs workspace and case workflows | Not identified in this pass | Not proven | Not proven |
| Finance | Controlled read-only finance registers; settlements currently unavailable | No unified finance feed identified | Not proven | Not proven |
| Operations | Exception/escalation register and acknowledgement RPC | Operational register, not inbox | Assigned/on-call routing not proven | Not proven |
| Enterprise | Membership, shipment, audit and approval registers | Approval event history, not inbox | Enterprise role routing not proven | Not proven |
| Platform Admin | Support queue; SIEM page explicitly disconnected | Support queue, not unified inbox | Legacy first-admin trigger only; modern on-call routing not proven | Not proven |

## 7. Consolidated notification architecture gaps

Across the inspected workspace implementations, the following capabilities remain unproven:
1. A common server-authoritative notification feed API/RPC.
2. Role- and organization-scoped recipient fan-out for all nine ecosystems.
3. Stable event IDs and database-enforced idempotency across legacy and canonical paths.
4. Unread counts, pagination, mark-read and mark-all-read semantics for all workspaces.
5. Real-time subscriptions or bounded polling with reconnect/missed-event recovery.
6. Provider-backed outbox dispatch, verified delivery callbacks and accurate delivery states.
7. Escalation/on-call routing for operational, finance and platform-security incidents.
8. User-visible delivery receipts and safe failure/retry/dead-letter handling.
9. Staging synthetic-user tests for same-organization, cross-organization, revoked-membership, multiple-role, duplicate-event and provider-failure cases.

## 8. Release decision

- Customs access gate: **SOURCE-CONFIRMED PARTIAL PASS; runtime authorization not tested**.
- Customs alerts: **NOT EVIDENCED**.
- Finance workspace: **CONTROLLED READ-ONLY SOURCE; notifications NOT EVIDENCED**.
- Operations exceptions: **OPERATIONAL REGISTER SOURCE-CONFIRMED; notifications NOT EVIDENCED**.
- Enterprise approvals: **REGISTER/EVENT HISTORY SOURCE-CONFIRMED; notifications NOT EVIDENCED**.
- Platform support: **SUPPORT QUEUE SOURCE-CONFIRMED; SIEM stream explicitly disconnected; alert routing NOT EVIDENCED**.
- Complete nine-ecosystem notifications: **NO-GO / NOT PROVEN**.

## 9. Next Phase 00 work

1. Finish static tracing of remaining page-level event producers and the deployed notification provider/retry Edge Functions.
2. Reconcile the legacy in-app notification table with the canonical event/outbox model and select a single idempotent source of truth.
3. Produce a unified notification event, recipient, priority, channel, consent, delivery-state and escalation contract.
4. Build the staging-only synthetic-user test matrix. Do not create Production test rows or send real communications.
5. Only then implement and verify the notification path in staging, with external provider calls disabled until a controlled sink is proven.

**No Production changes or external communications were made.**
