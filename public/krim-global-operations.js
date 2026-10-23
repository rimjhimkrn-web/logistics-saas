/* KRIM Global Operations: authenticated Supabase persistence; database RLS owns access control. */
(function () {
  "use strict";
  const allowed = new Set(["network-coverage","trade-lane-management","trade-document-packs","landed-cost","customer-support-cases","cargo-claims-disputes","carrier-contracts","fleet-maintenance","order-fulfilment","reverse-logistics","market-regulatory-config","business-continuity"]);
  const parts = location.pathname.split("/").filter(Boolean);
  const moduleKey = (parts[parts.length - 1] || "").replace(/\.html?$/i, "");
  if (!allowed.has(moduleKey)) return;
  const db = window.KRIM_SUPABASE || window.supabaseClient;
  const form = document.getElementById("recordForm"), body = document.getElementById("recordBody");
  const search = document.getElementById("search"), count = document.getElementById("rowCount");
  const toast = document.getElementById("toast"), table = document.getElementById("recordTable");
  const fields = form ? [...form.querySelectorAll('input:not([type="checkbox"]):not([type="hidden"])')] : [];
  let user = null, records = [], busy = false;
  const show = message => { if (!toast) return; toast.textContent = message; toast.classList.add("show"); setTimeout(() => toast.classList.remove("show"), 5000); };
  function empty(message, signIn) {
    if (!body) return;
    body.replaceChildren();
    const row = document.createElement("tr"), cell = document.createElement("td");
    cell.colSpan = (table && table.querySelectorAll("thead th").length) || 5;
    cell.className = "empty"; cell.append(document.createTextNode(message));
    if (signIn) {
      cell.append(document.createTextNode(" "));
      const a = document.createElement("a");
      a.href = window.krimPath ? window.krimPath("auth/login.html") : "../../auth/login.html";
      a.textContent = "Sign in to KRIM"; cell.appendChild(a);
    }
    row.appendChild(cell); body.appendChild(row);
  }
  function cell(row, value, status) {
    const td = document.createElement("td"); td.textContent = value == null ? "" : String(value);
    if (status) { const badge = document.createElement("span"); badge.className = "status review"; badge.textContent = td.textContent || "Unspecified"; td.textContent = ""; td.appendChild(badge); }
    row.appendChild(td);
  }
  function render() {
    if (!body) return;
    const q = (search && search.value || "").trim().toLowerCase();
    const filtered = records.filter(r => ((r.record_data && r.record_data.fields) || []).some(f => String(f.value || "").toLowerCase().includes(q)));
    if (count) count.textContent = records.length + " saved record" + (records.length === 1 ? "" : "s");
    body.replaceChildren();
    if (!filtered.length) { empty(records.length ? "No saved records match this search." : "No records saved for this module yet.", false); return; }
    filtered.forEach(r => {
      const tr = document.createElement("tr"), fs = (r.record_data && r.record_data.fields) || [];
      fs.forEach((f, i) => cell(tr, f.value, /status/i.test(String(f.label || "")) || (i === fs.length - 1 && /status/i.test(String(f.label || ""))));
      cell(tr, r.created_at ? new Date(r.created_at).toLocaleString() : "", false); body.appendChild(tr);
    });
  }
  async function load() {
    const res = await db.from("krim_global_ops_records").select("id,module_key,record_data,created_at").eq("module_key", moduleKey).order("created_at", {ascending:false}).limit(200);
    if (res.error) throw res.error; records = res.data || []; render();
  }
  function enable(on) { if (form) [...form.querySelectorAll("button,input")].forEach(el => el.disabled = !on); }
  async function init() {
    if (!db || !form || !body) { empty("KRIM data connection could not initialize. Refresh the page or contact support.", false); enable(false); return; }
    enable(false);
    try {
      const s = await db.auth.getSession(); if (s.error) throw s.error;
      user = s.data && s.data.session && s.data.session.user;
      if (!user) { empty("Sign in to view or save operational records. Nothing is stored in this browser preview.", true); show("Sign-in required. No local-only records will be accepted."); return; }
      await load(); enable(true); show("Connected to KRIM Supabase. Saved records are loaded for this signed-in account.");
    } catch (e) { console.error("KRIM Global Operations load failed", e); empty("Could not load saved records. Check connection/access, then refresh.", false); show("Supabase connection failed. No changes were saved."); }
  }
  if (form) form.addEventListener("submit", async e => {
    e.preventDefault(); if (!user || busy || !form.reportValidity()) return;
    const data = fields.map((f, i) => ({label:f.placeholder || f.name || ("Field " + (i + 1)), value:f.value.trim()}));
    if (data.some(f => !f.value)) { show("Complete all required fields before saving."); return; }
    busy = true; enable(false);
    try {
      const res = await db.from("krim_global_ops_records").insert({user_id:user.id,module_key:moduleKey,record_data:{fields:data}}).select("id,module_key,record_data,created_at").single();
      if (res.error) throw res.error;
      records.unshift(res.data); render(); form.reset(); show("Record saved to KRIM Supabase.");
    } catch (err) { console.error("KRIM Global Operations save failed", err); show("Save failed. No record was added to the list; check access and retry."); }
    finally { busy = false; enable(Boolean(user)); }
  });
  if (search) search.addEventListener("input", render);
  const clear = document.getElementById("clearSearch");
  if (clear) clear.addEventListener("click", () => { if (search) search.value = ""; render(); });
  const exportBtn = document.getElementById("exportBtn");
  if (exportBtn) exportBtn.addEventListener("click", () => {
    if (!records.length) { show("There are no saved records to export."); return; }
    const headers = [...table.querySelectorAll("thead th")].map(th => th.textContent.trim());
    const rows = records.map(r => [...(((r.record_data && r.record_data.fields) || []).map(f => f.value || "")), r.created_at ? new Date(r.created_at).toLocaleString() : ""]);
    const csv = [headers,...rows].map(row => row.map(v => '"' + String(v == null ? "" : v).replace(/"/g,'""') + '"').join(",")).join("\r\n");
    const url = URL.createObjectURL(new Blob([csv],{type:"text/csv;charset=utf-8;"})), a = document.createElement("a");
    a.href=url; a.download="krim-"+moduleKey+"-records.csv"; document.body.appendChild(a); a.click(); a.remove(); URL.revokeObjectURL(url); show("Exported saved Supabase records.");
  });
  init();
})();