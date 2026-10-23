import { readFileSync, existsSync, writeFileSync, unlinkSync, readdirSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join, dirname, resolve as pathResolve } from "node:path";

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
  "supabase/functions/create-global-razorpay-order/index.ts",
  "supabase/functions/verify-razorpay-payment/index.ts",
  "public/customer-os/customer-services/shipment-list.html",
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
  "control/partner-verification.html",
  "supabase/migrations/20261020074510_global_partner_onboarding_location_hardening.sql",
  "supabase/migrations/20261020074900_partner_verification_admin_review_workflow.sql",
  "supabase/migrations/20261020133000_partner_account_modes_test_and_individual_interest.sql",
  "supabase/migrations/20261020141000_add_partner_account_mode_column.sql",
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


function listHtmlFiles(dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const file = join(dir, entry.name);
    return entry.isDirectory() ? listHtmlFiles(file) : entry.isFile() && entry.name.toLowerCase().endsWith(".html") ? [file] : [];
  });
}

const customerOsPages = listHtmlFiles("public/customer-os");
let checkedCustomerOsLinks = 0;
for (const file of customerOsPages) {
  const html = readFileSync(file, "utf8");
  for (const match of html.matchAll(/(?:href|src|action)=["']([^"'#]+)["']/gi)) {
    const raw = match[1].trim();
    if (!raw || /^(?:[a-z][a-z0-9+.-]*:|\/\/|#)/i.test(raw)) continue;
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

const checkout = existsSync("public/quote-result.html") ? readFileSync("public/quote-result.html", "utf8") : "";
for (const [label, pattern] of [
  ["server-created Razorpay order", /create-global-razorpay-order/],
  ["server-side payment verification", /verify-razorpay-payment/],
  ["payment verification result guard", /result\.success\s*!==\s*true[\s\S]*?result\.verified\s*!==\s*true[\s\S]*?result\.status\s*!==\s*["']paid["']/],
]) {
  if (!pattern.test(checkout)) failures.push(`Checkout guard missing: ${label}`);
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
const partnerOnboarding = existsSync("public/partner/partner-onboarding.html") ? readFileSync("public/partner/partner-onboarding.html", "utf8") : "";
const partnerBid = existsSync("public/partner/submit-quote.html") ? readFileSync("public/partner/submit-quote.html", "utf8") : "";
const booking = existsSync("public/shipments/shipment-create.html") ? readFileSync("public/shipments/shipment-create.html", "utf8") : "";
const customerShipmentList = existsSync("public/customer-os/customer-services/shipment-list.html") ? readFileSync("public/customer-os/customer-services/shipment-list.html", "utf8") : "";
for (const [label, source, pattern] of [
  ["partner workspace distinguishes development/test mode", partnerWorkspace, /development_test/],
  ["partner workspace clearly locks live operations in test mode", partnerWorkspace, /Live commercial operations are disabled/],
  ["marketplace reads backend partner account mode", partnerMarketplace, /partner_account_mode/],
  ["marketplace blocks bidding in development/test mode", partnerMarketplace, /!commercialAccess\s*\|\|\s*!currentPartnerOrgId\s*\|\|\s*demoMode/],
  ["marketplace submits through the dedicated partner quote RPC", partnerMarketplace, /rpc\(['"]krim_submit_partner_quote['"]/],
  ["onboarding supports the three explicit partner pathways", partnerOnboarding, /development_test[\s\S]*individual_interest[\s\S]*registered_business/i],
  ["onboarding saves account mode through the backend RPC", partnerOnboarding, /rpc\(['"]krim_set_partner_account_mode['"]/],
  ["partner bid page requires verified eligible organization", partnerBid, /partner_verification_status[\s\S]*partner_lifecycle_status[\s\S]*partner_compliance_status/i],
  ["customer booking uses the secure shipment creation RPC", booking, /rpc\(['"]krim_create_global_shipment['"]/],
  ["customer booking rejects identical origin and destination", booking, /originId\s*===\s*destinationId/],
  ["Customer OS shipment list reads live shipment records", customerShipmentList, /from\(['"]krim_shipments['"]\)/],
  ["Customer OS shipment list is scoped to active organization membership", customerShipmentList, /krim_organization_members[\s\S]*?status[\s\S]*?active[\s\S]*?customerIds/],
]) {
  if (!pattern.test(source)) failures.push(`Partner/customer lifecycle safety check missing: ${label}`);
}

console.log(`KRIM production smoke check: ${required.length} required paths, ${checkedScripts} inline scripts checked, ${customerOsPages.length} Customer OS pages and ${checkedCustomerOsLinks} local links audited.`);
if (failures.length) {
  console.error(failures.map((f) => `FAIL: ${f}`).join("\n"));
  process.exit(1);
}
console.log("PASS: required checkout/partner files, payment guards, pricing fail-closed guard, and privileged RPC ACL migration are present.");
