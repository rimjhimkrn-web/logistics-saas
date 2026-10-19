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
  "supabase/migrations/20261019000100_fail_closed_tariff_quotes_without_approved_rate_cards.sql",
  "supabase/migrations/20261019020919_restrict_privileged_krim_rpc_to_authenticated.sql",
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

const pricingMigration = "supabase/migrations/20261019000100_fail_closed_tariff_quotes_without_approved_rate_cards.sql";
if (existsSync(pricingMigration)) {
  const sql = readFileSync(pricingMigration, "utf8");
  if (!/Tariff quote unavailable: no approved active rate card is configured/i.test(sql)) {
    failures.push("Fail-closed tariff pricing guard missing from migration.");
  }
} else {
  failures.push("Required fail-closed tariff pricing migration is missing.");
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

console.log(`KRIM production smoke check: ${required.length} required paths, ${checkedScripts} inline scripts checked.`);
if (failures.length) {
  console.error(failures.map((f) => `FAIL: ${f}`).join("\n"));
  process.exit(1);
}
console.log("PASS: required checkout/partner files, payment guards, pricing fail-closed guard, and privileged RPC ACL migration are present.");
