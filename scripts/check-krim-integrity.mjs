import { access, readFile } from "node:fs/promises";
import { constants } from "node:fs";
import path from "node:path";

const root = process.cwd();
const requiredFiles = [
  "index.html",
  "config.js",
  "platform/krim-config.js",
  "platform/krim-supabase.js",
  "auth/login.html",
  "auth/signup.html",
  "auth/partner-signup.html",
  "app/customer/index.html",
  "app/partner/index.html",
  "public/shipper/booking-request.html",
  "public/partner/partner-onboarding.html",
  "public/quote-result.html",
  "supabase/functions/public-shipment-tracking/index.ts",
  "docs/KRIM-VERIFIED-AUDIT-2026-10-16.md"
];

const failures = [];
for (const relative of requiredFiles) {
  try {
    await access(path.join(root, relative), constants.R_OK);
  } catch {
    failures.push(`Missing required file: ${relative}`);
  }
}

const frontendFiles = [
  "config.js",
  "platform/krim-config.js",
  "platform/krim-supabase.js",
  "public/quote-result.html"
];
const privilegedAssignmentPatterns = [
  /SUPABASE_SERVICE_ROLE_KEY\s*=\s*["'`][^"'\`]+["'`]/i,
  /RAZORPAY_KEY_SECRET\s*=\s*["'`][^"'\`]+["'`]/i,
  /RAZORPAY_WEBHOOK_SECRET\s*=\s*["'`][^"'\`]+["'`]/i
];
for (const relative of frontendFiles) {
  try {
    const source = await readFile(path.join(root, relative), "utf8");
    for (const pattern of privilegedAssignmentPatterns) {
      if (pattern.test(source)) {
        failures.push(`Possible privileged secret assignment in frontend file: ${relative}`);
      }
    }
  } catch {
    // Missing files are reported by the required-file check above.
  }
}

const checkout = await readFile(path.join(root, "public/quote-result.html"), "utf8").catch(() => "");
for (const expected of ["create-global-razorpay-order", "verify-razorpay-payment"]) {
  if (!checkout.includes(expected)) failures.push(`Checkout does not reference expected server endpoint: ${expected}`);
}
if (/functions\/v1\/process-payment(?:["'`]|\s|\?)/.test(checkout)) {
  failures.push("Checkout references the legacy process-payment endpoint instead of the verified payment flow.");
}
if (/amountInINR\s*=\s*\d+/.test(checkout)) {
  failures.push("Checkout contains a hardcoded payable amount.");
}

if (failures.length) {
  console.error("KRIM integrity check FAILED:");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exitCode = 1;
} else {
  console.log(`KRIM integrity check passed: ${requiredFiles.length} required files present; checkout contract markers verified.`);
}
