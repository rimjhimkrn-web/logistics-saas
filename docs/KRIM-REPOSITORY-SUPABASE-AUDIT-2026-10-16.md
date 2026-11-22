# KRIM repository and Supabase baseline audit — 2026-10-16

## Scope and evidence
This is a snapshot of the connected GitHub `main` tree and connected Supabase project at the time of review. It is not a penetration test, end-to-end test, or production launch approval. Re-run checks after changes.

## GitHub repository snapshot
- Repository: `rimjhimkrn-web/logistics-saas`
- Branch inspected: `main`
- Total tracked files reported by Git tree: **625**
- Files under `public/`: **287**
- Files under `auth/`: **31**
- Files under top-level `app/`: **11**
- Files under top-level `control/`: **0**
- Files under `domains/`: **13**
- Files under `platform/`: **9**
- Files under `core/`: **15**
- Files under `docs/`: **23**
- Files under top-level `supabase/`: **0**

### Interpretation
- KRIM already has a large public-facing file tree and multiple customer, app, billing, compliance, developer, AI/operations and control-centre areas. File count alone does not prove functional workflows.
- The tree uses several parallel route families, including top-level `app/`, `public/app/`, `public/customer/`, `public/partner/` and `public/control-centre/`. These must be mapped to one canonical route registry before broad wiring changes.
- A top-level `control/` directory and top-level `supabase/` migration/function source directory were not present in the inspected `main` tree. Do not infer that no Supabase schema or Edge Functions exist: they are present in the connected project. Establish a repeatable source-controlled migration/function workflow.
- Existing files should be audited and incrementally connected; do not create duplicate pages just because a proposed target filename differs from the current route layout.

## Connected Supabase snapshot
- Project: `logistics-saas`
- Project reference: `ebltviniygljwwseplph`
- Region: `ap-northeast-1`
- Status reported by Supabase: `ACTIVE_HEALTHY`
- Database engine: PostgreSQL 17
- Migration records returned: **73**
- Active Edge Functions returned: **9**

### Active Edge Functions observed
| Function | Version | JWT verification |
|---|---:|---|
| `razorpay-webhook` | 4 | false (must verify provider webhook signature internally) |
| `krim-ai` | 6 | true |
| `create-global-razorpay-order` | 2 | true |
| `verify-razorpay-payment` | 1 | true |
| `krim-notification-provider-adapter` | 4 | true |
| `global-admin-control` | 2 | true |
| `krim-global-growth-operations` | 2 | true |
| `create-razorpay-order` | 1 | true |
| `process-payment--` | 1 | true |

### Security advisor findings observed
1. **Seven SECURITY DEFINER functions callable by authenticated users** were flagged. The reported functions include:
   - `public.krim_award_partner_quote(p_partner_quote_id bigint)`
   - `public.krim_create_partner_opportunity(p_shipment_id bigint, p_response_deadline timestamp with time zone, p_service_tier text)`
   - `public.krim_provision_customer_organization(p_legal_name text)`
   - `public.krim_provision_partner_organization(p_legal_name text)`
   - `public.krim_respond_to_partner_assignment(p_assignment_id bigint, p_accept boolean, p_reason text)`
   - `public.krim_submit_partner_onboarding(p_legal_name text, p_country_code text, p_authority_id text, p_operational_category text, p_document_paths text[])`
   - `public.krim_submit_partner_quote(p_opportunity_id bigint, p_amount numeric, p_currency_code text, p_valid_until timestamp with time zone, p_notes text)`
   
   This is a review finding, not proof that every function is exploitable. Inspect function bodies, grants, identity checks and intended caller roles before changing permissions. Test legitimate partner/customer flows after any fix.
2. **Leaked-password protection is disabled.** Enable it when available in the project's Auth security settings; if plan or UI prevents it, document the limitation and compensate with strong password rules, MFA for privileged roles, rate limits and monitoring. This remains a security warning.
3. Performance advisors also returned an auth RLS initialization-plan warning and multiple permissive policy warnings (6 findings), plus 634 unused-index informational findings. Review policies for unintended OR access before changing them; unused-index warnings are not an instruction to drop indexes without workload analysis.

## Payment integration blocker found in frontend/backend naming
The inspected frontend file `public/quote-result.html` calls:
- `/functions/v1/create-razorpay-order`
- then `/functions/v1/process-payment`

The connected Supabase function inventory instead reports the deployed slug **`process-payment--`** (two trailing hyphens), not `process-payment`. This mismatch must be resolved deliberately; do not assume the endpoint exists under the frontend's requested name.

Additional checkout blockers from the inspected frontend:
- The order-creation request does not include a user Authorization bearer token even though the function has JWT verification enabled.
- Request body uses `JSON.parse(JSON.stringify(...))`, which produces an object rather than the required serialized JSON string for this fetch body; use `JSON.stringify(...)` only after agreeing on the endpoint contract.
- Freight amount is hardcoded to INR 12,500 in the browser rather than being derived from a valid accepted server-side quote.
- Checkout UI reports success without checking the payment-processing HTTP response/body.
- Placeholder contact number is hardcoded.
- Verify that the server binds the payment to the expected user, accepted quote/shipment, order, amount and currency; verify Razorpay signature/provider status and idempotency before writing ledger entries.

## Required execution order
1. **Route/file inventory:** map existing paths to user personas, canonical routes, navigation links, backend contracts and test evidence. Avoid duplicating pages.
2. **Security first:** inspect the seven flagged SECURITY DEFINER functions and relevant RLS/grants; correct only after reviewing bodies and proving intended access.
3. **Identity and onboarding:** prove Get Started → signup → verification → organization → correct workspace, including customer and partner isolation.
4. **Partner readiness:** prove verification, service areas, real capacity, assignment acceptance and proof-of-delivery.
5. **Quote and shipment:** server-authoritative pricing and atomic quote acceptance/booking; remove demo paths from production routes.
6. **Payments:** resolve exact Edge Function contract, JWT handling, server-calculated amount, verified checkout response, webhook idempotency, ledger reconciliation, refunds and payout tests.
7. **Reliability/compliance:** logging, retries, dead letters, recovery, privacy, market-specific compliance and support.
8. **Growth:** only after partner capacity and operational quality are proven; use lawful sourcing, suppression/unsubscribe, approval gates and audit logs.
9. **Live release:** independent review, documented test evidence and staged corridor launch. Keep live Razorpay credentials disabled until all payment/security/operational gates pass.

## Change management
The lifecycle checklist and browser-local audit board are being prepared on branch `krim/global-lifecycle-blueprint` in draft PR #4. They do not alter production Supabase. Do not merge merely to imply that the platform is complete; review the inventory and keep the implementation work evidence-driven.
