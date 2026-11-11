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
