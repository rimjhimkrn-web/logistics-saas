# KRIM Authenticated Privileged Function Journey Review
**Captured:** 16 November 2026  
**Project:** Production Supabase `ebltviniygljwwseplph`  
**Scope:** Read-only source inspection of selected authenticated-callable SECURITY DEFINER functions. No functions were invoked and no production data or schema was changed.

## Summary
A focused review was performed across customer/partner/driver provisioning, shipment creation, quote acceptance and exact-leg dispatch authorization. The inspected functions generally show meaningful server-side controls for organization membership, permission checks, verified provider capability, capacity reservation and dispatch readiness. This is positive evidence, but not a complete security certification.

## Function findings

### 1. Customer organization provisioning
`public.krim_provision_customer_organization(text)`:
- Requires a non-null authenticated user (`auth.uid()`).
- Validates legal-name length.
- Uses a per-user transaction advisory lock.
- Reuses an existing active customer/enterprise membership before creating another organization.
- Assigns owner role and writes an audit event.

**Remaining control gap:** The function does not independently require a confirmed email or recent MFA/AAL2. Earlier customer registration review also found the signup callback provisions membership before MFA and the canonical consent ledger remains empty. Confirmed-email and consent enforcement should be addressed in the registration flow before production acquisition is treated as fully hardened.

### 2. Partner organization provisioning
`public.krim_provision_partner_organization(text)`:
- Requires authentication and validates the submitted legal name.
- Uses a per-user advisory lock.
- Prevents ambiguous multiple active partner organizations for the same user.
- Creates a pending verification/compliance organization, owner and partner roles, an open verification case, and an audit event.

**Positive:** Self-registration does not set the partner to verified. The new partner is explicitly pending and must not be included in operational matching until independently verified and approved.

**Remaining control gap:** Like customer provisioning, the function does not itself enforce confirmed email or AAL2. Review the full registration journey and role assignment policies before broad public onboarding.

### 3. Driver organization provisioning — metadata trust issue
`public.krim_provision_driver_organization()` reads `auth.users.raw_user_meta_data` and checks whether `krim_account_type = 'driver'` before provisioning a driver organization and active driver membership.

Supabase user metadata is user-editable and must not be used as an authorization source. The check is currently an account-type/onboarding selector rather than a verified driver credential, and the function does not itself mark a driver as verified. Nevertheless, it should be replaced with a server-controlled registration intent or trusted app metadata / canonical onboarding record, with an explicit server-side role and eligibility check. Driver membership must never imply verified driver status or dispatch eligibility.

**Priority:** High for hardening the driver onboarding path; do not treat this finding as proof that a user can pass driver verification or dispatch gates.

### 4. Shipment creation
`public.krim_create_global_shipment(...)` verifies:
- authenticated user;
- membership in the supplied customer organization;
- `shipment.create` permission;
- active origin/destination locations and countries;
- operational market activation at both ends;
- distinct origin and destination.

The `from_places` overloads delegate to the guarded base function before updating the newly created shipment with route/place metadata. The base function therefore supplies the organization authorization boundary for those overloads. The place-based function also validates location names, country codes, coordinates and supported route metadata.

**Positive:** Client-supplied organization IDs are checked against the authenticated user's organization membership and permission. Location selection alone does not make a route bookable; operational market gates remain enforced.

**Review note:** Continue auditing all overloads and callers as one function family. Avoid changing only one overload or assuming identical behavior across signatures.

### 5. Customer quote acceptance
`public.krim_accept_global_quote(bigint)`:
- Locks quote and shipment rows.
- Verifies the authenticated user's organization access and `shipment.update` permission.
- Enforces quote/shipment state and expiry checks.
- Requires an accepted partner quote and matching accepted assignment for the same shipment.
- Requires active partner organization status, verification/lifecycle/compliance state, a current verified capability and route/weight/mode coverage.
- Finalizes the assignment only after these checks.

**Positive:** A customer quote cannot by itself create a provider-backed booking or turn an unverified provider into an assigned carrier.

### 6. Exact-leg dispatch authorization
`public.krim_authorize_leg_dispatch(bigint,text)`:
- Requires authentication, a valid assignment and bounded non-empty idempotency key.
- Requires accepted/active assignment bound to an exact leg.
- Checks `shipment.dispatch` permission for the assigned partner organization.
- Enforces current idempotency-key binding and rejects reuse for another leg or revoked authorization.
- Requires the exact leg to be assigned, a confirmed physical capacity binding and matching partner-owned capacity reservation.
- For road, requires an accepted assigned driver, active driver membership, verified driver/current licence, accepted licence documents, active verified vehicle and required current vehicle documents.
- For later legs, requires accepted custody transfer from the immediately preceding leg.
- Writes an authorization and a separate execution event; it explicitly does not record physical departure.

**Positive:** Authorization is not represented as proof that the truck departed. Physical departure and tracking remain separate events.

## Shared authorization helper
The inspected `private.krim_has_organization_access` and `private.krim_has_permission` helpers bind the supplied user ID to `auth.uid()` whenever a JWT user context exists, and verify active membership / active role-permission assignment for the target organization. This reduces the risk of a caller passing another user's UUID to those helper checks.

## Required next actions
1. Replace the driver provisioning dependency on user-editable `raw_user_meta_data` with a trusted server-side onboarding intent and explicit role eligibility.
2. Add/verify confirmed-email and appropriate assurance checks at the customer/partner/driver onboarding boundary, without relying on user metadata.
3. Audit the complete signup callback, invite acceptance and role-assignment flows for membership creation before email confirmation/MFA.
4. Continue source review of all authenticated-callable SECURITY DEFINER functions, especially partner quote submission/award, capacity, driver assignment, warehouse evidence and finance.
5. Add automated negative tests for cross-organization IDs, forged account metadata, unverified drivers, unverified partners, expired capability, wrong-leg assignments, replayed idempotency keys and missing custody.
6. Do not make production DDL or function replacements until the encrypted schema export has been recovered and migration history reconciled.

## Limits
This is source inspection of selected live function definitions and helper functions, not execution testing, full overload/call-graph analysis, tenant penetration testing or independent security certification. No production changes were made.
