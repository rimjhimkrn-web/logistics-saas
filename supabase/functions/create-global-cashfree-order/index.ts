import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cashfree-signature",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  return new Response(JSON.stringify({
    error: "This payment integration has been retired.",
    code: "PAYMENT_PROVIDER_RETIRED",
    message: "KRIM is operating in partner-direct mode. Pay your selected logistics partner directly. This retired provider endpoint cannot collect freight payments. For historical payments with unclear status, contact KRIM support for reconciliation; do not submit a second payment."
  }), {
    status: 410,
    headers: { ...corsHeaders, "Content-Type": "application/json", "Cache-Control": "no-store" }
  });
});