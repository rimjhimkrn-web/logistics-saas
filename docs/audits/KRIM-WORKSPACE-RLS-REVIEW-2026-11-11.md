# KRIM Workspace Access and RLS Review — 2026-11-11

## Scope and method
Read-only review of the production PostgreSQL RLS policies for the customer, partner and driver workspace tables, compared with the repository mobile workspace repository queries. No user data was read, no test accounts were created, and no production settings or records were changed.

## Positive controls observed
- Customer organization discovery queries active memberships for the authenticated user; organization reads are RLS-scoped to active membership.
- Customer shipment and customer quote reads are RLS-scoped through `private.krim_has_organization_access(auth.uid(), customer_organization_id)`.
- Partner capability, partner quote, and partner assignment reads are scoped to the partner organization, with additional customer-side visibility for partner quotes and shipment assignments.
- Open partner opportunity visibility requires an active partner-type membership, eligible organization state, registered-business mode, verified partner status, current-enough capability dates, and a shipment coverage predicate in one policy.
- Driver assignment reads require both `user_id = auth.uid()` and an active driver membership in the same organization.
- Driver profile reads are own-user scoped; driver trip-event and delivery-evidence reads are tied to the authenticated user's own assignments. Evidence inserts additionally validate owned storage objects, path structure, file size/type, recipient name, and active driver membership.

## Release-blocking review items

### 1. Partner quote confidentiality needs an explicit field-level decision
The authenticated SELECT policy on `krim_partner_quotes` permits access either to the partner organization or to the customer organization linked to the opportunity. The mobile partner repository selects amount, currency, notes, status, and validity fields. Because table SELECT is row-level rather than column-level, customer-side access may expose partner-submitted commercial details (including internal notes) to customer users if the table's column grants permit those fields.

**Confirmed exposure path:** the live `authenticated` role has table-level `SELECT` on `public.krim_partner_quotes`, and column checks show `SELECT` on every column, including `amount`, `currency_code`, `notes`, `pricing_snapshot`, and `metadata`. The live SELECT policy admits either the owning partner organization OR the customer organization linked to the opportunity. Therefore, an authenticated customer member of that customer organization can read the full partner-quote row, including partner notes and internal JSON fields, subject to the policy's opportunity relationship. This is not merely a UI concern.

**Repository query review:** the customer mobile repository reads `krim_quotes`, not `krim_partner_quotes`; the partner repository reads `krim_partner_quotes` filtered by its own `partner_organization_id`. The award workflow uses a privileged RPC. No customer-facing view for partner quote rows was found in the inspected public views.

**Recommended containment for review:** remove the customer-organization branch from direct authenticated SELECT on `krim_partner_quotes`, retaining partner-organization access. If customers need quote comparison, expose a separate customer-safe view/RPC with an explicit allowlist of approved fields. Do not implement the change until dependent callers are fully traced and regression tests cover customer A, partner B, unrelated customer C, and award/acceptance workflows.

### 2. Multiple permissive shipment/opportunity policies require OR-composition review
Production has multiple authenticated SELECT policies on `krim_partner_opportunities` and `krim_shipments`. PostgreSQL combines permissive policies with OR. One opportunity policy checks eligible partner status and capability coverage; another adds `private.krim_partner_compliance_is_current`. One shipment policy also checks the older status fields/capability coverage while a second policy is stricter about current compliance. The stricter policy does not narrow access if the older permissive policy independently grants it.

Required next step: consolidate or make every permissive branch independently satisfy the same current compliance, capability, route and organisation checks. First trace dependencies and preserve customer/awarded-partner access. Add tests for expired compliance, expired capability, inactive capability, wrong route, wrong mode, revoked membership, and unrelated tenant.

### 3. Platform-admin read branches in these policies need explicit MFA review
The inspected opportunity policy contains a direct `private.krim_has_permission(auth.uid(), 1, 'admin.platform')` branch without an explicit AAL2 predicate in that policy expression. Verify whether the helper itself enforces AAL2; do not assume it does. If it does not, platform-admin opportunity reads may be possible at AAL1. Review all policies and views used by admin workspaces for the same pattern.

### 4. Client-side organization filters are not authorization
Customer, partner and driver repositories filter queries using organization/user IDs supplied by the app. These filters are convenience constraints only. RLS and RPC authorization must remain the security boundary. Preserve this distinction in testing and UI messaging.

## Driver access notes
The production driver assignment policy is strongly scoped to the authenticated driver and active driver membership in the assignment's organization. Driver trip events and evidence are similarly tied to owned assignments. However, driver profile update policy should be checked for sensitive fields such as verification status, compliance state, and organization linkage: the inspected policy permits own-row UPDATE with user ID and active driver membership but does not itself show a column-level restriction.

Required next step: inspect column grants and whether sensitive profile columns can be changed directly by authenticated users. Prefer server-controlled fields to be writable only through guarded RPCs.

## No changes made
This review is read-only. No RLS policies, grants, functions, data, Edge Functions, authentication settings, or production configuration were modified.

## Required tests before workspace release
- Cross-tenant customer, partner and driver reads/writes.
- Partner quote commercial-field confidentiality.
- Expired/revoked partner compliance and capability.
- OR-composition of all permissive RLS policies.
- AAL1 vs AAL2 admin read access.
- Driver profile protected-column update attempts.
- Revoked membership and deactivated organization.
- RPC direct-call authorization independent of UI route guards.


## Partner quote confidentiality remediation trace — 2026-11-11

### Confirmed direct client callers
- `public/partner/quote-history.html` selects partner quote history fields scoped to the active partner organisation.
- `public/partner/submit-quote.html` selects partner bids scoped to the active partner organisation and submits changes through `krim_submit_partner_quote`.
- `public/shipper/quote-comparison.html` reads customer-facing `krim_quotes`, not `krim_partner_quotes`; it uses the customer quote's `partner_quote_id` only to inspect the related assignment status.
- `public/shipper/partner-bid-status.html` reads opportunity-level customer-visible status, not raw partner quote rows.
- No customer-facing view over `krim_partner_quotes` was found in the inspected public views.

### Backend callers found in live function definitions
Functions referencing `krim_partner_quotes`: `krim_award_partner_quote`, `krim_award_partner_quote_for_checkout`, `krim_ensure_assignment_capacity_commitment`, `krim_internal_aggregate_partner_quotes`, `krim_internal_create_partner_payable`, `krim_internal_create_partner_payable_for_completed_shipment`, `krim_internal_create_partner_payable_for_delivered_shipment`, `krim_internal_prepare_customer_quote`, `krim_partner_respond_to_invitation`, `krim_respond_to_partner_assignment`, and `krim_submit_partner_quote`. Several are internal/service-only; authenticated RPCs that award/submit/respond must retain their current caller authorization and be regression-tested.

### Proposed containment
A review-only SQL file was added at `docs/sql/krim-partner-quote-confidentiality-remediation.review.sql`. It replaces the current OR policy with partner-organization-only direct SELECT. It is wrapped in ROLLBACK and is not a production migration. Customer-facing quote details should continue through `krim_quotes` and the internal quote-preparation workflow, with an explicit customer-safe field allowlist.

### Important deployment gate
Before applying this policy in staging or production, inspect the complete definitions and authorization of `krim_award_partner_quote_for_checkout`, `krim_respond_to_partner_assignment`, and `krim_internal_prepare_customer_quote`; confirm all internal function calls are security-definer/service-only as intended; and run positive/negative integration tests. No policy or grant was changed in production.


## Customer quote / partner award workflow review — 2026-11-11

### Direct customer visibility after the proposed policy
- `krim_quotes` SELECT is scoped to the customer organisation.
- `krim_quote_versions` and `krim_quote_events` SELECT are scoped through the parent customer quote's customer organisation.
- Therefore, the proposed partner-only policy on raw `krim_partner_quotes` does not block customer access to their own quote versions or quote events.
- However, `krim_award_partner_quote_for_checkout` copies partner quote identifiers, partner quote number, partner organisation ID, amount and currency into `krim_quote_versions.pricing_snapshot`. These fields are currently visible to the customer organisation through quote-version RLS. This is not the raw partner notes exposure, but it is a disclosure decision: confirm whether partner identity and internal partner quote reference are intended customer-visible fields. If not, remove them from customer-visible snapshots or expose an allowlisted projection.

### Release-blocking lifecycle concern
The live `krim_award_partner_quote(p_partner_quote_id)` function:
1. Marks the selected partner quote `accepted`.
2. Marks competing partner quotes `rejected`.
3. Marks the partner opportunity `awarded`.
4. Creates a partner assignment with status `offered` and a 24-hour response deadline.
5. If the shipment is `quoted`, transitions it to `confirmed` before the partner has accepted the offered assignment.

The partner response function later changes the assignment to `accepted` or `rejected`. Thus the shipment can be marked `confirmed` while the partner assignment remains merely `offered`. This conflicts with the intended business rule that a booking is confirmed only after a partner explicitly accepts the specific job and terms. The checkout wrapper also creates a customer quote with status `accepted` immediately after the partner award, before partner assignment acceptance.

**Required remediation:** separate customer selection/award intent from confirmed booking. Keep shipment in a non-confirmed state while assignment is `offered`; only transition to `confirmed` after `krim_respond_to_partner_assignment(..., true, ...)` completes all capability/compliance checks and commits the accepted assignment. Define compensating/reopen behaviour for rejection/expiry, competing quotes, and customer quote/payment state. Preserve idempotency and lock ordering. Do not patch production without state-machine migration review and end-to-end regression tests.

### Verification limits
- These are static live-function and policy inspections. No test users, quotes, assignments, shipments, payments or financial records were created or modified.
- No production function, policy, grant or data was changed.
- The partner-quote confidentiality containment SQL remains review-only and must be tested in staging before deployment.


## Critical customer quote acceptance RPC finding — 2026-11-11

A further live production inspection of `public.krim_accept_global_quote(bigint)` found a backend/UI enforcement mismatch.

### Current backend behaviour
The SECURITY DEFINER RPC:
- locks the customer quote and shipment;
- checks customer organisation access and `shipment.update`;
- requires quote status `sent`, unexpired quote and shipment status `quoted`;
- changes quote status to `accepted`;
- calls `krim_transition_shipment(..., 'confirmed', ...)`;
- returns the accepted customer quote.

**It does not check that the quote has a partner_quote_id, nor that a matching partner assignment exists and is accepted, nor that the assigned partner remains verified/compliant/capable.** The customer quote comparison page checks for an accepted matching assignment before enabling its button, but that is browser-side gating and can be bypassed by directly calling the RPC.

This makes the server-side omission a critical release blocker: an authenticated customer with the relevant shipment permission may invoke the RPC directly and confirm a shipment without partner acceptance, depending on quote data and current shipment state.

### Required server-side acceptance gate
Before changing any quote or shipment state, the RPC (or a replacement transactional RPC) must:
1. Lock the quote, shipment, linked partner quote, opportunity and matching assignment in a documented consistent lock order.
2. Require non-null partner quote linkage and exact matching shipment/opportunity/customer organisation/partner organisation relationships.
3. Require exactly one authoritative assignment for the selected partner quote in `accepted` state, tied to the same shipment and an accepted/assigned leg.
4. Revalidate active partner organisation, current verification/compliance and route/mode/cargo/capacity capability at the final acceptance boundary.
5. Confirm the customer quote amount/currency/validity still match the approved customer-safe quote terms; do not leak partner notes or internal metadata.
6. Only then mark customer quote accepted and transition shipment to confirmed, atomically with audit event.
7. Be idempotent for a repeated acceptance of the same quote, but reject stale, conflicting, rejected, expired or cross-organisation state.

The existing customer UI pre-check is useful UX only and must not be treated as an authorization boundary.

### Required regression tests
- Direct RPC call with no partner linkage is denied; quote and shipment unchanged.
- Matching assignment `offered` is denied; quote and shipment unchanged.
- Matching assignment `rejected`, expired, cancelled or wrong shipment is denied.
- Assignment accepted but partner verification/compliance/capability expired is denied.
- Wrong customer organisation, unrelated partner, mismatched quote/assignment/opportunity/leg is denied.
- Wrong amount/currency or expired customer quote is denied.
- Correct accepted assignment + valid customer quote succeeds atomically.
- Duplicate acceptance returns the same accepted quote without duplicate events or transitions.
- Concurrent acceptance and concurrent partner rejection/withdrawal serialize safely.
- An ordinary customer without `shipment.update` is denied; partner user cannot accept for customer; anon denied.
- No direct customer query returns partner notes, pricing snapshot or internal metadata.

### Current status
This is a static review of live production function definitions and frontend source. No RPC, policy, grant, record or production setting was modified. Fix requires a reviewed migration and staging integration tests before deployment.


## Booking state-machine remediation design — 2026-11-11

This section records the exact current lifecycle interactions found in production function definitions. It is a design/test specification, not deployable SQL.

### Current sequence and defects

**Customer award path — `krim_award_partner_quote(bigint)`:**
- Authenticates the customer and checks `quote.update` + `shipment.update`.
- Checks partner organisation, verification/compliance, at least one active verified capability and current route coverage.
- Accepts the selected partner quote, rejects competing quotes, marks opportunity `awarded`, and creates partner assignment `offered` with 24-hour response deadline.
- Then immediately transitions shipment from `quoted` to `confirmed`.
- This is the premature confirmation defect.

**Checkout preparation path — `krim_award_partner_quote_for_checkout(bigint,timestamptz)`:**
- Calls `krim_award_partner_quote`, so it inherits the premature shipment confirmation.
- Immediately inserts the customer quote with status `accepted`, even though the assignment is still `offered`.
- Creates an `accepted` quote version and event. The version says payment after partner assignment acceptance, but the quote status already says accepted.
- The pricing snapshot contains partner quote ID/number and partner organisation ID, which are customer-visible through quote-version access. This is an explicit disclosure choice to resolve; do not assume those identifiers are customer-safe.

**Customer acceptance path — `krim_accept_global_quote(bigint)`:**
- Checks authenticated customer org access, `shipment.update`, sent/unexpired quote and shipment `quoted`.
- It does not verify partner quote linkage or assignment acceptance before accepting quote and confirming shipment.
- The browser quote comparison page checks assignment status before enabling the button, but the server RPC does not repeat this check. Direct RPC invocation bypasses the browser guard.

**Partner response path — `krim_respond_to_partner_assignment(bigint,boolean,text)`:**
- Checks authenticated membership in the assignment's partner org and `shipment.update`.
- On acceptance, rechecks route capability and current compliance, marks assignment accepted and assigns the shipment leg.
- On rejection, marks assignment rejected, withdraws the selected partner quote, reopens opportunity and restores competing quotes to submitted.
- It does not currently transition a prematurely confirmed shipment back to a non-confirmed state, nor reconcile an already-created accepted customer quote. That leaves stale accepted customer commercial state after rejection.

**Internal quote preparation — `krim_internal_prepare_customer_quote(bigint)`:**
- Service-only (authenticated EXECUTE false in current catalog).
- Takes latest quote version and changes customer quote status to `sent`.
- It counts partner quotes but does not itself enforce a valid accepted partner assignment. Its callers and intended quote lifecycle need to be traced before changing it.

### Target state machine

Do not overload the existing word `accepted` to mean both customer selection and partner commitment. Preserve distinct states:

1. **Partner offer submitted** — partner quote is submitted/shortlisted; no customer commitment.
2. **Customer selects offer / assignment offered** — selected partner quote is reserved; assignment is `offered`; opportunity is awarded/pending partner response; shipment remains `quoted` (or an explicit non-confirmed `awaiting_partner_acceptance` state if that state is added consistently across constraints, UI and reports). Customer quote must not be `accepted` or payable.
3. **Partner accepts** — partner response transaction revalidates membership, capability, compliance, capacity, quote validity and exact shipment/opportunity linkage; assignment becomes `accepted`; leg becomes assigned; write immutable audit/tracking event.
4. **Booking confirmation** — only after step 3, a single transactional server-side operation confirms the shipment and creates/marks the customer-facing quote as accepted/sent according to the agreed commercial model. The customer-safe price/terms must match the selected partner offer. This transition must be atomic with audit/event creation.
5. **Partner rejects / offer expires** — assignment becomes rejected/expired; selected partner quote withdrawn/expired; opportunity reopens only if no other active award/assignment exists; competing quotes return to eligible state only under a documented policy; shipment stays non-confirmed; any draft customer quote/version is cancelled/voided and never remains accepted/payable. Customer is invited to select another offer.
6. **Payment** — remains separately gated by confirmed booking, accepted customer terms, provider eligibility and payment reconciliation controls. Do not initiate payment while assignment is merely offered.

### Required implementation shape

- Replace the direct state mutation in `krim_award_partner_quote` with a **selection/reservation** transaction only. It must not call shipment transition to `confirmed`.
- Make `krim_respond_to_partner_assignment(..., true, ...)` the single server-side commitment boundary. After its current capability/compliance rechecks and leg assignment, it should atomically validate the reservation and finalize the customer-facing quote + shipment confirmation. Use a private internal helper to avoid a second public API path.
- Make `krim_award_partner_quote_for_checkout` create a non-payable pending customer quote (or defer quote creation until partner acceptance); never mark it `accepted` while assignment is offered.
- Harden `krim_accept_global_quote` to require the exact linked assignment in `accepted` state and matching shipment/partner quote/opportunity/leg/customer org, plus current partner compliance/capability. Better: make it a customer acknowledgement step after partner acceptance and do not let it independently confirm an unaccepted shipment.
- Rejection/expiry must reconcile assignment, opportunity, partner quote, customer quote/version and shipment consistently. No accepted quote can survive a rejected assignment.
- All mutation + audit + quote event + tracking event writes must be in the same transaction. Use consistent lock order across award, response, customer acceptance, expiry and cancellation paths; test deadlock/retry behaviour.
- Preserve least-privilege grants: no direct client table writes; customer and partner RPCs must verify auth.uid(), active org membership and exact permission. Internal helper functions remain non-executable by anon/authenticated.
- Keep the customer-safe quote response allowlisted. Do not return partner internal notes, metadata or raw pricing snapshot. Decide whether partner identity is contractually/customer-visible; if yes, expose only an explicit public display identity field, not internal org IDs or partner quote IDs.

### Expanded acceptance tests (release blocking)

**Reservation / award**
- Customer with quote.update + shipment.update can select an eligible partner quote; assignment is offered; shipment remains non-confirmed; customer quote is not accepted/payable.
- Customer without either permission, partner user, unrelated customer, anon and development/test partner are denied.
- Duplicate award returns same reservation without duplicate assignments/events; competing quote award serializes.
- Expired opportunity/partner quote, inactive/unverified/compliance-held partner, expired capability, wrong route/mode/weight/cargo, wrong shipment/customer org and mismatched quote linkage are denied with no partial writes.

**Partner acceptance / confirmation**
- Only active member with shipment.update in exact partner org can accept.
- Acceptance rechecks assignment deadline, partner status, compliance, route coverage, capability validity and capacity.
- Valid acceptance atomically sets assignment accepted, leg assigned, shipment confirmed and customer quote lifecycle to the agreed final state; exactly one audit and tracking/event set.
- Duplicate acceptance is idempotent; concurrent accept/reject has exactly one winner.
- Missing leg or multiple legs follows a documented deterministic leg allocation policy; never attach an assignment to an unrelated leg.
- If any audit/event/quote/shipment write fails, the whole transaction rolls back.

**Rejection / expiry / cancellation**
- Rejection leaves shipment unconfirmed and no accepted/payable customer quote.
- Rejection does not reopen opportunity while another active assignment exists.
- Expiry worker and partner response racing at deadline serialize deterministically.
- A rejected/expired offer can be replaced by a different eligible offer without reviving stale quote versions or payment intents.
- Customer cancellation and partner cancellation after acceptance have explicit compensation rules and audit history.

**Customer acceptance / payment**
- Direct call to `krim_accept_global_quote` with no partner quote, offered/rejected/expired assignment, mismatched assignment or non-confirmed shipment is denied.
- Customer can read only customer-safe quote and version fields; raw partner notes and internal metadata remain inaccessible.
- Payment/order creation is denied until final booking and customer terms are valid; no charge on no-match, offered, rejected or expired states.
- Repeated acceptance/payment webhook is idempotent; stale quote amount/currency or conflicting provider reference is rejected.

### Deployment sequence
1. Trace every caller/trigger/cron/Edge Function for the four public lifecycle RPCs and the internal quote-preparation helper.
2. Confirm status constraints, shipment transition matrix, quote version semantics, notifications and dashboards that depend on `confirmed` / `accepted`.
3. Build a dedicated test fixture and run all cases in isolated staging.
4. Deploy database functions and grants as one reviewed migration; then update customer/partner UI labels and checkout gating.
5. Verify live catalog definitions, execute privileges, RLS and negative/positive integration tests.
6. Keep real customer booking and payment disabled until all release gates pass.

**No production schema, RPC, policy, grant, shipment, quote, assignment, payment or other record was changed during this review.**


## Booking lifecycle dependency trace — production read-only — 2026-11-11

### Trigger dependencies confirmed
The following live triggers participate in the award / acceptance / rejection / dispatch lifecycle:

- `trg_krim_cancel_customer_quote_after_partner_rejection` — AFTER UPDATE of assignment status. When an `offered` assignment becomes `rejected`, it cancels an associated customer quote only if that quote is already `accepted`; it also cancels the latest accepted quote version and writes a quote event. This trigger does not handle expiry or cancellation transitions.
- `trg_krim_ensure_assignment_capacity_commitment` — AFTER INSERT OR UPDATE of assignment status/partner quote/partner org. On transition to `accepted`, it requires positive shipment weight, a matching partner quote/shipment/org, and creates or verifies a current capacity commitment. An acceptance RPC that changes assignment status must satisfy this trigger.
- `trg_krim_partner_assignment_quote_integrity` — BEFORE INSERT/UPDATE of assignment linkage fields. Enforces matching partner quote, opportunity, shipment, partner and optional shipment leg.
- `trg_krim_release_capacity_on_assignment_terminal` — releases held/confirmed capacity reservations and bindings on rejected/cancelled/completed/failed assignment status.
- `krim_shipment_readiness_enforcement` — BEFORE UPDATE of shipment status to confirmed/assigned/dispatched; calls `krim_internal_evaluate_shipment_readiness`.
- `trg_krim_guard_dispatch_capacity_confirmation` — BEFORE shipment transition to dispatched; requires accepted assignment(s) and confirmed capacity binding/reservation.

### Critical readiness-state interaction
The current `krim_internal_evaluate_shipment_readiness` explicitly sets partner status to `not_required` while shipment status is one of `draft`, `requested`, `quoted`, or `confirmed`. It only requires an accepted/active partner assignment after the shipment has moved beyond those states. Therefore, the readiness trigger does not stop a `quoted -> confirmed` transition when no partner has accepted. This is a second independent reason the current readiness gate cannot enforce the intended booking rule.

### Additional internal lifecycle dependency
`krim_internal_finalize_partner_assignment(assignment_id)` requires:
- shipment status already `confirmed`;
- assignment status `accepted`;
- linked partner quote;
- active committed capacity commitment.

It then changes assignment to `active` and shipment to `assigned`, marks the opportunity awarded and writes an audit event. Thus the proposed correction cannot simply move the existing `confirmed` transition into the current partner-response function without also reconciling this finalizer's required preconditions and status semantics.

`krim_internal_dispatch_assigned_shipment(assignment_id)` requires shipment `assigned`, assignment `active` or `accepted`, linked partner quote, shipment readiness `ready`, and operations dispatch readiness `ready_for_authorized_review`; then it changes shipment to `dispatched` and writes tracking, execution and audit events. Dispatch is separately guarded by the capacity trigger.

### Alternate partner invitation RPC
A second authenticated SECURITY DEFINER path, `krim_partner_respond_to_invitation(assignment_id, decision, amount, currency, valid_until, notes)`, exists alongside `krim_respond_to_partner_assignment`. Its accept branch creates a partner quote and capacity commitment, then marks the assignment `accepted`. Its decline branch marks the assignment `rejected`. Both branches must be included in any lifecycle migration and regression suite; changing only `krim_respond_to_partner_assignment` would leave an alternate path.

### Status constraints and transition matrix
Live check constraints allow:
- shipment statuses: draft, requested, quoted, confirmed, assigned, dispatched, in_transit, delivered, closed, cancelled, exception;
- assignment statuses: offered, accepted, rejected, cancelled, active, completed, failed;
- customer quote statuses: draft, sent, accepted, rejected, expired, cancelled;
- quote-version statuses: draft, calculated, presented, accepted, expired, superseded, rejected, cancelled;
- partner quote statuses: draft, submitted, under_review, shortlisted, accepted, rejected, withdrawn, expired;
- opportunity statuses: draft, open, shortlisted, awarded, cancelled, expired.

The current shipment transition table allows `quoted -> confirmed` with `shipment.update`, and `confirmed -> assigned` with `shipment.assign`. It does not define a direct `quoted -> assigned` transition. Any new lifecycle must deliberately update and test the transition matrix, not assume a status path exists.

### Scheduled expiry / automation trace
A read-only query of `cron.job` found no scheduled job whose command references shipment, quote or partner lifecycle terms. This does not rule out an external scheduler or Edge Function invocation, but no database-cron expiry worker was identified. Assignment response deadlines are checked on response; the inspected trigger handles rejection, not automatic expiry. A future expiry worker must be explicitly designed, idempotent, race-safe against partner acceptance, and reconcile quote, opportunity, capacity and customer notification states.

### Privilege inventory
The five main lifecycle RPCs inspected (`krim_accept_global_quote`, `krim_award_partner_quote`, `krim_award_partner_quote_for_checkout`, `krim_respond_to_partner_assignment`, `krim_transition_shipment`) are SECURITY DEFINER. `anon` cannot execute any of them. `authenticated` can execute the first four; `krim_transition_shipment` is not executable by authenticated and remains internal/service-only. This makes the authenticated RPC bodies and every alternate path the security boundary.

### Required design correction before migration
The implementation design must define two distinct concepts rather than overload one status:
1. **Commercial booking confirmation** — customer terms and a specific partner's accepted commitment are both valid.
2. **Operational shipment assignment/dispatch readiness** — capacity commitment, assignment activation, shipment readiness, compliance, documents, payment and operations review are complete.

The existing `confirmed -> assigned` finalizer sequence and readiness evaluator's current `confirmed = partner not required` rule must be redesigned together. Do not apply a patch that only moves a status update between the current RPCs. Preserve the existing capacity, quote-cancellation, quote-integrity, dispatch and audit triggers, or replace them with equivalent tested transactional controls.

### Trace completion and limits
- No matching database-cron lifecycle job was found.
- No production function, trigger, status constraint, grant, policy, setting or record was changed.
- Static inspection does not prove external schedulers, webhook callers or UI flows are absent. The remaining trace must include all frontend RPC call sites, Edge Function invocations and external scheduler configuration before the migration is finalised.


## Frontend lifecycle RPC caller trace — repository main — 2026-11-11

### Confirmed customer / operations / partner UI call sites
- `public/operations/partner-selection-assignment.html` calls `krim_award_partner_quote(p_partner_quote_id)` for the operations award action. Its UI copy says an assignment is created and the selected partner must still accept; shipment execution is not yet confirmed. This is inconsistent with the live RPC, which currently attempts `quoted -> confirmed` during award.
- The same page calls `krim_respond_to_partner_assignment(p_assignment_id,p_accept,p_reason)` for partner acceptance/rejection and validates the returned assignment status.
- `public/partner-selection-assignment.html` calls `krim_award_partner_quote_for_checkout(p_partner_quote_id,p_valid_until)`. This wrapper currently creates a customer quote with status `accepted` while the assignment returned by the award function is still `offered`.
- `public/partner/accepted-loads.html` calls `krim_respond_to_partner_assignment` for accept/decline. It also has a separate `krim_partner_reserve_shipment_leg_capacity` call path; this must be checked for duplicate or pre-accept capacity effects in staging.
- `public/shipper/quote-comparison.html` and `public/customer-os/assets/quote-operations.js` both call `krim_accept_global_quote`. The latter is shared customer quote-operation code, so both call sites need the server-side acceptance regression tests.
- `public/partner/submit-quote.html` calls `krim_submit_partner_quote` for partner quote submission.
- `public/shipper/partner-bid-status.html`, `public/partner/quote-history.html`, `public/customer/quote-acceptance.html` and `public/customer/quote-details.html` did not show direct calls to the five award/acceptance RPC names in the inspected source files.

### Mobile and legacy paths
- The inspected customer and partner mobile repository source files did not contain direct calls to the five lifecycle RPC names. This does not prove there are no indirect repository wrappers or other mobile call sites; expand the search across all mobile source before release.
- `krim_partner_respond_to_invitation` remains an authenticated backend RPC with no direct call found in the inspected current frontend files. It must be included in the backend compatibility plan and checked against older UI routes, external integrations and grants before retirement.
- The production database has no matching `cron.job` entries for quote/partner/shipment expiry. External scheduled jobs and Edge Function invocations were not visible through the database catalog query and remain to be checked in Supabase function configuration and repository workflows.

### UI / backend mismatch requiring an explicit acceptance contract
The operations award UI correctly tells the user that partner acceptance is still pending. The live award RPC nevertheless transitions the shipment to `confirmed`; the checkout wrapper additionally writes an `accepted` customer quote and accepted quote version before partner acceptance. The user-facing UI language is therefore safer than the authoritative persisted state, but the database state remains incorrect for the intended commercial rule.

### Remaining release trace
- Inspect every RPC caller across the complete repository (including mobile, admin, enterprise and legacy pages), not only the focused files above.
- Inspect the deployed Edge Function inventory and function source/configuration for direct or indirect lifecycle invocation.
- Inspect external GitHub Actions, provider webhooks and any third-party scheduler configuration; database cron absence is not proof no external scheduler exists.
- Check notifications, customer quote lists, payment-order creation, finance ledgers, customer/partner dashboards and operational reporting for assumptions that an `accepted` quote or `confirmed` shipment means the partner has already committed.
- No production changes were made.
