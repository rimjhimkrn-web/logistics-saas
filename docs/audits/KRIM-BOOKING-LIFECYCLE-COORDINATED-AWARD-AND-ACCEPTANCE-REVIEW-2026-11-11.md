# KRIM Booking Lifecycle — Coordinated Award/Acceptance Gate Review
Date: 2026-11-11
Status: READ-ONLY LIVE DEFINITION REVIEW — NO DATABASE CHANGES

## Why the quote-acceptance patch is not a complete lifecycle fix

The proposed migration `20261111120000_secure_global_quote_acceptance_partner_assignment.sql` tightens `krim_accept_global_quote(bigint)`, but the live booking lifecycle has two distinct award paths. Both must be treated together.

### Path A — customer quote acceptance RPC

Live production definition of `public.krim_accept_global_quote(bigint)` still allows a sent customer quote to become accepted and shipment to become confirmed without checking partner acceptance. The proposed migration adds a linked partner-quote check and requires a matching `krim_shipment_partner_assignments.status='accepted'`.

That gate is directionally correct for this path, but must be tested with the actual quote/assignment rows and all callers.

### Path B — partner-award-for-checkout RPC

Live production definition of `public.krim_award_partner_quote_for_checkout(bigint,timestamptz)` behaves differently:
1. It calls `krim_award_partner_quote(bigint)`.
2. The award function changes the partner quote to `accepted`, marks the opportunity awarded, creates the shipment-partner assignment with status `offered`, and moves shipment `quoted -> confirmed`.
3. The checkout wrapper immediately creates the customer quote with status `accepted`, creates quote version status `accepted`, and records an accepted event.
4. The stored customer payment terms nevertheless say payment occurs after partner assignment acceptance.

This means customer quote state and shipment state are advanced before the partner has accepted the offered assignment. The new `krim_accept_global_quote` migration does not fix this alternate path because this wrapper does not call that function and returns an already-accepted customer quote.

The frontend caller identified in the earlier caller trace is `public/partner-selection-assignment.html`. This route must be included in coordinated remediation and regression tests.

## Capacity and partner acceptance controls confirmed live

The production trigger `trg_krim_ensure_assignment_capacity_commitment` fires after assignment insert or status update. When an assignment becomes `accepted`, it:
- requires positive shipment weight;
- requires a linked partner quote matching shipment and partner;
- creates a `committed` partner shipment capacity commitment;
- verifies partner identity, commitment status, quantity and validity.

The partner response RPC `krim_respond_to_partner_assignment(bigint,boolean,text)` requires authenticated active partner-org access and `shipment.update`, checks route capability and current compliance, then sets assignment accepted. The trigger creates/validates the commitment transactionally.

The internal finalization function separately requires shipment `confirmed`, assignment `accepted`, linked partner quote and a current matching capacity commitment before moving the assignment active and shipment assigned.

Razorpay order creation and verification were previously traced to independently require accepted partner assignment and confirmed capacity binding. The partner shipment commitment and the capacity-leg binding are distinct controls; both must be covered in the end-to-end payment tests.

## Required coordinated remediation

Do not deploy the quote-acceptance migration alone as the complete fix. Before implementation:
1. Define one canonical state sequence for both award routes: customer chooses an eligible partner offer -> assignment offered -> partner explicitly accepts -> capacity commitment is confirmed -> customer quote becomes payable/accepted -> payment may be initiated -> operations assignment/dispatch gates.
2. Change `krim_award_partner_quote` so awarding creates an offer but does not falsely mark partner quote accepted, opportunity awarded, or shipment confirmed before partner response. Confirm dependent triggers and business reporting semantics before choosing exact states.
3. Change `krim_award_partner_quote_for_checkout` so it does not create customer quote/version/event as accepted while assignment remains offered. It should create a pending/sent customer quote or an explicit pending-partner-acceptance state supported consistently by schema, UI and RPCs.
4. Ensure partner acceptance updates all related records atomically and idempotently, including partner quote, opportunity, assignment, capacity commitment and customer quote readiness.
5. Retain the hardened `krim_accept_global_quote` gate for any separate customer acceptance path, but align allowed quote states and ensure it cannot bypass the canonical sequence.
6. Update web and mobile callers, quote comparison, partner accepted-loads, dashboards, Razorpay order/verification and webhook reconciliation.
7. Test retries, concurrent partner/customer actions, rejected offers, expired quotes, alternate award paths, multiple partner offers, amount/currency mismatch, capacity exhaustion, cancelled/re-awarded shipments and stale customer UI.

## Release decision

The existing proposed migration is a partial guard, not a complete fix. The award RPCs must be redesigned and tested as one coordinated lifecycle before production deployment. Do not merge or apply any of these changes based only on the partial migration.

## Safety status

This review read live function and trigger definitions only. No production or staging DDL, data, grants, payment settings, Edge Functions or operational records were changed. No test bookings or payments were created.
