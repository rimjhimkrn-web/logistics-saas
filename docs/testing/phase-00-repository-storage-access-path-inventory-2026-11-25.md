# Phase 00 — Repository-wide Storage access-path inventory (bounded source scan)
Date: 2026-11-25
Branch reviewed: qa/phase-00-baseline-2026-11-25
Scope: Enumerated complete Git tree; filtered source-file inventory by file type and path; inspected targeted upload/download and evidence workflows. This is a bounded scan, NOT a full-content scan of every source file. GitHub code-search indexing did not return searchable matches for the QA branch, so it could not substitute for scanning all source blobs. No repository code was changed.

## Inventory coverage and limits
- Git tree API returned `truncated=false`, with 2,255 blob entries.
- 1,218 source files were identified across HTML, JS/MJS, TS/TSX/JSX (1,023 HTML, 143 JS/MJS, 52 TS/TSX/JSX).
- 409 source files had path names associated with documents, evidence, POD, warehouse, customs, partner, driver, vehicle, shipment, storage, upload, download or vault.
- Targeted source review covered canonical and secondary upload/download surfaces across warehouse, customs, partner compliance, partner verification, driver verification, delivery-POD verification, vehicle review and customer ePOD.
- A content-level scan of all 1,218 source files was not completed. GitHub's code-search tool returned zero matches for the QA branch queries; the REST code-search endpoint indexes only the default branch, so it cannot establish completeness for this non-default QA branch.
- This report therefore records discovered paths and risks but does not claim that every source file or every indirect SDK wrapper was content-scanned.

## Newly identified access paths

### A. Partner compliance evidence upload — additional live upload producer
Source: `public/partner/compliance-evidence.html`
- Authenticated partner workspace resolves an eligible registered-business organization; development/test and individual-interest pathways are excluded from commercial compliance submission.
- Client enforces file size 1 byte–10 MiB and MIME PDF/JPEG/PNG.
- Uploads directly to private `krim-partner-verification` using path `organization_id/user_id/compliance-code-UUID.ext`, `upsert:false`, and contentType.
- Registers four evidence categories through `krim_partner_submit_compliance_evidence`; frontend expects a submitted state while commercial activation remains false pending review.
- **Partial-upload orphan risk:** if upload succeeds but the registration RPC fails, the UI explicitly says it cannot automatically delete partial private evidence because the current Storage policy does not authorize applicant deletion. Uploaded objects may remain unregistered and need support reconciliation. This is a known, acknowledged failure mode rather than silent success.
- Retry behavior is intentionally blocked when the RPC outcome is ambiguous; the user is told not to retry until KRIM checks the register. This is safer than duplicate submission but needs an operational reconciliation queue.

### B. Platform-admin partner verification preview
Source: `app/platform-admin/partner-verification.html`
- Requires an admin verification gate and MFA/AAL2 before loading the queue.
- Reads document paths from organization metadata and validates that paths start with the case organization ID and match a PDF/PNG/JPEG extension before presenting preview controls.
- Creates a 60-second signed URL directly from `krim-partner-verification` in the browser, then opens it in a new tab with `opener=null`.
- The path-prefix check is useful UI defense, but Storage SELECT policy remains the actual object-access boundary.
- Preview is a bearer signed link. No per-download audit event or immediate revocation guarantee is shown in this page.

### C. Platform-admin driver verification preview
Source: `app/platform-admin/driver-verification.html`
- Loads the review queue through `krim_admin_list_driver_verification_with_expiry`.
- Creates 60-second signed URLs from `krim-driver-verification` directly in the browser.
- Review decisions are separate database RPCs.
- The page's visible copy says privileged review; this source sample did not show a fresh explicit AAL2 check inside the preview handler itself. The database Storage SELECT policy and initial auth gate must enforce this; runtime behavior remains unverified.

### D. Platform-admin delivery POD verification preview
Source: `app/platform-admin/delivery-pod-verification.html`
- Performs an MFA gate before loading the queue and says list/decision RPCs require AAL2 and platform administrator permission.
- Creates 60-second signed URLs from `krim-driver-evidence` in the browser.
- Decisions use a separate review RPC.
- This is another direct signed-URL issuer and should be included in the full signed-link and audit-event inventory.

### E. Partner POD legacy routes
Sources: `public/partner/pod-submission.html`, `public/partner/pod-upload.html`
- Both are retired redirects to the authenticated partner document/delivery-evidence register; no independent upload logic remains in these legacy pages.
- Driver POD route aliases inspected are retired/empty redirect shells, not separate active upload pipelines.

### F. Warehouse Staging evidence page
Source: `app/warehouse/staging/page-13-warehouse-evidence.html`
- Explicitly locked in the reviewed Staging source: evidence metadata and Storage workflow are not exposed to authenticated warehouse users in that build.
- The page describes intended controls only; do not count it as a working Staging upload path.
- This is consistent with previously observed missing Staging evidence schema/privileges and should remain gated.

### G. Enterprise generic document vault
Source: `public/app/document-vault.html`
- The inspected page contains an upload affordance and preview button but the preview is an alert placeholder; no Storage SDK operation was identified in the reviewed source.
- It is a UI prototype, not proof of a functioning tenant-isolated document vault.

## Consolidated signed URL issuer inventory (discovered)
The following source pages create signed URLs in the browser with a 60-second expiry:
1. `public/warehouse/warehouse-evidence.html` — warehouse evidence preview.
2. `app/customer/customs-documents.html` — customs evidence preview.
3. `app/admin/vehicle-verification.html` — vehicle document preview.
4. `public/shipper/epod-vault.html` — verified customer ePOD preview.
5. `app/platform-admin/partner-verification.html` — partner verification preview.
6. `app/platform-admin/driver-verification.html` — driver verification preview.
7. `app/platform-admin/delivery-pod-verification.html` — delivery POD preview.

The list is the discovered issuer set from inspected sources, not a proven exhaustive set for the entire repository.

## Consolidated upload producer inventory (discovered)
1. `public/warehouse/warehouse-evidence.html` — `krim-warehouse-evidence`, then `krim_warehouse_register_evidence`.
2. `app/customer/customs-documents.html` — `krim-partner-verification`, then `krim_customs_document_submit`.
3. `public/partner/compliance-evidence.html` — `krim-partner-verification`, then `krim_partner_submit_compliance_evidence`.
4. Previously audited driver/vehicle evidence flows include registration/submit RPCs and their own bucket/path restrictions; no new driver direct-upload implementation was confirmed in this bounded follow-up.

## Cross-cutting risks and required controls
1. **Storage RLS is decisive.** Frontend checks, queue filtering and hidden buttons do not protect direct Storage API calls. Effective permissive policies combine with OR.
2. **Signed URLs are bearer capabilities.** Sixty seconds limits the exposure window but does not prove immediate revocation after membership, role or assignment changes.
3. **Download auditability is incomplete.** No universal server-side download broker or common access-event record was identified in the reviewed sources.
4. **Orphaned compliance uploads.** Build a safe reconciliation workflow for successful object upload + failed/ambiguous registration; do not give users broad delete permission merely to simplify cleanup.
5. **AAL2 parity.** Ensure every privileged preview route is protected by database/Storage authorization and not only by a page-level check.
6. **MIME/size.** Client validation is UX only. Keep bucket limits and database metadata checks, then add byte-signature validation and malware quarantine.
7. **POD bucket.** No inspected active path established a complete direct-upload workflow into `pod-documents`; keep it disabled until the intended path and strict bucket controls are documented.
8. **Generic vault prototypes.** Clearly distinguish non-operational UI prototypes from live secure document services.

## Required next verification
- Complete content scan of all 1,218 source files on the QA branch using a local clone or CI scanner with explicit file enumeration and machine-readable results.
- Include inline JS, shared runtime modules, dynamically loaded scripts, Edge Functions, mobile clients, redirect targets and generated bundles.
- Build an issuer matrix recording file, bucket, operation, TTL, authorization gate, object path source, audit event, and failure cleanup behavior.
- Verify every effective Storage policy for each discovered bucket in Production and Staging, including permissive-policy OR composition.
- After Staging policy repair and isolation setup, run synthetic direct API tests for each issuer and tenant boundary.
- Add safe reconciliation for unregistered private objects and audit download issuance/denials without storing signed tokens.

## Change record
Read-only source inspection. No code, database, Storage, Auth, secret, function, provider or deployment changes. This report alone is committed to the QA branch.
