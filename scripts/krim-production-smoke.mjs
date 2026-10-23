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
  "app/customer/index.html",
  "platform/krim-supabase.js",
  "supabase/migrations/20261018193607_implement_rate_card_backed_tariff_quotes.sql",
  "supabase/migrations/20261019100000_restore_rate_card_backed_tariff_quotes.sql",
  "supabase/migrations/20261019000100_fail_closed_tariff_quotes_without_approved_rate_cards.sql",
  "supabase/migrations/20261019020919_restrict_privileged_krim_rpc_to_authenticated.sql",
  "supabase/functions/create-global-razorpay-order/index.ts",
  "supabase/functions/verify-razorpay-payment/index.ts",
  "public/customer-os/customer-services/shipment-list.html",
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

// Keep the Customer OS single-source-of-truth: exact duplicate HTML files are failures,
// and every route must use the shared responsive design layer.
const exactPageOwners = new Map();
for (const file of customerOsPages) {
  const html = readFileSync(file, "utf8");
  const previous = exactPageOwners.get(html);
  if (previous) failures.push(`Duplicate Customer OS page content: ${previous} and ${file}`);
  else exactPageOwners.set(html, file);
  if (!html.includes("customer-os-global.css")) {
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
    if (!raw || raw.includes("<") || /\\s/.test(raw) || /^(?:[a-z][a-z0-9+.-]*:|\/\/|#)/i.test(raw)) continue;
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
    if (!raw || raw.includes("<") || /\\s/.test(raw) || /^(?:[a-z][a-z0-9+.-]*:|\/\/|#)/i.test(raw)) continue;
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
  ["payment checkout", "public/shipper/payment-checkout.html"],
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
const customerQuoteRequest = existsSync("public/customer/quote-request.html") ? readFileSync("public/customer/quote-request.html", "utf8") : "";
const customerInvoices = existsSync("public/customer-os/customer-services/invoices.html") ? readFileSync("public/customer-os/customer-services/invoices.html", "utf8") : "";
const customerSupport = existsSync("public/customer-os/customer-services/support.html") ? readFileSync("public/customer-os/customer-services/support.html", "utf8") : "";
const customerClaims = existsSync("public/customer-os/customer-services/claims.html") ? readFileSync("public/customer-os/customer-services/claims.html", "utf8") : "";
const customerPaymentHistory = existsSync("public/customer-os/customer-services/payment-history.html") ? readFileSync("public/customer-os/customer-services/payment-history.html", "utf8") : "";
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
  ["bookingRequest", "public/shipper/booking-request.html"],
].map(([key, file]) => [key, existsSync(file) ? readFileSync(file, "utf8") : ""]));

if (/href=["'][^"']*(?:admin|platform-admin|global-control-centre|global-control-center)[^"']*["']/i.test(phaseOneSources.homepage) || /href=["'][^"']*(?:admin|platform-admin|global-control-centre|global-control-center)[^"']*["']/i.test(phaseOneSources.access)) {
  failures.push("Public homepage/access portal must not expose privileged platform-administrator routes.");
}

for (const [label, source, pattern] of [
  ["public homepage routes customers to the access portal", phaseOneSources.homepage, /href=["'][^"']*auth\/access\.html["']/i],
  ["customer booking uses a relative login handoff instead of a hardcoded project prefix", phaseOneSources.bookingRequest, /window\.location\.replace\("\.\.\/\.\.\/auth\/login\.html\?role=customer&next="/],
  ["customer booking page contains no hardcoded GitHub Pages project prefix", phaseOneSources.bookingRequest, !/\/logistics-saas\//.test(phaseOneSources.bookingRequest)],
  ["customer login safely allows booking return paths on project and custom-domain deployments", phaseOneSources.login, /allowedBookingPaths[\s\S]*?\/public\/shipper\/booking-request\.html[\s\S]*?\/shipper\/booking-request\.html/],
  ["access portal offers canonical customer registration and role-checked sign-in", phaseOneSources.access, /href=["']signup\.html["'][\s\S]*?href=["']login\.html\?role=customer["']/i],
  ["customer registration uses Supabase Auth with customer and organization metadata", phaseOneSources.signup, /auth\.signUp\([\s\S]*?company_name:org[\s\S]*?krim_account_type:"customer"/],
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

console.log(`KRIM production smoke check: ${required.length} required paths, ${checkedScripts} inline scripts checked, ${customerOsPages.length} Customer OS pages / ${checkedCustomerOsLinks} Customer OS links, ${allHtmlFiles.length} HTML pages / ${checkedAllSiteLinks} site links audited.`);
if (failures.length) {
  console.error(failures.map((f) => `FAIL: ${f}`).join("\n"));
  process.exit(1);
}
console.log("PASS: required checkout/partner files, payment guards, pricing fail-closed guard, and privileged RPC ACL migration are present.");
