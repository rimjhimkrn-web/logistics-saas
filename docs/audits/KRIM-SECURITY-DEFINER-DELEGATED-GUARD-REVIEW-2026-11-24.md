# KRIM authenticated SECURITY DEFINER delegated-guard review

**Date:** 2026-11-24  
**Scope:** Live production catalog and function source, read-only.  
**No production function, grant, policy, or schema was changed.

## Catalog counts

Among 151 public-schema SECURITY DEFINER functions executable by `authenticated`:

| Source marker | Count |
|---|---:|
| Total | 151 |
| Direct `auth.uid()` marker | 141 |
| No direct `auth.uid()` marker | 10 |
| Permission/role guard marker | 103 |
| Tenant/organization marker | 123 |
| MFA/JWT marker | 56 |
| Mutating SQL body marker | 102 |
| Dynamic SQL marker | 0 |

These are source-text screening counts, not proof of security or insecurity. In particular, absence of a direct `auth.uid()` marker is not automatically a vulnerability where a function delegates to a guarded function.

## Review of all 10 functions without a direct auth.uid() marker

### Delegated partner capacity/capability functions

- `krim_admin_list_capacity_resources_lane_aware()` calls `public.krim_admin_list_capacity_resources()` before enriching the result. The base function was previously inspected and requires authenticated AAL2 plus platform-admin permission.
- `krim_partner_register_capacity_resource_for_lane(...)` delegates registration to `public.krim_partner_register_capacity_resource(...)`, then binds the new availability record to the selected lane and organization. The delegated base function must remain the authorization boundary; re-review it if its implementation changes.
- `krim_partner_submit_service_capability_v2(...)` delegates to `public.krim_partner_submit_service_capability(...)` and then updates the newly created capability record. The delegated base function must remain the authorization boundary; re-review it if its implementation changes.

### Vehicle administration functions

The following functions initialize the acting user through `public.krim_vehicle_admin_guard()` before returning data or mutating records:

- `krim_vehicle_admin_vehicle_list()`
- `krim_vehicle_finalize_verification(uuid)`
- `krim_vehicle_refresh_expiry()`
- `krim_vehicle_requirement_list()`
- `krim_vehicle_review_document(uuid,text,text)`
- `krim_vehicle_review_queue()`
- `krim_vehicle_set_document_requirement(text,text,text,boolean)`

The guard was inspected and requires an authenticated AAL2 session and `admin.platform` permission. Mutation functions also apply reviewer separation-of-duty checks and write audit events where appropriate.

## Decision

No direct authorization defect was identified in these 10 functions during this focused source review. The three delegated functions depend on the security of their base functions; this report does not treat wrapper checks as independent authorization.

The remaining 141 functions still require review of tenant scoping, delegated authorization, input validation, and object-level access. The counts above do not certify the entire 151-function set.

## Next review batch

Continue by reviewing the mutating functions with the weakest source markers and their complete call graph. Confirm tenant ownership checks at the data access boundary, not merely the presence of an organization identifier. Do not bulk revoke execute privileges or alter function definitions based on regex screening alone.

## Additional direct-identity functions reviewed
A second pass examined selected SECURITY DEFINER functions that contain `auth.uid()` but do not contain the literal `krim_has_permission` marker. Absence of that helper marker was not treated as a finding by itself; the functions were checked for object ownership, membership and facility scope.

- `krim_accept_driver_invitation(text)`: requires a 64-character token, authenticated and email-confirmed user, SHA-256 token match, exact invited email, unexpired/unrevoked/unaccepted invitation, and currently eligible partner organization. Creates/updates only the authenticated user's driver profile/membership and marks invitation accepted. Driver verification remains pending.
- `krim_vehicle_register(...)`: requires active owner/manager membership in the exact organization; legacy fleet ID must belong to that organization. Vehicle is created pending verification.
- `krim_warehouse_dispatch_transfer(...)`: requires operator authorization at both exact facilities in the same organization, locks source inventory, requires released quality state and sufficient stock, checks both facilities active/approved, enforces idempotency payload equality, and records movements/audit.
- `krim_warehouse_receive_transfer(...)`: derives organization/destination from locked transfer row, requires destination-facility operator, only receives dispatched transfer, requires a different user from dispatcher, enforces idempotency and blocks merging into inventory whose quality status is not hold. Received stock remains on hold.
- `krim_warehouse_review_inventory_quality(...)`: requires operator access to task facility, completed eligible task, different user from task creator/completer, independent private inspection evidence uploaded by another user, exact SKU/lot/facility match, and validates every contributing receipt before changing quality state.
- `krim_set_partner_account_mode(...)`: derives the single active partner organization from the caller's own active membership; rejects zero/multiple orgs and prevents approved/active partner organizations switching to non-commercial modes.
- `krim_provision_customer_organization(text)` and `krim_provision_partner_organization(text)`: derive actor from `auth.uid()`, serialize repeat provisioning with per-user advisory locks, reuse only the caller's existing eligible membership, and create owner membership/role/audit rows for the new organization. Partner provisioning starts in verification/compliance pending state.

No direct cross-tenant defect was identified in these reviewed bodies. This remains a source-level review, not a two-user runtime test. The 151-function inventory is not fully reviewed; 141 direct-`auth.uid()` functions remain subject to the broader review plan.
