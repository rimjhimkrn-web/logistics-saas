# KRIM Global Logistics OS — Execution Status
**Audit date:** 2026-10-16  
**Working branch:** `krim/global-lifecycle-foundation`  
**Production Supabase project:** `logistics-saas` (`ebltviniygljwwseplph`)  
**Rule:** A filename or dashboard card is not evidence that a workflow is operational.

## Verified repository baseline
- GitHub repository tree at audit start: **625 tracked files**.
- Main public entry points include root `index.html`, `public/get-started.html`, `auth/signup.html`, `auth/partner-signup.html`, `auth/login.html`, `public/quote.html`, and `public/quote-result.html`.
- The repository tree had **no `supabase/` directory** and **no `.github/workflows/` files** at audit time. The live database has migration history, but the SQL migration source files are not yet reproducibly version-controlled in this repository.
- The public pages use several different URL conventions. GitHub Pages serves the site beneath `/logistics-saas/`, so root-absolute links such as `/portal.html` can point to the wrong path. Use relative links or the shared `window.krimPath()` helper.
- Some onboarding pages were presentation-only: the shipper and partner signup handlers showed an alert and redirected without creating an account.
- The old callback referenced `auth/js/auth-core.js`, which was not present at that path in the repository tree.
- `core/krim-config.js` still contained a placeholder Supabase URL/key; any module using that configuration would not connect to the actual project.
- `public/app/app-runtime.js` contained a demonstration fallback that created a fake local auth session. Demo state must never be treated as authentication and this needs removal before any workspace is considered secure.
- The repository has overlapping entry points and page families. Do not mass-create duplicate files; first map existing files to one canonical route per capability.

## Verified Supabase baseline
- Project status: `ACTIVE_HEALTHY`; database engine: PostgreSQL 17.
- The live database has migration history for global partner lifecycle, organization provisioning, RLS/grants, workflow retries/dead-letter handling, global finance, developer API, and customer/partner quote and assignment lifecycle.
- Active Edge Functions observed: `razorpay-webhook`, `krim-ai`, `create-global-razorpay-order`, `verify-razorpay-payment`, `krim-notification-provider-adapter`, `global-admin-control`, `krim-global-growth-operations`, `create-razorpay-order`, and `process-payment--`.
- The deployed payment processor name observed is **`process-payment--`** (two trailing hyphens), not `process-payment`. Frontend endpoint and function request/response contracts must be aligned before checkout is enabled.
- Security advisors reported seven authenticated-callable `SECURITY DEFINER` RPC warnings and disabled leaked-password protection. Inspect each function's body, grants, and authorization logic before deciding whether to revoke execution or change its security mode. Do not blindly alter provisioning or partner workflow RPCs.
- Performance advisors reported a row-level security policy initialization warning on `revenue_ledger` and many unused indexes. Unused indexes should not be removed without workload evidence.
- No production Razorpay live-key switch, real partner acquisition campaign, or real payout activation is authorized by this audit document.

## Changes started on this branch
- [x] Replace shipper signup demo alert with Supabase Auth signup and `krim_provision_customer_organization`.
- [x] Replace partner signup demo alert with Supabase Auth signup and `krim_provision_partner_organization`.
- [x] Route login organization provisioning by account onboarding intent (customer vs partner).
- [x] Repair email verification callback so it uses the shared Supabase client and provisions the correct organization type.
- [ ] Verify email-confirmation redirect URLs are allowlisted in Supabase Auth.
- [ ] Run real browser tests for signup, email verification, login, MFA, and role routing.
- [x] Connect partner onboarding form to private document storage and the `krim_submit_partner_onboarding` RPC; browser/storage/RPC execution still needs a live test.
- [x] Repair root-absolute links and the broken callback import in the critical signup/login/checkout/onboarding path; the full 625-file site still needs a global link audit.
- [x] Replace placeholder Supabase configuration in `core/krim-config.js` with the project URL and publishable key.
- [x] Remove fabricated workspace identity, organization, notifications, permissions, and demo local session; runtime now requires a real Supabase session and fails closed for unavailable permissions.
- [ ] Establish canonical route registry and check all navigation buttons.
- [ ] Inventory every page's data source, action contract, role policy, loading state, empty state, and error state.
- [ ] Reconcile live Supabase schema with version-controlled SQL migrations without recreating existing objects.
- [ ] Resolve security advisor findings with tests.
- [ ] Audit Razorpay order creation, signature verification, webhooks, ledger writes, refunds, and settlement idempotency.
- [x] Add initial GitHub Actions onboarding integrity checks; comprehensive browser, security, release and rollback tests remain pending.
- [ ] Prove customer and partner lifecycle end to end in test mode before considering production payment keys.

## Production readiness gates
1. **No demo auth:** no fake local session may unlock any page or action.
2. **One route per workflow:** all Get Started, Sign In, back, and dashboard links resolve under GitHub Pages and any configured custom domain.
3. **Backend authorization:** all data mutations and protected reads are enforced by Supabase RLS/RPC/Edge Functions, not merely hidden in the UI.
4. **Customer lifecycle:** register → verify → provision organization → quote → accept → shipment → tracking → delivery/POD → invoice/payment/support.
5. **Partner lifecycle:** register → verify → submit documents → review/approval → publish capacity → receive/accept load → execute → POD → payable/settlement.
6. **Finance correctness:** server-authoritative amount; verified payment signature; trusted webhook; idempotent ledger; reconciled refunds and payouts.
7. **Security:** no critical advisor findings, no privileged secrets in browser code, tenant isolation tests pass, backup/restore and incident runbooks are tested.
8. **Release evidence:** CI and end-to-end tests pass; deployment and rollback are documented.
9. **Commercial readiness:** partner supply and service coverage are real and verified before broad customer marketing.
10. **Live keys:** enable only after all previous gates and an explicit controlled cutover checklist.

## Working rule
Make small, auditable changes on this branch, preserve existing design components, verify every change, then review the diff before merging to `main`. Never label a lifecycle complete until there is test evidence.


## Branch verification snapshot (after initial changes)
- Branch: `krim/global-lifecycle-foundation`.
- Static checks across 12 critical files: all required files present, expected integration markers found, no forbidden demo markers found, and no broken relative references in the checked HTML pages.
- Inline JavaScript syntax check: passed for the seven changed/critical HTML entry pages.
- GitHub Actions execution and browser-based verification: not yet confirmed.
- Supabase Auth email redirect allowlist: not yet confirmed.
- The live Supabase security advisor findings remain open; no live Razorpay keys should be enabled.
