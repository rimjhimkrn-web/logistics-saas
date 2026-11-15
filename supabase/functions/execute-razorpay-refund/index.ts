import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function reply(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);

  try {
    // Refund execution is disabled under the current partner-direct launch model.
    // Historical refund webhooks remain available for reconciliation; initiating a
    // new Razorpay refund requires a separate, explicit legacy-refund approval.
    if (
      Deno.env.get("KRIM_LEGACY_REFUND_EXECUTION_ENABLED") !== "true" ||
      Deno.env.get("KRIM_LEGACY_REFUND_APPROVAL_VERSION") !== "2026-11-15-v1"
    ) {
      return reply({
        error: "KRIM refund execution is disabled. Historical payment outcomes must be reconciled manually; do not initiate a new platform refund.",
        code: "KRIM_REFUND_EXECUTION_NOT_APPROVED",
      }, 503);
    }

    const auth = req.headers.get("Authorization") || "";
    if (!auth.startsWith("Bearer ")) return reply({ error: "Login required" }, 401);
    const token = auth.slice(7).trim();
    if (!token) return reply({ error: "Login required" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const razorpayKeyId = Deno.env.get("RAZORPAY_KEY_ID");
    const razorpayKeySecret = Deno.env.get("RAZORPAY_KEY_SECRET");
    if (!supabaseUrl || !anonKey || !razorpayKeyId || !razorpayKeySecret) {
      return reply({ error: "Refund execution server configuration is incomplete" }, 500);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: userData, error: userError } = await userClient.auth.getUser(token);
    if (userError || !userData?.user) return reply({ error: "Invalid or expired session" }, 401);

    let body: Record<string, unknown>;
    try { body = await req.json(); } catch { return reply({ error: "Invalid JSON body" }, 400); }
    const refundRequestId = String(body?.refund_request_id || "").trim();
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(refundRequestId)) {
      return reply({ error: "A valid refund_request_id is required" }, 400);
    }

    // The database performs AAL2, finance permission, reviewer identity,
    // requester/reviewer separation, full-amount and payment-state checks.
    const { data: claim, error: claimError } = await userClient.rpc(
      "krim_claim_razorpay_refund_execution",
      { p_refund_request_id: refundRequestId },
    );
    if (claimError || !claim) {
      console.error("Refund authorization/claim rejected", claimError);
      return reply({ error: claimError?.message || "Refund execution could not be authorized" }, 403);
    }

    const paymentId = String(claim.razorpay_payment_id || "");
    const amount = Number(claim.amount_paise);
    const key = String(claim.idempotency_key || "");
    if (!paymentId || !Number.isSafeInteger(amount) || amount <= 0 || key.length < 10 ||
        claim.currency !== "INR" || claim.status !== "execution_pending") {
      return reply({ error: "The approved refund claim is incomplete or invalid; manual reconciliation required" }, 409);
    }

    // Reuse the request's stable idempotency key and exact request body on every retry.
    const refundBody = {
      amount,
      notes: { krim_refund_request_id: refundRequestId },
    };
    const authHeader = "Basic " + btoa(`${razorpayKeyId}:${razorpayKeySecret}`);
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 18000);
    let providerResponse: Response;
    let providerText: string;
    try {
      providerResponse = await fetch(
        `https://api.razorpay.com/v1/payments/${encodeURIComponent(paymentId)}/refund`,
        {
          method: "POST",
          headers: {
            Authorization: authHeader,
            "Content-Type": "application/json",
            "X-Refund-Idempotency": key,
          },
          body: JSON.stringify(refundBody),
          signal: controller.signal,
        },
      );
      providerText = await providerResponse.text();
    } catch (networkError) {
      console.error("Refund provider response uncertain; keep execution_pending and retry only with same idempotency key", networkError);
      return reply({
        success: false,
        status: "execution_pending",
        code: "PROVIDER_RESPONSE_UNCERTAIN",
        message: "The provider response was not received. No new refund key was created. Reconcile Razorpay before retrying; retries use the same idempotency key.",
        refund_request_id: refundRequestId,
      }, 202);
    } finally {
      clearTimeout(timeout);
    }

    let providerData: Record<string, unknown>;
    try { providerData = JSON.parse(providerText); } catch { providerData = { raw: providerText.slice(0, 1000) }; }

    if (!providerResponse.ok) {
      // Do not mark the request failed from an ambiguous API error. The webhook is
      // the authoritative provider outcome; preserve execution_pending for safe review.
      console.error("Razorpay refund API returned non-success", providerResponse.status, providerData);
      return reply({
        success: false,
        status: "execution_pending",
        code: "PROVIDER_REJECTED_OR_UNCONFIRMED",
        provider_http_status: providerResponse.status,
        message: "Razorpay did not confirm refund creation. The request remains pending for reconciliation; do not change its idempotency key.",
        refund_request_id: refundRequestId,
      }, 202);
    }

    const providerRefundId = String(providerData.id || "");
    const providerStatus = String(providerData.status || "");
    if (!providerRefundId) {
      return reply({
        success: false,
        status: "execution_pending",
        code: "PROVIDER_RESPONSE_MISSING_REFUND_ID",
        message: "Razorpay response did not include a refund ID. Keep pending and reconcile using the same idempotency key.",
        refund_request_id: refundRequestId,
      }, 202);
    }

    // Webhook reconciliation records the provider ID/status and final ledger state.
    return reply({
      success: true,
      status: "execution_pending",
      message: "Razorpay accepted the refund request. Final status will be recorded by the signed refund webhook.",
      refund_request_id: refundRequestId,
      provider_refund_id: providerRefundId,
      provider_status: providerStatus,
    }, 202);
  } catch (error) {
    console.error("Refund execution error", error);
    return reply({ error: "Unexpected refund execution error; reconcile provider status before retrying" }, 500);
  }
});