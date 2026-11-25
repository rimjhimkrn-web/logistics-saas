# Phase 00 — Driver and vehicle evidence upload route reconciliation

**Date:** 2026-11-25  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Scope:** Static frontend and migration review on the QA branch. No runtime upload, RPC execution, Storage access, or database writes.

## Executive result

One additional live frontend upload route was confirmed:

- `app/partner/vehicle-registry.html` — vehicle document upload to private `krim-partner-verification`.

The inspected driver workspace pages did not expose a live Storage SDK upload call in this pass. This does not prove that no driver upload path exists elsewhere in the repository; the driver verification storage policies and backend workflows do exist and must be reconciled against their actual caller route.

## Vehicle document upload route

### Frontend behavior

`app/partner/vehicle-registry.html`:

- In its Staging hostname branch, the page uses illustrative local records and explicitly disables upload/backend submission.
- In its non-Staging branch, it loads the shared Supabase client, requires an authenticated session and exactly one active owner/manager membership in an active partner organization.
- Loads vehicles and existing document metadata through `krim_vehicle_list` and `krim_vehicle_documents_list`.
- Validates PDF/JPEG/PNG and 1–10 MiB in the browser.
- Uploads to `krim-partner-verification` at `{org_id}/{user_id}/vehicle/{vehicle_id}/{UUID}.{ext}`, `upsert:false`.
- Calls `krim_vehicle_document_register` after upload.
- If registration fails after upload, attempts to remove the uploaded object; cleanup failure is logged.
- The UI states that uploaded documents remain private and do not make a vehicle dispatch-eligible. Independent review is still required.

### Registration function

Migration `supabase/migrations/20261106200000_vehicle_document_submission.sql` defines a SECURITY DEFINER registration function with an empty pinned search path. It checks:

- Authenticated caller.
- Vehicle exists and is locked for update.
- Caller has active owner/manager membership in the vehicle's organization.
- Storage path matches organization, uploader, vehicle and filename structure.
- Object exists in `krim-partner-verification` and its `owner_id` matches the caller.
- Submitted MIME and size values are in the allowlist and 1–10 MiB range.
- Expiry date does not precede issue date.

It inserts the document record. The function checks the caller-supplied MIME and size values, but the inspected function does **not** compare them to the actual Storage object metadata. The page performs client-side MIME/size checks; client checks are not a server-side file-integrity control. This gap requires review before treating the vehicle evidence chain as production-secure.

The list function checks active organization membership, then returns document metadata for the vehicle. Its authorization is membership-level, not explicitly owner/manager-level; the exact intended visibility model should be confirmed against the workspace role model.

## Driver evidence reconciliation

Inspected:
- `app/driver/module-04-driver-vehicle-readiness.html`
- `app/driver/module-10-proof-of-delivery.html`
- `app/driver/module-16-driver-profile-compliance.html`
- corresponding sampled Staging pages
- `public/driver/profile.html` and `public/driver/pod-submission.html`
- driver verification Storage and database migrations

No direct Storage SDK upload call was found in the sampled driver workspace pages. The driver verification backend nevertheless defines:
- Private `krim-driver-verification` bucket configuration (10 MiB; PDF/JPEG/PNG).
- Own-user upload policy scoped to the caller's driver profile folder.
- AAL2 + platform-admin read policy for review.
- Own pending-document metadata insertion tied to the caller's profile.
- Cleanup policy for caller-owned unregistered uploads.
- Admin review queue and review functions.

Therefore driver verification upload is **backend-capable but frontend caller not located in this bounded pass**. Do not label the driver upload journey fully wired or tested. Driver POD submission is a separate evidence path and was covered by earlier source/migration audits; it remains runtime-unverified.

## Updated known frontend route inventory

Confirmed live Storage SDK upload routes now include at least:
1. `public/warehouse/warehouse-evidence.html`
2. `app/customer/customs-documents.html`
3. `public/partner/compliance-evidence.html`
4. `app/partner/vehicle-registry.html`

Confirmed signed-preview routes include:
- `app/admin/vehicle-verification.html`
- `app/platform-admin/delivery-pod-verification.html`
- `public/shipper/epod-vault.html`
- `public/warehouse/warehouse-evidence.html`
- `app/customer/customs-documents.html`

Other sampled routes are static guidance, redirects, or backend-only review pages rather than direct upload/download implementations. This inventory remains **minimum known coverage**, not a complete repository-wide scan.

## Findings requiring closure

1. **Vehicle metadata binding:** Registration function should verify Storage metadata MIME and byte size against supplied values, not trust client parameters.
2. **Driver upload route gap:** Locate the actual driver verification document submission UI or establish that onboarding currently has no live upload page.
3. **Staging separation:** The vehicle registry page's local-preview branch is gated by an exact hostname check for `krim-staging.pages.dev`; the QA shared environment resolver uses a broader host allowlist. Verify actual deployment hostnames and ensure no Staging host can fall through to live mode.
4. **Storage policy composition:** Reconcile all applicable permissive policies for `krim-partner-verification` and `krim-driver-verification`; policies OR together. Keep the previously found Staging partner-verification permissive-policy bypass as a blocker until proven corrected.
5. **Runtime tests:** After approved isolated Staging test sink and synthetic tenant setup, test upload ownership, cross-org access denial, metadata mismatch rejection, cleanup, AAL2 reviewer preview and membership revocation.

## Safety boundary

No files were uploaded, downloaded, listed or deleted. No signed URLs or RPCs were invoked. No database, Storage, Auth, policy, secret or deployment settings were changed. This is a report-only commit on the QA branch; no merge or deployment.
