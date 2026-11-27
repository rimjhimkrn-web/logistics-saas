function detectKrimEnvironment() {
  const hostname = window.location.hostname.toLowerCase();
  // Staging hostname takes priority over any page-level environment setting.
  if (hostname === "krim-staging.pages.dev" || hostname.endsWith(".krim-staging.pages.dev")) {
    return "preview";
  }

  const configured = window.KRIM_ENVIRONMENT ||
    document.querySelector('meta[name="krim-environment"]')?.content;
  const supported = ["development", "preview", "production"];
  if (supported.includes(configured)) return configured;
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

// Non-production hosts must never connect to the production database. Local
// development and all preview/staging deployments use the isolated staging project.
const PRODUCTION_SUPABASE_URL = "https://ebltviniygljwwseplph.supabase.co";
const PRODUCTION_SUPABASE_PUBLISHABLE_KEY = "sb_publishable_8xzZUeubYp_nIxVRWEQdiw_2H4RkHAa";
const STAGING_SUPABASE_URL = "https://qrpcivhdxobiaofppbkl.supabase.co";
const STAGING_SUPABASE_PUBLISHABLE_KEY = "sb_publishable_WYEwWxfNmMryQCu-mLAlQg_FRmn4_O3";
const SUPABASE_URL = window.KRIM_ENVIRONMENT === "production"
  ? PRODUCTION_SUPABASE_URL
  : STAGING_SUPABASE_URL;
const SUPABASE_PUBLISHABLE_KEY = window.KRIM_ENVIRONMENT === "production"
  ? PRODUCTION_SUPABASE_PUBLISHABLE_KEY
  : STAGING_SUPABASE_PUBLISHABLE_KEY;
window.KRIM_STAGING_PREVIEW = window.KRIM_ENVIRONMENT === "preview";

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

/* Shared language bootstrap: loaded on every page that uses the canonical
   KRIM config, so the saved preference survives navigation between modules. */
(function(){
  if(window.KRIM_LANGUAGE_BOOTSTRAPPED||document.querySelector('script[data-krim-language-loader]'))return;
  var s=document.createElement('script');s.src=(window.KRIM_BASE_PATH||'')+'/assets/krim-global-language.js?v=20261127-global-language-v1';
  s.defer=true;s.dataset.krimLanguageLoader='1';document.head.appendChild(s);
})();
