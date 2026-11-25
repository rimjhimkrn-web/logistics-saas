# Phase 00 — Document Upload, Download and Evidence Storage Source Audit
Date: 2026-11-25  
Branch: `qa/phase-00-baseline-2026-11-25`  
Scope: source-level review of representative partner, warehouse, customs, enterprise, customer ePOD/POD and generic document routes. No file upload, signed URL generation, RPC execution, database write or provider operation was performed.

## Executive result

**PARTIALLY MAPPED.** The repository contains two meaningful authenticated evidence-upload implementations in the sampled pages (Partner Compliance Evidence and Warehouse Evidence). Several other pages are intentionally read-only previews or static informational shells. Enterprise document metadata is organization-scoped and explicitly disables file operations. Customs documentation is explicitly a non-connected preview. Customer POD capture is explicitly read-only. The customer ePOD vault sampled page is a static shell, not a connected secure vault implementation.

This distinction is critical: a page named “vault”, “upload” or “documents” must not be treated as a functioning secure file service.

## 1. Route-by-route findings

| Route | Observed source behavior | Backend/storage wiring | Assessment |
|---|---|---|---|
| `public/partner/compliance-evidence.html` | Authenticated user; resolves active organization membership; supports file selection and compliance evidence submission. A special Staging preview path uses illustrative organization data and sends no file. | Private bucket `krim-partner-verification`; uploads objects under `<org-id>/<user-id>/compliance-<code>-<uuid>.<ext>`; RPC `krim_partner_submit_compliance_evidence`. | Real source wiring outside the preview path. Browser checks max 10 MB and PDF/JPEG/PNG MIME. No byte-signature inspection visible in this page trace. No object cleanup call found in the sampled submit flow; failed metadata registration may leave an orphan object. |
| `public/warehouse/warehouse-evidence.html` | Requires a session; lists warehouse tasks and evidence; uploads file and registers it against selected task. | Private bucket `krim-warehouse-evidence`; RPCs `krim_warehouse_list_tasks`, `krim_warehouse_list_evidence`, `krim_warehouse_register_evidence`; signed preview generated with `createSignedUrl(path, 60)`. | Real source wiring. Browser checks max 10 MB and JPEG/PNG/PDF. Uses path prefix `<organization-id>/<user-id>/...`. On registration failure, attempts to remove the uploaded object and reports cleanup failure. |
| `app/enterprise/documents.html` | Authenticated Enterprise membership; reads document metadata, verification records and shipment document requirements. | Direct reads of `krim_organization_members`, `krim_document_records`, `krim_document_types`, `krim_document_verifications`, `krim_shipment_document_requirements`. | Explicitly metadata-first and read-only. Source notice says no upload, download, preview, signing or verification action is exposed because a general Enterprise document-storage access policy has not been verified. |
| `app/customs/workflows/documents.html` | Static protected-workflow preview; empty records; no upload or authority submission. | No Supabase table, RPC, Edge Function or Storage call found in inspected page source. | NOT A LIVE CUSTOMS DOCUMENT WORKFLOW. Page explicitly says live records are not connected and no declarations, licence checks or authority communication are performed. |
| `public/customer-os/customer-services/epod-vault.html` | Static customer-facing shell/navigation in inspected source. | No Supabase client, Storage bucket, signed URL, RPC or table call found. | NOT A CONNECTED ePOD VAULT in this sampled page. Do not promise customer document retrieval based on this route alone. |
| `public/customer-os/customer-services/pod-capture.html` | Informational read-only preview. | No camera, signature, upload or persistent write action; no backend/storage calls found. | Explicitly not a driver POD capture flow. Customer users are told they do not create or self-verify driver POD. |
| `public/documents/document-upload.html` | Generic upload/vault-ingestion page shell. | No direct backend/storage integration found in inspected source. | NOT VERIFIED as an upload service. |
| `public/documents/document-download.html` | Generic download/export page shell. | No direct backend/storage integration found in inspected source. | NOT VERIFIED as a secure download service. |
| `public/partner/document-upload.html`, `public/driver/photo-proof.html` | Very small placeholder/redirect-sized HTML sources. | No direct backend/storage integration found. | Treat as aliases/placeholders until canonical destination is verified. |

## 2. Positive implementation controls observed

### Partner compliance evidence
- Session and active organization membership are resolved before submission.
- Organization must be one of the current user's active memberships.
- Object key includes organization and user identifiers and a random UUID.
- Upload uses `upsert:false`.
- Browser enforces a 10 MB maximum and an allowlist of PDF, JPEG and PNG MIME types.
- Metadata registration is delegated to `krim_partner_submit_compliance_evidence`.
- Staging preview explicitly avoids backend access and transmission.

### Warehouse evidence
- Session is required; unauthenticated users are redirected to warehouse login.
- Evidence list is loaded through a dedicated RPC.
- File upload uses a private bucket and an organization/user-prefixed object path.
- Upload uses `upsert:false`.
- Registration is delegated to `krim_warehouse_register_evidence`.
- Signed preview is short-lived (60 seconds).
- If registration fails after upload, the page attempts object deletion and surfaces cleanup failure.

## 3. Security gaps and launch risks to preserve

1. **MIME checks are not file-signature validation.** Browser `file.type` can be spoofed. Server-side byte signature/content inspection, malware scanning or quarantine, and safe PDF/image processing are not demonstrated by these page sources.
2. **Partner orphan cleanup is not demonstrated.** The source uploads multiple evidence objects and then registers metadata via RPC. No compensating `storage.remove` call was found in the inspected submission flow. A failed RPC may leave an unregistered object; confirm and repair with an idempotent cleanup mechanism.
3. **Warehouse cleanup is best-effort only.** The page attempts removal, but a failed cleanup is surfaced for administrator review. Add a durable orphan reconciliation job and audit event; do not rely only on browser cleanup.
4. **Signed URL authorization is not fully proven.** Warehouse page requests a 60-second signed URL after retrieving evidence rows, but we have not tested whether the server validates task membership, organization scope and caller permissions on every request. Signed URL revocation and download audit are not demonstrated.
5. **Storage bucket policy must be inspected independently.** Prior Phase 00 reports recorded a Staging `krim-partner-verification` INSERT policy risk and five private Production buckets. Browser path conventions are not a substitute for RLS/storage policy tests.
6. **Enterprise documents are intentionally withheld.** Do not enable upload/download until a dedicated organization-scoped document access policy, signed-link broker, and audit trail are implemented and tested.
7. **Customs and ePOD pages are previews/static shells.** Do not treat these pages as live operational capabilities or customer deliverables.
8. **No file malware quarantine or file scanning evidence** was identified in the inspected routes.
9. **No runtime tests were executed.** No synthetic upload, malicious file, cross-tenant path attempt, signed URL expiry, replay, revocation or unauthorized download was tested.

## 4. Required controlled tests before release

Use only an approved isolated Staging environment with synthetic identities, synthetic organizations and synthetic files. First prove Staging deployment origin, schema and ACL readiness; do not run these tests against Production.

| Test ID | Test | Expected evidence |
|---|---|---|
| DOC-01 | Valid PDF/JPEG/PNG within limit | Upload accepted; server-side file inspection; metadata row references exact object and tenant |
| DOC-02 | Zero-byte, >10 MB, spoofed MIME, wrong extension, malformed PDF/image | Rejected server-side; no durable object or orphan |
| DOC-03 | User A attempts to upload under Organization B path | Denied by Storage policy and server-side registration |
| DOC-04 | User A attempts to list/download Organization B evidence | Denied; no signed URL issued |
| DOC-05 | Upload succeeds, metadata RPC fails | Object removed or durable orphan task created; audit record retained |
| DOC-06 | Metadata registration succeeds, browser closes/retries | Idempotent outcome; no duplicate evidence records |
| DOC-07 | Signed URL after expiry / replay / copied URL by unauthorized user | Expired or denied as designed; issuance/download logged |
| DOC-08 | Remove/revoke evidence and retry old signed URL | Access behavior documented and proven; revocation limitation explicit |
| DOC-09 | Malware test file in isolated scanner | Quarantined/rejected; never served to users |
| DOC-10 | Cross-workspace role and cross-organization tests | Least-privilege enforcement across customer, partner, driver, warehouse, customs, finance, enterprise and admin |

Capture request/response traces, synthetic object paths, before/after DB rows, Storage policy decisions, audit records and cleanup results. No actual customer or partner documents.

## 5. Disposition

| Item | Status |
|---|---|
| Partner evidence source wiring | PASS (source inspection only) |
| Warehouse evidence source wiring | PASS (source inspection only) |
| Partner file validation and orphan handling | INCOMPLETE |
| Warehouse file validation and cleanup | PARTIAL |
| Enterprise document access | INTENTIONALLY WITHHELD |
| Customs document workflow | PREVIEW / NOT CONNECTED |
| Customer ePOD vault | NOT CONNECTED in sampled route |
| Customer POD capture | READ-ONLY PREVIEW |
| Signed URL scope, expiry and revocation runtime tests | NOT TESTED |
| Storage RLS cross-tenant tests | NOT TESTED |
| Malware scanning / quarantine | NOT VERIFIED |
| End-to-end upload/download journey | NOT TESTED |

**Release decision:** no general document vault or cross-workspace upload/download capability should be advertised as operational from this evidence. Partner compliance and warehouse evidence are the only two sampled routes with clear authenticated upload + metadata registration wiring. Keep all sensitive file operations behind existing gates until server-side validation, storage policy isolation, orphan cleanup and signed-link authorization have reproducible Staging evidence.

## Evidence boundary

This report is based on QA-branch source inspection and previously recorded Phase 00 Storage/security audits. It is not a live penetration test or an independent database-policy re-read. No uploads, downloads, signed URLs, RPCs, database writes, Production/Staging configuration changes, deployments or merges occurred.
