import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store"
};

function reply(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" }
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return reply(405, { error: "POST required" });

  const declaredLength = Number(req.headers.get("content-length") || "0");
  if (declaredLength > 9000) return reply(413, { error: "Request is too large." });

  try {
    const url = Deno.env.get("SUPABASE_URL");
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !key) return reply(503, { error: "Contact service is not configured." });

    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      return reply(400, { error: "Invalid request." });
    }
    if (body.privacy_consent !== true) {
      return reply(400, { error: "Please accept the privacy notice before submitting your enquiry." });
    }
    if (typeof body.website === "string" && body.website.trim()) {
      return reply(200, { success: true });
    }

    const full_name = String(body.full_name || "").trim();
    const email = String(body.email || "").trim().toLowerCase();
    const organization = String(body.organization || "").trim();
    const message = String(body.message || "").trim();
    const source_page = String(body.source_page || "");

    if (full_name.length < 2 || full_name.length > 120) {
      return reply(400, { error: "Enter a name between 2 and 120 characters." });
    }
    if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return reply(400, { error: "Enter a valid email address." });
    }
    if (organization.length < 2 || organization.length > 180) {
      return reply(400, { error: "Enter an organization name between 2 and 180 characters." });
    }
    if (message.length < 10 || message.length > 5000) {
      return reply(400, { error: "Message must be between 10 and 5000 characters." });
    }

    const db = createClient(url, key, {
      auth: { persistSession: false, autoRefreshToken: false }
    });

    // Use only the edge-provided Cloudflare client address; never trust caller-supplied X-Forwarded-For.
    const clientIp = req.headers.get("cf-connecting-ip");
    if (clientIp) {
      const { data: ipLimit, error: ipLimitError } = await db.rpc(
        "krim_check_public_inquiry_ip_limit",
        { p_ip: clientIp }
      );
      if (ipLimitError) {
        console.error("IP throttle check failed:", ipLimitError.message);
        return reply(503, { error: "Contact service is temporarily unavailable." });
      }
      if (ipLimit?.limited === true) {
        return reply(429, { error: "Too many requests. Please try again in a few minutes." });
      }
    }

    const { data, error } = await db.rpc("krim_submit_public_contact_inquiry", {
      p_full_name: full_name,
      p_email: email,
      p_organization: organization,
      p_message: message,
      p_source_page: source_page
    });

    if (error) {
      console.error("Contact inquiry transaction failed:", error.message);
      return reply(503, { error: "Your inquiry could not be saved. Please try again later." });
    }
    if (data?.rate_limited === true) {
      return reply(429, { error: "Too many enquiries from this email address. Please try again later." });
    }
    if (data?.success !== true || !data?.inquiry_id || !data?.outbox_id) {
      return reply(503, { error: "Your inquiry could not be confirmed. Please try again later." });
    }

    // Link the saved enquiry to the existing service-request qualification engine.
    // This creates a general enquiry request only; it does not create a quote or booking.
    const { data: linkedRequest, error: linkError } = await db.rpc(
      "krim_internal_link_public_inquiry_to_service_request",
      { p_inquiry_id: data.inquiry_id }
    );
    if (linkError) {
      console.error("Customer service-request linkage failed:", linkError.message);
    }

    const token = Deno.env.get("TELEGRAM_BOT_TOKEN");
    const chatId = Deno.env.get("TELEGRAM_CHAT_ID");
    if (!token || !chatId) {
      await db.from("krim_notification_outbox")
        .update({
          status: "failed",
          attempt_count: 1,
          last_error: "Telegram credentials are not configured.",
          next_attempt_at: new Date(Date.now() + 300000).toISOString()
        })
        .eq("id", data.outbox_id);
      return reply(200, {
        success: true,
        message: "Your inquiry has been received.",
        notification_status: "queued",
        reference: data.inquiry_id
      });
    }

    const attributionKeys = ["Landing page", "Referrer", "UTM source", "UTM medium", "UTM campaign", "UTM content"];
    const attributionLines = message.split(/\r?\n/).filter((line: string) =>
      attributionKeys.some((key) => line.startsWith(key + ":"))
    ).map((line: string) => line.slice(0, 260)).slice(0, 6);
    const notificationText = [
      "KRIM Logistics — New customer enquiry",
      `Name: ${full_name}`,
      `Email: ${email}`,
      `Organization: ${organization}`,
      `Source: ${source_page === "krim-global-advertisement.html" ? source_page : "contact.html"}`,
      ...attributionLines,
      `Reference: ${data.inquiry_id}`
    ].join("\n");

    try {
      const telegramResponse = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          chat_id: chatId,
          text: notificationText,
          disable_web_page_preview: true
        })
      });
      const telegramResult = await telegramResponse.json().catch(() => ({}));

      if (!telegramResponse.ok || telegramResult?.ok !== true) {
        await db.from("krim_notification_outbox")
          .update({
            status: "failed",
            attempt_count: 1,
            last_error: "Telegram provider rejected the notification.",
            next_attempt_at: new Date(Date.now() + 900000).toISOString()
          })
          .eq("id", data.outbox_id);
        return reply(200, {
          success: true,
          message: "Your inquiry has been received.",
          notification_status: "queued_for_retry",
          reference: data.inquiry_id
        });
      }

      const providerMessageId = String(telegramResult?.result?.message_id ?? "");
      const { error: updateError } = await db.from("krim_notification_outbox")
        .update({
          status: "sent",
          sent_at: new Date().toISOString(),
          attempt_count: 1,
          provider: "telegram",
          provider_message_id: providerMessageId || null,
          last_error: null
        })
        .eq("id", data.outbox_id);

      if (updateError) console.error("Outbox status update failed:", updateError.message);

      return reply(200, {
        success: true,
        message: "Your inquiry has been received.",
        notification_status: updateError ? "sent_status_pending" : "sent",
        reference: data.inquiry_id
      });
    } catch {
      await db.from("krim_notification_outbox")
        .update({
          status: "failed",
          attempt_count: 1,
          last_error: "Telegram network delivery failed.",
          next_attempt_at: new Date(Date.now() + 900000).toISOString()
        })
        .eq("id", data.outbox_id);
      return reply(200, {
        success: true,
        message: "Your inquiry has been received.",
        notification_status: "queued_for_retry",
        reference: data.inquiry_id
      });
    }
  } catch {
    return reply(400, { error: "Invalid request." });
  }
});