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
    const url = Deno.env.get("SUPABASE_URL"), serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const clientId = Deno.env.get("CASHFREE_CLIENT_ID"), clientSecret = Deno.env.get("CASHFREE_CLIENT_SECRET");
    if (!url || !serviceKey || !clientId || !clientSecret || (Deno.env.get("CASHFREE_ENV") || "sandbox") !== "sandbox")
      return reply({ error: "Cashfree sandbox is not configured; live verification is disabled" }, 503);
    const auth = req.headers.get("Authorization") || "";
    if (!auth.startsWith("Bearer ")) return reply({ error: "Login required" }, 401);
    const supabase = createClient(url, serviceKey);
    const { data: userData, error: userError } = await supabase.auth.getUser(auth.slice(7).trim());
    if (userError || !userData.user) return reply({ error: "Invalid or expired session" }, 401);
    const body = await req.json().catch(() => null);
    const orderId = String(body?.order_id || body?.cashfree_order_id || "").trim();
    if (!/^krim_[a-zA-Z0-9_-]{8,100}$/.test(orderId)) return reply({ error: "Invalid Cashfree order reference" }, 400);
    const { data: order, error: orderError } = await supabase.from("payment_orders")
      .select("id,krim_shipment_id,krim_quote_id,customer_id,customer_organization_id,amount_paise,currency,status,cashfree_order_id,cashfree_payment_id,partner_quote_id")
      .eq("cashfree_order_id", orderId).eq("payment_provider", "cashfree").maybeSingle();
    if (orderError || !order) return reply({ error: "Local Cashfree order not found" }, 404);
    if (order.customer_id !== userData.user.id) return reply({ error: "Payment order does not belong to this user" }, 403);
    if (order.status === "paid") return reply({ success: true, verified: true, idempotent: true, payment_order_id: order.id });
    const headers = { "x-api-version": "2023-08-01", "x-client-id": clientId, "x-client-secret": clientSecret };
    const base = "https://sandbox.cashfree.com/pg";
    const [orderRes, paymentsRes] = await Promise.all([
      fetch(base + "/orders/" + encodeURIComponent(orderId), { headers }),
      fetch(base + "/orders/" + encodeURIComponent(orderId) + "/payments", { headers }),
    ]);
    if (!orderRes.ok || !paymentsRes.ok) return reply({ error: "Cashfree could not confirm the order status yet" }, 502);
    const cashOrder: any = await orderRes.json();
    const payments: any = await paymentsRes.json();
    const paymentList = Array.isArray(payments) ? payments : [];
    const paidPayment = paymentList.find((p: any) => p?.payment_status === "SUCCESS" &&
      Number(p?.payment_amount) * 100 === Number(order.amount_paise) &&
      String(p?.payment_currency || order.currency).toUpperCase() === String(order.currency).toUpperCase());
    if (cashOrder?.order_status !== "PAID" || !paidPayment) {
      return reply({ success: true, verified: false, status: cashOrder?.order_status || "PENDING",
        message: "Cashfree has not confirmed a successful matching payment." });
    }
    const { data: quote } = await supabase.from("krim_quotes")
      .select("id,partner_quote_id,customer_organization_id,status").eq("id", order.krim_quote_id).maybeSingle();
    if (!quote || quote.status !== "accepted" || quote.partner_quote_id !== order.partner_quote_id ||
        quote.customer_organization_id !== order.customer_organization_id) {
      return reply({ error: "The accepted quote no longer matches this payment order; manual reconciliation required" }, 409);
    }
    const { data: assignment } = await supabase.from("krim_shipment_partner_assignments")
      .select("id,status").eq("shipment_id", order.krim_shipment_id).eq("partner_quote_id", quote.partner_quote_id)
      .order("created_at", { ascending: false }).limit(1).maybeSingle();
    if (!assignment || assignment.status !== "accepted") return reply({ error: "Partner assignment is not accepted; manual reconciliation required" }, 409);
    const { error: updateError } = await supabase.from("payment_orders").update({
      status: "paid", cashfree_payment_id: String(paidPayment.cf_payment_id || paidPayment.payment_id || ""),
      paid_at: new Date().toISOString(), updated_at: new Date().toISOString(),
    }).eq("id", order.id).eq("status", "created");
    if (updateError) {
      console.error("Cashfree payment status update failed", updateError.message);
      return reply({ error: "Payment verified with Cashfree but KRIM ledger update failed; contact support" }, 500);
    }
    return reply({ success: true, verified: true, payment_order_id: order.id,
      cashfree_order_id: orderId, status: "paid", sandbox: true });
  } catch (error) {
    console.error("Cashfree verification failed", error);
    return reply({ error: "Unexpected Cashfree verification error" }, 500);
  }
});