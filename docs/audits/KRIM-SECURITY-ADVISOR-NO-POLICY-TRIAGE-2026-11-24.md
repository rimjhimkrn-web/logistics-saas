# KRIM security advisor no-policy triage — 2026-11-24

## Summary
Read-only review of the current production Supabase security advisor findings. No grants, RLS policies, functions or data were changed.

Current advisor totals:
- 29 tables with RLS enabled and no policies (INFO).
- 151 SECURITY DEFINER functions executable by authenticated users (WARN).
- Leaked-password protection disabled (WARN).

## No-policy table grants
Catalog inspection of all 29 listed tables found:
- **No `anon` grants and no `authenticated` grants** on any of the 29 tables.
- Private-schema tables are limited to `postgres` and/or `service_role`.
- Most public-schema tables are limited to `postgres` and `service_role`.
- Three public custody/dispatch tables (`krim_shipment_leg_custody_transfer_events`, `krim_shipment_leg_custody_transfers`, `krim_shipment_leg_dispatch_authorizations`) showed only `postgres` table grants in the catalog query; service-role table grants were absent.
- Therefore the 29 no-policy findings are not evidence of direct PostgREST exposure to anon/authenticated based on the grants observed. They appear intentionally internal-only, but ownership, function-mediated access and application dependencies still need review.
- Do not add permissive policies merely to silence the advisor.

## SECURITY DEFINER triage
For the focused public RPC family (function names containing shipment, partner, workflow or notification):
- 44 functions are SECURITY DEFINER and executable by authenticated users.
- All 44 have explicit function-level `search_path` settings.
- None are executable by `anon` in the catalog privilege check.
- 42 directly read `auth.uid()`; the two that do not are wrappers that delegate to base RPCs which perform authenticated membership/permission and evidence ownership checks.
- 33 contain a KRIM permission helper; remaining functions use direct organization membership, organization access, warehouse operator checks, or delegated authorization. A focused manual review is documented in `KRIM-AUTHENTICATED-SHIPMENT-PARTNER-RPC-SECURITY-TRIAGE-2026-11-24.md`.
- This is a targeted static sample, not a complete review of all 151 advisor findings. It does not establish that every SECURITY DEFINER function is safe.

## Additional issue
The three custody/dispatch tables above may be intentionally accessed only through owner-executed functions/triggers, but service_role lacks direct table grants. Verify actual RPC/trigger use and Edge Function behavior before onboarding shipment custody and dispatch workflows. Do not grant service_role direct table access without confirming the least-privilege requirement.

## Auth configuration
Leaked-password protection remains disabled. Enable it in Supabase Auth settings after assessing the sign-in impact and user communication. This is an Auth configuration task, not a SQL policy fix.

## Release gates
1. Continue object-by-object review of all 151 SECURITY DEFINER findings; validate cross-tenant IDs and indirect callees.
2. Verify the three custody/dispatch table access paths and service-role need.
3. Validate all no-policy tables are not exposed through views, RPCs, storage policies or unintended grants.
4. Enable leaked-password protection and test signup/password reset flows.
5. Keep PR #245 draft until migration reconciliation and broader regression are complete.

## Decision
No broad policy/grant changes are justified by these findings alone. Production remains unchanged.


## Custody / dispatch table access-path follow-up
The three public tables without service_role table grants are not unused:
- `krim_authorize_leg_dispatch` is SECURITY DEFINER and callable by authenticated users; it checks `auth.uid()`, the `shipment.dispatch` permission for the assigned partner, accepted exact-leg assignment, confirmed capacity binding/reservation, and for ROAD mode verified driver/licence/vehicle documents. For later legs it requires an accepted custody transfer from the immediately preceding leg.
- `krim_create_leg_custody_transfer` is SECURITY DEFINER and checks authenticated identity, adjacent legs in the same active route plan, completed releasing leg, releasing-partner `partner.manage`, accepted receiving assignment, confirmed receiving capacity, exact cargo manifest, and uploader-owned private evidence.
- `krim_respond_to_leg_custody_transfer` is SECURITY DEFINER and checks authenticated identity plus receiving-partner `partner.manage`, revalidates receiving assignment and confirmed capacity at acceptance, and records an immutable event.
- `krim_revoke_leg_dispatch_authorization` is SECURITY DEFINER and checks authenticated identity plus partner `shipment.dispatch`; it blocks revocation after pickup/transit.
- Trigger functions on `krim_shipment_leg_dispatch_authorizations` additionally enforce warehouse handover and exact assignment binding.
- Private helper functions are not directly executable by authenticated or service_role, but are invoked internally by owner-executed functions/triggers.

This establishes a concrete owner-executed RPC/trigger access path; it does **not** justify granting service_role direct table access. Keep the no-policy tables without anon/authenticated grants and test the public RPCs with cross-partner/forged-ID negative cases before live use.
