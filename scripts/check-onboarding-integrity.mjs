import fs from "node:fs";
import path from "node:path";

const requiredFiles = [
  "index.html",
  "public/get-started.html",
  "auth/signup.html",
  "auth/partner-signup.html",
  "auth/login.html",
  "auth/auth-callback.html",
  "public/partner/partner-onboarding.html",
  "public/quote-result.html",
  "config.js",
  "core/krim-config.js",
  "public/app/app-store.js",
  "public/app/app-runtime.js"
];

const errors = [];
for (const file of requiredFiles) {
  if (!fs.existsSync(file)) errors.push(`Missing required file: ${file}`);
}

function resolveLocalReference(fromFile, reference) {
  const clean = reference.split(/[?#]/, 1)[0];
  if (!clean || clean.endsWith("/")) return null;
  if (/^(https?:|mailto:|tel:|data:|javascript:|#)/i.test(clean)) return null;
  if (clean.startsWith("/")) {
    errors.push(`Root-absolute path is not portable to GitHub Pages: ${fromFile} -> ${reference}`);
    return null;
  }
  return path.posix.normalize(path.posix.join(path.posix.dirname(fromFile), clean));
}

for (const file of requiredFiles.filter((name) => name.endsWith(".html"))) {
  if (!fs.existsSync(file)) continue;
  const html = fs.readFileSync(file, "utf8");
  const refs = [...html.matchAll(/(?:href|src)=["']([^"']+)["']/g)].map((match) => match[1]);
  for (const ref of refs) {
    const target = resolveLocalReference(file, ref);
    if (!target) continue;
    if (/\.(html|js|css|json|xml|txt|png|svg|webp|ico)$/i.test(target) && !fs.existsSync(target)) {
      errors.push(`Broken local reference: ${file} -> ${ref} (resolved to ${target})`);
    }
  }
}

const mustContain = [
  ["auth/signup.html", "krim_provision_customer_organization"],
  ["auth/partner-signup.html", "krim_provision_partner_organization"],
  ["auth/login.html", "krim_provision_partner_organization"],
  ["auth/auth-callback.html", "krim_provision_customer_organization"],
  ["auth/auth-callback.html", "krim_provision_partner_organization"],
  ["public/partner/partner-onboarding.html", "krim_submit_partner_onboarding"],
  ["public/partner/partner-onboarding.html", 'from("krim-partner-verification")'],
  ["public/quote-result.html", '"create-global-razorpay-order"'],
  ["public/quote-result.html", '"verify-razorpay-payment"'],
  ["public/app/app-runtime.js", "client.auth.getSession()"],
  ["public/app/app-store.js", 'permissions: []'],
  ["core/krim-config.js", "https://ebltviniygljwwseplph.supabase.co"]
];
for (const [file, text] of mustContain) {
  if (fs.existsSync(file) && !fs.readFileSync(file, "utf8").includes(text)) {
    errors.push(`Expected integration marker missing: ${file} -> ${text}`);
  }
}

const mustNotContain = [
  ["auth/signup.html", "Provisioning enterprise tenant"],
  ["auth/partner-signup.html", "Registering carrier fleet for"],
  ["auth/auth-callback.html", "./js/auth-core.js"],
  ["public/partner/partner-onboarding.html", "File Dialog Opened"],
  ["public/app/app-runtime.js", "demo_jwt_99824"],
  ["public/app/app-store.js", "Global Supply Chain Corp"],
  ["core/krim-config.js", "your-supabase-instance.supabase.co"],
  ["public/quote-result.html", "/logistics-saas/"]
];
for (const [file, text] of mustNotContain) {
  if (fs.existsSync(file) && fs.readFileSync(file, "utf8").includes(text)) {
    errors.push(`Forbidden demo/legacy marker remains: ${file} -> ${text}`);
  }
}

if (errors.length) {
  console.error("KRIM onboarding integrity checks failed:");
  for (const error of errors) console.error(" - " + error);
  process.exit(1);
}
console.log(`KRIM onboarding integrity checks passed (${requiredFiles.length} required files checked).`);
