# Phase 00 — Live Staging gate recheck (2026-11-25)

## Scope
Read-only catalog verification on Supabase Staging project `qrpcivhdxobiaofppbkl`, plus GitHub Actions job-result verification. No database, Storage, Auth, secrets, provider, deployment, or Production changes were made.

## CI evidence
The following QA-branch workflow runs completed successfully:
- Repository/static smoke: run `45573084338`, job `smoke-check`, conclusion `success`.
- Chromium environment isolation fixture: run `45573084316`, job `chromium-environment-smoke`, conclusion `success`.

The Chromium run validates the QA environment-selection logic against a local HTTPS fixture with a stubbed Supabase client. It is not evidence of a live Staging deployment or real Supabase authentication.

## Fresh Staging catalog evidence
Read-only query results:
- Bucket `krim-partner-verification` exists, private, 10 MiB maximum, MIME allowlist PDF/JPEG/PNG.
- Buckets `krim-driver-verification`, `krim-driver-evidence`, and `krim-warehouse-evidence` were not returned by the exact-ID catalog query; they remain absent from the reviewed Staging bucket set.
- Partner upload INSERT policy `krim_partner_verification_upload_own_org` is PERMISSIVE and restricts bucket, uploader UID in path segment 2, active membership, active organization, and eligible provider organization type.
- `krim_partner_verification_upload_require_aal2` is RESTRICTIVE and requires JWT AAL2. PostgreSQL policy composition means this restriction must also pass alongside a permissive policy. This confirms structural AAL2 enforcement for this INSERT path.
- `public.krim_admin_review_driver_document(uuid,text,text)`: authenticated EXECUTE=false; anon EXECUTE=false; service_role EXECUTE=true.

## Gate interpretation
- G0 (live Staging origin + deployed commit + matching Supabase project identity): BLOCKED / NOT VERIFIED. CI fixture evidence does not satisfy G0.
- G1 (partner upload assurance): STRUCTURAL PARTIAL PASS only. Runtime JWT/AAL1/AAL2 and tenant-boundary tests remain NOT TESTED; Production parity/owner decision remains open.
- G2 (Staging Storage parity): BLOCKED. Three reviewed driver/warehouse buckets are missing.
- G3 (driver reviewer RPC): BLOCKED. The browser page calls the RPC as an authenticated user, but the Staging ACL currently denies authenticated EXECUTE. The narrow grant proposal remains unapplied pending G0 proof and explicit approval.
- G4 (synthetic identities): NOT ESTABLISHED.
- G5 (safe test sink and cleanup): NOT ESTABLISHED.
- G6 (runtime verification): NOT STARTED.

## Next safe action
Obtain owner-side hosting evidence for the Staging Pages project: project/site name, production deployment URL, branch, deployed commit SHA, deployment status, and any custom-domain/redirect mapping relevant to the configured Staging origin. Then verify that the served site selects project ref `qrpcivhdxobiaofppbkl` before any authenticated test.

## Safety
No Production or Staging mutations, real payments, provider sends, customer/partner onboarding, merges, or deployments were performed. No PASS is claimed for unexecuted runtime tests.
