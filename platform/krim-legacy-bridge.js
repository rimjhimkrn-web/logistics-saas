/* =========================================================
   KRIM FRONTEND BATCH 2
   LEGACY -> CANONICAL COMPATIBILITY BRIDGE
   ========================================================= */
(function (global) {
  "use strict";

  if (!global.KRIM_SUPABASE) {
    console.error("KRIM bridge: Supabase client is unavailable.");
    return;
  }

  const supportedEnvironments = ["development", "preview", "production"];
  const environment = supportedEnvironments.includes(global.KRIM_ENVIRONMENT)
    ? global.KRIM_ENVIRONMENT
    : "production";

  const routes = {
    auth: {
      login: "/auth/login.html",
      register: "/auth/register.html",
      resetPassword: "/forgot-password.html"
    }
  };

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
      defaultCountry: "IN",
      defaultCurrency: "INR",
      defaultTimezone: "Asia/Kolkata"
    },
    routes,
    features: {}
  };

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

  global.KRIM_FRONTEND_BRIDGE = Object.freeze({
    version: "2.0.1",
    environment,
    canonicalReady: true,
    legacyClientPreserved: true
  });
})(window);
