/**
 * KRIM AI workspace runtime.
 * Uses the existing authenticated Supabase session and the deployed krim-ai Edge Function.
 * Never fabricates output; all backend failures are shown to the user.
 */
(function () {
  "use strict";

  const MAX_INPUT_LENGTH = 2000;
  const runtimeScript = document.currentScript;
  const base = runtimeScript ? runtimeScript.src : new URL("ai-runtime.js", location.href).href;

  function loadScript(src) {
    return new Promise((resolve, reject) => {
      const existing = [...document.scripts].find(s => s.src === src);
      if (existing) {
        if (existing.dataset.krimLoaded === "true") return resolve();
        existing.addEventListener("load", resolve, { once: true });
        existing.addEventListener("error", reject, { once: true });
        return;
      }
      const script = document.createElement("script");
      script.src = src;
      script.async = true;
      script.onload = () => { script.dataset.krimLoaded = "true"; resolve(); };
      script.onerror = () => reject(new Error("Could not load required platform script."));
      document.head.appendChild(script);
    });
  }

  async function getClient() {
    const configUrl = new URL("../../platform/krim-config.js", base).href;
    await loadScript(configUrl);
    if (!window.supabase || typeof window.supabase.createClient !== "function") {
      await loadScript("https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2");
    }
    const config = window.KRIM_CONFIG && window.KRIM_CONFIG.supabase;
    if (!config || !config.url || !config.publishableKey) {
      throw new Error("KRIM Supabase configuration is missing.");
    }
    if (!window.__KRIM_AI_SUPABASE__) {
      window.__KRIM_AI_SUPABASE__ = window.supabase.createClient(
        config.url, config.publishableKey,
        { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } }
      );
    }
    return window.__KRIM_AI_SUPABASE__;
  }

  function setStatus(form, message) {
    const scope = form.closest(".panel, .ai-card, section") || form.parentElement;
    const status = scope.querySelector("[data-krim-ai-status]") ||
      document.querySelector("[data-krim-ai-status]");
    if (status) status.textContent = message;
  }

  function renderResult(form, result) {
    const scope = form.closest(".panel, .ai-card, section") || form.parentElement;
    let output = scope.querySelector("[data-krim-ai-result]");
    if (!output) {
      output = document.createElement("pre");
      output.dataset.krimAiResult = "";
      output.setAttribute("role", "region");
      output.setAttribute("aria-label", "KRIM AI response");
      output.style.cssText = "white-space:pre-wrap;overflow-wrap:anywhere;padding:12px;border:1px solid #d7deea;border-radius:8px;background:#f8fafc;color:#172033;font:inherit;";
      (scope.querySelector("[data-krim-ai-status]") || form).insertAdjacentElement("afterend", output);
    }
    const answer = result?.answer ?? result?.response ?? result?.message ?? result?.output ?? result?.result;
    output.textContent = typeof answer === "string" ? answer : JSON.stringify(result, null, 2);
  }

  async function submit(form) {
    const entries = [...new FormData(form).entries()]
      .map(([key, value]) => [key, String(value).trim()]);
    if (!entries.length || entries.some(([, value]) => !value || value.length > MAX_INPUT_LENGTH)) {
      setStatus(form, "Enter valid values for all fields (maximum 2,000 characters per field).");
      return;
    }
    const page = form.dataset.page || location.pathname.split("/").pop().replace(".html", "");
    const prompt = "KRIM Logistics AI workspace: " + page +
      "\nProvide decision support only. Do not claim to execute actions, change shipment records, approve payments, or guarantee forecasts. Clearly state assumptions and uncertainty.\nRequest data:\n" +
      entries.map(([key, value]) => key + ": " + value).join("\n");
    if (prompt.length > 12000) {
      setStatus(form, "Request is too long. Please shorten the input.");
      return;
    }

    const buttons = [...form.querySelectorAll('button[type="submit"], input[type="submit"]')];
    buttons.forEach(button => { button.disabled = true; });
    setStatus(form, "Connecting to KRIM AI securely…");
    try {
      const client = await getClient();
      const { data: sessionData, error: sessionError } = await client.auth.getSession();
      if (sessionError) throw sessionError;
      if (!sessionData?.session?.access_token) {
        setStatus(form, "Sign in to KRIM before using AI. No request was sent.");
        return;
      }
      const { data, error } = await client.functions.invoke("krim-ai", {
        body: { message: prompt, page, fields: entries.map(([key]) => key) }
      });
      if (error) {
        let detail = error.message || "The AI service returned an error.";
        try {
          if (error.context && typeof error.context.json === "function") {
            const body = await error.context.json();
            detail = body.error || body.message || detail;
          }
        } catch (_) {}
        throw new Error(detail);
      }
      if (!data || data.error) throw new Error(data?.error || "The AI service returned no usable response.");
      renderResult(form, data);
      setStatus(form, "Response received from KRIM AI. Review all recommendations before acting.");
      form.dispatchEvent(new CustomEvent("krim:ai-response", {
        bubbles: true, detail: { page, received: true }
      }));
    } catch (error) {
      console.error("KRIM AI request failed:", error);
      setStatus(form, "KRIM AI request failed: " + (error?.message || "Unknown error") +
        ". Check your sign-in, network, Edge Function configuration, and OpenAI secret.");
    } finally {
      buttons.forEach(button => { button.disabled = false; });
    }
  }

  document.addEventListener("DOMContentLoaded", () => {
    document.querySelectorAll("[data-krim-ai-form]").forEach(form => {
      if (form.dataset.krimAiBound === "true") return;
      form.dataset.krimAiBound = "true";
      form.addEventListener("submit", event => {
        event.preventDefault();
        submit(form);
      });
    });
  });
})();
