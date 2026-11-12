import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  return new Response(JSON.stringify({
    error: "This legacy payment endpoint has been retired.",
    code: "LEGACY_PAYMENT_ENDPOINT_RETIRED",
    message: "KRIM is operating in partner-direct mode. Pay your selected logistics partner directly. This retired endpoint cannot collect freight payments. For any historical payment with unclear status, contact KRIM support for reconciliation; do not submit a second payment.",
  }), {
    status: 410,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
});