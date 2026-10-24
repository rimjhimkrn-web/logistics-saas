const SUPABASE_URL = "https://ebltviniygljwwseplph.supabase.co";

const SUPABASE_PUBLISHABLE_KEY =
  "sb_publishable_8xzZUeubYp_nIxVRWEQdiw_2H4RkHAa";

function detectKrimEnvironment() {
  const configured = window.KRIM_ENVIRONMENT ||
    document.querySelector('meta[name="krim-environment"]')?.content;
  const supported = ["development", "preview", "production"];

  if (supported.includes(configured)) return configured;

  const hostname = window.location.hostname.toLowerCase();
  if (hostname === "localhost" || hostname === "127.0.0.1" || hostname === "::1") {
    return "development";
  }
  if (
    hostname.includes(".preview.") ||
    /^pr-\d+--.+\.netlify\.app$/.test(hostname) ||
    /-git-[^.]+\.vercel\.app$/.test(hostname)
  ) {
    return "preview";
  }
  return "production";
}

window.KRIM_ENVIRONMENT = detectKrimEnvironment();

const krimBasePath =
  window.location.hostname.endsWith("github.io") &&
  window.location.pathname.startsWith("/logistics-saas")
    ? "/logistics-saas"
    : "";

window.KRIM_BASE_PATH = krimBasePath;
window.krimPath = function (path = "") {
  const cleanPath = String(path).replace(/^\/+/, "");
  return cleanPath ? `${krimBasePath}/${cleanPath}` : `${krimBasePath}/`;
};


const krimSupabaseClient =
  window.KRIM_SUPABASE ||
  window.supabaseClient ||
  window.supabase.createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);

window.KRIM_SUPABASE = krimSupabaseClient;
window.supabaseClient = krimSupabaseClient;
/*
 * Canonical KRIM route registry.
 * Keep one approved destination for each core workflow; legacy pages should
 * redirect here rather than creating parallel implementations.
 */
window.KRIM_ROUTES = Object.freeze({
  home: "index.html",
  access: "auth/access.html",
  login: "auth/login.html",
  customer: "app/customer/index.html",
  partner: "app/partner/index.html",
  driver: "app/driver/index.html",
  warehouse: "app/warehouse/index.html",
  customs: "app/customs/index.html",
  finance: "app/finance/index.html",
  operations: "app/operations/index.html",
  enterprise: "app/enterprise/index.html",
  platformAdmin: "app/platform-admin/index.html",
  customerBooking: "public/shipper/booking-request.html",
  customerQuoteRequest: "public/customer/quote-request.html",
  quoteResult: "public/quote-result.html",
  customerShipments: "public/customer-os/customer-services/shipment-list.html",
  tracking: "public/tracking.html",
  partnerOnboarding: "public/partner/partner-onboarding.html",
  partnerMarketplace: "public/partner/load-marketplace.html",
  driverAssignments: "app/driver/module-01-assignment-inbox.html",
  warehouseInbound: "public/warehouse/inbound-receiving.html",
  warehouseInventory: "public/warehouse/inventory-ledger.html",
  customsQueue: "app/customs/index.html",
  financeInvoices: "app/finance/invoicing.html",
  operationsControl: "app/operations/index.html",
  enterpriseShipments: "app/enterprise/shipments.html",
  support: "public/support/help-centre.html"
});

window.krimRoute = function (routeName, query = {}) {
  const route = window.KRIM_ROUTES[routeName];
  if (!route) throw new Error("Unknown KRIM route: " + routeName);
  const url = new URL(window.krimPath(route), window.location.origin);
  Object.entries(query || {}).forEach(([key, value]) => {
    if (value !== undefined && value !== null && String(value) !== "") {
      url.searchParams.set(key, String(value));
    }
  });
  return url.href;
};
