import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type RequestBody = { channel?: string; provider?: string; action?: string };

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store" },
  });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) return json({ error: "authentication_required" }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !supabaseAnonKey) return json({ error: "server_auth_configuration_missing" }, 503);

  let body: RequestBody;
  try { body = await req.json(); } catch { return json({ error: "invalid_json" }, 400); }

  const channel = (body.channel ?? "").trim().toLowerCase();
  const provider = (body.provider ?? "").trim().toLowerCase();

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) return json({ error: "invalid_session" }, 401);

  const { data: isPlatformAdmin, error: permissionError } = await supabase.rpc("krim_has_permission", {
    p_user_id: userData.user.id,
    p_organization_id: 1,
    p_permission_code: "admin.platform",
  });
  if (permissionError) return json({ error: "permission_check_unavailable" }, 503);
  if (isPlatformAdmin !== true) return json({ error: "platform_admin_required" }, 403);

  if (channel === "email" && provider === "resend") {
    const configured = Boolean(Deno.env.get("RESEND_API_KEY"));
    return json({
      ok: configured,
      status: configured ? "credential_available" : "provider_credential_not_configured",
      channel: "email", provider: "resend", adapter_ready: configured, sending_enabled: false,
    }, configured ? 200 : 409);
  }

  if (channel === "telegram" && provider === "telegram" && body.action === "test") {
    const token = Deno.env.get("TELEGRAM_BOT_TOKEN");
    const chatId = Deno.env.get("TELEGRAM_CHAT_ID");
    if (!token || !chatId) return json({ error: "telegram_credentials_not_configured" }, 409);

    const message = "KRIM Logistics: Telegram notification connection test successful. This is a founder-authorized system test; no customer or partner message was sent.";
    let telegramResponse: Response;
    try {
      telegramResponse = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ chat_id: chatId, text: message, disable_web_page_preview: true }),
      });
    } catch {
      return json({ error: "telegram_provider_unreachable" }, 502);
    }

    const result = await telegramResponse.json().catch(() => ({}));
    if (!telegramResponse.ok || result?.ok !== true) {
      return json({ error: "telegram_delivery_failed", provider_status: telegramResponse.status }, 502);
    }
    return json({ ok: true, status: "test_message_sent", channel: "telegram", provider: "telegram" });
  }

  return json({ error: "unsupported_provider_route" }, 400);
});
