(function () {
  "use strict";
  var root = document.getElementById("appContent");
  if (!root) return;
  var labels = {
    users: ["IDENTITY & ACCESS", "Review organization membership, role assignment, invitations and access-review evidence. This view never grants permissions from the browser."],
    quotes: ["COMMERCIAL CONTROL", "Review rate coverage and quote readiness. Quote creation, acceptance and pricing changes remain server-authorized."],
    finance: ["FINANCE & TREASURY", "Review payment visibility and reconciliation readiness. This workspace does not initiate payouts or modify ledger entries."],
    analytics: ["ENTERPRISE INTELLIGENCE", "Operational indicators are calculated only from records the signed-in account can read."],
    documents: ["DOCUMENT CONTROL", "Review secure evidence and document workflow readiness. Private files require authorized storage policies."],
    integrations: ["INTEGRATION GOVERNANCE", "Review external-system ownership, event delivery and connection health; no integration is marked live without evidence."],
    "ai-activity": ["AI OVERSIGHT", "Review AI execution provenance, human review and safety evidence."],
    recommendations: ["DECISION SUPPORT", "Recommendations must include source evidence, owner and a recorded human disposition."],
    approvals: ["CONTROLLED APPROVALS", "Approval actions require server-side role checks, separation of duties and an audit trail."],
    automation: ["WORKFLOW OBSERVABILITY", "Inspect execution freshness, failures, retries and recovery ownership."],
    pause: ["EMERGENCY GOVERNANCE", "Emergency controls are intentionally read-only until a protected, audited backend control is connected."],
    memory: ["INSTITUTIONAL KNOWLEDGE", "Maintain approved operating standards, decisions, owners and review dates."]
  };
  function el(tag, cls, text) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text !== undefined && text !== null) n.textContent = text;
    return n;
  }
  function card(title, value, detail) {
    var n = el("article", "portal-card surface enterprise-live-card");
    n.append(el("span", "enterprise-domain-number", "KRIM"), el("h3", "", title), el("p", "", value), el("small", "", detail));
    return n;
  }
  function table(rows) {
    var wrap = el("div", "data-table-wrap");
    var t = el("table", "data-table");
    var head = el("thead"), hr = el("tr");
    ["Shipment reference", "Origin", "Destination", "Goods", "Status", "Created"].forEach(function (x) { hr.append(el("th", "", x)); });
    head.append(hr);
    var body = el("tbody");
    rows.forEach(function (s) {
      var tr = el("tr");
      [s.id ? "KR-" + s.id : "—", s.pickup_location, s.delivery_location, s.material_goods, s.status || "Unspecified", s.created_at && window.KRIM && window.KRIM.market ? window.KRIM.market.formatDate(s.created_at) : s.created_at].forEach(function (v) { tr.append(el("td", "", v == null ? "—" : String(v))); });
      body.append(tr);
    });
    t.append(head, body); wrap.append(t); return wrap;
  }
  function downloadCsv(rows) {
    var cols = ["id", "pickup_location", "delivery_location", "material_goods", "weight", "truck_type", "status", "created_at"];
    var csv = [cols.join(",")].concat(rows.map(function (r) {
      return cols.map(function (k) { return '"' + String(r[k] == null ? "" : r[k]).replace(/"/g, '""') + '"'; }).join(",");
    })).join("\r\n");
    var a = el("a"); a.href = URL.createObjectURL(new Blob([csv], { type: "text/csv;charset=utf-8" })); a.download = "krim-enterprise-shipments.csv"; a.click(); URL.revokeObjectURL(a.href);
  }
  async function showShipments() {
    root.replaceChildren(el("span", "eyebrow", "GLOBAL ENTERPRISE OPERATIONS · SHIPMENT CONTROL"), el("h1", "", "Shipment control tower"), el("p", "muted", "Live shipment records returned by the existing authenticated KRIM data service. Results remain subject to backend row-level access rules."));
    var status = el("p", "muted", "Connecting to authorized shipment data…");
    root.append(status);
    try {
      if (!window.KRIM || !window.KRIM.api || typeof window.KRIM.api.listShipmentRequests !== "function") throw new Error("Shipment service unavailable");
      var rows = await window.KRIM.api.listShipmentRequests();
      if (!Array.isArray(rows)) rows = [];
      status.remove();
      var counts = {};
      rows.forEach(function (r) { var k = String(r.status || "unspecified").toLowerCase(); counts[k] = (counts[k] || 0) + 1; });
      var summary = el("div", "grid portal-grid enterprise-detail-grid");
      summary.append(card("Visible shipment records", String(rows.length), "Authorized rows returned to this session"), card("Active / in progress", String(rows.filter(function (r) { return !/delivered|cancel|complete/i.test(String(r.status || "")); }).length), "Derived from visible status values"), card("Delivered / completed", String(rows.filter(function (r) { return /delivered|complete/i.test(String(r.status || "")); }).length), "Derived from visible status values"));
      root.append(summary);
      var tools = el("div", "surface enterprise-detail-banner");
      var search = el("input"); search.type = "search"; search.placeholder = "Filter by reference, route, goods or status"; search.setAttribute("aria-label", "Filter shipment records"); search.style.cssText = "width:100%;max-width:540px;min-height:44px;padding:10px 12px;border:1px solid #dfe7f1;border-radius:10px";
      var exportBtn = el("button", "button button--outline", "Export visible rows (CSV)"); exportBtn.type = "button"; exportBtn.style.marginLeft = "10px";
      var resultCount = el("p", "muted", rows.length + " visible records"); resultCount.style.marginBottom = "0";
      tools.append(search, exportBtn, resultCount); root.append(tools);
      var region = el("div"); root.append(region);
      function draw() {
        var q = search.value.trim().toLowerCase();
        var filtered = rows.filter(function (r) { return [r.id, r.pickup_location, r.delivery_location, r.material_goods, r.status].some(function (v) { return String(v == null ? "" : v).toLowerCase().indexOf(q) >= 0; }); });
        resultCount.textContent = filtered.length + " of " + rows.length + " visible records";
        region.replaceChildren(filtered.length ? table(filtered) : el("section", "empty-state", "No matching shipments. Clear the filter or check whether the account has authorized shipment records."));
        exportBtn.disabled = !filtered.length;
        exportBtn.onclick = function () { downloadCsv(filtered); };
      }
      search.addEventListener("input", draw); draw();
      root.append(el("div", "enterprise-integrity-note", "Data integrity: these totals are derived from records visible to the current authenticated session. They are not global network totals."));
    } catch (err) {
      status.textContent = "Shipment data could not be loaded for this account. Check the active session, data access policy and browser network status.";
      root.append(el("div", "enterprise-integrity-note", "No sample records are shown. This page will not bypass organization isolation or invent operational data."));
    }
  }
  function showSection(id) {
    if (id === "shipments") { var currentHeading = root.querySelector("h1"); if (currentHeading && currentHeading.textContent === "Shipment control tower") return true; showShipments(); return true; }
    var spec = labels[id];
    if (!spec || !root.querySelector(".empty-state")) return false;
    root.replaceChildren(el("span", "eyebrow", "GLOBAL ENTERPRISE OPERATIONS · " + spec[0]), el("h1", "", id === "ai-activity" ? "AI activity" : id === "recommendations" ? "Recommendations & evidence" : id === "approvals" ? "Approval queue" : id === "pause" ? "Emergency pause" : id === "memory" ? "Institutional memory" : id.charAt(0).toUpperCase() + id.slice(1)), el("p", "muted", spec[1]));
    var grid = el("div", "grid portal-grid enterprise-detail-grid");
    var items = {
      users: [["Member directory", "Requires organization-scoped membership read"], ["Role and access review", "Server-side permissions remain authoritative"], ["Invitations", "Invite and expiry workflow not connected"]],
      quotes: [["Approved rate cards", "Approved, effective-dated rates required"], ["Quote lifecycle", "Create, review and accept actions not exposed here"], ["Commercial approvals", "Threshold rules must be enforced server-side"]],
      finance: [["Payments", "Read-only reconciliation view not connected"], ["Receivables and invoices", "Authorized finance data source required"], ["Partner settlements", "No payout is triggered from this page"]],
      analytics: [["Service reliability", "Needs verified milestone definitions"], ["Spend and conversion", "Requires joined, authorized commercial records"], ["Data freshness", "Source timestamps must be measured"]],
      documents: [["Document register", "Private metadata and access checks required"], ["Secure evidence", "No file upload is claimed here"], ["Version history", "Review and retention rules required"]],
      integrations: [["Connection registry", "Owner, environment and scope required"], ["Webhook delivery", "Retries and duplicate protection required"], ["Health checks", "Live status requires observed checks"]],
      "ai-activity": [["Execution registry", "Protected execution logs required"], ["Human review", "Reviewer and override rationale required"], ["Quality evaluation", "Evaluation records required"]],
      recommendations: [["Recommendation register", "Authorized source records required"], ["Evidence review", "Source links and freshness required"], ["Decision outcomes", "Audited accept, reject and defer actions required"]],
      approvals: [["Pending approvals", "Queue source not connected"], ["Separation of duties", "Requester/approver checks must be server-side"], ["Decision history", "Actor, time and rationale required"]],
      automation: [["Execution history", "Workflow log source not connected"], ["Failure and retry review", "Idempotent retry controls required"], ["Service objectives", "Freshness and alert thresholds not configured"]],
      pause: [["Incident register", "Protected incident source not connected"], ["Emergency pause", "No pause action is exposed until secured"], ["Recovery validation", "Authorized approval and audit required"]],
      memory: [["Decision register", "Versioned records not connected"], ["Operating runbooks", "Owners and review cadence required"], ["Lessons learned", "Corrective actions and incident links required"]]
    }[id] || [];
    items.forEach(function (item, i) { grid.append(card(item[0], item[1], "Capability readiness · " + String(i + 1).padStart(2, "0"))); });
    root.append(grid);
    var note = el("div", "enterprise-integrity-note"); note.append(el("strong", "", "Governed by design"), el("p", "", "This section is explicit about connected services versus outstanding integrations. No fake records, permissions or operational actions are presented as live.")); root.append(note);
    return true;
  }
  var pending = false;
  var observer = new MutationObserver(function () {
    if (pending) return; pending = true;
    setTimeout(function () { pending = false; if (location.hash && location.hash !== "#overview") showSection(location.hash.slice(1)); }, 80);
  });
  observer.observe(root, { childList: true, subtree: true });
  window.addEventListener("hashchange", function () { setTimeout(function () { if (location.hash && location.hash !== "#overview") showSection(location.hash.slice(1)); }, 100); });
})();