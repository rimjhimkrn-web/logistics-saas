# Step 56 — Remaining payment and checkout entry-point audit
Date: 2026-11-13
Repository: rimjhimkrn-web/logistics-saas
Reviewed ref: 11bd7c7c57b373c6993b837c26641ca752d9695d (PR #65 head)
Scope: read-only source audit of remaining customer mobile, partner mobile, finance, billing, customer workspace and quote-result payment surfaces. No production endpoint invocation, provider API call, database write, deployment or secret access.

## Executive result
**A live-code bypass remains in the customer mobile app source.** The native customer app still renders a “Pay securely” action for an accepted quote + confirmed shipment, invokes `create-global-razorpay-order`, launches Razorpay Checkout in a WebView, then invokes `verify-razorpay-payment`. This contradicts KRIM's selected partner-direct commercial model and bypasses the website-only UI restrictions documented in earlier steps. The deployed order Edge Function was separately found in Step 53 to lack a partner-direct server-side block, so this mobile caller can reach a real order-creation path if the function's other checks pass. This is a **critical launch blocker** until the mobile client is disabled/rewired and the server-side guard is independently implemented and verified.

## Confirmed findings

### F56-01 — Customer mobile has active freight checkout code (Critical)
File: `mobile/krim-customer/src/CustomerWorkspace.tsx`
- Lines 95–110: `startPayment` validates accepted quote, confirmed shipment and quote expiry, then invokes `create-global-razorpay-order`.
- Lines 112–128: payment success data is submitted to `verify-razorpay-payment`; success message treats payment as reconciled.
- Line 211: customer Quotes tab displays a “Pay securely” button for accepted quote + confirmed shipment.
- Lines 239–255: WebView hosts Razorpay Checkout JS and opens the provider checkout.
- No partner-direct warning or UI-level kill switch appears in this code path.
Assessment: not merely a stale label; this is executable client-side integration code. The function's own server-side authorization may reject some records, but Step 53 found no partner-direct model guard in deployed function v24. Do not test by initiating a real payment.

### F56-02 — Web quote-result page blocks order creation (Pass, source-level)
File: `public/quote-result.html`
- Lines 7–8 retain stale metadata/title describing secure Razorpay checkout / partner payment confirmation.
- Visible body says partner-direct payments and KRIM freight checkout disabled (lines 109–112).
- `startPayment()` sets gateway to partner-direct only, shows direct-partner instructions and explicitly says no KRIM order is created (lines 231–237).
- Static source inspection found no order-creation or provider SDK invocation in this page.
Assessment: operational control is present in the page logic, but metadata/title/legacy copy should be corrected to avoid misleading browser/search previews and user expectations.

### F56-03 — Finance and billing pages mostly communicate disabled collection (Pass, source-level)
Reviewed:
- `public/finance/payment-methods.html`: India method entry states KRIM freight checkout disabled under partner-direct model.
- `public/finance/payment-gateways.html`: adapter present / checkout disabled; explains customers pay contracted partner directly. Its CTA still links to the legacy-named quote-result page, which is now a guidance/partner-direct page.
- `public/billing/escrow-settlement.html`: explicitly says escrow/automated payouts are not offered and warns users not to send freight funds to KRIM.
- `app/finance/payment-processing.html`: read-only payment register and manual review preparation; explicitly states no financial transaction is executed from this page.
- `app/enterprise/finance.html`: no payment checkout invocation found in the inspected page.

### F56-04 — Partner mobile does not expose Razorpay checkout in inspected workspace (Pass, source-level)
File: `mobile/krim-partner/src/PartnerWorkspace.tsx`
No Razorpay, Cashfree, checkout order creation or provider invocation tokens found in the inspected source.

### F56-05 — Customer OS operation modules are not order-creation callers in inspected source (Pass, source-level)
Files:
- `public/customer-os/assets/quote-operations.js`
- `public/customer-os/assets/shipment-operations.js`
No provider/order-creation invocation tokens found in these inspected modules.

## Risk / launch decision
- **Do not enable customer mobile production distribution or invite customers to use its payment action** while F56-01 remains.
- Disable/remove the native customer app payment action and WebView checkout implementation for the partner-direct release; replace with clear “Contact your contracted logistics partner directly” instructions.
- Separately add the previously proposed unconditional server-side block to the deployed canonical order function and set the INR/Razorpay registry checkout flag false. Those production changes require explicit approval and safe staging; they were not performed here.
- Correct stale quote-result title and description metadata in a later branch-only change.
- After changes, perform static caller inventory across all mobile apps and workspaces, then safe non-production tests proving the canonical order endpoint rejects direct calls under partner-direct mode. No live payment test.
- This audit is targeted source inspection, not exhaustive dynamic testing of every built APK, cached bundle, browser route, or API caller. Confirm the exact distributed mobile build/version before release.

## No changes made
No code changes to runtime files, no production DB/function changes, no provider calls, no payment initiation, no migrations, no deployment, and no secret access. This report only is added to the existing unmerged PR branch.
