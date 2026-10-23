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
  ["/logistics-saas/customer/shipment-list.html", "/logistics-saas/customer-os/customer-services/shipment-list.html"],
  ["/logistics-saas/shipments/shipment-list.html", "/logistics-saas/customer-os/customer-services/shipment-list.html"],
  ["/logistics-saas/customer-os/customer-services/quote-comparison.html", "/logistics-saas/shipper/quote-comparison.html"],
  ["/logistics-saas/customer-os/quotes-pricing/quote-comparison.html", "/logistics-saas/shipper/quote-comparison.html"],
  ["/logistics-saas/customer-os/shipper-services/quote-comparison.html", "/logistics-saas/shipper/quote-comparison.html"],
  ["/logistics-saas/customer/quote-comparison.html", "/logistics-saas/shipper/quote-comparison.html"],
  ["/logistics-saas/quotes/quote-comparison.html", "/logistics-saas/shipper/quote-comparison.html"],
  ["/logistics-saas/customer-os/customer-services/quote-request.html", "/logistics-saas/customer/quote-request.html"],
  ["/logistics-saas/customer-os/quotes-pricing/quote-request.html", "/logistics-saas/customer/quote-request.html"],
  ["/logistics-saas/quotes/quote-request.html", "/logistics-saas/customer/quote-request.html"],
  ["/logistics-saas/customer-os/shipper-services/payment-checkout.html", "/logistics-saas/shipper/payment-checkout.html"],
  ["/logistics-saas/finance/payment-checkout.html", "/logistics-saas/shipper/payment-checkout.html"],
  ["/logistics-saas/src/customer/workspace.html", "/logistics-saas/customer/workspace.html"]
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
    if (normalized.startsWith("/logistics-saas/public/")) {
      normalized = "/logistics-saas/" + normalized.slice("/logistics-saas/public/".length);
    } else if (normalized.startsWith("/public/")) {
      normalized = "/logistics-saas/" + normalized.slice("/public/".length);
    } else if (!normalized.startsWith("/logistics-saas/")) {
      // Keep API-style paths untouched; normalize file paths that otherwise escape the project base.
      if (/^\/(?:api|rest|rpc|functions)\//i.test(normalized)) return whole;
      if (/\.[a-z0-9]{1,8}$/i.test(normalized)) normalized = "/logistics-saas" + normalized;
      else return whole;
    }
    normalized = canonical.get(normalized) || normalized;
    const next = normalized + suffix;
    if (next !== value) changedLinks++;
    return `${attr}=${quote}${next}${quote}`;
  });

  // Fix the legacy relative shipment-list link whose duplicate file was intentionally removed.
  if ((file === "public/customer/shipment-create.html" || file === "public/shipments/shipment-create.html") &&
      /(?:href|src)=["']shipment-list\.html(?:[?#][^"']*)?["']/i.test(html)) {
    html = html.replace(/\b(href|src)=(["'])shipment-list\.html((?:[?#][^"']*)?)\2/gi,
      (_, attr, quote, suffix) => {
        changedLinks++;
        return `${attr}=${quote}/logistics-saas/customer-os/customer-services/shipment-list.html${suffix}${quote}`;
      });
  }

  if (html !== original) {
    writeFileSync(file, html, "utf8");
    changedFiles++;
  }
}
console.log(`KRIM Pages link normalization: updated ${changedLinks} links across ${changedFiles} HTML files.`);
