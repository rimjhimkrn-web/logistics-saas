# Phase 00 — Repository-wide Storage access-path inventory

**Date:** 2026-11-25  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Scope:** Read-only repository inventory and source-search attempt. No application, database, bucket, policy, or deployment changes.

## Executive result

**Status: INCOMPLETE — repository-wide source coverage is not proven.**

The recursive Git tree for the QA branch was retrieved successfully: **2,259 repository blobs**, of which **1,512** were source candidates with HTML/JS/TS/SQL extensions. A filename/path filter identified **435** candidates with storage/document/evidence/upload/download/POD/driver/customs/warehouse/tracking-related path terms.

A bounded source review from the immediately preceding audits already confirmed Storage SDK usage in the following canonical pages:

| Path | Observed operation | Evidence status |
|---|---|---|
| `public/warehouse/warehouse-evidence.html` | Private-bucket upload, evidence registration, 60-second signed preview | Source inspected in prior report |
| `app/customer/customs-documents.html` | Private-bucket upload, document registration, 60-second signed preview | Source inspected in prior report |
| `app/admin/vehicle-verification.html` | Review queue and 60-second signed preview | Source inspected in prior report |
| `public/shipper/epod-vault.html` | Verified POD metadata and 60-second signed URL | Source inspected in prior report |
| `public/partner/documents-delivery-evidence.html` | Evidence metadata; no download action found in that page | Source inspected in prior report |
| `public/documents/document-upload.html` | Static/presentation page; no live Storage integration found | Source inspected in prior report |
| `public/documents/document-download.html` | Static/presentation page; no live Storage integration found | Source inspected in prior report |

These are **known routes, not an exhaustive list**. Full details and caveats are in:
- `phase-00-storage-upload-evidence-ownership-signed-url-security-audit-2026-11-25.md`
- `phase-00-frontend-document-upload-download-and-signed-link-trace-2026-11-25.md`

## Repository inventory method and limitations

1. Retrieved the recursive Git tree for the exact QA branch. GitHub reported `truncated=false`.
2. Counted all blobs and source candidates, then narrowed path candidates by storage/document/evidence/upload/download/POD/driver/customs/warehouse/tracking naming.
3. Attempted indexed GitHub code searches for `storage.from`, `createSignedUrl`, `createSignedUploadUrl`, `getPublicUrl`, and `storage/v1/object`. All returned zero results. This is **not evidence of absence**: the repository code-search index was not demonstrated to cover the QA branch, and prior code-search attempts reported incomplete indexing.
4. A direct raw-file sweep across all 435 path candidates could not be completed within the connector's per-execution tool-call limit. Therefore this report does **not** certify that every Storage access path has been found.

## Known security and implementation observations carried forward

- The five sampled Production buckets were private. The `pod-documents` bucket had no configured size/MIME restrictions in the earlier read-only catalog audit.
- A Staging permissive INSERT policy on `krim-partner-verification` was found to OR-combine with narrower policies and potentially bypass the intended organization/uploader path restriction. Staging sensitive uploads remain blocked pending reviewed remediation.
- Sampled upload pages apply client-side file type/size checks, but server-side evidence registration checks metadata rather than proving the file's byte signature. No malware scanning/quarantine pipeline was found in the bounded review.
- Four sampled preview flows create 60-second signed URLs in the browser. No central signed-link broker or consistent download-audit event was established.
- Generic document upload/download pages are not evidence of a functioning secure vault.
- Existing signed URLs may remain usable until expiry after a user's membership or permission is revoked; immediate revocation was not demonstrated.
- These observations are not expanded into new claims about uninspected paths.

## Required next step

Complete a deterministic source scan of **all 1,512 source candidates** on this exact branch using a repository archive/clone or another bulk-readable mechanism, then classify every occurrence of:
- `storage.from(...)`
- `upload`, `uploadToSignedUrl`, `createSignedUploadUrl`
- `download`, `createSignedUrl(s)`, `getPublicUrl`
- direct `/storage/v1/object` fetches
- Edge Function handlers that issue signed URLs or proxy object bytes
- bucket identifiers and path construction

For each occurrence, record file, line, operation, bucket, caller authentication, authorization source, expiry, audit event, and whether it is reachable from a canonical route. Then reconcile the resulting inventory against Storage bucket metadata and RLS policies. Do not create test objects, signed URLs, or database writes during this static phase.

## Safety boundary

Read-only inventory only. No user files or Storage objects were opened, uploaded, downloaded, or deleted. No signed URLs were generated. No Production or Staging settings, secrets, policies, functions, or data were changed. Nothing was merged to `main` or deployed.
