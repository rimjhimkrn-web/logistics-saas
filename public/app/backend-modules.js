import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = "https://ebltviniygljwwseplph.supabase.co";
const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_8xzZUeubYp_nIxVRWEQdiw_2H4RkHAa";
const supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
});

const page = location.pathname.split("/").pop() || "app-shell.html";
const styles = "mt-6 rounded-2xl border border-slate-700 bg-slate-800 p-5 text-sm text-slate-100 space-y-4";
const field = "w-full rounded-lg border border-slate-600 bg-slate-900 px-3 py-2 text-slate-100";
const btn = "rounded-lg bg-sky-600 px-4 py-2 font-semibold text-white hover:bg-sky-500 disabled:opacity-50";
const label = "block text-xs font-semibold text-slate-300 mb-1";
let root, user, statusEl;

function node(tag, attrs = {}, text = "") {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === "className") el.className = v;
    else if (k.startsWith("on") && typeof v === "function") el.addEventListener(k.slice(2).toLowerCase(), v);
    else el.setAttribute(k, v);
  }
  if (text !== "") el.textContent = text;
  return el;
}
function setStatus(message, bad = false) {
  if (!statusEl) return;
  statusEl.textContent = message;
  statusEl.className = bad ? "text-sm text-rose-300" : "text-sm text-emerald-300";
}
function addStatus(message, bad = false) { setStatus(message, bad); }
function addField(parent, title, name, value, type = "text", options = null) {
  const wrap = node("label", { className: "block min-w-0" });
  wrap.append(node("span", { className: label }, title));
  let input;
  if (options) {
    input = node("select", { name, className: field });
    for (const [v, t] of options) input.append(node("option", { value: v }, t));
    input.value = value;
  } else {
    input = node("input", { name, type, value: value ?? "", className: field, maxlength: "200" });
  }
  wrap.append(input);
  parent.append(wrap);
  return input;
}
function addCheck(parent, title, name, checked) {
  const wrap = node("label", { className: "flex items-center justify-between gap-4 rounded-xl bg-slate-900 p-3" });
  wrap.append(node("span", {}, title));
  const input = node("input", { type: "checkbox", name, className: "h-5 w-5 accent-sky-500" });
  input.checked = Boolean(checked);
  wrap.append(input);
  parent.append(wrap);
  return input;
}
function button(parent, title, handler) {
  const b = node("button", { type: "button", className: btn }, title);
  b.addEventListener("click", async () => {
    b.disabled = true;
    try { await handler(); } catch (e) { setStatus(e?.message || "The request failed.", true); }
    finally { b.disabled = false; }
  });
  parent.append(b);
  return b;
}
function section(title, description = "") {
  const s = node("section", { className: styles });
  s.append(node("h2", { className: "text-lg font-bold" }, title));
  if (description) s.append(node("p", { className: "text-xs text-slate-400" }, description));
  root.append(s);
  return s;
}
function listRows(parent, rows, columns, emptyText) {
  if (!rows?.length) { parent.append(node("p", { className: "text-slate-400 text-xs" }, emptyText)); return; }
  const table = node("div", { className: "space-y-2" });
  for (const row of rows) {
    const item = node("div", { className: "rounded-lg border border-slate-700 bg-slate-900 p-3" });
    for (const [key, title] of columns) {
      const value = row[key] == null ? "—" : (typeof row[key] === "object" ? JSON.stringify(row[key]) : String(row[key]));
      item.append(node("p", { className: "break-words text-xs mb-1" }, title + ": " + value));
    }
    table.append(item);
  }
  parent.append(table);
}
async function logEvent(event_type, details = {}) {
  const { error } = await supabase.from("krim_user_activity_events").insert({
    user_id: user.id, event_type, page_path: location.pathname, details
  });
  if (error) console.warn("KRIM activity log not recorded:", error.message);
}
async function loadPreferences() {
  const { data, error } = await supabase.from("krim_user_app_preferences").select("preferences").eq("user_id", user.id).maybeSingle();
  if (error) throw error;
  return data?.preferences || {};
}
async function savePreferences(prefs, eventType = "preferences_saved") {
  const { error } = await supabase.from("krim_user_app_preferences").upsert({
    user_id: user.id, preferences: prefs, updated_at: new Date().toISOString()
  }, { onConflict: "user_id" });
  if (error) throw error;
  await logEvent(eventType, { keys: Object.keys(prefs) });
  setStatus("Saved to your authenticated KRIM account.");
}
function makeForm(parent) {
  const f = node("form", { className: "grid grid-cols-1 md:grid-cols-2 gap-4" });
  f.addEventListener("submit", e => e.preventDefault());
  parent.append(f);
  return f;
}
async function renderAccount() {
  const s = section("Authenticated account", "Identity comes from Supabase Auth; this panel does not trust demo profile data.");
  listRows(s, [{
    email: user.email, user_id: user.id, created_at: user.created_at,
    last_sign_in_at: user.last_sign_in_at
  }], [["email","Email"],["user_id","User ID"],["created_at","Account created"],["last_sign_in_at","Last sign-in"]], "");
  const prefs = await loadPreferences();
  s.append(node("p", { className: "text-xs text-slate-400" }, "Saved preference record: " + (Object.keys(prefs).length ? "available" : "not created yet")));
  await logEvent("app_opened", { module: "account-overview" });
}
async function renderPreferences() {
  const prefs = await loadPreferences();
  const s = section("Saved preferences", "These values are stored per authenticated user in Supabase, not only in this browser.");
  const f = makeForm(s);
  addField(f,"Theme","theme",prefs.theme || "dark","text",[["dark","Dark"],["light","Light"],["high-contrast","High contrast"]]);
  addField(f,"Currency","currency",prefs.currency || "INR","text",[["INR","INR — Indian Rupee"],["USD","USD — US Dollar"],["EUR","EUR — Euro"],["GBP","GBP — Pound Sterling"],["AED","AED — UAE Dirham"]]);
  addField(f,"Language","language",prefs.language || "en","text",[["en","English"],["hi","Hindi"]]);
  addField(f,"Timezone","timezone",prefs.timezone || "Asia/Kolkata","text",[["Asia/Kolkata","India"],["UTC","UTC"],["Europe/London","London"],["Europe/Berlin","Berlin"],["Asia/Dubai","Dubai"],["America/New_York","New York"]]);
  addField(f,"Telemetry refresh","telemetrySeconds",String(prefs.telemetrySeconds || 60),"number",[["5","5 seconds"],["15","15 seconds"],["60","60 seconds"]]);
  const sound = addCheck(f,"Acoustic alerts","acousticAlerts",prefs.acousticAlerts ?? true);
  const submit = node("button",{type:"submit",className:btn},"Save preferences");
  f.append(submit);
  f.addEventListener("submit", async e => {
    e.preventDefault();
    const data = Object.fromEntries(new FormData(f));
    data.telemetrySeconds = Number(data.telemetrySeconds);
    data.acousticAlerts = sound.checked;
    await savePreferences({...prefs,...data});
  });
}
async function renderAccessibility() {
  const prefs = await loadPreferences(), a = prefs.accessibility || {};
  const s = section("Accessibility preferences", "Saved to your own KRIM preference record. These controls do not claim to change OS-level accessibility settings.");
  const f = makeForm(s);
  const contrast = addCheck(f,"High contrast","highContrast",a.highContrast ?? false);
  const reducedMotion = addCheck(f,"Reduce motion","reducedMotion",a.reducedMotion ?? false);
  const largeText = addCheck(f,"Larger text","largeText",a.largeText ?? false);
  const screenReader = addCheck(f,"Enhanced screen-reader labels","screenReader",a.screenReader ?? true);
  f.append(node("button",{type:"submit",className:btn},"Save accessibility settings"));
  f.addEventListener("submit",async e=>{e.preventDefault();const next={...prefs,accessibility:{highContrast:contrast.checked,reducedMotion:reducedMotion.checked,largeText:largeText.checked,screenReader:screenReader.checked}};await savePreferences(next,"accessibility_saved");});
}
async function renderPrivacy() {
  const prefs = await loadPreferences(), p = prefs.privacy || {};
  const s = section("Privacy and consent controls", "Consent changes are written as dated events; settings here do not automatically delete account data or change legal retention requirements.");
  const f = makeForm(s);
  const marketing=addCheck(f,"Marketing email","marketing_email",p.marketing_email ?? false);
  const analytics=addCheck(f,"Product analytics","product_analytics",p.product_analytics ?? false);
  const personalization=addCheck(f,"Personalization","personalization",p.personalization ?? false);
  f.append(node("button",{type:"submit",className:btn},"Save privacy choices"));
  f.addEventListener("submit",async e=>{
    e.preventDefault();
    const choices={marketing_email:marketing.checked,product_analytics:analytics.checked,personalization:personalization.checked};
    const consentRows = Object.entries(choices).map(([consent_type,granted]) => ({
      user_id:user.id, consent_type, granted, policy_version:"2026-10"
    }));
    const {error:consentError}=await supabase.from("krim_user_consent_events").insert(consentRows);
    if(consentError) throw consentError;
    await savePreferences({...prefs,privacy:choices},"privacy_settings_saved");
    const {data,error}=await supabase.from("krim_user_consent_events").select("consent_type,granted,policy_version,created_at").eq("user_id",user.id).order("created_at",{ascending:false}).limit(12);
    if(error) throw error;
    const history=section("Recent consent history");
    listRows(history,data,[["consent_type","Consent"],["granted","Granted"],["policy_version","Policy version"],["created_at","Recorded at"]],"No consent events found.");
  });
  const {data,error}=await supabase.from("krim_user_consent_events").select("consent_type,granted,policy_version,created_at").eq("user_id",user.id).order("created_at",{ascending:false}).limit(8);
  if(error) throw error;
  listRows(s,data,[["consent_type","Consent"],["granted","Granted"],["created_at","Recorded at"]],"No consent events recorded yet.");
}
async function renderActivity() {
  const s=section("Your activity history","Events shown here are user-scoped records written by KRIM application modules. This is not the privileged platform audit log.");
  const {data,error}=await supabase.from("krim_user_activity_events").select("event_type,page_path,details,created_at").eq("user_id",user.id).order("created_at",{ascending:false}).limit(100);
  if(error) throw error;
  listRows(s,data,[["event_type","Event"],["page_path","Page"],["details","Details"],["created_at","Time"]],"No activity events yet.");
}
async function renderConnectedApps() {
  const s=section("Integration registry","This page reads only integrations the signed-in user is authorized to see. Connecting or revoking credentials requires a separately authorized OAuth/admin workflow; no fake revoke action is offered.");
  const {data,error}=await supabase.from("krim_integrations").select("id,integration_type,provider_name,status,authentication_type,environment,last_sync_at,last_error_at").order("provider_name").limit(100);
  if(error){s.append(node("p",{className:"text-rose-300 text-xs"},"Integration registry is unavailable for your current organization permissions: "+error.message));return;}
  listRows(s,data,[["provider_name","Provider"],["integration_type","Type"],["status","Status"],["authentication_type","Auth"],["environment","Environment"],["last_sync_at","Last sync"],["last_error_at","Last error"]],"No integrations are visible to this account or organization.");
}
async function renderExports() {
  const s=section("Data export requests","Requests are recorded securely. A queued request is not a completed downloadable export; an authorized export worker must process it.");
  const f=makeForm(s);
  const scope=addField(f,"Export scope","export_scope","profile_and_preferences","text",[["profile_and_preferences","Profile and preferences"],["activity_history","Activity history"],["privacy_consent_history","Privacy and consent history"],["account_data_request","Account data request"]]);
  button(f,"Request export",async()=>{
    const {data,error}=await supabase.from("krim_data_export_requests").insert({user_id:user.id,export_scope:scope.value}).select("id,export_scope,status,requested_at").single();
    if(error)throw error;
    await logEvent("export_requested",{request_id:data.id,export_scope:data.export_scope});
    setStatus("Export request recorded as queued. It is not downloadable until a backend worker completes it.");
    await showExportRows(s);
  });
  await showExportRows(s);
}
async function showExportRows(parent){
  const {data,error}=await supabase.from("krim_data_export_requests").select("id,export_scope,status,requested_at,completed_at,failure_code").eq("user_id",user.id).order("requested_at",{ascending:false}).limit(25);
  if(error)throw error;
  const box=node("div",{className:"space-y-2"}); parent.append(node("h3",{className:"font-semibold"},"Your requests")); parent.append(box);
  listRows(box,data,[["export_scope","Scope"],["status","Status"],["requested_at","Requested"],["completed_at","Completed"],["failure_code","Failure code"]],"No export requests.");
}
async function renderOfflineQueue() {
  const s=section("Offline queue","Only safe draft notes and read-request retries are accepted. These entries are stored in Supabase but are not automatically executed as shipment/payment commands.");
  const f=makeForm(s);
  const action=addField(f,"Queue item type","action_type","draft_note","text",[["draft_note","Draft note"],["retry_read_request","Retry read request"]]);
  const payload=addField(f,"Short note / reference","note","","text");
  button(f,"Add queue item",async()=>{
    const note=payload.value.trim();
    if(!note || note.length>500) throw new Error("Enter a note between 1 and 500 characters.");
    const {error}=await supabase.from("krim_offline_queue_items").insert({user_id:user.id,action_type:action.value,payload:{note}});
    if(error)throw error;
    payload.value="";
    await logEvent("offline_item_queued",{action_type:action.value});
    setStatus("Queue item saved. No operational command has been executed.");
    await showQueueRows(s);
  });
  await showQueueRows(s);
}
async function showQueueRows(parent){
  const {data,error}=await supabase.from("krim_offline_queue_items").select("id,action_type,payload,status,created_at").eq("user_id",user.id).order("created_at",{ascending:false}).limit(50);
  if(error)throw error;
  const box=node("div",{className:"space-y-2"}); parent.append(node("h3",{className:"font-semibold"},"Pending queue records"));parent.append(box);
  if(!data.length){box.append(node("p",{className:"text-xs text-slate-400"},"Queue is empty."));return;}
  for(const row of data){
    const item=node("div",{className:"rounded-lg border border-slate-700 bg-slate-900 p-3 flex flex-wrap justify-between gap-3"});
    item.append(node("p",{className:"text-xs break-all"},row.action_type+" · "+(row.payload?.note||"") +" · "+row.created_at));
    button(item,"Remove",async()=>{
      const {error:delError}=await supabase.from("krim_offline_queue_items").delete().eq("id",row.id).eq("user_id",user.id);
      if(delError)throw delError;
      await logEvent("offline_item_removed",{action_type:row.action_type});
      item.remove();setStatus("Queue record removed.");
    });
    box.append(item);
  }
}
async function renderSync() {
  const s=section("Live connection check","Checks the browser network and an authenticated, RLS-protected Supabase query. This is not a claim of global replication health.");
  const result=node("div",{className:"space-y-2 text-xs"});s.append(result);
  const online=navigator.onLine;
  result.append(node("p",{}, "Browser network: "+(online?"online":"offline")));
  const started=performance.now();
  const {data,error}=await supabase.from("krim_user_app_preferences").select("user_id").eq("user_id",user.id).maybeSingle();
  result.append(node("p",{}, "Supabase authenticated query: "+(error?"failed":"success")));
  result.append(node("p",{}, "Round trip: "+Math.round(performance.now()-started)+" ms"));
  if(error) result.append(node("p",{className:"text-rose-300"},error.message));
  else result.append(node("p",{className:"text-slate-400"},data?"Preference row found.":"No preference row yet; backend reachable."));
  button(s,"Refresh status",async()=>{result.replaceChildren();await renderSyncInto(result);});
}
async function renderSyncInto(result){
  result.append(node("p",{},"Browser network: "+(navigator.onLine?"online":"offline")));
  const t=performance.now();const {data,error}=await supabase.from("krim_user_app_preferences").select("user_id").eq("user_id",user.id).maybeSingle();
  result.append(node("p",{},"Supabase authenticated query: "+(error?"failed":"success")));
  result.append(node("p",{},"Round trip: "+Math.round(performance.now()-t)+" ms"));
  if(error)result.append(node("p",{className:"text-rose-300"},error.message));else result.append(node("p",{} ,data?"Preference row found.":"No preference row yet; backend reachable."));
}
async function renderErrors() {
  const s=section("Client error reports","Reports are private to your account. Stack traces and access tokens are intentionally not collected.");
  const f=makeForm(s);
  const severity=addField(f,"Severity","severity","error","text",[["info","Info"],["warning","Warning"],["error","Error"],["critical","Critical"]]);
  const message=addField(f,"Error summary","message","","text");
  button(f,"Submit report",async()=>{
    const msg=message.value.trim();if(!msg||msg.length>1000)throw new Error("Enter an error summary up to 1,000 characters.");
    const {error}=await supabase.from("krim_client_error_reports").insert({user_id:user.id,severity:severity.value,message:msg,page_path:location.pathname,error_name:"User submitted"});
    if(error)throw error;
    await logEvent("error_reported",{severity:severity.value});
    message.value="";setStatus("Error report saved to your private account record.");await showErrorRows(s);
  });
  await showErrorRows(s);
}
async function showErrorRows(parent){
  const {data,error}=await supabase.from("krim_client_error_reports").select("severity,message,page_path,error_name,created_at").eq("user_id",user.id).order("created_at",{ascending:false}).limit(50);
  if(error)throw error;
  const box=node("div",{className:"space-y-2"});parent.append(node("h3",{className:"font-semibold"},"Your reports"));parent.append(box);
  listRows(box,data,[["severity","Severity"],["message","Message"],["page_path","Page"],["created_at","Reported"]],"No error reports.");
}
async function renderHelp() {
  const s=section("Help and support","Opens public resources or records a support request intent. This does not claim that an email or ticket was sent.");
  const links=node("div",{className:"flex flex-wrap gap-3"});
  const docs=node("a",{href:"../../public/contact.html",className:btn,target:"_blank",rel:"noopener"},"Contact KRIM");
  const guides=node("a",{href:"../../public/guides.html",className:btn,target:"_blank",rel:"noopener"},"Guides");
  links.append(docs,guides);s.append(links);
  button(s,"Record that I need support",async()=>{await logEvent("help_opened",{source:"help-centre"});setStatus("Support intent recorded in your activity history. No support ticket or email was created.");});
}
async function render() {
  // Disable legacy mockup buttons so they cannot imply a backend action succeeded.
  document.querySelectorAll("main button").forEach((b) => {
    b.disabled = true;
    b.title = "Legacy preview control. Use the authenticated backend controls below."; 
    b.classList.add("opacity-50", "cursor-not-allowed");
  });
  root = node("div", { className: "max-w-5xl mx-auto px-4 pb-12 w-full" });
  const title = node("h2",{className:"text-xl font-bold"},"KRIM Backend Connection");
  const desc = node("p",{className:"text-xs text-slate-400"},"Authenticated account data · row-level security · server-confirmed results");
  statusEl = node("p",{className:"text-sm text-slate-300","aria-live":"polite"},"Connecting…");
  root.append(title,desc,statusEl);
  const main=document.querySelector("main") || document.body;
  main.append(root);
  const {data:{user:currentUser},error}=await supabase.auth.getUser();
  if(error || !currentUser){
    statusEl.textContent="Sign in required. No demo identity is used, and private backend records are not loaded.";
    const a=node("a",{href:"../../auth/login.html",className:btn},"Sign in to KRIM");
    root.append(a);return;
  }
  user=currentUser;
  statusEl.textContent="Authenticated as "+(user.email || user.id)+". Backend actions are scoped by RLS.";
  try {
    if(page==="account-overview.html") await renderAccount();
    else if(page==="activity-history.html") await renderActivity();
    else if(page==="preferences.html") await renderPreferences();
    else if(page==="connected-applications.html") await renderConnectedApps();
    else if(page==="privacy-controls.html") await renderPrivacy();
    else if(page==="accessibility-settings.html") await renderAccessibility();
    else if(page==="data-export.html") await renderExports();
    else if(page==="help-centre.html") await renderHelp();
    else if(page==="offline-queue.html") await renderOfflineQueue();
    else if(page==="sync-status.html") await renderSync();
    else if(page==="error-centre.html") await renderErrors();
    else statusEl.textContent="Shared backend client ready.";
  } catch(e) {
    console.error("KRIM backend module error:",e);
    setStatus("Backend request failed: "+(e?.message||"unknown error"),true);
  }
}
// Surface rejected form/query promises in the visible module status instead of leaving users with silent failures.
window.addEventListener("unhandledrejection", event => {
  const reason = event.reason;
  const message = reason && reason.message ? reason.message : "An unexpected backend request failed.";
  console.error("KRIM backend module rejected promise:", reason);
  setStatus("Request failed: " + message, true);
  event.preventDefault();
});
window.addEventListener("online", () => setStatus("Browser network restored. Refresh this page's data to retry."));
window.addEventListener("offline", () => setStatus("Browser is offline. Backend changes cannot be confirmed.", true));
document.addEventListener("DOMContentLoaded", () => {
  render().catch(e => {
    console.error("KRIM backend module startup failed:", e);
    setStatus("Module startup failed: " + (e && e.message ? e.message : "unknown error"), true);
  });
});
