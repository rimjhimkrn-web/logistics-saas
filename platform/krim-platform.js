/* =========================================================
   KRIM CANONICAL FRONTEND PLATFORM FACADE
   Single browser-side integration surface for the KRIM UI.
   Backend authorization remains authoritative.
   ========================================================= */
(function (global) {
  "use strict";

  const config = global.KRIM_CONFIG;
  if (!config) {
    console.error("KRIM: Canonical configuration is unavailable.");
    return;
  }

  const markets = global.KRIM_MARKETS || {};
  const catalog = global.KRIM_CATALOG || {};

  function currentLanguage() {
    let saved = null;
    try {
      saved = localStorage.getItem("krim-language") || localStorage.getItem("krim_locale");
    } catch (_) {}
    const normalized = saved === "zh-CN" ? "zh" : saved;
    return (markets.languages || []).some(item => item.code === normalized) ? normalized : "en";
  }

  function translate(key) {
    const language = currentLanguage();
    return (catalog[language] && catalog[language][key]) ||
      (catalog.en && catalog.en[key]) || key;
  }

  function setLanguage(language) {
    const code = language === "zh-CN" ? "zh" : String(language || "en");
    const supported = (markets.languages || []).find(item => item.code === code);
    if (!supported) return;

    try {
      localStorage.setItem("krim-language", supported.code);
      localStorage.setItem("krim_locale", supported.code);
    } catch (_) {}

    document.documentElement.lang = supported.code;
    document.documentElement.dir = supported.dir || "ltr";

    document.querySelectorAll("[data-i18n]").forEach(element => {
      element.textContent = translate(element.dataset.i18n);
    });

    document.querySelectorAll("[data-language-select]").forEach(select => {
      select.value = supported.code;
    });

    global.dispatchEvent(new CustomEvent("krim:localechange", {
      detail: { language: supported.code }
    }));
    global.dispatchEvent(new CustomEvent("krim:language-change", {
      detail: { language: supported.code }
    }));
  }

  function notify(message, type) {
    const region = document.querySelector("[data-notifications]");
    if (!region) return;

    const item = document.createElement("div");
    item.className = "notice notice--" + (type || "info");
    item.setAttribute("role", type === "error" ? "alert" : "status");
    item.textContent = String(message || "");
    region.replaceChildren(item);
  }

  const pwaState = { deferred: null };

  const pwa = {
    isInstalled() {
      return Boolean(
        (global.matchMedia &&
          global.matchMedia("(display-mode: standalone)").matches) ||
        global.navigator.standalone === true
      );
    },

    canPromptInstall() {
      return pwaState.deferred !== null;
    },

    async promptInstall() {
      if (!pwaState.deferred) return null;

      const prompt = pwaState.deferred;
      pwaState.deferred = null;

      await prompt.prompt();
      return prompt.userChoice;
    }
  };

  global.addEventListener("beforeinstallprompt", event => {
    event.preventDefault();
    pwaState.deferred = event;
  });

  global.addEventListener("appinstalled", () => {
    pwaState.deferred = null;
  });

  const clientReady = () => Boolean(global.KRIM_SUPABASE);

  const auth = {
    async session() {
      if (global.KRIM_AUTH) {
        return {
          data: {
            session: await global.KRIM_AUTH.getSession()
          },
          error: null
        };
      }

      if (!clientReady()) {
        return {
          data: { session: null },
          error: new Error("Authentication is unavailable.")
        };
      }

      return global.KRIM_SUPABASE.auth.getSession();
    },

    async signIn(credentials) {
      if (global.KRIM_AUTH) {
        return global.KRIM_AUTH.signIn(
          credentials.email,
          credentials.password
        );
      }

      return global.KRIM_SUPABASE.auth.signInWithPassword(credentials);
    },

    async signUp(credentials) {
      if (!clientReady()) {
        return {
          data: null,
          error: new Error("Authentication is unavailable.")
        };
      }

      return global.KRIM_SUPABASE.auth.signUp({
        email: credentials.email,
        password: credentials.password,
        options: {
          emailRedirectTo:
            new URL(
              config.routes.auth.login,
              global.location.origin
            ).href
        }
      });
    },

    async requestPasswordReset(email) {
      if (global.KRIM_AUTH) {
        return global.KRIM_AUTH.resetPassword(
          email,
          new URL(
            config.routes.auth.resetPassword,
            global.location.origin
          ).href
        );
      }

      return global.KRIM_SUPABASE.auth.resetPasswordForEmail(
        email,
        {
          redirectTo:
            new URL(
              config.routes.auth.resetPassword,
              global.location.origin
            ).href
        }
      );
    },

    async updatePassword(password) {
      if (global.KRIM_AUTH) {
        return global.KRIM_AUTH.updatePassword(password);
      }

      return global.KRIM_SUPABASE.auth.updateUser({ password });
    },

    async signOut() {
      if (global.KRIM_AUTH) {
        return global.KRIM_AUTH.signOut();
      }

      return global.KRIM_SUPABASE.auth.signOut();
    },

    onStateChange(handler) {
      if (!clientReady()) return () => {};

      const { data } =
        global.KRIM_SUPABASE.auth.onAuthStateChange(handler);

      return () => data.subscription.unsubscribe();
    }
  };

  async function createShipmentRequest(values) {
    if (!global.KRIM_API) {
      throw new Error("KRIM API is unavailable.");
    }

    const limits = {
      pickup_location: 160,
      delivery_location: 160,
      material_goods: 160,
      weight: 80,
      truck_type: 100,
      customer_name: 120,
      phone_number: 32
    };

    const payload = {};

    for (const [key, limit] of Object.entries(limits)) {
      payload[key] =
        String(values[key] || "")
          .trim()
          .slice(0, limit);

      if (!payload[key]) {
        throw new Error(
          "Shipment request fields are incomplete."
        );
      }
    }

    return global.KRIM_API.insert(
      "shipment_requests",
      [payload]
    );
  }

  const api = Object.freeze({
    createShipmentRequest,

    select: (...args) =>
      global.KRIM_API.select(...args),

    insert: (...args) =>
      global.KRIM_API.insert(...args),

    update: (...args) =>
      global.KRIM_API.update(...args),

    upsert: (...args) =>
      global.KRIM_API.upsert(...args),

    remove: (...args) =>
      global.KRIM_API.remove(...args),

    delete: (...args) =>
      global.KRIM_API.remove(...args),

    invoke: (...args) =>
      global.KRIM_API.invoke(...args),

    count: (...args) =>
      global.KRIM_API.count(...args)
  });

  const errors = {
    report(category) {
      global.dispatchEvent(
        new CustomEvent("krim:error", {
          detail: {
            category,
            timestamp: new Date().toISOString()
          }
        })
      );
    }
  };

  const analytics = {
    track(name) {
      if (!name) return;

      global.dispatchEvent(
        new CustomEvent("krim:event", {
          detail: {
            name: String(name).slice(0, 64),
            timestamp: new Date().toISOString()
          }
        })
      );
    }
  };

  global.KRIM = Object.freeze({
    config,

    i18n: Object.freeze({
      translate,
      setLanguage
    }),

    market: Object.freeze({
      active:
        markets.defaultMarket ||
        config.market.defaultCountry,

      timezone:
        config.market.defaultTimezone,

      serviceAvailability:
        "confirm-per-request",

      formatCurrency(amount, currency) {
        return new Intl.NumberFormat(
          document.documentElement.lang || "en",
          {
            style: "currency",
            currency:
              currency ||
              config.market.defaultCurrency,
            maximumFractionDigits: 2
          }
        ).format(amount);
      },

      formatNumber(value, options) {
        return new Intl.NumberFormat(
          document.documentElement.lang || "en",
          options
        ).format(value);
      },

      formatDate(value, timeZone) {
        return new Intl.DateTimeFormat(
          document.documentElement.lang || "en",
          {
            dateStyle: "medium",
            timeZone:
              timeZone ||
              config.market.defaultTimezone
          }
        ).format(new Date(value));
      },

      formatTime(value, timeZone) {
        return new Intl.DateTimeFormat(
          document.documentElement.lang || "en",
          {
            timeStyle: "short",
            timeZone:
              timeZone ||
              config.market.defaultTimezone
          }
        ).format(new Date(value));
      }
    }),

    organization:
      Object.freeze({ current: null }),

    permissions:
      Object.freeze({
        authority: "backend",
        can: () => null
      }),

    features:
      Object.freeze({
        enabled: () => false
      }),

    analytics:
      Object.freeze(analytics),

    errors:
      Object.freeze(errors),

    notifications:
      Object.freeze({ notify }),

    pwa:
      Object.freeze(pwa),

    auth:
      Object.freeze(auth),

    api
  });

  document.addEventListener("change", event => {
    if (
      event.target.matches(
        "[data-language-select]"
      )
    ) {
      setLanguage(event.target.value);
    }
  });

  setLanguage(currentLanguage());

})(window);
