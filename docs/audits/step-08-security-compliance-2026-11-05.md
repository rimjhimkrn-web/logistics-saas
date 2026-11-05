# Step 8 — Security & Compliance Audit
Date: 5 November 2026
Project: KRIM Logistics Production Supabase

## Scope and safety
Read-only review of RLS, table grants, SECURITY DEFINER RPCs, administrator AAL2 controls, Storage policies, public Edge Functions and browser configuration. No customer, partner, shipment, payment, evidence or verification records were created or changed. Two legacy POD access paths were locked because their tables/bucket were empty.

## Database security findings

### RLS-enabled tables without policies
- Supabase Security Advisor reports 23 RLS-enabled tables with no policies (INFO).
- Checked every affected table in `public` and `private`: anon and authenticated roles have no SELECT, INSERT, UPDATE or DELETE grants. These tables are inaccessible through the Data API and remain deny-by-default. They include internal rate-limit, payment-provider/transaction, inquiry-IP-limit, market-readiness and country-operating-pack governance tables.
- No RLS-disabled public-table finding was returned by the Security Advisor.

### SECURITY DEFINER functions
- 249 SECURITY DEFINER functions exist in the public schema; 79 are executable by authenticated users; zero are executable by anon.
- All 79 authenticated-executable functions contain an `auth.uid()` guard. All 249 have an explicit `search_path` setting; 52 deliberately use an empty search path.
- The Security Advisor's 79 warnings are therefore not treated as blanket vulnerabilities: these are intentional RPC boundaries, and each must retain its function-specific ownership, membership, permission, state-transition and evidence checks. Do not revoke them wholesale or convert them blindly to SECURITY INVOKER.
- 19 authenticated RPCs do not use the generic `krim_has_permission` / internal permission helper; they are user-owned workflows (for example driver-owned assignment events, customer/partner provisioning and warehouse operator task/evidence actions). These require continued per-function review as the platform evolves.

### Privileged administrator RPCs
- Audited all authenticated SECURITY DEFINER functions that check `admin.platform`. One gap was found: `krim_admin_schedule_inquiry_followup` required platform-admin permission but did not independently require AAL2.
- Applied migration `enforce_aal2_on_admin_inquiry_followup` and committed exact SQL as `supabase/migrations/20261105062300_enforce_aal2_on_admin_inquiry_followup.sql` (commit `e115bc03852a005781abb40f19c12ba9698dda1d`).
- Re-verified the RPC has authenticated EXECUTE, anon EXECUTE false, and an explicit server-side `auth.jwt()->>'aal' = 'aal2'` check. The current count of authenticated platform-admin SECURITY DEFINER RPCs missing AAL2 is **0**.
- Other partner verification, partner capability, driver verification, POD review, warehouse facility review and pricing admin RPCs already require AAL2 and platform-admin permission in the database, not only in browser code.

## Storage security
- Five buckets are configured private: `krim-driver-evidence`, `krim-driver-verification`, `krim-partner-verification`, `krim-warehouse-evidence`, and legacy `pod-documents`.
- No anonymous Storage policies exist. The four current evidence buckets have user/organization-scoped policies, 10 MB limits and explicit MIME allowlists; privileged evidence reads require AAL2.
- Found a legacy `pod-documents` bucket with no size/MIME restrictions and three policies referencing legacy `shipment_requests` and `partners`. It had zero objects and the legacy `shipment_pod_documents` table had zero rows.
- Applied and committed:
  - `retire_legacy_pod_documents_bucket_policies` — removes legacy customer/partner Storage read/upload policies.
  - `retire_legacy_shipment_pod_document_policies` — removes legacy table policies and revokes all anon/authenticated table privileges.
- Verified the legacy table remains RLS-enabled with zero policies and zero authenticated grants; the bucket remains private with zero objects and zero policies. The canonical POD workflow continues through `krim_pod_records` and the private `krim-driver-evidence` bucket.

## Public Edge Function review
Only four deployed functions currently have `verify_jwt=false`:
- `razorpay-webhook`: intentional provider webhook entry; raw-body HMAC signature, event ID, deduplication, amount/currency validation and paid-order downgrade protection are present.
- `public-shipment-tracking`: accepts only a 32-hex opaque token generated from a UUID, with a unique database index. It returns shipment status, route locations and recorded events only; it does not return customer/partner contact details or accept sequential database IDs. No IP rate limiter is present; add Cloudflare/edge throttling before broad public promotion.
- `krim-public-contact-inquiry`: intentional public form; Edge Function calls the hashed-IP rate-limit RPC (10 requests per 10-minute window) and database logic limits each email to 3 submissions per hour, with strict field lengths/format validation and notification outbox handling.
- `cashfree-payment-webhook`: retired endpoint; always returns HTTP 410 and does not process payment events.

## Browser configuration and secrets
- The committed root `config.js` contains the Supabase URL and publishable key only. No service-role key or Razorpay/Cashfree secret literal was found in that file.
- Payment provider secrets were not read or displayed; they remain Edge Function environment variables.
- No secrets or credentials were printed or copied into repository files.

## Outstanding security controls
1. Supabase Auth leaked-password protection is disabled. Official Supabase documentation says this feature is available on Pro plan and above. The project has been operating on the Free tier; enabling it requires a project-plan upgrade or a deliberate acceptance of the current limitation. No plan upgrade was made.
2. Admin RPCs enforce AAL2, but a project-wide mandatory MFA enrollment policy for every new user was not verifiable through the available project-management interface. Keep admin access restricted to AAL2; verify global enrollment policy before launch.
3. Add IP throttling to public tracking at Cloudflare/edge before broad public promotion. Opaque tokens materially reduce enumeration risk, but do not prevent request flooding.
4. Continue the per-function review of authenticated SECURITY DEFINER RPCs as part of regression testing; do not treat the Security Advisor warning count as proof of an exploit.

## Result
Step 8 is **partially complete**. Database access boundaries, admin AAL2 enforcement and legacy POD access have been hardened and verified. Remaining items are the Supabase Auth plan-level leaked-password control, confirmation of global new-user MFA policy, public tracking throttling and the continuing per-function review. No live operation was started.
