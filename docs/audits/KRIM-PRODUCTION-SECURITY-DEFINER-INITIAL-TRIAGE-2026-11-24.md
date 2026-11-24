# KRIM production SECURITY DEFINER initial triage — 2026-11-24

## Scope

Read-only inspection of public-schema SECURITY DEFINER functions in production. No grants, functions, policies, tables or auth settings were changed.

## Aggregate inventory

- Public SECURITY DEFINER functions: 333.
- Executable by authenticated: 151.
- Executable by anon: 0.
- Missing function search_path configuration: 0.
- Explicit empty search_path configuration: 188.
- Public tables without RLS: 0.
- Authenticated-callable SECURITY DEFINER functions using `auth.uid()` in source: 141.
- Using `krim_has_permission`: 103.
- Using `krim_has_organization_access` or `krim_warehouse_is_operator`: 31.
- Using `auth.jwt()`: 56.
- Ten authenticated-callable functions do not contain the common authorization markers directly in their own source.

These marker counts overlap. They are triage indicators, not proof of authorization correctness or exploitability.

## Review of the ten marker-free functions

The initial source excerpts indicate wrapper/delegation patterns rather than immediate evidence of anonymous access:
- `krim_admin_list_capacity_resources_lane_aware` delegates to `krim_admin_list_capacity_resources`.
- `krim_partner_register_capacity_resource_for_lane` delegates to `krim_partner_register_capacity_resource`.
- `krim_partner_submit_service_capability_v2` delegates to `krim_partner_submit_service_capability`.
- Vehicle verification functions call `krim_vehicle_admin_guard()` and then enforce independent-review/evidence rules.

This is not sufficient to close the review. Each delegated target and guard must be inspected recursively, and execution grants of all callees must be checked. A wrapper must not be considered safe solely because it delegates.

## High-risk review rules

1. Verify every authenticated-callable function has an explicit caller identity and organization/role authorization path, either directly or through a reviewed guard/delegated function.
2. Verify tenant ownership is derived from trusted database state and not accepted solely from caller-supplied organization IDs.
3. Verify platform-admin functions require the correct permission and AAL2 where policy requires it.
4. Verify self-approval restrictions for partner, driver, vehicle, warehouse quality and finance approval workflows.
5. Inspect every dynamic SQL statement and every SECURITY DEFINER function with empty `search_path`; require schema-qualified object references. Empty search_path is not itself a vulnerability and must not be replaced with `public`.
6. Review default EXECUTE privileges and explicit grants for anon/authenticated/service_role. No anonymous execution was found in the aggregate ACL check.
7. Review 29 RLS-enabled tables without policies individually. These currently fail closed for ordinary table access; do not create broad policies to silence the advisor.
8. Configure leaked-password protection through the supported Auth configuration after verifying the exact production setting and rollout impact.

## Status

Initial triage only. The 151 authenticated-callable functions have not all received a full authorization/tenant-isolation review. No bulk revocation or blanket policy change is appropriate.

The notification subsystem remains a separate release blocker: its general dispatch functions are service-role-only, currently have no database-function callers, and the UI remains explicitly disconnected.
