/* =========================================================
   KRIM FRONTEND BATCH 2
   LEGACY -> CANONICAL COMPATIBILITY BRIDGE

   Purpose:
   - Allows the existing frontend stack and the canonical
     platform facade to coexist during controlled migration.
   - Does not replace backend authorization.
   - Does not contain service-role credentials.
   ========================================================= */
(function (global) {
  "use strict";

  /*
   * The current production frontend already creates
   * window.KRIM_SUPABASE and exposes the existing environment.
   * This bridge only supplies the canonical facade with the
   * configuration/API shape it expects.
   */

  if (!global.KRIM_SUPABASE) {
    console.error("KRIM bridge: Supabase client is unavailable.");
    return;
  }

  const supportedEnvironments = ["development", "preview", "production"];
  const environment = supportedEnvironments.includes(global.KRIM_ENVIRONMENT)
    ? global.KRIM_ENVIRONMENT
    : "production";

  const defaultCountry = "IN";
  const defaultCurrency = "INR";
  const defaultTimezone = "Asia/Kolkata";

  const routes = {
    auth: {
      login: "/app/sign-in.html",
      register: "/app/register.html",
      resetPassword: "/app/reset-password.html"
    }
  };

  /*
   * Only publishable browser configuration is exposed here.
   * No service-role or privileged secret belongs in this layer.
   */
  global.KRIM_CONFIG = global.KRIM_CONFIG || {
    supabase: {
      url: global.SUPABASE_URL,
      anonKey: global.SUPABASE_PUBLISHABLE_KEY
    },
    apiBase: global.SUPABASE_URL
      ? global.SUPABASE_URL + "/functions/v1"
      : "",
    environment,
    appName: "KRIM Global Logistics",
    appVersion: "1.0.0",
    market: {
      defaultCountry,
      defaultCurrency,
      defaultTimezone
    },
    routes,
    features: {}
  };

  /*
   * Canonical API adapter.
   * Existing pages can continue using their current client while
   * new pages receive one stable KRIM API surface.
   */
  const client = global.KRIM_SUPABASE;

  function table(name) {
    if (!name || typeof name !== "string") {
      throw new Error("KRIM API: invalid table name.");
    }
    return client.from(name);
  }

  global.KRIM_API = global.KRIM_API || Object.freeze({
    select(tableName, columns, options) {
      let query = table(tableName).select(columns || "*");

      if (options && options.eq) {
        Object.entries(options.eq).forEach(([key, value]) => {
          query = query.eq(key, value);
        });
      }

      if (options && options.order) {
        query = query.order(
          options.order.column,
          { ascending: options.order.ascending !== false }
        );
      }

      if (options && Number.isInteger(options.limit)) {
        query = query.limit(options.limit);
      }

      return query;
    },

    insert(tableName, rows, options) {
      let query = table(tableName).insert(rows);
      if (options && options.select) query = query.select(options.select);
      return query;
    },

    update(tableName, values, options) {
      let query = table(tableName).update(values);

      if (options && options.eq) {
        Object.entries(options.eq).forEach(([key, value]) => {
          query = query.eq(key, value);
        });
      }

      if (options && options.select) query = query.select(options.select);
      return query;
    },

    upsert(tableName, rows, options) {
      return table(tableName).upsert(rows, options || {});
    },

    remove(tableName, options) {
      let query = table(tableName).delete();

      if (options && options.eq) {
        Object.entries(options.eq).forEach(([key, value]) => {
          query = query.eq(key, value);
        });
      }

      return query;
    },

    async invoke(functionName, body, options) {
      return client.functions.invoke(functionName, {
        body: body || {},
        ...(options || {})
      });
    },

    async count(tableName, options) {
      let query = table(tableName).select("*", {
        count: "exact",
        head: true
      });

      if (options && options.eq) {
        Object.entries(options.eq).forEach(([key, value]) => {
          query = query.eq(key, value);
        });
      }

      return query;
    }
  });

  /*
   * Keep the old client reference intact for existing pages.
   * This bridge is deliberately additive.
   */
  global.KRIM_FRONTEND_BRIDGE = Object.freeze({
    version: "2.0.0",
    environment,
    canonicalReady: true,
    legacyClientPreserved: true
  });

})(window);
