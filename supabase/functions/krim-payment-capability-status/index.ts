import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
    const { data: userData, error: userError } = await admin.auth.getUser(auth.slice(7).trim());
    if (userError || !userData.user) return respond({ success: false, error: "Session is invalid or expired" }, 401);

    let body: any;
    try { body = await req.json(); } catch { return respond({ success: false, error: "Invalid JSON body" }, 400); }
    const currency = String(body?.currency_code || "").trim().toUpperCase();
    if (!/^[A-Z]{3}$/.test(currency)) return respond({ success: false, error: "A valid ISO-style currency code is required" }, 400);

    const { data: capability, error } = await admin
      .from("krim_payment_capability_registry")
      .select("country_code,currency_code,provider_code,integration_status,checkout_enabled,merchant_eligibility_verified,presentment_supported,settlement_supported,refunds_supported,fx_supported")
      .eq("country_code", "IN")
      .eq("currency_code", currency)
      .eq("provider_code", "razorpay")
      .maybeSingle();

    if (error) {
      console.error("Payment capability lookup failed", error);
      return respond({ success: false, error: "Unable to check payment capability" }, 500);
    }
    void capability; // Registry state is deliberately not used to enable checkout in this launch mode.

    // Partner-direct is the active launch model. Capability registry records are informational only\n    // and must never expose checkout as available, regardless of provider configuration.\n    const enabled = false;

    return respond({
      success: true,
      enabled,
      country_code: "IN",
      currency_code: currency,
      provider_code: "razorpay",
      status: "partner_direct_disabled",
      reason: enabled
        ? (currency === "INR" ? "Current INR checkout capability is configured." : "International currency capability passed all configured gates.")
        : "This currency is not enabled. Merchant eligibility, presentment, settlement, refunds and FX must be verified before activation.",
      checked_at: new Date().toISOString(),
    });
  } catch (error) {
    console.error("Payment capability status error", error);
    return respond({ success: false, error: "Unexpected server error" }, 500);
  }
});
