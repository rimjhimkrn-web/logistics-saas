import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function currencyMinorUnitExponent(currency: string): number {
  const code = String(currency || "").trim().toUpperCase();
  if (["BIF","CLP","DJF","GNF","ISK","JPY","KMF","KRW","PYG","RWF","UGX","UYI","VND","VUV","XAF","XOF","XPF"].includes(code)) return 0;
  if (["BHD","IQD","JOD","KWD","LYD","OMR","TND"].includes(code)) return 3;
  if (["CLF","UYW"].includes(code)) return 4;
  return 2;
}


const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function respond(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return respond({ success: false, error: "POST required" }, 405);

  try {
    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const auth = req.headers.get("Authorization") || "";
    if (!url || !serviceKey) return respond({ success: false, error: "Server configuration unavailable" }, 500);
    if (!auth.startsWith("Bearer ")) return respond({ success: false, error: "Sign in required" }, 401);

    const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const token = auth.slice(7).trim();
    const { data: userData, error: userError } = await admin.auth.getUser(token);
    if (userError || !userData.user) return respond({ success: false, error: "Session is invalid or expired" }, 401);
    const user = userData.user;

    let body: any;
    try { body = await req.json(); } catch { return respond({ success: false, error: "Invalid JSON body" }, 400); }
    const orderId = String(body?.payment_order_id || "").trim();
    const shipmentId = Number(body?.shipment_id);
    const quoteId = Number(body?.quote_id);
    if (!orderId || orderId.length > 100 || !Number.isSafeInteger(shipmentId) || shipmentId < 1 || !Number.isSafeInteger(quoteId) || quoteId < 1) {
      return respond({ success: false, error: "Valid payment order, shipment and quote references are required" }, 400);
    }

    const { data: order, error: orderError } = await admin
      .from("payment_orders")
      .select("id,customer_id,customer_organization_id,krim_shipment_id,krim_quote_id,partner_quote_id,amount_paise,currency,status,razorpay_order_id,razorpay_payment_id,paid_at")
      .eq("id", orderId)
      .eq("payment_provider", "razorpay")
      .maybeSingle();
    if (orderError) return respond({ success: false, error: "Unable to read KRIM payment status" }, 500);
    if (!order) return respond({ success: false, error: "Payment order not found" }, 404);

    if (order.customer_id && order.customer_id !== user.id) return respond({ success: false, error: "Payment order access denied" }, 403);
    if (Number(order.krim_shipment_id) !== shipmentId || Number(order.krim_quote_id) !== quoteId) {
      return respond({ success: false, error: "Payment order does not match the requested shipment and quote" }, 409);
    }
    if (!order.customer_organization_id) return respond({ success: false, error: "Payment order has no customer organization binding" }, 409);

    const { data: hasAccess, error: accessError } = await admin.rpc("krim_has_organization_access", {
      p_user_id: user.id,
      p_organization_id: order.customer_organization_id,
    });
    if (accessError) return respond({ success: false, error: "Organization access check failed" }, 500);
    if (!hasAccess) return respond({ success: false, error: "Organization access denied" }, 403);

    const { data: quote, error: quoteError } = await admin.from("krim_quotes")
      .select("id,shipment_id,customer_organization_id,partner_quote_id,amount,currency_code,status")
      .eq("id", quoteId)
      .eq("shipment_id", shipmentId)
      .maybeSingle();
    if (quoteError) return respond({ success: false, error: "Unable to validate quote linkage" }, 500);
    if (!quote || Number(quote.customer_organization_id) !== Number(order.customer_organization_id) || Number(quote.partner_quote_id) !== Number(order.partner_quote_id)) {
      return respond({ success: false, error: "Quote and payment order linkage does not match" }, 409);
    }
    const { data: shipment, error: shipmentError } = await admin.from("krim_shipments")
      .select("id,customer_organization_id")
      .eq("id", shipmentId)
      .maybeSingle();
    if (shipmentError) return respond({ success: false, error: "Unable to validate shipment linkage" }, 500);
    if (!shipment || Number(shipment.customer_organization_id) !== Number(order.customer_organization_id)) {
      return respond({ success: false, error: "Shipment and payment order organization linkage does not match" }, 409);
    }
    if (Number(quote.amount) * (10 ** currencyMinorUnitExponent(String(order.currency || "").toUpperCase())) !== Number(order.amount_paise) && Math.round(Number(quote.amount) * (10 ** currencyMinorUnitExponent(String(order.currency || "").toUpperCase()))) !== Number(order.amount_paise)) {
      return respond({ success: false, error: "Quote amount and payment order amount do not match" }, 409);
    }
    if (String(quote.currency_code || "").toUpperCase() !== String(order.currency || "").toUpperCase()) {
      return respond({ success: false, error: "Quote currency and payment order currency do not match" }, 409);
    }

    const { data: transaction, error: transactionError } = await admin
      .from("krim_financial_transactions")
      .select("id,shipment_id,organization_id,provider_reference,status,amount,currency_code,transaction_time")
      .eq("provider", "razorpay")
      .eq("provider_reference", order.razorpay_payment_id || "__no_payment_reference__")
      .maybeSingle();
    if (transactionError) return respond({ success: false, error: "Financial transaction reconciliation lookup failed" }, 500);

    const paid = order.status === "paid" && Boolean(order.razorpay_payment_id) && Boolean(transaction)
      && transaction.status === "completed"
      && Number(transaction.shipment_id) === shipmentId
      && Number(transaction.organization_id) === Number(order.customer_organization_id)
      && Math.round(Number(transaction.amount) * (10 ** currencyMinorUnitExponent(String(order.currency || "").toUpperCase()))) === Number(order.amount_paise)
      && String(transaction.currency_code || "").toUpperCase() === String(order.currency || "").toUpperCase();

    return respond({
      success: true,
      verified: paid,
      status: paid ? "paid" : (order.status === "paid" ? "reconciliation_pending" : order.status),
      payment_order_id: order.id,
      customer_organization_id: order.customer_organization_id,
      partner_quote_id: order.partner_quote_id,
      shipment_id: shipmentId,
      quote_id: quoteId,
      amount_paise: order.amount_paise,
      currency: order.currency,
      razorpay_order_id: order.razorpay_order_id,
      razorpay_payment_id: order.razorpay_payment_id,
      paid_at: order.paid_at,
      financial_transaction_id: transaction?.id || null,
      checked_at: new Date().toISOString(),
      message: paid
        ? "KRIM server records confirm a paid order and matching completed financial transaction."
        : "KRIM does not yet have a fully reconciled verified payment record. Do not pay again until the original transaction is checked.",
    });
  } catch (error) {
    console.error("Payment verification status error:", error);
    return respond({ success: false, error: error instanceof Error ? error.message : "Unexpected server error" }, 500);
  }
});