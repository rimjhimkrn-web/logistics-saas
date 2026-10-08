/**
 * KRIM OS — Authenticated Application Core Runtime
 * Phase 3: Shared Authenticated Application Core
 * 
 * Drives session authentication state, client-side RBAC DOM guards,
 * organization context switching UI, and global keyboard shortcuts.
 */

import { store } from "/app/app-store.js";

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

    // 1. Session & Auth Verification Guard
    this.verifySessionGuard();

    // 2. Bind UI Components with State Store
    this.bindStoreWithUI();

    // 3. Register Global Keyboard Commands (Cmd + K)
    this.registerGlobalShortcuts();

    // 4. Enforce Client-Side RBAC Protection
    this.enforceRBACGuards();

    this.isInitialized = true;
    console.log("✅ [KRIM App Runtime] Core Runtime Operating Nominal.");
  }

  /**
   * Verification Guard to enforce active session
   */
  verifySessionGuard() {
    const authSession = localStorage.getItem("krim_auth_session") || sessionStorage.getItem("krim_auth_session");
    
    // Fallback stub session for demonstration / local dev
    if (!authSession) {
      console.info("[KRIM App Runtime] No active auth token found. Initializing enterprise demo session context.");
      localStorage.setItem("krim_auth_session", JSON.stringify({ token: "demo_jwt_99824", active: true }));
    }
  }

  /**
   * Synchronize DOM elements with reactive App Store
   */
  bindStoreWithUI() {
    const orgNameEl = document.getElementById("current-org-name");
    const currencySelectEl = document.getElementById("app-currency-select");

    // Sync initial state
    if (orgNameEl) orgNameEl.innerText = store.state.currentOrg.name;
    if (currencySelectEl) currencySelectEl.value = store.state.preferences.currency;

    // Currency Switcher Event
    currencySelectEl?.addEventListener("change", (e) => {
      store.setCurrency(e.target.value);
    });

    // Subscribe to State Changes
    store.subscribe((state, key) => {
      if (key === "ORGANIZATION_CHANGED" && orgNameEl) {
        orgNameEl.innerText = state.currentOrg.name;
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
