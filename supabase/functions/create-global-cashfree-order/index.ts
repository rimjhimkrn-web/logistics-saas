import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" },
});

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);

  try {
    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const clientId = Deno.env.get("CASHFREE_CLIENT_ID");
    const clientSecret = Deno.env.get("CASHFREE_CLIENT_SECRET");
    const env = (Deno.env.get("CASHFREE_ENV") || "sandbox").toLowerCase();
    if (!url || !serviceKey || !clientId || !clientSecret || env !== "sandbox") {
      return reply({ error: "Cashfree sandbox is not configured. Live mode is intentionally disabled." }, 503);
    }
    const auth = req.headers.get("Authorization") || "";
    if (!auth.startsWith("Bearer ")) return reply({ error: "Login required" }, 401);
    const supabase = createClient(url, serviceKey);
    const { data: authData, error: authError } = await supabase.auth.getUser(auth.slice(7).trim());
    if (authError || !authData.user) return reply({ error: "Invalid or expired session" }, 401);
    const body = await req.json().catch(() => null);
    const shipmentId = Number(body?.krim_shipment_id);
    if (!Number.isSafeInteger(shipmentId) || shipmentId <= 0) return reply({ error: "Valid shipment ID required" }, 400);

    const { data: shipment, error: shipmentError } = await supabase
      .from("krim_shipments").select("id, shipment_number, status").eq("id", shipmentId).maybeSingle();
    if (shipmentError || !shipment) return reply({ error: "Shipment not found" }, 404);
    if (shipment.status !== "confirmed") return reply({ error: "Shipment must be confirmed before checkout" }, 409);

    const { data: quote, error: quoteError } = await supabase
      .from("krim_quotes")
      .select("id, shipment_id, customer_organization_id, partner_quote_id, amount, currency_code, valid_until, status")
      .eq("shipment_id", shipmentId).eq("status", "accepted")
      .order("id", { ascending: false }).limit(1).maybeSingle();
    if (quoteError || !quote) return reply({ error: "Accepted quote not found" }, 409);
    if (!quote.customer_organization_id) return reply({ error: "Quote organization is missing" }, 409);
    const { data: access, error: accessError } = await supabase.rpc("krim_has_organization_access", {
      p_organization_id: quote.customer_organization_id,
      p_user_id: authData.user.id,
    });
    if (accessError || access !== true) return reply({ error: "You do not have access to this shipment" }, 403);
    if (!quote.partner_quote_id) return reply({ error: "Partner selection is required before checkout" }, 409);
    const { data: assignment } = await supabase.from("krim_shipment_partner_assignments")
      .select("id,status").eq("shipment_id", shipmentId).eq("partner_quote_id", quote.partner_quote_id)
      .order("created_at", { ascending: false }).limit(1).maybeSingle();
    if (!assignment || assignment.status !== "accepted") return reply({ error: "Partner assignment is not accepted" }, 409);
    if (quote.valid_until && new Date(quote.valid_until).getTime() <= Date.now()) return reply({ error: "Quote expired" }, 409);
    const amount = Number(quote.amount);
    const currency = String(quote.currency_code || "").toUpperCase();
    if (!Number.isFinite(amount) || amount <= 0 || currency !== "INR") return reply({ error: "Sandbox checkout currently supports valid INR quotes only" }, 400);

    const { data: existing } = await supabase.from("payment_orders")
      .select("id,cashfree_order_id,cashfree_payment_session_id,amount_paise,currency,status")
      .eq("krim_quote_id", quote.id).eq("customer_id", authData.user.id)
      .eq("payment_provider", "cashfree").in("status", ["created","pending"])
      .order("created_at", { ascending: false }).limit(1).maybeSingle();
    if (existing?.cashfree_order_id && existing.cashfree_payment_session_id &&
        Number(existing.amount_paise) === Math.round(amount * 100) && existing.currency === currency) {
      return reply({ success: true, provider: "cashfree", sandbox: true, payment_order_id: existing.id,
        order_id: existing.cashfree_order_id, payment_session_id: existing.cashfree_payment_session_id,
        amount: amount, currency, quote_id: quote.id, shipment_id: shipment.id });
    }

    const orderId = "krim_" + shipmentId + "_" + quote.id + "_" + crypto.randomUUID().replaceAll("-", "").slice(0, 12);
    const base = "https://sandbox.cashfree.com/pg";
    const cfRes = await fetch(base + "/orders", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-version": "2023-08-01",
        "x-client-id": clientId,
        "x-client-secret": clientSecret,
        "x-idempotency-key": crypto.randomUUID(),
      },
      body: JSON.stringify({
        order_id: orderId, order_amount: Math.round(amount * 100) / 100, order_currency: currency,
        customer_details: {
          customer_id: authData.user.id,
          customer_email: authData.user.email || "customer@krimlogistics.com",
          customer_phone: String(authData.user.phone || "9999999999"),
        },
        order_meta: { return_url: "https://rimjhimkrn-web.github.io/logistics-saas/public/quote-result.html?shipment_id=" + shipmentId + "&cashfree_order_id={order_id}" },
        order_note: "KRIM sandbox shipment " + (shipment.shipment_number || shipmentId),
      }),
    });
    const cfText = await cfRes.text();
    let cf: any = {}; try { cf = JSON.parse(cfText); } catch { /* handled below */ }
    if (!cfRes.ok || !cf?.payment_session_id || !cf?.order_id) {
      console.error("Cashfree sandbox order failed", cfRes.status, cfRes.statusText);
      return reply({ error: "Cashfree sandbox could not create an order", provider_status: cfRes.status }, 502);
    }
    const { data: saved, error: saveError } = await supabase.from("payment_orders").insert({
      shipment_id: null, krim_shipment_id: shipmentId, krim_quote_id: quote.id,
      partner_quote_id: quote.partner_quote_id, customer_organization_id: quote.customer_organization_id,
      customer_id: authData.user.id, amount_paise: Math.round(amount * 100), currency,
      status: "created", payment_provider: "cashfree", cashfree_order_id: cf.order_id,
      cashfree_payment_session_id: cf.payment_session_id,
    }).select("id").single();
    if (saveError) {
      console.error("Cashfree order persistence failed", saveError.message);
      return reply({ error: "Order created but could not be safely recorded; contact support before retrying" }, 500);
    }
    return reply({ success: true, provider: "cashfree", sandbox: true, payment_order_id: saved.id,
      order_id: cf.order_id, payment_session_id: cf.payment_session_id, amount, currency,
      quote_id: quote.id, shipment_id: shipment.id });
  } catch (error) {
    console.error("Cashfree order handler failed", error);
    return reply({ error: "Unexpected sandbox checkout error" }, 500);
  }
});