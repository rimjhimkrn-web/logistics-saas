# Phase 00 — Signed URL, document-serving and file-validation security audit

Date: 2026-11-25  
Environments: Production and Staging Supabase  
Scope: Read-only review of Storage bucket configuration, object RLS, evidence registration/review RPC source, Storage inventory and deployed Edge Function inventory. No object was uploaded/downloaded, no signed URL was created, no endpoint invoked, and no provider/configuration was changed.

## Executive verdict

**NOT VERIFIED for real-user onboarding.** Private buckets and multiple strong evidence ownership checks are present in Production. Evidence registration RPCs commonly confirm that a private object exists, belongs to the submitting user, and has matching Storage metadata. However, this is metadata validation, not proof that the underlying file bytes match the declared MIME type or are safe. No malware scanning, quarantine/approval gate, signed URL expiry enforcement, or runtime cross-tenant signed-URL tests were evidenced in this pass.

The previously reported Staging partner verification bucket INSERT policy remains a critical issue: its standalone AAL2 policy is permissive and bypasses the intended organization/path predicate.

## Evidence reviewed

- Production bucket configuration: five private buckets. Four evidence buckets have 10 MB limits and MIME allowlists; legacy `pod-documents` has no size/MIME restrictions.
- Staging bucket configuration: only private `krim-partner-verification`, 10 MB, PDF/JPEG/PNG.
- `storage.objects` RLS is enabled (not FORCE RLS) in both environments.
- Storage object inventory query returned no rows in either environment.
- Production and Staging Edge Function inventories were reviewed. No dedicated document malware scanner, file-processing/quarantine or signed-URL broker Edge Function was identified in the inventory. Staging only has `global-admin-control`, `krim-resend-email-worker` and `owner-testing-authorize` at this checkpoint.
- Relevant Production database function source inspected: claim evidence, customs broker license/document submission and review, driver document review, vehicle document register/review, warehouse evidence register/review and delivery POD review.

## Positive controls observed

1. **Private-by-default buckets.** All five Production buckets and the one Staging bucket are configured with `public=false`.
2. **Uploader ownership checks.** Multiple evidence registration/review functions require the uploaded object to exist in the expected bucket and match the original uploader/owner.
3. **Path binding.** Claims, customs, driver, vehicle and warehouse evidence functions validate paths against claim/shipment/organization/user/profile/vehicle/task context.
4. **Metadata consistency.** Several RPCs compare Storage `metadata.mimetype` and `metadata.size` to the metadata submitted to the database.
5. **Independent review.** Customs broker license, driver and vehicle document review source includes submitter/reviewer separation; warehouse quality review requires independently uploaded inspection evidence.
6. **Size/type metadata bounds.** Multiple registration functions enforce 1 byte–10 MB and PDF/JPEG/PNG allowlists. Bucket configuration provides another layer for the configured buckets.

## Findings and risks

### 1. No file-byte signature validation evidenced — HIGH

The inspected RPCs validate client-supplied MIME metadata and Storage metadata. These values do not establish that the file's actual bytes are a valid PDF/JPEG/PNG. A malicious or malformed file may carry a spoofed content type. No file magic-byte validation, parser hardening, image re-encoding, PDF sanitization or malware scanning/quarantine workflow was evidenced in the inspected source/inventory.

**Required:** validate actual file signatures server-side; process risky formats in an isolated scanner; keep uploads quarantined until clean; reject mismatches and oversized/decompression-bomb inputs; record scan engine/version/result and immutable object hash.

### 2. No malware scanning/quarantine evidence — HIGH

No dedicated scanning function or quarantine bucket/state was identified in the deployed Edge Function inventory. This does not prove that no external scanner exists, but there is no evidence of one in the reviewed Supabase deployment. Sensitive business registration, tax, identity, vehicle, customs and POD evidence should not be made available to reviewers before a scan verdict.

### 3. Signed URL lifecycle not proven — HIGH

No end-to-end test established:
- whether the app uses signed URLs or authenticated downloads for each document class;
- which user/role can mint a signed URL;
- whether the URL is scoped to one exact object and bucket;
- whether expiry is short and appropriate;
- whether a URL remains usable after membership revocation, evidence deletion or account suspension;
- whether URLs are excluded from logs, analytics, browser storage and notifications.

A signed URL is a bearer credential. Once minted, access generally persists until expiry even if the caller's membership changes; therefore short TTLs and careful issuance are essential. Do not treat private bucket status alone as proof of secure document delivery.

### 4. Staging partner bucket upload policy is critically overbroad

As documented in the preceding Storage audit, the standalone `krim_partner_verification_upload_require_aal2` INSERT policy checks only bucket ID and AAL2. Because permissive policies OR together, it independently bypasses the organization/user/path predicate. Do not perform Staging upload or signed URL tests until a reviewed Staging-only correction is approved and verified.

### 5. Storage environment parity is incomplete

Production has driver evidence, driver verification, partner verification, warehouse evidence and POD buckets. Staging only has partner verification. Driver, warehouse, customs and POD document journeys cannot be fully exercised in Staging at present.

### 6. Legacy POD bucket has no limits

Production `pod-documents` has no configured size limit or MIME allowlist. Confirm whether it is unused. If any workflow still uses it, define a strict upload contract and policy before release; do not change/delete it until dependencies are mapped.

### 7. No object inventory or lifecycle evidence

Storage object inventory returned zero rows in both environments. Therefore retention, deletion, replacement/upsert, orphan cleanup, legal hold, object versioning, signed URL expiry and evidence recovery are not empirically demonstrated.

### 8. Review RPCs trust stored metadata as evidence metadata

This is useful integrity checking between the DB record and Storage object row, but it does not establish actual byte safety, trusted timestamps, document authenticity or external issuer validity. Human/independent verification and provenance remain necessary for business licences, insurance and regulated documents.

## Required remediation and verification gates

1. Fix the Staging partner upload policy so AAL2 is an additional predicate within the same tenant/uploader/path policy, not a separate permissive allow rule.
2. Add a server-side upload finalization pipeline: private quarantine → byte-signature and size checks → malware scan → safe processing → immutable clean object → evidence registration.
3. Define per-bucket MIME, size, path, owner and retention standards; resolve `pod-documents` legacy usage.
4. Inventory all client calls to `createSignedUrl`, `createSignedUrls`, `download` and any Edge Function issuing signed URLs; ensure each issuance performs current user, organization, role, evidence-record and status checks.
5. Use short-lived URLs, avoid URL logging, do not persist them in local/session storage, and re-authorize every new issuance.
6. After approved Staging remediation and synthetic fixture setup, test cross-tenant access denial, AAL1/AAL2 boundaries, expired URL rejection, URL behavior after membership revocation, deleted-object behavior, wrong MIME/signature, oversized file, duplicate/replacement, and scanner failure/quarantine.
7. Use only synthetic non-sensitive documents during QA. Never upload real identity or tax records into a test sink.

## Release decision

- Private bucket flags: **PASS (catalog-observed only)**.
- Evidence uploader ownership/path checks: **PARTIAL PASS (source-observed only)**.
- Database/Storage metadata consistency: **PARTIAL PASS (source-observed only)**.
- Actual byte signature validation: **NOT EVIDENCED**.
- Malware scanning/quarantine: **NOT EVIDENCED**.
- Signed URL issuance/expiry/revocation: **NOT VERIFIED**.
- Staging upload isolation: **FAIL — critical policy issue remains**.
- Runtime cross-tenant document access: **NOT TESTED**.
- Real document onboarding: **NOT APPROVED**.

No Production or Staging data, policies, buckets, functions or secrets were changed. NO EVIDENCE = NO PASS.
