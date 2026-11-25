# Phase 00 — Partner compliance evidence upload route trace

**Date:** 2026-11-25  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Classification:** Static source and migration review only. No upload, RPC execution, object read, or database write.

## Newly confirmed Storage route

**Frontend:** `public/partner/compliance-evidence.html`

The route is not a redirect or static mock. Its source implements a live partner compliance evidence submission flow:

- Authenticates with `db.auth.getUser()`; redirects unauthenticated users to partner sign-in.
- Reads active organization memberships and eligible organization records.
- Restricts the UI to active, verified, approved/active registered-business partner organizations.
- Requires four evidence categories: business registration, tax registration, operating authority, and insurance/liability.
- Client validates file size (1 byte–10 MiB) and MIME allowlist (PDF/JPEG/PNG).
- Builds paths in the form `{organization_id}/{user_id}/compliance-{category}-{UUID}.{ext}`.
- Uploads to private bucket `krim-partner-verification` with `upsert:false`.
- Calls `krim_partner_submit_compliance_evidence` only after uploading all selected files.
- If upload fails before RPC, the UI warns that partial private objects may remain because applicant deletion is not authorized. If RPC outcome is uncertain, it instructs the user not to retry until support reconciles the evidence register.

## Backend registration controls observed

Migration `supabase/migrations/20261105210000_partner_compliance_evidence_submission.sql` defines `public.krim_partner_submit_compliance_evidence(bigint,jsonb,text)`:

- `SECURITY DEFINER`, empty pinned search path.
- Rejects unauthenticated callers.
- Requires exactly four unique categories and a declaration of at least 30 characters.
- Requires active, identity-verified registered-business organization, approved/active lifecycle, supported organization type, and `partner.manage` permission.
- Validates jurisdiction code.
- Enforces org/user/category-specific UUID path shape.
- Validates filename length, MIME allowlist and 10 MiB maximum.
- Confirms Storage object exists in `krim-partner-verification`, is owned by the caller, and Storage metadata MIME/size match submitted metadata.
- Inserts evidence rows and a `krim_audit_events` submission event.
- Returns `commercial_activation:false`; submission does not itself activate commercial service.
- Revokes PUBLIC/anon execution and grants authenticated execution.

**Important limitation:** the function validates Storage metadata, not file-byte signatures or malware status. The frontend does not perform cleanup after partial upload; the page explicitly warns that uploaded private objects may remain. This needs a reconciled orphan-object lifecycle, not an unsafe broad delete policy.

## Other files checked in this pass

- `app/platform-admin/delivery-pod-verification.html`: confirmed 60-second signed preview from `krim-driver-evidence`; this corroborates the previously reported admin POD review route.
- `public/partner/document-upload.html` and `public/partner/pod-upload.html`: redirects, not independent upload implementations.
- `public/customer/pod-download.html`: redirects to canonical customer OS route.
- `public/customer-os/customer-services/pod-capture.html` and `pod-download.html`: guidance/control pages; no direct Storage SDK calls found in inspected source.
- `app/warehouse/staging/page-13-warehouse-evidence.html`: explicitly describes backend readiness gates; no live Storage SDK operation found in inspected source.
- Sampled `app/admin/staging/page-*` verification pages did not expose direct Storage SDK calls in inspected lines.

## Inventory update

Add `public/partner/compliance-evidence.html` to the confirmed live upload-route list. It was not included in the previous seven-route sample inventory. The total confirmed distinct frontend routes is therefore **at least eight** (not a repository-wide completeness claim).

## Remaining work

- Complete a bulk source-content scan across all source candidates; connector call limits prevented fetching every file in one pass.
- Trace the exact effective Production and Staging Storage INSERT/SELECT/DELETE policy composition for this bucket and confirm whether the permissive Staging policy remains present on the current branch's target project.
- Establish a safe, server-governed orphan cleanup/reconciliation path for partially uploaded partner compliance objects.
- Add byte-signature validation and malware quarantine/scanning before evidence is accepted.
- Run synthetic two-tenant runtime tests only after Staging policy isolation and test-sink protections are approved.

## Safety

No Storage objects were listed, downloaded, uploaded, deleted, or signed. No Supabase function/RPC was executed. No database or bucket configuration changed. Report only, QA branch only; no merge or deployment.
