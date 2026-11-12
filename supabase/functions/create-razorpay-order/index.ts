import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  return new Response(JSON.stringify({
    success: false,
    error: "This legacy payment endpoint has been retired.",
    code: "PAYMENT_ENDPOINT_RETIRED",
    message: "KRIM is operating in partner-direct mode. Pay your selected logistics partner directly. Do not retry this retired endpoint or submit freight payment to KRIM.",
  }), {
    status: 410,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
});
