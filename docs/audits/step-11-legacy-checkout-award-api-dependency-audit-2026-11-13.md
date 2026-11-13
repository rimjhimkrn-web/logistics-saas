# KRIM Customer Journey — Step 11: Legacy Checkout Award API Dependency Audit

**Audit date:** 2026-11-13  
**Disposition:** **BLOCKED — no first-party browser caller was identified in the reviewed surfaces, but the authenticated database RPC remains an exposed API and cannot yet be safely revoked without a complete dependency and migration-parity review.**

## Scope

Reviewed the working branch `website/global-launch-readiness` after the Step 10 UI pause:
- `public/shipper/payment-checkout.html`
- `public/customer/quote-acceptance.html` (legacy redirect)
- `public/quotes/quote-acceptance.html` (legacy redirect)
- `public/customer-os/quotes-pricing/quote-acceptance.html` and its previously audited `assets/quote-operations.js` caller
- `supabase/migrations/20261111120000_secure_global_quote_acceptance_partner_assignment.sql`
- Step 10 status/caller inventory.

## Findings

### 1. No direct browser caller identified in the reviewed pages

The two legacy quote-acceptance routes are redirects to the canonical Customer OS page; they do not invoke an award RPC. The canonical Customer OS acceptance handler and primary shipper quote comparison UI have already been paused on this branch.

The payment-readiness page `public/shipper/payment-checkout.html` reads the exact quote, shipment, customer organization and accepted assignment, then uses the existing secure payment-order flow. The inspected source contains no call to `krim_award_partner_quote_for_checkout`. It is a payment-readiness/order surface, not an assignment-award creator.

This is a focused first-party browser review, not proof that no external, server-side, unpublished or stale client can call the RPC.

### 2. The database RPC remains a callable alternate authority

The Step 10 read-only production privilege inspection found:
- `authenticated`: EXECUTE allowed
- `anon`: EXECUTE denied
- `service_role`: EXECUTE allowed

The previously inspected production definition can create an offered assignment and write an accepted customer quote before partner acceptance. That sequencing is incompatible with KRIM's partner-direct commercial model.

Disabling buttons and removing browser callers does not secure a SECURITY DEFINER RPC that remains executable by authenticated users.

### 3. The proposed quote-acceptance migration does not retire the checkout RPC

`20261111120000_secure_global_quote_acceptance_partner_assignment.sql` hardens `krim_accept_global_quote(bigint)`. It does not replace, revoke or neutralize `krim_award_partner_quote_for_checkout(bigint,timestamptz)`.

The follow-up partner-eligibility migration also does not retire the checkout award path. Therefore these proposals, even if applied, would not by themselves establish one finalization authority.

## Required remediation decision

Preferred target:
1. Retire `krim_award_partner_quote_for_checkout(bigint,timestamptz)` as a commercial state-changing API.
2. Before revoking authenticated EXECUTE, complete a repository-wide source scan including Edge Functions, RPC wrappers, generated clients, admin/operations surfaces, scheduled jobs and external integration contracts.
3. Inspect dependent triggers and function-to-function calls in the live database; distinguish direct user entry points from internal helper dependencies.
4. If internal dependencies remain, split the internal implementation into a narrowly granted private helper and make the public legacy RPC fail closed. Do not simply revoke service-role execution if a trusted internal workflow still depends on it.
5. Revoke authenticated EXECUTE only in a migration after migration-parity staging tests prove no supported workflow depends on it.
6. Make partner response the single atomic finalization transaction: on partner acceptance, validate exact assignment/partner quote/opportunity/shipment/customer quote/leg relationships and current eligibility, then persist accepted assignment + customer quote + confirmed shipment together. Rejection/expiry must leave no accepted customer quote.
7. Keep freight payment customer-to-partner. Do not route the partner's freight charge through KRIM checkout.

## Verification required before implementation

- Confirm exact deployed signature, owner, SECURITY DEFINER/search_path, ACL and dependent objects from the live catalog.
- Enumerate all SQL functions and triggers that call this RPC.
- Search all repository source and deployment artifacts for the function name, including case/format variants and generated bundles.
- Build migration-parity staging; current staging is empty and is not a safe test target.
- Test direct authenticated RPC invocation, duplicate calls, concurrent awards, partner rejection/expiry, stale quote records, rollback and audit events.
- Recheck all payment entry points separately; this audit does not certify Razorpay merchant eligibility or settlements.

## Safety boundary

This step used branch source inspection and prior read-only production privilege/function findings. No production database changes, grant changes, payment actions, partner awards/responses, customer quote acceptance, migration application, merge or deployment were performed. PR #65 remains draft/unmerged/undeployed.

## Exit decision

**Step 11 audit complete; implementation remains BLOCKED.** No first-party browser dependency was identified in the reviewed legacy surfaces, but the authenticated RPC is still exposed. Do not claim production acceptance security or commercial launch readiness until the dependency scan, staging parity, backend retirement and atomic partner-acceptance tests are complete.
