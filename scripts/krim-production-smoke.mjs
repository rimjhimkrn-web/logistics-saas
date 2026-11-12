import { readFileSync, existsSync, writeFileSync, unlinkSync, readdirSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join, dirname, resolve as pathResolve } from "node:path";

const required = [
  "public/quote-result.html",
  "public/payment-verification.html",
  "public/shipment-confirmation.html",
  "public/finance/payment-result.html",
  "public/shipper/spot-approvals.html",
  "public/partner/accepted-loads.html",
  "public/partner/dispatch-assignment.html",
  "app/customs/index.html",
  "app/warehouse/index.html",
  "app/operations/index.html",
  "public/operations/index.html",
  "config.js",
  "public/krim-global-operations.js",
  "supabase/migrations/20261024100000_krim_global_operations_records_backend.sql",
  "core/krim-global-interface.css",
  "auth/access.html",
  "auth/signup.html",
  "auth/login.html",
  "auth/forgot-password.html",
  "auth/reset-password.html",
  "auth/auth-callback.html",
  "auth/mfa-enroll.html",
  "auth/logout.html",
  "auth/verify-email.html",
  "public/shipper/booking-request.html",
  "public/shipper/coverage-review.html",
  "app/customer/index.html",
  "platform/krim-supabase.js",
  "supabase/migrations/20261018193607_implement_rate_card_backed_tariff_quotes.sql",
  "supabase/migrations/20261019100000_restore_rate_card_backed_tariff_quotes.sql",
  "supabase/migrations/20261019000100_fail_closed_tariff_quotes_without_approved_rate_cards.sql",
  "supabase/migrations/20261019020919_restrict_privileged_krim_rpc_to_authenticated.sql",
  "supabase/functions/create-global-razorpay-order/index.ts",
  "supabase/functions/verify-razorpay-payment/index.ts",
  "docs/global-payment-provider-expansion-plan.md",
  "supabase/functions/process-payment--/index.ts",
  "public/customer-os/customer-services/shipment-list.html",
  "public/customer-os/customer-services/shipment-details.html",
  "public/customer-os/customer-services/shipment-timeline.html",
  "public/customer-os/customer-services/tracking-map.html",
  "public/customer-os/customer-services/recurring-shipments.html",
  "public/customer-os/customer-services/saved-routes.html",
  "public/customer-os/customer-services/shipping-preferences.html",
  "public/customer-os/customer-services/cargo-profiles.html",
  "public/customer-os/customer-services/returns.html",
  "public/shipments/shipment-create.html",
  "public/customer-os/customer-services/invoices.html",
  "public/customer-os/customer-services/support.html",
  "public/customer-os/customer-services/claims.html",
  "public/customer-os/customer-services/payment-history.html",
  "public/shipper/quote-comparison.html",
  "public/customer/quote-request.html",
  "public/shipper/payment-checkout.html",
  "app/partner/index.html",
  "public/partner/partner-onboarding.html",
  "public/partner/load-marketplace.html",
  "public/partner/available-loads.html",
  "public/partner/submit-quote.html",
  "public/partner/quote-history.html",
  "public/partner/accepted-loads.html",
  "public/shipper/booking-request.html",
  "public/shipper/active-shipments.html",
  "public/shipper/spot-approvals.html",
  "public/shipper/quote-comparison.html",
  "control/partner-verification.html",
  "supabase/migrations/20261020074510_global_partner_onboarding_location_hardening.sql",
  "supabase/migrations/20261020074900_partner_verification_admin_review_workflow.sql",
  "supabase/migrations/20261020133000_partner_account_modes_test_and_individual_interest.sql",
  "supabase/migrations/20261020141000_add_partner_account_mode_column.sql",
];

const failures = [];

// Do not advertise retired Cashfree placeholders as active payment providers.
// These files are deliberately fail-closed until real adapters and tests replace them.
for (const retiredProviderPath of [
  "supabase/functions/create-global-cashfree-order/index.ts",
  "supabase/functions/verify-global-cashfree-payment/index.ts",
  "supabase/functions/cashfree-payment-webhook/index.ts",
]) {
  if (!existsSync(retiredProviderPath)) {
    failures.push(`Retired Cashfree endpoint source is missing: ${retiredProviderPath}`);
    continue;
  }
  const retiredProviderSource = readFileSync(retiredProviderPath, "utf8");
  if (!retiredProviderSource.includes("PAYMENT_PROVIDER_RETIRED") || !retiredProviderSource.includes("status: 410")) {
    failures.push(`Cashfree endpoint must remain retired until a tested adapter is implemented: ${retiredProviderPath}`);
  }
}

// Retired legacy payment endpoint must remain fail-closed. The canonical checkout
// uses create-global-razorpay-order + verify-razorpay-payment; this legacy route
// previously wrote financial records without tying the provider payment to the
// authenticated user's exact canonical payment order.
const retiredPaymentPath = "supabase/functions/process-payment--/index.ts";
if (!existsSync(retiredPaymentPath)) {
  failures.push("Legacy payment endpoint retirement source is missing.");
} else {
  const retiredPaymentSource = readFileSync(retiredPaymentPath, "utf8");
  if (!retiredPaymentSource.includes("LEGACY_PAYMENT_ENDPOINT_RETIRED") || !retiredPaymentSource.includes("status: 410")) {
    failures.push("Legacy payment endpoint must return HTTP 410 and an explicit retired marker.");
  }
  if (/from\(["']revenue_ledger["']\)|from\(["']krim_shipments["']\)\.update/.test(retiredPaymentSource)) {
    failures.push("Retired legacy payment endpoint must not write revenue or shipment state.");
  }
}

// Canonical Razorpay lifecycle source guards. These are static regression checks,
// not a substitute for sandbox API tests or a live provider test transaction.
const razorpayCreatePath = "supabase/functions/create-global-razorpay-order/index.ts";
const razorpayVerifyPath = "supabase/functions/verify-razorpay-payment/index.ts";
const razorpayWebhookPath = "supabase/functions/razorpay-webhook/index.ts";
const razorpayCreateSource = existsSync(razorpayCreatePath) ? readFileSync(razorpayCreatePath, "utf8") : "";
const razorpayVerifySource = existsSync(razorpayVerifyPath) ? readFileSync(razorpayVerifyPath, "utf8") : "";
const razorpayWebhookSource = existsSync(razorpayWebhookPath) ? readFileSync(razorpayWebhookPath, "utf8") : "";
if (!razorpayCreateSource) failures.push("Canonical Razorpay order-creation source is missing.");
for (const token of ['krim_payment_capability_registry', 'merchant_eligibility_verified', 'settlement_supported', 'refunds_supported', 'fx_supported', 'payment_provider: "razorpay"', 'rzp_test_', 'rzp_live_', 'PAYMENT_KEY_MODE_UNVERIFIED', 'PAYMENT_LIVE_CAPABILITIES_UNVERIFIED']) {
  if (!razorpayCreateSource.includes(token)) failures.push("Razorpay checkout capability/provider guard is missing: " + token);
}
if (!razorpayVerifySource.includes('.eq("status", paymentOrder.status)') ||
    !razorpayVerifySource.includes('currentOrder.razorpay_payment_id !== razorpayPaymentId') ||
    !razorpayVerifySource.includes('refusing to overwrite its payment state')) {
  failures.push("Razorpay verification must use a conditional payment-order transition and reject conflicting concurrent payment IDs.");
}
for (const token of ['razorpay_payment_id', 'razorpay_order_id', 'razorpay_signature', 'razorpayPayment.order_id', 'razorpayPayment.amount', 'razorpayPayment.currency', 'razorpayStatus !== "captured"', 'krim_shipment_partner_assignments', 'partner_quote_id']) {
  if (!razorpayVerifySource.includes(token)) failures.push("Razorpay verification must bind payment to the provider order, amount, currency, captured state and accepted partner quote: " + token);
}
for (const token of ['capacity_binding_id', 'krim_capacity_leg_bindings', 'krim_capacity_reservations', 'CAPACITY_RESERVATION_REQUIRED', 'CAPACITY_BINDING_NOT_CONFIRMED', 'CAPACITY_RESERVATION_NOT_CONFIRMED']) {
  if (!razorpayVerifySource.includes(token)) failures.push("Razorpay payment verification must re-check the accepted assignment's exact confirmed capacity binding and reservation: " + token);
}
for (const token of ['x-razorpay-signature', 'x-razorpay-event-id', 'payment_orders', 'amount_paise', 'PAYMENT_ORDER_MISMATCH', 'webhookPaymentStatus !== "captured"']) {
  if (!razorpayWebhookSource.includes(token)) failures.push("Razorpay webhook verification guard is missing: " + token);
}
if (!razorpayWebhookSource.includes('webhookCurrency !== expectedCurrency') || !razorpayWebhookSource.includes('webhookAmount !== expectedAmount')) {
  failures.push("Razorpay webhook must compare provider amount and currency against the canonical payment order.");
}

// Regression guard for executable amount/currency/status validation.
// Both payment.captured and order.paid are accepted only through the same
// payment-entity checks above (payment ID, amount, currency and captured state).
if (razorpayWebhookSource.includes("/*\\n// Fail closed unless the signed provider event") ||
    razorpayWebhookSource.includes("/*\\n* Fail closed unless the signed provider event")) {
  failures.push("Razorpay webhook payment validation must not be enclosed in a block comment.");
}
if (razorpayWebhookSource.includes('eventType === "order.paid"') &&
    (!razorpayWebhookSource.includes('webhookPaymentStatus !== "captured"') ||
     !razorpayWebhookSource.includes('webhookAmount !== expectedAmount') ||
     !razorpayWebhookSource.includes('webhookCurrency !== expectedCurrency'))) {
  failures.push("Razorpay order.paid must share the validated payment entity amount, currency and captured-state checks.");
}
if (!razorpayWebhookSource.includes("if (existingEvent?.processed)") ||
    !razorpayWebhookSource.includes("if (!existingEvent)")) {
  failures.push("Razorpay webhook must allow retry of previously stored but unprocessed events.");
}
if (!razorpayWebhookSource.includes('eq("razorpay_order_id", razorpayOrderId)') ||
    !razorpayWebhookSource.includes('eventType === "payment.failed"')) {
  failures.push("Razorpay failed-payment handling must resolve the canonical payment order by provider order ID.");
}




// Public contact/support pages must not claim success or show invented ticket data.
const contactPath = "public/contact.html";
if (existsSync(contactPath)) {
  const contact = readFileSync(contactPath, "utf8");
  if (contact.includes("Inquiry transmitted successfully") || contact.includes("will contact you shortly")) {
    failures.push("Public contact form contains an unverified success/response claim.");
  }
  if (!contact.includes("krim-public-contact-inquiry") || !contact.includes("form.addEventListener('submit'")) {
    failures.push("Public contact form is not wired to the deployed inquiry endpoint.");
  }
}
const supportPath = "public/support/ticket-desk.html";
if (existsSync(supportPath)) {
  const support = readFileSync(supportPath, "utf8");
  if (support.includes("TKT-2026-9912") || support.includes("Global Supply Chain Corp") || support.includes("Creating New Support Ticket") || support.includes("Opening Ticket Resolution Workspace")) {
    failures.push("Support desk contains fabricated ticket rows or fake action alerts.");
  }
  if (!support.includes("Live ticket register not connected")) {
    failures.push("Support desk must disclose that the live ticket register is not connected.");
  }
}



// Audit guard: the public E2E dashboard must never claim tests passed unless a real
// runner and recorded execution evidence are connected. A display-only page must say NOT RUN.
const e2eDashboardPath = "public/testing/e2e-test-runner.html";
if (existsSync(e2eDashboardPath)) {
  const dashboard = readFileSync(e2eDashboardPath, "utf8");
  if (/100% Passing Rate|ALL SUITES GREEN|Executing full E2E test suite[\s\\S]*?All tests passed successfully|Zero Downtime Failover/i.test(dashboard)) {
    failures.push("E2E dashboard contains fabricated/unverified test-success claims.");
  }
  if (!/NOT RUN|Runner Not Connected/i.test(dashboard)) {
    failures.push("E2E dashboard must disclose that no live runner is connected and no tests were executed.");
  }
} else {
  failures.push("Public E2E dashboard is missing; audit its replacement before removing this guard.");
}

 // Global interface conformance across Phases 2–5: one shared stylesheet is loaded last,
 // so page-local styles cannot silently replace the approved design tokens and components.
 const phaseTwoToFiveInterfacePages = [
   "app/customer/index.html",
   "public/shipper/booking-request.html",
   "public/shipper/coverage-review.html",
   "public/shipper/rate-calculator.html",
   "public/shipper/active-shipments.html",
   "public/customer/shipment-create.html",
   "public/customer-os/customer-services/shipment-list.html",
   "public/shipper/spot-approvals.html",
   "public/shipper/quote-comparison.html",
   "public/customer/quote-request.html",
   "public/shipper/payment-checkout.html",
   "public/quote-result.html",
   "public/payment-verification.html",
   "public/finance/payment-result.html",
   "public/shipment-confirmation.html",
   "public/customer-os/customer-services/payment-history.html",
 ];
 for (const file of phaseTwoToFiveInterfacePages) {
   if (!existsSync(file)) { failures.push(`Missing global-interface page: ${file}`); continue; }
   const html = readFileSync(file, "utf8");
   const head = html.slice(0, html.toLowerCase().lastIndexOf("</head>"));
   const stylesheetCount = (head.match(/krim-global-interface\.css/g) || []).length;
   if (stylesheetCount !== 1) failures.push(`Page must include the shared global stylesheet exactly once: ${file}`);
   if (!/<body\b[^>]*class=["\'][^"\']*\bkrim-global-shell\b/i.test(html)) failures.push(`Page is missing the shared KRIM global shell: ${file}`);
   if (head.lastIndexOf("krim-global-interface.css") < head.lastIndexOf("</style>")) failures.push(`Global stylesheet must load after page-local styles: ${file}`);
 }

// Phase 2 customer-facing pages must share the approved global design layer.
const phase2InterfacePages = [
  "app/customer/index.html",
  "public/shipper/booking-request.html",
  "public/shipper/coverage-review.html",
  "public/shipper/rate-calculator.html",
  "public/shipper/active-shipments.html",
  "public/shipper/spot-approvals.html",
  "public/shipper/quote-comparison.html",
];
for (const file of phase2InterfacePages) {
  if (!existsSync(file)) {
    failures.push(`Missing Phase 2 customer page: ${file}`);
    continue;
  }
  const html = readFileSync(file, "utf8");
  if (!html.includes("krim-global-interface.css")) {
    failures.push(`Phase 2 page is missing the shared global stylesheet: ${file}`);
  }
  if (!/<body\b[^>]*class=["'][^"']*\bkrim-global-shell\b/i.test(html)) {
    failures.push(`Phase 2 page is missing the shared global shell class: ${file}`);
  }
}
// Phase 3 shipment creation: one canonical form, idempotent backend contract and safe legacy alias.
const canonicalShipmentForm = "public/shipper/booking-request.html";
const legacyShipmentAlias = "public/customer/shipment-create.html";
const customerWorkspace = "app/customer/index.html";
if (existsSync(canonicalShipmentForm)) {
  const html = readFileSync(canonicalShipmentForm, "utf8");
  if (!html.includes("krim_create_global_shipment_idempotent")) failures.push("Canonical shipment form must use the idempotent shipment-creation RPC.");
  if (!html.includes("getBookingRequestId")) failures.push("Canonical shipment form is missing its stable booking-request identifier.");
  if (!/submitting\s*=\s*true/.test(html)) failures.push("Canonical shipment form is missing duplicate-submit protection.");
  if (!html.includes("rate-calculator.html?shipment_id=")) failures.push("Canonical shipment form must continue to the quote/rate workflow with its real shipment reference.");
}
if (existsSync(legacyShipmentAlias)) {
  const html = readFileSync(legacyShipmentAlias, "utf8");
  if (!html.includes("../shipper/booking-request.html")) failures.push("Legacy shipment URL must forward to the canonical shipment form.");
  if (!html.includes("krim-global-interface.css")) failures.push("Legacy shipment alias must use the shared global interface.");
}
if (existsSync(customerWorkspace)) {
  const html = readFileSync(customerWorkspace, "utf8");
  if (html.includes("../../public/customer/shipment-create.html")) failures.push("Customer workspace still points to the legacy shipment form instead of the canonical route.");
  if (!html.includes("../../public/shipper/booking-request.html")) failures.push("Customer workspace must expose the canonical global shipment form.");
}

// Phase 4 pricing and quote governance: enforce canonical pages and server-authoritative commercial decisions.
const quoteDesk = "public/shipper/rate-calculator.html";
const quoteReview = "public/shipper/spot-approvals.html";
const quoteComparison = "public/shipper/quote-comparison.html";
for (const file of [quoteDesk, quoteReview, quoteComparison]) {
  if (!existsSync(file)) {
    failures.push(`Missing Phase 4 canonical quote workflow page: ${file}`);
    continue;
  }
  const html = readFileSync(file, "utf8");
  if (!html.includes("krim-global-interface.css")) failures.push(`Phase 4 page is missing the shared global stylesheet: ${file}`);
  if (!html.includes("krim-global-shell")) failures.push(`Phase 4 page is missing the shared global shell class: ${file}`);
}
if (existsSync(quoteDesk)) {
  const html = readFileSync(quoteDesk, "utf8");
  if (!html.includes('rpc("krim_create_tariff_quote"')) failures.push("Quote desk must request pricing from the server-side tariff RPC.");
  if (!html.includes('rpc("krim_create_partner_opportunity"')) failures.push("Quote desk must use the controlled partner-bid fallback when no tariff matches.");
  if (!/No approved price has been shown|No approved tariff matches|no customer price has been invented/i.test(html)) failures.push("Quote desk must clearly avoid displaying invented prices.");
  if (!html.includes("public/shipper/spot-approvals.html")) failures.push("Quote desk must route to the canonical quote and bid status page.");
}
if (existsSync(quoteReview)) {
  const html = readFileSync(quoteReview, "utf8");
  if (!html.includes('rpc("krim_accept_global_quote"')) failures.push("Quote review must use the server-side quote acceptance RPC.");
  if (!html.includes("valid_until")) failures.push("Quote review must inspect quote validity before acceptance.");
  if (!html.includes("public/shipper/rate-calculator.html")) failures.push("Quote review must link back to the canonical quote desk.");
}
if (existsSync(quoteComparison)) {
  const html = readFileSync(quoteComparison, "utf8");
  if (!html.includes("krim_accept_global_quote")) failures.push("Quote comparison must use the server-side quote acceptance RPC.");
  if (!/valid_until|valid until/i.test(html)) failures.push("Quote comparison must expose quote validity.");
  if (!/PREVIEW ONLY|Not a real quote|No live quotes|no quote/i.test(html)) failures.push("Quote comparison must distinguish empty/demo states from real customer offers.");
}

// Phase 5 partner-direct customer flow: KRIM freight payment is not a booking gate.
const paymentReadiness = existsSync("public/shipper/payment-checkout.html") ? readFileSync("public/shipper/payment-checkout.html", "utf8") : "";
const secureCheckout = existsSync("public/quote-result.html") ? readFileSync("public/quote-result.html", "utf8") : "";
const paymentVerification = existsSync("public/payment-verification.html") ? readFileSync("public/payment-verification.html", "utf8") : "";
const shipmentConfirmation = existsSync("public/shipment-confirmation.html") ? readFileSync("public/shipment-confirmation.html", "utf8") : "";
const customerRefunds = existsSync("public/customer-os/customer-services/refunds.html") ? readFileSync("public/customer-os/customer-services/refunds.html", "utf8") : "";
const customerHome = existsSync("public/customer-os/index.html") ? readFileSync("public/customer-os/index.html", "utf8") : "";
for (const [file, html] of [
  ["public/shipper/payment-checkout.html", paymentReadiness],
  ["public/quote-result.html", secureCheckout],
  ["public/shipment-confirmation.html", shipmentConfirmation],
]) {
  if (!html.includes("partner") || !/partner-direct/i.test(html)) failures.push(`Customer payment/confirmation route must explain partner-direct operation: ${file}`);
  if (/checkout\.razorpay\.com|new Razorpay|create-global-razorpay-order|Pay now|Confirm & pay/i.test(html)) failures.push(`Customer route contains an active or misleading freight checkout action: ${file}`);
}
if (!/pay your partner directly|pay the partner directly|pay only the partner/i.test(secureCheckout + paymentReadiness + shipmentConfirmation)) failures.push("Customer payment guidance must explicitly direct freight payment to the selected partner.");
if (!/partner/i.test(customerRefunds) || !/refund/i.test(customerRefunds)) failures.push("Customer refund route must explain partner-direct freight refund handling.");
if (/Confirm & pay|Payment checkout/i.test(customerHome)) failures.push("Customer homepage must not advertise KRIM freight checkout in partner-direct mode.");
if (!/payment_order_id/.test(paymentVerification) || !/krim-payment-verification-status/.test(paymentVerification)) failures.push("Historical payment verification must retain authenticated server-side status verification.");
for (const retiredPath of [
  "public/freight/forwarder-settlement.html",
  "public/finance/customer-invoices.html",
  "public/finance/tax-invoices.html",
  "public/finance/invoice-details.html",
  "public/finance/transaction-details.html",
  "public/finance/transaction-fees.html",
  "public/finance/accounts-payable.html",
  "public/finance/accounts-receivable.html",
  "public/finance/dispute-management.html",
  "public/support/payment-disputes.html",
  "public/support/refund-disputes.html",
]) {
  const source = existsSync(retiredPath) ? readFileSync(retiredPath, "utf8") : "";
  if (!source.includes("Not an active financial transaction workflow") || !/partner-direct launch controls/i.test(source)) failures.push("Legacy finance/support route must be clearly retired under partner-direct launch: " + retiredPath);
  if (/<form\b/i.test(source) || /handleSettlementSubmit|Generate Invoice|Finalize Freight Suite|Submit payment dispute|Submit refund dispute/i.test(source)) failures.push("Retired finance/support route must not expose a legacy form or fake financial action: " + retiredPath);
}
const paymentDisputesPage = existsSync("public/support/payment-disputes.html") ? readFileSync("public/support/payment-disputes.html", "utf8") : "";
const refundDisputesPage = existsSync("public/support/refund-disputes.html") ? readFileSync("public/support/refund-disputes.html", "utf8") : "";
if (!/authenticated KRIM support ticket workflow/i.test(paymentDisputesPage + refundDisputesPage)) failures.push("Payment and refund dispute guidance must direct platform issues to authenticated KRIM support.");
for (const retiredDemoPath of [
  "public/billing/financial-ledger-audit.html",
  "public/billing/freight-audit-disputes.html",
  "public/enterprise/billing-consolidation.html",
]) {
  const source = existsSync(retiredDemoPath) ? readFileSync(retiredDemoPath, "utf8") : "";
  if (!source.includes("Not an active financial transaction or dispute workflow") || !/partner-direct launch controls/i.test(source)) failures.push("Legacy finance demo must be explicitly retired: " + retiredDemoPath);
  if (/<form\b/i.test(source) || /Export GL Journal|Reject Line Item & Issue Debit Note|Accept Adjusted Amount|handleBillingSubmit/i.test(source)) failures.push("Retired finance demo must not retain a fake financial action: " + retiredDemoPath);
}
for (const retiredFinancePath of [
  "public/finance/api-keys.html",
  "public/finance/audit-logs.html",
  "public/finance/bank-accounts.html",
  "public/finance/bank-reconciliation.html",
  "public/finance/carrier-payables.html",
  "public/finance/cash-flow-forecast.html",
  "public/finance/compliance-rules.html",
  "public/finance/credit-notes.html",
  "public/finance/executive-dashboard.html",
  "public/finance/expense-reports.html",
]) {
  const source = existsSync(retiredFinancePath) ? readFileSync(retiredFinancePath, "utf8") : "";
  if (!source.includes("Not an active finance, bank, compliance or payout workflow") || !/partner-direct launch controls/i.test(source)) failures.push("Legacy finance screen must be explicitly retired: " + retiredFinancePath);
  if (/<form\b/i.test(source) || /SWIFT_BATCH_EXECUTE|Execute Transfer|Create Credit Note|Generate API Key|Initiate Payout/i.test(source)) failures.push("Retired finance screen must not retain a demo financial action: " + retiredFinancePath);
}
for (const retiredDashboardPath of [
  "public/finance/finance-dashboard.html",
  "public/finance/financial-consolidation.html",
  "public/finance/fraud-prevention.html",
  "public/finance/fx-hedging.html",
  "public/finance/liquidity-overview.html",
]) {
  const source = existsSync(retiredDashboardPath) ? readFileSync(retiredDashboardPath, "utf8") : "";
  if (!source.includes("Not an active finance, treasury, risk or monitoring workflow") || !/partner-direct launch controls/i.test(source)) failures.push("Legacy finance dashboard must be explicitly retired: " + retiredDashboardPath);
  if (/<form\b/i.test(source) || /Execute Hedge|Create Forward Contract|Approve Liquidity Transfer|Mark Fraud Resolved/i.test(source)) failures.push("Retired finance dashboard must not retain a demo financial action: " + retiredDashboardPath);
}
const shipperFinance = existsSync("public/shipper/invoices.html") ? readFileSync("public/shipper/invoices.html", "utf8") : "";
if (!/Historical Records|Historical Financial Records|partner-direct launch/i.test(shipperFinance) || !/Customers pay freight partners directly/i.test(shipperFinance)) failures.push("Shipper finance page must clearly identify historical records and partner-direct payment.");
if (/Platform commission|Partner payout|platform_commission,partner_payout/.test(shipperFinance)) failures.push("Customer-facing historical ledger must not expose internal commission or partner payout allocations.");
const partnerSettlementHistory = existsSync("public/partner/settlements.html") ? readFileSync("public/partner/settlements.html", "utf8") : "";
if (!/historical KRIM settlement records/i.test(partnerSettlementHistory) || !/does not initiate payouts/i.test(partnerSettlementHistory)) failures.push("Partner settlement register must be explicitly historical and read-only in partner-direct mode.");
for (const retiredTreasuryPath of [
  "public/finance/sweep-rules.html",
  "public/finance/treasury-dashboard.html",
]) {
  const source = existsSync(retiredTreasuryPath) ? readFileSync(retiredTreasuryPath, "utf8") : "";
  if (!source.includes("Not an active bank, treasury or transfer workflow") || !/partner-direct launch controls/i.test(source)) failures.push("Treasury page must be explicitly retired: " + retiredTreasuryPath);
  if (/<form\b/i.test(source) || /Create Sweep Rule|Execute Sweep|Initiate Transfer|Approve Bank Transfer/i.test(source)) failures.push("Retired treasury page must not expose a transfer action: " + retiredTreasuryPath);
}
const customerInvoicePage = existsSync("public/customer-os/customer-services/invoices.html") ? readFileSync("public/customer-os/customer-services/invoices.html", "utf8") : "";
if (!/HISTORICAL KRIM RECORDS/i.test(customerInvoicePage) || !/partner issues the freight invoice|logistics partner issues the freight invoice/i.test(customerInvoicePage)) failures.push("Customer invoice register must distinguish KRIM records from partner-issued freight invoices.");




if (/krim-payment-verification-status|payment_order_id|verified payment/i.test(shipmentConfirmation)) failures.push("Partner-direct shipment confirmation must not require a KRIM freight payment order or payment verification.");
if (!/accepted quotation|accepted quote/i.test(shipmentConfirmation) || !/partner confirmation/i.test(shipmentConfirmation)) failures.push("Partner-direct shipment confirmation must explain quote and partner confirmation steps.");
const legacyPaymentResult = existsSync("public/finance/payment-result.html") ? readFileSync("public/finance/payment-result.html", "utf8") : "";
if (/Payment Executed Successfully|€14,250\.00 EUR Transferred|TXN-2026-OCT-8842/.test(legacyPaymentResult)) failures.push("Legacy payment-result page contains a fictional hard-coded payment success.");
if (!/location\.replace/.test(legacyPaymentResult) || !/payment-verification\.html/.test(legacyPaymentResult)) failures.push("Legacy payment-result page must redirect to canonical verified payment status.");
const orderFn = existsSync("supabase/functions/create-global-razorpay-order/index.ts") ? readFileSync("supabase/functions/create-global-razorpay-order/index.ts", "utf8") : "";
if (!orderFn.includes("KRIM_COMMERCIAL_LAUNCH_MODE") || !orderFn.includes("FREIGHT_CHECKOUT_DISABLED")) failures.push("Razorpay order creation must have the server-side partner-direct launch-mode hard stop.");
const retiredFinancePages = [
  "public/billing/escrow-settlement.html",
  "public/billing/carrier-payables.html",
  "public/billing/customer-invoices.html",
  "public/finance/payment-gateways.html",
  "public/finance/payment-methods.html",
  "public/finance/refund-requests.html",
  "public/finance/refund-status.html",
  "public/finance/payment-verification.html",
  "public/finance/merchant-accounts.html",
  "public/finance/payment-history.html",
  "public/finance/webhooks.html",
  "public/enterprise/escrow-settlement.html",
];
for (const file of retiredFinancePages) {
  const html = existsSync(file) ? readFileSync(file, "utf8") : "";
  if (!/disabled|not an active|not offered|not a live/i.test(html)) failures.push("Legacy finance page must clearly disclose that the workflow is disabled: " + file);
  if (/Release Payout|Save Escrow Configuration|Settle →|Opening SWIFT|Payment Reminder Email Transmitted|JPMorgan \/ Citi Escrow Active|ACH\/SEPA disbursements/i.test(html)) failures.push("Legacy finance page contains an active-looking payout, escrow or payment action: " + file);
}
const publicPartnerSettlementPage = existsSync("public/partner/settlements.html") ? readFileSync("public/partner/settlements.html", "utf8") : "";
if (!publicPartnerSettlementPage.includes("Historical Settlement Records") || /<button[^>]*(?:payout|transfer|release)/i.test(publicPartnerSettlementPage)) failures.push("Partner settlement register must remain read-only historical data with no payout action.");

const paymentOptionsFn = existsSync("supabase/functions/krim-global-payment-options/index.ts") ? readFileSync("supabase/functions/krim-global-payment-options/index.ts", "utf8") : "";
const paymentCapabilityFn = existsSync("supabase/functions/krim-payment-capability-status/index.ts") ? readFileSync("supabase/functions/krim-payment-capability-status/index.ts", "utf8") : "";
if (!/selectable:\s*false/.test(paymentOptionsFn) || !/checkout_configured:\s*false/.test(paymentOptionsFn) || !/partner-direct mode/i.test(paymentOptionsFn)) failures.push("Global payment options must never expose provider checkout as selectable during partner-direct launch.");
if (!/const enabled = false/.test(paymentCapabilityFn) || !/partner_direct_disabled/.test(paymentCapabilityFn)) failures.push("Payment capability status must report checkout disabled regardless of registry configuration.");
const taxSettingsPage = existsSync("public/finance/tax-settings.html") ? readFileSync("public/finance/tax-settings.html", "utf8") : "";
if (!/Tax configuration is not active/i.test(taxSettingsPage) || !/NOT CONFIGURED · NOT VERIFIED · NOT FOR TAX RELIANCE/i.test(taxSettingsPage) || !/GST registration status/i.test(taxSettingsPage)) failures.push("Tax settings page must clearly state that tax configuration and registration status are not verified.");
if (/automated tax calculation|Configure multi-jurisdiction tax engines|reverse-charge VAT rules/i.test(taxSettingsPage)) failures.push("Tax settings page must not advertise unavailable automated tax configuration.");
const billingRuntime = existsSync("public/billing/billing-runtime.js") ? readFileSync("public/billing/billing-runtime.js", "utf8") : "";
if (!/intentionally inactive/i.test(billingRuntime) || !/return false/.test(billingRuntime) || !/KRIM freight rating is disabled/i.test(billingRuntime)) failures.push("Legacy browser billing runtime must remain inactive and must not assert ledger integrity or rate freight.");
if (/VERIFIED\)|Financial Settlement Engine Active|Debits == Credits/i.test(billingRuntime)) failures.push("Legacy browser billing runtime must not make unsupported ledger-integrity or settlement-engine claims.");
const partnerDirectPolicy = existsSync("public/legal/payment-policy.html") ? readFileSync("public/legal/payment-policy.html", "utf8") : "";
if (!/Customers pay the partner directly/i.test(partnerDirectPolicy) || !/does not collect or hold freight payments/i.test(partnerDirectPolicy) || !/legal and tax advisers/i.test(partnerDirectPolicy)) failures.push("Payment policy must disclose partner-direct freight payment and interim legal/tax review status.");
const refundGuidance = existsSync("refund.html") ? readFileSync("refund.html", "utf8") : "";
if (!/partner-collected freight payments/i.test(refundGuidance) || !/Mandatory consumer rights remain unaffected/i.test(refundGuidance)) failures.push("Public refund guidance must preserve customer rights and distinguish partner-collected freight refunds.");

for (const retiredPath of [
  "supabase/functions/create-razorpay-order/index.ts",
  "supabase/functions/process-payment--/index.ts",
  "supabase/functions/create-global-cashfree-order/index.ts",
  "supabase/functions/verify-global-cashfree-payment/index.ts",
  "supabase/functions/cashfree-payment-webhook/index.ts",
]) {
  const source = existsSync(retiredPath) ? readFileSync(retiredPath, "utf8") : "";
  if (!source.includes("410") || !/partner-direct mode/i.test(source) || /Use the KRIM (global )?Razorpay checkout/i.test(source)) failures.push("Retired payment endpoint must stay HTTP 410 and provide partner-direct guidance: " + retiredPath);
}

const verifyFn = existsSync("supabase/functions/verify-razorpay-payment/index.ts") ? readFileSync("supabase/functions/verify-razorpay-payment/index.ts", "utf8") : "";
for (const [label, source, pattern] of [
  ["order endpoint authenticates the bearer session", orderFn, /auth\.getUser\(token\)/],
  ["order endpoint derives the amount from the accepted quote", orderFn, /Number\(quote\.amount\)/],
  ["order endpoint checks accepted partner assignment", orderFn, /assignment\.status\s*!==\s*["']accepted["']/],
  ["order endpoint enforces verified payment capability", orderFn, /krim_payment_capability_registry[\s\S]*?checkout_enabled/],
  ["verification checks HMAC signature", verifyFn, /generateHmacSha256[\s\S]*?razorpaySignature/],
  ["verification independently fetches provider payment", verifyFn, /api\.razorpay\.com\/v1\/payments/],
  ["verification requires captured status", verifyFn, /razorpayStatus\s*!==\s*["']captured["']/],
  ["verification checks amount and currency", verifyFn, /Payment amount mismatch[\s\S]*?Payment currency mismatch/],
  ["verification calls the atomic idempotent finance reconciler", verifyFn, /krim_internal_reconcile_razorpay_captured_payment/],
]) {
  if (!pattern.test(source)) failures.push(`Phase 5 payment safety check missing: ${label}`);
}
for (const file of required) {
  if (!existsSync(file)) failures.push(`Missing required production file: ${file}`);
}

let checkedScripts = 0;
for (const file of required.filter((p) => p.endsWith(".html") && existsSync(p))) {
  const html = readFileSync(file, "utf8");
  const scripts = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi)];
  for (const [, attrs, body] of scripts) {
    if (/\bsrc\s*=/.test(attrs) || /\btype\s*=\s*["'](?:application\/ld\+json|application\/json|importmap)["']/i.test(attrs)) continue;
    if (!body.trim()) continue;
    const temp = join(tmpdir(), `krim-inline-${process.pid}-${checkedScripts}.js`);
    writeFileSync(temp, body, "utf8");
    const result = spawnSync(process.execPath, ["--check", temp], { encoding: "utf8" });
    unlinkSync(temp);
    checkedScripts++;
    if (result.status !== 0) {
      failures.push(`Inline JavaScript syntax error in ${file}:\n${result.stderr || result.stdout}`);
    }
  }
}


function listHtmlFiles(dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const file = join(dir, entry.name);
    return entry.isDirectory() ? listHtmlFiles(file) : entry.isFile() && entry.name.toLowerCase().endsWith(".html") ? [file] : [];
  });
}

const customerOsPages = listHtmlFiles("public/customer-os");

// Keep the Customer OS single-source-of-truth: exact duplicate HTML files are failures,
// and every route must use the shared responsive design layer.
const exactPageOwners = new Map();
for (const file of customerOsPages) {
  const html = readFileSync(file, "utf8");
  const previous = exactPageOwners.get(html);
  if (previous) failures.push(`Duplicate Customer OS page content: ${previous} and ${file}`);
  else exactPageOwners.set(html, file);
  // Legacy compatibility aliases intentionally redirect to a canonical page and
  // therefore do not need their own workspace stylesheet. They still participate in
  // route/link checks below so stale targets are caught.
  const isCompatibilityRedirect =
    /<link[^>]+rel=["']canonical["']/i.test(html) &&
    (/<meta[^>]+http-equiv=["']refresh["']/i.test(html) ||
      /location\.replace\(/i.test(html));
  if (!isCompatibilityRedirect && !html.includes("customer-os-global.css")) {
    failures.push(`Customer OS page is missing the shared UI stylesheet: ${file}`);
  }
}
const sharedCustomerCss = "public/customer-os/assets/customer-os-global.css";
if (!existsSync(sharedCustomerCss)) failures.push("Shared Customer OS design stylesheet is missing.");

let checkedCustomerOsLinks = 0;
for (const file of customerOsPages) {
  const html = readFileSync(file, "utf8");
  for (const match of html.matchAll(/(?:href|src|action)=["']([^"'#]+)["']/gi)) {
    const raw = match[1].trim();
    if (!raw || raw.includes("<") || /\s/.test(raw) || /^(?:[a-z][a-z0-9+.-]*:|\/\/|#)/i.test(raw)) continue;
    const clean = raw.split(/[?#]/)[0];
    if (!clean) continue;
    let target;
    if (clean.startsWith("/logistics-saas/")) {
      target = clean.slice("/logistics-saas/".length);
    } else if (clean.startsWith("/")) {
      failures.push(`Customer OS route omits GitHub Pages project prefix in ${file}: ${raw}`);
      continue;
    } else {
      target = pathResolve(dirname(file), clean);
    }
    if (!target) target = "index.html";
    if (target.endsWith("/")) target += "index.html";
    checkedCustomerOsLinks++;
    if (!existsSync(target)) failures.push(`Broken Customer OS local link in ${file}: ${raw} -> ${target}`);
  }
}


// Repository-wide local-link audit: catch dead links outside the Customer OS as well.
// GitHub Pages publishes the project at /logistics-saas/, with public/ content also
// mirrored to the site root by the deployment workflow.
const phaseOneAuthPages = new Set([
  "auth/access.html", "auth/signup.html", "auth/login.html",
  "auth/forgot-password.html", "auth/reset-password.html",
  "auth/auth-callback.html", "auth/mfa-enroll.html",
  "auth/logout.html", "auth/verify-email.html",
  "auth/driver-access.html", "auth/partner-signup.html", "auth/partner-signin.html"
]);
const allHtmlFiles = listHtmlFiles(".").filter((p) =>
  p === "index.html" || p === "public/index.html" || p === "public/global-workflows.html" ||
  phaseOneAuthPages.has(p) || p.startsWith("public/customer-os/") || p.startsWith("public/customer/") ||
  p.startsWith("public/shipper/") || p.startsWith("public/shipments/") ||
  p.startsWith("public/quotes/") || p.startsWith("public/finance/") || p === "public/admin/customer-ecosystem-os.html"
);
let checkedAllSiteLinks = 0;
for (const file of allHtmlFiles) {
  const html = readFileSync(file, "utf8");
  for (const match of html.matchAll(/(?:href|src|action)=["']([^"'#]+)["']/gi)) {
    const raw = match[1].trim();
    if (!raw || raw.includes("<") || /\s/.test(raw) || /^(?:[a-z][a-z0-9+.-]*:|\/\/|#)/i.test(raw)) continue;
    const clean = raw.split(/[?#]/)[0];
    if (!clean) continue;
    let candidates = [];
    if (clean.startsWith("/logistics-saas/")) {
      const target = clean.slice("/logistics-saas/".length);
      candidates = [target];
    } else if (clean.startsWith("/")) {
      failures.push(`Potential GitHub Pages 404 (missing /logistics-saas/ prefix) in ${file}: ${raw}`);
      const target = clean.slice(1);
      candidates = [target];
    } else {
      candidates = [pathResolve(dirname(file), clean)];
    }
    checkedAllSiteLinks++;
    const expanded = candidates.flatMap((target) =>
      target.endsWith("/") ? [join(target, "index.html")] : [target, join(target, "index.html")]
    );
    if (!expanded.some((target) => existsSync(target))) {
      failures.push(`Broken site-local link in ${file}: ${raw} -> ${candidates.join(" or ")}`);
    }
  }
}

// Check shared Customer OS JavaScript navigation (these routes are injected at runtime).
const customerWorkflow = existsSync("public/customer-os/assets/customer-workflow.js") ? readFileSync("public/customer-os/assets/customer-workflow.js", "utf8") : "";
for (const [label, route] of [
  ["quote comparison", "public/shipper/quote-comparison.html"],
  ["shipment register", "public/customer-os/customer-services/shipment-list.html"],
  ["payment history", "public/customer-os/customer-services/payment-history.html"],
  ["quote request", "public/customer/quote-request.html"],
]) {
  if (!existsSync(route)) failures.push(`Customer workflow target missing: ${label} -> ${route}`);
  if (!customerWorkflow.includes(route)) failures.push(`Shared Customer OS navigation is missing canonical route for ${label}: ${route}`);
}
for (const deletedRoute of ["public/customer/quote-comparison.html", "public/customer/shipment-list.html", "public/finance/payment-checkout.html"]) {
  if (customerWorkflow.includes(deletedRoute)) failures.push(`Shared Customer OS navigation still references deleted route: ${deletedRoute}`);
}

for (const [label, route] of [
  ["customer invoices", "public/customer-os/customer-services/invoices.html"],
  ["customer claims", "public/customer-os/customer-services/claims.html"],
  ["customer address book", "public/customer-os/customer-services/address-book.html"],
  ["customer company profile", "public/customer-os/customer-services/company-profile.html"],
]) {
  if (!existsSync(route)) failures.push(`Canonical Customer OS route missing: ${label} -> ${route}`);
  if (!customerWorkflow.includes(route)) failures.push(`Shared Customer OS navigation does not use canonical route for ${label}: ${route}`);
}
for (const duplicateAlias of ["public/customer-os/customer-services/shipment-create.html"]) {
  if (existsSync(duplicateAlias)) failures.push(`Duplicate Customer OS route alias should be removed: ${duplicateAlias}`);
  if (customerWorkflow.includes(duplicateAlias)) failures.push(`Shared Customer OS navigation references duplicate route alias: ${duplicateAlias}`);
}

const checkout = existsSync("public/quote-result.html") ? readFileSync("public/quote-result.html", "utf8") : "";
for (const [label, pattern] of [
  ["no Razorpay SDK in customer quote route", /checkout\.razorpay\.com/],
  ["no Razorpay constructor in customer quote route", /new Razorpay/],
  ["no customer freight order invocation", /create-global-razorpay-order/],
  ["partner-direct guidance is present", /Pay your partner directly/],
]) {
  const matched = pattern.test(checkout);
  if (label.startsWith("no ") ? matched : !matched) failures.push(`Partner-direct customer route guard failed: ${label}`);
}

const razorpayOrder = existsSync("supabase/functions/create-global-razorpay-order/index.ts") ? readFileSync("supabase/functions/create-global-razorpay-order/index.ts", "utf8") : "";
const razorpayVerify = existsSync("supabase/functions/verify-razorpay-payment/index.ts") ? readFileSync("supabase/functions/verify-razorpay-payment/index.ts", "utf8") : "";
for (const [label, source, pattern] of [
  ["Razorpay order endpoint requires authenticated user", razorpayOrder, /auth\.getUser\(token\)/],
  ["Razorpay order checks the accepted quote", razorpayOrder, /accepted quote/i],
  ["Razorpay order verifies partner assignment", razorpayOrder, /assignment\.status/],
  ["Razorpay verification checks the provider signature", razorpayVerify, /generateHmacSha256[\s\S]*?razorpaySignature/],
  ["Razorpay verification checks accepted quote and partner assignment", razorpayVerify, /(?=[\s\S]*accepted customer quote)(?=[\s\S]*accepted partner assignment)/i],
]) {
  if (!pattern.test(source)) failures.push(`Razorpay safety check missing: ${label}`);
}

const pricingMigration = "supabase/migrations/20261019000100_fail_closed_tariff_quotes_without_approved_rate_cards.sql";
if (existsSync(pricingMigration)) {
  const sql = readFileSync(pricingMigration, "utf8");
  if (!/Tariff quote unavailable: no approved active rate card is configured/i.test(sql)) {
    failures.push("Fail-closed tariff pricing guard missing from migration.");
  }
} else {
  failures.push("Required fail-closed tariff pricing migration is missing.");
}

const restoredPricingMigration = "supabase/migrations/20261019100000_restore_rate_card_backed_tariff_quotes.sql";
if (existsSync(restoredPricingMigration)) {
  const sql = readFileSync(restoredPricingMigration, "utf8");
  for (const [label, pattern] of [
    ["restored tariff function remains SECURITY DEFINER", /SECURITY\s+DEFINER/i],
    ["restored tariff function pins search_path", /SET\s+search_path\s+TO\s+'public',\s*'pg_temp'/i],
    ["restored tariff function requires an active global rate card", /r\.status\s*=\s*'active'[\s\S]*?r\.effective_from\s*<=\s*now\(\)/i],
    ["restored tariff function fails closed when no rate card matches", /Tariff quote unavailable: no approved active global rate card matches this route and service tier\./i],
  ]) {
    if (!pattern.test(sql)) failures.push(`Restored tariff migration safety check missing: ${label}`);
  }
  if (/INSERT\s+INTO\s+public\.krim_pricing_rate_cards/i.test(sql)) {
    failures.push("Restored tariff migration must not seed unapproved commercial rates.");
  }
} else {
  failures.push("Required restored rate-card-backed tariff migration is missing.");
}

const securityMigration = "supabase/migrations/20261019020919_restrict_privileged_krim_rpc_to_authenticated.sql";
if (existsSync(securityMigration)) {
  const sql = readFileSync(securityMigration, "utf8");
  if (!/REVOKE\s+EXECUTE[\s\S]*?FROM\s+PUBLIC\s*,\s*anon/i.test(sql)) {
    failures.push("Privileged RPC public/anon execute revocation is missing.");
  }
  if (!/GRANT\s+EXECUTE[\s\S]*?TO\s+authenticated/i.test(sql)) {
    failures.push("Privileged RPC authenticated execute grant is missing.");
  }
} else {
  failures.push("Required privileged RPC security migration is missing.");
}


const partnerWorkspace = existsSync("app/partner/index.html") ? readFileSync("app/partner/index.html", "utf8") : "";
const partnerMarketplace = existsSync("public/partner/load-marketplace.html") ? readFileSync("public/partner/load-marketplace.html", "utf8") : "";
const partnerLiveExchange = existsSync("public/partner/available-loads.html") ? readFileSync("public/partner/available-loads.html", "utf8") : "";
const partnerOnboarding = existsSync("public/partner/partner-onboarding.html") ? readFileSync("public/partner/partner-onboarding.html", "utf8") : "";
const partnerBid = existsSync("public/partner/submit-quote.html") ? readFileSync("public/partner/submit-quote.html", "utf8") : "";
const booking = existsSync("public/shipments/shipment-create.html") ? readFileSync("public/shipments/shipment-create.html", "utf8") : "";
const customerShipmentList = existsSync("public/customer-os/customer-services/shipment-list.html") ? readFileSync("public/customer-os/customer-services/shipment-list.html", "utf8") : "";
const customerQuoteRequest = existsSync("public/customer/quote-request.html") ? readFileSync("public/customer/quote-request.html", "utf8") : "";
const customerInvoices = existsSync("public/customer-os/customer-services/invoices.html") ? readFileSync("public/customer-os/customer-services/invoices.html", "utf8") : "";
const customerSupport = existsSync("public/customer-os/customer-services/support.html") ? readFileSync("public/customer-os/customer-services/support.html", "utf8") : "";
const customerClaims = existsSync("public/customer-os/customer-services/claims.html") ? readFileSync("public/customer-os/customer-services/claims.html", "utf8") : "";
const customerPaymentHistory = existsSync("public/customer-os/customer-services/payment-history.html") ? readFileSync("public/customer-os/customer-services/payment-history.html", "utf8") : "";
for (const [label, source, pattern] of [
  ["partner workspace distinguishes development/test mode", partnerWorkspace, /development_test/],
  ["partner workspace clearly locks live operations in test mode", partnerWorkspace, /Live commercial operations are disabled/],
  ["legacy marketplace route redirects to the live freight exchange", partnerMarketplace, /available-loads\.html[\s\S]*window\.location\.replace/],
  ["live freight exchange requires an authenticated session", partnerLiveExchange, /client\.auth\.getSession\(\)/],
  ["live freight exchange blocks unverified partner organizations", partnerLiveExchange, /partner_verification_status[\s\S]*partner_compliance_status[\s\S]*Partner verification required/],
  ["partner quote form requires verified organization eligibility", partnerBid, /function partnerEligible\(o\)[\s\S]*partner_verification_status[\s\S]*partner_compliance_status/],
  ["partner quote form submits through the dedicated partner quote RPC", partnerBid, /rpc\(['"]krim_submit_partner_quote['"]/],
  ["onboarding supports the three explicit partner pathways", partnerOnboarding, /development_test[\s\S]*individual_interest[\s\S]*registered_business/i],
  ["onboarding saves account mode through the backend RPC", partnerOnboarding, /rpc\(['"]krim_set_partner_account_mode['"]/],
  ["partner bid page requires verified eligible organization", partnerBid, /partner_verification_status[\s\S]*partner_lifecycle_status[\s\S]*partner_compliance_status/i],
  ["customer booking uses the secure shipment creation RPC", booking, /rpc\(['"]krim_create_global_shipment['"]/],
  ["customer booking rejects identical origin and destination", booking, /originId\s*===\s*destinationId/],
  ["Customer OS shipment list reads live shipment records", customerShipmentList, /from\(['"]krim_shipments['"]\)/],
  ["Customer OS shipment list is scoped to active organization membership", customerShipmentList, /krim_organization_members[\s\S]*?status[\s\S]*?active[\s\S]*?customerIds/],
  ["Customer quote request reads saved shipment records", customerQuoteRequest, /from\(['"]krim_shipments['"]\)/],
  ["Customer quote request reads saved quote records", customerQuoteRequest, /from\(['"]krim_quotes['"]\)/],
  ["Customer quote request scopes records to active customer organizations", customerQuoteRequest, /krim_organization_members[\s\S]*?customer_organization_id[\s\S]*?customerIds/],
  ["Customer invoice register reads saved invoice records", customerInvoices, /from\(['"]krim_invoices['"]\)/],
  ["Customer invoice register filters by the organization protected by invoice RLS", customerInvoices, /from\(['"]krim_invoices['"]\)[\s\S]*?\.in\(['"]organization_id['"],customerIds\)/],
  ["Customer support page creates saved support tickets", customerSupport, /from\(['"]support_tickets['"]\)\.insert\(payload\)/],
  ["Customer support tickets bind to the signed-in user and active organization", customerSupport, /user_id:session\.user\.id[\s\S]*?krim_organization_id:Number\(org\.id\)[\s\S]*?krim_shipment_id:shipmentId/],
  ["Customer support verifies active organization membership before ticket creation", customerSupport, /krim_organization_members[\s\S]*?status[\s\S]*?active[\s\S]*?organization_type/],
  ["Customer claims page reads saved claim records", customerClaims, /from\(['"]krim_claims['"]\)/],
  ["Customer claims page filters by the organization protected by claims RLS", customerClaims, /from\(['"]krim_claims['"]\)[\s\S]*?\.in\(['"]organization_id['"],customerIds\)/],
  ["Customer payment history reads saved payment records", customerPaymentHistory, /from\(['"]payments['"]\)/],
  ["Customer payment history filters by the signed-in user protected by payment RLS", customerPaymentHistory, /from\(['"]payments['"]\)[\s\S]*?\.eq\(['"]customer_id['"],auth\.session\.user\.id\)/],
  ["Repeat shipment page reads live organization-scoped shipment records", existsSync("public/customer-os/customer-services/recurring-shipments.html") ? readFileSync("public/customer-os/customer-services/recurring-shipments.html", "utf8") : "", /from\(['"]krim_shipments['"]\)[\s\S]*?customer_organization_id/],
  ["Repeat shipment action opens canonical booking with source record ID", existsSync("public/customer-os/customer-services/recurring-shipments.html") ? readFileSync("public/customer-os/customer-services/recurring-shipments.html", "utf8") : "", /shipment-create\.html\?repeat_from=/],
  ["Canonical booking scopes repeat-prefill to the active customer organization", existsSync("public/shipments/shipment-create.html") ? readFileSync("public/shipments/shipment-create.html", "utf8") : "", /applyRepeatTemplate[\s\S]*?eq\(['"]customer_organization_id['"],customerOrganizationId\)/],
  ["Returns page starts reverse shipment draft through canonical booking", existsSync("public/customer-os/customer-services/returns.html") ? readFileSync("public/customer-os/customer-services/returns.html", "utf8") : "", /shipment-create\.html\?repeat_from=[\s\S]*?reverse=1/],
  ["Saved routes page persists user-owned route preferences", existsSync("public/customer-os/customer-services/saved-routes.html") ? readFileSync("public/customer-os/customer-services/saved-routes.html", "utf8") : "", /saved_routes[\s\S]*?upsert\(/],
  ["Shipping preferences persist personal localization settings to the signed-in user", existsSync("public/customer-os/customer-services/shipping-preferences.html") ? readFileSync("public/customer-os/customer-services/shipping-preferences.html", "utf8") : "", /customer_localization[\s\S]*?upsert\(/],
  ["Cargo profiles persist personal profile records to the signed-in user", existsSync("public/customer-os/customer-services/cargo-profiles.html") ? readFileSync("public/customer-os/customer-services/cargo-profiles.html", "utf8") : "", /cargo_profiles[\s\S]*?upsert\(/],
  ["Cargo profile opens canonical booking with profile ID", existsSync("public/customer-os/customer-services/cargo-profiles.html") ? readFileSync("public/customer-os/customer-services/cargo-profiles.html", "utf8") : "", /shipment-create\.html\?cargo_profile_id=/],
  ["Canonical booking loads cargo profile from current user's own preferences", existsSync("public/shipments/shipment-create.html") ? readFileSync("public/shipments/shipment-create.html", "utf8") : "", /applyCargoProfilePrefill[\s\S]*?eq\(['"]user_id['"],session\.user\.id\)/],
  ["Shipping preferences load active country and currency catalogs", existsSync("public/customer-os/customer-services/shipping-preferences.html") ? readFileSync("public/customer-os/customer-services/shipping-preferences.html", "utf8") : "", /from\(['"]krim_countries['"]\)[\s\S]*?from\(['"]krim_currencies['"]\)/],
  ["Saved route opens canonical booking with origin and destination", existsSync("public/customer-os/customer-services/saved-routes.html") ? readFileSync("public/customer-os/customer-services/saved-routes.html", "utf8") : "", /shipment-create\.html\?origin_location_id=[\s\S]*?destination_location_id=/],
  ["Canonical booking prefill validates route IDs against active locations", existsSync("public/shipments/shipment-create.html") ? readFileSync("public/shipments/shipment-create.html", "utf8") : "", /applySavedRoutePrefill[\s\S]*?locations\.find\(l=>Number\(l\.id\)===originId\)[\s\S]*?locations\.find\(l=>Number\(l\.id\)===destinationId\)/],
  ["Canonical booking reverses locations only when explicitly requested", existsSync("public/shipments/shipment-create.html") ? readFileSync("public/shipments/shipment-create.html", "utf8") : "", /reverse=new URLSearchParams\(location\.search\)\.get\(['"]reverse['"]\)==='1'[\s\S]*?s\.destination_location_id[\s\S]*?s\.origin_location_id/],
]) {
  if (!pattern.test(source)) failures.push(`Partner/customer lifecycle safety check missing: ${label}`);
}

// Phase 1 — institutional customer-entry and identity-flow source guards.
// These assertions catch regressions in repository code; they do not replace deployed browser tests.
const phaseOneSources = Object.fromEntries([
  ["homepage", "index.html"],
  ["access", "auth/access.html"],
  ["signup", "auth/signup.html"],
  ["login", "auth/login.html"],
  ["forgot", "auth/forgot-password.html"],
  ["reset", "auth/reset-password.html"],
  ["callback", "auth/auth-callback.html"],
  ["mfaEnroll", "auth/mfa-enroll.html"],
  ["logout", "auth/logout.html"],
  ["verifyEmail", "auth/verify-email.html"],
  ["logout", "auth/logout.html"],
  ["bookingRequest", "public/shipper/booking-request.html"],
].map(([key, file]) => [key, existsSync(file) ? readFileSync(file, "utf8") : ""]));

if (/href=["'][^"']*(?:admin|platform-admin|global-control-centre|global-control-center)[^"']*["']/i.test(phaseOneSources.homepage) || /href=["'][^"']*(?:admin|platform-admin|global-control-centre|global-control-center)[^"']*["']/i.test(phaseOneSources.access)) {
  failures.push("Public homepage/access portal must not expose privileged platform-administrator routes.");
}

for (const [label, source, pattern] of [
  ["public homepage routes customers to the access portal", phaseOneSources.homepage, /href=["'][^"']*auth\/access\.html["']/i],
  ["customer booking uses a relative login handoff instead of a hardcoded project prefix", phaseOneSources.bookingRequest, /window\.location\.replace\("\.\.\/\.\.\/auth\/login\.html\?role=customer&next="/],
  ["customer booking page contains no hardcoded GitHub Pages project prefix", phaseOneSources.bookingRequest, /(?![\s\S]*\/logistics-saas\/)[\s\S]*/],
  ["customer login safely allows booking return paths on project and custom-domain deployments", phaseOneSources.login, /allowedBookingPaths[\s\S]*?\/public\/shipper\/booking-request\.html[\s\S]*?\/shipper\/booking-request\.html/],
  ["access portal offers canonical customer registration and role-checked sign-in", phaseOneSources.access, /href=["']signup\.html["'][\s\S]*?href=["']login\.html\?role=customer["']/i],
  ["customer registration uses Supabase Auth with customer and organization metadata", phaseOneSources.signup, /auth\.signUp\([\s\S]*?company_name:org[\s\S]*?krim_account_type:"customer"/],
  ["customer signup and password recovery enforce a consistent 12-character minimum", phaseOneSources.signup + phaseOneSources.reset, /minlength="12"[\s\S]*?minlength="12"[\s\S]*?password\.length<12[\s\S]*?minlength="12"/],
  ["customer registration sends email-confirmation users through the auth callback", phaseOneSources.signup, /emailRedirectTo:new URL\("auth-callback\.html",location\.href\)\.href/],
  ["customer registration provisions its organization when an authenticated signup session is returned", phaseOneSources.signup, /rpc\("krim_provision_customer_organization"[\s\S]*?mfa-enroll\.html/],
  ["sign-in validates active organization membership before role routing", phaseOneSources.login, /from\("krim_organization_members"\)[\s\S]*?eq\(\s*"status"\s*,\s*"active"\s*\)[\s\S]*?workspacePaths/],
  ["public sign-in rejects platform administrator accounts", phaseOneSources.login, /Platform administration uses a separate privileged sign-in/],
  ["sign-in routes users through MFA enrollment or challenge", phaseOneSources.login, /auth\.mfa\.listFactors\(\)[\s\S]*?mfa-enroll\.html[\s\S]*?auth\.mfa\.getAuthenticatorAssuranceLevel/],
  ["password recovery uses Supabase reset email and the canonical reset page", phaseOneSources.forgot, /auth\/reset-password\.html[\s\S]*?resetPasswordForEmail\(/],
  ["password reset validates recovery session and revokes sessions after successful update", phaseOneSources.reset, /recoverySession[\s\S]*?auth\.updateUser\(\{password:pwd\}\)[\s\S]*?signOut\(\{scope:"global"\}\)/],
  ["email callback exchanges the confirmation code and provisions customer organization", phaseOneSources.callback, /exchangeCodeForSession\(code\)[\s\S]*?krim_provision_customer_organization/],
  ["MFA enrollment requires a session and verifies a one-time challenge", phaseOneSources.mfaEnroll, /auth\.getSession\(\)[\s\S]*?auth\.mfa\.enroll\([\s\S]*?auth\.mfa\.challenge\([\s\S]*?auth\.mfa\.verify\(/],
  ["logout requests global Supabase sign-out", phaseOneSources.logout, /signOut\(\{\s*scope:\s*['"]global['"]\s*\}\)/],
  ["email verification supports OTP verification and resend", phaseOneSources.verifyEmail, /verifyOtp\([\s\S]*?auth\.resend\(/],
]) {
  if (!pattern.test(source)) failures.push(`Phase 1 customer-entry check missing: ${label}`);
}

const phaseOneVisualPages = ["auth/access.html","auth/signup.html","auth/login.html","auth/forgot-password.html","auth/reset-password.html","auth/auth-callback.html","auth/mfa-enroll.html","auth/verify-email.html","auth/logout.html"];
for (const file of phaseOneVisualPages) {
  const source = existsSync(file) ? readFileSync(file, "utf8") : "";
  if (!source.includes("krim-global-shell") || !source.includes("../core/krim-global-interface.css")) failures.push("Missing KRIM global interface on " + file);
}
// Phase 2 — location discovery and honest serviceability / coverage review.
const phaseTwoBooking = existsSync("public/shipper/booking-request.html") ? readFileSync("public/shipper/booking-request.html", "utf8") : "";
const phaseTwoCoverage = existsSync("public/shipper/coverage-review.html") ? readFileSync("public/shipper/coverage-review.html", "utf8") : "";
const phaseTwoMigration = existsSync("supabase/migrations/20261023110000_enable_authenticated_customer_coverage_requests.sql") ? readFileSync("supabase/migrations/20261023110000_enable_authenticated_customer_coverage_requests.sql", "utf8") : "";
for (const [label, source, pattern] of [
  ["shipment intake links to the canonical coverage-review page", phaseTwoBooking, /id=["']coverage-review-link["'] href=["']coverage-review\.html["']/],
  ["coverage review preserves exact origin and destination as customer-entered text", phaseTwoCoverage, /Origin \(customer-entered\)[\s\S]*?Destination \(customer-entered\)/],
  ["coverage review uses the existing customer service-request RPC", phaseTwoCoverage, /rpc\(["']krim_submit_customer_service_request["'][\s\S]*?p_request_type:\s*["']general["']/],
  ["coverage review requires a verified identity and active customer workspace", phaseTwoCoverage, /krim_customer_identity_links[\s\S]*?eq\(["']identity_status["'],["']verified["']\)[\s\S]*?krim_customer_workspace_profiles[\s\S]*?workspace_status/],
  ["coverage review does not claim that route coverage is confirmed", phaseTwoCoverage, /Coverage status: not verified[\s\S]*?route coverage, pricing and service availability remain unverified/],
  ["coverage RPC migration grants execution only to authenticated customers and excludes anon", phaseTwoMigration, /REVOKE ALL ON FUNCTION[\s\S]*?FROM anon[\s\S]*?GRANT EXECUTE ON FUNCTION[\s\S]*?TO authenticated/],
  ["general coverage inquiries do not count as quote or shipment acquisition events", phaseTwoMigration, /IF v_request_type='quote'[\s\S]*?quote_requested[\s\S]*?ELSIF v_request_type='shipment'[\s\S]*?shipment_requested/],
]) {
  if (!pattern.test(source)) failures.push(`Phase 2 location/coverage check missing: ${label}`);
}
if (!phaseTwoCoverage.includes("../../core/krim-global-interface.css")) failures.push("Phase 2 coverage review is missing the shared KRIM interface stylesheet.");

// Phase 6 — one canonical customer shipment dashboard, real organization-scoped records,
// searchable/filterable/sortable/paginated results, valid detail routes, and shared interface.
const phaseSixDashboard = existsSync("public/customer-os/customer-services/shipment-list.html")
  ? readFileSync("public/customer-os/customer-services/shipment-list.html", "utf8") : "";
const phaseSixLegacy = existsSync("public/shipper/active-shipments.html")
  ? readFileSync("public/shipper/active-shipments.html", "utf8") : "";
for (const [file, source] of [
  ["public/customer-os/customer-services/shipment-list.html", phaseSixDashboard],
  ["public/customer-os/customer-services/shipment-details.html", existsSync("public/customer-os/customer-services/shipment-details.html") ? readFileSync("public/customer-os/customer-services/shipment-details.html", "utf8") : ""],
  ["public/customer-os/customer-services/shipment-timeline.html", existsSync("public/customer-os/customer-services/shipment-timeline.html") ? readFileSync("public/customer-os/customer-services/shipment-timeline.html", "utf8") : ""],
  ["public/customer-os/customer-services/tracking-map.html", existsSync("public/customer-os/customer-services/tracking-map.html") ? readFileSync("public/customer-os/customer-services/tracking-map.html", "utf8") : ""],
]) {
  if (!source.includes("krim-global-interface.css")) failures.push("Phase 6 page is missing the shared KRIM interface stylesheet: " + file);
  if (!/<body\b[^>]*class=["'][^"']*\bkrim-global-shell\b/i.test(source)) failures.push("Phase 6 page is missing the shared KRIM global shell: " + file);
  const head = source.slice(0, source.toLowerCase().lastIndexOf("</head>"));
  if ((head.match(/krim-global-interface\.css/g) || []).length !== 1) failures.push("Phase 6 page must load exactly one global stylesheet: " + file);
  if (head.lastIndexOf("krim-global-interface.css") < head.lastIndexOf("</style>")) failures.push("Phase 6 global stylesheet must load after page-local styles: " + file);
}
for (const [label, source, pattern] of [
  ["dashboard authenticates and checks active organization membership", phaseSixDashboard, /auth\.getSession\([\s\S]*?krim_organization_members[\s\S]*?eq\('status','active'\)/],
  ["dashboard limits records to active customer, shipper or enterprise organizations", phaseSixDashboard, /krim_organizations[\s\S]*?eq\('status','active'\)[\s\S]*?customerIds[\s\S]*?customer_organization_id/],
  ["dashboard uses live shipment records and no demo dataset", phaseSixDashboard, /from\('krim_shipments'\)[\s\S]*?customer_organization_id[\s\S]*?order\('created_at'[\s\S]*?limit\(100\)/],
  ["dashboard implements search, status filtering, sorting and pagination", phaseSixDashboard, /search.addEventListener[\s\S]*?filter.addEventListener[\s\S]*?sort-order[\s\S]*?page-prev[\s\S]*?page-next/],
  ["dashboard actions route to canonical shipment details, visibility and quote list", phaseSixDashboard, /customer-services\/shipment-details\.html[\s\S]*?visibility\/live-tracking-map\.html[\s\S]*?quotes-pricing\/quote-list\.html/],
  ["dashboard creates shipments only through the canonical request page", phaseSixDashboard, /public\/shipper\/booking-request\.html/],
  ["legacy active shipments route redirects to canonical dashboard and preserves query/hash", phaseSixLegacy, /customer-os\/customer-services\/shipment-list\.html[\s\S]*?target\.search=location\.search[\s\S]*?target\.hash=location\.hash[\s\S]*?location\.replace/],
]) {
  if (!pattern.test(source)) failures.push("Phase 6 dashboard check missing: " + label);
}
for (const file of ["public/customer-os/customer-services/shipment-details.html","public/customer-os/customer-services/shipment-timeline.html","public/customer-os/customer-services/tracking-map.html"]) {
  if (!existsSync(file)) failures.push("Missing Phase 6 customer shipment workflow page: " + file);
}
const phaseSixCustomerNav = existsSync("public/customer-os/assets/customer-workflow.js") ? readFileSync("public/customer-os/assets/customer-workflow.js", "utf8") : "";
if (!/book:'public\/shipper\/booking-request\.html'/.test(phaseSixCustomerNav)) failures.push("Customer OS navigation must use the canonical shipment-request page.");

// Phase 7 — recorded tracking/timeline, explicit freshness, saved time-zone display,
// persisted customer notification preferences, and shared global interface.
const phaseSevenTracking = existsSync("public/customer-os/customer-services/tracking-map.html") ? readFileSync("public/customer-os/customer-services/tracking-map.html", "utf8") : "";
const phaseSevenTimeline = existsSync("public/customer-os/customer-services/shipment-timeline.html") ? readFileSync("public/customer-os/customer-services/shipment-timeline.html", "utf8") : "";
const phaseSevenOperations = existsSync("public/customer-os/assets/shipment-operations.js") ? readFileSync("public/customer-os/assets/shipment-operations.js", "utf8") : "";
const phaseSevenPreferences = existsSync("public/customer-os/customer-services/shipping-preferences.html") ? readFileSync("public/customer-os/customer-services/shipping-preferences.html", "utf8") : "";
const phaseSevenHub = existsSync("public/customer-os/index.html") ? readFileSync("public/customer-os/index.html", "utf8") : "";
for (const [file, source] of [
  ["public/customer-os/customer-services/tracking-map.html", phaseSevenTracking],
  ["public/customer-os/customer-services/shipment-timeline.html", phaseSevenTimeline],
  ["public/customer-os/customer-services/shipping-preferences.html", phaseSevenPreferences],
  ["public/customer-os/index.html", phaseSevenHub],
]) {
  const head = source.slice(0, source.toLowerCase().lastIndexOf("</head>"));
  if (!source.includes("krim-global-interface.css")) failures.push("Phase 7 page is missing the shared KRIM interface stylesheet: " + file);
  if (!/<body\b[^>]*class=["'][^"']*\bkrim-global-shell\b/i.test(source)) failures.push("Phase 7 page is missing the shared KRIM global shell: " + file);
  if ((head.match(/krim-global-interface\.css/g) || []).length !== 1) failures.push("Phase 7 page must load exactly one shared global stylesheet: " + file);
}
for (const [label, source, pattern] of [
  ["timeline reads persisted shipment status, tracking and milestone events", phaseSevenOperations, /krim_shipment_status_history[\s\S]*?krim_tracking_events[\s\S]*?krim_shipment_milestones/],
  ["tracking reads persisted shipment tracking events", phaseSevenOperations, /from\(['"]krim_tracking_events['"]\)[\s\S]*?eq\(['"]shipment_id['"],shipment.id\)/],
  ["tracking explicitly distinguishes recorded events from live GPS", phaseSevenOperations, /recorded-event visibility, not live GPS/i],
  ["tracking flags potentially stale events without claiming a delivery SLA", phaseSevenOperations, /trackingFreshness[\s\S]*?over 24 hours old[\s\S]*?not a delivery SLA/],
  ["timestamps use the saved user time-zone preference", phaseSevenOperations, /timeZone:userTimezone[\s\S]*?customer_localization[\s\S]*?timezone/],
  ["customer notification preferences are saved per user", phaseSevenPreferences, /shipping_preferences[\s\S]*?notifications:getChecks\('notify'\)[\s\S]*?krim_user_app_preferences[\s\S]*?upsert\(/],
  ["notification settings state that preferences do not guarantee delivery", phaseSevenPreferences, /Actual message delivery still depends on verified contact details, consent, provider configuration and notification service status/i],
  ["tracking and timeline link to the canonical notification preference page", phaseSevenTracking + phaseSevenTimeline, /shipping-preferences\.html/],
  ["customer hub links to the saved notification preferences", phaseSevenHub, /customer-services\/shipping-preferences\.html/],
]) {
  if (!pattern.test(source)) failures.push("Phase 7 tracking/notification check missing: " + label);
}

// Phase 8 — pickup and custody: canonical secured milestone route, honest lifecycle,
// global interface, customer entry points, driver access, and retirement of fake-success forms.
const phaseEightPickup = existsSync("public/pickup-tracking.html") ? readFileSync("public/pickup-tracking.html", "utf8") : "";
const phaseEightList = existsSync("public/customer-os/customer-services/shipment-list.html") ? readFileSync("public/customer-os/customer-services/shipment-list.html", "utf8") : "";
const phaseEightOps = existsSync("public/customer-os/assets/shipment-operations.js") ? readFileSync("public/customer-os/assets/shipment-operations.js", "utf8") : "";
const phaseEightHub = existsSync("public/customer-os/index.html") ? readFileSync("public/customer-os/index.html", "utf8") : "";
const phaseEightNav = existsSync("public/customer-os/assets/customer-workflow.js") ? readFileSync("public/customer-os/assets/customer-workflow.js", "utf8") : "";
const phaseEightDriver = existsSync("app/driver/module-05-pickup-collection.html") ? readFileSync("app/driver/module-05-pickup-collection.html", "utf8") : "";
for (const [file, source] of [
  ["public/pickup-tracking.html", phaseEightPickup],
  ["app/driver/module-05-pickup-collection.html", phaseEightDriver],
]) {
  const head = source.slice(0, source.toLowerCase().lastIndexOf("</head>"));
  if (!source.includes("krim-global-interface.css")) failures.push("Phase 8 page is missing the shared KRIM interface stylesheet: " + file);
  if (!/<body\b[^>]*class=["'][^"']*\bkrim-global-shell\b/i.test(source)) failures.push("Phase 8 page is missing the KRIM global shell: " + file);
  if ((head.match(/krim-global-interface\.css/g) || []).length !== 1) failures.push("Phase 8 page must load exactly one shared global stylesheet: " + file);
}
for (const [label, source, pattern] of [
  ["canonical pickup lookup uses the server-authorized shipment tracking RPC", phaseEightPickup, /rpc\(["']krim_get_shipment_tracking["']/],
  ["pickup event writes use the server-validated operational milestone RPC", phaseEightPickup, /rpc\(["']krim_record_operational_milestone["']/],
  ["pickup form does not claim success before the server accepts the event", phaseEightPickup, /Milestone not recorded[\s\S]*?server rejected the milestone/],
  ["pickup retry response distinguishes safely ignored duplicate events", phaseEightPickup, /Duplicate retry safely ignored/],
  ["pickup UI explains that custody, collection and delivery are separate states", phaseEightPickup, /scheduled pickup, physical collection, custody handover and delivery are distinct states/],
  ["customer shipment register opens canonical pickup workflow with shipment reference", phaseEightList, /pickup-tracking\.html\?shipment=[\s\S]*?s\.shipment_number/],
  ["shipment details offers the canonical pickup and custody workflow", phaseEightOps, /Pickup & custody[\s\S]*?public\/pickup-tracking\.html[\s\S]*?url\.includes\('pickup-tracking'\)/],
  ["customer hub links to the canonical pickup route", phaseEightHub, /href=["']\.\.\/pickup-tracking\.html["']/],
  ["customer workflow navigation exposes pickup and custody", phaseEightNav, /pickup:'public\/pickup-tracking\.html'[\s\S]*?Pickup & custody/],
  ["driver pickup module authenticates a session and active driver membership", phaseEightDriver, /auth\.getSession\([\s\S]*?krim_organization_members[\s\S]*?No active driver membership/],
  ["driver pickup module reads real assignments without inserting demo trips", phaseEightDriver, /from\('krim_driver_assignments'\)[\s\S]*?No demo trips are inserted/],
]) {
  if (!pattern.test(source)) failures.push("Phase 8 pickup/custody check missing: " + label);
}
for (const [file, target] of [
  ["public/shipments/pickup.html", /location\.replace\(['"]\.\.\/pickup-tracking\.html/],
  ["public/partner/pickup-confirmation.html", /location\.replace\(['"]\.\.\/pickup-tracking\.html/],
  ["public/driver/pickup-checklist.html", /location\.replace\(['"]\.\.\/\.\.\/app\/driver\/module-05-pickup-collection\.html/],
]) {
  const source = existsSync(file) ? readFileSync(file, "utf8") : "";
  if (!target.test(source)) failures.push("Phase 8 compatibility route does not redirect to the canonical secured workflow: " + file);
  if (/Pickup record saved successfully|Pickup verified and weight bridge slip authenticated|Pickup checklist verified successfully/.test(source)) failures.push("Phase 8 legacy route still contains a fake pickup-success message: " + file);
}

// Phase 9 — cross-workspace execution: shared interface, canonical entry points,
// and retirement of legacy shipment-core screens that contained fixed sample shipment data.
const phaseNineRolePages = [
  "app/partner/index.html",
  "public/partner/accepted-loads.html",
  "public/partner/dispatch-assignment.html",
  "app/warehouse/index.html",
  "app/customs/index.html",
  "app/operations/index.html",
  "public/global-workflows.html",
];
for (const file of phaseNineRolePages) {
  const source = existsSync(file) ? readFileSync(file, "utf8") : "";
  const head = source.slice(0, source.toLowerCase().lastIndexOf("</head>"));
  if (!source.includes("krim-global-interface.css")) failures.push("Phase 9 role/workflow page is missing the shared KRIM interface stylesheet: " + file);
  if (!/<body\b[^>]*class=["'][^"']*\bkrim-global-shell\b/i.test(source)) failures.push("Phase 9 role/workflow page is missing the KRIM global shell: " + file);
  if ((head.match(/krim-global-interface\.css/g) || []).length !== 1) failures.push("Phase 9 role/workflow page must load exactly one shared global stylesheet: " + file);
}
// Phase 9 interface sweep: every transport, warehouse and operations page must use the same shared shell.
const phaseNineInterfaceFiles = [...new Set([
  ...phaseNineRolePages,
  "public/road-rail.html",
  "public/ocean.html",
  "public/air.html",
  "public/warehousing.html",
  "public/shipments/transport-legs.html",
  "public/shipments/shipment-documents.html",
  "public/shipments/shipment-exceptions.html",
  ...listHtmlFiles(".").filter((file) => file.startsWith("public/warehouse/") || file.startsWith("public/operations/")),
])];
for (const file of phaseNineInterfaceFiles) {
  const source = existsSync(file) ? readFileSync(file, "utf8") : "";
  // Retired legacy routes intentionally use a tiny noindex redirect document.
  // They must not masquerade as workspace pages or be forced to duplicate the shell.
  const retiredRedirect =
    /<meta\s+name=["']robots["']\s+content=["']noindex,nofollow["']/i.test(source) &&
    /location\.replace\(/.test(source) &&
    /legacy/i.test(source) &&
    /(retired|replaced)/i.test(source);
  if (retiredRedirect) continue;
  const head = source.slice(0, source.toLowerCase().lastIndexOf("</head>"));
  const cssCount = (head.match(/core\/krim-global-interface\.css/g) || []).length;
  if (cssCount !== 1) failures.push("Phase 9 page must load exactly one shared KRIM stylesheet: " + file);
  if (!/<body\b[^>]*class=["'][^"']*\bkrim-global-shell\b/i.test(source)) failures.push("Phase 9 page is missing the KRIM global shell: " + file);
  const expectedHref = /^(?:app\/|public\/(?:warehouse|operations|partner|shipments)\/)/.test(file) ? "../../core/krim-global-interface.css" : "../core/krim-global-interface.css";
  if (!head.includes('href="' + expectedHref + '"')) failures.push("Phase 9 page has an incorrect shared stylesheet path (expected " + expectedHref + "): " + file);
  if (head.lastIndexOf("krim-global-interface.css") < head.lastIndexOf("</style>")) failures.push("Phase 9 global stylesheet must follow inline page styles: " + file);
}
const phaseNineOperationsEntry = existsSync("public/operations/index.html") ? readFileSync("public/operations/index.html", "utf8") : "";
if (!phaseNineOperationsEntry.includes('href="../../core/krim-global-interface.css"')) failures.push("Phase 9 shared operations workbench must declare the shared stylesheet.");
if (!/<body\b[^>]*class=["'][^"']*\bkrim-global-shell\b/i.test(phaseNineOperationsEntry)) failures.push("Phase 9 shared operations workbench is missing the KRIM global shell.");
for (const [file, target, forbiddenSample] of [
  ["public/shipments/transport-legs.html", /location\.replace\(["']\.\.\/\.\.\/app\/operations\/index\.html/, "SHP-2026-OCT-9901"],
  ["public/shipments/shipment-documents.html", /location\.replace\(["']\.\.\/\.\.\/app\/customs\/index\.html/, "SHP-2026-OCT-9901"],
  ["public/shipments/shipment-exceptions.html", /location\.replace\(["']\.\.\/\.\.\/app\/operations\/index\.html/, "SHP-2026-OCT-9901"],
]) {
  const source = existsSync(file) ? readFileSync(file, "utf8") : "";
  if (!target.test(source)) failures.push("Phase 9 legacy workflow does not redirect to the canonical role workspace: " + file);
  if (source.includes(forbiddenSample)) failures.push("Phase 9 legacy workflow still contains a fixed sample shipment reference: " + file);
}
const phaseNineDirectory = existsSync("public/global-workflows.html") ? readFileSync("public/global-workflows.html", "utf8") : "";
for (const [label, pattern] of [
  ["transport-leg directory entry routes to Operations", /href=["']\.\.\/app\/operations\/index\.html["'][^>]*data-search=["'][^"']*transport legs/],
  ["document directory entry routes to Customs", /href=["']\.\.\/app\/customs\/index\.html["'][^>]*data-search=["'][^"']*shipment documents/],
  ["exception directory entry routes to Operations", /href=["']\.\.\/app\/operations\/index\.html["'][^>]*data-search=["'][^"']*shipment exceptions/],
]) {
  if (!pattern.test(phaseNineDirectory)) failures.push("Phase 9 workflow directory routing check missing: " + label);
}

const globalInterfaceCss = existsSync("core/krim-global-interface.css") ? readFileSync("core/krim-global-interface.css", "utf8") : "";
for (const token of ["--krim-global-navy", "--krim-global-blue", "--krim-global-line", ":where(input,select,textarea)", ":where(button,.btn", ":focus-visible"]) {
  if (!globalInterfaceCss.includes(token)) failures.push("Missing global interface design token/component: " + token);
}

// Global Operations backend wiring: all 12 registers must use the shared authenticated adapter,
 // and the adapter must remain syntactically valid JavaScript.
const globalOperationsModules = [
  "network-coverage", "trade-lane-management", "trade-document-packs", "landed-cost",
  "customer-support-cases", "cargo-claims-disputes", "carrier-contracts", "fleet-maintenance",
  "order-fulfilment", "reverse-logistics", "market-regulatory-config", "business-continuity",
];
for (const moduleName of globalOperationsModules) {
  const file = "public/global-operations/" + moduleName + ".html";
  const source = existsSync(file) ? readFileSync(file, "utf8") : "";
  if (!source) { failures.push("Global Operations page is missing: " + file); continue; }
  if (!source.includes('src="../krim-global-operations.js"')) failures.push("Global Operations page is not wired to the shared Supabase adapter: " + file);
  if (source.includes("Added to this page preview only")) failures.push("Global Operations page still contains local-only preview saving: " + file);
  const sdk = source.indexOf("supabase-js");
  const config = source.indexOf("../../config.js");
  const adapter = source.indexOf("../krim-global-operations.js");
  if (!(sdk >= 0 && config > sdk && adapter > config)) failures.push("Global Operations scripts must load SDK, config, then adapter: " + file);
}
const globalOpsSyntax = spawnSync(process.execPath, ["--check", "public/krim-global-operations.js"], { encoding: "utf8" });
if (globalOpsSyntax.status !== 0) failures.push("Global Operations Supabase adapter has a JavaScript syntax error: " + (globalOpsSyntax.stderr || globalOpsSyntax.stdout || "unknown error"));


 // Platform Admin schema contract: prevent stale column names from reaching the live PostgREST API.
 const platformAdminPage = existsSync("app/platform-admin/index.html") ? readFileSync("app/platform-admin/index.html", "utf8") : "";
 const globalAdminFunction = existsSync("supabase/functions/global-admin-control/index.ts") ? readFileSync("supabase/functions/global-admin-control/index.ts", "utf8") : "";
 if (!platformAdminPage) failures.push("Platform Admin control page is missing.");
 if (!platformAdminPage.includes('["customer_organization_id","Customer organization ID"]')) failures.push("Platform Admin shipment table must use the canonical customer_organization_id field.");
 if (!platformAdminPage.includes('"customer_organization_id"')) failures.push("Platform Admin table renderer must recognize the canonical customer_organization_id field.");
 if (/shipments:\[\["id","ID"\],\["shipment_number","Shipment"\],\["status","Status"\],\["organization_id","Organization ID"\]/.test(platformAdminPage)) failures.push("Platform Admin shipment table still references the obsolete organization_id field.");
 if (!globalAdminFunction) failures.push("Version-controlled global-admin-control Edge Function source is missing.");
 if (!globalAdminFunction.includes('rows("krim_shipments","id,shipment_number,status,customer_organization_id,created_at,updated_at")')) failures.push("global-admin-control shipment query must use the canonical organization field.");
 if (!globalAdminFunction.includes('rows("krim_quotes","id,shipment_id,status,customer_organization_id,created_at,updated_at")')) failures.push("global-admin-control quote query must use valid canonical quote columns.");
 if (/rows\("krim_(shipments|quotes)","[^"]*,organization_id,/.test(globalAdminFunction)) failures.push("global-admin-control still contains an obsolete organization_id query.");

// Prevent UI-only helpers and static finance mockups from claiming live verification.
const adminRuntimeTruth = readFileSync("public/admin/admin-runtime.js", "utf8");
const productionRuntimeTruth = readFileSync("public/production/production-runtime.js", "utf8");
const treasuryPageTruth = readFileSync("public/finance/treasury-dashboard.html", "utf8");
const revenuePageTruth = readFileSync("public/finance/revenue-reports.html", "utf8");
if (adminRuntimeTruth.includes("ISO 27001 / SOC 2 Audit Logger: ONLINE") || adminRuntimeTruth.includes("SHA-256 Cryptographic Seals Active")) failures.push("Admin UI helper must not claim unverified SIEM/compliance/audit-sealing status.");
if (productionRuntimeTruth.includes("Cryptographic SHA-256 Release Hash: VERIFIED") || productionRuntimeTruth.includes("All 18 Phases Locked")) failures.push("Production UI helper must not claim an unperformed release freeze/hash verification.");
if (!treasuryPageTruth.includes("Not an active bank, treasury or transfer workflow") || !/partner-direct launch controls/i.test(treasuryPageTruth)) failures.push("Treasury dashboard must remain retired and explicitly unavailable in partner-direct mode.");
if (!revenuePageTruth.includes("No verified KRIM revenue data available") || !revenuePageTruth.includes("No reconciled paid invoices or subscription transactions are available yet")) failures.push("Revenue reports must show an honest empty state until reconciled subscription revenue exists.");

// Additional Step 7 regression guards: these inspect source only and do not claim
// that provider-signed integration tests or financial settlement have run.
for (const [label, token] of [
  ["raw-body HMAC signing", "const rawBody = await req.text()"],
  ["constant-time signature comparison", "safeEqual(receivedBytes, expectedBytes)"],
  ["failed-payment no-downgrade guard", 'failedOrder.status !== "paid"'],
  ["failed-payment conditional update", '.neq("status", "paid")'],
  ["conflicting paid-payment protection", "PAYMENT_ID_CONFLICT"],
  ["conditional captured-payment transition", '.eq("status", paymentOrder.status)'],
  ["webhook event completion timestamp", 'processed_at: new Date().toISOString()'],
  ["retryable concurrent event delivery", "Webhook event is already being processed; retry delivery"],
  ["unsupported event fail-closed behavior", "UNSUPPORTED_EVENT_TYPE"],
]) {
  if (!razorpayWebhookSource.includes(token)) {
    failures.push("Step 7 webhook regression guard missing (" + label + "): " + token);
  }
}
if (!razorpayWebhookSource.includes('if (existingEvent?.processed)') ||
    !razorpayWebhookSource.includes('if (!existingEvent)') ||
    !razorpayWebhookSource.includes('insertEventError.code === "23505"')) {
  failures.push("Step 7 webhook must distinguish completed duplicates from retryable in-progress/failed deliveries.");
}

// Step 7 finance workspaces must display real RLS-scoped records without adding
// browser-side financial write paths or implying that a payment is a payout.
const paymentProcessingPage = readFileSync("app/finance/payment-processing.html", "utf8");
const partnerSettlementPage = readFileSync("app/finance/partner-settlements.html", "utf8");
for (const [label, source, tokens] of [
  ["payment processing register", paymentProcessingPage, ["from(\"payment_orders\")", "paymentRegisterRows", "paymentRegisterState", "Data unavailable. No zero-count claim is made."]],
  ["partner payable register", partnerSettlementPage, ["from(\"krim_partner_payables\")", "payableRegisterRows", "payableRegisterState", "A payable is not an executed payout."]],
]) {
  for (const token of tokens) {
    if (!source.includes(token)) failures.push("Step 7 " + label + " is missing read-only register safeguard: " + token);
  }
  if (/\.from\(["'](?:payment_orders|krim_partner_payables)["']\)[\s\S]{0,500}\.(?:insert|update|upsert|delete)\(/.test(source)) {
    failures.push("Step 7 " + label + " must remain read-only in the browser.");
  }
}
for (const token of ["capacity_binding_id", "krim_capacity_leg_bindings", "krim_capacity_reservations", "CAPACITY_RESERVATION_REQUIRED", "CAPACITY_BINDING_NOT_CONFIRMED", "CAPACITY_RESERVATION_NOT_CONFIRMED"]) {
  if (!razorpayVerifySource.includes(token)) failures.push("Step 7 payment verification capacity regression guard missing: " + token);
}

// Cross-app shipment lifecycle contract: source-level regression guards only.
// These checks ensure all three mobile clients call the secured workflow contracts;
// they do not simulate authenticated users or claim a live shipment was executed.
const customerMobile = existsSync("mobile/krim-customer/src/CustomerWorkspace.tsx") ? readFileSync("mobile/krim-customer/src/CustomerWorkspace.tsx", "utf8") : "";
if (/react-native-webview|razorpayCheckoutHtml|verify-razorpay-payment|create-global-razorpay-order/.test(customerMobile)) failures.push("Customer mobile app must not contain an active or dormant KRIM freight checkout implementation in partner-direct mode.");

if (/functions\.invoke\(["']create-global-razorpay-order/.test(customerMobile)) failures.push("Customer mobile app must not invoke freight order creation during partner-direct launch.");
const partnerMobileWorkspace = existsSync("mobile/krim-partner/src/PartnerWorkspace.tsx") ? readFileSync("mobile/krim-partner/src/PartnerWorkspace.tsx", "utf8") : "";
const partnerRepository = existsSync("mobile/krim-partner/src/lib/partnerRepository.ts") ? readFileSync("mobile/krim-partner/src/lib/partnerRepository.ts", "utf8") : "";
const partnerMobile = partnerMobileWorkspace + "\\n" + partnerRepository;
const driverMobile = existsSync("mobile/krim-driver/src/DriverWorkspace.tsx") ? readFileSync("mobile/krim-driver/src/DriverWorkspace.tsx", "utf8") : "";
for (const [label, source, tokens] of [
  ["Customer mobile", customerMobile, ['krim_create_global_shipment_idempotent', 'krim_accept_global_quote', 'Partner-direct launch: KRIM does not collect freight payments.', 'loadCustomerShipments', 'loadCustomerQuotes', 'Partner-direct launch']],
  ["Partner mobile", partnerMobile, ['krim_submit_partner_quote', 'krim_respond_to_partner_assignment', 'loadPartnerAssignments', 'response_deadline.gt.', 'registered_business']],
  ["Driver mobile", driverMobile, ['krim_driver_accept_assignment', 'krim_driver_record_trip_event', 'krim_driver_submit_delivery_pod', 'krim-driver-evidence', 'image/jpeg', 'image/png', 'image/webp']],
]) {
  if (!source) { failures.push(label + " source is missing."); continue; }
  for (const token of tokens) if (!source.includes(token)) failures.push(label + " lifecycle contract is missing: " + token);
}
if (partnerMobile && (!partnerMobile.includes("organizations.length!==1") || !partnerMobile.includes("activeCaps===0") || !partnerMobile.includes('selected?.partner_account_mode!=="registered_business"'))) {
  failures.push("Partner quote submission must remain gated to one unambiguous registered, verified and capable organization.");
}
if (partnerMobile && !partnerMobile.includes("Assignment responses are paused until this account has one unambiguous partner organization.")) {
  failures.push("Partner assignment accept/decline must be blocked when organization context is ambiguous.");
}
const podAdminSource = existsSync("app/platform-admin/delivery-pod-verification.html") ? readFileSync("app/platform-admin/delivery-pod-verification.html", "utf8") : "";
const platformAdminNavigation = existsSync("app/platform-admin/index.html") ? readFileSync("app/platform-admin/index.html", "utf8") : "";
for (const token of ["krim_admin_list_delivery_pods", "krim_admin_review_delivery_pod", "AAL2", "PRIVATE"]) {
  if (!podAdminSource.includes(token)) failures.push("Admin POD review workspace is missing protected workflow control: " + token);
}
if (!platformAdminNavigation.includes('href="delivery-pod-verification.html"')) failures.push("Platform Admin home must link to the protected POD review workspace.");
const podAdminMigration = existsSync("supabase/migrations/20261106010000_add_admin_pod_verification_and_delivery_authorization.sql")
  ? readFileSync("supabase/migrations/20261106010000_add_admin_pod_verification_and_delivery_authorization.sql", "utf8") : "";
for (const token of ["auth.uid()", "aal2", "private.krim_has_permission", "krim_internal_verify_delivery_pod", "krim_internal_authorize_delivery"]) {
  if (!podAdminMigration.includes(token)) failures.push("POD database authorization migration is missing control: " + token);
}

console.log(`KRIM production smoke check: ${required.length} required paths, ${checkedScripts} inline scripts checked, ${customerOsPages.length} Customer OS pages / ${checkedCustomerOsLinks} Customer OS links, ${allHtmlFiles.length} HTML pages / ${checkedAllSiteLinks} site links audited.`);
if (failures.length) {
  console.error(failures.map((f) => `FAIL: ${f}`).join("\n"));
  process.exit(1);
}
console.log("PASS: required checkout/partner files, payment guards, pricing fail-closed guard, and privileged RPC ACL migration are present.");
