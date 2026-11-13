# Step 32 — Pending migration safety review (2026-11-13)

## Scope
Read-only review of the two newest SQL migrations on `website/global-launch-readiness` and the Razorpay order Edge Function. No migration was applied and no production data, schema, Auth settings, secrets, payment provider, or deployment was changed.

## Reviewed files
- `supabase/migrations/20261113120000_harden_partner_review_mfa_and_approved_lifecycle.sql`
- `supabase/migrations/20261113130000_revalidate_partner_eligibility_on_customer_quote_acceptance.sql`
- `supabase/functions/create-global-razorpay-order/index.ts`

## Findings
1. The first migration adds an AAL2 requirement to partner verification queue/review RPCs and restricts private verification-evidence reads to AAL2 users with `admin.platform`. It also accepts the `approved` partner lifecycle state in capability review. The migration uses guarded text replacement of live function definitions and intentionally aborts if expected source fragments differ. This is safer than blind replacement, but must be exercised against a staging clone with the exact production schema before application.
2. The second migration revalidates partner organization and capability eligibility at customer quote acceptance. It requires active organization, registered-business mode, lifecycle `approved` or `active`, verification `verified`, compliance exactly `compliant`, and shipment coverage. This is a strict vocabulary choice: confirm the production compliance status values and the capability coverage function behavior in staging before applying, or legitimate partners with alternate approved statuses could be blocked.
3. Both migrations are additive function/policy changes but depend on the exact deployed function bodies and schema. Production currently has no safe staging parity established; do not apply these migrations to production until migration history, schema parity, and rollback behavior are proven.
4. The Razorpay order function retains a server-side fail-closed commercial launch-mode gate. The partner-direct launch model should keep checkout disabled; do not set `KRIM_COMMERCIAL_LAUNCH_MODE=freight_checkout` for the current operating model.
5. This was a source review only. No authenticated negative cross-tenant tests, migration execution, Edge Function invocation, payment attempt, or CI pass was performed.

## Required before production
- Establish staging from an approved encrypted schema-only baseline and reconcile migration history; do not replay the full migration directory blindly.
- Verify exact partner lifecycle/compliance status vocabulary and test positive/negative partner capability cases in staging.
- Test AAL1 denial and AAL2 authorized admin access for partner verification RPCs and evidence storage.
- Test quote acceptance after partner suspension, capability withdrawal, expired capability, and route/coverage mismatch.
- Capture rollback plan and successful CI + staging evidence before production approval.

## Result
**Not production-approved.** The migrations are promising safeguards but remain unverified against a staging clone. Existing PR #65 remains draft and must not be merged or deployed on the strength of this static review alone.
