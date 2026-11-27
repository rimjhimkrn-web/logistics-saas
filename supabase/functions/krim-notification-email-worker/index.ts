import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { "content-type": "application/json", "cache-control": "no-store" }
});

function escapeHtml(value: string): string {
  return value.replace(/[&<>\"']/g, (char) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;"
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
  if (!await matchesSecret(suppliedSecret, cronSecret)) return json({ error: "unauthorized" }, 401);

  // Deliberately disabled until provider credentials, sender domain and approval are configured.
  if (Deno.env.get("KRIM_NOTIFICATION_EMAIL_SENDING_ENABLED") !== "true") {
    return json({ error: "email_sending_disabled" }, 503);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const resendApiKey = Deno.env.get("RESEND_API_KEY") ?? "";
  const fromEmail = Deno.env.get("RESEND_FROM_EMAIL") ?? "";
  if (!supabaseUrl || !serviceRoleKey || !resendApiKey || !fromEmail) {
    return json({ error: "worker_configuration_missing" }, 503);
  }

  const db = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false }
  });
  const workerId = `krim-email-${crypto.randomUUID()}`;
  let claimed = 0;
  let acceptedByProvider = 0;
  let failed = 0;
  let cancelled = 0;

  for (let index = 0; index < 5; index++) {
    const { data: claim, error: claimError } = await db.rpc("krim_claim_email_notification_delivery", {
      p_worker_id: workerId,
      p_lease_seconds: 300
    });
    if (claimError) return json({ error: "queue_claim_failed", claimed, accepted_by_provider: acceptedByProvider, failed, cancelled }, 503);
    if (!claim?.claimed) break;
    claimed++;

    const handoff = claim.handoff ?? {};
    const deliveryId = Number(handoff.delivery_id);
    const outboxId = Number(claim.outbox_id);
    if (handoff.status !== "queued" || !Number.isSafeInteger(deliveryId) || !Number.isSafeInteger(outboxId)) {
      if (handoff.status === "cancelled" || handoff.status === "failed") cancelled++;
      else failed++;
      continue;
    }

    const { data: outbox, error: outboxError } = await db
      .from("krim_notification_outbox")
      .select("id,organization_id,recipient_type,recipient_reference,subject,message,provider,idempotency_key,metadata,status")
      .eq("id", outboxId)
      .maybeSingle();

    if (outboxError || !outbox || outbox.status !== "processing" ||
        outbox.metadata?.worker_id !== workerId ||
        outbox.recipient_type !== "user" ||
        String(outbox.provider ?? "").toLowerCase() !== "resend") {
      const { data: cancelledResult } = await db.rpc("krim_cancel_email_notification_delivery", {
        p_delivery_id: deliveryId, p_worker_id: workerId,
        p_reason: "outbox_missing_invalid_or_unsupported_provider"
      });
      if (cancelledResult === true) cancelled++;
      else failed++;
      continue;
    }

    const recipientUserId = String(outbox.metadata?.recipient_user_id ?? "");
    const notificationClass = String(outbox.metadata?.notification_class ?? "");
    const organizationId = Number(outbox.organization_id);
    const allowedEventTypes = new Set([
      "shipment.created",
      "shipment.status_changed",
      "partner.assignment_offered",
      "partner.assignment_status_changed"
    ]);
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(recipientUserId) ||
        outbox.recipient_reference !== recipientUserId ||
        !Number.isSafeInteger(organizationId) || organizationId <= 0 ||
        notificationClass !== "essential" ||
        !allowedEventTypes.has(String(outbox.notification_type ?? ""))) {
      const { data: cancelledResult } = await db.rpc("krim_cancel_email_notification_delivery", {
        p_delivery_id: deliveryId, p_worker_id: workerId,
        p_reason: "recipient_metadata_invalid"
      });
      if (cancelledResult === true) cancelled++;
      else failed++;
      continue;
    }

    const { data: eligible, error: eligibilityError } = await db.rpc("krim_check_notification_email_eligibility", {
      p_user_id: recipientUserId,
      p_organization_id: organizationId,
      p_notification_class: notificationClass
    });
    if (eligibilityError || eligible !== true) {
      const { data: cancelledResult } = await db.rpc("krim_cancel_email_notification_delivery", {
        p_delivery_id: deliveryId, p_worker_id: workerId,
        p_reason: "recipient_not_eligible_immediately_before_send"
      });
      if (cancelledResult === true) cancelled++;
      else failed++;
      continue;
    }

    const { data: userResult, error: userError } = await db.auth.admin.getUserById(recipientUserId);
    const recipientEmail = userResult?.user?.email ?? "";
    const emailConfirmed = Boolean(userResult?.user?.email_confirmed_at);
    if (userError || !recipientEmail || !emailConfirmed) {
      const { data: cancelledResult } = await db.rpc("krim_cancel_email_notification_delivery", {
        p_delivery_id: deliveryId, p_worker_id: workerId,
        p_reason: "recipient_email_missing_or_unconfirmed"
      });
      if (cancelledResult === true) cancelled++;
      else failed++;
      continue;
    }

    const subject = String(outbox.subject ?? "KRIM Logistics notification").replace(/[\r\n]+/g, " ").slice(0, 180);
    const message = String(outbox.message ?? "You have a new KRIM Logistics update.");
    const textBody = `KRIM Logistics\n\n${message}\n\nSign in to your KRIM workspace to review the details.`;
    const htmlBody = `<!doctype html><html><body style="font-family:Arial,sans-serif;color:#172033;line-height:1.6"><h2>KRIM Logistics</h2><p>${escapeHtml(message)}</p><p>Sign in to your KRIM workspace to review the details.</p></body></html>`;

    let success = false;
    let providerMessageId: string | null = null;
    let errorCode = "provider_error";
    let errorMessage = "Email provider request failed.";
    try {
      const response = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "authorization": `Bearer ${resendApiKey}`,
          "content-type": "application/json",
          "idempotency-key": String(outbox.idempotency_key ?? `krim-notification-${outboxId}`).slice(0, 256)
        },
        body: JSON.stringify({ from: fromEmail, to: [recipientEmail], subject, text: textBody, html: htmlBody }),
        signal: AbortSignal.timeout(15000)
      });
      const result = await response.json().catch(() => ({}));
      success = response.ok && typeof result?.id === "string" && result.id.length > 0;
      if (success) providerMessageId = result.id;
      else {
        errorCode = response.status === 429 ? "provider_rate_limited"
          : response.status >= 500 ? "provider_temporary_error" : "provider_rejected_request";
        errorMessage = `Resend rejected the request (HTTP ${response.status}).`;
      }
    } catch {
      errorCode = "provider_network_error";
      errorMessage = "Resend timed out or could not be reached.";
    }

    const { data: completed, error: completionError } = await db.rpc("krim_complete_email_notification_delivery", {
      p_delivery_id: deliveryId,
      p_worker_id: workerId,
      p_success: success,
      p_provider_message_id: providerMessageId,
      p_error_code: success ? null : errorCode,
      p_error_message: success ? null : errorMessage
    });

    if (completionError || completed !== true) failed++;
    else if (success) acceptedByProvider++;
    else failed++;
  }

  return json({
    ok: failed === 0,
    claimed,
    accepted_by_provider: acceptedByProvider,
    failed,
    cancelled,
    processed_at: new Date().toISOString()
  }, failed > 0 ? 503 : 200);
});
