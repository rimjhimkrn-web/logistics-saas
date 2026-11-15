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

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest)).map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return respond({ error: "Method not allowed" }, 405);

  try {
    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !serviceKey) return respond({ error: "Tracking service is temporarily unavailable." }, 503);

    const body = await req.json().catch(() => null);
    let token = typeof body?.tracking_number === "string" ? body.tracking_number.trim().toUpperCase() : "";
    if (token.startsWith("KRIM-")) token = token.slice(5);
    if (!/^[A-F0-9]{32}$/.test(token)) {
      return respond({ error: "Enter the secure KRIM tracking reference shown in your shipment details." }, 400);
    }

    const db = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: shipment, error: lookupError } = await db
      .from("krim_shipments")
      .select("id,shipment_number,status,estimated_delivery_at,actual_delivery_at,origin_location_id,destination_location_id,last_known_location_id,created_at,public_tracking_token")
      .eq("public_tracking_token", token)
      .maybeSingle();

    if (lookupError) {
      console.error("Tracking lookup query failed", lookupError.message);
      return respond({ error: "Tracking is temporarily unavailable. Please try again later." }, 503);
    }
    if (!shipment) return respond({ error: "No shipment was found for that secure tracking reference." }, 404);

    const [{ data: eventRows }, { data: activeSessions, error: sessionsError }] = await Promise.all([
      db.from("krim_tracking_events").select("event_type,event_time,location_id")
        .eq("shipment_id", shipment.id).neq("source_type", "gps").neq("event_type", "gps_position")
        .order("event_time", { ascending: false }).limit(10),
      db.from("krim_driver_tracking_sessions").select("id,started_at,partner_assignment_id,driver_assignment_id,shipment_leg_id,organization_id,user_id,platform,consent_notice_text,consent_notice_sha256")
        .eq("shipment_id", shipment.id).eq("status", "active")
        .order("started_at", { ascending: false }).limit(20),
    ]);
    if (sessionsError) console.error("Active GPS consent sessions unavailable", sessionsError.message);
    const events = eventRows || [];
    const terminalShipment = ["delivered", "cancelled", "closed", "completed"].includes(String(shipment.status || "").toLowerCase());
    const sessionCandidates = sessionsError || terminalShipment ? [] : (activeSessions || []);
    const authorizedSessions = (await Promise.all(sessionCandidates.map(async (session) => {
      if (!session.partner_assignment_id || !session.driver_assignment_id) return null;
      const [partnerResult, driverResult, membershipResult, organizationResult, profileResult] = await Promise.all([
        db.from("krim_shipment_partner_assignments").select("id,status,partner_organization_id,shipment_leg_id")
          .eq("id", session.partner_assignment_id).eq("shipment_id", shipment.id).maybeSingle(),
        db.from("krim_driver_assignments").select("id,status,user_id,organization_id,shipment_leg_id")
          .eq("id", session.driver_assignment_id).eq("shipment_id", shipment.id).maybeSingle(),
        db.from("krim_organization_members").select("user_id")
          .eq("organization_id", session.organization_id).eq("user_id", session.user_id)
          .eq("role", "driver").eq("status", "active").maybeSingle(),
        db.from("krim_organizations").select("id")
          .eq("id", session.organization_id).eq("status", "active").maybeSingle(),
        db.from("krim_driver_profiles").select("id,licence_number,verification_status")
          .eq("user_id", session.user_id).eq("organization_id", session.organization_id).maybeSingle(),
      ]);
      const lookupError = partnerResult.error || driverResult.error || membershipResult.error || organizationResult.error || profileResult.error;
      if (lookupError) {
        console.error("Tracking assignment authorization lookup failed", lookupError.message);
        return null;
      }
      const partnerActive = partnerResult.data
        && partnerResult.data.partner_organization_id === session.organization_id
        && partnerResult.data.shipment_leg_id === session.shipment_leg_id
        && ["accepted", "active", "in_progress", "assigned"].includes(String(partnerResult.data.status || "").toLowerCase());
      const driverInTransit = driverResult.data
        && driverResult.data.user_id === session.user_id
        && driverResult.data.organization_id === session.organization_id
        && driverResult.data.shipment_leg_id === session.shipment_leg_id
        && String(driverResult.data.status || "").toLowerCase() === "in_transit";
      const driverVerified = profileResult.data
        && ["verified", "approved"].includes(String(profileResult.data.verification_status || "").toLowerCase())
        && Boolean(String(profileResult.data.licence_number || "").trim());
      const consentText = String(session.consent_notice_text || "");
      const consentHash = String(session.consent_notice_sha256 || "");
      const consentValid = Boolean(consentText.trim())
        && /^[0-9a-f]{64}$/.test(consentHash)
        && await sha256Hex(consentText) === consentHash;
      const membershipActive = Boolean(membershipResult.data && organizationResult.data);
      const nativePlatform = session.platform === "android" || session.platform === "ios";
      return partnerActive && driverInTransit && driverVerified && membershipActive && nativePlatform && consentValid ? session : null;
    }))).filter((session): session is NonNullable<typeof session> => session !== null);
    const gpsCandidates = authorizedSessions.length === 0 ? [] : await Promise.all(
      authorizedSessions.map(async (session) => {
        const { data, error } = await db.from("krim_tracking_events")
          .select("event_time,latitude,longitude,metadata")
          .eq("shipment_id", shipment.id).eq("source_type", "gps").eq("event_type", "gps_position")
          .filter("metadata->>tracking_session_id", "eq", session.id)
          .lte("event_time", new Date(Date.now() + 60000).toISOString())
          .not("latitude", "is", null).not("longitude", "is", null)
          .order("event_time", { ascending: false }).limit(1).maybeSingle();
        if (error) console.error("Session-scoped GPS position unavailable", error.message);
        return data;
      })
    );
    const gpsRow = gpsCandidates.filter(
      (row): row is NonNullable<typeof row> => row !== null
    ).sort(
      (a, b) => new Date(b.event_time).getTime() - new Date(a.event_time).getTime()
    )[0] || null;
    const gpsAgeMs = gpsRow ? Date.now() - new Date(gpsRow.event_time).getTime() : null;
    const sessionAgeMs = authorizedSessions[0] ? Date.now() - new Date(authorizedSessions[0].started_at).getTime() : null;
    const gpsSharingStatus = sessionsError ? "unavailable"
      : terminalShipment ? "completed"
      : !authorizedSessions.length ? "inactive"
      : gpsAgeMs === null ? (sessionAgeMs !== null && sessionAgeMs <= 120000 ? "starting" : "stale")
      : gpsAgeMs <= 120000 ? "active"
      : gpsAgeMs <= 900000 ? "delayed" : "stale";
    const locationIds = [...new Set([
      shipment.origin_location_id, shipment.destination_location_id,
      shipment.last_known_location_id, ...events.map((e) => e.location_id),
    ].filter((id) => id !== null && id !== undefined))];

    let locations = new Map<number, string>();
    if (locationIds.length) {
      const { data: locationRows } = await db.from("krim_locations")
        .select("id,city,state_region").in("id", locationIds);
      if (locationRows) locations = new Map(locationRows.map((loc) => [
        Number(loc.id), [loc.city, loc.state_region].filter(Boolean).join(", ") || "Location update",
      ]));
    }

    return respond({
      success: true,
      tracking_number: "KRIM-" + shipment.public_tracking_token,
      shipment_number: shipment.shipment_number,
      status: shipment.status || "unknown",
      origin: locations.get(Number(shipment.origin_location_id)) ?? null,
      destination: locations.get(Number(shipment.destination_location_id)) ?? null,
      current_location: locations.get(Number(shipment.last_known_location_id)) ?? null,
      created_at: shipment.created_at,
      estimated_delivery_at: shipment.estimated_delivery_at,
      delivered_at: shipment.actual_delivery_at,
      gps_sharing_status: gpsSharingStatus,
      latest_position: !terminalShipment && authorizedSessions.length > 0 && gpsRow && gpsAgeMs !== null && gpsAgeMs >= -60000 && gpsAgeMs <= 900000 ? {
        latitude: Number(gpsRow.latitude),
        longitude: Number(gpsRow.longitude),
        recorded_at: gpsRow.event_time,
        accuracy_m: gpsRow.metadata?.accuracy_m ?? null,
        freshness: (Date.now() - new Date(gpsRow.event_time).getTime()) <= 120000 ? "live"
          : (Date.now() - new Date(gpsRow.event_time).getTime()) <= 900000 ? "recent" : "stale",
      } : null,
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