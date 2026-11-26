# KRIM Phase 04.6 — Driver Signup, Verification, Fleet Binding and Dispatch Trace

Date: 2026-11-26
Branch: remediation/phase-03dw-isolation-2026-11-26
Scope: Static source review of driver signup/sign-in/callback and driver-related migrations, plus read-only live Staging/Production inspection of driver security-definer functions, ACLs and schema.

## Decision

**Driver synthetic-user creation and real driver onboarding remain BLOCKED.** No database changes, deployments, test identities, document uploads, or real dispatch actions were performed.

This trace found two separate classes of blockers: a broken/insecure self-registration route and Staging RPC permission drift that can break the intended invitation and review journey.

## 1. Signup and sign-in route trace

Source reviewed:
- `auth/driver-signup.html`
- `auth/driver-signin.html`
- `auth/auth-callback.html`

Observed sequence:
1. Driver signup creates an Auth user and stores profile fields in editable user metadata, including `krim_account_type='driver'`.
2. Email confirmation returns to the shared auth callback.
3. The callback routes to Driver Sign In based on that metadata. The callback itself correctly says email confirmation does not authorize a workspace.
4. Driver Sign In first checks active `krim_organization_members` rows.
5. If no driver membership exists but metadata says driver, it calls `krim_provision_driver_organization()`.
6. That RPC currently creates an active `driver_individual` carrier organization and active driver membership.
7. Driver Sign In then checks active membership and active organization, then requires verified TOTP/AAL2 before opening the workspace.

Security issue: metadata is not trusted authorization. The active membership check is server-backed, but the auto-provision branch uses editable metadata to invoke a SECURITY DEFINER routine that creates a privileged-looking active driver membership. Do not restore authenticated EXECUTE to this routine in this state.

Functional issue: the self-provisioning function creates a standalone `driver_individual` organization and membership, but does not create a `krim_driver_profiles` row. The reviewed driver approval process expects a driver profile linked to a verified, compliant registered-business carrier with verified transport capability and accepted licence/identity evidence. Therefore, the self-registration route does not establish the prerequisites for normal commercial driver approval and fleet binding.

## 2. Intended carrier-invitation path

The repository migration `20261104192000_lock_driver_onboarding_mode.sql` defines a more defensible commercial path:
- invitation token must be 64 lowercase hex characters and is stored/checked by hash;
- signed-in email must be confirmed and match the invited email;
- invitation must be unused, unrevoked and unexpired;
- carrier must be active, registered-business, verified, compliant and have active verified transport capability;
- development/test drivers are excluded from commercial carrier operations;
- driver membership and profile are created/linked in the carrier organization;
- profile remains pending;
- invitation acceptance is audited.

This is the appropriate commercial onboarding direction. However, the live Staging ACL currently denies authenticated EXECUTE on `krim_accept_driver_invitation(text)`, whereas Production grants authenticated EXECUTE. The browser sign-in source calls this RPC when an invitation is present. This is a confirmed Staging functional blocker.

## 3. Driver verification and evidence controls

The reviewed verification source requires:
- private storage bucket for driver evidence;
- owner-scoped document uploads;
- document rows tied to the authenticated user's profile and organization;
- document review states pending/accepted/rejected;
- AAL2 plus `admin.platform` for verification review;
- approval only after complete driver profile, future licence expiry, active driver membership, verified compliant registered carrier, current verified transport capability, and independently accepted front/back licence plus identity documents;
- self-review denied;
- identity/licence detail changes reset verification to pending;
- licence expiry enforced across operations.

The database guards prevent a user from self-setting verification status. These are positive controls in source/live function definitions, but browser/storage runtime behavior and negative RLS tests remain untested.

## 4. Vehicle binding and assignment acceptance

Live function definitions reviewed:
- `krim_vehicle_driver_bind(bigint,uuid,uuid)`
- `krim_driver_accept_assignment(uuid)`

The binding function requires:
- caller has partner `shipment.dispatch` permission;
- partner is active, registered-business, verified, compliant and lifecycle active;
- current verified transport capability;
- vehicle belongs to partner, is verified and active;
- required vehicle documents are approved and unexpired;
- driver profile is verified, licence number present, licence expiry future;
- active driver membership in the same organization;
- all three driver evidence documents independently accepted;
- no conflicting active driver/vehicle binding.

Assignment acceptance requires:
- assignment belongs to the signed-in driver;
- active driver membership;
- verified driver profile and future licence expiry;
- accepted front/back licence and identity evidence;
- verified, active, bound vehicle and approved current vehicle documents;
- accepted partner assignment matches exact shipment, leg and partner;
- shipment/leg state is eligible;
- shipment weight is within vehicle capacity;
- ROAD leg and current partner capability/service-area coverage.

These are strong static guards. They have not been exercised with signed-in identities.

## 5. Trip event and dispatch execution

Live `krim_driver_record_trip_event(uuid,text,text)`:
- binds assignment to auth.uid();
- checks active driver membership and exact assignment;
- checks linked partner assignment, shipment, and leg;
- only permits pickup, in_transit, exception;
- requires accepted driver assignment for pickup;
- requires pickup before in_transit;
- checks exact-leg dispatch authorization, partner compliance, capability, capacity and custody for active multi-leg shipments;
- restricts pickup/transit to ROAD for multi-leg shipments;
- writes trip, tracking and partner execution events.

The prior audit finding remains open: `private.krim_leg_dispatch_authorization_is_current(...)` does not itself check customs clearance. The general shipment compliance/customs gates must be reconciled before real dispatch. This driver trace does not close that Phase 03 blocker.

## 6. Live ACL comparison — important Staging drift

Live ACL inspection found:
- Production authenticated EXECUTE: `krim_accept_driver_invitation(text)` YES; `krim_admin_review_driver_verification(uuid,text,text)` YES; `krim_driver_accept_assignment(uuid)` YES; `krim_driver_record_trip_event(uuid,text,text)` YES.
- Staging authenticated EXECUTE: invitation acceptance NO; admin review NO; driver assignment acceptance YES; driver trip event YES.
- `krim_vehicle_driver_bind(bigint,uuid,uuid)` is service_role-only in both inspected environments (authenticated EXECUTE NO). This may be intentional if invoked only through a trusted server path, but the browser call-site and intended invocation architecture must be confirmed before any permission change.
- anon EXECUTE is denied on the inspected routines.

Thus the live Staging invitation-acceptance and admin-review functions cannot be called directly by an authenticated browser client as currently configured. This conflicts with the repository's browser-driven invitation and admin-review RPC design. Do not grant access until source provenance, intended RPC callers, AAL2/permission guards and audit behavior are reconciled.

## 7. Required remediation sequence

### Gate A — remove metadata-based self-provisioning
- Remove the `krim_provision_driver_organization()` auto-provision call from driver sign-in.
- Treat `krim_account_type` only as routing/onboarding intent.
- Require a valid carrier invitation or a separately approved driver application.
- Keep driver workspace access dependent on active membership plus approved profile and AAL2.

### Gate B — make signup path coherent
- Either remove public self-registration or convert it to a pending driver application that creates no active operational membership.
- Ensure every commercial driver profile is linked to a verified carrier organization through a valid invitation.
- Ensure no driver_individual self-created organization can satisfy carrier verification/dispatch controls.
- Make email confirmation and invitation acceptance idempotent and safe for retries.

### Gate C — reconcile Staging RPCs
- Recover canonical migration provenance for invitation acceptance and admin review.
- Decide whether these functions should be browser-callable; if yes, add only authenticated EXECUTE with the existing in-function identity/AAL2/permission checks and explicit anon/PUBLIC revokes.
- Confirm vehicle binding is intentionally service_role-only or route it through a secured server endpoint; do not grant authenticated by assumption.
- Test direct RPC calls, cross-user invitation token use, expired/revoked/replayed invitations, self-review, non-AAL2 review, non-admin review, and profile/evidence mismatch.

### Gate D — operational eligibility
- Test driver profile verification, licence expiry, document revocation/re-upload, vehicle binding, assignment acceptance, dispatch revocation, and event replay.
- Resolve customs/compliance gate omission for all applicable shipment legs before dispatch.
- Only then proceed to synthetic driver accounts.

## Status register

| Check | Status |
|---|---|
| Driver signup/sign-in/callback source trace | VERIFIED |
| Editable metadata used to trigger driver self-provisioning | VERIFIED |
| Self-provisioning creates active driver membership without driver profile | VERIFIED |
| Invitation path validates confirmed email and verified carrier | VERIFIED in source and live function |
| Staging authenticated EXECUTE missing for invitation acceptance | VERIFIED |
| Staging authenticated EXECUTE missing for admin review | VERIFIED |
| Assignment acceptance evidence/fleet gates | VERIFIED in live function definition |
| Driver trip event ownership and state gates | VERIFIED in live function definition |
| Vehicle binding browser/server invocation intent | UNRESOLVED |
| Browser, Storage and RPC runtime tests | NOT TESTED |
| Customs gate for all applicable legs | OPEN Phase 03 blocker |
| Synthetic driver users | BLOCKED |

No Production or Staging state was changed.
