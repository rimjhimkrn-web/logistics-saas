# KRIM India Launch — Non-Empty Search-Path SECURITY DEFINER Review
**Date:** 27 November 2026  
**Environment:** Staging only (`qrpcivhdxobiaofppbkl`)  
**Production:** Not accessed  
**Method:** Read-only static review of function bodies and delegated authorization paths.

## Scope and refreshed result
Reviewed all four authenticated-callable SECURITY DEFINER functions from the current non-empty-search_path subset. This closes the static review of the four search-path exceptions in the 55-function inventory; it does not certify all 55 functions or replace runtime authorization tests.

## Function-by-function findings

### 1. `krim_admin_list_capacity_resources_lane_aware()`
- Search path: `pg_catalog, public`.
- Delegates to `krim_admin_list_capacity_resources()`.
- The delegated function checks non-null `auth.uid()`, AAL2, and `admin.platform` permission before returning pending capacity resources.
- Wrapper only enriches the delegated result with lane/availability metadata.
- Assessment: authorization is inherited through the guarded helper. No unauthenticated path identified in the inspected chain.
- Hardening note: use an empty search_path for consistency and retain fully qualified references; no change made.

### 2. `krim_partner_register_capacity_resource_for_lane(...)`
- Search path: `pg_catalog, public`.
- Checks `auth.uid()`, requires a lane ID, verifies that the lane is active and matches the supplied origin and transport mode.
- Delegates resource creation to `krim_partner_register_capacity_resource(...)`, which independently checks authenticated user, active organization membership, `partner.manage` permission, partner organization type, current compliance, verified active capability for the transport mode/country, valid resource/availability values, and private evidence-file ownership.
- The delegated function creates the resource and availability as pending review/unavailable; the wrapper attaches the lane to the newly returned availability row scoped by both availability ID and organization ID.
- Assessment: organization authorization and evidence ownership are inherited from the delegated helper; lane validation is additional. No immediate missing authorization found in the inspected chain.
- Hardening note: empty search_path consistency and regression tests for mismatched lane, origin, mode and organization. No change made.

### 3. `krim_set_email_marketing_consent(boolean,text)`
- Search path: `pg_catalog, public, auth`.
- Checks `auth.uid()`, requires a non-deleted Auth user, explicit consent decision and non-empty policy version.
- Writes only a `marketing_email` consent event for the current user.
- Assessment: direct user scoping is present; no organization or other-user identifier is accepted. No immediate authorization gap found.
- Regression tests required: grant/revoke append-only history, deleted account, null decision and missing policy version.

### 4. `krim_set_notification_preference(bigint,text,text,boolean)`
- Search path: `pg_catalog, public, auth`.
- Checks `auth.uid()`; only permits `marketing` and `product_updates`, explicitly rejecting attempts to disable essential notification categories.
- Restricts channels to a fixed allowlist; if an organization ID is supplied, requires active membership for the current user.
- Reads/updates preferences by current user ID plus organization/type/channel, with advisory transaction locking.
- Assessment: user/organization scoping and essential-notification guard are visible. No immediate authorization gap found.
- Regression tests required: cross-organization ID, inactive membership, concurrent updates, and attempts to disable essential notifications.

## Overall conclusion
- All four non-empty-search_path exceptions have now been statically reviewed, including delegated helper authorization where applicable.
- No immediate missing authentication/organization authorization issue was established in these four inspected paths.
- Two wrappers use `pg_catalog, public`; two preference/consent functions use `pg_catalog, public, auth`. Explicit search_path is not equivalent to empty search_path. Fully qualified references and consistency hardening remain appropriate.
- This does not close the full 55-function review: transitive helper behavior, trigger side effects, views, storage policies and negative runtime tests remain open.
- No function was changed, revoked, or invoked.

## Next fast-track actions
1. Trace triggers and side effects on capacity registration and partner capability submission.
2. Complete workflow/test-run and notification isolation before fixture execution.
3. Implement negative cross-tenant, wrong-role and invalid-evidence tests.
4. Review remaining SECURITY DEFINER helper dependencies and public view/RPC exposure.
5. Re-run advisors and targeted grants after any approved fix.

## Safety record
No SQL mutations, function calls, fixture provisioning, event insertion, queue claims, notification/email/provider/payment calls or Production access occurred.
