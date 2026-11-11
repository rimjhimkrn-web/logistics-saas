# KRIM Booking Lifecycle — Coordinated Database Migration and Rollback Design
Date: 2026-11-11
Branch: `audit/workspace-rls-review-2026-11-11`
Status: DESIGN ONLY — NOT EXECUTABLE SQL — NOT DEPLOYED

## Executive decision

Do not apply the existing partial migration `20261111120000_secure_global_quote_acceptance_partner_assignment.sql` alone.

Production currently has three incompatible meanings mixed together:
- quote award (commercial selection),
- partner acceptance (capacity commitment),
- customer quote acceptance/payment and shipment readiness.

The two award RPCs are not equivalent:
- `krim_award_partner_quote` marks the partner quote accepted, rejects competitors, marks the opportunity awarded, creates an assignment as `offered`, and attempts `quoted -> confirmed`.
- `krim_award_partner_quote_for_checkout` calls that function and then creates a customer quote and quote version as `accepted` before the partner accepts.
- `krim_accept_global_quote` independently accepts a `sent` customer quote and confirms the shipment without checking partner acceptance/capacity.

The shipment readiness evaluator requires paid evidence for states beyond `draft/requested`, but treats partner assignment as not required while shipment is `quoted/confirmed`. The readiness trigger runs on transitions to `confirmed/assigned/dispatched`. Therefore simply moving partner acceptance earlier or later without redesigning readiness is unsafe.

## Target lifecycle contract

Use existing statuses where possible. Avoid introducing new enum-like values until every CHECK constraint, client, report, RPC, trigger, event consumer and integration has been inventoried.

| Stage | Partner quote | Opportunity | Assignment | Customer quote/version | Shipment | Capacity |
|---|---|---|---|---|---|---|
| Sourcing | submitted/under_review/shortlisted | open | none | none | requested/quoted | none |
| Offer issued | selected quote remains shortlisted (or explicit offered status after migration) | remains open/shortlisted, not awarded | offered | draft/sent + presented | quoted | none |
| Partner accepted | selected quote accepted | awarded only now | accepted | sent/presented, still awaiting customer | quoted | committed shipment-level capacity |
| Partner capacity confirmed | accepted | awarded | accepted | sent/presented | quoted | confirmed reservation + confirmed leg binding |
| Customer accepts | accepted | awarded | accepted | accepted | quoted | commitment + binding + reservation confirmed |
| Payment verified | accepted | awarded | accepted/active as workflow requires | accepted | confirmed | all capacity gates remain valid |
| Operations activation | accepted | awarded | active | accepted | assigned | binding/reservation still valid |
| Dispatch | accepted | awarded | active | accepted | dispatched | dispatch trigger confirms binding/reservation |

Important: the table is a proposed contract. Before implementation, validate whether `quoted` can remain through payment and whether shipment `confirmed` is the correct post-payment state in all operational modules. Do not change status semantics solely based on this document.

## Database migration work packages

### M0 — Preconditions and compatibility inventory (must finish first)
- Freeze current production function definitions, identity arguments, return types, grants, trigger definitions, constraints and dependencies.
- Inventory every repository and database consumer of `awarded`, `confirmed`, `accepted`, `offered`, quote versions, readiness gates and payment evidence.
- Inventory event processors and outbox consumers for `krim_events`, `krim_audit_events`, shipment status history, tracking events, analytics and notifications.
- Identify all callers of `krim_transition_shipment`, `krim_internal_finalize_partner_assignment`, `krim_internal_dispatch_assigned_shipment`, readiness evaluator and capacity reservation RPC.
- Verify existing production data shape read-only before adding uniqueness constraints or changing status rules.
- Confirm mobile/web versions in circulation and API backward-compatibility plan.

Exit condition: complete dependency matrix and no unknown writer/caller for the state columns being changed.

### M1 — State and data-integrity migration
Prefer no new statuses initially. If the final contract requires new statuses, use a separately reviewed migration:
- Add CHECK-constraint values only after all clients and consumers can safely understand them.
- Add explicit foreign-key/uniqueness protections for one live assignment/one live customer quote per intended shipment/opportunity, after duplicate data audit.
- Ensure a partner quote can be selected/offered without prematurely setting it to `accepted`.
- Ensure opportunity award fields/status are set only at the accepted-partner milestone.
- Ensure customer quote and version status remain `draft/sent` and `presented` until the customer accepts after all partner gates.
- Ensure expiry/rejection/cancellation closes both quote and latest active version consistently.
- Add immutable event records for offer, partner acceptance, capacity commitment, capacity reservation, customer acceptance, payment verified, operations activation and dispatch.

Migration must be additive and guarded. Do not silently rewrite historical quotes, assignments, payments or shipment states. Any backfill requires a separate data reconciliation report, dry-run counts and explicit approval.

### M2 — Partner quote award RPC
Replace `krim_award_partner_quote` with a transactionally coherent offer operation:
- retain auth.uid, active customer organization, quote.update and shipment.update permission checks;
- retain development/test partner prohibition and partner verification/compliance/capability revalidation;
- lock shipment, opportunity, selected quote and any existing live assignment in a consistent documented lock order;
- enforce opportunity open/deadline and quote validity;
- create one `offered` assignment with bounded response deadline;
- do not set selected partner quote `accepted`, do not reject competing quotes, do not set opportunity `awarded`, and do not transition shipment to `confirmed` at offer time;
- record offer event and audit event in the same transaction;
- make retries return the same still-live offer only when identity and requested state match; otherwise reject with deterministic conflict.

Competitor quotes should remain available until partner acceptance. On successful acceptance, reject/cancel competitors atomically with a reason/event.

### M3 — Checkout award wrapper
Replace `krim_award_partner_quote_for_checkout` so it no longer means “accepted checkout quote”:
- create a customer quote in `sent` (or a clearly defined pending/presented state using existing supported values) and quote version `presented`;
- ensure this quote is explicitly non-payable until partner acceptance and confirmed capacity binding/reservation;
- do not create quote or version as `accepted`;
- preserve validity bounded by partner quote expiry and maximum validity;
- preserve pricing snapshot and exact currency/amount binding;
- use a unique constraint/idempotency key to prevent multiple active quotes for the same partner award;
- return a structured state contract including assignment status, quote status and `payment_ready=false`.

### M4 — Partner response RPC
Update `krim_respond_to_partner_assignment`:
- preserve active partner membership, shipment.update permission, response deadline, quote linkage, route capability and current compliance checks;
- use deterministic lock order: shipment -> opportunity -> assignment -> partner quote -> relevant capacity rows (or document and apply one lock order consistently across all functions);
- accept once only; idempotent same-user/same-decision retry returns the existing state, contradictory retry rejects;
- on accept, atomically set assignment accepted, partner quote accepted, opportunity awarded, reject competitors, commit shipment-level capacity, and write tracking/audit/domain events;
- verify assignment still belongs to the active selected opportunity and no other live accepted/active assignment conflicts;
- do not transition shipment to `confirmed` here unless the readiness model is explicitly changed and the required payment state is already satisfied;
- on reject, close the pending customer quote/version and mark offer/selected partner quote appropriately; reopen opportunity for another partner only if policy permits and no other live assignment/payment exists.
- capacity commitment trigger remains authoritative; tests must prove rollback of the entire partner acceptance if commitment fails.

### M5 — Capacity reservation and assignment activation
Preserve two distinct gates:
1. Shipment-level capacity commitment created on partner acceptance.
2. Time-window physical resource reservation and confirmed leg binding created by partner schedule action.

The capacity reservation transaction must prove:
- same shipment, partner org, assignment, leg, transport mode and lane;
- current partner capability and compliance;
- verified available physical resource, active availability window, unit compatibility and capacity remaining;
- no double-booking across overlapping availability windows;
- one matching active partner capacity commitment (reject zero/multiple matches);
- reservation and binding both confirmed and mutually linked;
- assignment links to the confirmed binding;
- commitment counters and audit/events commit atomically.

Do not allow customer acceptance/payment if only the shipment-level commitment exists but the leg binding/reservation is absent.

Update `krim_internal_finalize_partner_assignment` to require the final commercial state and all capacity gates it is supposed to enforce. It currently requires shipment `confirmed`, assignment `accepted` and shipment-level committed capacity, then changes assignment to active and shipment to assigned. It does not itself check the confirmed leg binding/reservation. Add that check only after confirming no existing caller legitimately finalizes before schedule reservation.

### M6 — Customer quote acceptance
Replace `krim_accept_global_quote`:
- validate auth identity, customer org membership, shipment.update permission, quote ownership and exact quote/shipment/partner quote identity;
- lock shipment, opportunity, quote/version, assignment and capacity rows consistently;
- require quote `sent`, not expired, selected partner quote accepted and matching;
- require exactly one accepted/active matching assignment;
- require committed shipment capacity and confirmed binding + confirmed reservation for the same partner/shipment/leg;
- verify quote amount/currency/validity still match the accepted partner quote and pricing snapshot;
- accept quote and current version once, write immutable event/audit;
- return deterministic idempotent result on same accepted quote retry;
- do not move shipment to `confirmed` until the defined payment and readiness gate is satisfied.

### M7 — Shipment readiness and transitions
Split readiness into stage-specific predicates rather than one overloaded boolean:
- sourcing readiness: valid route/market/corridor, customer data, cargo;
- partner readiness: accepted assignment + active partner compliance/capability;
- capacity readiness: committed capacity + confirmed leg binding/reservation;
- commercial readiness: customer quote accepted with matching partner quote;
- payment readiness: provider-verified exact amount/currency and correct customer/shipment;
- execution readiness: compliance/documents/customs, partner, capacity and payment as required for dispatch.

Define exactly which predicate gates each shipment transition. At minimum:
- `quoted -> confirmed` must not be triggered by partner offer creation;
- `confirmed -> assigned` requires the accepted partner, capacity and commercial/payment conditions agreed by policy;
- dispatch requires confirmed reservation/binding and active accepted assignment, as existing dispatch guard already enforces;
- preserve service-role-only internal transitions and do not grant direct client updates.

The readiness evaluator currently treats partner as `not_required` in `quoted/confirmed`, and requires paid evidence for any state beyond `draft/requested`. Change this only with the agreed state machine and a test matrix; do not remove payment gates.

### M8 — Payment order, verification and webhook
Keep Razorpay fail-closed:
- order creation checks accepted customer quote, accepted assignment, partner quote identity, committed capacity, confirmed reservation/binding, exact amount/currency, validity and merchant capability;
- verification repeats the checks and verifies provider signature/order/payment identity;
- webhook verifies signature/event identity, amount/currency and canonical payment state;
- payment must not be captured/posted as a shipment payment if the partner assignment or capacity gate has been cancelled/expired/replaced;
- race handling: if partner rejects/cancels or capacity expires after order creation but before payment verification, verification must reject or route to a safe refund/manual-review state; never silently confirm;
- idempotent duplicate provider events and payment retries must not create duplicate ledger postings, invoice, payout or shipment state transitions.
- SaaS subscription billing remains separate from freight payments.

## API and client compatibility

Do not silently change existing RPC return shape while old clients remain live.

Preferred transition:
1. Introduce versioned RPCs with explicit structured response (or preserve exact return type and add a separate state/status RPC).
2. Update customer web, operations web, partner web, customer app and partner app to new contract.
3. Add compatibility tests for old clients; temporarily make old mutation RPCs fail closed with actionable upgrade error once the cutover is approved.
4. Update partner mobile capacity reservation UX or provide a secure supported web handoff.
5. Only after clients are deployed and verified, retire old RPC grants/callers.
6. Keep driver app downstream of authorized dispatch only.

Required response fields: `assignment_id`, `assignment_status`, `partner_quote_status`, `opportunity_status`, `customer_quote_id`, `customer_quote_status`, `quote_version_id`, `capacity_commitment_status`, `capacity_binding_status`, `reservation_status`, `payment_ready`, `next_action`, `idempotent`.

## Grants and security

- Preserve SECURITY DEFINER functions with empty/fixed search_path and schema-qualified object references.
- Verify execute grants after each migration: anon must remain denied; authenticated only for intended user-facing RPCs; internal helpers service_role-only.
- Revalidate every SECURITY DEFINER auth.uid, active membership, org permission, object ownership, state and row-lock check.
- Do not rely on frontend prechecks.
- Review service_role Edge Function paths separately.
- Add tests for cross-org quote/assignment IDs, forged partner IDs, wrong customer org, expired quote, revoked membership, insufficient permission, MFA requirements for admin actions, anonymous calls, service-role-only helpers, replay and concurrent requests.
- Never add broad RLS policies to make the flow work.

## Mandatory regression test matrix

### Award and partner response
- customer org owner/admin with permissions succeeds; viewer/other org/anon fails;
- ineligible/development partner, expired quote, closed opportunity, route/mode/weight mismatch fail;
- repeated award returns same offer; concurrent award of two partner quotes cannot create two live assignments;
- partner accepts once; contradictory second decision fails; duplicate same decision is idempotent;
- partner membership revoked/compliance expired before accept fails;
- capacity commitment missing/insufficient/expired causes complete rollback;
- competitor quotes are rejected only after selected partner accepts.

### Capacity
- verified matching resource succeeds;
- wrong org, wrong mode/lane/unit, unverified resource, inactive availability, expired window fail;
- insufficient physical capacity, overlapping availability double-book, multiple commitment matches fail;
- concurrent reservations cannot exceed capacity;
- reservation and binding are both confirmed and linked; retries do not duplicate.

### Customer acceptance and payment
- no acceptance before partner acceptance and confirmed reservation/binding;
- wrong partner quote, wrong shipment, wrong org, stale amount/currency, expired quote, missing version fail;
- customer acceptance retry is idempotent;
- Razorpay order fails for any missing partner/capacity/payment-capability prerequisite;
- verification/webhook recheck all state and exact amount/currency;
- partner rejection/capacity expiry after order creation but before verification cannot result in captured/posted shipment payment without safe reconciliation;
- duplicate webhook/payment retries create one financial posting.

### Rejection, expiry and downstream
- reject offer closes pending customer quote/version and emits correct events;
- quote expiry closes version and blocks order;
- cancellation releases commitment/reservation/binding exactly once;
- claim eligibility remains correct for confirmed/closed shipments;
- shipment event, snapshot, status history, audit, notifications and analytics reflect actual transitions exactly once;
- dispatch and driver actions remain blocked until authorized dispatch.

## Rollback plan

Each migration must be small and separately reviewable. Never combine a state rewrite, payment changes and grants into one irreversible deployment.

1. Pre-deployment: take provider-supported backup/PITR confirmation, capture migration version and catalog snapshots, verify no conflicting deployment.
2. Deploy additive tables/columns/constraints/functions first; do not delete or rewrite old functions yet.
3. Deploy new versioned RPCs and clients behind a server-side feature flag that defaults OFF.
4. Run synthetic end-to-end tests in staging only; no production test shipment or payment.
5. Enable for internal test organisation only after explicit approval; retain kill switch.
6. Observe events, failed RPCs, capacity counters and payment reconciliation.
7. Roll back by disabling feature flag and routing clients to safe request-only flow; do not revert schema destructively if any new records exist.
8. If additive schema must remain, leave it dormant; only drop after confirming zero references/data and separate approval.
9. Never reverse actual captured payment or ledger records through a schema rollback. Use controlled refund/reconciliation workflows.

## Release gates

- Staging schema is currently blank and has no app tables/functions/migrations; no paid branch has been approved.
- A reviewed schema-only bootstrap is required before staging tests; no production data, auth users, secrets, payment credentials or storage objects should be copied.
- CI must pass SQL lint/static security checks, function grant assertions, migration dry-run and Deno/TypeScript/mobile tests.
- Staging E2E must pass all cases above, including concurrent transactions.
- Independent review of SQL, grants, triggers and rollback.
- User approval required before any production DDL, payment setting, Edge Function deployment or cost-incurring staging action.

## Explicit non-actions

This document is design guidance only. It is not executable SQL and must not be pasted into production SQL editor. No migration was applied, no data was changed, no grant/function/trigger was changed, no payment was attempted, and no paid staging branch was created.
