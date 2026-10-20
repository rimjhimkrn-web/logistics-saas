import { readFileSync, existsSync, writeFileSync, unlinkSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join } from "node:path";

const required = [
  "public/quote-result.html",
  "public/shipper/spot-approvals.html",
  "public/partner/accepted-loads.html",
  "public/partner/dispatch-assignment.html",
  "config.js",
  "platform/krim-supabase.js",
  "supabase/migrations/20261018193607_implement_rate_card_backed_tariff_quotes.sql",
  "supabase/migrations/20261019100000_restore_rate_card_backed_tariff_quotes.sql",
  "supabase/migrations/20261019000100_fail_closed_tariff_quotes_without_approved_rate_cards.sql",
  "supabase/migrations/20261019020919_restrict_privileged_krim_rpc_to_authenticated.sql",
  "supabase/functions/create-global-cashfree-order/index.ts",
  "supabase/functions/verify-global-cashfree-payment/index.ts",
  "supabase/functions/cashfree-payment-webhook/index.ts",
  "app/partner/index.html",
  "public/partner/partner-onboarding.html",
  "public/partner/load-marketplace.html",
  "public/partner/available-loads.html",
  "public/partner/submit-quote.html",
  "public/partner/quote-history.html",
  "public/partner/accepted-loads.html",
  "public/shipper/booking-request.html",
  "public/shipper/active-shipments.html",
  "public/partner/partner-verification-control.html",
  "supabase/migrations/20261020074510_global_partner_onboarding_location_hardening.sql",
  "supabase/migrations/20261020074900_partner_verification_admin_review_workflow.sql",
  "supabase/migrations/20261020075927_partner_account_modes_test_and_individual_interest.sql",
  "supabase/migrations/20261020080517_add_partner_account_mode_column.sql",
];

const failures = [];
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

const checkout = existsSync("public/quote-result.html") ? readFileSync("public/quote-result.html", "utf8") : "";
for (const [label, pattern] of [
  ["server-created Razorpay order", /create-global-razorpay-order/],
  ["server-side payment verification", /verify-razorpay-payment/],
  ["payment verification result guard", /verification\?\.success\s*\|\|\s*!verification\?\.verified/],
]) {
  if (!pattern.test(checkout)) failures.push(`Checkout guard missing: ${label}`);
}

const cashfreeOrder = existsSync("supabase/functions/create-global-cashfree-order/index.ts") ? readFileSync("supabase/functions/create-global-cashfree-order/index.ts", "utf8") : "";
const cashfreeVerify = existsSync("supabase/functions/verify-global-cashfree-payment/index.ts") ? readFileSync("supabase/functions/verify-global-cashfree-payment/index.ts", "utf8") : "";
const cashfreeWebhook = existsSync("supabase/functions/cashfree-payment-webhook/index.ts") ? readFileSync("supabase/functions/cashfree-payment-webhook/index.ts", "utf8") : "";
for (const [label, source, requiredText] of [
  ["Cashfree order endpoint is sandbox-only", cashfreeOrder, "sandbox.cashfree.com/pg"],
  ["Cashfree order requires authenticated user", cashfreeOrder, "auth.getUser"],
  ["Cashfree payment verification checks provider status", cashfreeVerify, "order_status"],
  ["Cashfree webhook verifies signature", cashfreeWebhook, "x-webhook-signature"],
  ["Cashfree webhook independently verifies provider status", cashfreeWebhook, "paymentsRes.ok"],
  ["Cashfree webhook accepts retryable pending orders", cashfreeWebhook, '"pending"'],
]) {
  if (!source.includes(requiredText)) failures.push(`Cashfree safety check missing: ${label}`);
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
const partnerOnboarding = existsSync("public/partner/partner-onboarding.html") ? readFileSync("public/partner/partner-onboarding.html", "utf8") : "";
const partnerBid = existsSync("public/partner/submit-quote.html") ? readFileSync("public/partner/submit-quote.html", "utf8") : "";
const booking = existsSync("public/shipper/booking-request.html") ? readFileSync("public/shipper/booking-request.html", "utf8") : "";
for (const [label, source, pattern] of [
  ["partner workspace distinguishes development/test mode", partnerWorkspace, /development_test/],
  ["partner workspace clearly locks live operations in test mode", partnerWorkspace, /Live commercial operations are disabled/],
  ["marketplace reads backend partner account mode", partnerMarketplace, /partner_account_mode/],
  ["marketplace blocks bidding in development/test mode", partnerMarketplace, /!commercialAccess\s*\|\|\s*!currentPartnerOrgId\s*\|\|\s*demoMode/],
  ["marketplace submits through the dedicated partner quote RPC", partnerMarketplace, /rpc\(['"]krim_submit_partner_quote['"]/],
  ["onboarding supports the three explicit partner pathways", partnerOnboarding, /development_test[\s\S]*individual_interest[\s\S]*registered_business/i],
  ["onboarding saves account mode through the backend RPC", partnerOnboarding, /rpc\(['"]krim_set_partner_account_mode['"]/],
  ["partner bid page requires verified eligible organization", partnerBid, /Bidding is locked[\s\S]*verified/i],
  ["customer booking uses the secure shipment creation RPC", booking, /rpc\(['"]krim_create_global_shipment['"]/],
  ["customer booking rejects identical origin and destination", booking, /origin\s*===\s*destination/],
]) {
  if (!pattern.test(source)) failures.push(`Partner/customer lifecycle safety check missing: ${label}`);
}

console.log(`KRIM production smoke check: ${required.length} required paths, ${checkedScripts} inline scripts checked.`);
if (failures.length) {
  console.error(failures.map((f) => `FAIL: ${f}`).join("\n"));
  process.exit(1);
}
console.log("PASS: required checkout/partner files, payment guards, pricing fail-closed guard, and privileged RPC ACL migration are present.");
