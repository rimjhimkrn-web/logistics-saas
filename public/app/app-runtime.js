/**
 * KRIM OS — Authenticated Application Core Runtime
 * Phase 3: Shared Authenticated Application Core
 * 
 * Drives session authentication state, client-side RBAC DOM guards,
 * organization context switching UI, and global keyboard shortcuts.
 */

import { store } from "./app-store.js";
import { supabase } from "../../platform/krim-supabase.js";

class AppRuntime {
  constructor() {
    this.isInitialized = false;
  }

  /**
   * Boot operational runtime
   */
  async init() {
    if (this.isInitialized) return;

    console.log("🚀 [KRIM App Runtime] Initializing Authenticated Application Core...");

    // A real Supabase session is required. Never create a demo/stub session.
    const session = await this.verifySessionGuard();
    if (!session) return;

    try {
      await store.loadAuthenticatedContext(session);
      if (!store.state.currentOrg) {
        this.showRuntimeNotice("Your account has no active KRIM organization yet. Complete onboarding or contact your organization administrator.");
        return;
      }

      this.bindStoreWithUI();
      this.registerGlobalShortcuts();
      this.enforceRBACGuards();
      this.isInitialized = true;
      console.log("KRIM authenticated application runtime initialized.");
    } catch (error) {
      console.error("KRIM workspace initialization failed.", error);
      this.showRuntimeNotice("KRIM could not load your authorized workspace. Refresh the page or contact support.");
    }
  }

  /**
   * Verification Guard to enforce active session
   */
  async verifySessionGuard() {
    const { data, error } = await supabase.auth.getSession();
    if (error || !data?.session) {
      const loginRoute = window.KRIM_ROUTE ? window.KRIM_ROUTE("auth/login.html") : "../../auth/login.html";
      window.location.replace(loginRoute);
      return null;
    }
    return data.session;
  }

  showRuntimeNotice(message) {
    let notice = document.getElementById("krim-runtime-notice");
    if (!notice) {
      notice = document.createElement("div");
      notice.id = "krim-runtime-notice";
      notice.setAttribute("role", "status");
      notice.style.cssText = "margin:16px;padding:14px;border:1px solid #92400e;border-radius:12px;background:#1c1917;color:#fde68a;font:13px/1.5 system-ui,sans-serif;";
      document.body.prepend(notice);
    }
    notice.textContent = message;
  }

  /**
   * Synchronize DOM elements with reactive App Store
   */
  bindStoreWithUI() {
    const orgNameEl = document.getElementById("current-org-name");
    const currencySelectEl = document.getElementById("app-currency-select");

    // Sync initial state
    if (orgNameEl) orgNameEl.innerText = (store.state.currentOrg?.name || "KRIM Workspace");
    if (currencySelectEl) currencySelectEl.value = store.state.preferences.currency;

    // Currency Switcher Event
    currencySelectEl?.addEventListener("change", (e) => {
      store.setCurrency(e.target.value);
    });

    // Subscribe to State Changes
    store.subscribe((state, key) => {
      if (key === "ORGANIZATION_CHANGED" && orgNameEl) {
        orgNameEl.innerText = (state.currentOrg?.name || "KRIM Workspace");
      }
      if (key === "CURRENCY_CHANGED" && currencySelectEl) {
        currencySelectEl.value = state.preferences.currency;
      }
    });
  }

  /**
   * Global Keyboard Event Listeners (Cmd+K / Ctrl+K)
   */
  registerGlobalShortcuts() {
    window.addEventListener("keydown", (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key === "k") {
        e.preventDefault();
        this.toggleCommandPalette();
      }
    });

    document.getElementById("cmd-palette-trigger")?.addEventListener("click", () => {
      this.toggleCommandPalette();
    });
  }

  /**
   * Trigger Global Command Palette Navigation
   */
  toggleCommandPalette() {
    const existingPalette = document.getElementById("cmd-palette-modal");
    if (existingPalette) {
      existingPalette.remove();
      return;
    }

    // Modal Command Palette Injection
    const modalHtml = `
      <div id="cmd-palette-modal" class="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-sm flex items-start justify-center pt-20 px-4 font-mono">
        <div class="bg-[#081020] border border-slate-800 w-full max-w-xl rounded-2xl shadow-2xl overflow-hidden text-xs">
          <div class="p-4 border-b border-slate-800 flex items-center gap-3">
            <span class="text-slate-500">🔍</span>
            <input id="cmd-input-search" type="text" placeholder="Type a command or search (e.g., 'Shipments', 'Create Rate', 'Vault')..." class="w-full bg-transparent text-white outline-none placeholder-slate-600" focus />
            <kbd class="px-2 py-1 bg-slate-900 border border-slate-800 rounded text-[10px] text-slate-400">ESC</kbd>
          </div>
          <div class="p-2 space-y-1 max-h-80 overflow-y-auto text-slate-300">
            <a href="/app/dashboard-framework.html" class="flex items-center justify-between p-2.5 rounded-xl hover:bg-cyan-500/10 hover:text-cyan-400 transition-all">
              <span>📊 Dashboard Framework</span>
              <span class="text-[10px] text-slate-500">NAVIGATE</span>
            </a>
            <a href="/app/global-search.html" class="flex items-center justify-between p-2.5 rounded-xl hover:bg-cyan-500/10 hover:text-cyan-400 transition-all">
              <span>🌐 Global Search Engine</span>
              <span class="text-[10px] text-slate-500">NAVIGATE</span>
            </a>
            <a href="/app/document-vault.html" class="flex items-center justify-between p-2.5 rounded-xl hover:bg-cyan-500/10 hover:text-cyan-400 transition-all">
              <span>📁 Document & e-Sign Vault</span>
              <span class="text-[10px] text-slate-500">NAVIGATE</span>
            </a>
            <a href="/app/org-switcher.html" class="flex items-center justify-between p-2.5 rounded-xl hover:bg-cyan-500/10 hover:text-cyan-400 transition-all">
              <span>🏢 Organization & Workspace Switcher</span>
              <span class="text-[10px] text-slate-500">NAVIGATE</span>
            </a>
          </div>
        </div>
      </div>
    `;

    document.body.insertAdjacentHTML("beforeend", modalHtml);

    // Escape Key Listener to Close
    const closeHandler = (e) => {
      if (e.key === "Escape") {
        document.getElementById("cmd-palette-modal")?.remove();
        window.removeEventListener("keydown", closeHandler);
      }
    };
    window.addEventListener("keydown", closeHandler);
    document.getElementById("cmd-palette-modal")?.addEventListener("click", (e) => {
      if (e.target.id === "cmd-palette-modal") closeHandler({ key: "Escape" });
    });
  }

  /**
   * DOM RBAC Permission Guard
   * Hides or disables elements with data-rbac attribute if user lacks permission
   */
  enforceRBACGuards() {
    const guardedElements = document.querySelectorAll("[data-rbac]");
    guardedElements.forEach((el) => {
      const requiredPerm = el.getAttribute("data-rbac");
      if (!store.hasPermission(requiredPerm)) {
        el.style.display = "none";
      }
    });
  }
}

export const appRuntime = new AppRuntime();

// Auto-bootstrap runtime on DOM load
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => appRuntime.init());
} else {
  appRuntime.init();
}
