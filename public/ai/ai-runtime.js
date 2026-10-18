/**
 * KRIM AI workspace runtime.
 * Uses the existing authenticated Supabase session and the deployed krim-ai Edge Function.
 * Never fabricates output; all backend failures are shown to the user.
 */
(function () {
  "use strict";

  const MAX_INPUT_LENGTH = 2000;
  // This runtime is loaded as a module on AI workspace pages, where document.currentScript is null.
  // Find the actual script URL so nested pages resolve platform/ correctly on GitHub Pages and custom domains.
  const runtimeScript = document.currentScript || document.querySelector('script[src*="/ai/ai-runtime.js"]') || document.querySelector('script[src$="ai-runtime.js"]');
  const base = runtimeScript && runtimeScript.src ? runtimeScript.src : new URL("ai-runtime.js", location.href).href;

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
    const answer = result?.answer ?? result?.reply ?? result?.response ?? result?.message ?? result?.output ?? result?.result;
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
      // Read-only workspaces use the signed-in Supabase client; database RLS remains authoritative.
      if (page === "conversation-history") {
        const { data, error } = await client.from("ai_conversations").select("id,title,status,created_at,updated_at").order("updated_at", { ascending: false }).limit(50);
        if (error) throw error;
        renderResult(form, { records: data || [], note: "Conversation records visible to this session under database RLS." });
        setStatus(form, "Loaded " + (data || []).length + " conversation record(s).");
      } else if (page === "ai-audit-history") {
        const { data, error } = await client.from("ai_actions").select("id,action_type,status,created_at,approved_at,executed_at,error_message").order("created_at", { ascending: false }).limit(50);
        if (error) throw error;
        renderResult(form, { records: data || [], note: "Read-only audit records visible under database RLS. This page does not execute actions." });
        setStatus(form, "Loaded " + (data || []).length + " audit record(s).");
      } else if (page === "human-review-queue") {
        const { data, error } = await client.from("ai_actions").select("id,action_type,status,requested_data,created_at,approved_at,executed_at").order("created_at", { ascending: false }).limit(50);
        if (error) throw error;
        const reviewable = (data || []).filter(row => /pending|review|approval/i.test(String(row.status || "")));
        renderResult(form, { records: reviewable, note: "Read-only review candidates from actual AI action rows. Approval and execution are disabled until a server-side role-checked workflow is configured." });
        setStatus(form, "Loaded " + reviewable.length + " candidate review record(s); no action was approved or executed.");
      } else {
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
        // Persist the exchange under the authenticated user. RLS policies remain the authority;
        // if persistence is denied, show a warning instead of claiming the history was saved.
        const replyText = data.reply || data.answer || data.response || data.output_text || data.message;
        if (typeof replyText === "string" && replyText.trim()) {
          const { data: conversation, error: conversationError } = await client
            .from("ai_conversations")
            .insert({
              user_id: sessionData.session.user.id,
              user_role: "customer",
              title: (entries[0]?.[1] || page).slice(0, 160),
              status: "active"
            })
            .select("id")
            .single();
          if (conversationError) {
            setStatus(form, "AI response received, but conversation history was not saved: " + conversationError.message);
          } else {
            const { error: messageError } = await client.from("ai_messages").insert([
              { conversation_id: conversation.id, sender: "user", message: prompt },
              { conversation_id: conversation.id, sender: "assistant", message: replyText.trim() }
            ]);
            if (messageError) {
              setStatus(form, "AI response received, but message history was not fully saved: " + messageError.message);
            } else {
              setStatus(form, "AI response received and conversation saved. Recommendations are advisory; verify source data before acting.");
            }
          }
        } else {
          setStatus(form, "AI response received, but no text field was returned for conversation persistence.");
        }
      }
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
