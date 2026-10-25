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
    const authorization = req.headers.get("Authorization") || "";
    if (!url || !serviceKey) return respond({ success: false, error: "Server configuration unavailable" }, 500);
    if (!authorization.startsWith("Bearer ")) return respond({ success: false, error: "Sign in required" }, 401);

    const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: authData, error: authError } = await admin.auth.getUser(authorization.slice(7).trim());
    if (authError || !authData.user) return respond({ success: false, error: "Session is invalid or expired" }, 401);

    let body: any;
    try { body = await req.json(); } catch { return respond({ success: false, error: "Invalid JSON body" }, 400); }
    const country = String(body?.country_code || "IN").trim().toUpperCase();
    const currency = String(body?.currency_code || "INR").trim().toUpperCase();
    if (!/^[A-Z]{2}$/.test(country) || !/^[A-Z]{3}$/.test(currency)) {
      return respond({ success: false, error: "Valid country and currency codes are required" }, 400);
    }

    const { data: rows, error } = await admin
      .from("krim_payment_capability_registry")
      .select("country_code,currency_code,provider_code,integration_status,checkout_enabled,merchant_eligibility_verified,presentment_supported,settlement_supported,refunds_supported,fx_supported,evidence_reference,reviewed_at,notes")
      .eq("country_code", country)
      .eq("currency_code", currency)
      .order("provider_code", { ascending: true });

    if (error) {
      console.error("Global payment options lookup failed", error);
      return respond({ success: false, error: "Unable to load payment options" }, 500);
    }

    const options = (rows || []).map((row: any) => {
      const blockers: string[] = [];
      if (row.integration_status !== "implemented") blockers.push("Integration is not implemented.");
      if (row.checkout_enabled !== true) blockers.push("Checkout is disabled.");
      if (row.merchant_eligibility_verified !== true) blockers.push("Merchant eligibility is not verified.");
      if (row.presentment_supported !== true) blockers.push("Presentment support is not verified.");
      if (row.settlement_supported !== true) blockers.push("Settlement support is not verified.");
      if (row.refunds_supported !== true) blockers.push("Refund support is not verified.");
      if (row.fx_supported !== true) blockers.push("FX support is not verified.");
      if (!String(row.evidence_reference || "").trim()) blockers.push("Evidence reference is missing.");
      if (!row.reviewed_at) blockers.push("Review timestamp is missing.");

      const operationallyVerified = blockers.length === 0;
      return {
        provider_code: row.provider_code,
        country_code: row.country_code,
        currency_code: row.currency_code,
        integration_status: row.integration_status,
        checkout_configured: row.integration_status === "implemented" && row.checkout_enabled === true,
        operationally_verified: operationallyVerified,
        selectable: row.integration_status === "implemented" && row.checkout_enabled === true && operationallyVerified,
        blockers,
        reviewed_at: row.reviewed_at,
        notes: row.notes || null,
      };
    });

    return respond({
      success: true,
      country_code: country,
      currency_code: currency,
      options,
      selectable_count: options.filter((option: any) => option.selectable).length,
      message: "Only explicitly enabled and evidence-verified provider/country/currency combinations are selectable. Planned providers are displayed as unavailable and cannot create payment orders.",
      checked_at: new Date().toISOString(),
    });
  } catch (error) {
    console.error("Global payment options error", error);
    return respond({ success: false, error: "Unexpected server error" }, 500);
  }
});