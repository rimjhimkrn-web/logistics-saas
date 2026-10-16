import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
};

function respond(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return respond({ error: "Method not allowed" }, 405);

  try {
    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !serviceKey) return respond({ error: "Tracking service is temporarily unavailable." }, 503);

    const body = await req.json().catch(() => null);
    const trackingNumber = typeof body?.tracking_number === "string" ? body.tracking_number.trim().toUpperCase() : "";
    if (trackingNumber.length < 8 || trackingNumber.length > 100 || !/^[A-Z0-9-]+$/.test(trackingNumber)) {
      return respond({ error: "Enter the tracking number provided by KRIM." }, 400);
    }

    const db = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: legacy, error: lookupError } = await db
      .from("shipment_requests")
      .select("tracking_number,status,created_at,delivered_at,krim_shipment_id,pickup_location,delivery_location")
      .eq("tracking_number", trackingNumber)
      .maybeSingle();

    if (lookupError) {
      console.error("Tracking lookup query failed", lookupError.message);
      return respond({ error: "Tracking is temporarily unavailable. Please try again later." }, 503);
    }
    if (!legacy) return respond({ error: "No shipment was found for that tracking number." }, 404);

    let shipment: Record<string, unknown> | null = null;
    let events: Array<Record<string, unknown>> = [];
    if (legacy.krim_shipment_id) {
      const { data } = await db.from("krim_shipments")
        .select("shipment_number,status,estimated_delivery_at,actual_delivery_at")
        .eq("id", legacy.krim_shipment_id).maybeSingle();
      if (data) shipment = data as Record<string, unknown>;

      const { data: eventRows } = await db.from("krim_tracking_events")
        .select("event_type,event_time,location_id")
        .eq("shipment_id", legacy.krim_shipment_id)
        .order("event_time", { ascending: false }).limit(10);
      if (eventRows) events = eventRows as Array<Record<string, unknown>>;
    }

    const locationIds = [...new Set(events.map((e) => e.location_id).filter((id) => id !== null))];
    let locations = new Map<number, string>();
    if (locationIds.length) {
      const { data: locationRows } = await db.from("krim_locations")
        .select("id,city,state_region").in("id", locationIds);
      if (locationRows) locations = new Map(locationRows.map((loc) => [
        Number(loc.id), [loc.city, loc.state_region].filter(Boolean).join(", ") || "Location update",
      ]));
    }

    // Deliberately omit names, phone numbers, full addresses, internal notes, and event metadata.
    return respond({
      success: true,
      tracking_number: legacy.tracking_number,
      shipment_number: shipment?.shipment_number ?? null,
      status: shipment?.status ?? legacy.status ?? "unknown",
      origin: legacy.pickup_location ?? null,
      destination: legacy.delivery_location ?? null,
      created_at: legacy.created_at ?? null,
      estimated_delivery_at: shipment?.estimated_delivery_at ?? null,
      delivered_at: shipment?.actual_delivery_at ?? legacy.delivered_at ?? null,
      events: events.map((event) => ({
        event_type: event.event_type,
        event_time: event.event_time,
        location: event.location_id === null ? null : locations.get(Number(event.location_id)) ?? null,
      })),
    });
  } catch (error) {
    console.error("Public tracking handler failed", error instanceof Error ? error.message : "unknown");
    return respond({ error: "Tracking is temporarily unavailable. Please try again later." }, 500);
  }
});