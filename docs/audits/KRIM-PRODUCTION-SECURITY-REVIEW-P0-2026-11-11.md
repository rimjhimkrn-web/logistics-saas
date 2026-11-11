# KRIM Production Security Review — P0 follow-up — 11 November 2026

## Scope
Read-only review of selected live PostgreSQL function definitions and grants, current Supabase security advisor output, and the repository's privileged Edge Function. No production schema, data, roles, grants, secrets, Auth settings, or deployed functions were changed.

## Verified catalog results
- Public-schema SECURITY DEFINER functions: **307**.
- SECURITY DEFINER functions with an explicit function-level `search_path` setting: **307 / 307**.
- SECURITY DEFINER functions with no function-level `search_path` setting: **0**.
- Functions configured with empty search path: **152**.
- Supabase advisor warning: **126** SECURITY DEFINER functions are executable by the authenticated role. This is an exposure inventory, not proof that all 126 are exploitable. Each exposed function must be checked for the correct user, organisation, role, permission, object ownership and state-transition checks.
- A representative privilege check confirmed `public.krim_transition_shipment(bigint,text,text,jsonb)` is executable by `service_role`, but not by `anon` or `authenticated`.

## Selected function review

### `krim_accept_global_quote(bigint)`
The current production definition has an empty search path and performs the following checks before customer acceptance:
- locks the quote and shipment rows;
- verifies quote and shipment customer-organisation consistency;
- checks active organisation access and `shipment.update` permission;
- requires a sent, unexpired customer quote and a quoted shipment;
- requires a linked, valid partner quote with matching amount/currency;
- requires an accepted shipment-partner assignment before confirming the shipment.

This is a useful fail-closed control. It still requires integration tests for cross-tenant access, expired offers, mismatched currencies/amounts, rejected or withdrawn offers, concurrent acceptance and duplicate retries.

### `krim_create_global_shipment(...)`
The current production definition checks authenticated organisation access and `shipment.create` permission, validates active origin/destination locations and operational country activation, and creates a shipment in `draft` state. It does not itself establish provider availability or confirm a booking. This is consistent with the rule that a shipment draft/request is not a confirmed logistics service.

### `krim_transition_shipment(...)`
The current production function uses an explicit `search_path = pg_catalog, public` and is not executable by `anon` or `authenticated`; the privilege check showed `service_role` only. Preserve that boundary unless a separately reviewed, permission-checked user-facing RPC is designed. Do not grant direct authenticated execution simply to make a UI button work.

### `krim_warehouse_review_inventory_quality(...)`
The current production definition checks an authenticated user, completed goods-receipt/damage task, warehouse operator access, separation of reviewer from task creator/completer, required inspection report, inventory/task organisation and facility match, and a constrained quality decision with reason. Add negative tests for cross-organisation, cross-facility, creator self-review, missing evidence and repeated review.

### `krim_admin_list_partner_capabilities()`
The current production definition checks authenticated user, AAL2 and `admin.platform` permission, and limits the review queue to pending submissions with evidence paths that are correctly scoped to organisation and submitting user and backed by owned storage objects.

## Privileged Edge Function review: `global-admin-control`
The checked-in function:
- requires a Bearer token and validates it with `auth.getUser()`;
- requires current MFA assurance level AAL2;
- checks active server-side `platform_admin` / `platform_superadmin` assignments using the service role;
- restricts role/user administration mutations to platform superadmin;
- validates inquiry status, note length and follow-up outcome inputs;
- uses server-side database access and does not ship the service-role key to the browser.

### Finding requiring remediation
Its `audit()` helper awaits an insert into `krim_audit_events` but ignores the returned Supabase `error`. Therefore an admin operation may succeed even when its audit event fails to persist. Sensitive admin mutations should move to transactional database RPCs that commit the mutation and audit event atomically, or use an explicit durable intent/completion pattern with idempotent reconciliation. Merely throwing after a PostgREST insert failure is not atomic and can report failure after the mutation has already occurred.

### Additional acceptance checks
- Confirm platform role assignment rows are active and the lookup cannot be confused by duplicate or malformed role relationships.
- Confirm the expected `admin.platform` permission model matches the platform role assignment check.
- Test all admin actions as signed-out, AAL1, ordinary authenticated, platform_admin and platform_superadmin users.
- Test audit-table failure and verify sensitive mutations cannot silently complete without a durable audit trail.
- Test concurrent role revocation during an admin request and ensure access is rechecked at the mutation boundary.
- Confirm the browser guard remains defense-in-depth only; server-side Edge Function authorization is authoritative.

## P0 remediation plan
1. Export all 126 advisor-flagged authenticated-executable SECURITY DEFINER function names, signatures, grants, settings and definitions into a controlled review inventory.
2. Classify each as intentionally callable or server-only. Revoke only after tracing frontend/mobile/Edge Function callers and validating replacement paths.
3. For each intentionally callable function, record checks for auth identity, active membership, organisation scope, role/permission, object ownership, state and idempotency.
4. Convert privileged admin mutations to atomic database RPCs with audit events in the same transaction.
5. Classify the 26 RLS-enabled/no-policy tables individually. Private service-only tables may be intentional; public tables need explicit access decisions. Do not add broad policies.
6. Enable leaked-password protection in Supabase Auth after checking user-impact and supported Auth configuration; this setting was not changed in this review.
7. Run a dedicated staging security matrix before production rollout.

## Release decision
P0 is **in progress, not complete**. The function-level search-path baseline is positive, and selected critical functions show strong access/state controls. However, the 126 exposed SECURITY DEFINER review, 26 no-policy table classifications, admin audit durability, leaked-password protection and authenticated end-to-end tests remain open. Do not declare the platform security-complete or open paid checkout yet.


## RLS no-policy privilege classification — read-only follow-up
The live catalog was queried for every RLS-enabled table with zero policies, including direct table privileges for `anon`, `authenticated` and `service_role`.

Result:
- **26 / 26** findings had no direct SELECT, INSERT, UPDATE or DELETE privilege for `anon`.
- **26 / 26** had no direct SELECT, INSERT, UPDATE or DELETE privilege for `authenticated`.
- **25 / 26** had direct `service_role` SELECT privilege.
- `private.krim_ai_rate_limits` had no direct SELECT privilege for `service_role` either; this may be accessed through a narrowly scoped privileged function or another controlled path and needs a call-path review.
- The 21 public-schema tables among these findings are therefore not directly readable or writable by the browser's anon/authenticated database roles, based on the current grants queried. They are still exposed-schema objects and require confirmation that only intended server-side code accesses them.
- No broad RLS policies were added. These findings are now classified as **likely intentional service-only / deny-by-default**, pending verification of every service-role Edge Function/RPC caller and API schema exposure.

This materially narrows the RLS remediation: do not add policies simply to clear the advisor. Preserve the deny-by-default grants and document each privileged access path. The RLS advisor warning may remain for intentionally service-only tables.


## Authenticated-callable SECURITY DEFINER inventory — static triage batch 1

The live catalog was queried for all public-schema SECURITY DEFINER functions for which the authenticated role has EXECUTE. This inventory returns **126 functions**, all with anon EXECUTE false in the same catalog privilege checks.

### Family distribution
| Function family | Count |
|---|---:|
| Platform admin | 53 |
| Driver | 11 |
| Partner | 9 |
| Customer / shipment lifecycle | 11 |
| Vehicle / fleet | 16 |
| Warehouse | 14 |
| Other shared functions | 12 |
| **Total** | **126** |

### Static guard-pattern indicators
Across the 126 function definitions:
- 116 reference `auth.uid()` directly.
- 53 reference `auth.jwt()`.
- 52 explicitly check AAL2.
- 52 explicitly check `admin.platform`.
- 83 reference a KRIM permission helper.
- 9 reference the organisation-access helper.
- 69 reference `private.krim_has_permission`.
- 51 use row locking (`FOR UPDATE`).
- 8 include an idempotency/replay pattern.
- 15 inspect `storage.objects`.

These are static indicators only. A text match is not proof of correct authorization, and the absence of a direct check is not automatically a vulnerability when a function delegates to a separately guarded function.

### Admin-family review
52 of 53 `krim_admin_*` functions explicitly include both AAL2 and `admin.platform` permission checks. The remaining function, `krim_admin_list_capacity_resources_lane_aware()`, delegates first to `krim_admin_list_capacity_resources()`, which independently enforces:
1. non-null `auth.uid()`;
2. AAL2;
3. `private.krim_has_permission(user, 1, 'admin.platform')`.

The wrapper returns only the already-authorized result plus lane availability details. This is an inherited guard path, not an unguarded admin endpoint based on the inspected definition. Add a regression test to ensure this delegation remains intact.

### Functions without a direct `auth.uid()` reference
Ten functions lacked a direct `auth.uid()` string reference in their own definition:
- `krim_admin_list_capacity_resources_lane_aware()` delegates to the guarded admin list function above.
- `krim_partner_register_capacity_resource_for_lane(...)` delegates to the guarded base capacity-registration function before attaching the lane to the returned availability record.
- `krim_partner_submit_service_capability_v2(...)` delegates to the base capability submission function, then attaches bounded metadata to the returned capability.
- Six vehicle administration functions call `public.krim_vehicle_admin_guard()` to establish the authenticated administrator context before acting.
- `krim_vehicle_refresh_expiry()` also uses the same guard; it is a privileged maintenance action and should be invoked only by an authorised admin/scheduler pathway, not a general user client.

The delegation paths were inspected in the live definitions. Regression tests must verify that the guard helper itself enforces the expected identity, MFA and permission, and that no replacement overload bypasses it.

### High-priority follow-up review
The broad static inventory is not a substitute for per-function business-logic review. Highest-risk next targets are:
1. shipment/customer quote, assignment, driver acceptance and delivery-POD transitions;
2. partner capability, compliance evidence, service area and capacity registration;
3. vehicle/driver binding, document review, expiry suspension and maintenance execution;
4. support ticket, exception and escalation actions;
5. warehouse evidence, inventory and QC transitions.

For every function, tests must cover unauthenticated execution, wrong organisation, insufficient permission, wrong object owner, self-approval, invalid state, expired evidence, concurrent request and duplicate retry as relevant.

## Current disposition
- The 126-function authenticated-execution inventory is now captured and grouped.
- No function grants were changed or revoked. This is intentional: revoking a callable RPC without tracing every web/mobile/Edge Function caller could break production workflows.
- No broad grants or policies were added.
- The review is **still in progress** until function-by-function test evidence and a full call-site map exist.


## Partner and dispatch lifecycle RPC review — static batch 2

The following live production definitions were inspected:

### Partner capability submission
`krim_partner_submit_service_capability(...)`:
- requires authenticated `auth.uid()`;
- requires `partner.manage` for the submitted organisation;
- requires an active registered-business partner organisation;
- requires current organisation compliance;
- requires an active KRIM transport mode and active coverage country;
- validates service type, weight and region lengths;
- limits evidence to one through five files and constrains storage paths to the submitting organisation and user;
- creates capability records as `active=false`, `verification_status='pending'`;
- writes an audit event in the same database transaction.

This is correctly fail-closed at submission: a partner cannot activate its own capability. The evidence-object lookup checks the private bucket and path, but the inspected function does not compare `storage.objects.owner` with the submitting user. The path includes the user's ID; nevertheless, owner binding should be enforced explicitly and covered by a negative test before this is considered fully verified.

### Partner service-area submission
`krim_partner_submit_service_area(...)`:
- requires authenticated identity and `partner.manage`;
- validates the country/market/location scope against active catalogues;
- validates mode/service and effective dates;
- requires one to five evidence files in the caller's organisation/user path;
- verifies the evidence object is in the private partner-verification bucket and owned by the submitting user;
- blocks duplicate pending submissions;
- creates the request as draft / pending_review and writes an audit event.

### Partner capacity registration and lane wrapper
`krim_partner_register_capacity_resource_for_lane(...)` delegates to the base capacity registration RPC, then links the resulting availability record to a lane using both the generated availability ID and the submitted organisation ID. The base function is the authoritative identity/permission boundary. The wrapper's delegation must remain intact; add tests for a forged organisation ID, a lane outside the caller's approved scope and replayed registration.

### Partner assignment response
`krim_respond_to_partner_assignment(...)`:
- locks the offered assignment;
- checks the caller belongs to the assignment's partner organisation and has `shipment.update`;
- enforces response deadline and offered state;
- on acceptance, rechecks route capability and current compliance;
- links/creates the shipment leg and writes tracking and audit events;
- on rejection, updates assignment, quote and opportunity state and writes an audit event.

The function has no explicit idempotency key. It does return already accepted/rejected states in narrow replay cases, but concurrency and repeated acceptance/rejection must be tested for consistency, especially around quote and opportunity state.

### Driver and vehicle assignment
`krim_assign_driver_to_partner_shipment(...)` includes substantial dispatch gates:
- partner assignment must already be accepted;
- caller must have `shipment.dispatch` for the partner organisation;
- shipment and leg must be assigned and linked to the same partner;
- partner must be active, verified, compliant and have current capability/service-area coverage;
- driver must have active driver membership, verified profile and independently accepted front/back licence evidence;
- driver must be bound to a verified operational vehicle;
- mandatory vehicle documents must be approved and current;
- shipment weight must fit the vehicle's verified payload capacity;
- driver and vehicle cannot have another open assignment.

`krim_driver_accept_assignment(...)` checks that the assignment belongs to the signed-in driver, validates active driver membership and licence evidence, rechecks vehicle binding/verification/documents, partner assignment, shipment and road-leg status, route coverage and payload capacity. It supports a consistent already-accepted replay.

These are strong server-side gates in the inspected definitions. They still require integration tests with test fixtures; no real dispatch or driver acceptance was attempted against production data.

## Findings requiring explicit closure
1. Add storage object owner binding to `krim_partner_submit_service_capability` and its v2 wrapper path, with a migration and tests in staging before production.
2. Add or prove idempotent/concurrent behaviour for partner assignment response.
3. Confirm the service-role and authenticated callers of the lane/capability wrappers and test delegated permission enforcement.
4. Test all driver/vehicle verification expiry and cross-organisation denial cases.
5. Inspect the remaining partner compliance and driver POD functions, including evidence storage ownership, delivery completion state and customer verification.
6. Keep live bookings, driver dispatch and payments disabled unless the specific partner, vehicle, route and job have passed their respective gates.

## Status
This is a static review of live function definitions, not a successful end-to-end operation. No partner capability, quote, assignment, driver assignment, delivery POD, or payment was created or altered during this review.


## Delivery POD, shipment completion and privileged helper review — static batch 3

### Driver POD submission
`krim_driver_submit_delivery_pod(...)`:
- requires authenticated identity;
- locks a driver assignment belonging to the signed-in user;
- requires active driver membership in the assignment organisation;
- requires the assignment to be in transit and linked to an accepted/active partner shipment assignment;
- checks private delivery evidence records against `storage.objects` and requires object ownership by the assigned driver;
- delegates POD creation to the internal submission function.

The internal submission function locks the partner assignment, shipment and leg; checks shipment/assignment state; returns the existing pending/verified POD for a retry; and writes POD, execution, tracking and audit records in one transaction.

### POD review and delivery authorization
`krim_admin_review_delivery_pod(...)`:
- requires authenticated identity, AAL2 and `admin.platform`;
- locks the POD and only permits submitted/under-review states;
- prevents a driver who submitted delivery evidence from independently reviewing that POD;
- requires at least one private evidence object owned by the assigned driver;
- verifies or rejects the POD, then on verification invokes the delivery-authorization helper;
- records a platform audit event with the decision and reason.

`krim_internal_authorize_delivery(...)` verifies the POD state and the linked assignment/shipment/leg/partner relationships, locks the relevant rows, marks the leg and assignment completed, and marks the shipment delivered only when all other legs are delivered/completed/cancelled. It writes tracking, partner execution and audit events. Already-delivered shipments return an idempotent result.

### Internal helper privilege boundary
Live privilege checks confirm:
- `krim_internal_verify_delivery_pod(...)`: anon EXECUTE false; authenticated EXECUTE false; service_role EXECUTE true.
- `krim_internal_authorize_delivery(...)`: anon false; authenticated false; service_role true.
- `krim_internal_submit_delivery_pod(...)`: anon false; authenticated false; service_role true.
- The public driver submission and admin review entry points are authenticated-callable, but contain their own identity/role gates.

This is the intended boundary: browser users call the guarded entry points; internal mutation helpers are not directly callable by anon or authenticated roles.

### Important remaining checks
1. The admin review entry point checks AAL2 and platform permission; regression tests must prove a driver, partner admin, regular organisation admin and non-MFA platform user cannot verify POD.
2. The driver submission path verifies evidence ownership and driver/assignment linkage; test a copied storage path, another driver's object, a different partner organisation, and duplicate concurrent submissions.
3. Delivery authorization is idempotent when shipment status is already delivered. Test two concurrent verification requests and multi-leg shipments where one leg is delivered but the overall shipment must remain in transit.
4. Review rejection and POD resubmission semantics need explicit tests. Confirm a rejected POD cannot be treated as delivered and that replacement evidence creates a clean review trail.
5. Verify the helper function owners and all execute grants after any future migration; do not grant internal helpers to authenticated users.

### Disposition
Static review found the expected service-role-only privilege boundary for the three internal POD helpers and strong server-side linkage/ownership/state checks in the reviewed entry points. No POD, shipment status, assignment, tracking, or financial records were modified. No live end-to-end test was run because production has no real verified partner/assignment/POD fixtures and should not be populated with fabricated operational transactions.


## Finance, payment and refund lifecycle — static batch 4

### Privilege boundary
The production catalog shows the reviewed internal finance mutation functions are not executable by anon or authenticated roles and are executable by service_role only. Examples include internal payment-to-ledger posting, partner settlement authorization/posting, financial reconciliation, customer invoicing after delivery, and Razorpay captured-payment reconciliation. This is the expected separation between client-facing workflows and privileged payment/ledger mutations.

### Refund workflow
The customer refund submission private function:
- requires authenticated identity;
- locks the payment order;
- accepts only a paid order;
- currently permits full refunds only (partial refunds explicitly disabled);
- checks customer ownership or active organisation membership;
- requires an idempotency key;
- allows only one refund request per payment order;
- writes the request and event in one transaction.

The finance review private function:
- requires AAL2;
- requires active finance/platform/operations organisation membership;
- requires `finance.manage` or `admin.platform`;
- prevents the original requester from reviewing their own request;
- requires a meaningful review note;
- locks the request and enforces valid state transitions;
- writes the review event in the same transaction.

The refund execution-claim function:
- requires AAL2;
- requires the same finance reviewer who approved the request;
- prevents requester/reviewer self-approval;
- checks active finance/platform/operations membership and permission;
- accepts only approved/pending execution states;
- prevents a second provider refund ID from being generated;
- checks full INR Razorpay payment/order/amount conditions;
- persists the idempotency key and execution claim before returning the execution payload.

The public wrappers for refund submit/review delegate to private security-definer implementations. The private refund functions were inspected directly. Do not grant direct browser access to the internal execution helpers.

### Financial controls and gaps
- Internal ledger posting checks positive amounts, distinct debit/credit accounts, active accounts within the specified organisation and currency consistency. It uses transaction references for duplicate detection; concurrency behaviour must be verified against unique constraints and parallel calls.
- Partner payout authorization checks approved payable state, active treasury controls, required financial approval, approval amount/currency equality and a stable execution fingerprint. It returns idempotently for already settled/paid records.
- Partner payout reconciliation requires exactly one matching provider-confirmed completed payout transaction with matching amount, currency and provider reference before reconciling.
- Financial reconciliation functions are service-role-only, but the global reconciliation path can create exceptions; they must only be run by controlled scheduled/operations workflows and tested on fixtures.
- One older customer-payment activation helper and a newer Razorpay captured-payment reconciliation path coexist. Their callers, trigger paths, and migration history need an explicit map before any legacy path is removed.
- Public wrappers for refund request review/submit are authenticated-callable but rely on private function guards. Tests must prove wrong customer, cross-organisation, same-user requester/reviewer, non-finance user, non-AAL2 user and replay cases are denied.
- Do not activate recurring SaaS checkout or any freight payment pathway from this review. Payment-provider eligibility and commercial approval remain separate blockers.

### Required tests before production sign-off
1. Full refund request: wrong customer, wrong organisation, unpaid order, amount mismatch, duplicate request, duplicate idempotency key and concurrent retry.
2. Refund review: customer requester, partner user, ordinary org admin, non-finance member, no MFA, insufficient note, invalid state and concurrent review.
3. Refund execution: different executor from approver, missing finance permission, expired/revoked membership, mismatched amount/currency, already-present provider refund ID and repeated execution claim.
4. Ledger: invalid/negative/zero amount, same debit/credit account, inactive/wrong-org account, currency mismatch, duplicate reference and concurrent duplicate posting.
5. Partner payout: missing treasury rule, approval missing, approval mismatch, duplicate provider payout, provider reference mismatch and repeat reconciliation.
6. Payment webhooks: duplicate event, stale event, failed then captured, conflicting provider payment ID, amount/currency mismatch, quote changed after order creation, and shipment/assignment state mismatch.
7. SaaS subscriptions must remain in a separate schema/domain with dedicated plan, subscription, entitlement, invoice, payment-event and refund records.

### Disposition
The reviewed finance/refund internal helper privilege boundary is fail-closed at the database grant layer, and the refund request/review logic has useful identity, MFA, approval separation and idempotency protections. This is a static code review only. No payment, refund, invoice, payable, ledger or reconciliation record was created or changed. Production payment settings were not modified.
