function detectKrimEnvironment() {
  const hostname = String(window.location.hostname || "").toLowerCase();

  // Explicit host allowlist. Never infer production from an unknown hostname.
  if (
    hostname === "krim-staging.pages.dev" ||
    hostname.endsWith(".krim-staging.pages.dev")
  ) return "preview";

  if (
    hostname === "localhost" ||
    hostname === "127.0.0.1" ||
    hostname === "::1"
  ) return "development";

  // GitHub Pages is the currently verified public production hostname.
  if (hostname === "rimjhimkrn-web.github.io") return "production";

  throw new Error(
    "KRIM environment blocked: this hostname is not allowlisted. No Supabase client was initialized."
  );
}

window.KRIM_ENVIRONMENT = detectKrimEnvironment();

// Browser configuration contains publishable keys only; never put service-role or secret keys here.
const KRIM_SUPABASE_ENVIRONMENTS = Object.freeze({
  production: Object.freeze({
    projectRef: "ebltviniygljwwseplph",
    url: "https://ebltviniygljwwseplph.supabase.co",
    publishableKey: "sb_publishable_8xzZUeubYp_nIxVRWEQdiw_2H4RkHAa"
  }),
  preview: Object.freeze({
    projectRef: "qrpcivhdxobiaofppbkl",
    url: "https://qrpcivhdxobiaofppbkl.supabase.co",
    publishableKey: "sb_publishable_WYEwWxfNmMryQCu-mLAlQg_FRmn4_O3"
  }),
  development: Object.freeze({
    projectRef: "qrpcivhdxobiaofppbkl",
    url: "https://qrpcivhdxobiaofppbkl.supabase.co",
    publishableKey: "sb_publishable_WYEwWxfNmMryQCu-mLAlQg_FRmn4_O3"
  })
});

const selectedSupabaseConfig = KRIM_SUPABASE_ENVIRONMENTS[window.KRIM_ENVIRONMENT];
if (!selectedSupabaseConfig) {
  throw new Error("KRIM environment has no approved Supabase project mapping.");
}
window.KRIM_SUPABASE_CONFIG = Object.freeze({ ...selectedSupabaseConfig });
window.KRIM_SUPABASE_PROJECT_REF = selectedSupabaseConfig.projectRef;
window.KRIM_STAGING_PREVIEW = window.KRIM_ENVIRONMENT === "preview";
// Preview review mode is UI behavior only, never an authorization boundary.
window.KRIM_AUTH_DISABLED = window.KRIM_STAGING_PREVIEW;

if (!window.supabase || typeof window.supabase.createClient !== "function") {
  throw new Error("KRIM Supabase SDK is unavailable; client initialization stopped.");
}

// Always create the client from the hostname-verified mapping. Do not trust
// a pre-existing global client whose project identity cannot be proven.
const krimSupabaseClient = window.supabase.createClient(
  selectedSupabaseConfig.url,
  selectedSupabaseConfig.publishableKey,
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
      flowType: "pkce"
    }
  }
);

window.KRIM_SUPABASE = krimSupabaseClient;
window.supabaseClient = krimSupabaseClient;

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
