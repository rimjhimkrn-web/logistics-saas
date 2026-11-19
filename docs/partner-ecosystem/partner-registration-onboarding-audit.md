# KRIM Partner Registration → Onboarding → Verification → Workspace Audit

**Audited branch:** `staging/owner-admin-url-fix`  
**Database checked:** KRIM Logistics Staging (`qrpcivhdxobiaofppbkl`)  
**Scope:** Public partner registration, email confirmation, sign-in, onboarding, document upload, verification review and workspace routing.  
**Status:** Read-only source and staging-database audit. No code, schema, data or production changes made.

## Executive result

The journey has a substantial foundation: partner registration provisions an organization, email confirmation routes to role-specific sign-in, partner sign-in checks active membership and organization state, onboarding submits a multi-category application, and the admin verification RPCs enforce platform-admin permission plus AAL2.

However, the journey is **not yet cleared for production**. The key blocker is inconsistent MFA enforcement: several partner pages and partner-facing SECURITY DEFINER functions do not independently require AAL2, and the private document bucket's upload policy is authenticated/member scoped but does not add a restrictive AAL2 condition. Client-side sign-in checks are not a substitute for server/database enforcement.

## File-by-file findings

| File | Current role | Source inspection finding | Decision |
|---|---|---|---|
| `auth/partner-signup.html` | Create partner account | Uses Supabase signUp; collects business/applicant name, pathway, country, city and service category; records terms acceptance in user metadata; provisions organization and sets mode when a session is returned; otherwise sends user to email confirmation. | KEEP; test email-confirmation and retry recovery. |
| `auth/auth-callback.html` | Email confirmation callback | Explicitly treats email confirmation as identity proof only, then routes partner accounts to partner sign-in. | KEEP. |
| `auth/partner-signin.html` | Partner login | Checks active organization membership, resolves partner organization, attempts provisioning recovery for partner metadata accounts, checks verified TOTP and AAL2, then routes to partner gateway. | KEEP; validate direct-route bypass protections at DB level. |
| `auth/partner-redirect.html` | Session redirect | Checks for a session then redirects to the partner gateway. The gateway is responsible for organization resolution. | KEEP as a thin compatibility route, or redirect directly to gateway. |
| `public/partner/partner-onboarding.html` | Application and evidence submission | Checks session, active membership, partner organization and account mode; uploads documents to private bucket; calls multi-category onboarding RPC. No explicit client-side MFA/AAL2 check was found. | KEEP; MFA gate and backend enforcement are required. |
| `app/partner/index.html` | Partner workspace gateway | Checks session, active organization membership, organization type/status and account mode; routes to role-specific workspace. No explicit MFA/AAL2 check was found. | KEEP; add MFA UX gate and rely on enforced backend/RLS. |
| `app/partner/business/index.html` | Registered-business workspace | Checks session, membership, organization type/status and verification/compliance/lifecycle state. No explicit MFA/AAL2 check was found. | KEEP; add MFA UX gate and verify every data path. |
| `app/partner/individual/index.html` | Independent workspace | Checks session, membership, organization type/status and pathway; displays restricted interest status. No explicit MFA/AAL2 check was found. | KEEP; add MFA UX gate and verify every data path. |
| `app/partner/development/index.html` | Non-commercial test workspace | Checks session, membership and development/test mode; labels test mode non-commercial. No explicit MFA/AAL2 check was found. | KEEP for controlled test users only; exclude from public commercial navigation. |
| `app/platform-admin/partner-verification.html` | Admin verification queue | Calls admin list/review RPCs and has MFA/privileged-session checks in the UI. | KEEP; DB functions also enforce AAL2 and platform permission. |
| `app/platform-admin/partner-compliance.html` | Admin compliance queue | Uses AAL2 checks and dedicated admin review RPCs. | KEEP. |
| `app/platform-admin/partner-capabilities.html` | Admin capability review | Uses MFA/privileged-session checks and dedicated RPCs. | KEEP. |
| `app/platform-admin/partner-service-areas.html` | Admin service-area review | Uses AAL2 session verification and dedicated RPCs. | KEEP. |

## Staging database checks

### Verified positive controls

- `krim-partner-verification` bucket exists and is private.
- `krim_organization_members` SELECT policy limits membership visibility to the signed-in user's own memberships.
- `krim_organizations` SELECT policy scopes access to active organization membership; platform-admin read is separately AAL2 and permission gated.
- `krim_admin_list_partner_verification_cases()` checks authenticated user, AAL2 and `admin.platform` permission.
- `krim_admin_review_partner_verification(...)` checks authenticated user, AAL2 and `admin.platform` permission; requires a rejection reason; validates required business fields and private-storage ownership before approval; writes an audit event.
- Approval in the verification RPC does not automatically mark compliance as complete; it leaves compliance pending.

### Security blockers requiring a staging migration

The following staging database function definitions were inspected:

- `krim_provision_partner_organization(text)` — SECURITY DEFINER; checks `auth.uid()` and organization constraints, but does not check `auth.jwt()->>'aal' = 'aal2'`.
- `krim_set_partner_account_mode(text,jsonb)` — SECURITY DEFINER; checks authenticated membership and mode constraints, but does not check AAL2.
- `krim_submit_partner_onboarding_global_multi_v1(...)` — SECURITY DEFINER; checks authenticated identity, organization membership, registered-business mode, document path and coverage, but does not check AAL2.
- The private bucket's `storage.objects` INSERT policy checks authenticated user, own user folder and active partner organization membership, but no restrictive AAL2 policy was found for this bucket.

**Impact:** The public sign-in UI's MFA flow is not enough by itself. A user holding an AAL1 session may be able to reach these page/RPC/storage paths directly unless a separate database control denies the request. Enforce MFA at the database/storage layer before treating the partner document-submission path as secure.

## Required remediation sequence

1. Add an AAL2 check to the three partner-facing SECURITY DEFINER functions above, retaining their existing ownership, validation and audit logic.
2. Add a **restrictive** `storage.objects` INSERT policy for `krim-partner-verification` requiring `auth.jwt()->>'aal' = 'aal2'`; retain the existing organization-folder ownership policy.
3. Add user-friendly MFA enrollment/challenge gates to onboarding, partner gateway and role-specific workspaces. These are UX controls; the database checks remain authoritative.
4. Verify function EXECUTE grants and ensure no unintended anonymous execution path exists.
5. Test AAL1 denied / AAL2 allowed for registration provisioning, pathway update, onboarding RPC and private document upload, using staging test identities only.
6. Verify admin review, rejection, approval and audit-event behavior still work.
7. Test the full browser journey and direct URL entry, then update the cleanup map with verified canonical routes.

## Test status

| Test | Result |
|---|---|
| Source inspection of signup, callback, signin, onboarding and workspace gateway | Completed |
| Source inspection of business, individual and development workspaces | Completed |
| Source inspection of four platform-admin review pages | Completed |
| Staging database function-definition inspection | Completed |
| Staging RLS/storage policy inspection | Completed |
| Real browser signup/email confirmation | Not performed |
| AAL1/AAL2 RPC and storage negative/positive tests | Not performed |
| Real document upload and admin signed-link review | Not performed |
| Full partner end-to-end test | Not performed |
| Production changes | None |

## Decision

Keep the existing journey pages. Do not delete or merge registration, onboarding, verification or role-specific workspace pages at this stage. Fix and verify the MFA/backend boundary first; then consolidate navigation and aliases without breaking the journey.


## Staging-only remediation applied (19 Nov 2026)

A staging database change was applied and then read back for verification.

- Added an AAL2 check to `krim_submit_partner_onboarding_global_multi_v1(...)`. AAL1 requests are rejected before verification data is submitted.
- Added a restrictive INSERT policy on `storage.objects` for the private `krim-partner-verification` bucket. It requires AAL2 while retaining the existing permissive organization-folder/user ownership policy.
- Confirmed the bucket remains private.
- Confirmed both the original upload ownership policy and the new restrictive AAL2 policy are present.
- Confirmed the onboarding RPC definition contains the new MFA guard.
- Kept `krim_provision_partner_organization` and `krim_set_partner_account_mode` available during bootstrap. These operations create pending/non-commercial state and are called before the partner can complete MFA enrollment; blocking them at AAL1 would break initial registration. They do not approve verification or enable commercial access.
- Tracked the repeatable SQL change at `supabase/migrations/202611190001_partner_onboarding_require_aal2.sql`.

**Still outstanding:** add clear MFA enrollment/challenge guidance to the partner onboarding page before document upload; perform authenticated AAL1-denial/AAL2-success tests using dedicated staging accounts; verify function grants and direct URL behavior; run full browser end-to-end testing. The database policy is the security boundary; the page-level MFA prompt is usability, not a replacement for it.

**Do not interpret this as full production approval.** No production project was changed.


## Partner onboarding MFA guidance added (19 Nov 2026)

Updated `public/partner/partner-onboarding.html` on the staging branch:

- Added a visible MFA explanation when the Registered Business pathway is selected.
- Before any registered-business document upload, the page checks for a verified TOTP factor.
- If no verified factor exists, it sends the user to `auth/mfa-enroll.html`.
- If a factor exists but the session is not AAL2, it sends the user to `auth/mfa-challenge.html`.
- Both flows return to the Partner Workspace gateway; the user can reopen onboarding from there.
- Development/Test and Independent Interest pathways are not forced through the business-document MFA gate.

**Static validation:** both inline scripts passed JavaScript syntax compilation; the MFA gate was confirmed to occur before the first document upload call.

**Not yet verified:** browser execution of enrollment/challenge redirects, live AAL1 denial/AAL2 success using staging test accounts, and end-to-end document submission/reviewer access. The enrollment and challenge pages intentionally return to the Partner Workspace gateway because their allowlists do not permit arbitrary onboarding-page return URLs.
