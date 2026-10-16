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
      user: { id: null, name: "", email: "", avatar: "", role: "UNASSIGNED", permissions: [] },
      currentOrg: { id: null, name: "No organization selected", code: "", plan: "", sandboxMode: true },
      availableOrgs: [],
      preferences: { currency: "INR", locale: "en-IN", timezone: "Asia/Kolkata", theme: "dark" },
      notifications: [],
      telemetrySocket: { connected: false, latencyMs: null, lastHeartbeat: null }
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
    return Array.isArray(this.state.user.permissions) && this.state.user.permissions.includes(permission);
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
  
