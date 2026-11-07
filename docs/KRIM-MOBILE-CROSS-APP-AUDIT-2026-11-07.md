# KRIM Mobile Cross-App Operational & Security Audit
**Audit date:** 7 November 2026  
**Scope:** Customer, Partner and Driver mobile workspaces; live Supabase access controls and operational RPC contracts.  
**Environment:** Production Supabase inspected read-only. No production rows, schema, grants, credentials, payments or assignments were changed.

## Executive result
The three Expo applications have authenticated, read-only workspace foundations. They are not production-ready mobile releases. Booking, partner quotation submission, assignment acceptance, trip-event writes, POD upload and payment actions remain gated.

## Live data snapshot
Counts observed during this audit:
- Shipments: 18
- Customer quotes: 7
- Partner opportunities: 3
- Driver assignments: 0
- Driver trip events: 0

These are database counts, not proof of active commercial fulfilment or revenue.

## Authorization review
### Customer
- Organization memberships are read for the authenticated user and active memberships.
- Shipment and quote lists are filtered to the selected customer organization and remain subject to RLS.
- Shipment tracking uses `krim_get_shipment_tracking`, a SECURITY DEFINER RPC with authenticated execution. Its implementation must continue to enforce authenticated user and customer-organization / active partner-assignment authorization.
- Customer booking and payment actions are not enabled.

### Partner
- Partner workspace reads organization, verified capability, opportunity, quote and assignment data through existing authenticated reads/RLS.
- Do not enable quote submission using the current `krim_submit_partner_quote` contract: it chooses the earliest active eligible partner organization for the user rather than accepting the organization selected in the UI. This can misattribute a quote for multi-organization users.
- Do not enable assignment response until the full partner assignment RPC, permission contract and end-to-end state transitions are covered by tests.

### Driver
- `krim_driver_assignments` SELECT policy requires `user_id = auth.uid()` and an active driver membership in the same organization.
- `krim_driver_trip_events` SELECT policy requires the event's user to be the authenticated user, the event assignment to belong to that user, and active driver membership.
- Driver profile SELECT is scoped to the authenticated user's own profile.
- `krim_driver_accept_assignment` checks active driver membership, verified driver identity and accepted front/back licence evidence, assigned verified vehicle and approved vehicle documents, linked accepted commercial assignment, shipment state, payload capacity, road leg and current approved partner service area.
- `krim_driver_record_trip_event` enforces event order and linked assignment/shipment/leg/partner state. Delivery completion is not a supported event; it requires the separate POD workflow.
- `krim_driver_submit_delivery_pod` checks authenticated assignment ownership, active driver membership, in-transit state, accepted linked partner assignment, and evidence file ownership in the private `krim-driver-evidence` bucket.
- Driver app currently performs read-only queries. No location tracking or write actions are enabled.

## Confirmed release blockers
1. No driver assignments or trip events currently exist, so driver execution cannot be end-to-end validated with real assigned work.
2. The partner quote RPC must be redesigned/reviewed to accept and validate an explicit partner organization ID before multi-organization quote submission is exposed.
3. Partner accept/reject and driver accept / trip-event / POD workflows require authenticated negative and positive integration tests before enabling UI actions.
4. Customer booking and quote acceptance require complete server-authoritative lifecycle, payment and failure/retry tests.
5. Razorpay payment-to-ledger-to-partner-settlement reconciliation remains a separate production gate; no payment was initiated in this audit.
6. Physical Android device testing, private environment configuration, EAS signing, release build and store review are still outstanding.
7. Public client apps must use only the Supabase publishable key. Never embed service-role keys or other server secrets.

## CI finding and correction
The mobile validation run associated with the earlier PR merge commit passed Partner and Driver but failed Customer TypeScript checking because `CustomerWorkspace.tsx` imported `./supabase` and `./customerRepository` from the wrong directory. The imports were corrected to `./lib/supabase` and `./lib/customerRepository` in commit `70b90c22b9147e4818b392fb6de928e616794a4e`. A new successful validation run is not yet evidenced at the time of this report.

## Go / no-go
**NO-GO for public production launch or live operational actions.**  
**GO for continued development, internal read-only testing and partner/customer onboarding preparation.**

This report is an evidence-based engineering checkpoint, not a legal, regulatory, security certification or operational guarantee.
