# Phase 00 — Frontend document upload/download and signed-link trace
Date: 2026-11-25
Branch: qa/phase-00-baseline-2026-11-25
Scope: Bounded source inspection of canonical warehouse, customs, vehicle-review and customer ePOD pages, plus document-suite pages and legacy redirects. No browser session, upload, download, signed URL issuance, RPC invocation, or provider operation was performed.

## Executive result
**NOT PASS — access design is partially evidenced, not runtime verified.** Several operational pages upload directly to private Supabase Storage and register metadata through authorization-aware RPCs. Four sampled preview/download surfaces create short-lived 60-second signed URLs in the browser. The source does not establish an auditable server-side download gateway, immediate revocation after membership/role changes, download audit events, or runtime tenant isolation. The standalone document-suite upload/download pages are static presentation pages, not a working secure document pipeline.

## Traced implementations

### 1. Warehouse evidence — operational upload and preview
Source: `public/warehouse/warehouse-evidence.html`
- Requires an authenticated Supabase session; redirects unauthenticated users to warehouse login.
- Loads authorized tasks through `krim_warehouse_list_tasks` and evidence metadata through `krim_warehouse_list_evidence`.
- Client checks file size <= 10 MiB and MIME in JPEG/PNG/PDF.
- Uploads to private `krim-warehouse-evidence` using path `organization_id/user_id/randomized-filename`, `upsert:false`, and declared contentType.
- Calls `krim_warehouse_register_evidence` after upload; database routine verifies task operator access, path structure, object owner, declared MIME metadata and size.
- If registration fails, frontend attempts to remove the unregistered object. Cleanup failure is logged and displayed as requiring administrator review.
- Preview uses `createSignedUrl(path, 60)`, i.e. a 60-second signed URL.
- Popup-block fallback places the signed URL into a visible status message. This can expose the bearer URL to screen capture, copied text, browser extensions or support screenshots. Prefer a controlled same-tab/open flow without rendering the token as text.

### 2. Customs document upload and review preview
Source: `app/customer/customs-documents.html`
- Requires authenticated customer workspace and derives authorized customer organization access from membership/permission queries.
- Client checks <=10 MiB, PDF/JPEG/PNG, and expiry date not before issue date.
- Uploads to `krim-partner-verification` using shipment/org/user-scoped path and `upsert:false`.
- Registers via `krim_customs_document_submit`; backend checks active membership, customer shipment.update or accepted broker assignment + compliance.view, path, object owner and metadata.
- Document preview calls `createSignedUrl(path, 60)` in the browser.
- Review rejection UI separately checks AAL2 before calling the review RPC. The source does not establish whether every preview path is also AAL2-gated; Storage SELECT policy and runtime role behavior remain authoritative and untested.

### 3. Vehicle document review preview
Source: `app/admin/vehicle-verification.html`
- Reviewer queue is loaded through `krim_vehicle_review_queue`.
- Preview calls `createSignedUrl(storage_path, 60)` against `krim-partner-verification`.
- Approve/reject actions call separate RPCs; page text says reviewer cannot review own upload.
- The preview code itself does not perform a fresh explicit AAL2 check immediately before signed URL issuance. Effective access depends on Storage SELECT policy and RPC/role checks. Runtime proof is absent.
- Review source does not establish access-event audit logging for preview/download.

### 4. Customer ePOD vault
Source: `public/shipper/epod-vault.html`
- Loads customer organization memberships, shipments, document records, shipment-document links, POD records, versions and verification records.
- Renders evidence file links only when POD status is `verified`, and both `verified_at` and `verified_by` exist.
- Calls `createSignedUrl(path, 60)` on `krim-driver-evidence` when an authorized user opens a verified file.
- This is a useful presentation-level gate, but it is not a security boundary by itself. A user can call Storage APIs directly; object SELECT policy must independently enforce customer/assigned-org authorization and only verified evidence. That exact effective policy was not proven by this source trace.
- The page does not show a server-side download audit RPC/event before issuing the signed URL.
- A minted signed URL is a bearer capability for its validity period. Membership or role revocation after issuance is not shown to invalidate already minted URLs immediately.

### 5. Partner documents & POD
Source: `public/partner/documents-delivery-evidence.html`
- The inspected page loads document metadata and POD records for the active partner organization and assigned shipments.
- It explicitly says raw storage references and file contents are not exposed in the register.
- It does not expose a download action in the inspected rendering path; no signed URL creation was identified in this page.
- Legacy partner document-upload and POD-upload paths redirect to canonical pages; they are not independent upload implementations.

### 6. Public ePOD vault and guidance pages
Sources: `public/customer-os/customer-services/epod-vault.html`, `public/customer-os/customer-services/pod-download.html`
- These are guidance/recordkeeping pages, not a live file download endpoint.
- The ePOD vault page explicitly says it displays no document, shipment record or download link and describes the intended lifecycle: authenticated user, active membership, shipment authorization, verified POD, short-lived signed access, audit outcomes.
- The download page is explanatory guidance; it does not create signed links or retrieve private objects.
- The guidance requirements should not be mistaken for proof that the actual download path implements every control.

### 7. Generic document-suite upload/download
Sources: `public/documents/document-upload.html`, `public/documents/document-download.html`, `public/documents/document-runtime.js`
- The upload/download HTML pages are static presentation pages; no Supabase Storage upload/download call or signed URL creation was identified.
- The upload page claims encrypted ingestion and automatic SHA-256 fingerprinting, but the sampled page itself does not wire a file input to a storage upload or server-side encryption workflow.
- `document-runtime.js` includes a browser-side SHA-256 helper and a signature-token validation helper, but the inspected source does not establish a complete secure ingestion/download service or a server-verified integrity chain.
- Do not represent these generic pages as a production-ready document vault until they are connected to a real authorized backend workflow.

## Signed-link behavior and risk
1. Four sampled pages create 60-second signed URLs in the browser: warehouse evidence, customs documents, vehicle review, and customer ePOD vault.
2. The browser SDK call uses the user's current session. Storage SELECT policies are therefore a critical enforcement point. UI filtering/hidden buttons do not prevent direct API requests.
3. Signed URLs are bearer tokens. A 60-second TTL limits exposure but does not provide immediate revocation when a user's organization membership, role or shipment assignment is revoked after issuance.
4. No source evidence was found in the sampled pages for a dedicated server-side signed-link broker that re-checks authorization and records a download event before each issuance.
5. No signed-link audit event, access-denied event, token redaction, Referrer-Policy behavior, or cache-control behavior was established by this source-only trace.
6. Warehouse page can print a signed URL into visible page text when popups are blocked; remove this fallback in a future approved fix.
7. Client MIME/size checks improve UX but are bypassable. Server-side bucket limits, object metadata checks and byte-signature/malware validation are required.

## Required next tests/fixes
1. Perform complete repository-wide source search for all Storage SDK calls and Edge Function download handlers; this report is a bounded sample, not exhaustive.
2. Inspect every effective Production and Staging SELECT/INSERT/UPDATE/DELETE policy for all five buckets, including overlap and policy OR composition.
3. Build isolated synthetic identities in Staging only after the Staging policy defect is corrected and test direct Storage API access, not just UI button visibility.
4. Verify that a customer can obtain a link only for independently verified POD belonging to an authorized customer organization; partner/other-tenant users must be denied.
5. Verify admin/vehicle reviewer AAL2 and no-self-review at the database layer, not only in the UI.
6. Verify signed URL TTL, object deletion, membership/assignment revocation, browser history/referrer leakage, caching and logging. Do not claim immediate revocation unless demonstrated.
7. Introduce server-side access event logging and short-lived link issuance if auditability is required. Ensure URLs/tokens are never stored in logs or database records.
8. Remove or redesign the warehouse popup fallback that displays the signed URL.
9. Replace static generic document-suite upload/download pages or clearly label them as non-operational until integrated with a real secure backend.
10. Add content sniffing, malware scanning/quarantine, retention and object lifecycle tests.

## Evidence limitations
- Source inspection only; no browser was authenticated and no signed URL was actually minted.
- No private file was accessed or downloaded.
- No live response headers, Referrer-Policy, Cache-Control or browser history behavior were tested.
- No exhaustive repository-wide search was completed; GitHub code-search returned incomplete/empty results and cannot prove absence.
- Source code does not prove the deployed Pages content matches the QA branch.
- Supabase RLS and runtime authorization behavior remain unverified for cross-tenant cases.

## Change record
No Production or Staging database, Storage, Auth, function, secret, code, or deployment changes. Report committed only to the QA branch.
