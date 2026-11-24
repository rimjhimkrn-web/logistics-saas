# KRIM authenticated shipment / partner RPC security triage — 2026-11-24

## Scope
Read-only production catalog review of SECURITY DEFINER functions in `public` whose names match shipment, partner, workflow or notification. This is a static triage, not a penetration test. No database changes were made.

## Inventory
- 44 matching SECURITY DEFINER functions are executable by `authenticated`.
- All 44 have an explicit function-level `search_path` override; none inherit the caller's default search path.
- 42 directly reference `auth.uid()`.
- 33 contain a `krim_has_permission` or `private.krim_has_permission` authorization check.
- The remaining functions require case-by-case review because some use direct membership, warehouse-operator checks, organization-access helpers, or delegate to a separately secured RPC.
- None of the 44 are executable by `anon` according to the catalog privilege check.

## Focused manual review
1. `krim_partner_register_capacity_resource_for_lane(...)` and `krim_partner_submit_service_capability_v2(...)` do not directly read `auth.uid()`. Both delegate to the authenticated-executable base RPCs:
   - `krim_partner_register_capacity_resource(...)` checks `auth.uid()`, active organization membership, `partner.manage`, partner organization type, current compliance, verified capability coverage and ownership of private evidence objects.
   - `krim_partner_submit_service_capability(...)` checks `auth.uid()`, `partner.manage`, active registered-business partner status, current compliance, valid mode/country, and evidence object ownership.
   Their wrappers add lane attachment / bounded details persistence after the base RPC succeeds. No direct auth bypass was established in this static review.
2. `krim_customer_list_partner_quotes(...)` requires an authenticated user and verifies organization access for every requested shipment before returning partner quotes.
3. `krim_provision_partner_organization(...)` requires an authenticated user, derives the new organization membership from that user, prevents multiple active partner organizations, and creates the new organization in pending verification/compliance state.
4. `krim_set_partner_account_mode(...)` requires an authenticated user and derives the partner organization from active membership; approved/active partners cannot be switched into non-commercial modes.
5. `krim_warehouse_list_assigned_shipment_legs(...)` calls the warehouse operator authorization helper before returning assigned shipment legs.
6. `krim_create_global_shipment_from_places(...)` requires an authenticated user and delegates to the core shipment creation RPC. Its core authorization is inherited from that callee and should remain part of future regression tests.

## Important limitations
- This review does not prove every SECURITY DEFINER function is safe. It did not dynamically test cross-tenant IDs, forged JWT claims, malformed inputs, storage ownership edge cases, race conditions or every indirect callee.
- SECURITY DEFINER functions outside the name filter and other schemas were not reviewed here.
- The global Supabase advisor findings (SECURITY DEFINER executable-by-authenticated and RLS-without-policy) still require object-by-object triage; do not bulk revoke or add policies.
- A few function search paths intentionally include `pg_temp`; those functions require source-level confirmation that all security-sensitive relations/functions are schema-qualified.

## Release gates
Before production release:
1. Add negative cross-tenant RPC tests for customer shipment access, partner capacity submission, partner quote submission/award, driver assignment and warehouse inventory operations.
2. Verify all security-definer indirect callees and object ownership / EXECUTE grants.
3. Audit all remaining SECURITY DEFINER functions, not only this name-filtered subset.
4. Keep PR #245 draft until migration-source reconciliation and the full security regression pass.

## Decision
No immediate direct authorization bypass was established in the focused static sample, but this is not a security sign-off. No production grants, policies or function definitions were changed.
