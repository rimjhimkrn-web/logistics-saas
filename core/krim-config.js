/* ==========================================================================
   KRIM LOGISTICS OS — GLOBAL CONFIGURATION & ROUTE REGISTRY
   ========================================================================== */

const KRIM_CONFIG = {
  ENV: "production",
  VERSION: "2026.4.0",
  SYSTEM_CLOCK_YEAR: 2026,
  
  // Backend Integration Endpoint
  SUPABASE_URL: "https://your-supabase-instance.supabase.co", 
  SUPABASE_ANON_KEY: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",

  // Roles & Access Levels
  ROLES: {
    CUSTOMER: "customer",
    PARTNER: "partner",
    ENTERPRISE: "enterprise",
    DRIVER: "driver",
    WAREHOUSE: "warehouse",
    FREIGHT: "freight_forwarder",
    OPERATIONS: "operations",
    FINANCE: "finance",
    COMPLIANCE: "compliance",
    SUPPORT: "support",
    DEVELOPER: "developer",
    SUPER_ADMIN: "super_admin"
  },

  // Portal Route Map
  ROUTES: {
    customer: "/customer/workspace.html",
    partner: "/partner/workspace.html",
    enterprise: "/enterprise/portal.html",
    driver: "/driver/app.html",
    warehouse: "/warehouse/workspace.html",
    freight_forwarder: "/freight/workspace.html",
    operations: "/operations/workspace.html",
    finance: "/finance/workspace.html",
    compliance: "/compliance/workspace.html",
    support: "/support/workspace.html",
    developer: "/docs/developer.html",
    super_admin: "/control/global-control-centre/index.html",
    login: "/auth/login.html"
  },

  // Supported Locales & Currencies
  LOCALIZATION: {
    DEFAULT_LOCALE: "en-US",
    DEFAULT_CURRENCY: "USD",
    SUPPORTED_CURRENCIES: ["USD", "EUR", "GBP", "INR", "SGD", "AED", "JPY"],
    SUPPORTED_LANGUAGES: [
      { code: "en", name: "English", dir: "ltr" },
      { code: "ar", name: "العربية", dir: "rtl" },
      { code: "es", name: "Español", dir: "ltr" },
      { code: "fr", name: "Français", dir: "ltr" },
      { code: "de", name: "Deutsch", dir: "ltr" },
      { code: "zh", name: "中文", dir: "ltr" },
      { code: "hi", name: "हिन्दी", dir: "ltr" }
    ]
  }
};

Object.freeze(KRIM_CONFIG);
