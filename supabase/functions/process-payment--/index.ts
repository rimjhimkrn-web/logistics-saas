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
    message: "Use the canonical KRIM Razorpay checkout. Payment success must be established only by verify-razorpay-payment and the canonical payment verification receipt. Do not retry a payment through another endpoint when its status is unclear.",
  }), {
    status: 410,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
});