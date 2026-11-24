import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { "content-type": "application/json", "cache-control": "no-store" }
});

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const authorization = req.headers.get("Authorization") ?? "";
  const cronHeader = req.headers.get("x-krim-cron-secret") ?? "";
  const bearerToken = authorization.startsWith("Bearer ") ? authorization.slice(7) : "";
  const cronSecret = Deno.env.get("KRIM_NOTIFICATION_CRON_SECRET") ?? "";

  async function matchesCronSecret(candidate: string): Promise<boolean> {
    if (!cronSecret || cronSecret.length < 32 || candidate.length !== cronSecret.length) return false;
    const [candidateDigest, expectedDigest] = await Promise.all([
      crypto.subtle.digest("SHA-256", new TextEncoder().encode(candidate)),
      crypto.subtle.digest("SHA-256", new TextEncoder().encode(cronSecret))
    ]);
    const a = new Uint8Array(candidateDigest);
    const b = new Uint8Array(expectedDigest);
    let diff = 0;
    for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
    return diff === 0;
  }

  const cronAuthorized =
    await matchesCronSecret(cronHeader) ||
    await matchesCronSecret(bearerToken);

  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const token = Deno.env.get("TELEGRAM_BOT_TOKEN");
  const chatId = Deno.env.get("TELEGRAM_CHAT_ID");
  if (!url || !anon || !service || !token || !chatId || !cronSecret) return json({ error: "server_configuration_missing" }, 503);

  if (!cronAuthorized) {
    if (!authorization.startsWith("Bearer ")) return json({ error: "authentication_required" }, 401);
    const authClient = createClient(url, anon, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false }
    });
    const { data: userData, error: userError } = await authClient.auth.getUser();
    if (userError || !userData.user) return json({ error: "invalid_session" }, 401);

    const { data: allowed, error: permissionError } = await authClient.rpc("krim_has_permission", {
      p_user_id: userData.user.id, p_organization_id: 1, p_permission_code: "admin.platform"
    });
    if (permissionError) return json({ error: "permission_check_unavailable" }, 503);
    if (allowed !== true) return json({ error: "platform_admin_required" }, 403);
  }

  const db = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });

  async function processQueue(claimRpc: string, finishRpc: string) {
    const { data: rows, error: claimError } = await db.rpc(claimRpc, { p_limit: 10 });
    if (claimError) return { claimed: 0, sent: 0, failed: 0, error: claimRpc };
    let sent = 0;
    let failed = 0;
    for (const row of (rows ?? [])) {
      let success = false;
      let messageId: string | null = null;
      let errorText = "Telegram delivery failed.";
      try {
        const response = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ chat_id: chatId, text: row.notification_message, disable_web_page_preview: true }),
          signal: AbortSignal.timeout(12000)
        });
        const result = await response.json().catch(() => ({}));
        success = response.ok && result?.ok === true;
        if (success) messageId = String(result?.result?.message_id ?? "");
        else errorText = "Telegram provider rejected retry (HTTP " + response.status + ").";
      } catch {
        errorText = "Telegram network timeout or connection failure.";
      }
      const { data: finish, error: finishError } = await db.rpc(finishRpc, {
        p_outbox_id: row.outbox_id,
        p_success: success,
        p_provider_message_id: messageId,
        p_error: success ? null : errorText
      });
      if (finishError || finish?.ok !== true) failed++;
      else if (success) sent++;
      else failed++;
    }
    return { claimed: (rows ?? []).length, sent, failed, error: null };
  }

  const enquiries = await processQueue(
    "krim_internal_claim_founder_telegram_retries",
    "krim_internal_finish_founder_telegram_retry"
  );
  const followups = await processQueue(
    "krim_internal_claim_founder_followup_telegram_retries",
    "krim_internal_finish_founder_followup_telegram_retry"
  );

  return json({
    ok: enquiries.error === null && followups.error === null,
    enquiries,
    followups,
    processed_at: new Date().toISOString()
  }, enquiries.error || followups.error ? 503 : 200);
});