# KRIM Customer Registration, Organisation Provisioning & Workspace Activation Audit
**Date:** 16 November 2026  
**Scope:** Read-only review of public customer registration pages, Supabase Auth callback, customer organisation provisioning RPC, customer registration/activation RPCs, customer workspace access checks, production Auth and organisation counts, RLS policies and function grants.

## Executive decision
**Customer authentication and basic organisation provisioning exist, but KRIM's canonical customer activation lifecycle is not connected end-to-end.** The active signup path creates an Auth identity, provisions an active customer organisation and owner membership after email confirmation, then routes the user to MFA setup. However, this path does not create the canonical customer account, workspace profile, identity-link, consent-ledger, onboarding or activation-check records.

A separate, more complete customer registration/activation model exists in database functions, but the registration and activation RPCs are not executable by the authenticated role and are not called by the current signup/callback flow. The customer workspace displays MFA assurance but does not require AAL2 before rendering the authenticated workspace.

**Do not mark customer registration or workspace activation production-ready.**

No signup was submitted, no email sent, no customer or organisation created, no role or membership changed, and no production database mutation was performed.

## 1. Production snapshot

| Component | Current rows |
|---|---:|
| Supabase Auth users | 9 |
| Email-confirmed Auth users | 9 |
| KRIM organisations (all types) | 14 |
| KRIM organisation memberships | 13 |
| Customer-type organisations | 5 |
| Enterprise-type organisations | 1 |
| Customer profiles in legacy `customer_profiles` | 6 |
| Canonical customer accounts | 0 |
| Canonical customer workspace profiles | 0 |
| Canonical customer identity links | 0 |
| Customer consent ledger rows | 0 |
| Customer activation checks | 0 |
| Organisation onboarding rows | 0 |
| Organisation invitations | 0 |

All 13 current organisation membership rows are active. The six legacy `customer_profiles` rows are not evidence of six activated canonical customer accounts. The 5 customer organisations and one enterprise organisation each currently have one active membership, but no canonical customer account or workspace profile is linked in the inspected tables.

Counts are a point-in-time production snapshot and do not identify individual users or establish whether every row is a real customer versus a prior test/operational record.

## 2. Two different customer signup routes exist

### Route A — `auth/signup.html` (customer-specific route)
- Requires organisation/business name, full name, email, password (12+ characters), password confirmation and Terms/Privacy checkbox.
- Calls Supabase `auth.signUp` with client-supplied user metadata including full name, company name, account type `customer`, and terms version.
- If email confirmation is required and no session is returned, it tells the user to verify their email and continue through the callback.
- If a session is returned immediately, it calls `krim_provision_customer_organization` and then routes to MFA enrollment.

### Route B — `app/register.html` (generic account route)
- Requires email, password (8+ characters) and Terms/Privacy checkbox.
- Calls `window.KRIM.auth.signUp`.
- The shared auth flow creates only the Supabase Auth identity and explicitly tells the user that workspace access still requires an authorised organisation membership.
- It does not collect an organisation name or call customer provisioning.
- This can leave a valid Auth account with no workspace membership until another authorised onboarding route is completed.

**Finding P0-A — Competing registration experiences.** The two public registration pages create materially different outcomes and password requirements. One is customer-specific and provisions an organisation; the other creates only an identity. This can produce confusion, orphaned Auth accounts and support burden. Choose one canonical entry point and route role-specific onboarding from it.

## 3. Email callback provisions an active organisation before MFA is completed

The `auth/auth-callback.html` callback:
1. Exchanges the email confirmation code or loads the session.
2. Reads account type and company name from Auth user metadata.
3. For customer accounts, calls `krim_provision_customer_organization`.
4. Only after provisioning does it check verified TOTP factors and route the user to MFA enrollment/challenge.
5. Then redirects to the customer workspace.

The provisioning function is `SECURITY DEFINER`, requires `auth.uid()`, validates organisation name, takes an advisory lock, reuses an existing active customer/enterprise organisation membership when present, or creates a new customer organisation. It then creates an active owner membership and an active `organization_owner` role assignment, plus an audit event.

It is granted to `authenticated`, `postgres` and `service_role`.

**Finding P0-B — Workspace authority becomes active before MFA.** The callback creates active organisation membership and role assignment before MFA enrollment/challenge is completed. The customer dashboard checks membership, then calls `getAuthenticatorAssuranceLevel()` only to display a security indicator; it does not stop access when current assurance is AAL1. The organisation RLS policy also permits active members to read their organisation without requiring AAL2.

**Impact:** the page flow promises authenticator setup before workspace access, but the database membership and workspace data access are already available before AAL2. A client-side redirect is not a security boundary.

**Required correction:** do not grant operational membership/permissions until MFA requirements are met, or enforce AAL2 server-side on every sensitive customer RPC/RLS path. Separate a pending registration/identity state from active operational membership. Test direct Data API calls at AAL1, not just page navigation.

**Finding P0-C — Provisioning RPC does not independently require verified email.** The callback normally runs after email confirmation, but `krim_provision_customer_organization` itself checks only that `auth.uid()` exists and that the organisation name is valid. Because authenticated clients have EXECUTE permission, the database function does not independently enforce `auth.users.email_confirmed_at IS NOT NULL`. The security guarantee currently relies on the frontend callback sequence.

**Required correction:** enforce verified email inside the privileged function (and any other required account assurance conditions), rather than relying on the browser to call it only after confirmation.

## 4. Current provisioning is not the canonical customer-account lifecycle

The current callback RPC `krim_provision_customer_organization` creates:
- `krim_organizations` customer row (status active).
- `krim_organization_members` owner row (status active).
- `krim_user_role_assignments` organisation_owner role (active).
- `krim_audit_events` provisioning event.

It does **not** create:
- `krim_customer_acquisition_profiles` canonical customer profile.
- `krim_customer_workspace_profiles` workspace profile.
- `krim_customer_identity_links` verified identity-to-profile binding.
- `krim_customer_accounts` customer account number/status.
- `krim_customer_consents` structured Terms/Privacy/data-processing consent rows.
- `krim_customer_activation_checks` activation evidence.
- `krim_organization_onboarding` organisation onboarding state.

The production counts for all seven omitted canonical record families are zero.

**Finding P0-D — Active organisation without canonical customer account.** The current signup path can result in an active customer organisation and owner membership while the customer account, customer workspace profile and activation evidence remain absent. This splits the customer identity and organisation model across two systems.

**Impact:** downstream customer services, billing, customer analytics, consent validation, onboarding progress and support may depend on records that the active signup path never creates. Organisation membership alone must not be interpreted as a fully onboarded/verified customer account.

## 5. A second registration/activation architecture exists but is disconnected

### `krim_register_customer_account`
This SECURITY DEFINER function:
- Requires `auth.uid()` and a valid Auth email.
- Creates an acquisition profile.
- Creates a customer organisation.
- Links the profile and organisation.
- Creates a pending workspace profile and pending customer identity link.
- Creates an inactive organisation membership and inactive `customer_user` role assignment.
- Writes a registration audit event.

But production function grants show EXECUTE only for `postgres` and `service_role`; there is no `authenticated` EXECUTE grant. The current customer signup and callback do not call this function.

### `krim_request_customer_activation`
This SECURITY DEFINER function:
- Requires an authenticated user.
- Finds the user's pending/verified customer identity link.
- Requires email confirmation.
- Requires three granted consent types: `terms`, `privacy`, `data_processing`.
- Calls the internal customer workspace activation function.
- Writes an activation audit event.

Its EXECUTE grant is also only `postgres` and `service_role`; no `authenticated` grant exists. It is not called by the current signup/callback.

### `krim_internal_activate_customer_workspace`
This function checks the customer profile, organisation and workspace profile; verifies email; verifies identity linkage; verifies the three required consent rows; then activates identity, membership, role assignment, workspace profile and acquisition profile.

The function is a stronger model than the simple callback provisioning path, but its prerequisites are not created by the current signup path and the public activation entry point is not exposed to authenticated customers.

**Finding P0-E — Canonical activation functions are not reachable through the customer journey.** The complete activation workflow is present in the database but disconnected from the actual registration experience. Do not grant EXECUTE to authenticated blindly: first reconcile the identity, MFA, consent, profile ownership and transaction boundaries.

## 6. Consent evidence is incomplete

Both signup pages collect a Terms/Privacy checkbox. The customer-specific route puts terms acceptance and version into user-editable Auth metadata. The generic route passes a terms flag and version into the shared signUp helper, which stores them in user metadata.

Neither flow writes the three canonical consent ledger rows required by `krim_request_customer_activation`. The production consent ledger is empty.

**Finding P1-A — A checkbox and user metadata are not the canonical consent ledger.** Store exact notice/version, purpose, timestamp, source, authenticated actor and withdrawal history in the consent model. Distinguish contractual acceptance from optional marketing consent. Do not make optional marketing consent a condition of service access.

## 7. Workspace access and tenant isolation

Positive controls:
- `krim_organizations` SELECT is scoped to active organisation members or AAL2 platform administrators.
- `krim_organization_members` SELECT returns the current user's own membership rows.
- Customer account and activation-check SELECT policies use organisation membership checks.
- Customer identity, workspace profile, consent and acquisition profile policies are organisation-scoped.
- The customer dashboard obtains the signed-in session and queries only active memberships for the current user; it then maps the organisation type to a workspace role.
- It obtains customer shipment and quote counts scoped to the member's customer organisation IDs.

Important limitations:
- The customer dashboard does not reject AAL1; it only displays the current assurance level.
- The customer workspace profile, identity link, consent and acquisition profile policies are tied to organisation membership. Pending users cannot naturally inspect their own pending setup state unless a separate secure owner-bound read path is supplied.
- The current registration RPC makes membership active immediately, bypassing the intended pending-state experience.
- The workspace dashboard's visible navigation links are not access controls; each underlying service must continue enforcing RLS and RPC authorization.

## 8. Required staging acceptance tests
1. Canonical customer signup creates exactly one Auth identity and one pending customer registration case.
2. Email confirmation is required before any organisation membership or operational role is activated.
3. Duplicate callback/retry is idempotent: one customer profile, one organisation, one workspace profile, one identity link and one owner membership.
4. AAL1 user cannot access protected customer workspace data or sensitive operations; AAL2 can only after MFA policy is satisfied.
5. Direct RPC call to organisation provisioning by an unconfirmed user is rejected by the database.
6. User-editable Auth metadata cannot grant role, membership, verification or permissions.
7. Customer organisation creation validates organisation type, country/market/currency/timezone and prevents accidental duplicate organisation creation.
8. Canonical customer account and customer number are created once, with consistent organisation binding.
9. Customer identity link is unique per user/profile/organisation and cannot be reassigned by the client.
10. Three required legal/service consents are recorded with exact notice versions and timestamps; optional marketing consent remains optional.
11. Consent withdrawal is append-only and does not erase the historical evidence of prior acceptance.
12. Activation checks are generated from real requirements and cannot be marked complete by the customer without evidence/reviewer approval where required.
13. Customer workspace activation occurs only after all required server-side checks pass.
14. Organisation owner and customer_user permissions are intentionally defined and do not conflict.
15. Tenant A cannot read, update, invite, or infer Tenant B's members, profile, shipment, quote, consent or billing records.
16. A customer user cannot create arbitrary memberships or escalate their role.
17. An Auth account created through the generic signup path is either routed into the same canonical onboarding process or clearly remains an identity-only account.
18. Customer dashboard handles no membership, pending membership, multiple organisations, unsupported roles, expired sessions, MFA downgrade and backend errors without showing false access.
19. Customer conversion from an enquiry binds the lead to the authenticated user and organisation with immutable attribution; it does not create a second profile or duplicate organisation.
20. Customer account activation is not treated as partner verification, booking, shipment completion or KRIM revenue.

## 9. Safe implementation sequence
1. Preserve the production migration-history recovery blocker; do not apply DDL or grant changes.
2. Choose one canonical signup entry point and remove/redirect the competing identity-only route after link audit.
3. Design one idempotent registration transaction that creates pending identity/profile/organisation/workspace and exact consent evidence.
4. Require email verification and MFA policy server-side before activating operational membership/permissions.
5. Reconcile `krim_register_customer_account`, `krim_provision_customer_organization` and `krim_request_customer_activation` into one supported lifecycle. Remove dead/duplicate paths only through reviewed forward-only migrations.
6. Provide an owner-bound pending-onboarding read path without broadening RLS.
7. Add verified organisation/account status and audit event transitions.
8. Run the staging acceptance matrix with multiple users and two organisations, including AAL1/AAL2 direct API tests.
9. Release only after schema/migration recovery, security review and post-deploy verification.

## 10. Scope and limitations
Read-only inspection of production table counts, selected schema columns, RLS policies, table grants, RPC definitions and EXECUTE grants. Reviewed checked-in signup, generic registration, shared auth helper, email callback, customer workspace dashboard and onboarding redirect pages. No browser signup, real email verification, MFA enrollment, direct customer data API test, or staging seeded test was performed. No production DDL, DML, grants, role changes, notifications or emails were sent.

**Decision:** Auth identity creation and organisation provisioning are implemented. Canonical customer-account creation, consent capture, activation checks, MFA-before-access enforcement and the end-to-end customer workspace activation lifecycle are not yet production-ready.
