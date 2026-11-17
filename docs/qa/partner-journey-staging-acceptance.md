# KRIM Partner Journey — Staging Acceptance Test Plan

**Environment:** Staging only  
**Branch:** `ai/partner-gateway-warehouse-routing`  
**Status:** Test plan prepared; browser end-to-end execution not yet performed  
**Production:** No deployment or production data changes

## Safety rules

- Use only a dedicated test email/account and non-production documents.
- Do not upload real PAN, Aadhaar, bank statements, GST certificates or sensitive personal documents to a test environment.
- Do not use a real customer shipment, live freight transaction or real payment.
- Keep India and all markets inactive until legal/operational activation gates are approved.
- Do not mark any partner verified or commercially eligible merely to make a test pass.
- Record screenshots and timestamps without exposing secrets, OTPs, access tokens or full identity documents.

## Test accounts and roles required

1. Partner applicant — registered logistics business pathway.
2. Partner applicant — individual-interest pathway.
3. Partner applicant — development/test pathway.
4. Platform administrator — MFA/TOTP enrolled, AAL2 session, `admin.platform` permission.
5. Optional second administrator/reviewer — required to test reviewer independence and prevent self-approval.

Use separate test identities for applicant and reviewer. An applicant must not approve their own case.

## Acceptance sequence

### A. Entry and account creation

- [ ] Open partner gateway in Staging.
- [ ] Confirm registered-business, individual-interest and development/test routes are visible and correctly labelled.
- [ ] Create a registered-business test account.
- [ ] Confirm duplicate/invalid email handling and required-field validation.
- [ ] Confirm email confirmation is required where configured.
- [ ] Open the confirmation link and verify the callback returns to the correct partner flow.
- [ ] Refresh and sign out/in; confirm organization provisioning is not duplicated.
- [ ] Confirm a user with no active partner organization cannot enter a commercial workspace.

**Pass condition:** account is authenticated, exactly one intended active partner organization is linked, and no commercial access is granted by signup alone.

### B. MFA and workspace routing

- [ ] Enrol TOTP MFA for the test partner.
- [ ] Confirm workspace entry is blocked until the required AAL2 level is present.
- [ ] Confirm the partner gateway routes the account to the matching account-mode workspace.
- [ ] Confirm a warehouse organization routes correctly.
- [ ] Confirm multiple active partner organizations do not silently select an arbitrary organization.
- [ ] Confirm sign-out returns to partner sign-in.

**Pass condition:** only the correct authenticated organization workspace opens, with server-side permissions still enforced.

### C. Verification submission

- [ ] Enter test business identity and operational details.
- [ ] Upload synthetic PDF/JPEG/PNG evidence to the private verification bucket.
- [ ] Confirm unsupported file types and files above the size limit are rejected.
- [ ] Confirm a partner cannot read another organization's evidence.
- [ ] Submit the verification application.
- [ ] Confirm status is pending and commercial functions remain restricted.
- [ ] Confirm failed submission/refresh does not delete evidence already committed to the case.

**Pass condition:** a pending case is created with organization-scoped private evidence and a durable audit trail.

### D. Independent admin review

- [ ] Sign in as a separate administrator with MFA/AAL2.
- [ ] Confirm a non-admin and an admin without AAL2 cannot access the review queue.
- [ ] Open the pending case and preview evidence through a short-lived signed URL.
- [ ] Confirm the applicant cannot approve their own case.
- [ ] Test request-information with a clear note; confirm the partner sees the exact request.
- [ ] Resubmit corrected synthetic evidence; confirm the same case is reopened/updated according to the intended workflow.
- [ ] Test rejection with a valid reason.
- [ ] Test approval only with valid evidence and independent reviewer.
- [ ] Confirm every decision creates an audit event and updates the partner-visible state.

**Pass condition:** only an authorized independent reviewer can decide; every decision is traceable and the partner receives the correct status.

### E. Capability, service area and capacity

- [ ] Confirm unverified/non-compliant partners cannot submit commercial service areas.
- [ ] Confirm India service-area submission remains blocked while India is inactive or has no active market/location.
- [ ] Confirm the service-coverage page refuses to silently select an organization when the signed-in user has multiple active partner organizations; the intended organization must be selected explicitly.
- [ ] Confirm the service-coverage page lists only active partner organizations belonging to the signed-in user, requires an explicit choice when there are multiple, and remembers the choice for the current browser session.
- [ ] Tamper with or retain a stale selected organization ID; confirm it is ignored unless that ID is still present in the user's active partner memberships, and the chooser is shown again.
- [ ] Confirm capability registration is locked unless the selected organization is an active registered business with approved verification, active lifecycle and current compliance.
- [ ] Confirm only active KRIM transport modes and countries can be selected; an inactive country such as India must not be selectable.
- [ ] Submit one to five valid PDF/JPEG/PNG evidence files (maximum 10 MB each); confirm files are uploaded under the selected organization/user capability folder and the database RPC creates a pending, inactive capability.
- [ ] Confirm capability submission rejects invalid service types, inactive country/mode IDs, invalid weight, malformed evidence paths, missing evidence objects, oversized details and duplicate pending capability requests.
- [ ] Confirm an uncertain RPC response is not blindly retried; uploaded evidence is retained for reconciliation when the database outcome is unknown.
- [ ] Confirm a successful submission appears in the selected organization's capability registry as pending and inactive, with evidence count and details saved.
- [ ] Confirm another organization cannot read or manage the submitted capability or its private evidence.
- [ ] Confirm capacity registration is locked unless the selected registered-business partner is active, independently verified and compliant, has at least one active verified capability, and an active KRIM network lane is available.
- [ ] Confirm the lane dropdown contains only active lanes whose origin location and transport mode are present in the active KRIM catalogues.
- [ ] Register a real vehicle/equipment/facility resource with finite positive capacity, supported units, future start/end timestamps, and one to five valid evidence documents; confirm evidence paths use the required organization/user/capacity-UUID filename format.
- [ ] Confirm the lane-specific RPC rejects an inactive lane, mismatched origin, mismatched transport mode, unverified capability, invalid resource type, invalid capacity, invalid time window, duplicate/missing evidence, and evidence outside the partner's private folder.
- [ ] Confirm successful registration creates a resource in pending_review and a linked availability row in unavailable status; no assignment/matching must use it before independent review.
- [ ] Confirm the resource and availability rows appear only within the selected organization's inventory, and no other partner organization can read them.
- [ ] Simulate a lost/uncertain RPC response; confirm the UI instructs reconciliation and does not automatically submit a duplicate resource.
- [ ] In a separate test jurisdiction only, submit a test capability and service area with valid synthetic evidence.
- [ ] Submit a verified resource and availability window.
- [ ] Confirm unverified, expired, inactive, insufficient-capacity or mismatched-lane resources do not qualify.
- [ ] Confirm enough verified capacity is required for the requested units.
- [ ] Test held and confirmed reservations reduce remaining capacity.
- [ ] Test overlapping/concurrent matching attempts and ensure capacity cannot be overbooked.
- [ ] Test invalid dates/time zones and confirm the system fails closed.

**Pass condition:** matching never returns a partner as eligible without approved service capability, active route/market, current evidence and sufficient verified capacity.


### E7. End-to-end partner eligibility gates

- [ ] Confirm an organisation without active verified capability is excluded from matching and cannot submit/award quotes.
- [ ] Confirm a verified capability alone, without an independently approved active service area, is excluded from matching.
- [ ] Confirm service-area coverage must match the exact origin and destination location (country, active market or location scope), service type and transport mode.
- [ ] Confirm inactive, rejected, pending, expired or not-yet-effective service areas do not contribute coverage.
- [ ] Confirm a country with a non-approved or overdue operating pack cannot contribute matching coverage.
- [ ] Confirm partner organisation must be active, registered-business, currently compliant and verified.
- [ ] Confirm a partner must have verified available capacity on an active exact route lane and date, with reservations deducted.
- [ ] Confirm expired capacity or a capacity reservation created after matching prevents a later award/assignment.
- [ ] Confirm shipment-wide and leg-specific matching apply the same service-area and capability gates.
- [ ] Confirm no-candidate results are explicit and do not create a partner quote, award or assignment.
- [ ] Confirm positive matching with a real, independently approved partner, route, capability, evidence and capacity fixture.
- [ ] Confirm negative cases for missing endpoint coverage, wrong mode, wrong service type, inactive country pack, insufficient weight, expired availability and over-reserved capacity.

**Pass condition:** no partner is represented as eligible or awarded unless current compliance, verified capability, independently approved endpoint service areas, active operating-pack status and sufficient verified route capacity all agree.

### E6. Platform-admin service-area review workspace

- [ ] Confirm unauthenticated users cannot see the protected queue or review controls.
- [ ] Confirm privileged admin access gateway rejects users without platform-admin role and MFA/AAL2.
- [ ] Confirm queue displays only `draft` / `pending_review` declarations and shows partner, geography, service, mode, effective dates, submitter, notes and evidence count.
- [ ] Confirm filter works on the rendered queue without changing database records.
- [ ] Preview each evidence file through a private signed URL that expires after 60 seconds; confirm missing/foreign paths fail closed.
- [ ] Confirm approval requires a rationale of at least 10 characters and rejection at least 5; both are capped at 1,000 characters.
- [ ] Confirm administrator who submitted the request cannot approve it.
- [ ] Confirm approval failure when partner compliance, country operating pack, geography, capability or evidence gates are not satisfied.
- [ ] Confirm rejection preserves exact reviewer reason, identity and timestamp; partner can see the reason.
- [ ] Confirm success message is shown only after the RPC returns the matching request ID and decision.
- [ ] Confirm queue refresh removes reviewed records and no duplicate decision is possible on a non-pending record.

**Pass condition:** a privileged administrator can review evidence and make a reasoned, audited decision; no service-area declaration becomes active through partner self-service.

### E5. Partner service-area submission, review feedback and resubmission

- [ ] Confirm only active, verified, compliant registered-business partners with active manager permission can submit.
- [ ] Confirm country, market and location scopes must be active and consistent; inactive country/market/location and inactive transport modes are rejected.
- [ ] Confirm one to five evidence files are uploaded to the private organisation/user service-area folder and verified as owned by the submitter.
- [ ] Confirm submission creates one `draft` row with `workflow_status=pending_review`, a submitter identity, evidence references and an audit event; it is not operational coverage.
- [ ] Confirm a matching duplicate pending request is blocked.
- [ ] As an independent AAL2 platform administrator, approve or reject with a valid rationale; submitter cannot approve own request.
- [ ] Confirm approval requires an active compliant registered-business organisation, approved current country operating pack, active matching market/location/mode, matching active verified capability and valid private evidence.
- [ ] Confirm approval sets the service-area row active and workflow approved; rejection closes the row and stores the exact reviewer reason, identity and timestamp.
- [ ] Confirm partner view shows the review decision, exact reason, review timestamp and correction count.
- [ ] Confirm only the original submitter can select their own rejected request for correction; prefilled scope and service details match the rejected record.
- [ ] Upload replacement evidence and resubmit; confirm same service-area ID is reused, prior review metadata is retained in `resubmission_history`, current review fields are cleared and workflow returns to pending review.
- [ ] Confirm resubmission writes `partner.service_area.resubmitted` audit event and duplicate pending request checks exclude only the same record.
- [ ] Confirm another user, another organisation, non-rejected record, inactive membership, missing permission, invalid scope, invalid dates and foreign/missing evidence are rejected.
- [ ] Confirm failed submission/resubmission does not change the original row or prior review history.

**Pass condition:** the partner declaration remains non-operational until independently approved; rejected declarations can be corrected without duplicate records or loss of audit history.

### E4. Rejected capacity correction and resubmission

- [ ] As the original submitting partner, confirm only your own rejected resources appear in the correction selector; another organisation member cannot resubmit a resource they did not submit.
- [ ] Select a rejected resource and confirm its saved resource fields, availability window and original lane are loaded for correction.
- [ ] Correct the requested fields, upload one to five replacement evidence files, and submit.
- [ ] Confirm the same resource ID and linked availability ID are reused; no duplicate resource is created.
- [ ] Confirm the resource returns to `pending_review` and availability remains `unavailable` until an independent administrator approves it.
- [ ] Confirm the previous rejection decision, reason, reviewer and timestamp are retained in `resubmission_history`; the current review fields are cleared.
- [ ] Confirm the audit log records `partner.capacity_resource.resubmitted`.
- [ ] Confirm the RPC rejects another user's resource, a non-rejected resource, inactive membership, missing permission, non-compliant organisation, unverified capability, inactive/mismatched lane, invalid capacity/date and missing/foreign evidence.
- [ ] Confirm a failed submission does not change the rejected resource or its prior review history.

**Pass condition:** correction updates the original rejected record, preserves the prior decision history, and never makes the resource bookable before a fresh independent review.

### E3. Partner-facing capacity status and review feedback

- [ ] Sign in as a partner with one active registered-business organization and confirm only that organization's resource, availability and commitment rows are visible.
- [ ] Sign in as a partner with multiple active partner organizations; require an explicit organization choice before loading or registering resources, and verify a stale/tampered organization ID is rejected.
- [ ] Confirm each resource displays its backend status and the recorded verification state.
- [ ] After an administrator requests/rejects a resource with a reason, confirm the partner sees the exact recorded `metadata.review_reason`, review decision and review timestamp.
- [ ] Confirm no feedback is fabricated when no review reason exists.
- [ ] Confirm resource and linked availability rows remain organisation-scoped and RLS denies cross-organisation reads.
- [ ] Confirm partner cannot alter review state or reviewer feedback through the page or direct client writes.
- [ ] Confirm refresh reflects the latest database state after an administrator decision.

**Pass condition:** a partner can understand the actual recorded resource decision and reviewer feedback, without gaining any approval or availability override.

### E2. Independent capacity-resource review

- [ ] Open the dedicated platform-admin capacity review workspace.
- [ ] Confirm anonymous users and authenticated non-admin users cannot load the queue.
- [ ] Confirm a platform admin without AAL2 is denied by the backend.
- [ ] Confirm an AAL2 platform admin can load only pending-review resources.
- [ ] Confirm each resource displays its organisation, partner lifecycle/compliance state, mode, location, capacity, availability windows and linked availability records.
- [ ] Preview synthetic evidence using a 60-second signed URL; confirm private storage and cross-organisation access remain denied.
- [ ] Confirm the submitter cannot approve their own resource, including when the UI is bypassed and the RPC is called directly.
- [ ] Confirm approval is rejected if the organisation is not current/compliant, the matching transport capability is not independently verified, no future availability remains, or evidence is missing/invalid.
- [ ] Confirm approval updates the resource to available/verified and only future availability records to available; expired windows remain expired.
- [ ] Confirm rejection updates the resource to rejected and linked availability to unavailable.
- [ ] Confirm decisions require a 5–1000 character reason and create an immutable audit event.
- [ ] Confirm a failed/uncertain decision is not shown as successful and a refresh reconciles the actual database state.

**Pass condition:** only an independent AAL2 platform administrator can decide a pending resource; approval cannot bypass partner, compliance, capability, evidence or availability gates.

### F. Notifications

- [ ] Confirm in-app notification appears for relevant verification changes.
- [ ] Confirm only the intended authenticated user can read their notifications.
- [ ] Confirm mark-as-read affects only the user's own notification.
- [ ] Confirm refresh/polling does not create duplicates.
- [ ] Test email only after a dedicated Resend test key, verified sender/domain and cron secret are configured in Staging.
- [ ] Confirm email retries are idempotent and failed messages remain observable.

**Pass condition:** notification access is correctly scoped; email is not considered tested until a real test email is received and delivery status is confirmed.

### G. Negative and security tests

- [ ] Anonymous access to private partner documents is denied.
- [ ] Cross-organization document reads are denied.
- [ ] Non-admin queue reads/writes are denied.
- [ ] Authenticated users cannot directly insert admin decisions or notifications.
- [ ] Partner cannot self-approve or alter verification status directly.
- [ ] Stale/expired signed evidence links stop working.
- [ ] Malformed RPC inputs fail closed.
- [ ] Audit events cannot be modified by ordinary partner users.
- [ ] No freight collection, split settlement, payout or live payment is triggered in this test journey.

## Current execution record

| Area | Current evidence | Status |
|---|---|---|
| Partner routing and UI code | Changes present in open draft PR #68 | Implemented in branch; browser acceptance pending |
| Email confirmation callback/provisioning | Code changes present in PR #68 | Implemented in branch; browser acceptance pending |
| MFA/AAL2 gates | Existing flow and PR changes | Browser acceptance pending |
| Private verification storage and RPCs | Staging migrations/policies previously inspected | Database-level checks performed; browser upload/read test pending |
| Independent admin review | Backend guards and UI present | Browser acceptance pending |
| Service-area workflow | UI/RPC present; Staging has zero service-area rows | No positive end-to-end test |
| Capacity matching | Private eligibility helper and matching gate present | Definition/negative-input checks performed; positive/negative fixture tests pending |
| In-app notifications | Page and RLS grants present | Browser acceptance pending |
| Resend email | Worker deployed to Staging; secrets/cron/test email not configured | Not operationally tested |
| India market activation | Country inactive; pack `research_pending`; no source records | Correctly blocked |

## Release gate

Do not merge PR #68 or deploy to Production until:
- All applicable tests above pass with recorded evidence.
- Any failed test is fixed and rerun.
- Security review covers RLS, RPC grants, storage policies and service-role functions.
- Capacity/date/time-zone and concurrency tests pass.
- The India legal/market activation gates are separately satisfied.
- The owner explicitly approves release.


### E8. Partner assignment acceptance and physical capacity reservation

- [ ] Confirm only an active, verified, compliant registered-business partner with the exact awarded quote/opportunity/leg binding can accept an offer.
- [ ] Confirm accepting an assignment for a customer-confirmed shipment does not mark the shipment assigned before a verified vehicle/weight capacity reservation exists.
- [ ] Confirm the accepted partner can reserve capacity only for its own assignment, exact shipment leg, active route lane, verified resource and overlapping future departure/arrival window.
- [ ] Confirm reservation checks both availability capacity and underlying resource capacity, subtracting overlapping held (unexpired) and confirmed reservations.
- [ ] Run concurrent reservation attempts against the same resource/window; confirm row locks prevent overbooking and one attempt fails when remaining capacity is insufficient.
- [ ] Retry with the same idempotency key; confirm the existing reservation/binding is returned and capacity is not counted twice.
- [ ] Reuse an idempotency key for another shipment leg; confirm the RPC rejects it.
- [ ] Confirm no suitable verified capacity leaves the assignment accepted but the shipment unassigned, with a clear next step to reserve capacity.
- [ ] After a valid reservation, confirm a customer-confirmed shipment is finalized and the assignment becomes active; a shipment still awaiting customer quote acceptance remains deferred.
- [ ] Reject/cancel/fail an assignment after reservation; confirm linked reservation and binding are released exactly once and capacity becomes available again.
- [ ] Confirm expired holds and their bindings transition to expired and no longer consume capacity.
- [ ] Confirm a failed reservation creates no orphan confirmed reservation or binding and leaves the assignment retryable.
- [ ] Confirm capacity reservation and assignment transitions create traceable reservation, binding and audit events.

**Pass condition:** partner acceptance alone cannot make a shipment operationally assigned; assignment finalization follows a successful, exact, verified physical capacity reservation, with idempotent retries and release on terminal outcomes.


### E8 implementation record

| Control | Staging evidence | Status |
|---|---|---|
| Acceptance defers confirmed shipment without physical reservation | Partner response RPC now checks for a confirmed reservation/binding before finalization | Definition verified |
| Reservation completes assignment finalization | Reservation RPC invokes assignment finalizer after creating the verified binding for a confirmed shipment | Definition verified |
| Reservation authorization | Authenticated execute granted; anon execute denied | Grant check passed |
| Positive capacity reservation / concurrency / idempotency | Staging has no verified resource fixtures | Not end-to-end tested |
| Release / expiry lifecycle | Existing terminal-status release trigger and expiry worker identified | Needs fixture-based lifecycle test |


### E8 partner interface follow-up

- [ ] Sign in as an eligible partner and load the Shipment & Job Management page.
- [ ] Confirm assignment capacity state loads through `krim_partner_list_assignment_capacity_states` without direct table SELECT grants.
- [ ] Confirm a confirmed binding + confirmed reservation displays as reserved.
- [ ] Confirm released/expired binding or reservation is not displayed as currently reserved and the accepted assignment offers a new scheduling action.
- [ ] Confirm a user from another organization cannot retrieve assignment capacity state by guessing assignment IDs.
- [ ] Confirm a user with no active membership cannot retrieve assignment capacity state.
- [ ] Confirm browser refresh preserves the authoritative binding/reservation state.

**Implementation note:** the partner job page now reads capacity state through a SECURITY DEFINER RPC that checks active organization membership and limits results to supplied assignment IDs. Authenticated EXECUTE is granted; anon EXECUTE is denied. Direct SELECT on reservation tables remains denied.

### E9. Terminal assignment capacity release

- [ ] On rejected/cancelled/completed/failed assignment transition, confirm legacy shipment-weight commitment is released even without a modern capacity binding.
- [ ] With a held or confirmed modern reservation, confirm the linked reservation and binding are released exactly once.
- [ ] Confirm release events and audit events identify the assignment and terminal reason.
- [ ] Confirm already released/expired bindings do not create duplicate release events.
- [ ] Confirm expiry of a customer quote and partner rejection both release the associated commitment.
- [ ] Confirm customer shipment cancellation remains covered by the independent shipment-terminal release trigger.
- [ ] Run repeated and concurrent terminal transitions; confirm capacity is not double-released or left held.
- [ ] Confirm completed assignments release reservation accounting while retaining the completed assignment history.

**Pass condition:** every terminal assignment outcome frees its outstanding capacity commitment/reservation without duplicate release events or orphaned held capacity.

### E9 implementation record

| Control | Staging evidence | Status |
|---|---|---|
| Legacy commitment released without modern binding | Terminal trigger now updates committed legacy row independently of binding ID | Definition/migration verification pending |
| Held/confirmed reservation and binding released | Trigger retains linked reservation/binding release and event writes | Fixture-based test pending |
| Duplicate terminal transition | Trigger exits when status is unchanged and only updates live rows | Definition review only |
| Positive lifecycle / concurrency tests | No verified capacity fixtures in Staging | Not end-to-end tested |

### E10. Automated capacity-hold expiry

- [ ] Worker accepts POST only and rejects missing/incorrect cron secret.
- [ ] Worker uses server-side service credentials only; no service key is exposed to clients.
- [ ] Worker invokes `krim_internal_expire_capacity_holds` with bounded batch size.
- [ ] Expired held reservations become expired and linked held/pending bindings become expired.
- [ ] Reservation and binding events are written once; repeat worker runs do not duplicate expiry events.
- [ ] Verify worker schedule is configured at the platform scheduler and monitor failures.
- [ ] Exercise retry after transient RPC failure and confirm next run safely processes remaining holds.

**Current environment finding:** Staging has no `pg_cron` extension or cron.job relation. The worker source is prepared, but is not deployed or scheduled. A high-entropy `KRIM_CRON_SECRET` must be configured before deployment and scheduler activation.
