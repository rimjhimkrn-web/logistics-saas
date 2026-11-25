# Phase 00 — Shipment booking, quote, partner assignment and lifecycle audit

Date: 2026-11-25  
Branch: `qa/phase-00-baseline-2026-11-25`  
Scope: read-only SQL function/source and data-consistency review in Production and Staging. No shipment mutations or RPC invocations.

## Executive decision

**NO-GO for real customer shipment onboarding until the confirmed-shipment assignment inconsistency is reconciled and Staging synthetic lifecycle tests pass.**

Production contains six `confirmed` shipments and six accepted customer quotes, but zero partner assignments exist for any of those six confirmed shipments. The current `krim_accept_global_quote` implementation requires a matching accepted partner quote and assignment before a new quote can be accepted. The existing confirmed records date from 2026-09-24 through 2026-09-26 and may predate the current guard. They are therefore historical data requiring reconciliation, not proof that the current function can create an invalid booking.

Staging has no shipment, quote, assignment, capability or partner verification case rows in the inspected tables, so it is not yet a populated synthetic test environment.

## Read-only data snapshot

### Production
- Shipments: 18 total — draft 8, quoted 3, confirmed 6, closed 1.
- Customer quotes: 7 — accepted 6, sent 1.
- Partner quotes: 0.
- Partner assignments: 0.
- Partner capabilities: 1 total; 0 active + verified.
- Partner verification cases: 1.
- Active verified/approved partner organizations: 0.
- Confirmed shipments without any partner assignment: **6 of 6**.
- The six confirmed shipments have one customer quote each, no legacy shipment-request link, and no partner assignment.

### Staging
- Shipments: 0.
- Customer quotes: 0.
- Partner quotes: 0.
- Partner assignments: 0.
- Partner capabilities: 0.
- Partner verification cases: 0.
- Active verified/approved partner organizations: 0.

## Function source and environment comparison

Inspected:
- `krim_create_global_shipment(bigint,bigint,bigint,text,numeric)`
- `krim_create_global_quote(bigint,numeric,text,timestamptz)`
- `krim_accept_global_quote(bigint)`
- `krim_transition_shipment(bigint,text,text,jsonb)`
- `krim_partner_submit_service_capability(...)`
- `krim_partner_submit_service_capability_v2(...)`

### Positive controls observed
- Shipment creation and quote acceptance use organization access and permission checks.
- Quote acceptance locks the quote and shipment rows.
- Quote acceptance checks quote status and expiry.
- Current acceptance requires an accepted partner quote, matching assignment, active/verified organization, verified active capability and shipment coverage.
- Partner capability submission checks partner manager permission, active registered-business organization, current compliance, active transport mode, valid country, bounded fields, evidence path ownership and private storage object ownership.
- Capability submissions are initially inactive and pending verification.
- POD submission is a SECURITY DEFINER RPC with explicit authenticated assignment/driver ownership controls from earlier source review.
- Shipment transition RPC is not directly executable by authenticated or anon in inspected ACL; internal trusted callers are expected.

### Production/Staging drift
The `krim_accept_global_quote` function source differs:
- Production fingerprint: `52a450b8968cf4721f8c4a691c25354a`
- Staging fingerprint: `eb91525bb65c0146c58ccecc2e3d1d6d`
- Staging adds `private.krim_partner_compliance_is_current(o.id)` to the partner eligibility check; Production does not.
- Both require verified partner organization, accepted matching partner quote/assignment, verified active capability and shipment coverage.
- Other inspected lifecycle function fingerprints matched across environments.
- ACL metadata for the quote-accept function showed authenticated/service_role execution in both environments (text order differed only); this is not a grant discrepancy.

This means Staging has a stricter compliance gate than Production. Do not copy or deploy either version blindly; review the migration/source history and agree a canonical implementation before production release.

### SECURITY DEFINER search path note
The inspected `krim_create_global_quote` function is SECURITY DEFINER with `search_path=public, pg_temp`, while most inspected functions use an empty search path. Its body uses schema-qualified references for key tables/functions, but the SECURITY DEFINER search path should be hardened to an empty path after a dependency review. This is a hardening finding, not a confirmed exploit; public schema CREATE is denied to ordinary roles in the prior catalog review.

## Required reconciliation and test gates

1. Investigate the six historical confirmed shipments and accepted quotes. Determine whether they were manually seeded, test records, legacy transitions, or actual customer commitments. Do not auto-create partner assignments or rewrite statuses.
2. Establish an explicit data remediation decision, with audit trail and owner approval, before any mutation.
3. Reconcile the Production/Staging `krim_accept_global_quote` function difference and make the stricter compliance policy canonical if approved.
4. Harden `krim_create_global_quote` SECURITY DEFINER search_path after dependency review.
5. Provision isolated synthetic Staging organizations/users: customer, verified partner, unverified partner, driver and admin. Use fake data and private test evidence only.
6. Test positive flow: customer draft → booking → quote request → partner quote → partner assignment acceptance → customer quote acceptance → confirmation → dispatch → in-transit → delivery → verified POD → close.
7. Test negative cases: cross-organization booking/quote, missing permissions, unverified/inactive partner, expired quote, capability mismatch, non-adjacent/invalid transition, unauthorized driver, wrong assignment, reused POD and concurrent quote acceptance.
8. Verify audit events and user notifications at every lifecycle step. The separate notification audits already show that notification preparation is not delivery.
9. Do not use Production rows for synthetic test runs.

## Evidence boundary

All findings derive from source/catalog reads and aggregate/record-level SELECTs. No RPC or Edge Function was invoked. No shipment, quote, assignment, partner capability, verification case, payment or POD was written. No provider was contacted. Production and Staging remained unchanged.
