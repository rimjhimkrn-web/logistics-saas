# KRIM Storage and View Security Review — 2026-11-09

## Scope
Read-only inspection of production PostgreSQL catalogs, Storage bucket metadata, Storage object policies, and Supabase security advisors. No database or Auth settings were changed.

## Views
- One view exists in the inspected exposed/internal application schemas: `public.partner_rating_summary`.
- It is configured with `security_invoker = true`, so it does not automatically bypass underlying table RLS.
- It has SELECT grants to anon and authenticated, but its underlying `partners` and `shipment_requests` tables do not grant SELECT to anon and both have RLS enabled. `shipment_ratings` grants SELECT to anon and authenticated and has RLS enabled.
- Authenticated users have SELECT on the underlying tables subject to their RLS policies.
- This view is legacy-model based (`partners`, `shipment_requests`, `shipment_ratings`), while KRIM's current global shipment model uses `krim_shipments`. Confirm whether the view is still needed and whether its public grant is intentional before relying on it.

## Storage buckets
All five inspected buckets are private. No objects were stored in any of them at audit time.

| Bucket | Public | Max size | MIME allowlist | Storage object policies |
|---|---|---:|---|---:|
| krim-driver-evidence | No | 10 MiB | JPEG, PNG, WebP, PDF | 4 |
| krim-driver-verification | No | 10 MiB | JPEG, PNG, WebP, PDF | 3 |
| krim-partner-verification | No | 10 MiB | PDF, JPEG, PNG | 16 |
| krim-warehouse-evidence | No | 10 MiB | JPEG, PNG, PDF | 3 |
| pod-documents | No | Not set | Not set | 0 |

The four active evidence buckets have scoped authenticated SELECT/INSERT policies and cleanup/admin paths. Policies were reviewed at a high level for ownership, organization membership, assignment, shipment, and MFA/permission checks. This is not yet a complete path-by-path Storage authorization test.

### Storage follow-up
- `pod-documents` is private and has no Storage object policies, no upload size/MIME restrictions, and currently zero objects. With no object policies, ordinary authenticated client access is denied; however, the bucket configuration is incomplete if it is intended for future use.
- Do not enable or use `pod-documents` until the intended upload/read model is defined. Prefer the already-scoped private evidence buckets or design a dedicated scoped policy set and bucket limits after staging tests.
- Verify that the application uses the current signed ePOD workflow and does not write to this legacy bucket.

## Supabase security advisor snapshot
The current advisor snapshot reports:
- 26 RLS-enabled tables without policies (includes private-schema service-only tables and public-schema restricted tables).
- 126 public SECURITY DEFINER functions executable by authenticated users.
- Leaked password protection is disabled.

The 126-function warning is a broad exposure inventory, not proof each function is vulnerable. Each RPC needs a call-chain authorization review and least-privilege EXECUTE grants. No bulk revoke or SECURITY INVOKER conversion should be performed without checking app dependencies and function logic.

Leaked password protection should be enabled in Supabase Auth password security settings when the owner is ready; this is an Auth configuration change and was not made during this read-only audit.

## Decision / next gates
1. Keep `pod-documents` unused until configuration and policy design are approved.
2. Review remaining authenticated-callable SECURITY DEFINER RPCs by business domain and verify authorization on every read/write path.
3. Confirm legacy rating view is required and intentionally exposed.
4. Enable leaked password protection after checking Auth settings and testing signup/password reset flows.
5. Build the staging baseline and run synthetic positive/negative Storage, view, and RPC tests before live operations.

Production remained untouched.
