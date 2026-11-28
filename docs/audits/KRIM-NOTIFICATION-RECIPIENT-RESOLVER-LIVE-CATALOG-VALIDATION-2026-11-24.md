# Recipient resolver live-catalog validation — 2026-11-24

**Scope:** read-only comparison of the PR #245 proposed identity resolver against the current production catalog.  
**Production impact:** none. No DDL, DML, migration replay, fixtures, or message delivery.

## Confirmed schema compatibility

The following references used by the resolver exist with compatible types:
- `krim_shipments.id` and `customer_organization_id`: bigint.
- `krim_shipment_partner_assignments.shipment_id` and `partner_organization_id`: bigint.
- `krim_customer_identity_links.customer_profile_id` and `organization_id`: bigint; `user_id`: uuid; `verified_at`: nullable timestamptz.
- `krim_customer_acquisition_profiles.id` and `organization_id`: bigint; `status`: text.
- `krim_customer_workspace_profiles.customer_profile_id` and `organization_id`: bigint; workspace/account status: text.
- `krim_organization_members.organization_id`: bigint; `user_id`: uuid; `role` and `status`: text.
- `krim_organizations.id`: bigint; `timezone`: nullable text.

## Constraint values confirmed

- Organization status: active, inactive, suspended.
- Organization types: customer, partner, enterprise, carrier, warehouse, forwarder, platform, customs, finance, operations.
- Partner lifecycle: not_applicable, registered, verification_pending, under_review, approved, active, restricted, suspended, closed.
- Partner verification: not_started, pending, in_review, verified, rejected, expired.
- Partner compliance: not_started, pending, in_review, compliant, restricted, non_compliant, expired.
- Customer acquisition status: discovered, engaged, registered, active, inactive, suppressed.
- Customer identity status: pending, verified, suspended, revoked.
- Customer workspace status: pending, provisioning, active, restricted, closed.
- Customer account status: pending, email_unverified, active, suspended, closed.
- Membership roles: owner, admin, operator, dispatcher, finance, manager, member, driver.
- Membership status: active, inactive, suspended.
- Partner assignment status: offered, accepted, rejected, cancelled, active, completed, failed.

The resolver's selected enum/check values are valid against these live constraints. Partner assignment resolution intentionally includes offered/accepted/active and excludes rejected/cancelled/completed/failed. Customer profile status is explicitly required to be active. Customer workspace and account must both be active. Driver members are excluded from both customer and partner recipients.

## Schema privilege check

The `krim_internal` schema currently grants USAGE to service_role and not to anon/authenticated. The proposed resolver grants EXECUTE only to service_role and revokes public/anon/authenticated. This is consistent with the intended service-only boundary, subject to verifying function owner and exact ACL in the disposable migration test.

## Remaining validation limits

This is catalog compatibility, not executable SQL validation. No free disposable PostgreSQL/Supabase environment is currently available in the connected project without creating a paid branch. Production has no eligible recipient fixtures for this resolver. Therefore:
- PL/pgSQL compilation and runtime behavior remain untested.
- Query-plan and duplicate-row behavior remain untested with realistic multi-member fixtures.
- SECURITY DEFINER owner/ACL behavior must be verified after applying to a disposable database.
- The function must not be promoted into executable migrations or applied to production yet.

## Next safe step

Obtain a zero-cost isolated PostgreSQL test runtime (for example, local PostgreSQL/Supabase CLI if available), load a reconciled schema snapshot, then test the resolver using synthetic customer/partner identities. If no isolated runtime is available, retain this as a reviewed proposal and do not claim runtime validation.
