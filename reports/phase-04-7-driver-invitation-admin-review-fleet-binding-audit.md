# KRIM Phase 04.7 — Partner Invitation, Admin Review and Fleet Binding Call-Site Audit

Date: 2026-11-26
Branch: remediation/phase-03dw-isolation-2026-11-26
Scope: Read-only repository call-site trace and live Production/Staging function definition and EXECUTE ACL comparison.

## Decision

**Phase 04.7 audit complete. Driver onboarding and synthetic-user generation remain BLOCKED.**

The intended Production workflow is substantially coherent: verified carriers create scoped driver invitations; drivers accept one-time invitations; AAL2 platform admins review driver documents; partner dispatch-authorized users bind verified drivers to verified vehicles. However, Staging is not currently capable of exercising the real authenticated workflow: every inspected invitation, admin-review and vehicle-binding RPC is denied to the authenticated role in Staging, while Production grants the expected authenticated EXECUTE. The staging pages that were inspected mostly switch to local illustrative previews and do not exercise the backend.

No Production or Staging database changes, migrations, grants, deployments, account creation, invitation issuance, evidence upload or fleet mutation occurred.

## 1. Partner-issued driver invitation page

Source: `public/partner/driver-invitations.html`

Production call sequence:
1. Uses the shared KRIM Supabase client and requires a signed-in account.
2. Reads active organization memberships and organization status.
3. Requires exactly one eligible active registered-business organization that is verified, lifecycle-active and compliant.
4. Requires active verified transport capability.
5. Calls:
   - `krim_list_driver_invitations(p_organization_id)`
   - `krim_create_driver_invitation(p_organization_id,p_email)`
   - `krim_revoke_driver_invitation(p_invitation_id)`
6. Displays the one-time invite URL returned by the create RPC and lets the partner copy it. The page does not itself send an email.
7. Staging hostname takes a local preview path: illustrative records only; no backend invitation RPC is called.

Live Production function definitions:
- List and revoke both require authenticated `auth.uid()` and `partner.manage` permission scoped to the supplied invitation organization.
- Create requires `partner.manage`, valid email, active verified compliant registered-business carrier and active verified transport capability; it applies a per-inviter hourly limit, revokes prior unused invitations to the same email, creates a 7-day single-use random token, stores only its hash, and writes an audit event.
- Revoke checks the invitation's actual organization, requires `partner.manage`, only revokes unused/unrevoked invitations, and writes an audit event.
- The invitation acceptance routine separately checks confirmed matching email, token validity/expiry/replay/revocation and current carrier eligibility.

Positive: authorization is enforced in the SECURITY DEFINER routines, not trusted to the page's client-side membership checks. Invitation tokens are stored hashed and acceptance is scoped to the confirmed invited email.

Operational limitation: no mail delivery is implemented by this page; a partner manually shares the returned private link. Do not describe this as an email invitation service.

## 2. Driver invitation signup and callback handoff

Source: `auth/driver-signup.html`

- Signup reads the `invite` query parameter and stores it in sessionStorage.
- The same invite parameter is included in the email-confirmation callback URL.
- Signup metadata includes driver profile fields and `krim_account_type='driver'`; these remain untrusted user-editable metadata and must not authorize operational access.
- The earlier Phase 04.6 finding remains: the sign-in self-provisioning fallback must be removed. A valid invitation is the commercial onboarding route; metadata is routing intent only.
- No live invite token was generated or tested.

## 3. Platform-admin driver document review

Source: `app/platform-admin/driver-verification.html`

The page directly calls:
- `krim_admin_list_driver_verification_with_expiry()`
- `krim_admin_review_driver_document(p_document_id,p_decision,p_reason)`
- `krim_admin_update_driver_licence_expiry(...)`

It previews evidence from the private `krim-driver-verification` bucket using a 60-second signed URL. Review decisions are made by RPC, not direct table writes.

Live Production review RPC:
- requires authenticated user;
- requires JWT AAL2;
- requires `admin.platform`;
- denies reviewer self-review;
- requires original uploader ownership and expected private object path before accepting a document;
- marks evidence accepted/rejected and records reviewer/reason;
- only sets the profile verified when licence number is present, licence expiry is future, front/back licence and identity documents are all accepted, carrier organization is active/verified/compliant, transport capability is verified, and active driver membership exists;
- writes audit state.

This current live definition is stronger than the older migration snapshot that appeared to require fewer document types. The live database definition was used for this assessment. The page uses document-level review; it does not call the separate profile-level review RPC.

## 4. Vehicle registry and independent review

Sources:
- `app/partner/vehicle-registry.html`
- `app/admin/vehicle-verification.html`

Partner registry submits vehicle and evidence through dedicated RPCs and private `krim-partner-verification` storage. Admin review uses:
- `krim_vehicle_review_queue()`
- `krim_vehicle_review_document(...)`
- `krim_vehicle_admin_vehicle_list()`
- `krim_vehicle_finalize_verification(...)`

Live functions are service_role-only at the EXECUTE ACL layer, consistent with a private admin/server-mediated path. The admin page calls these functions using the signed-in browser client, however. This creates a caller/ACL inconsistency: either the page must use a trusted server-side admin gateway or the intended authenticated admin function permissions must be explicitly designed and granted with strong in-function AAL2/platform-admin checks. Do not grant browser EXECUTE merely to make the page work. Confirm actual role handling in `krim_vehicle_admin_guard()` and the deployed admin gateway before changing the architecture.

The finalization routine requires a configured non-empty country/category document requirement set, all required evidence approved and current, and reviewer independence from evidence the reviewer submitted. No runtime test was performed.

## 5. Driver–vehicle binding page

Source: `app/partner/driver-vehicle-assignment.html`

Production page uses browser-authenticated Supabase RPCs:
- `krim_vehicle_driver_eligible_vehicles(p_organization_id)`
- `krim_vehicle_driver_eligible_drivers(p_organization_id)`
- `krim_vehicle_driver_binding_list(p_organization_id)`
- `krim_vehicle_driver_bind(p_organization_id,p_vehicle_id,p_driver_user_id)`
- `krim_vehicle_driver_unbind(p_binding_id,p_reason)`

The UI checks active owner/manager membership and requires a single partner organization. The actual SECURITY DEFINER functions enforce `shipment.dispatch`, organization/carrier verification and compliance, current transport capability, vehicle verification/active status, mandatory current vehicle evidence, driver verified profile, future licence expiry, active same-organization driver membership, accepted front/back/identity documents, and uniqueness of active driver/vehicle binding. Unbind requires dispatch permission and reason, refuses while relevant active shipment assignments exist, and writes audit events.

Staging path is local preview with sample records; it does not call these RPCs.

## 6. Production vs Staging EXECUTE ACL comparison

The following inspected routines all deny anon EXECUTE in both environments.

| RPC | Production authenticated | Staging authenticated |
|---|---:|---:|
| Create driver invitation (bigint,text) | YES | NO |
| List driver invitations (bigint) | YES | NO |
| Revoke driver invitation (uuid) | YES | NO |
| Admin list driver verification with expiry | YES | NO |
| Admin review driver document | YES | NO |
| Vehicle eligible vehicles | YES | NO |
| Vehicle eligible drivers | YES | NO |
| Vehicle binding list | YES | NO |
| Vehicle-driver bind | YES | NO |
| Vehicle-driver unbind | YES | NO |

This is a verified environment drift, not merely a UI preview issue. Staging cannot run the intended authenticated browser calls. The local preview mode masks this by never calling the RPCs.

A legacy overload `krim_create_driver_invitation(text)` also exists in Production, but authenticated and anon EXECUTE are both denied; the current page uses the explicit organization-scoped `(bigint,text)` overload. Do not re-enable the legacy overload.

## 7. Additional eligibility-list mismatch

The live `krim_vehicle_driver_eligible_drivers` list filters verified profile, active driver membership, accepted front/back licence and absence of active binding, but does not filter future licence expiry or accepted identity document. The final bind RPC checks both. This means the UI can display a candidate that the bind RPC will reject. The bind routine remains fail-closed; the eligibility query should be aligned for accurate operator UX.

## 8. Remediation sequence

1. Keep `krim_provision_driver_organization()` authenticated EXECUTE revoked and remove metadata-based self-provisioning from driver sign-in.
2. Keep the verified carrier invitation as the commercial entry route; ensure invitation acceptance produces only pending profile verification.
3. Resolve the vehicle-admin invocation architecture: browser client vs trusted admin Edge Function/server gateway. Preserve AAL2, `admin.platform`, reviewer independence, evidence ownership and audit requirements.
4. Reconcile Staging RPC grants only after recovering canonical migration provenance. For each RPC, decide whether authenticated browser execution is intended. Keep service-role-only functions behind a trusted server route. Never bulk grant or replay Production migrations.
5. Align `krim_vehicle_driver_eligible_drivers` with final binding checks (future licence expiry and accepted identity document).
6. Build negative tests for cross-organization invitation list/revoke, wrong carrier role, unverified carrier, replayed/expired/revoked invite, non-AAL2/non-admin review, self-review, missing/backdated licence, wrong evidence owner, missing identity evidence, expired vehicle documents, duplicate binding, cross-tenant binding, and unbind with active assignments.
7. Only after these checks and the Phase 03 customs/compliance dispatch blockers are resolved should isolated Staging synthetic driver identities be created.

## Status register

| Area | Status |
|---|---|
| Partner invitation page call-site mapping | VERIFIED |
| Invite create/list/revoke authorization in Production | VERIFIED in live function definitions |
| Token hash, expiry, replay/revocation controls | VERIFIED in live function definition |
| Driver signup invitation handoff | VERIFIED in source |
| Admin document review page call-site mapping | VERIFIED |
| Admin document approval controls | VERIFIED in live function definition |
| Vehicle review page call-site mapping | VERIFIED |
| Vehicle finalization evidence gates | VERIFIED in live function definition |
| Driver–vehicle binding page call-site mapping | VERIFIED |
| Binding/unbinding authorization gates | VERIFIED in live function definitions |
| Production/Staging authenticated EXECUTE drift | VERIFIED |
| Staging real authenticated browser workflow | BLOCKED |
| Admin vehicle review caller architecture | UNRESOLVED |
| Eligible-driver list parity with bind checks | GAP IDENTIFIED |
| Browser/storage/RPC runtime tests | NOT TESTED |
| Driver synthetic identities | BLOCKED |
| Customs/compliance clearance enforcement | OPEN Phase 03 blocker |

No Production or Staging state was changed.
