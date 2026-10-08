/**
 * KRIM OS — Authenticated Application Reactive State Store
 * Phase 3: Shared Authenticated Application Core
 * 
 * Manages reactive state for Organization Context, RBAC permissions,
 * active user session, currency/localization preferences, notifications,
 * and real-time operational socket feeds.
 */

class AppStore {
  constructor() {
    this.state = {
      user: {
        id: "usr_9982401",
        name: "Operations Director",
        email: "ops.director@krim.os",
        avatar: "OP",
        role: "ENTERPRISE_ADMIN",
        permissions: [
          "shipment:read",
          "shipment:write",
          "shipment:delete",
          "org:manage",
          "billing:access",
          "telemetry:live",
          "customs:submit"
        ]
      },
      currentOrg: {
        id: "org_global_01",
        name: "Global Supply Chain Corp",
        code: "GSCC-GLOBAL",
        plan: "ENTERPRISE_TIER_1",
        sandboxMode: false
      },
      availableOrgs: [
        { id: "org_global_01", name: "Global Supply Chain Corp", role: "ENTERPRISE_ADMIN" },
        { id: "org_apac_02", name: "KRIM APAC Freight Hub", role: "REGIONAL_DISPATCHER" },
        { id: "org_emea_03", name: "EuroTrans Logistics GmbH", role: "AUDITOR" }
      ],
      preferences: {
        currency: "USD",
        locale: "en-US",
        timezone: "UTC",
        theme: "dark"
      },
      notifications: [
        { id: "n_101", type: "WARN", title: "Customs Hold Alert", msg: "Container MSCU892101 held at Rotterdam Gate 4", time: "2m ago", unread: true },
        { id: "n_102", type: "INFO", title: "e-POD Received", msg: "AOG Shipment AWB-7720-90 signed by Receiver", time: "12m ago", unread: true },
        { id: "n_103", type: "SUCCESS", title: "EDI 315 Synced", msg: "Vessel MAERSK MC-KINNEY MOLLER departed SIN", time: "1h ago", unread: true }
      ],
      telemetrySocket: {
        connected: true,
        latencyMs: 14,
        lastHeartbeat: new Date().toISOString()
      }
    };

    this.listeners = new Set();
    this.initFromLocalStorage();
  }

  /**
   * Initialize state overrides from persistent local storage
   */
  initFromLocalStorage() {
    try {
      const savedPref = localStorage.getItem("krim_app_preferences");
      if (savedPref) {
        this.state.preferences = { ...this.state.preferences, ...JSON.parse(savedPref) };
      }
      const savedOrg = localStorage.getItem("krim_active_org");
      if (savedOrg) {
        this.state.currentOrg = JSON.parse(savedOrg);
      }
    } catch (e) {
      console.warn("[KRIM Store] Storage hydration fallback used.", e);
    }
  }

  /**
   * Subscribe to state mutation events
   * @param {Function} listener Callback function receiving (newState, mutationKey)
   */
  subscribe(listener) {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  /**
   * Notify all registered UI components of state change
   */
  notify(key) {
    this.listeners.forEach((listener) => listener(this.state, key));
  }

  /**
   * Update Organization Context
   */
  setOrganization(orgId) {
    const target = this.state.availableOrgs.find((o) => o.id === orgId);
    if (target) {
      this.state.currentOrg = { ...this.state.currentOrg, id: target.id, name: target.name };
      localStorage.setItem("krim_active_org", JSON.stringify(this.state.currentOrg));
      this.notify("ORGANIZATION_CHANGED");
    }
  }

  /**
   * Update Currency Preference
   */
  setCurrency(currCode) {
    this.state.preferences.currency = currCode;
    localStorage.setItem("krim_app_preferences", JSON.stringify(this.state.preferences));
    this.notify("CURRENCY_CHANGED");
  }

  /**
   * Check RBAC Permission
   */
  hasPermission(permission) {
    return this.state.user.permissions.includes(permission) || this.state.user.role === "ENTERPRISE_ADMIN";
  }

  /**
   * Mark all notifications as read
   */
  markNotificationsRead() {
    this.state.notifications.forEach((n) => (n.unread = false));
    this.notify("NOTIFICATIONS_UPDATED");
  }
}

export const store = new AppStore();
  
