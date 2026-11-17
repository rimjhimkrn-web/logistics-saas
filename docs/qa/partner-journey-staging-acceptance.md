# KRIM Partner Journey — Staging Acceptance Test Plan

**Environment:** Staging only  
**Branch:** `ai/partner-gateway-warehouse-routing`  
**Status:** Test plan prepared; browser end-to-end execution not yet performed  
**Production:** No deployment or production data changes

## Safety rules

- Use only a dedicated test email/account and non-production documents.
- Do not upload real PAN, Aadhaar, bank statements, GST certificates or sensitive personal documents to a test environment.
- Do not use a real customer shipment, live freight transaction or real payment.
- Keep India and all markets inactive until legal/operational activation gates are approved.
- Do not mark any partner verified or commercially eligible merely to make a test pass.
- Record screenshots and timestamps without exposing secrets, OTPs, access tokens or full identity documents.

## Test accounts and roles required

1. Partner applicant — registered logistics business pathway.
2. Partner applicant — individual-interest pathway.
3. Partner applicant — development/test pathway.
4. Platform administrator — MFA/TOTP enrolled, AAL2 session, `admin.platform` permission.
5. Optional second administrator/reviewer — required to test reviewer independence and prevent self-approval.

Use separate test identities for applicant and reviewer. An applicant must not approve their own case.

## Acceptance sequence

### A. Entry and account creation

- [ ] Open partner gateway in Staging.
- [ ] Confirm registered-business, individual-interest and development/test routes are visible and correctly labelled.
- [ ] Create a registered-business test account.
- [ ] Confirm duplicate/invalid email handling and required-field validation.
- [ ] Confirm email confirmation is required where configured.
- [ ] Open the confirmation link and verify the callback returns to the correct partner flow.
- [ ] Refresh and sign out/in; confirm organization provisioning is not duplicated.
- [ ] Confirm a user with no active partner organization cannot enter a commercial workspace.

**Pass condition:** account is authenticated, exactly one intended active partner organization is linked, and no commercial access is granted by signup alone.

### B. MFA and workspace routing

- [ ] Enrol TOTP MFA for the test partner.
- [ ] Confirm workspace entry is blocked until the required AAL2 level is present.
- [ ] Confirm the partner gateway routes the account to the matching account-mode workspace.
- [ ] Confirm a warehouse organization routes correctly.
- [ ] Confirm multiple active partner organizations do not silently select an arbitrary organization.
- [ ] Confirm sign-out returns to partner sign-in.

**Pass condition:** only the correct authenticated organization workspace opens, with server-side permissions still enforced.

### C. Verification submission

- [ ] Enter test business identity and operational details.
- [ ] Upload synthetic PDF/JPEG/PNG evidence to the private verification bucket.
- [ ] Confirm unsupported file types and files above the size limit are rejected.
- [ ] Confirm a partner cannot read another organization's evidence.
- [ ] Submit the verification application.
- [ ] Confirm status is pending and commercial functions remain restricted.
- [ ] Confirm failed submission/refresh does not delete evidence already committed to the case.

**Pass condition:** a pending case is created with organization-scoped private evidence and a durable audit trail.

### D. Independent admin review

- [ ] Sign in as a separate administrator with MFA/AAL2.
- [ ] Confirm a non-admin and an admin without AAL2 cannot access the review queue.
- [ ] Open the pending case and preview evidence through a short-lived signed URL.
- [ ] Confirm the applicant cannot approve their own case.
- [ ] Test request-information with a clear note; confirm the partner sees the exact request.
- [ ] Resubmit corrected synthetic evidence; confirm the same case is reopened/updated according to the intended workflow.
- [ ] Test rejection with a valid reason.
- [ ] Test approval only with valid evidence and independent reviewer.
- [ ] Confirm every decision creates an audit event and updates the partner-visible state.

**Pass condition:** only an authorized independent reviewer can decide; every decision is traceable and the partner receives the correct status.

### E. Capability, service area and capacity

- [ ] Confirm unverified/non-compliant partners cannot submit commercial service areas.
- [ ] Confirm India service-area submission remains blocked while India is inactive or has no active market/location.
- [ ] Confirm the service-coverage page refuses to silently select an organization when the signed-in user has multiple active partner organizations; the intended organization must be selected explicitly.
- [ ] Confirm the service-coverage page lists only active partner organizations belonging to the signed-in user, requires an explicit choice when there are multiple, and remembers the choice for the current browser session.
- [ ] Tamper with or retain a stale selected organization ID; confirm it is ignored unless that ID is still present in the user's active partner memberships, and the chooser is shown again.
- [ ] Confirm capability registration is locked unless the selected organization is an active registered business with approved verification, active lifecycle and current compliance.
- [ ] Confirm only active KRIM transport modes and countries can be selected; an inactive country such as India must not be selectable.
- [ ] Submit one to five valid PDF/JPEG/PNG evidence files (maximum 10 MB each); confirm files are uploaded under the selected organization/user capability folder and the database RPC creates a pending, inactive capability.
- [ ] Confirm capability submission rejects invalid service types, inactive country/mode IDs, invalid weight, malformed evidence paths, missing evidence objects, oversized details and duplicate pending capability requests.
- [ ] Confirm an uncertain RPC response is not blindly retried; uploaded evidence is retained for reconciliation when the database outcome is unknown.
- [ ] Confirm a successful submission appears in the selected organization's capability registry as pending and inactive, with evidence count and details saved.
- [ ] Confirm another organization cannot read or manage the submitted capability or its private evidence.
- [ ] In a separate test jurisdiction only, submit a test capability and service area with valid synthetic evidence.
- [ ] Submit a verified resource and availability window.
- [ ] Confirm unverified, expired, inactive, insufficient-capacity or mismatched-lane resources do not qualify.
- [ ] Confirm enough verified capacity is required for the requested units.
- [ ] Test held and confirmed reservations reduce remaining capacity.
- [ ] Test overlapping/concurrent matching attempts and ensure capacity cannot be overbooked.
- [ ] Test invalid dates/time zones and confirm the system fails closed.

**Pass condition:** matching never returns a partner as eligible without approved service capability, active route/market, current evidence and sufficient verified capacity.

### F. Notifications

- [ ] Confirm in-app notification appears for relevant verification changes.
- [ ] Confirm only the intended authenticated user can read their notifications.
- [ ] Confirm mark-as-read affects only the user's own notification.
- [ ] Confirm refresh/polling does not create duplicates.
- [ ] Test email only after a dedicated Resend test key, verified sender/domain and cron secret are configured in Staging.
- [ ] Confirm email retries are idempotent and failed messages remain observable.

**Pass condition:** notification access is correctly scoped; email is not considered tested until a real test email is received and delivery status is confirmed.

### G. Negative and security tests

- [ ] Anonymous access to private partner documents is denied.
- [ ] Cross-organization document reads are denied.
- [ ] Non-admin queue reads/writes are denied.
- [ ] Authenticated users cannot directly insert admin decisions or notifications.
- [ ] Partner cannot self-approve or alter verification status directly.
- [ ] Stale/expired signed evidence links stop working.
- [ ] Malformed RPC inputs fail closed.
- [ ] Audit events cannot be modified by ordinary partner users.
- [ ] No freight collection, split settlement, payout or live payment is triggered in this test journey.

## Current execution record

| Area | Current evidence | Status |
|---|---|---|
| Partner routing and UI code | Changes present in open draft PR #68 | Implemented in branch; browser acceptance pending |
| Email confirmation callback/provisioning | Code changes present in PR #68 | Implemented in branch; browser acceptance pending |
| MFA/AAL2 gates | Existing flow and PR changes | Browser acceptance pending |
| Private verification storage and RPCs | Staging migrations/policies previously inspected | Database-level checks performed; browser upload/read test pending |
| Independent admin review | Backend guards and UI present | Browser acceptance pending |
| Service-area workflow | UI/RPC present; Staging has zero service-area rows | No positive end-to-end test |
| Capacity matching | Private eligibility helper and matching gate present | Definition/negative-input checks performed; positive/negative fixture tests pending |
| In-app notifications | Page and RLS grants present | Browser acceptance pending |
| Resend email | Worker deployed to Staging; secrets/cron/test email not configured | Not operationally tested |
| India market activation | Country inactive; pack `research_pending`; no source records | Correctly blocked |

## Release gate

Do not merge PR #68 or deploy to Production until:
- All applicable tests above pass with recorded evidence.
- Any failed test is fixed and rerun.
- Security review covers RLS, RPC grants, storage policies and service-role functions.
- Capacity/date/time-zone and concurrency tests pass.
- The India legal/market activation gates are separately satisfied.
- The owner explicitly approves release.
