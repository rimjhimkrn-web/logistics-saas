import { readFileSync, writeFileSync, readdirSync, existsSync } from "node:fs";
import { join, dirname, resolve } from "node:path";

function htmlFiles(dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const file = join(dir, entry.name);
    if (entry.isDirectory()) {
      if ([".git", "node_modules", ".next", "dist"].includes(entry.name)) return [];
      return htmlFiles(file);
    }
    return entry.isFile() && entry.name.toLowerCase().endsWith(".html") ? [file] : [];
  });
}

const canonical = new Map([
  ["/logistics-saas/customer/shipment-list.html", "/logistics-saas/public/customer-os/customer-services/shipment-list.html"],
  ["/logistics-saas/shipments/shipment-list.html", "/logistics-saas/public/customer-os/customer-services/shipment-list.html"],
  ["/logistics-saas/customer-os/customer-services/quote-comparison.html", "/logistics-saas/public/shipper/quote-comparison.html"],
  ["/logistics-saas/customer-os/quotes-pricing/quote-comparison.html", "/logistics-saas/public/shipper/quote-comparison.html"],
  ["/logistics-saas/customer-os/shipper-services/quote-comparison.html", "/logistics-saas/public/shipper/quote-comparison.html"],
  ["/logistics-saas/customer/quote-comparison.html", "/logistics-saas/public/shipper/quote-comparison.html"],
  ["/logistics-saas/quotes/quote-comparison.html", "/logistics-saas/public/shipper/quote-comparison.html"],
  ["/logistics-saas/customer-os/customer-services/quote-request.html", "/logistics-saas/public/customer/quote-request.html"],
  ["/logistics-saas/customer-os/quotes-pricing/quote-request.html", "/logistics-saas/public/customer/quote-request.html"],
  ["/logistics-saas/quotes/quote-request.html", "/logistics-saas/public/customer/quote-request.html"],
  ["/logistics-saas/customer-os/shipper-services/payment-checkout.html", "/logistics-saas/public/shipper/payment-checkout.html"],
  ["/logistics-saas/finance/payment-checkout.html", "/logistics-saas/public/shipper/payment-checkout.html"],
  ["/logistics-saas/src/customer/workspace.html", "/logistics-saas/public/customer/workspace.html"]
]);

let changedFiles = 0;
let changedLinks = 0;
for (const file of htmlFiles(".")) {
  let html = readFileSync(file, "utf8");
  const original = html;
  html = html.replace(/\b(href|src|action)=(["'])([^"'\s]+)\2/gi, (whole, attr, quote, value) => {
    if (!value.startsWith("/") || value.startsWith("//")) return whole;
    const suffixAt = value.search(/[?#]/);
    const path = suffixAt < 0 ? value : value.slice(0, suffixAt);
    const suffix = suffixAt < 0 ? "" : value.slice(suffixAt);
    let normalized = path;

    // GitHub Pages publishes the public/ directory as the site root.
    if (normalized === "/") {
      normalized = "/logistics-saas/";
    } else if (normalized.startsWith("/public/")) {
      normalized = "/logistics-saas" + normalized;
    } else if (!normalized.startsWith("/logistics-saas/")) {
      // Keep API-style paths untouched; normalize file paths that otherwise escape the project base.
      if (/^\/(?:api|rest|rpc|functions)\//i.test(normalized)) return whole;
      if (/\.[a-z0-9]{1,8}$/i.test(normalized)) normalized = "/logistics-saas" + normalized;
      else return whole;
    }
    if (normalized.startsWith("/logistics-saas/") && !normalized.startsWith("/logistics-saas/public/")) {
      const candidate = normalized.slice("/logistics-saas/".length);
      if (!existsSync(candidate) && existsSync(join("public", candidate))) {
        normalized = "/logistics-saas/public/" + candidate;
      }
    }
    normalized = canonical.get(normalized) || normalized;
    const next = normalized + suffix;
    if (next !== value) changedLinks++;
    return `${attr}=${quote}${next}${quote}`;
  });

  // Route relative links to intentionally removed duplicate customer pages to canonical routes.
  html = html.replace(/\b(href|src)=(["'])([^"'#]+)\2/gi, (whole, attr, quote, value) => {
    if (value.startsWith("/") || /^(?:[a-z][a-z0-9+.-]*:|\/\/|#)/i.test(value)) return whole;
    const clean = value.split(/[?#]/)[0];
    const resolved = resolve(dirname(file), clean);
    if (existsSync(resolved)) return whole;
    const name = clean.split("/").pop();
    const routes = {
      "shipment-list.html": "/logistics-saas/public/customer-os/customer-services/shipment-list.html",
      "quote-comparison.html": "/logistics-saas/public/shipper/quote-comparison.html",
      "quote-request.html": "/logistics-saas/public/customer/quote-request.html",
      "payment-checkout.html": "/logistics-saas/public/shipper/payment-checkout.html",
      "partner-onboarding.html": "/logistics-saas/public/partner/partner-onboarding.html",
      "workspace.html": "/logistics-saas/public/customer/workspace.html"
    };
    if (!routes[name]) return whole;
    changedLinks++;
    return `${attr}=${quote}${routes[name]}${value.slice(clean.length)}${quote}`;
  });

  if (html !== original) {
    writeFileSync(file, html, "utf8");
    changedFiles++;
  }
}
console.log(`KRIM Pages link normalization: updated ${changedLinks} links across ${changedFiles} HTML files.`);
