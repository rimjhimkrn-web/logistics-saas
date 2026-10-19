import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json", "Cache-Control": "no-store" } });
}
function bytesToBase64(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}
async function hmacBase64(secret: string, message: string) {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return bytesToBase64(new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message))));
}
function constantTimeEqual(a: string, b: string) {
  if (a.length !== b.length) return false;
  let out = 0;
  for (let i = 0; i < a.length; i++) out |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return out === 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);
  try {
    const secret = Deno.env.get("CASHFREE_CLIENT_SECRET");
    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!secret || !url || !serviceKey || (Deno.env.get("CASHFREE_ENV") || "sandbox") !== "sandbox")
      return reply({ error: "Cashfree sandbox webhook is not configured" }, 503);

    const signature = req.headers.get("x-webhook-signature") || "";
    const timestamp = req.headers.get("x-webhook-timestamp") || "";
    if (!signature || !timestamp || !/^\d{10,16}$/.test(timestamp)) return reply({ error: "Missing webhook signature" }, 401);
    const raw = await req.text();
    const expected = await hmacBase64(secret, timestamp + raw);
    if (!constantTimeEqual(signature, expected)) return reply({ error: "Invalid webhook signature" }, 401);

    let event: any;
    try { event = JSON.parse(raw); } catch { return reply({ error: "Invalid JSON" }, 400); }
    const orderId = String(event?.data?.order?.order_id || event?.data?.order_id || "");
    const payment = event?.data?.payment || {};
    const paymentStatus = String(payment?.payment_status || "");
    if (!orderId || !orderId.startsWith("krim_")) return reply({ received: true, ignored: true });

    const supabase = createClient(url, serviceKey);
    const { data: local, error: localError } = await supabase.from("payment_orders")
      .select("id,status,amount_paise,currency,customer_id,krim_quote_id,krim_shipment_id,customer_organization_id,partner_quote_id")
      .eq("cashfree_order_id", orderId).eq("payment_provider", "cashfree").maybeSingle();
    if (localError || !local) return reply({ received: true, ignored: true });

    // A signed webhook is a notification, not the final source of truth: query Cashfree independently.
    const clientId = Deno.env.get("CASHFREE_CLIENT_ID");
    if (!clientId) return reply({ error: "Cashfree API credentials missing" }, 503);
    const headers = { "x-api-version": "2023-08-01", "x-client-id": clientId, "x-client-secret": secret };
    const base = "https://sandbox.cashfree.com/pg";
    const [orderRes, paymentsRes] = await Promise.all([
      fetch(base + "/orders/" + encodeURIComponent(orderId), { headers }),
      fetch(base + "/orders/" + encodeURIComponent(orderId) + "/payments", { headers }),
    ]);
    if (!orderRes.ok || !paymentsRes.ok) return reply({ error: "Provider status check failed; retry webhook" }, 502);
    const cashOrder: any = await orderRes.json();
    const payments: any = await paymentsRes.json();
    const list = Array.isArray(payments) ? payments : [];
    const successful = list.find((p: any) => p?.payment_status === "SUCCESS" &&
      Math.round(Number(p?.payment_amount) * 100) === Number(local.amount_paise) &&
      String(p?.payment_currency || local.currency).toUpperCase() === String(local.currency).toUpperCase());
    if (cashOrder?.order_status !== "PAID" || !successful || paymentStatus !== "SUCCESS") {
      return reply({ received: true, verified: false, provider_status: cashOrder?.order_status || paymentStatus });
    }
    if (local.status === "paid") return reply({ received: true, verified: true, duplicate: true });

    const { data: quote } = await supabase.from("krim_quotes")
      .select("id,status,partner_quote_id,customer_organization_id").eq("id", local.krim_quote_id).maybeSingle();
    const { data: assignment } = quote ? await supabase.from("krim_shipment_partner_assignments")
      .select("id,status").eq("shipment_id", local.krim_shipment_id).eq("partner_quote_id", quote.partner_quote_id)
      .order("created_at", { ascending: false }).limit(1).maybeSingle() : { data: null };
    if (!quote || quote.status !== "accepted" || quote.partner_quote_id !== local.partner_quote_id ||
        quote.customer_organization_id !== local.customer_organization_id || !assignment || assignment.status !== "accepted")
      return reply({ received: true, verified: false, review_required: true });

    const { error: updateError } = await supabase.from("payment_orders").update({
      status: "paid", cashfree_payment_id: String(successful.cf_payment_id || successful.payment_id || ""),
      paid_at: new Date().toISOString(), updated_at: new Date().toISOString(),
    }).eq("id", local.id).eq("status", "created");
    if (updateError) {
      console.error("Cashfree webhook ledger update failed", updateError.message);
      return reply({ error: "Ledger update failed; retry webhook" }, 500);
    }
    return reply({ received: true, verified: true });
  } catch (error) {
    console.error("Cashfree webhook handler failed", error);
    return reply({ error: "Unexpected webhook processing error" }, 500);
  }
});