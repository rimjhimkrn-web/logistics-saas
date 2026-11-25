# Phase 00 — Repository Storage access-path expansion audit
Date: 2026-11-25
Branch: qa/phase-00-baseline-2026-11-25
Scope: QA-branch Git tree inventory (1,512 first-party HTML/JS/TS/SQL files excluding node_modules), targeted source inspection of partner compliance evidence, driver POD, admin POD/partner/driver/vehicle review, claims, warehouse, customs, enterprise documents, customer ePOD, and selected mobile repositories. No file upload/download, signed URL minting, browser session, database mutation, or deployment was performed.

## Executive result
**NOT PASS — expanded inventory found additional document access paths.** The previous report's four sampled signed-link pages were not the complete set. Additional admin review pages issue 60-second signed URLs, and the partner compliance workflow directly uploads private evidence. A truly exhaustive all-file content scan was not completed: the Git tree lists 1,512 first-party source files, but the connector's per-file fetch limit prevented fetching all files in one pass; GitHub code-search returned incomplete/empty results. Findings below are source-confirmed paths, not a claim that every repository occurrence has been found.

## Additional source-confirmed access paths

### 1. Partner compliance evidence upload
File: `public/partner/compliance-evidence.html`
- Direct browser upload to private `krim-partner-verification`.
- Upload uses `upsert:false`, cacheControl 3600 and the browser-declared `file.type`.
- If an upload succeeds but a later upload/registration step fails, the page explicitly warns that partial private evidence files may remain because the current Storage policy does not authorize applicant deletion.
- This creates an orphan-object/retention and support-recovery concern. Need a controlled server-side cleanup/expiry process or a safe, narrowly scoped applicant cleanup policy; do not grant broad delete access.
- The source snippet confirms the upload call but this bounded review did not validate the full upload path construction or the exact backend registration RPC for every evidence category.

### 2. Platform admin delivery POD preview
File: `app/platform-admin/delivery-pod-verification.html`
- Opens evidence from `krim-driver-evidence` using `createSignedUrl(path, 60)`.
- Page requires an admin gate and states AAL2/platform-admin checks for listing and decision requests.
- The preview handler itself relies on the previously loaded queue row and Storage SELECT RLS; no independent AAL2 re-check immediately before link creation is evident in the inspected handler.
- No download-audit event was identified in the inspected preview handler.

### 3. Platform admin partner verification preview
File: `app/platform-admin/partner-verification.html`
- Creates 60-second signed URLs from `krim-partner-verification`.
- Source displays a staging-preview state that explicitly does not load private evidence; the operational branch has a separate preview function.
- Preview issuance relies on the current browser session and Storage SELECT policy. No server-side download broker or explicit download-audit RPC was identified in the inspected handler.

### 4. Platform admin driver verification preview
File: `app/platform-admin/driver-verification.html`
- Creates 60-second signed URLs from `krim-driver-verification`.
- Queue data comes from `krim_admin_list_driver_verification_with_expiry`; decisions use a separate review RPC.
- The inspected preview function creates the signed link client-side. No separate download-audit event or per-preview server-side authorization check was identified in that function.

### 5. Platform admin claims evidence preview
File: `app/platform-admin/claims-review.html`
- Creates 60-second signed URLs from `krim-partner-verification` for evidence path values.
- Claim queue and evidence metadata are loaded through authenticated database queries.
- The inspected click handler does not show a separate server-side signed-link broker or access-audit RPC before creating the URL. Effective Storage SELECT RLS remains critical.

### 6. Existing vehicle verification preview
File: `app/admin/vehicle-verification.html`
- Previously identified: creates 60-second signed URLs from `krim-partner-verification`.
- The inspected page has separate review actions; preview authorization is not independently re-evaluated by a server-side broker in the handler.

### 7. Warehouse evidence upload and preview
File: `public/warehouse/warehouse-evidence.html`
- Previously identified: direct browser upload to `krim-warehouse-evidence`, then metadata registration RPC; 60-second signed preview.
- Client MIME/size validation is not byte-level validation. Cleanup after failed registration is attempted but can fail.

### 8. Customs shipment documents
File: `app/customer/customs-documents.html`
- Previously identified: direct browser upload to `krim-partner-verification`, then `krim_customs_document_submit`; 60-second signed preview.

### 9. Customer ePOD vault
File: `public/shipper/epod-vault.html`
- Previously identified: browser creates a 60-second signed URL only after UI filters require verified POD state and verification metadata.
- These UI conditions are not a substitute for Storage SELECT policy; a direct Storage API call bypasses the UI.

### 10. Driver POD submission remains paused
File: `app/driver/module-10-proof-of-delivery.html`
- Explicitly states POD submission is paused and that the page will not upload evidence, create evidence records or submit delivery confirmation.
- Do not interpret the presence of POD-related RPCs or legacy upload pages as an active driver POD submission path.

### 11. Enterprise document workspace is metadata-only
File: `app/enterprise/documents.html`
- Explicitly read-only; loads organization-scoped document metadata and shipment document requirements.
- Does not expose upload, download, preview, signing or verification action because a general Enterprise storage policy has not been verified.
- This is a safe fail-closed limitation, not a missing permission to work around.

### 12. Legacy and customer-facing pages
- `public/partner/document-upload.html`, `public/partner/pod-upload.html`, `public/driver/pod-submission.html`, `public/customer/pod-capture.html` and `public/customer/pod-download.html` are small redirect/guidance pages in the inspected source; they are not independent live Storage SDK implementations.
- `public/customer-os/customer-services/pod-capture.html` and `public/customer-os/shipper-services/epod-vault.html` are guidance/presentation pages, not live file operations.

### 13. Mobile repositories — sampled repository modules
- `mobile/krim-driver/src/lib/driverRepository.ts` reads driver delivery evidence metadata rows but the inspected module contains no Storage upload/download call.
- `mobile/krim-partner/src/lib/partnerRepository.ts` and `mobile/krim-customer/src/lib/customerRepository.ts` were inspected for Storage SDK calls; no `.storage` upload/download call was found in those sampled repository modules.
- This does not prove the entire mobile applications or future screens have no other Storage access paths.

## Consolidated source-level access-path map
| Workflow | Bucket | Operation | Source-confirmed behavior |
|---|---|---|---|
| Partner compliance | `krim-partner-verification` | Upload | Browser direct upload; partial objects can remain |
| Customs documents | `krim-partner-verification` | Upload + preview | RPC registration; 60s signed preview |
| Vehicle review | `krim-partner-verification` | Preview | 60s signed URL |
| Partner verification review | `krim-partner-verification` | Preview | 60s signed URL |
| Claims review | `krim-partner-verification` | Preview | 60s signed URL |
| Driver verification review | `krim-driver-verification` | Preview | 60s signed URL |
| Driver POD admin review | `krim-driver-evidence` | Preview | 60s signed URL |
| Warehouse evidence | `krim-warehouse-evidence` | Upload + preview | Direct upload + registration RPC; 60s preview |
| Customer verified ePOD | `krim-driver-evidence` | Preview | UI filters verified POD; 60s signed URL |
| Driver POD submission | `krim-driver-evidence` | Upload | Explicitly paused in inspected page |
| Enterprise documents | No file bucket call | Metadata only | Read-only; no file action |

## Cross-cutting risks
1. Signed URL creation is performed in browser code on multiple admin and workspace pages, not through one centrally auditable server-side download broker.
2. A 60-second expiry limits exposure but does not guarantee immediate invalidation when user membership/role/assignment is revoked after issuance.
3. The partner compliance page can leave orphaned uploads when the process fails partway through; no safe cleanup mechanism is proven.
4. Browser-declared MIME type and client size checks can be bypassed; byte-signature validation and malware scanning/quarantine are not proven.
5. Admin pages often separate queue authorization and signed URL creation; source-level UI gate does not replace object-level RLS or a fresh server-side authorization check.
6. No signed-link issuance audit trail, per-document download event, or token redaction behavior was established by this inspection.
7. The generic document-suite and Enterprise document UI should not be represented as complete upload/download vaults.

## Required next actions before real document onboarding
1. Fix the Staging partner-verification permissive AAL2 INSERT policy defect identified in the preceding Storage audit; then test the effective policy with synthetic tenants.
2. Create a complete, machine-assisted source inventory/CI scanner that searches all first-party HTML/JS/TS plus mobile source for Storage SDK methods, raw Storage REST URLs, public URL creation and signed URL handlers. Fail CI when new unreviewed storage paths are added.
3. Centralize sensitive download link issuance in a narrowly scoped Edge Function or equivalent server-side broker: authenticate, re-check current org membership, role/permission, shipment/assignment, evidence verification state and AAL2 as applicable; emit an access audit event; return a minimal short-lived URL.
4. Ensure browser pages never render signed URL tokens in status text, logs, analytics, referrers or persistent storage.
5. Add a server-managed orphan upload cleanup queue with age limit, metadata checks and audit trail; do not broaden user delete privileges.
6. Verify Storage policies independently for direct API access, cross-tenant denial, role revocation and verified-POD-only access.
7. Add byte-signature/content sniffing, malware scanning/quarantine, and strict upload limits to all buckets, including the POD bucket if it is ever reactivated.
8. Build isolated Staging tests for all workflows before opening upload/download access to partners, drivers, warehouses, customs brokers or customers.

## Evidence limitations
- Tree inventory: 1,512 first-party source files excluding node_modules, and 320 paths with document/evidence/upload/download/POD/verification/warehouse/customs/vehicle-related names.
- Connector per-file fetch limit prevented fetching and scanning every first-party source file in a single pass. GitHub code-search endpoint returned incomplete/empty results and is not treated as proof of absence.
- Source inspection only; no authenticated browser, object listing, file upload, file download, signed URL minting, or Storage RPC invocation.
- No actual Storage signing-key rotation or revocation test. Supabase documentation states individual signed URLs cannot be revoked; underlying object deletion/move/rename or URL-signing-key rotation are the documented invalidation options. CDN-cached content may remain available until cache purge.
- No claim that QA branch source is deployed to the live GitHub Pages production site.

## Change record
No Production or Staging database, Storage, Auth, function, secret, code, or deployment changes. Report committed only to the QA branch.
