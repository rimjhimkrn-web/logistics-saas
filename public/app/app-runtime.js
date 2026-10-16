import { store } from "./app-store.js";

class AppRuntime {
  constructor() { this.isInitialized = false; }

  async init() {
    if (this.isInitialized) return;
    await store.ready;
    this.verifySessionGuard();
    this.bindStoreWithUI();
    this.registerGlobalShortcuts();
    this.enforceRBACGuards();
    this.isInitialized = true;
  }

  verifySessionGuard() {
    if (store.state.user) return;
    document.dispatchEvent(new CustomEvent("krim:auth-required"));
    if (document.getElementById("krim-auth-required-banner")) return;
    const banner = document.createElement("div");
    banner.id = "krim-auth-required-banner";
    banner.className = "mx-4 my-3 rounded-xl border border-amber-500/40 bg-amber-950/40 p-4 text-sm text-amber-100";
    const message = document.createElement("p");
    message.textContent = "Sign in to load your KRIM account and organization data. Protected actions are unavailable until authentication succeeds.";
    const link = document.createElement("a");
    link.href = "../../auth/login.html";
    link.className = "mt-2 inline-block underline";
    link.textContent = "Sign in";
    banner.append(message, link);
    document.body.prepend(banner);
  }

  bindStoreWithUI() {
    const orgNameEl = document.getElementById("current-org-name");
    const currencySelectEl = document.getElementById("app-currency-select");
    const refresh = (state) => {
      if (orgNameEl) orgNameEl.textContent = state.currentOrg?.name || "No organization selected";
      if (currencySelectEl) currencySelectEl.value = state.preferences.currency || "INR";
    };
    refresh(store.state);
    currencySelectEl?.addEventListener("change", (e) => {
      store.setCurrency(e.target.value).catch(error => console.error("[KRIM] Preference save failed:", error));
    });
    store.subscribe((state, key) => {
      if (["ORGANIZATION_CHANGED","CURRENCY_CHANGED","INITIALIZED"].includes(key)) refresh(state);
    });
  }

  registerGlobalShortcuts() {
    window.addEventListener("keydown", e => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        this.toggleCommandPalette();
      }
    });
    document.getElementById("cmd-palette-trigger")?.addEventListener("click", () => this.toggleCommandPalette());
  }

  toggleCommandPalette() {
    const existing = document.getElementById("cmd-palette-modal");
    if (existing) { existing.remove(); return; }
    const modal = document.createElement("div");
    modal.id = "cmd-palette-modal";
    modal.className = "fixed inset-0 z-50 bg-slate-950/80 flex items-start justify-center pt-20 px-4";
    const panel = document.createElement("div");
    panel.className = "bg-slate-900 border border-slate-700 w-full max-w-xl rounded-2xl p-4 space-y-3";
    const title = document.createElement("h2");
    title.className = "text-white font-bold";
    title.textContent = "KRIM Command Palette";
    panel.append(title);
    const links = [
      ["Dashboard","./dashboard-framework.html"],
      ["Global Search","./global-search.html"],
      ["Document Vault","./document-vault.html"],
      ["Organization Switcher","./org-switcher.html"],
      ["Preferences","./preferences.html"],
      ["Activity History","./activity-history.html"]
    ];
    for (const [text, href] of links) {
      const a = document.createElement("a");
      a.href = href; a.textContent = text;
      a.className = "block rounded-lg p-2 text-slate-200 hover:bg-slate-800";
      panel.append(a);
    }
    modal.append(panel);
    modal.addEventListener("click", e => { if (e.target === modal) modal.remove(); });
    window.addEventListener("keydown", function close(e) { if (e.key === "Escape") { modal.remove(); window.removeEventListener("keydown", close); } });
    document.body.append(modal);
  }

  enforceRBACGuards() {
    document.querySelectorAll("[data-rbac]").forEach(el => {
      const permission = el.getAttribute("data-rbac");
      if (!store.hasPermission(permission)) {
        el.setAttribute("aria-disabled", "true");
        el.title = "Permission must be verified by the backend.";
      }
    });
  }
}
export const appRuntime = new AppRuntime();
if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", () => appRuntime.init());
else appRuntime.init();
