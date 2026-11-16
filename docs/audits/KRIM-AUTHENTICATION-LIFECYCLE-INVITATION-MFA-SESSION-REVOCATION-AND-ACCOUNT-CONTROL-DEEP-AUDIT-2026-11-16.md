# KRIM Authentication Lifecycle, Invitation, MFA, Session Revocation and Account-Control Deep Audit — 2026-11-16

## Executive decision

**NO-GO for authentication lifecycle certification or unrestricted external onboarding.** Supabase Auth is operating and the canonical sign-in flow has email-confirmation, organization-membership routing and TOTP enrollment/challenge steps. The verified driver-invitation path is materially stronger than the generic organization-invitation path. However, session inventory/revocation is incomplete, account deactivation/deletion are request-only, generic organization invitations are not implemented, MFA enrollment has a destructive page-load side effect, and older React/legacy paths still use client-editable metadata for role/tenant decisions.

This was a read-only review of repository source, live Auth aggregate counts, database catalog/function definitions, grants and RLS policies. No password reset, login, MFA challenge/enrollment, invitation, user creation, session revocation, account action, RPC invocation, database mutation or email was performed.

## 1. Production snapshot

Read-only aggregate counts:
- Supabase Auth users: **9**
- Email-confirmed users: **9**
- Currently banned users: **0**
- Deleted users: **0**
- Auth session rows: **16**
- Session rows with AAL: **11 aal1**, **5 aal2**
- MFA factors: **4**, all **verified**
- KRIM session registry (`krim_auth_sessions`): **0**
- Device registry (`krim_user_devices`): **0**
- Generic organization invitations (`krim_organization_invitations`): **0**
- Private driver invitations: **0**
- Account action requests: **0**
- User consent events: **0**

These are point-in-time counts, not evidence of every session being currently active, every user having an MFA factor, or the full account lifecycle having been tested. The 16 Auth session rows include both AAL1 and AAL2 records. Do not interpret factor count or session AAL distribution as proof of policy enforcement across every backend operation.

## 2. Positive controls

### Canonical sign-in
- `auth/login.html` signs in through Supabase Auth.
- It reads the signed-in user's active organization memberships, resolves organization types, maps them to supported workspace roles, and rejects a requested workspace that is not represented by an active membership.
- It rejects platform-admin access through the ordinary user sign-in route.
- It requires a verified TOTP factor before normal workspace entry and challenges MFA when Supabase reports `nextLevel='aal2'`.
- It verifies the browser session belongs to the authenticated user before redirecting.
- Workspace selection is treated as a routing preference, not as permission creation.

### Email confirmation callback
- `auth/auth-callback.html` exchanges a PKCE code for a session (or reads the existing session).
- Newly confirmed driver users are sent through driver sign-in and membership checks rather than directly into the operational workspace.
- Customer/partner organization provisioning uses authenticated RPCs that bind the operation to `auth.uid()`.
- Partner account mode is separately written through a server function and remains non-commercial until verification.

### Password recovery
- Forgot-password uses Supabase `resetPasswordForEmail` with a KRIM callback.
- Reset-password exchanges the recovery code, verifies a recovery session, checks MFA requirements where Supabase reports AAL2 is needed, updates the password and attempts global sign-out.
- Recovery messaging is neutral and does not intentionally confirm whether an email exists.

### Driver invitation — strongest invitation path
- Driver invitation creation requires `partner.manage`, an active registered-business carrier, verified partner status, active lifecycle, compliant status and verified active transport capability.
- It rate-limits invitation creation to 10 per inviter/organization per hour.
- Tokens are 32 random bytes encoded as 64 lowercase hex characters; only SHA-256 token hashes are stored.
- Existing pending invitations for the same organization/email are revoked before a new invitation is inserted.
- Invitations expire after 7 days.
- Acceptance requires an authenticated user, confirmed email, exact email match, valid/unexpired/unrevoked/unused token and rechecked carrier eligibility.
- Acceptance locks the invitation row, creates or updates the driver's organization membership, keeps driver verification pending, records an audit event and marks the token accepted.
- Revocation and listing require `partner.manage`; listing is limited to 100 rows.
- The old one-argument driver-invitation function is not executable by anon or authenticated users; only the newer UUID invitation workflow is currently executable by authenticated users.

## 3. P0 — Client-controlled role and tenant metadata remain in a parallel React auth path

### Evidence
`src/lib/auth/auth-context.tsx` derives:
- role from `currentSession.user.user_metadata.role`;
- tenant ID from `currentSession.user.user_metadata.tenant_id`;
- MFA requirement from the metadata-derived role list plus the current AAL result.

Supabase user metadata is user-editable. This state is not a trusted role or tenant authority. The canonical HTML login path is more careful and resolves membership from the database, but the React AuthContext remains a separate path and can present incorrect role/tenant/MFA state to any consumer that trusts it.

### Required action
- Remove user_metadata-derived role/tenant authorization state from React.
- Resolve role, organization and permissions from canonical membership/RBAC endpoints.
- Use the server's AAL claim for sensitive operations; client role-based MFA flags are UX only.
- Keep authorization fail-closed when membership/role lookup fails.
- Add a repository-wide search and route inventory for all AuthContext consumers before retiring this path.

## 4. P1 — Session management page cannot enumerate or revoke real sessions

### Evidence
- `auth/active-sessions.html` reads `krim_auth_sessions`, which currently has **0 rows**, despite **16** rows in `auth.sessions`.
- No session registry population or synchronization path was found in the reviewed source/catalog.
- The page explicitly says it cannot reliably enumerate or revoke other sessions.
- Its action calls `supabase.auth.signOut({scope:'local'})`, which signs out only the current browser session.
- The React AuthContext `signOutAllDevices` calls global sign-out but ignores the returned `error` field before redirecting.
- `auth/logout.html` also calls global sign-out but does not inspect the returned `error`; it clears browser storage and redirects in a `finally` block even if the server-side revocation request returned an error object.

### Impact
The user-facing account-security area is not a real active-session manager. A user cannot currently inspect and selectively revoke other devices from this UI. The “sign out all” flows may clear the local browser and redirect even when Supabase reports that global revocation failed. Clearing local storage is not equivalent to server-side refresh-token/session revocation.

### Required action
- Build a server-authoritative session inventory keyed by Supabase `session_id` and reconcile it with Auth session state; do not invent client-side session records.
- Implement server-side global/selected-session revocation with explicit error handling and verified post-action status.
- Distinguish “this browser signed out” from “all sessions revoked”.
- For sensitive operations, consider validating session_id against `auth.sessions` where strict immediate revocation guarantees are required.
- Add tests for refresh-token revocation, old access-token expiry, session replay, membership revocation and global sign-out failure.

## 5. P1 — Generic organization invitation workflow is a placeholder

### Evidence
- `krim_organization_invitations` has an invitation schema and RLS SELECT limited to active organization access.
- The live table has **0** rows.
- No generic create, accept or revoke RPC was found in the reviewed callable function inventory.
- `auth/organization-invitation-acceptance.html` loads `krim-account-actions.js`, which explicitly says invitation acceptance requires a server-validated token.
- The page accepts a token as text, but submission throws “Invitation acceptance endpoint is not yet configured; token was not consumed.”
- The separate `auth/invitation.html` handles Supabase Auth invite/password setup; it does not implement organization membership invitation acceptance or role provisioning.

### Impact
A Supabase Auth invitation and a KRIM organization-membership invitation are different lifecycle steps. The current UX can be mistaken for a complete organization invitation flow even though it does not attach the invited user to an organization or role.

### Required action
Implement one canonical organization invite lifecycle:
1. Inviter must have organization.manage (or an explicit member-invite permission) in the exact organization.
2. Server-side role allowlist prevents self-assignment of owner/admin/platform/finance/compliance privileges.
3. Generate high-entropy one-time token; store only a cryptographic hash.
4. Bind exact email and organization; set expiry and revoke state.
5. Require confirmed matching email at acceptance.
6. Lock invitation and atomically create membership + role assignment + audit event.
7. Make retries idempotent and reject duplicate/replayed/expired/revoked invitations.
8. Support revocation and record all state transitions.
9. Deliver links only through a verified notification provider; do not expose raw tokens in logs.

## 6. P1 — Membership and role revocation are not fully audited or session-coordinated

### Evidence
- `krim_organization_members` has an AFTER INSERT audit trigger only.
- No UPDATE/DELETE trigger was found for membership changes.
- `krim_user_role_assignments` has no equivalent membership-lifecycle audit trigger in the reviewed trigger catalog.
- The membership/role tables are RLS-enabled and self-read only; client INSERT/UPDATE/DELETE policies were not present in the prior authorization catalog.
- The authorization helpers re-check active membership and active role assignment on backend calls, which is a positive protection against stale role claims.
- Auth session rows remain a separate Supabase Auth concern; no workflow was found that coordinates membership suspension/removal with session revocation.

### Impact
A role/membership change may correctly deny subsequent database operations if each backend operation rechecks current membership, but the change is not consistently captured as an auditable before/after transition. Existing browser sessions may remain authenticated after access is removed, creating stale UI and potential exposure through any path that fails to recheck membership.

### Required action
- Add a controlled membership/role state-transition service with before/after state, actor, subject, organization, reason, timestamp, request/session ID and audit event.
- Define whether membership suspension/revocation triggers targeted session revocation or global sign-out.
- Recheck current membership/permission on every protected RPC/Edge Function and sensitive storage operation.
- Test revoked membership with an unexpired JWT and an already-open browser tab.

## 7. P1 — Driver self-provisioning is selected by user-editable account metadata

### Evidence
- Public driver signup writes `krim_account_type='driver'` into user_metadata.
- Driver sign-in reads that metadata and, if no driver membership exists, calls `krim_provision_driver_organization()`.
- The SECURITY DEFINER function checks `auth.uid()` and then checks `auth.users.raw_user_meta_data.krim_account_type='driver'` before creating a driver-individual organization and active driver membership.
- User metadata is editable by the account holder; it is not a trusted role claim.
- This self-provisioned organization is an individual driver shell, not an accepted carrier invitation. It does not establish a verified carrier relationship, driver verification, or shipment assignment.
- The stronger carrier invitation path separately checks exact email, token and carrier eligibility.

### Impact
The driver path is intentionally self-service for individual-interest onboarding, but the server function treats a mutable metadata flag as the eligibility switch. This should be a product/onboarding state, not a trusted authorization attribute. The present flow does not prove commercial driver eligibility; it must never be interpreted as granting carrier membership or trip access.

### Required action
- Replace metadata-only eligibility with a server-side driver onboarding state/claim established through an explicit registration intent flow, with rate limits and abuse controls.
- Keep self-provisioned driver-individual accounts non-commercial and isolated from carrier work.
- Require the secure carrier invitation for joining a verified carrier organization.
- Ensure every driver assignment, milestone, evidence and dispatch action checks exact driver identity, active membership, verified profile and assignment state.

## 8. P1 — MFA enrollment deletes pending factors when the page is opened

### Evidence
`auth/mfa-enroll.html`:
- lists the current user's TOTP factors;
- blocks if a verified factor exists;
- automatically unenrolls every unverified factor before creating a new factor.

### Impact
Opening the enrollment page has a destructive side effect. A pending factor created by an interrupted enrollment or another browser/device is removed without an explicit user choice. This can interrupt a parallel setup attempt and is surprising for an account-security screen.

### Required action
- Do not delete pending factors automatically on page load.
- Show pending factors and provide an explicit “discard pending setup” action with confirmation, or resume a valid pending setup.
- Verify that only the factor created by the current enrollment flow is challenged and verified.
- Add multi-tab, interrupted enrollment, multiple pending factor and recovery tests.

## 9. P1 — Account deactivation and deletion are request-only, not executable lifecycle controls

### Evidence
- `krim_account_action_requests` has RLS enabled.
- Authenticated users may insert only their own requests with status pending and may read only their own requests.
- `auth/krim-account-actions.js` records account deactivation/deletion requests and explicitly states that this does not itself deactivate or delete the account.
- Live account action requests: **0**.
- No verified privileged processor, re-authenticated account deactivation, Auth user deletion, data-retention orchestration, organization ownership transfer, legal hold or deletion-completion evidence was found in the reviewed workflow.

### Impact
This is correctly presented as a request rather than a completed account action, but the page must not be represented as an operational self-service deactivation/deletion system. Account disablement, session revocation, organization transfer and data deletion are not proven.

### Required action
- Define separate suspend/deactivate/delete-request/approved/deleting/completed/rejected states.
- Require recent reauthentication and MFA for destructive actions.
- Transfer organization ownership or resolve sole-owner dependencies before deletion.
- Revoke sessions before deactivation/deletion and verify the effect.
- Implement retention, legal hold, financial records, audit preservation, storage object cleanup and Auth deletion as an orchestrated, retryable workflow.
- Keep the UI explicitly marked “request only” until the backend is complete.

## 10. P2 — Recovery and security notifications need end-to-end verification

- Password reset attempts global sign-out after updating the password, but a client-side timeout can leave the user uncertain whether the password update succeeded; the user is advised to attempt sign-in before retrying.
- Change-email reauthenticates with the current password but MFA/step-up enforcement is not visibly applied in the account action page.
- Change-phone calls Auth updateUser and relies on the configured provider verification; provider readiness has not been demonstrated.
- Account consent UI writes events directly with a client-provided policy version; a canonical policy catalogue, withdrawal/regrant semantics and retention/export lifecycle are not complete.
- Supabase supports security-sensitive Auth notification templates (password/email/phone/identity/MFA changes) as a platform feature; KRIM has not demonstrated configured delivery or end-to-end receipt. Enable and test these notifications after provider configuration.
- No backup-code generation/verification workflow is implemented in KRIM; the UI explicitly disables it. Confirm the current Supabase Auth recovery-code capability and project settings before deciding whether to integrate it or document an alternate recovery process.

## 11. Invitation and account lifecycle data model status

- Generic organization invitation table exists but no generic lifecycle endpoint is implemented.
- Private driver invitation table exists and is currently empty.
- Driver invitation create/accept/revoke/list functions are present; the secure token path is executable only for authenticated users and requires current authorization.
- A legacy one-argument driver invitation function remains in the database but is not executable by anon or authenticated roles. Retire it only after migration history reconciliation.
- Organization membership has insert audit only; update/revoke lifecycle is incomplete.
- User role assignment is separate from membership role and legacy `user_roles`; canonical authority/precedence is still not established.
- KRIM session registry and device registry exist but are empty and are not synchronized with Supabase Auth session rows.
- Account action requests exist but no completion processor is evidenced.

## 12. Required staging verification matrix — not run

1. Sign up with email confirmation enabled; replay callback code; expired/used callback code.
2. Duplicate signup, existing account, enumeration-resistant recovery response and rate-limit handling.
3. Attempt user_metadata role/tenant/account_type manipulation before and after signup.
4. Confirm customer/partner self-provisioning creates only the intended organization and no approval or commercial capability.
5. Driver self-registration versus secure carrier invitation; wrong email, unconfirmed email, expired, revoked, reused and concurrent acceptance token.
6. Driver carrier suspended/compliance-expired/capability-revoked between invite creation and acceptance.
7. Generic organization invite: role allowlist, inviter scope, token hashing, exact email, expiry, replay, revoke, idempotency and audit.
8. AAL1/AAL2 enforcement for every privileged operation, including direct RPC and Edge Function calls.
9. MFA enrollment with no factor, one verified factor, one pending factor, multiple pending factors, multiple tabs and interrupted enrollment.
10. MFA factor removal/replacement, lost authenticator, recovery code, password reset and step-up reauthentication.
11. Local sign-out, global sign-out, global sign-out API error, revoked refresh token, expired access token and old session replay.
12. Membership/role revoke while a JWT is still valid and a protected page remains open.
13. Session inventory synchronization and targeted revocation.
14. Account deactivation/deletion request, approval, ownership transfer, legal hold, storage cleanup, session revocation and completion.
15. Email change, phone change and security notification delivery.
16. Verify no access after banned/deleted user state and no orphaned organization owner.
17. Verify all auth actions generate complete audit records without passwords, raw tokens, TOTP secrets or recovery codes in logs.

No staging test was executed. No production Auth mutation was performed.

## 13. Remediation order

**P0**
1. Remove metadata-derived role/tenant decisions from React AuthContext and any other protected client.
2. Ensure every sensitive backend operation validates current membership, permission and required AAL independently of the frontend.

**P1**
3. Implement session inventory and real global/selected-session revocation with error verification.
4. Implement the generic organization invitation lifecycle; distinguish Auth invites from organization membership invites.
5. Add update/revoke audit for membership and role assignments, with a session revocation policy.
6. Remove destructive automatic pending-MFA-factor cleanup on page load.
7. Replace metadata-only driver self-provision eligibility with explicit server-side onboarding intent; preserve the secure carrier invite path.
8. Implement the account deactivation/deletion processor or keep those pages explicitly request-only.
9. Configure and verify security-sensitive email notifications and recovery behaviour.

**P2**
10. Canonicalize role authority and account lifecycle state machine.
11. Implement scoped device registry and consent policy catalogue.
12. Retire dead legacy invitation/session flows after migration reconciliation.

## 14. Release decision

**NO-GO for full authentication lifecycle certification.** The canonical sign-in and secure driver invitation path are meaningful foundations, but KRIM does not yet have a complete organization invitation system, real active-session management, complete membership-revocation audit, or executable account deactivation/deletion. MFA is broadly present but still needs lifecycle hardening and staging tests.

## Change boundary and CI

- Audited repository HEAD: `28a100ab730ac3b25515a9e81058c146109d05c9`.
- Production smoke checks for this SHA: passed (run `43855486005`).
- Static link audit for this SHA: passed (run `43855485958`).
- Pages deployment for this SHA: in progress at the time of this audit (run `43855484469`).
- These checks are repository smoke/link/build evidence, not Auth penetration tests or proof of session revocation.
- Production/repository migration-history mismatch remains unresolved. No migration, DDL, grant, RLS policy, Auth setting, user, invitation, role, MFA factor, session, Edge Function or business record was changed.
