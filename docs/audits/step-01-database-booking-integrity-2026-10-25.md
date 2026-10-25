# KRIM Logistics — Step 1: Database & Booking Integrity

Audit date: 2026-10-25  
Environment: Supabase production project `ebltviniygljwwseplph`  
Disposition: **Core new-booking safeguards verified; historical exceptions preserved and carried forward.**

## Verified safeguards

- The customer booking page requires transport mode and route type and submits the idempotent shipment-creation RPC with a booking UUID.
- The supported place-based creation function validates route type against the allowed values and rejects invalid domestic/cross-border country combinations.
- The transport-mode function validates the selected mode against supported values.
- The idempotent creation function checks authentication, customer-organisation access, `shipment.create` permission, active organisation status, and requires a booking request reference. It uses an advisory lock and checks existing booking details before returning a retry result.
- The shipment table has RLS enabled and denies direct INSERT to `anon` and `authenticated`; browser creation must go through the controlled RPC.
- The unique partial index on customer organisation + booking request reference protects against duplicate bookings.
- The initial shipment-leg trigger is installed.
- Legacy 5-argument and 6-argument `krim_create_global_shipment_from_places` overloads that omit route type are no longer executable by `anon` or `authenticated`. Service-role execution is retained for backend use.
- The new migration is committed to the repository and applied to production: `20261025141756_retire_legacy_place_shipment_overloads.sql`.

## Production verification result

A read-only invariant query returned:

- Shipment records: 17
- Historical shipments missing one or more of transport mode, route type, and booking reference: 17
- Orphan shipment legs: 0
- Closed-shipment / inconsistent-leg exceptions: 1
- Authenticated access to legacy 5-argument RPC: false
- Authenticated access to legacy 6-argument RPC: false
- Server-side route-type guard present: true
- Server-side transport-mode guard present: true

## Historical exceptions — deliberately not rewritten

1. All 17 existing shipment rows lack requested transport mode, route type, and booking reference. Eight legacy `shipment_requests` rows are not linked authoritatively to the newer records. No missing values were guessed or backfilled.
2. Shipment `KRIM-2026-00000001` is closed and has 11 status-history entries / 12 audit events. Its single leg is marked `assigned` while `assignment_status` is `unassigned`, and its partner organisation field is populated; however, there are no matching current partner-assignment, assignment-activation, or driver-assignment rows. This appears to be historical/test lifecycle data, but the source does not prove the correct replacement state. The leg and history were left unchanged.

## Scope boundary

This audit verifies database safeguards, RPC definitions/permissions, the booking-page call contract, and read-only data invariants. It does **not** claim a live authenticated user journey was executed, nor does it verify live payment or carrier fulfilment. Those require the later end-to-end test workstream and an actual controlled test account/session.

## Step 1 exit disposition

**Step 1 is closed for the core new-booking database safeguards, with two explicit historical-data exceptions carried forward.** The exceptions must not be treated as successful bookings or silently repaired. Reconcile only if authoritative source evidence becomes available. Full authenticated end-to-end booking verification remains in the dedicated automated end-to-end test phase.
