# KRIM Private Storage, Evidence Ownership and Document Access Security Audit
**Date:** 16 November 2026  
**Scope:** Read-only production inspection of Supabase Storage buckets, object-row count, storage RLS policies and grants, plus selected evidence-registration, POD, customs, driver, partner and warehouse RPC definitions. Repository search for explicit signed/public URL helpers. No file was uploaded, downloaded, signed, deleted or previewed; no storage policy, bucket, function or data was changed.

## Executive decision
**NO-GO for storage/evidence security certification until staging access tests and the identified legacy-bucket and evidence lifecycle questions are resolved.** The current production buckets are all private, no storage objects currently exist, and the principal evidence paths use organization/user/assignment scoping with authenticated RLS. Several sensitive workflows verify the uploader owns the object before registering or approving evidence.

This is a source/catalog review, not a test of real browser downloads, signed-URL expiry, cache behavior, CDN behavior, or service-role access.

## 1. Production Storage baseline
Five private buckets exist:
- `krim-driver-evidence` — 10 MB limit; JPEG, PNG, WebP, PDF.
- `krim-driver-verification` — 10 MB limit; JPEG, PNG, WebP, PDF.
- `krim-partner-verification` — 10 MB limit; PDF, JPEG, PNG.
- `krim-warehouse-evidence` — 10 MB limit; JPEG, PNG, PDF.
- `pod-documents` — private, but no bucket-level file-size limit or MIME allowlist configured.

Production `storage.objects` count is **0** at audit time: 0 objects in public buckets and 0 in private buckets. There are no public buckets.

Storage object policies are scoped to the authenticated role. The inspected policy catalogue includes:
- Driver evidence: upload and read own assignment; AAL2 platform-admin preview; verified-POD customer read.
- Driver verification: own-profile upload, AAL2 platform-admin read, limited cleanup of unregistered uploads.
- Partner verification: own-organization upload/read, AAL2 platform-admin read, category-specific cleanup for unlinked uploads, and scoped customs/claim evidence rules.
- Warehouse evidence: operator-scoped upload/read, AAL2 platform-admin read, limited cleanup of unregistered evidence.
- No bucket-specific policy was found for `pod-documents`.

The storage.objects table grants SELECT/INSERT/UPDATE/DELETE to anon and authenticated at the SQL privilege layer, but RLS is the effective row gate. This is not by itself a bypass. However, unnecessary table privileges increase the impact if a future policy is accidentally broadened; review grants and policies together in the migration-safe hardening phase.

## 2. Positive controls observed
### Driver delivery evidence and POD
- Driver evidence upload policy binds the object path to the authenticated user and a driver assignment owned by that user, with active driver membership and active organization.
- Driver evidence read policy is limited to the authenticated driver's own assignment path.
- `krim_driver_submit_delivery_pod` checks exact driver assignment ownership, active driver membership, in-transit state, active linked partner assignment, and at least one evidence object in `krim-driver-evidence` owned by the driver.
- POD submission embeds only registered evidence paths/metadata from the driver's own assignment.
- POD review is AAL2 and platform-admin permission gated, requires a separate reviewer, verifies at least one evidence object owned by the assigned driver, and only then invokes delivery authorization.
- Customer storage SELECT policy is limited to evidence referenced by a POD whose status is verified, with verified timestamp and customer organization access.
- Platform-admin POD evidence preview requires AAL2 and `admin.platform`.

### Driver verification
- Driver verification upload policy requires the user's own driver profile, active driver membership and active organization.
- Admin read is AAL2 and platform-admin permission gated.
- Cleanup is limited to uploader-owned objects that are not yet linked to a registered driver document.

### Partner and vehicle evidence
- Partner verification upload paths include organization and uploader identity; own-organization reads require active membership and active organization of an allowed partner-type organization.
- Partner compliance evidence registration validates active verified registered-business status, `partner.manage`, four required evidence categories, strict path shape, MIME and 10 MB size, and confirms the storage object exists and is owned by the submitter with matching MIME/size metadata.
- Vehicle document registration validates organization owner/manager membership, organization/user/vehicle path, file type/size, and object ownership via the storage object's uploader field; the reviewer independently rechecks ownership and metadata before approval.

### Warehouse evidence
- Warehouse evidence policy scopes paths to organization/user and warehouse eligibility/permission.
- `krim_warehouse_register_evidence` verifies warehouse operator access, organization/user/file path, object ownership, MIME and size (up to 10 MB).
- Quality review requires a private uploader-owned inspection report from an actor other than the reviewer and validates SKU/lot/task/facility alignment.
- Transfer quality review requires private reviewer-owned evidence and independent reviewer separation.

### Customs and claims
- Customs broker licence and shipment-document buckets are private and policy-scoped to active organization membership, shipment/customer access or accepted broker assignment; admin access requires AAL2 and platform permission.
- Customs submission and review routines enforce private evidence metadata, ownership and maker-checker controls (see separate customs audit).
- Claim evidence paths are scoped to claim/organization/uploader; reads are restricted to claim parties or authorized platform/operations users.

## 3. Findings and risk classification

### P1 — Legacy `pod-documents` bucket is private but ungoverned
The bucket is private, which is a positive default, but it has no bucket-level size or MIME restrictions and no bucket-specific authenticated RLS policy was found. There are currently zero objects in all buckets, so there is no evidence of an active exposure. The bucket is nevertheless an unmanaged storage surface: any future code that begins writing to it may fail closed unexpectedly or tempt a developer to add an overly broad policy.

**Required action:** determine whether this is a legacy unused bucket. If unused, remove it only after repository/function/deployment dependency review and migration reconciliation. If required, define purpose-specific upload/read/delete policies, file-size/MIME limits, ownership and retention before first use. Do not make it public.

### P1 — Signed URL issuance, expiry and revocation are not proven
Repository search did not identify explicit `createSignedUrl`, `createSignedUrls`, `createSignedUploadUrl` or `getPublicUrl` calls, and no dedicated public database RPC named for signed URL issuance was found. This does not prove no signed URLs are generated: the browser may call the SDK dynamically, and privileged Edge Functions/service-role code was not exhaustively traced in this pass.

**Required action:** inventory every browser and Edge Function download/preview path. For each, verify the caller's current tenant/role permission before URL generation; use the shortest practical expiry; never persist signed URLs in tables, logs, analytics or notifications; ensure private cache/no-store behavior; and test that a URL cannot be reused after expiry or shared to a different tenant during its valid window. A signed URL is a bearer capability until expiry, so removing a membership does not necessarily revoke an already-issued URL.

### P1 — Storage SQL grants are broader than necessary
The inspected SQL grants include anon and authenticated SELECT/INSERT/UPDATE/DELETE on `storage.objects`. The bucket policies inspected are authenticated-only and there are no anon policies in the reviewed catalogue, so no anon access path was established. Still, direct UPDATE/DELETE grants are unnecessary for most client workflows and should be reviewed against Supabase's supported Storage API model before tightening. Do not revoke provider-managed grants ad hoc.

### P2 — Evidence lifecycle lacks production proof
There are zero storage objects, so no actual upload/preview/download, malware scanning, retention, deletion, supersession, restore, or signed-link expiry path has been exercised against real evidence. Code checks metadata and path but do not substitute for end-to-end content inspection or malware scanning.

### P2 — Cross-bucket policy drift
Driver, partner, customs, claims and warehouse evidence use different path conventions, owner/owner_id field references, cleanup conditions and permission vocabularies. The reviewed functions contain multiple good controls, but the conventions are not a single reusable contract. Future additions can accidentally omit one check.

**Required action:** define a shared evidence contract (bucket, object path, uploader, tenant, entity, allowed MIME, size, lifecycle state, retention, reviewer, and download authorization) and test each bucket against the same negative-case matrix.

## 4. Required staging-only security tests
No tests were executed because there are no storage objects and no staging evidence fixtures were authorized. Before release, create synthetic non-production users/tenants and test:
1. Anonymous upload, list, download, update and delete.
2. Authenticated non-member and wrong-workspace upload/read.
3. Tenant A reading Tenant B object by guessed path, UUID, filename and metadata.
4. User A reading User B driver evidence or driver-verification object.
5. Driver accessing another driver's assignment evidence.
6. Customer reading POD evidence before verification, after rejection, after verification, and after shipment/customer organization access is revoked.
7. Platform admin at AAL1 versus AAL2.
8. Customs broker before and after accepted assignment, licence expiry and assignment revocation.
9. Warehouse user without facility/operator access; facility suspension and membership revocation.
10. Object owner mismatch, wrong path prefix, wrong MIME, wrong size, forged metadata, duplicate object path and replacement upload.
11. Signed URL expiry, cross-tenant sharing, cache headers, browser history/referrer leakage and URL logging.
12. Orphan cleanup cannot delete an object already linked to an evidence record.
13. Evidence supersession/replacement preserves audit history and does not silently change a previously reviewed file.
14. Service-role endpoints do not return signed links or raw evidence to unauthorized callers.
15. Error responses do not reveal another tenant's file existence, names, paths or metadata.

## 5. Change control and release gate
- Read-only catalog/function inspection only.
- No object uploads/downloads/previews or signed URLs generated.
- No storage policy, bucket configuration, grants, function or production data changed.
- No real user or customer evidence inspected.
- Production schema migration reconciliation remains unresolved. Do not apply production storage DDL, revoke grants, alter bucket policies or delete `pod-documents` until the migration crosswalk and dependencies are reconciled.

**Release status: NO-GO for storage/evidence security certification.** Private-bucket defaults and strong path/ownership checks are present, but signed-link behavior and full staging access boundaries remain unverified, and `pod-documents` is an unmanaged legacy bucket candidate.
