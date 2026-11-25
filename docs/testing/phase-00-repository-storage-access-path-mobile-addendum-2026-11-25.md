# Phase 00 — Repository Storage access-path inventory addendum
Date: 2026-11-25
Branch: qa/phase-00-baseline-2026-11-25
Scope: Follow-up source inspection after the bounded repository inventory and expansion reports. Read-only Git tree enumeration plus targeted source fetches. No app code, database, Storage objects, credentials, runtime sessions, or deployment were changed.

## Result
**NOT PASS — additional first-party mobile evidence upload path confirmed.** The repository has multiple direct browser/client Storage SDK integrations. This remains a source inventory, not runtime proof and not an exhaustive all-blob content scan.

## Additional confirmed access path

### Native KRIM Driver evidence upload
File: `mobile/krim-driver/src/DriverWorkspace.tsx`
- Uploads delivery evidence directly from the authenticated mobile client to private bucket `krim-driver-evidence`.
- Object path is `user_id/assignment_id/timestamp-index.extension`; upload sets the browser-derived content type and `upsert:false`.
- Builds evidence metadata rows binding assignment, driver user, recipient name, storage path, original filename, content type and byte size.
- Tracks uploaded paths and attempts Storage object removal if evidence registration does not complete.
- Source lines: 92–93, 110–122 (line references are in the QA-branch file).
- This path needs the same two-tenant / assigned-driver negative tests as the web POD flow, plus checks for partial upload cleanup failure, retry/idempotency, MIME spoofing and exact assignment binding.
- No upload or cleanup was executed.

## Consolidated direct Storage SDK paths confirmed in this review set

### Upload producers
1. `public/warehouse/warehouse-evidence.html` — `krim-warehouse-evidence`; task/org/user path; then `krim_warehouse_register_evidence`; attempts object cleanup if registration fails.
2. `app/customer/customs-documents.html` — `krim-partner-verification`; shipment/org/user path; then `krim_customs_document_submit`.
3. `public/partner/compliance-evidence.html` — `krim-partner-verification`; registered-business partner evidence upload; registration via compliance evidence RPC; orphan evidence is explicitly possible when registration fails.
4. `mobile/krim-driver/src/DriverWorkspace.tsx` — `krim-driver-evidence`; driver/assignment path; metadata registration follows upload; attempts cleanup on registration failure.

### Browser signed-link issuers (60-second expiry in inspected handlers)
1. `public/warehouse/warehouse-evidence.html` — `krim-warehouse-evidence`.
2. `app/customer/customs-documents.html` — `krim-partner-verification`.
3. `app/admin/vehicle-verification.html` — `krim-partner-verification`.
4. `public/shipper/epod-vault.html` — `krim-driver-evidence`.
5. `app/platform-admin/partner-verification.html` — `krim-partner-verification`.
6. `app/platform-admin/driver-verification.html` — `krim-driver-verification`.
7. `app/platform-admin/delivery-pod-verification.html` — `krim-driver-evidence`.
8. `app/platform-admin/claims-review.html` — `krim-partner-verification`.

These are direct client-side signed URL issuers. A 60-second expiry limits exposure duration but does not itself provide download audit, immediate revocation, or fresh authorization at every preview action. Effective Storage SELECT policy remains the security boundary.

## Other relevant findings carried forward
- `app/enterprise/documents.html` is metadata/read-only in the inspected implementation; it is not a proven general-purpose upload/download vault.
- `public/app/document-vault.html` is a presentation/prototype surface; its preview affordance is not evidence of a live secure document service.
- Retired POD/document redirects should not be counted as independent upload implementations.
- Earlier Staging review found an overly broad AAL2-only INSERT policy composition on `krim-partner-verification`; Staging remains unsuitable for sensitive uploads until fixed.
- Earlier bucket review found `pod-documents` without bucket-level MIME/size limits; its active workflow remains unproven.
- Existing reports identify no proven central signed-link broker, download audit event, malware/quarantine pipeline, or robust orphan-object reconciliation workflow in the sampled paths.

## Coverage and limitations
- Current QA branch Git tree response was `truncated=false`, with 2,466 tree entries.
- The tree inventory identified 1,506 candidate first-party HTML/JS/TS/TSX/SQL source files under the filter used in this pass (generated/vendor/minified paths excluded). Path-based narrowing identified 537 likely relevant files, but the connector call limit prevented fetching and content-scanning all of them in one pass.
- This addendum inspects the four upload producers and eight signed-link issuer handlers listed above, plus selected mobile and document-vault surfaces. It does not assert that these are every Storage operation in the repository.
- GitHub code search returned incomplete/empty results for this non-default QA branch and is not accepted as proof of absence.
- No edge function was executed; this pass does not certify the absence of server-side upload/download endpoints.
- No file bytes, object listings, signed URLs, browser network traces, Storage audit logs, or runtime tenant sessions were inspected.
- Source findings apply to the QA branch, not necessarily the deployed GitHub Pages build or live Supabase projects.

## Required next verification
1. Complete a deterministic content scan of every first-party source blob (prefer a local checkout/archive or a paginated blob fetch strategy that avoids connector per-call limits).
2. Trace the exact mobile driver evidence registration RPC and its Storage INSERT/DELETE policies, including the failure cleanup branch.
3. Establish a controlled Staging test sink and synthetic two-tenant accounts before any upload, signed-link, delete, or negative-authorization runtime tests.
4. Test each upload/preview path for owner, organization, assignment, AAL2, file signature, size/MIME, expiry, revocation, audit and orphan cleanup.
5. Do not enable real customer document exchange until these checks pass.

## Disposition
Inventory addendum only. No code, database, Storage policy, object, secret, auth user, payment, provider, or deployment changes. **No runtime test passed; no evidence = no pass.**
