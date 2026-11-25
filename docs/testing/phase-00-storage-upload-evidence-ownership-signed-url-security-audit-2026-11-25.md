# Phase 00 — Storage upload, evidence ownership and document-access security audit
Date: 2026-11-25
Branch: qa/phase-00-baseline-2026-11-25
Scope: Read-only Production and Staging Storage bucket metadata, Storage RLS policies, selected evidence-registration function definitions and EXECUTE ACLs. No objects were listed/read/written/deleted; no signed URLs created; no functions invoked; no credentials or secrets inspected.

## Executive result
**NOT PASS.** Production has meaningful private-bucket and ownership controls, but file-byte validation and signed-URL lifecycle were not proven. Staging contains a critical permissive Storage INSERT policy that OR-combines with its scoped partner-verification upload policy and reduces the effective gate to bucket + AAL2. This can allow an AAL2 authenticated user to upload into arbitrary object paths in that bucket, subject to Storage's other constraints. Staging must not be used for sensitive uploads until this policy is corrected and independently verified.

## Bucket configuration observed in Production
All five buckets are private:
- `krim-driver-evidence`: 10 MiB; JPEG, PNG, WebP, PDF.
- `krim-driver-verification`: 10 MiB; JPEG, PNG, WebP, PDF.
- `krim-partner-verification`: 10 MiB; PDF, JPEG, PNG.
- `krim-warehouse-evidence`: 10 MiB; JPEG, PNG, PDF.
- `pod-documents`: no configured bucket-level file-size limit or MIME allowlist.

Staging inventory/policies are not a full parity copy: the sampled Storage policy inventory contains only partner-verification policies, including the broad AAL2 INSERT policy.

## Critical finding
### F1 — Staging partner-verification AAL2 upload policy bypasses path/tenant scoping
Staging has two permissive INSERT policies on `storage.objects` for `krim-partner-verification`:
1. `krim_partner_verification_upload_own_org`: requires an active membership in the matching active partner-type organization and a path whose second segment is the caller's user ID.
2. `krim_partner_verification_upload_require_aal2`: requires only the bucket ID and JWT AAL2.

Because PostgreSQL permissive policies combine with OR, satisfying the second policy is sufficient; it does not require the organization, membership, or uploader-path checks in the first policy. This is a high-severity Staging isolation defect. No upload was attempted. Fix only through a separately approved change after confirming intended policy composition; do not simply assume multiple permissive policies are cumulative AND conditions.

## Production positive controls
1. All five buckets are private.
2. Driver verification upload policy requires the caller's own user folder, an existing driver profile, active driver membership and active organization.
3. Driver delivery evidence upload/read is tied to the caller's own driver assignment and active driver membership; upload policy excludes delivered/cancelled assignments.
4. Warehouse evidence upload requires organization/user/file path structure, active organization membership, eligible warehouse organization and `partner.manage`; read policy checks warehouse operator scope or AAL2 + platform admin.
5. Customs shipment document upload checks shipment, submitter organization, user folder, customer shipment.update or accepted customs broker assignment with compliance permission. Read policy is based on customer shipment permission, accepted broker assignment or AAL2 + platform admin.
6. Claim evidence upload policy ties claim ID, organization ID and user ID to an active claimant membership and update permission. Read access is scoped to claimant/respondent organization access.
7. Evidence-registration RPCs cross-check the uploaded object in Storage and compare owner, MIME metadata and byte-size metadata before registering evidence. Warehouse and customs routines enforce PDF/JPEG/PNG and 10 MiB; claim evidence enforces PDF/JPEG/PNG and 10 MiB.
8. Vehicle document registration checks active owner/manager membership, object path pattern, uploader ownership and object MIME/size metadata. These are metadata checks, not byte-signature checks.

## Further findings
### F2 — POD bucket has no bucket-level upload restrictions
The private `pod-documents` bucket has NULL file-size and allowed-MIME settings. The inspected driver POD registration routine aggregates already-registered driver-evidence objects from `krim-driver-evidence`, rather than demonstrating a safe direct upload path into `pod-documents`. The bucket's intended lifecycle and any upload policy/consumer remain unverified. Keep direct POD-bucket uploads disabled until strict limits, MIME allowlist and byte-level validation are established.

### F3 — MIME metadata is not content validation
The selected registration routines compare caller-supplied MIME/size values to Storage object metadata. This prevents simple metadata disagreement but does not prove the actual file bytes match the declared format, nor that files are free of malware, polyglots, decompression bombs or active content. No byte-signature inspection or malware scanning/quarantine workflow was identified in this bounded review.

### F4 — No signed-URL lifecycle proof
No dedicated KRIM signed-URL creation/revocation/download function was found in the selected function catalog. Storage signed URLs may be issued through the Storage API, but this review did not prove which pages issue them, whether the caller is authorized immediately before issuance, their TTL, whether object access can be revoked before expiry, or whether URL tokens are prevented from leaking into logs/referrers. Private bucket status alone does not answer those questions.

### F5 — Evidence RPCs vary in authorization strength and ACL
- `krim_vehicle_document_register` is SECURITY DEFINER, pins empty search_path and checks auth, active owner/manager membership, object ownership, path, metadata, and 10 MiB format constraints. Production authenticated EXECUTE is present; Staging authenticated EXECUTE is absent in the sampled catalog.
- `krim_warehouse_register_evidence` is SECURITY DEFINER with empty search_path; checks warehouse operator, path, ownership, MIME metadata and 10 MiB size. Production and Staging authenticated EXECUTE parity was not established by the bounded output; Staging Storage policy coverage is incomplete.
- `krim_customs_document_submit` delegates to a private SECURITY DEFINER routine; checks active membership, customer update permission or accepted broker assignment/compliance permission, path and object ownership/metadata. Authenticated wrapper EXECUTE was present in the sampled catalog.
- `krim_claim_add_evidence` delegates to a private SECURITY DEFINER routine; checks claimant organization membership/update permission, claim status, path, object owner and metadata. Authenticated wrapper EXECUTE was present.
- Driver POD submission checks the driver owns the assignment, active driver membership, in-transit status, linked accepted/active partner assignment and at least one owned evidence object. It does not itself demonstrate byte scanning or signed-URL security.

### F6 — Storage policy review is bounded to catalog state
Policies are permissive and additive. Effective access is the OR of all applicable permissive policies, not the strictest single policy. New policies can unintentionally widen access. The Production policy set includes many distinct workflows sharing the partner-verification bucket, so each future policy change needs a complete effective-policy review.

## Required fixes and tests before real document onboarding
1. Remove or narrow the Staging AAL2-only permissive INSERT policy so the effective policy requires BOTH AAL2 and the full tenant/uploader path rule (e.g., combine predicates in one policy or use restrictive-policy design carefully); then verify with catalog and negative runtime tests.
2. Decide and document the intended POD bucket upload workflow; configure size/MIME limits and matching object RLS before enabling it.
3. Add server-side byte-signature/content validation and malware scanning/quarantine or a documented risk-accepted compensating control.
4. Trace all frontend upload and download calls; inventory signed URL creation, TTL, storage path authorization, token exposure, caching, referrer behavior and revocation semantics.
5. Establish isolated synthetic Staging identities and test allowed own-object upload/read, wrong user, wrong org, wrong assignment, wrong bucket, arbitrary path, MIME spoof, oversized file, overwrite/upsert, delete-before-registration, expired signed URL, and membership revocation.
6. Verify that privileged evidence review requires intended permission + AAL2 and does not permit self-approval.
7. Do not copy Production policies wholesale into Staging; create a minimal isolated test policy set.

## Evidence limitations
- No Storage object names/content were enumerated.
- No upload, delete, download, signed URL, function invocation or authenticated session test was performed.
- Storage object metadata does not prove actual file bytes.
- No live browser source tracing was performed in this task; signed URL issuance and token leakage remain NOT VERIFIED.
- Staging policy result is catalog evidence; actual exploitation was not attempted.
- Function-source sampling is not an exhaustive scan of all Storage consumers or Edge Functions.

## Change record
No Production or Staging database, Storage, Auth, function, secret, code, or deployment changes. Report committed only to the QA branch.
