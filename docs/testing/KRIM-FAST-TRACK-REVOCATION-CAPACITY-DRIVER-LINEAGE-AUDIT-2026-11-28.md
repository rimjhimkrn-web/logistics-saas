# KRIM Fast-Track — Capability Revocation, Capacity and Driver Execution Audit
Date: 2026-11-28
Environment: Staging only (qrpcivhdxobiaofppbkl)
Method: read-only inspection of live function definitions. No functions invoked; no data or schema changed.

## Confirmed revocation behaviour
The public.krim_admin_revoke_partner_capability(bigint,text) function:
- requires authenticated AAL2 and platform-admin permission;
- locks the capability and partner organisation;
- only revokes an active, verified capability;
- marks it inactive and suspended and writes an audit event;
- explicitly returns existing_assignments_cancelled=false.

It does not enumerate dependent matching results, open opportunities, submitted quotes, accepted assignments, capacity commitments, driver assignments, or in-progress shipments. No operations exception is created by this RPC. This confirms the revocation-to-operations gap previously identified.

## Capacity and assignment controls observed
- Capacity commitment attachment trigger chooses a matching active commitment by partner, lane, mode, unit, time interval and remaining capacity; if more than one matches, it rejects the reservation as ambiguous.
- Assignment acceptance trigger requires positive shipment weight and a matching partner quote, then creates/validates a committed capacity commitment for the assignment.
- Assignment finalization separately locks and validates capacity binding, reservation, shipment leg and capacity commitment before activating the assignment.
- Capacity reservation accounting updates reserved/utilized counters and rejects inconsistent counters or inactive/insufficient commitments.
These are useful physical-capacity controls. They do not establish which approved partner capability/evidence version authorised the partner for the shipment.

## Driver execution linkage
- Driver assignment acceptance requires the exact linked partner assignment to match shipment, leg and partner organisation and be accepted/active.
- It also checks active driver membership, verified driver profile, current licence and accepted front/back licence plus identity evidence, verified active vehicle binding and required approved vehicle documents.
- This is a meaningful downstream linkage safeguard, but it does not carry or verify the partner capability eligibility decision used upstream.

## Combined invariant required
Revocation, capacity and driver execution need one shared lineage chain:
capability submission/version -> immutable eligibility decision -> opportunity/quote version -> partner assignment -> capacity binding/reservation/commitment -> driver assignment -> shipment leg/execution.

Revocation workflow should:
1. atomically suspend the capability and block new eligibility decisions/quotes/awards using it;
2. identify dependent open opportunities and submitted quotes for withdrawal/re-evaluation;
3. identify accepted assignments, reservations, commitments and driver assignments;
4. create a durable operations exception per affected work item, preserving shipment and assignment records;
5. require an authorised operator to resolve each case (continue under documented exception, requalify, or arrange controlled reassignment);
6. release capacity only through existing audited reservation/commitment lifecycle rules, never by deleting records or blindly zeroing counters.

Concurrency requirements: revocation and new quote/award/finalization must lock capability/decision rows in a consistent order so no new allocation races past suspension. Already in-transit execution must not be silently cancelled. Legacy work without capability lineage remains unattributed pending review.

## Regression tests
- Revocation blocks new match, quote, award and allocation immediately.
- Revocation identifies all affected open and accepted workflow records.
- Accepted/in-progress assignments remain intact and receive operations exceptions.
- Driver acceptance is blocked when its linked partner assignment is no longer valid, without destroying the driver record.
- Capacity reservations/commitments remain balanced through operator resolution, release, completion and reassignment.
- Concurrent revocation and quote award cannot create an allocation after revocation wins the lock.
- Ambiguous overlapping capacity commitments continue to fail closed.
- Missing capability lineage blocks new awards/finalization but does not trigger inferred backfill on legacy rows.

## Status / limitations
- This audit confirms code paths, not successful runtime E2E behaviour.
- No Staging operational data was modified and no notifications were sent.
- Historical migration ledger reconciliation and a local isolated Supabase CLI/Docker test environment remain blockers to implementation.
- Production was not accessed or changed.
