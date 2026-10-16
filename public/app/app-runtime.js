/**
 * KRIM OS — Authenticated Application Core Runtime
 * Phase 3: Shared Authenticated Application Core
 * 
 * Drives session authentication state, client-side RBAC DOM guards,
 * organization context switching UI, and global keyboard shortcuts.
 */

import { store } from "./app-store.js";

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
    const authenticated = await this.verifySessionGuard();
    if (!authenticated) return;

    // 2. Bind UI Components with State Store
    this.bindStoreWithUI();

    // 3. Register Global Keyboard Commands (Cmd + K)
    this.registerGlobalShortcuts();

    // 4. Enforce Client-Side RBAC Protection
    this.enforceRBACGuards();

    this.isInitialized = true;
    console.log("✅ [KRIM App Runtime] Core Runtime Operating Nominal.");
  }

  async ensureSupabaseClient() {
    if (window.KRIM_SUPABASE) return window.KRIM_SUPABASE;

    const loadScript = (src) => new Promise((resolve, reject) => {
      const existing = Array.from(document.scripts).find((script) => script.src === src);
      if (existing) {
        if (existing.dataset.loaded === "true") return resolve();
        existing.addEventListener("load", resolve, { once: true });
        existing.addEventListener("error", reject, { once: true });
        return;
      }
      const script = document.createElement("script");
      script.src = src;
      script.async = false;
      script.addEventListener("load", () => { script.dataset.loaded = "true"; resolve(); }, { once: true });
      script.addEventListener("error", reject, { once: true });
      document.head.appendChild(script);
    });

    await loadScript("https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2");
    const configUrl = new URL("../../config.js", import.meta.url).href;
    await loadScript(configUrl);
    if (!window.KRIM_SUPABASE) throw new Error("KRIM Supabase client could not be initialized.");
    return window.KRIM_SUPABASE;
  }

  /**
   * Real authentication guard and least-privilege workspace context.
   * Local storage values are never accepted as proof of authentication.
   */
  async verifySessionGuard() {
    let client;
    try {
      client = await this.ensureSupabaseClient();
      const { data: { session }, error } = await client.auth.getSession();
      if (error) throw error;
      if (!session?.user?.id) {
        window.location.href = new URL("../../auth/login.html", import.meta.url).href;
        return false;
      }

      const user = session.user;
      const fullName = String(user.user_metadata?.full_name || "").trim();
      store.state.user = {
        id: user.id,
        name: fullName || user.email || "Signed-in user",
        email: user.email || "",
        avatar: (fullName || user.email || "U").slice(0, 2).toUpperCase(),
        role: "UNASSIGNED",
        permissions: []
      };

      const { data: memberships, error: membershipError } = await client
        .from("krim_organization_members")
        .select("organization_id, role")
        .eq("user_id", user.id)
        .eq("status", "active");

      if (membershipError) {
        console.warn("[KRIM App Runtime] Organization membership could not be loaded; workspace access remains restricted.", membershipError.message);
        store.state.availableOrgs = [];
      } else {
        const membershipRows = memberships || [];
        const orgIds = [...new Set(membershipRows.map((row) => row.organization_id).filter(Boolean))];
        let organizations = [];
        if (orgIds.length) {
          const { data: orgRows, error: orgError } = await client
            .from("krim_organizations")
            .select("id, display_name, legal_name, organization_type, default_currency_code, status")
            .in("id", orgIds);
          if (orgError) {
            console.warn("[KRIM App Runtime] Organization context could not be loaded.", orgError.message);
          } else {
            organizations = orgRows || [];
          }
        }

        store.state.availableOrgs = organizations.map((org) => {
          const membership = membershipRows.find((row) => String(row.organization_id) === String(org.id));
          return { id: org.id, name: org.display_name || org.legal_name || ("Organization " + org.id), role: membership?.role || "member" };
        });

        const savedOrg = localStorage.getItem("krim_active_org");
        const selected = store.state.availableOrgs.find((org) => savedOrg && String(org.id) === String(JSON.parse(savedOrg).id))
          || store.state.availableOrgs[0];
        store.state.currentOrg = selected
          ? { id: selected.id, name: selected.name, code: "", plan: "", sandboxMode: false }
          : { id: null, name: "No organization selected", code: "", plan: "", sandboxMode: true };
      }

      // Permissions are loaded only from database role assignments; failures leave the UI denied by default.
      const { data: assignments, error: assignmentError } = await client
        .from("krim_user_role_assignments")
        .select("organization_id, role_id")
        .eq("user_id", user.id)
        .eq("is_active", true);

      if (!assignmentError && assignments?.length) {
        const roleIds = [...new Set(assignments.map((row) => row.role_id).filter(Boolean))];
        const { data: roles, error: rolesError } = await client
          .from("krim_security_roles")
          .select("id, role_code")
          .in("id", roleIds);
        if (!rolesError && roles?.length) {
          store.state.user.role = roles.map((role) => role.role_code).join(",");
          const { data: mappings, error: mappingError } = await client
            .from("krim_role_permissions")
            .select("permission_id, role_id, granted")
            .in("role_id", roleIds)
            .eq("granted", true);
          if (!mappingError && mappings?.length) {
            const permissionIds = [...new Set(mappings.map((row) => row.permission_id).filter(Boolean))];
            const { data: permissionRows, error: permissionError } = await client
              .from("krim_security_permissions")
              .select("id, permission_code")
              .in("id", permissionIds);
            if (!permissionError) {
              store.state.user.permissions = (permissionRows || []).map((row) => row.permission_code);
            }
          }
        }
      } else if (assignmentError) {
        console.warn("[KRIM App Runtime] Permissions could not be loaded; restricted controls remain hidden.", assignmentError.message);
      }

      store.notify("AUTH_CONTEXT_LOADED");
      return true;
    } catch (error) {
      console.error("[KRIM App Runtime] Authentication bootstrap failed.", error);
      window.location.href = new URL("../../auth/login.html", import.meta.url).href;
      return false;
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
