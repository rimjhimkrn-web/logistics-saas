# KRIM Founder & Admin Acquisition Workspace Audit
**Date:** 16 November 2026  
**Scope:** Read-only review of the founder/admin enquiry desk, platform-admin Edge Function, MFA guard, prospect review, acquisition command and performance pages, relevant production RLS/grants/constraints, and live acquisition record counts.

## Executive decision
**The secured enquiry desk is implemented and has a credible server-side admin gate, but the broader founder acquisition workspace is only partially operational.** An authorized platform administrator can load the inbound enquiry queue, update an enquiry status, and record internal follow-up notes through the restricted `global-admin-control` Edge Function. The page does not provide a complete lead ownership, qualification, conversion or revenue workflow.

No test enquiry was submitted. No customer or partner records were created. No contact, email, Telegram or marketing messages were sent. No production data, policies, functions or schema were changed.

## 1. Production state

| Record family | Production rows |
|---|---:|
| Public contact enquiries | 0 |
| Customer acquisition profiles | 0 |
| Customer acquisition events | 0 |
| Customer qualification cases | 0 |
| Inquiry follow-up history | 0 |

These are current read-only counts. The workspace has no real lead records to demonstrate the full operational journey.

## 2. Enquiry Desk: working implementation

File: `public/growth/enquiry-management.html`

The page:
- Uses `auth/krim-admin-guard.js` before revealing the protected body.
- Calls `global-admin-control` for the inquiry queue and follow-up history.
- Displays contact name, organisation, email, source, enquiry message and privacy-consent evidence.
- Allows status values: `new`, `in_review`, `responded`, `closed`, `spam`.
- Allows an administrator to append an internal follow-up note, optional follow-up time and outcome (`pending`, `contacted`, `qualified`, `not_interested`, `converted`).
- Escapes values before inserting them into HTML.
- Explicitly warns that a converted note is not proof of a verified booking or revenue.

The page's queue and history are read from the backend, not hard-coded demo data.

## 3. Admin API security

Production `global-admin-control` is ACTIVE version 27 with platform JWT verification enabled.

The checked-in function source requires:
1. A bearer token.
2. A valid authenticated user.
3. Current MFA assurance level AAL2.
4. An active global role assignment with role code `platform_admin` or `platform_superadmin`.

It then uses a service-role Supabase client for restricted reads and writes. The public inquiry table has an explicit deny policy for anon and authenticated clients. Authenticated users have no direct SELECT grant on the inquiry table; the admin function is the intended privileged access path.

The role-assignment SELECT policy only exposes the current user's own assignments to authenticated clients. The admin function performs its role lookup server-side.

**Important limitation:** the GitHub source was reviewed, but the deployed version-27 function source was not successfully retrieved for byte-for-byte parity verification. Production activation/version metadata is known; exact deployed-source parity is not established by this audit.

## 4. Critical admin workflow gaps

### P0-A — Audit writes are best-effort, not guaranteed
The Edge Function's `audit()` helper inserts into `krim_audit_events` but does not check or throw on the insert error. The API can return `ok:true` after a status or follow-up change even if the audit insert failed. The frontend then displays “audit event recorded”.

**Impact:** the user interface can claim an action was audited when no audit row was committed. This breaks the assurance expected for changes to lead status and contact history.

**Required correction:** make business write + audit event atomic (prefer one transaction/RPC), or fail the operation when the audit write fails and safely reconcile any partial write. Store previous and new state, actor, timestamp, request ID and event ID. Verify audit immutability and idempotency. Do not merely add a second non-atomic insert.

### P0-B — The admin workspace has no lead ownership or assignment
The inquiry page has no owner, queue assignment, team hand-off, SLA, priority, due-date escalation or reassignment workflow. The follow-up table records who created a note, but it is not an owner/assignment model.

**Impact:** as enquiry volume grows, the founder cannot reliably see who is responsible for each lead, which leads are overdue, or whether a follow-up was completed by the responsible person.

**Required correction:** add a tenant-independent platform lead ownership model with an authorised assignment/reassignment action, immutable assignment history, due/overdue state and SLA escalation. Keep contact data restricted to authorised staff.

### P0-C — Qualification and conversion are notes, not a verified lifecycle
The UI lets the administrator select “qualified” or “converted” as a follow-up outcome. It does not update a canonical qualification case, verify customer account/organisation creation, bind the inquiry to a customer, or require completed shipment evidence before reporting conversion.

**Impact:** follow-up outcomes can be mistaken for actual customer conversion. The current UI does display a warning, but the data model does not enforce that distinction.

**Required correction:** keep activity outcome separate from lifecycle state. A qualified lead requires a reviewed qualification case; a converted customer requires a verified user/organisation binding; a first completed customer transaction requires the actual shipment completion evidence. Revenue must be separately recognised only after the independently agreed KRIM service fee is earned and received.

### P1-A — Follow-up scheduling accepts past timestamps
The admin Edge Function parses a supplied `follow_up_at` value but does not reject past times. The separate `krim_admin_schedule_inquiry_followup` RPC does reject past times, but the current page calls the Edge Function's `add_inquiry_followup` action instead.

**Impact:** the UI may create an immediately overdue reminder when the user intended to schedule a future action. The two write paths have inconsistent validation and behaviour.

**Required correction:** use one canonical follow-up write path. Validate a future timestamp, timezone interpretation, sensible maximum scheduling horizon and outcome in the backend. Permit explicit overdue/backdated activity only as a separate recorded activity type, not as a scheduled reminder.

### P1-B — Follow-up write paths behave differently
The SQL RPC `krim_admin_schedule_inquiry_followup` inserts a pending follow-up and changes a new inquiry to `in_review`. The UI's Edge Function action inserts a follow-up and writes an audit event but does not update the inquiry status.

**Impact:** the same action can produce different pipeline state depending on which API is used.

**Required correction:** consolidate to one canonical API and transaction. Ensure follow-up activity and inquiry status remain consistent.

### P1-C — Status changes lack transition and reason controls
The admin endpoint accepts any of the five allowed statuses from any current state. It records the new status in audit metadata but does not include the prior state or require a reason for closing, marking spam, or moving to responded.

**Required correction:** define permitted transitions, require a closure/spam reason, preserve old/new state, and prevent silent reopening or loss of context. Status must not be used as a substitute for qualification or conversion.

### P1-D — Follow-up queue and reminders are not a full work queue
The page loads up to 500 follow-up records and displays history. It does not show a dedicated due-today/overdue queue, filter by owner, or show completion status and escalation state. Existing cron processing of due inquiry reminders is not evidence of a usable owner work queue or delivered notification.

**Required correction:** expose a secure due/overdue queue, owner filter, timezone-aware display, reminder state, retry/dead-letter visibility and a human action completion state.

## 5. Other acquisition pages are not live operating tools

| Page | Current behaviour |
|---|---|
| `public/growth/acquisition-command.html` | Reads a count of `krim_growth_opportunities` under the current session; it does not show the canonical enquiry/qualification/conversion funnel. |
| `public/growth/acquisition-performance.html` | Explicit template; metrics are not connected to live data. |
| `public/growth/prospect-review.html` | Explicit draft-only form; does not save to Supabase or load a review queue. |
| `public/growth/customer-acquisition.html` | Restricted growth overview with live counts for sources, signals, opportunities, enquiries and partner opportunities, but does not provide the actual lead work queue or verified conversion evidence. |

The existence of a page, a configured source, or a growth opportunity is not proof of a prospect, qualified customer, booking or revenue. Do not present the performance template as a live dashboard.

## 6. Privacy and access notes
- The enquiry table denies direct anon/authenticated client access.
- The admin function enforces AAL2 and platform role checks in its checked-in source.
- The admin guard also calls the protected admin function before making the page visible.
- The UI escapes user-supplied contact and message values before rendering.
- The follow-up history table has service-role table grants in the inspected production grant list; direct authenticated access is not provided.
- The platform admin API uses a service-role client; every action must remain behind its explicit action-level authorization and MFA check.
- Audit event insert failure is currently not propagated to the caller (P0 finding above).
- Follow-up records cascade-delete when an inquiry is deleted; confirm whether that retention behaviour is compatible with the required audit/retention policy before allowing inquiry deletion. No deletion action was tested.

## 7. Required staging acceptance tests
1. Anonymous request to admin function is rejected.
2. Authenticated AAL1 user is rejected.
3. AAL2 user without platform admin role is rejected.
4. AAL2 platform admin can load inquiry queue and history.
5. Customer, partner and unrelated tenant users cannot load or mutate inquiries.
6. A status update writes exactly one immutable audit event in the same transaction; simulate audit insert failure and prove the status update does not falsely report success.
7. Status transition matrix rejects invalid transitions and requires reason for terminal states.
8. Follow-up write rejects past scheduled timestamps and invalid timezone/date input.
9. One canonical follow-up endpoint is used by UI and worker; status transition and history remain consistent.
10. Concurrent double-click/retry creates one action or safely identifies duplicate request.
11. Lead assignment requires platform permission and writes old/new owner audit history.
12. Owner sees only permitted assigned work; other users cannot infer private lead details.
13. Due/overdue queue handles timezone boundaries, daylight saving where relevant, retries and dead letters.
14. Qualification outcome creates/updates one canonical qualification case, not a free-text claim.
15. Customer conversion requires a real user and active organisation binding.
16. Completed customer activation requires verified service/booking/shipment evidence.
17. Revenue reporting excludes gross freight value and includes only separately agreed KRIM service fees earned and received.
18. Empty queues render honestly without demo counts or false delivery claims.

## 8. Next implementation sequence
1. Recover and reconcile production migration history/schema source (existing global blocker).
2. Define canonical lead lifecycle, ownership, assignment history, activity model and status transition matrix.
3. Consolidate follow-up writes and atomic audit transaction.
4. Build secure owner-based founder queue and due/overdue worklist.
5. Bind qualification and customer conversion to actual customer organisation evidence.
6. Connect acquisition performance dashboard to canonical event-backed metrics.
7. Run staging tests with seeded synthetic records and two distinct admin roles.
8. Only after passing, schedule controlled production release and post-deploy verification.

## 9. Scope and limitations
Read-only review of production counts, table columns, RLS policies, grants, constraints and function definitions; checked-in admin Edge Function, admin guard and growth pages. No admin session was used to view customer PII. No test enquiry or synthetic record was created. No follow-up, status change, role change, notification or external communication was made. No production schema or data was changed. Deployed version-27 source parity was not verified.

**Decision:** enquiry desk access control and core queue actions are implemented in the repository, but founder acquisition operations are not yet production-ready as a complete CRM/work queue. Audit atomicity, ownership, lifecycle evidence and canonical follow-up behaviour must be corrected first.
