# Phase 00 — Private document storage, evidence ownership and tenant isolation audit

Date: 2026-11-25  
Environments: Production and Staging Supabase  
Scope: Read-only review of Storage buckets, object RLS policies, bucket constraints, object inventory and evidence access patterns. No upload, download, signed URL, deletion, policy change or bucket modification was performed.

## Executive verdict

**NOT VERIFIED for real-user onboarding.** All inspected buckets are configured private, and several strong organization-, assignment- and shipment-scoped policies exist. However, Staging contains a potentially overbroad permissive INSERT policy on the partner verification bucket that can bypass the intended path/organization checks for any authenticated AAL2 user. This is a critical Staging blocker and must be corrected before synthetic upload testing.

## Bucket inventory

| Bucket | Production | Staging | Private | Size limit |
|---|---|---|---|---:|
| krim-driver-evidence | Present | Missing | Yes | 10 MB |
| krim-driver-verification | Present | Missing | Yes | 10 MB |
| krim-partner-verification | Present | Present | Yes | 10 MB |
| krim-warehouse-evidence | Present | Missing | Yes | 10 MB |
| pod-documents | Present | Missing | Yes | Not configured |

- Production has five buckets; Staging has only the partner verification bucket.
- No objects were returned from the inspected Storage object inventory in either environment.
- The `pod-documents` bucket has no configured size limit or MIME allowlist in Production. It should be treated as an unused/legacy bucket until ownership, upload paths and limits are established.
- Storage `objects` has RLS enabled but not FORCE RLS in both environments. This is not automatically a vulnerability; service-role/owner behavior and policy paths require care.

## Positive controls observed in Production

### Partner verification evidence
- Bucket is private.
- Upload path binds organization ID and current Auth user ID.
- Upload requires active membership in an active eligible logistics-provider organization.
- Read path checks active organization membership and organization type.
- Separate platform-admin read requires AAL2 and `admin.platform`.
- Unlinked evidence cleanup is limited to the current uploader and excludes files already referenced by organization/capacity/service-area records.

### Driver evidence and verification
- Driver evidence upload/read paths bind Auth user ID, assignment ID, driver assignment ownership, active driver membership and active organization.
- Uploads are blocked for delivered/cancelled assignments.
- Driver verification uploads bind the user to their own driver profile and active driver organization membership.
- Driver verification admin read requires AAL2 and platform-admin permission.

### Warehouse evidence
- Upload/read paths require an eligible warehouse organization, active membership, `partner.manage` permission and a user-scoped folder path.
- Platform-admin read requires AAL2 and `admin.platform`.
- Cleanup is uploader-owned and blocked when the object is already referenced by warehouse evidence metadata.

### Customs evidence
- Customs broker license upload/read paths bind customs organization membership, organization type, uploader and compliance permission.
- Shipment document paths bind shipment ID, customer/broker organization and current user; read access is tied to customer shipment permission, accepted broker assignment or AAL2 platform admin.
- Cleanup excludes files referenced by customs license/submission records.

### POD evidence
- Customer read policy only permits evidence paths referenced by a verified POD record for a shipment belonging to an organization the user can access.
- Platform-admin preview is AAL2-gated.

## Critical findings

1. **Staging partner evidence INSERT policy is overbroad (critical).** Staging has a standalone permissive policy named `krim_partner_verification_upload_require_aal2` whose check is only: bucket is `krim-partner-verification` and JWT AAL is `aal2`. PostgreSQL permissive policies combine with OR. Therefore, this policy independently permits any authenticated AAL2 user to insert an object into that bucket without satisfying the separate organization/uploader path policy. This defeats the intended tenant/path restriction. Remove or rewrite this policy only through a reviewed Staging-only change after explicit approval; do not test uploads while it exists.

2. **Staging storage parity is incomplete.** Four Production buckets are absent in Staging. Staging cannot currently exercise driver, warehouse or POD evidence journeys. Do not create buckets or copy policies until the intended test fixture and exact limits are approved.

3. **Production partner verification evidence has no explicit per-object size/MIME check in the Storage policy.** The bucket has 10 MB and MIME allowlist configuration, which is useful, but runtime enforcement and client-supplied content-type spoofing have not been tested. Confirm server-side file signature validation for high-risk business/identity documents.

4. **POD bucket lacks file-size and MIME restrictions.** `pod-documents` is private but has no bucket-level size/MIME allowlist in the inspected metadata. It may be legacy or unused; confirm no page, RPC, signed URL or workflow relies on it before changing or deleting anything.

5. **Driver evidence admin preview is broad within its bucket.** The AAL2 platform-admin policy permits preview of any object in `krim-driver-evidence`, without checking a corresponding driver assignment or POD record in the policy predicate. This may be intentional for a privileged compliance role, but should be justified, audited and logged; consider narrower case-based access.

6. **Storage object RLS is enabled but not FORCE RLS.** This is common for Storage internals and not a standalone issue. Confirm that no client-side code uses owner/service credentials and that SECURITY DEFINER/server-side functions enforce equivalent tenant scope.

7. **No runtime isolation proof.** No synthetic user from tenant A attempted to read, overwrite, delete or sign a URL for tenant B's evidence. No uploader-versus-reviewer, accepted-broker, customer-verified-POD or AAL1/AAL2 negative tests were performed.

8. **No object inventory means no evidence lifecycle proof.** Storage object queries returned no rows in the inspected buckets, so retention, orphan cleanup, malware scanning, evidence replacement, deletion/retention and signed URL expiration were not empirically verified.

## Required remediation and test gates

1. Correct the Staging partner bucket policy so AAL2 is an additional requirement inside the same organization/uploader/path predicate, not an independent permissive policy.
2. Establish the complete Staging bucket inventory and limits from an approved migration/configuration plan.
3. Confirm `pod-documents` is legacy or configure explicit limits and a reviewed access model before any use.
4. Add server-side MIME/signature validation and safe file processing for identity, business, customs, warehouse and POD documents.
5. Establish retention, deletion, legal-hold, signed-URL expiry and orphan-evidence cleanup requirements.
6. After Staging is isolated and corrected, run tenant-A/tenant-B negative tests, uploader ownership tests, role-specific reviewer tests, object replacement/deletion tests and signed URL expiry tests.
7. Do not upload real identity documents during QA. Use synthetic non-sensitive fixtures and a test sink.

## Release decision

- Private bucket configuration: **PASS (catalog-observed only)**.
- Production tenant-scoped policy source: **PARTIAL PASS (source/catalog-observed only)**.
- Staging partner evidence upload policy: **FAIL — critical overbroad permissive policy**.
- Staging storage parity: **FAIL / INCOMPLETE**.
- POD bucket limits: **REMEDIATION REQUIRED**.
- Runtime cross-tenant evidence isolation: **NOT TESTED**.
- Real partner/driver/warehouse/customs onboarding: **NOT APPROVED**.

No Production or Staging changes were made. NO EVIDENCE = NO PASS.
