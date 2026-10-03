(function (global) {
  "use strict";

  const catalog = global.KRIM_CATALOG || {};
  const marketConfig = global.KRIM_MARKETS || {};

  function currentLanguage() {
    try { return localStorage.getItem("krim-language") || "en"; } catch (error) { return "en"; }
  }

  function translate(key) {
    const language = currentLanguage();
    return (catalog[language] && catalog[language][key]) || (catalog.en && catalog.en[key]) || key;
  }

  function setLanguage(language) {
    const supported = (marketConfig.languages || []).find((item) => item.code === language);
    if (!supported) return;
    try {
      localStorage.setItem("krim-language", supported.code);
    } catch (error) {
      console.warn("Language preference could not be saved.");
    }
    document.documentElement.lang = supported.code;
    document.documentElement.dir = supported.dir;
    document.querySelectorAll("[data-i18n]").forEach((element) => {
      element.textContent = translate(element.dataset.i18n);
    });
    document.querySelectorAll("[data-language-select]").forEach((select) => {
      select.value = supported.code;
      let notice = select.parentElement.querySelector("[data-language-coverage]");
      if (!notice) {
        notice = document.createElement("small");
        notice.className = "language-coverage";
        notice.dataset.languageCoverage = "";
        select.insertAdjacentElement("afterend", notice);
      }
      notice.textContent = translate("languageCoverage");
    });
    global.dispatchEvent(new CustomEvent("krim:language-change", { detail: { language: supported.code } }));
  }

  function notify(message, type) {
    const region = document.querySelector("[data-notifications]");
    if (!region) return;
    const item = document.createElement("div");
    item.className = "notice notice--" + (type || "info");
    item.setAttribute("role", type === "error" ? "alert" : "status");
    item.textContent = message;
    region.replaceChildren(item);
  }

  function reportError(category) {
    global.dispatchEvent(new CustomEvent("krim:error", {
      detail: { category, timestamp: new Date().toISOString() }
    }));
  }

  let client = global.supabaseClient || null;
  try {
    if (!client && typeof supabaseClient !== "undefined") client = supabaseClient;
  } catch (error) {
    client = null;
  }

  global.KRIM = Object.freeze({
    config: Object.freeze({ markets: marketConfig }),
    i18n: Object.freeze({ translate, setLanguage }),
    market: Object.freeze({
      active: "IN",
      serviceAvailability: "confirm-per-request",
      formatCurrency(amount, currency) {
        try {
          return new Intl.NumberFormat(document.documentElement.lang || "en", {
            style: "currency",
            currency: currency || "INR",
            maximumFractionDigits: 2
          }).format(amount);
        } catch (error) {
          return String(amount) + " " + (currency || "INR");
        }
      },
      formatDate(value, timeZone) {
        try {
          return new Intl.DateTimeFormat(document.documentElement.lang || "en", {
            dateStyle: "medium",
            timeZone: timeZone || "Asia/Kolkata"
          }).format(new Date(value));
        } catch (error) {
          return "";
        }
      }
    }),
    organization: Object.freeze({ current: null }),
    permissions: Object.freeze({
      authority: "backend",
      can: () => null
    }),
    features: Object.freeze({
      enabled: () => false
    }),
    notifications: Object.freeze({ notify }),
    auth: Object.freeze({
      async session() {
        if (!client) return { data: { session: null }, error: new Error("Authentication is unavailable.") };
        try {
          const result = await client.auth.getSession();
          if (result.error) reportError("authentication");
          return result;
        } catch (error) {
          reportError("authentication");
          return { data: { session: null }, error };
        }
      },
      async signIn(credentials) {
        if (!client) return { error: new Error("Authentication is unavailable.") };
        try {
          const result = await client.auth.signInWithPassword(credentials);
          if (result.error) reportError("authentication");
          return result;
        } catch (error) {
          reportError("authentication");
          throw error;
        }
      },
      async signUp(credentials) {
        if (!client) return { error: new Error("Authentication is unavailable.") };
        try {
          const result = await client.auth.signUp({
            email: credentials.email,
            password: credentials.password,
            options: {
              emailRedirectTo: new URL("/app/sign-in.html", global.location.origin).href
            }
          });
          if (result.error) reportError("authentication");
          return result;
        } catch (error) {
          reportError("authentication");
          throw error;
        }
      },
      async requestPasswordReset(email) {
        if (!client) return { error: new Error("Authentication is unavailable.") };
        try {
          const result = await client.auth.resetPasswordForEmail(email, {
            redirectTo: new URL("/app/reset-password.html", global.location.origin).href
          });
          if (result.error) reportError("authentication");
          return result;
        } catch (error) {
          reportError("authentication");
          throw error;
        }
      },
      async updatePassword(password) {
        if (!client) return { error: new Error("Authentication is unavailable.") };
        try {
          const result = await client.auth.updateUser({ password });
          if (result.error) reportError("authentication");
          return result;
        } catch (error) {
          reportError("authentication");
          throw error;
        }
      },
      async signOut() {
        if (!client) return { error: new Error("Authentication is unavailable.") };
        try {
          const result = await client.auth.signOut();
          if (result.error) reportError("authentication");
          return result;
        } catch (error) {
          reportError("authentication");
          throw error;
        }
      },
      onStateChange(handler) {
        if (!client) return () => {};
        const { data } = client.auth.onAuthStateChange(handler);
        return () => data.subscription.unsubscribe();
      }
    }),
    api: Object.freeze({
      async createShipmentRequest(values) {
        if (!client) throw new Error("Shipment requests are temporarily unavailable.");
        const limits = { pickup_location: 160, delivery_location: 160, material_goods: 160, weight: 80, truck_type: 100, customer_name: 120, phone_number: 32 };
        const payload = Object.fromEntries(Object.entries(limits).map(([key, limit]) => [key, String(values[key] || "").trim().slice(0, limit)]));
        if (Object.values(payload).some((value) => !value)) throw new Error("Shipment request fields are incomplete.");
        let result;
        try {
          result = await client.from("shipment_requests").insert([payload]);
        } catch (error) {
          reportError("request");
          throw error;
        }
        if (result.error) {
          reportError("request");
          throw result.error;
        }
        return result;
      },
      async listShipmentRequests() {
        if (!client) throw new Error("Shipment data is temporarily unavailable.");
        let result;
        try {
          result = await client
            .from("shipment_requests")
            .select("id, pickup_location, delivery_location, material_goods, weight, truck_type, status, created_at")
            .order("created_at", { ascending: false });
        } catch (error) {
          reportError("data-access");
          throw error;
        }
        if (result.error) {
          reportError("data-access");
          throw result.error;
        }
        return result.data || [];
      }
    })
  });

  global.addEventListener("error", (event) => {
    reportError("script");
    console.error("Frontend script error occurred.");
  });
  global.addEventListener("unhandledrejection", () => {
    reportError("request");
    console.error("Unhandled frontend request failure.");
  });
  if (global.PerformanceObserver) {
    try {
      new PerformanceObserver((entries) => {
        entries.getEntries().forEach((entry) => {
          global.dispatchEvent(new CustomEvent("krim:performance", { detail: { type: entry.entryType, duration: entry.duration } }));
        });
      }).observe({ type: "longtask", buffered: true });
    } catch (error) {
      console.info("Long-task performance metrics are unavailable.");
    }
  }

  document.addEventListener("change", (event) => {
    if (event.target.matches("[data-language-select]")) setLanguage(event.target.value);
  });

  setLanguage(currentLanguage());
})(window);