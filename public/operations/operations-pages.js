/* KRIM Operations pages — shared, read-only live shipment workbench.
 * Data is fetched from Supabase under the current user's session and RLS.
 * No simulated shipment, carrier, route, or milestone records are created.
 */
(function () {
  "use strict";
  const cfg = window.KRIM_CONFIG || {};
  const base = cfg.platform?.basePath || (location.pathname.startsWith("/logistics-saas/") ? "/logistics-saas/" : "/");
  const page = document.body.dataset.operationsPage || "operations-dashboard";
  const pages = {
    "operations-dashboard": ["Operations Dashboard", "A live overview of shipment operations and execution exceptions.", "Operations overview"],
    "dispatch-queue": ["Dispatch Queue", "Review shipments that may need dispatch attention. Confirm assignments in the authorized workflow.", "Dispatch work queue"],
    "load-planning": ["Load Planning", "Review shipment requirements and plan load consolidation with verified capacity data.", "Load planning"],
    "carrier-matching": ["Carrier Matching", "Review shipment records before matching them with eligible, verified carrier capacity.", "Carrier matching"],
    "route-planner": ["Route Planner", "Review shipment origin and destination details before selecting an approved route.", "Route planning"],
    "vehicle-capacity": ["Vehicle Capacity", "Use shipment requirements to review capacity needs. Live vehicle capacity requires connected fleet data.", "Capacity review"],
    "trip-monitoring": ["Trip Monitoring", "Monitor shipment records and operational status. Live GPS telemetry is shown only when a real source is connected.", "Trip monitoring"],
    "dispatch-confirmation": ["Dispatch Confirmation", "Review shipment records before confirming dispatch in the authorized backend workflow.", "Dispatch confirmation"],
    "pickup-monitoring": ["Pickup Monitoring", "Review shipment status for pickup follow-up. Pickup events are not inferred when absent from backend data.", "Pickup monitoring"],
    "delivery-monitoring": ["Delivery Monitoring", "Review shipment status for delivery follow-up. Delivery completion must be confirmed by an authorized workflow.", "Delivery monitoring"],
    "missed-milestones": ["Missed Milestones", "Identify records with available status and timestamp data; missing milestone timestamps are not fabricated.", "Milestone review"],
    "late-shipment-management": ["Late Shipment Management", "Review records for delay follow-up. This page does not invent ETA or lateness predictions.", "Delay review"],
    "rerouting-approvals": ["Rerouting Approvals", "Review shipments before a reroute is approved. No route changes are submitted by this read-only workbench.", "Reroute review"],
    "incident-management": ["Incident Management", "Review shipment records and use the existing exception workflow to record verified incidents.", "Incident review"],
    "control-room-handover": ["Control Room Handover", "Review current operational records before completing a handover through an authorized workflow.", "Handover review"],
    "service-level-monitoring": ["Service Level Monitoring", "Review live shipment status. SLA calculations require configured service-level rules and verified event timestamps.", "Service-level review"],
    "capacity-planning": ["Capacity Planning", "Review current shipment volume. Forecasts require verified capacity, demand, and historical data.", "Capacity planning"],
    "operations-reports": ["Operations Reports", "Search and inspect the shipment records your account is permitted to access.", "Operational report"]
  };
  const current = pages[page] || pages["operations-dashboard"];
  const esc = (v) => String(v ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const $ = (id) => document.getElementById(id);
  function sessionToken() {
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (!key || !key.startsWith("sb-") || !key.includes("auth-token")) continue;
      try {
        const data = JSON.parse(localStorage.getItem(key));
        if (data?.access_token) return data.access_token;
      } catch (_) {}
    }
    return "";
  }
  function renderRows(rows) {
    const query = ($("search")?.value || "").trim().toLowerCase();
    const status = ($("status-filter")?.value || "").toLowerCase();
    const filtered = rows.filter(row => {
      const text = Object.values(row).map(v => typeof v === "object" ? JSON.stringify(v) : String(v ?? "")).join(" ").toLowerCase();
      const s = String(row.status ?? row.shipment_status ?? "").toLowerCase();
      return (!query || text.includes(query)) && (!status || s === status || s.includes(status));
    });
    $("record-count").textContent = String(filtered.length);
    $("table-body").innerHTML = filtered.length ? filtered.map(row => {
      const id = row.shipment_number || row.reference_number || row.public_tracking_number || row.id || "—";
      const origin = row.origin_name || row.origin || row.origin_location || row.origin_country || "—";
      const destination = row.destination_name || row.destination || row.destination_location || row.destination_country || "—";
      const state = row.status || row.shipment_status || "Unspecified";
      const mode = row.transport_mode || row.mode || "—";
      const updated = row.updated_at || row.created_at || "—";
      return "<tr><td><strong>"+esc(id)+"</strong></td><td>"+esc(origin)+"</td><td>"+esc(destination)+"</td><td><span class='status'>"+esc(state)+"</span></td><td>"+esc(mode)+"</td><td>"+esc(updated === "—" ? updated : new Date(updated).toLocaleString())+"</td></tr>";
    }).join("") : "<tr><td colspan='6' class='empty'>No records match this view.</td></tr>";
  }
  async function load() {
    const cfgSupabase = cfg.supabase || {};
    const url = cfgSupabase.url || cfg.SUPABASE_URL;
    const key = cfgSupabase.publishableKey || cfg.SUPABASE_ANON_KEY;
    const token = sessionToken();
    if (!url || !key) {
      $("connection-state").textContent = "Configuration unavailable";
      $("table-body").innerHTML = "<tr><td colspan='6' class='empty'>Supabase configuration was not found. Check platform/krim-config.js.</td></tr>";
      return;
    }
    if (!token) {
      $("connection-state").textContent = "Sign in required";
      $("table-body").innerHTML = "<tr><td colspan='6' class='empty'>Sign in to view shipment records permitted for your account. <a href='"+esc(base+"auth/login.html")+"'>Sign in</a></td></tr>";
      return;
    }
    $("connection-state").textContent = "Connecting…";
    try {
      const response = await fetch(url.replace(/\/$/, "") + "/rest/v1/krim_shipments?select=*&order=created_at.desc&limit=100", {
        headers: { apikey: key, Authorization: "Bearer " + token, Accept: "application/json" }
      });
      if (response.status === 401 || response.status === 403) throw new Error("Your session or permissions do not allow this data. Sign in again or contact your administrator.");
      if (!response.ok) throw new Error("Shipment data could not be loaded (HTTP " + response.status + ").");
      const data = await response.json();
      if (!Array.isArray(data)) throw new Error("The shipment endpoint returned an unexpected response.");
      window.KRIM_OPERATIONS_SHIPMENTS = data;
      $("connection-state").textContent = "Connected · live data";
      $("last-updated").textContent = "Refreshed " + new Date().toLocaleTimeString();
      const statuses = [...new Set(data.map(r => String(r.status || r.shipment_status || "")).filter(Boolean))].sort();
      $("status-filter").innerHTML = "<option value=''>All statuses</option>" + statuses.map(s => "<option value='"+esc(s)+"'>"+esc(s)+"</option>").join("");
      renderRows(data);
    } catch (error) {
      $("connection-state").textContent = "Data unavailable";
      $("table-body").innerHTML = "<tr><td colspan='6' class='empty'>"+esc(error.message || "Unable to load shipment records.")+"</td></tr>";
      $("record-count").textContent = "—";
    }
  }
  document.title = "KRIM Logistics | " + current[0];
  $("page-title").textContent = current[0];
  $("page-description").textContent = current[1];
  $("section-title").textContent = current[2];
  $("refresh").addEventListener("click", load);
  $("search").addEventListener("input", () => renderRows(window.KRIM_OPERATIONS_SHIPMENTS || []));
  $("status-filter").addEventListener("change", () => renderRows(window.KRIM_OPERATIONS_SHIPMENTS || []));
  $("menu-toggle").addEventListener("click", () => $("operations-nav").classList.toggle("open"));
  load();
})();