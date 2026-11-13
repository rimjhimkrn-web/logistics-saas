# Step 29 — Backend authorization and database access audit

Date: 2026-11-13
Production project: `ebltviniygljwwseplph`
Branch under review: `website/global-launch-readiness`
PR #65 remains draft, unmerged and undeployed.

## Scope and method

Read-only inspection of production PostgreSQL catalog metadata, RLS policy definitions, SECURITY DEFINER function grants/definitions, selected partner/admin/vehicle workflows, relevant migration source, and current Supabase Security Advisor findings. No user rows or document contents were queried.

## Positive controls observed

- All 378 tables in the exposed `public` schema have RLS enabled; zero public tables were found with RLS disabled.
- The only public view returned by the view inventory query, `public.partner_rating_summary`, has `security_invoker=true`.
- The checked `private.krim_has_permission` implementation requires active user-role assignment, active organization membership and active organization status before granting a permission.
- Sampled cross-workspace read policies for invoices, settlements, exceptions, shipment alerts/customs/milestones use organization permission checks or shipment ownership/permission joins rather than blanket authenticated access.
- The inspected partner capacity registration and service-capability submission SECURITY DEFINER functions validate `auth.uid()`, active membership/partner.manage permission, current compliance, verified capability, and private evidence paths.
- The sampled vehicle administration routines call `krim_vehicle_admin_guard()`, which requires an authenticated AAL2 session and `admin.platform` permission.
- AAL2 enforcement is also present in the inspected global rate-card administration migration and the proposed partner verification migration.
- The public function inventory query found no SECURITY DEFINER functions executable by `anon`; 126 are executable by `authenticated` and are flagged by Supabase Advisor.

## Findings and risk interpretation

### 1. 26 RLS-enabled tables have no policies

Supabase Advisor reports 26 tables with RLS enabled and no policies: five private backend tables and 21 public-schema tables, including corridor/country-pack, market-readiness, partner-compliance and pricing evidence/control tables.

RLS with no policies is generally fail-closed for ordinary roles, not proof of a data leak. However, these tables need explicit owner/service-role access-path review and confirmation that no required user-facing workflow is unintentionally blocked. Do not add broad policies just to silence the warning.

### 2. 126 SECURITY DEFINER routines are callable by authenticated users

This is a significant review surface, but the Advisor warning alone does not prove unauthorized access: these routines are intentionally used as RPC endpoints and many have internal authorization checks. The inspected samples use explicit user/permission checks or delegate to guarded routines.

A complete per-function authorization review and targeted negative tests are still required. The warning should not be cleared by blanket revocation, because doing so could break legitimate workflows.

### 3. Leaked-password protection is disabled

Supabase Advisor reports leaked-password protection disabled. Enable it in Supabase Auth security/password settings after confirming the intended password policy and then test signup, reset and password-change flows.

### 4. Legacy localStorage guard dependency inventory not completed

The attempt to scan every JavaScript/TypeScript source file exceeded the connector's call limit. This audit therefore does not claim that all routes have been proven independent of the legacy `js/guards.js` and `js/session.js` scripts. Continue with a narrower reference inventory and verify backend RLS/RPC enforcement for every protected page.

### 5. Cross-tenant isolation not dynamically tested

No authenticated customer/partner/driver/warehouse/finance/admin sessions were used. No synthetic cross-organization reads or writes, anonymous RPC calls, role escalation attempts, replay tests or storage object access attempts were performed. RLS catalog inspection is not a substitute for negative integration tests.

## Safety and change log

- Production SQL was read-only catalog/metadata inspection; no INSERT/UPDATE/DELETE/DDL.
- No production or staging schema changes.
- No accounts, real customer data, secrets, storage documents, payments, emails or webhooks accessed or changed.
- No function grants changed, no migration applied, no deployment or merge.
- No code fix committed in this step; identified issues require staged, function-specific changes after migration parity is resolved.

## Result

Step 29 is a read-only backend authorization audit. It confirms broad RLS coverage and several sound permission/AAL2 patterns, but does not certify the complete RPC surface or cross-tenant isolation. Highest-priority next work: enable leaked-password protection, complete the 126-function authorization inventory, resolve the 26 no-policy table access paths deliberately, and run controlled negative isolation tests on a schema-faithful staging environment.
