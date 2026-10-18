/**
 * KRIM Support Runtime
 * Browser-only prototype helpers for support pages.
 * No message dispatch, live status checks, backend writes, refunds, or insurer notifications occur here.
 */
(function () {
  "use strict";
  const STORAGE_KEY = "krim_support_records_v1";
  const $ = (id) => document.getElementById(id);
  const form = $("support-form");
  const result = $("support-result") || $("ticket-result");
  const page = document.body.dataset.supportPage || "";
  const readRecords = () => {
    try { const value = JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]"); return Array.isArray(value) ? value : []; }
    catch (_) { return []; }
  };
  const writeRecords = (records) => localStorage.setItem(STORAGE_KEY, JSON.stringify(records));
  const say = (message) => { if (result) result.textContent = message; };
  const safe = (value) => String(value || "").trim();
  const id = () => "KRIM-SUP-" + new Date().toISOString().slice(0,10).replace(/-/g,"") + "-" + Math.random().toString(36).slice(2,7).toUpperCase();
  const format = (record) => [
    "Reference: " + record.id,
    "Type: " + record.type,
    "Status: " + record.status,
    "Priority: " + (record.priority || "P3 — Standard"),
    "Created: " + record.createdAt,
    "Subject: " + (record.subject || record.category || record.reference || "Support request"),
    record.description ? "Details: " + record.description : ""
  ].filter(Boolean).join("\n");
  const renderHistory = (statusFilter) => {
    const records = readRecords().filter(r => !statusFilter || statusFilter === "All statuses" || r.status === statusFilter);
    say(records.length ? records.slice().reverse().map(format).join("\n\n──────────────\n\n") : "No matching support records are saved in this browser yet.");
  };
  const knowledge = [
    ["Shipment tracking","Use the shipment reference provided in your booking and review the latest event timestamp. If updates stop, open a ticket with the reference and last known location."],
    ["Quotes and bookings","Confirm route, cargo details, transport mode, pickup window, and quote validity before accepting a quote."],
    ["Documents and customs","Use the relevant shipment reference and ensure documents are current. Do not upload sensitive documents to an unapproved channel."],
    ["Payments and invoices","Keep your invoice or payment reference. Never share passwords, OTPs, or full card details with support."],
    ["Claims and damage","Record when the issue was discovered, cargo condition, quantities, and evidence availability. Follow applicable claim deadlines and insurer instructions."],
    ["Partner onboarding","Prepare company and compliance details and submit sensitive documents only through verified secure workflows."],
    ["Account access","Use the official recovery workflow. Support should never ask for your password or one-time passcode."]
  ];
  if (form) form.addEventListener("submit", function (event) {
    event.preventDefault();
    const data = Object.fromEntries(new FormData(form).entries());
    if (page === "help-centre" || page === "knowledge-base") {
      const query = safe(data.q).toLowerCase();
      const matches = knowledge.filter(([title, body]) => (title + " " + body).toLowerCase().includes(query));
      say((matches.length ? matches : knowledge).map(([title, body]) => title + "\n" + body).join("\n\n"));
      return;
    }
    if (page === "ticket-history") { renderHistory(data.status); return; }
    if (page === "service-status") {
      say("Live monitoring is not connected. No current uptime or incident state can be verified from this page. Selected service: " + (data.service || "All services") + ".");
      return;
    }
    const records = readRecords();
    if (page === "ticket-details") {
      const record = records.find(r => r.id.toLowerCase() === safe(data.ticketId).toLowerCase());
      say(record ? format(record) : "No matching ticket found in this browser's local records. Records are not yet synced to Supabase.");
      return;
    }
    if (page === "resolution-confirmation" || page === "priority-escalation") {
      const record = records.find(r => r.id.toLowerCase() === safe(data.ticketId).toLowerCase());
      if (!record) { say("No matching local ticket was found. Create a ticket first or check the exact reference."); return; }
      if (page === "priority-escalation") {
        record.status = "Escalated";
        record.escalationReason = safe(data.reason);
      } else {
        record.status = safe(data.outcome) || "Feedback received";
        record.resolutionFeedback = safe(data.description);
      }
      record.updatedAt = new Date().toISOString();
      writeRecords(records);
      say("Local record updated only. No support team was notified and no operational decision was made.\n\n" + format(record));
      return;
    }
    const reference = safe(data.reference || data.shipmentRef || "");
    const description = safe(data.description || data.reason || "");
    const subject = safe(data.subject || data.category || page.replace(/-/g," "));
    if (!description && !subject) { say("Please complete the required fields."); return; }
    const record = {
      id: id(), type: page, category: safe(data.category), subject,
      reference, shipmentRef: safe(data.shipmentRef), description,
      priority: safe(data.priority) || "P3 — Standard",
      status: page.includes("claim") || page.includes("dispute") || page.includes("complaint") ? "Review requested" : "Open",
      createdAt: new Date().toISOString(), storage: "local-browser-only"
    };
    records.push(record);
    writeRecords(records);
    form.reset();
    say("Saved locally in this browser. Reference: " + record.id + "\nStatus: " + record.status + "\n\nThis has NOT been sent to KRIM support or any external party. Backend integration is still required.\n\n" + format(record));
  });
  console.info("[KRIM Support] Browser prototype ready. Backend dispatch and live monitoring are not connected.");
})();