(function () {
  "use strict";

  const parts = location.pathname.split("/").filter(Boolean);
  const base = location.hostname.endsWith("github.io")
    ? "/" + (parts[0] || "logistics-saas")
    : "";
  const gate = base + "/auth/login.html?workspace=platform_admin&reason=required";

  function deny() {
    location.replace(gate);
  }

  function loadScript(src) {
    return new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = src;
      script.onload = resolve;
      script.onerror = () => reject(new Error("Could not load " + src));
      document.head.appendChild(script);
    });
  }

  (async function () {
    try {
      // Load environment selection before the Supabase SDK or any auth request.
      if (!window.KRIM_CONFIG) {
        await loadScript(base + "/platform/krim-config.js");
      }
      const config = window.KRIM_CONFIG && window.KRIM_CONFIG.supabase;
      if (!config || !config.url || !config.publishableKey) {
        throw new Error("Environment-specific Supabase configuration is missing");
      }

      if (!window.supabase) {
        await loadScript("https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2");
      }
      if (!window.supabase) throw new Error("Auth SDK unavailable");

      const client = window.supabase.createClient(config.url, config.publishableKey);
      const { data, error } = await client.auth.getSession();
      if (error || !data || !data.session) {
        deny();
        return;
      }

      const { data: result, error: invokeError } =
        await client.functions.invoke("global-admin-control", {
          body: { action: "overview" }
        });
      if (invokeError || !result || result.ok !== true) {
        deny();
        return;
      }

      document.documentElement.classList.add("krim-admin-authorized");
    } catch (_) {
      deny();
    }
  })();
})();
