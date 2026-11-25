# Phase 00 — Auth, organization provisioning and booking RPC security review
Date: 2026-11-25
Branch: qa/phase-00-baseline-2026-11-25
Scope: Read-only Production PostgreSQL catalog and deployed function source review. Prioritized authenticated SECURITY DEFINER functions in account provisioning, organization authorization, partner onboarding/capability, customer shipment creation and partner quote submission. No RPC invocation, no synthetic users, no DB writes, no grants/configuration changes.

## Executive verdict
The reviewed core customer/partner booking and quote functions generally enforce `auth.uid()`, organization membership and permission checks, and the partner quote path requires verified registered-business status plus a currently active verified capability. Partner capability evidence is tied to the caller's storage ownership and organization folder. These are positive source-level controls, not runtime proof.

One concrete hardening issue was found: driver organization provisioning uses `auth.users.raw_user_meta_data.krim_account_type` as its eligibility check. Supabase user metadata is user-editable and must not be treated as a trusted authorization claim. In this function it only gates self-provisioning of a driver-individual organization; it does not directly grant dispatch, shipment, or admin permissions. Still, the gate should be based on a trusted server-controlled account classification or an explicit onboarding state, not raw user metadata.

Other important release gates remain: Staging lacks the relevant authenticated grants/data for a signed-in end-to-end test, and source inspection cannot prove RLS, tenant isolation, storage policy, concurrency, or browser-to-RPC behavior at runtime.

## 1. Authorization helper functions
Reviewed private helpers:
- `private.krim_has_organization_access(uuid,bigint)`: requires the supplied user ID to equal `auth.uid()` whenever a JWT user exists, and requires an active membership in an active organization.
- `private.krim_has_permission(uuid,bigint,text)`: same caller identity guard, then requires an active role assignment, granted role-permission mapping, active membership and active organization.
- Both are SECURITY DEFINER with explicit `search_path=public, pg_catalog`.

The `auth.uid() IS NULL OR auth.uid()=p_user_id` expression is safe only when callers themselves reject unauthenticated requests before relying on the helper. The reviewed public provisioning/booking functions do explicit `auth.uid()` checks, and the helper functions themselves are not exposed as anonymous callable RPCs in the reviewed catalog. Continue to preserve that invariant.

## 2. Customer organization provisioning
`krim_provision_customer_organization(text)`:
- Requires authenticated caller and validates organization name length.
- Serializes provisioning per user with an advisory transaction lock.
- Reuses an existing active customer/enterprise membership rather than creating another organization.
- Otherwise creates a customer organization, owner membership and owner role assignment bound to the caller.
- Writes an audit event.

Source review did not find a caller-supplied user ID or arbitrary target organization assignment path. This is a self-service organization creation flow, not independent verification of the legal entity. Customer organization creation must not be confused with KYC/credit/commercial approval.

## 3. Partner organization provisioning
`krim_provision_partner_organization(text)`:
- Requires authentication and validates legal-name length.
- Serializes per-user provisioning.
- Rejects ambiguous multiple active partner organizations and reuses a single existing membership.
- Creates a partner organization in pending verification/compliance lifecycle, creates owner membership and owner/partner role assignments, opens a verification case and records an audit event.

Positive: organization is created pending, not verified or commercially active. Quote submission separately checks verified/approved partner status, active lifecycle, compliant status, active registered-business mode and an active verified capability. This is the correct separation between registration and marketplace eligibility in the inspected paths.

Residual: confirm all other partner workspace write RPCs enforce the same verification/compliance gates where the operation requires them; role assignment alone must not be interpreted as verified operational authority.

## 4. Driver organization provisioning — hardening required
`krim_provision_driver_organization()`:
- Requires authenticated caller.
- Reads `auth.users.raw_user_meta_data` and checks `krim_account_type='driver'`.
- Serializes per-user provisioning.
- Rejects multiple active driver organizations, reuses a single one, or creates a driver-individual carrier organization and active driver membership.

Finding: `raw_user_meta_data` is user-editable and is not a trusted authorization source. This is not an observed privilege escalation into a partner/admin role, but it is an unreliable gate for creating a driver organization. Replace the decision source with server-controlled `app_metadata` or a database-owned onboarding/account-type record written only by a trusted flow. If user metadata is retained for display, do not use it as the security predicate. Keep downstream driver verification, assignment ownership, active membership, dispatch and POD checks mandatory.

## 5. Customer shipment creation
Reviewed:
- `krim_create_global_shipment`
- `krim_create_global_shipment_from_places` (5-, 6- and 7-argument overloads)
- `krim_create_global_shipment_idempotent`

Positive source controls:
- Explicit authenticated caller checks in the public wrappers.
- Customer organization membership and `shipment.create` permission checks in the core creation function.
- Active organization, location/country and market-operational readiness checks.
- Goods description and positive weight bounds.
- Place labels/country codes and coordinate range checks.
- Domestic/cross-border route-type consistency in the 7-argument overload.
- Idempotent wrapper locks on organization + booking request ID, returns the original shipment for matching details and rejects reuse with changed details.

Review note:
- The place resolver can create missing active `customer_requested` location catalogue rows from caller-provided place labels and coordinates. This is authenticated and organization-authorized, but it creates shared catalogue data. Before broad customer acquisition, add/confirm provenance, duplicate normalization, abuse throttling and moderation/retirement for untrusted customer-requested locations. Do not present these generated locations as independently verified service locations.
- The 7-argument route-type overload delegates to the 6-argument transport-mode overload, which validates the supported mode list. Preserve that call chain; avoid bypassing the validating overload in future changes.
- Booking source guards still block the current UI submission in the reviewed release branch; this audit did not enable it or test a booking.

## 6. Partner onboarding and capability submission
Reviewed:
- `krim_submit_partner_onboarding_global_v2`
- `krim_submit_partner_onboarding_global_multi_v1`
- `krim_partner_submit_service_capability`
- `krim_partner_submit_service_capability_v2`

Positive source controls:
- Authentication required.
- Onboarding validates country codes, authority ID, legal name, address and field lengths.
- Required document path is scoped to organization ID + caller UUID and accepted file extensions; document object must exist in the private verification bucket.
- Requires active membership in the matching partner-type organization and registered-business mode.
- Submissions set verification/compliance to pending and create/update verification cases plus audit events.
- Capability submission requires `partner.manage`, active registered-business organization, current partner compliance, active transport mode/country, bounded weight/region and one to five evidence paths.
- Each capability evidence path must be in the caller's organization/caller-specific folder and the Storage object must be owned by the caller.
- New capabilities are inserted inactive and pending verification; V2 details are size/length bounded.

Residual:
- Source checks that the document object exists and belongs to the expected path; it does not independently prove the document contents are authentic or current. That must remain a human/independent verification step.
- Full storage bucket policy, MIME/size enforcement and tenant-isolation tests remain separate required checks.
- The V2 wrapper delegates to the base capability function and then updates the new row; runtime transaction and concurrent duplicate behavior were not exercised.

## 7. Partner quote submission
`krim_submit_partner_quote(bigint,numeric,text,timestamptz,text)`:
- Requires authenticated caller and validates opportunity ID, positive bounded amount, 3-letter currency and notes length.
- Resolves exactly one eligible active partner organization from the caller's memberships.
- Requires registered-business mode, verified active capability, verified/approved organization status, active/verified lifecycle and compliant status.
- Requires `quote.create` permission.
- Requires active configured currency, locks open opportunity, rejects awarded/expired opportunities, checks capability covers shipment route/mode/weight and prevents a customer organization bidding on its own shipment.
- Clamps quote validity to response deadline, upserts a partner's existing active quote, and writes an audit event.

This is a strong source-level eligibility boundary. It has not been runtime tested, and prior Staging ACL review found authenticated EXECUTE absent for this RPC in Staging.

## 8. Function catalog / execution boundary
Production catalog snapshot:
- 151 authenticated-executable SECURITY DEFINER functions in public schema.
- All 151 had explicit function-level search_path configuration.
- Seven function configurations included `pg_temp`; each must be checked for safe ordering and object qualification during the wider review.
- The selected provisioning, booking and quote RPCs are authenticated-executable; selected helpers are in private schema and not presented as anonymous public APIs.
- This report does not claim the remaining 140 functions are safe. It is a focused first tranche.

## 9. Remediation and verification gates
1. Replace driver account eligibility check against `raw_user_meta_data.krim_account_type` with trusted server-controlled account type/onboarding state; retain authentication and downstream driver checks.
2. Add/confirm provenance and moderation for `customer_requested` location catalogue rows; prevent duplicate or malicious catalogue pollution.
3. Keep partner registration pending until independent evidence review and capability approval; never equate owner/partner role assignment with verification.
4. Confirm Storage policies enforce private bucket access and same organization/user path ownership on upload, read and delete.
5. Restore only the necessary least-privilege Staging grants after isolated test identities and test-sink protections are established; do not copy all Production grants.
6. Perform positive and negative JWT tests for customer A/customer B, partner A/partner B, driver A/driver B, unverified partner, verified partner without capability, expired capability, inactive membership, AAL1/AAL2 admin and anonymous caller.
7. Exercise booking idempotency under concurrent duplicate requests in isolated Staging; verify no duplicate shipment and no location catalogue abuse.
8. Continue the remaining authenticated SECURITY DEFINER review in risk-prioritized batches: admin review/approval, payments/refunds, warehouse/customs, driver/dispatch/POD, finance, notification and support operations.

## Evidence boundary
Only read-only SQL catalog/source inspection was performed. No RPC was called, no auth users were created, no test data was inserted, no Storage file was uploaded, no grants or policies were changed, and no Production or Staging configuration was modified. Findings are source-observed, not runtime proof.

## Verdict
- Customer organization provisioning: **SOURCE REVIEW PASS; legal/business verification remains separate**.
- Partner organization provisioning: **SOURCE REVIEW PASS; pending-state separation observed**.
- Driver organization provisioning: **HARDENING REQUIRED — user-editable metadata used as eligibility gate**.
- Customer shipment creation: **SOURCE REVIEW PASS WITH SHARED LOCATION-CATALOGUE ABUSE REVIEW REQUIRED**.
- Partner onboarding/capability: **SOURCE REVIEW PASS; evidence authenticity and storage isolation not runtime verified**.
- Partner quote submission: **SOURCE REVIEW PASS; Staging grant and runtime tests remain blockers**.
- Overall onboarding: **NOT VERIFIED; no real user onboarding approval**.
