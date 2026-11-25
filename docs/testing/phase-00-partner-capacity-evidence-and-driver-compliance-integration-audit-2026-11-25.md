# Phase 00 — Partner capacity evidence and driver compliance UI integration audit

**Date:** 2026-11-25  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Scope:** Read-only frontend and migration source inspection. No Storage objects, RPCs, database rows, or signed URLs accessed.

## Executive result

This pass confirms a further live Storage upload route and identifies a driver onboarding integration gap:

- **Live upload:** `public/partner/capacity-resources.html` uploads 1–5 partner capacity evidence files to private `krim-partner-verification`.
- **Live review preview:** `app/platform-admin/capacity-resources.html` creates 60-second signed previews for submitted evidence.
- **Driver compliance page:** `app/driver/module-16-driver-profile-compliance.html` is read-only. It loads driver profile and document metadata but contains no document upload control or Storage SDK call. The page tells drivers with no profile to ask their carrier administrator to complete onboarding. Driver upload policies and backend review functions exist, but the live upload caller was not located in this pass.

## Partner capacity evidence submission

### Frontend source

`public/partner/capacity-resources.html`:

- Requires an authenticated user and active partner organization; the page only enables resource submission for a registered-business partner whose verification, lifecycle and compliance states meet the configured eligible values.
- Validates 1–5 supporting files before upload.
- Uploads each file to private `krim-partner-verification`, with object path `{organization_id}/{user_id}/capacity-{UUID}.{pdf|png|jpg}`, `upsert:false`.
- Calls `krim_partner_register_capacity_resource` after all uploads.
- Verifies the returned resource and availability states are exactly `pending_review` and `unavailable`; this prevents a successful submission from being represented as bookable.
- Before the RPC is attempted, it tries to remove partial uploads if an upload fails. If cleanup cannot be confirmed, it instructs the user to contact support. If the RPC was attempted but its outcome is uncertain, it tells the user to check the register before retrying.

### Database registration and cleanup

Migration `supabase/migrations/20261104102936_capacity_resource_private_evidence_uploads.sql` defines a SECURITY DEFINER function with empty pinned search path. It checks:

- Authenticated user, active organization membership and `partner.manage`.
- Organization is active, registered-business, verified/approved, active/verified lifecycle and compliant.
- Allowed resource/availability types, finite positive capacity and future availability interval.
- Active transport mode and location.
- 1–5 unique document paths matching the organization/user/capacity UUID filename pattern.
- Each referenced object exists in `krim-partner-verification`.

A later migration, `20261115152500_bind_partner_capacity_evidence_to_original_uploader.sql`, modifies the registration and review function definitions to bind the object to the submitting user. This is an important ownership hardening step. The approval path also requires evidence to remain present and ties review to the original submitter.

A dedicated Storage DELETE policy permits authenticated cleanup only for the caller's capacity-prefixed objects that are not linked from capacity-resource or organization metadata. This is narrower than general delete access.

**Remaining caveat:** the inspected registration function verifies object existence and, after the later hardening migration, uploader ownership. It does not establish byte-signature validation, malware scanning, or a central orphan-object reconciliation worker. These remain open security/operations requirements.

## Admin review and signed preview

`app/platform-admin/capacity-resources.html`:

- Loads the review queue through `krim_admin_list_capacity_resources_lane_aware`.
- Opens a private object preview using `createSignedUrl(path,60)`.
- Displays the 60-second expiry notice.
- Review decisions are separate from preview creation.

Source inspection shows that the page labels the session as MFA-verified superadmin after queue load; however, this frontend label is not itself proof of AAL2. The database queue/review RPC must remain the authoritative AAL2 and role boundary. No runtime session, signed URL or reviewer test was performed.

## Driver compliance: backend exists, live upload caller not found

`app/driver/module-16-driver-profile-compliance.html`:

- Requires a session, active driver membership and active organization.
- Loads the driver's profile and document metadata from `krim_driver_verification_documents`.
- Displays verification state and document review metadata.
- Has no file input, Storage upload call, upload RPC call or document submission action in the inspected page.
- Tells drivers with no profile to ask their carrier administrator to complete onboarding.

The database migration set contains a private `krim-driver-verification` bucket, a caller-owned upload policy, pending-document metadata controls, cleanup of unregistered uploads, and AAL2 admin review functions. The backend therefore supports a driver evidence lifecycle, but this pass did not locate the live page or workflow that allows the driver or carrier to submit files. Do not mark driver self-service compliance upload as implemented or end-to-end wired.

## Updated confirmed frontend Storage operation inventory

Confirmed direct frontend Storage operations now include at least:
- Uploads:
  1. `public/warehouse/warehouse-evidence.html`
  2. `app/customer/customs-documents.html`
  3. `public/partner/compliance-evidence.html`
  4. `app/partner/vehicle-registry.html`
  5. `public/partner/capacity-resources.html`
- Signed previews:
  1. `public/warehouse/warehouse-evidence.html`
  2. `app/customer/customs-documents.html`
  3. `app/admin/vehicle-verification.html`
  4. `app/platform-admin/delivery-pod-verification.html`
  5. `public/shipper/epod-vault.html`
  6. `app/platform-admin/capacity-resources.html`

This is a minimum confirmed list, not a repository-wide exhaustive scan. Earlier reports remain the evidence source for the first four upload routes and previously sampled preview pages.

## Phase 00 blockers and follow-up

1. Locate or implement the canonical driver verification upload workflow; ensure carrier/admin submission authority and driver self-service permissions are explicitly defined.
2. Confirm the exact AAL2 and platform-admin checks in the capacity review RPCs and test them with synthetic users.
3. Verify the deployed Staging hostname routes to Staging Supabase, not the live project, before any test.
4. Reconcile the effective Storage policy set for partner verification, driver verification and POD buckets; remember permissive Storage policies combine with OR semantics.
5. Add byte-signature validation and malware quarantine/scanning before evidence is accepted.
6. Establish an auditable orphan-object reconciliation/cleanup worker without granting broad client delete permissions.
7. After isolated test-sink protections are in place, test upload, registration, preview, approval/rejection, ownership mismatch, cross-organization denial, cleanup and permission revocation.

## Safety boundary

Static source and migration review only. No file content or Storage object was accessed. No upload, download, deletion, signed URL generation, RPC execution, database mutation, Auth mutation, policy change, secret change, merge or deployment occurred.
