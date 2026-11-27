# KRIM India Launch — Remaining SECURITY DEFINER Review
**Date:** 27 November 2026  
**Environment:** Staging project `qrpcivhdxobiaofppbkl` only  
**Production:** Not accessed  
**Method:** Read-only catalog and function-definition inspection. No RPC invocation.

## Refreshed inventory
The current Staging query returned 55 SECURITY DEFINER functions executable by `authenticated` in the inspected exposed schemas:
- 55/55 have an explicit function search_path setting.
- 51/55 set an empty search_path.
- 53/55 contain an `auth.uid()` reference.
- 2/55 do not contain a direct `auth.uid()` reference.
- 0/55 are executable by `anon` in this query.

These are static indicators, not a blanket security certification. A function without a direct auth.uid() call can still delegate to a guarded function; every wrapper/dependency must be checked. Likewise, explicit search_path does not prove object authorization.

## Two no-direct-auth.uid() functions investigated

### 1. `public.krim_admin_list_capacity_resources_lane_aware()`
- SECURITY DEFINER; search_path is `pg_catalog, public`, not empty.
- It delegates immediately to `public.krim_admin_list_capacity_resources()`.
- The delegated function checks authenticated identity, AAL2 and `admin.platform` permission before returning the platform-wide pending-review queue.
- The wrapper then enriches those results with lane and availability data.
- Static conclusion: the authentication/authorization boundary is inherited from the delegated function. The wrapper is an admin-only read path by dependency, not an unauthenticated public path.
- Follow-up: explicitly document the dependency and consider empty search_path with fully qualified references as consistency hardening. No change made.

### 2. `public.krim_partner_submit_service_capability_v2(...)`
- SECURITY DEFINER; empty search_path.
- It delegates to `public.krim_partner_submit_service_capability(...)`, then adds bounded submission detail fields.
- The delegated function checks `auth.uid()`, `partner.manage` permission for the supplied organization, active registered-business partner status, current compliance, active transport mode, valid service/coverage fields, evidence path ownership and private storage object ownership.
- The wrapper only updates the capability row returned by the guarded submit function and returns its result.
- Static conclusion: organization/user authorization is inherited from the delegated submit RPC; no missing authorization was established in this wrapper review.
- Follow-up: regression-test cross-organization IDs, another user's evidence paths, inactive/noncompliant partner and malformed detail payload. No change made.

## Broader priority review
Previously inspected partner verification, quote award/acceptance, driver assignment/acceptance, dispatch and tracking functions showed explicit empty search_path and visible identity/role/organization checks in their definitions. Some administrative operations write real in-app notifications and email outbox rows; do not invoke them with fixtures until notification isolation is proven.

## Remaining risk and decision
- The 55-function inventory is not fully closed. This pass investigated the two functions without a direct `auth.uid()` reference and confirmed their delegated authorization path by static inspection.
- 4 functions use a non-empty but explicit search_path; they require individual review of name resolution and fully qualified object references.
- SECURITY DEFINER dependencies, triggers, views and storage policies remain part of the authorization surface.
- No blanket revoke, broad grant, policy change or function replacement is recommended from this inventory alone.

## Next P0 work
1. Review the remaining 4 non-empty-search_path functions and their called helpers.
2. Trace write-trigger side effects for partner capability, quote, assignment and notification paths.
3. Finish isolated test runtime/queue and notification boundaries.
4. Prepare negative cross-tenant and wrong-role authorization tests.
5. Re-run advisors and targeted privilege checks after any approved fix.

## Safety record
No SQL mutation, function invocation, event insertion, fixture provisioning, queue claim, email/provider/payment call or Production access occurred.
