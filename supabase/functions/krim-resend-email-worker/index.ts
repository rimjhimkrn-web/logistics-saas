import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { "content-type": "application/json", "cache-control": "no-store" }
});

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (char) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  })[char] ?? char);
}

async function matchesSecret(candidate: string, expected: string): Promise<boolean> {
  if (!expected || expected.length < 32 || candidate.length !== expected.length) return false;
  const [left, right] = await Promise.all([
    crypto.subtle.digest("SHA-256", new TextEncoder().encode(candidate)),
    crypto.subtle.digest("SHA-256", new TextEncoder().encode(expected))
  ]);
  const a = new Uint8Array(left);
  const b = new Uint8Array(right);
  let difference = 0;
  for (let i = 0; i < a.length; i++) difference |= a[i] ^ b[i];
  return difference === 0;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const cronSecret = Deno.env.get("KRIM_NOTIFICATION_CRON_SECRET") ?? "";
  const suppliedSecret = req.headers.get("x-krim-cron-secret") ?? "";
  if (!await matchesSecret(suppliedSecret, cronSecret)) {
    return json({ error: "unauthorized" }, 401);
  }

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const resendKey = Deno.env.get("RESEND_API_KEY") ?? "";
  const from = Deno.env.get("RESEND_FROM_EMAIL") ?? "";
  const appBase = Deno.env.get("KRIM_APP_BASE_URL") ?? "https://rimjhimkrn-web.github.io/logistics-saas";

  if (!url || !serviceKey || !resendKey || !from) {
    return json({ error: "server_configuration_missing" }, 503);
  }

  let appUrl: URL;
  try {
    appUrl = new URL(appBase);
    if (appUrl.protocol !== "https:" || appUrl.username || appUrl.password) {
      return json({ error: "invalid_app_base_url" }, 503);
    }
  } catch {
    return json({ error: "invalid_app_base_url" }, 503);
  }

  const db = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false }
  });

  const { data: rows, error: claimError } = await db.rpc("krim_internal_claim_resend_email_batch", {
    p_limit: 10
  });
  if (claimError) return json({ error: "queue_claim_failed" }, 503);

  let sent = 0;
  let failed = 0;
  let skipped = 0;

  for (const row of rows ?? []) {
    let success = false;
    let providerMessageId: string | null = null;
    let errorCode = "provider_error";
    let errorText = "Resend email delivery failed.";

    try {
      const userId = String(row.recipient_user_id ?? "");
      const { data: userResult, error: userError } = await db.auth.admin.getUserById(userId);
      const recipient = userResult?.user?.email ?? "";
      const confirmedAt = userResult?.user?.email_confirmed_at ?? null;

      if (userError || !recipient || !confirmedAt) {
        errorCode = "recipient_unavailable_or_unconfirmed";
        errorText = "The partner email address is unavailable or no longer confirmed.";
        skipped++;
      } else {
        const requestText = String(row.email_payload?.request ?? "");
        const subject = String(row.email_subject ?? "Action required: KRIM partner application")
          .replace(/[\r\n]+/g, " ").slice(0, 180);
        const workspacePath = String(row.email_payload?.workspace_path ?? "/app/partner/business/index.html");
        const safePath = workspacePath.startsWith("/") && !workspacePath.startsWith("//")
          ? workspacePath : "/app/partner/business/index.html";
        const workspaceUrl = new URL(safePath.replace(/^\/+/, ""), appUrl.toString().replace(/\/$/, "") + "/").toString();
        const escapedRequest = escapeHtml(requestText);
        const textBody = [
          "KRIM Logistics — Partner application update",
          "",
          "Additional information is required to review your partner application.",
          requestText,
          "",
          "Please sign in to your KRIM Partner Workspace and open Partner Onboarding:",
          workspaceUrl,
          "",
          "This is an automated transactional message. If you did not create a KRIM partner application, you can ignore it."
        ].join("\n");
        const htmlBody = `<!doctype html><html><body style="font-family:Arial,sans-serif;color:#172033;line-height:1.6">
          <h2>KRIM Logistics — Partner application update</h2>
          <p>Additional information is required to review your partner application.</p>
          <div style="padding:16px;background:#f3f5f8;border-radius:8px;white-space:pre-wrap">${escapedRequest}</div>
          <p><a href="${escapeHtml(workspaceUrl)}">Open Partner Workspace</a> and review Partner Onboarding.</p>
          <p style="font-size:12px;color:#687386">This is an automated transactional message. If you did not create a KRIM partner application, you can ignore it.</p>
        </body></html>`;

        const response = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            "authorization": `Bearer ${resendKey}`,
            "content-type": "application/json",
            "idempotency-key": String(row.idempotency_key ?? `krim-partner-verification-${row.outbox_id}`).slice(0, 256)
          },
          body: JSON.stringify({ from, to: [recipient], subject, text: textBody, html: htmlBody }),
          signal: AbortSignal.timeout(15000)
        });

        const result = await response.json().catch(() => ({}));
        success = response.ok && typeof result?.id === "string" && result.id.length > 0;
        if (success) {
          providerMessageId = result.id;
        } else {
          errorCode = response.status === 429 ? "provider_rate_limited"
            : response.status >= 500 ? "provider_temporary_error"
            : "provider_rejected_request";
          errorText = `Resend rejected the email request (HTTP ${response.status}).`;
        }
      }
    } catch {
      errorCode = "provider_network_error";
      errorText = "Resend request timed out or the provider could not be reached.";
    }

    const { data: finish, error: finishError } = await db.rpc("krim_internal_finish_resend_email", {
      p_outbox_id: row.outbox_id,
      p_delivery_id: row.delivery_id,
      p_success: success,
      p_provider_message_id: providerMessageId,
      p_error_code: success ? null : errorCode,
      p_error: success ? null : errorText
    });

    if (finishError || finish?.ok !== true) {
      failed++;
    } else if (success) {
      sent++;
    } else {
      failed++;
    }
  }

  return json({
    ok: failed === 0,
    claimed: (rows ?? []).length,
    accepted_by_provider: sent,
    failed,
    skipped,
    processed_at: new Date().toISOString()
  }, failed > 0 ? 503 : 200);
});
