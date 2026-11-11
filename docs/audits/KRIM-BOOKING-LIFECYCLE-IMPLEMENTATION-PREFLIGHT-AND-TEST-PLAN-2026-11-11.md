# KRIM Booking Lifecycle Remediation — Implementation Preflight & Staging Test Plan
Date: 2026-11-11
Status: REVIEW ONLY — NOT A MIGRATION; NO PRODUCTION CHANGES

## Decision

Do not apply a one-function patch. The production state machine has coupled award, partner acceptance, capacity commitment, assignment activation, readiness and dispatch behaviour. The existing customer quote acceptance migration (`20261111120000_secure_global_quote_acceptance_partner_assignment.sql`) is necessary but insufficient: it requires an accepted assignment when the customer accepts, while the award RPC and checkout wrapper currently transition earlier.

The safe implementation must be delivered as a coordinated migration after staging schema parity is established. This document is the implementation gate and test contract, not executable DDL.

## Production behaviour confirmed by read-only inspection

1. `krim_award_partner_quote(bigint)` accepts the selected partner quote, rejects competitors, marks the opportunity awarded, inserts an assignment as `offered`, and transitions a `quoted` shipment to `confirmed`.
2. `krim_award_partner_quote_for_checkout(bigint,timestamptz)` calls the award RPC and creates a customer quote and quote version with status `accepted` while the assignment is still `offered`.
3. `krim_partner_respond_to_invitation(bigint,text,numeric,text,timestamptz,text)` is a second authenticated accept/decline path. Its accept path creates a partner quote and capacity commitment, then marks the assignment `accepted`.
4. `krim_internal_evaluate_shipment_readiness(bigint)` treats partner assignment as `not_required` for shipment statuses `draft`, `requested`, `quoted`, and `confirmed`; partner assignment is required only later.
5. `krim_internal_finalize_partner_assignment(bigint)` expects shipment `confirmed`, assignment `accepted`, and committed capacity, then activates the assignment and moves shipment to `assigned`.
6. The transition matrix currently allows `quoted -> confirmed` and `confirmed -> assigned`; no direct `quoted -> assigned` transition was observed.
7. Capacity commitment, quote-integrity, rejection, terminal capacity release, shipment-readiness and dispatch-capacity triggers are part of this lifecycle and must be preserved or replaced with equivalent tested transactional logic.
8. Frontend callers found include operations award, partner acceptance, checkout award, shipper quote comparison and customer quote operations. The invitation RPC had no direct call in the inspected UI paths but remains an executable backend path and cannot be ignored.

## Target state model

Keep these concepts separate:
- **Partner award pending:** customer/operations selected an offer; assignment is `offered`; shipment remains `quoted`; no customer quote is represented as accepted; no payment order may be created.
- **Partner commitment accepted:** partner has accepted the exact assignment and terms; partner eligibility, route capability, current compliance and capacity commitment are revalidated atomically.
- **Customer commercial acceptance:** customer accepts the customer-facing quote only after partner commitment is valid; this is the point at which a booking may become `confirmed`.
- **Operational activation:** the accepted assignment is finalised/activated and shipment becomes `assigned` only after required capacity/readiness controls.
- **Dispatch:** only the existing dispatch readiness, verified capacity and operations authorisation controls may move the shipment to `dispatched`.

The implementation must explicitly settle whether customer acceptance is required before or after partner acceptance. The required business rule for KRIM is: no customer-visible confirmed booking and no payment eligibility until the partner has explicitly committed to the exact job. Do not infer that quote status `accepted` alone means partner acceptance.

## Coordinated implementation work required

A single reviewed migration (or a tightly ordered migration set) must:
1. Rework `krim_award_partner_quote` so it creates an `offered` assignment without prematurely confirming shipment, and define opportunity/competing-quote states that remain recoverable if the partner declines or the offer expires.
2. Rework `krim_award_partner_quote_for_checkout` so it creates a customer quote in a non-accepted state (normally `sent` or another explicitly approved pending state); quote version and event must agree. It must not create a paid order or accepted commercial record.
3. Reconcile both partner acceptance RPCs. They must converge on one guarded transactional acceptance path or demonstrably equivalent checks. Validate exact assignment ownership, active membership and permission, assignment deadline, active registered partner, verified capability for this shipment, current compliance, quote validity, amount/currency and capacity before writing accepted state.
4. Reconcile `krim_internal_finalize_partner_assignment`, shipment transition rules and the readiness evaluator so the intended confirmed/assigned states do not contradict the partner commitment requirement.
5. Preserve quote-integrity, acceptance-capacity, cancellation, capacity-release, shipment-readiness and dispatch-capacity trigger guarantees. Update any trigger that assumes an opportunity is already awarded or a customer quote is already accepted.
6. Keep `krim_accept_global_quote` as a server-side gate: only a sent, unexpired customer quote matching the valid partner quote and an accepted assignment may be accepted. Lock quote, shipment, partner quote and assignment consistently to avoid races.
7. Prevent checkout/order creation and webhook reconciliation from treating a pending/offered assignment or a premature accepted quote as payable.
8. Make every state change idempotent, append audit events transactionally, and define rejection/expiry/cancellation recovery and customer/partner notifications.
9. Restrict all internal helpers to service/function owner as appropriate; retain explicit authenticated RPC permissions only on guarded entry points. Preserve fixed search_path and explicit EXECUTE ACLs.
10. Include rollback that restores function definitions and transition/trigger behaviour from the exact pre-migration snapshot. Do not use a blind down migration if live records have progressed under the new model.

## Read-only staging preflight SQL

Run only against a staging database with schema parity. It reads catalog metadata and does not modify objects or data.

```sql
DO $$
DECLARE missing text[] := ARRAY[]::text[];
BEGIN
  IF to_regprocedure('public.krim_award_partner_quote(bigint)') IS NULL THEN missing := array_append(missing,'krim_award_partner_quote(bigint)'); END IF;
  IF to_regprocedure('public.krim_award_partner_quote_for_checkout(bigint,timestamp with time zone)') IS NULL THEN missing := array_append(missing,'krim_award_partner_quote_for_checkout(bigint,timestamptz)'); END IF;
  IF to_regprocedure('public.krim_partner_respond_to_invitation(bigint,text,numeric,text,timestamp with time zone,text)') IS NULL THEN missing := array_append(missing,'krim_partner_respond_to_invitation(...)'); END IF;
  IF to_regprocedure('public.krim_respond_to_partner_assignment(bigint,boolean,text)') IS NULL THEN missing := array_append(missing,'krim_respond_to_partner_assignment(bigint,boolean,text)'); END IF;
  IF to_regprocedure('public.krim_accept_global_quote(bigint)') IS NULL THEN missing := array_append(missing,'krim_accept_global_quote(bigint)'); END IF;
  IF to_regprocedure('public.krim_internal_finalize_partner_assignment(bigint)') IS NULL THEN missing := array_append(missing,'krim_internal_finalize_partner_assignment(bigint)'); END IF;
  IF to_regprocedure('public.krim_internal_evaluate_shipment_readiness(bigint)') IS NULL THEN missing := array_append(missing,'krim_internal_evaluate_shipment_readiness(bigint)'); END IF;
  IF cardinality(missing) > 0 THEN RAISE EXCEPTION 'Staging schema mismatch: %', array_to_string(missing, ', '); END IF;
END $$;

SELECT p.oid::regprocedure AS signature,
       p.prosecdef AS security_definer,
       p.proconfig AS function_settings,
       has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute,
       has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute
FROM pg_proc p
WHERE p.oid IN (
  'public.krim_award_partner_quote(bigint)'::regprocedure,
  'public.krim_award_partner_quote_for_checkout(bigint,timestamptz)'::regprocedure,
  'public.krim_partner_respond_to_invitation(bigint,text,numeric,text,timestamptz,text)'::regprocedure,
  'public.krim_respond_to_partner_assignment(bigint,boolean,text)'::regprocedure,
  'public.krim_accept_global_quote(bigint)'::regprocedure,
  'public.krim_internal_finalize_partner_assignment(bigint)'::regprocedure,
  'public.krim_internal_evaluate_shipment_readiness(bigint)'::regprocedure
)
ORDER BY 1;

SELECT t.tgname, c.oid::regclass AS table_name, t.tgenabled,
       pg_get_triggerdef(t.oid) AS trigger_definition
FROM pg_trigger t
JOIN pg_class c ON c.oid=t.tgrelid
WHERE NOT t.tgisinternal
  AND c.oid IN (
    'public.krim_shipments'::regclass,
    'public.krim_shipment_partner_assignments'::regclass,
    'public.krim_partner_quotes'::regclass,
    'public.krim_quotes'::regclass,
    'public.krim_partner_shipment_capacity_commitments'::regclass
  )
ORDER BY 2,1;
```

## Required staging regression matrix

Use isolated fixtures with at least two customer organisations, two verified partner organisations, one unverified/expired partner, and independent authenticated users. Never use production customer or partner records.

### Award and checkout quote
- Award creates one `offered` assignment; shipment remains `quoted`.
- Award does not create an `accepted` customer quote/version.
- Repeated award request returns the same assignment and does not duplicate events or capacity reservations.
- Competing partner quotes cannot be awarded after one valid award.
- Expired opportunity, expired quote, inactive partner, unverified capability, expired compliance, wrong route/mode/cargo/weight all fail closed.
- Customer A cannot award Customer B's opportunity; unrelated user and partner user denied.
- Concurrent awards for different partner quotes on one opportunity produce exactly one winner and one consistent assignment.
- Checkout quote creation uses a pending/sent status; quote and quote-version statuses/events remain consistent; no payment order exists.
- Duplicate checkout request returns the same quote or a deterministic conflict without duplicate versions/events.

### Partner acceptance — both entry points
- Owning partner organisation can accept only its own offered assignment.
- Other partner, customer, driver, inactive member, missing permission and anonymous caller are denied.
- Acceptance after response deadline fails; race between expiry and acceptance yields one terminal outcome.
- Partner must still be verified, compliant and capability-valid at acceptance time.
- Amount/currency/partner quote must match the offered terms; altered or stale terms fail.
- Capacity reservation/commitment is created exactly once and is linked to the assignment and quote.
- Both `krim_respond_to_partner_assignment` and `krim_partner_respond_to_invitation` cannot bypass each other's invariants.
- Duplicate acceptance is idempotent; conflicting accept/decline requests cannot both succeed.
- Rejection releases capacity, does not leave opportunity falsely awarded, and permits a controlled next-offer path without reusing a rejected customer quote.

### Customer acceptance and booking confirmation
- Customer cannot accept before partner assignment is accepted.
- Customer can accept only its own sent, unexpired quote.
- Quote, shipment, partner quote, amount, currency, partner organisation and assignment must all match.
- Cross-customer quote ID, stale quote, expired quote, withdrawn/rejected partner quote, rejected/cancelled assignment and wrong partner fail closed.
- Concurrent customer acceptance requests produce one accepted quote/event and one shipment transition.
- Accepted partner assignment remains linked to the same shipment; no reassignment race.

### Finalisation, readiness, dispatch and finance
- Assignment finalizer cannot activate an offered/rejected/expired assignment or uncommitted capacity.
- Confirmed state is impossible before partner commitment and required customer acceptance.
- Readiness evaluator reports partner missing until the required accepted/active assignment exists; it must not label partner `not_required` for a commercially confirmed shipment.
- Dispatch requires active/accepted assignment, confirmed capacity binding, verified route/capability/compliance, shipment readiness and operations authorisation.
- Rejection/cancellation/expiry/completion releases capacity exactly once.
- Payment order creation and webhook capture cannot make an unconfirmed or uncommitted shipment payable/paid.
- No ledger, invoice, payable or partner settlement is created by award or offer alone.
- Every successful and failed privileged transition has an attributable audit trail; mutation and audit must commit atomically.
- Multi-leg shipments require all required legs/assignments and readiness gates before final delivered/closed states.

## Release gate

Do not merge or deploy until:
- staging schema is reconciled with production migration history;
- complete function/trigger definitions and grants are snapshotted;
- the coordinated migration has a reviewed rollback and data-reconciliation plan;
- all regression cases above pass on staging, including concurrency;
- all frontend and backend callers are mapped;
- payment/notification side effects are verified;
- a human operator approves the exact migration and deployment window.

Production has not been changed by this document. Do not treat this review file as executable migration SQL.
