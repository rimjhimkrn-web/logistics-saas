import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  "https://ebltviniygljwwseplph.supabase.co",
  "sb_publishable_8xzZUeubYp_nIxVRWEQdiw_2H4RkHAa",
  { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } }
);

class AppStore {
  constructor() {
    this.state = {
      user: null,
      currentOrg: null,
      availableOrgs: [],
      preferences: { currency: "INR", locale: "en", timezone: "Asia/Kolkata", theme: "dark" },
      notifications: [],
      telemetrySocket: { connected: false, latencyMs: null, lastHeartbeat: null },
      loading: true,
      error: null
    };
    this.listeners = new Set();
    this.ready = this.initialize();
  }

  async initialize() {
    this.state.loading = true;
    this.notify("INITIALIZING");
    try {
      const { data, error } = await supabase.auth.getUser();
      if (error) throw error;
      const authUser = data?.user || null;
      this.state.user = authUser ? {
        id: authUser.id,
        name: authUser.user_metadata?.full_name || authUser.email || "KRIM User",
        email: authUser.email || "",
        avatar: (authUser.email || "K").slice(0, 1).toUpperCase(),
        role: null,
        permissions: []
      } : null;

      if (!authUser) {
        this.state.currentOrg = null;
        this.state.availableOrgs = [];
        this.state.error = "Sign-in required";
        return;
      }

      const [prefResult, memberResult] = await Promise.all([
        supabase.from("krim_user_app_preferences").select("preferences").eq("user_id", authUser.id).maybeSingle(),
        supabase.from("krim_organization_members")
          .select("organization_id,role,status,krim_organizations(id,display_name,legal_name,default_currency_code,timezone)")
          .eq("user_id", authUser.id)
          .eq("status", "active")
      ]);

      if (!prefResult.error && prefResult.data?.preferences) {
        const p = prefResult.data.preferences;
        this.state.preferences = {
          ...this.state.preferences,
          currency: p.currency || this.state.preferences.currency,
          locale: p.language || p.locale || this.state.preferences.locale,
          timezone: p.timezone || this.state.preferences.timezone,
          theme: p.theme || this.state.preferences.theme,
          ...p
        };
      }
      if (!memberResult.error && Array.isArray(memberResult.data)) {
        this.state.availableOrgs = memberResult.data.map(m => {
          const org = m.krim_organizations || {};
          return {
            id: m.organization_id,
            name: org.display_name || org.legal_name || ("Organization " + m.organization_id),
            role: m.role,
            currency: org.default_currency_code || null,
            timezone: org.timezone || null
          };
        });
      }
      const savedOrg = this.state.availableOrgs.find(o => String(o.id) === String(this.state.preferences.activeOrganizationId));
      this.state.currentOrg = savedOrg || this.state.availableOrgs[0] || null;
      this.state.error = prefResult.error?.message || memberResult.error?.message || null;
      await this.recordActivity("app_opened", { source: "app-shell" });
    } catch (error) {
      this.state.error = error?.message || "Unable to initialize KRIM session";
      this.state.user = null;
      this.state.currentOrg = null;
      this.state.availableOrgs = [];
    } finally {
      this.state.loading = false;
      this.notify("INITIALIZED");
    }
  }

  subscribe(listener) {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  notify(key) {
    this.listeners.forEach(listener => listener(this.state, key));
  }

  async recordActivity(event_type, details = {}) {
    if (!this.state.user?.id) return;
    const { error } = await supabase.from("krim_user_activity_events").insert({
      user_id: this.state.user.id,
      event_type,
      page_path: location.pathname,
      details
    });
    if (error) console.warn("[KRIM Store] Activity logging unavailable:", error.message);
  }

  async setOrganization(orgId) {
    const target = this.state.availableOrgs.find(o => String(o.id) === String(orgId));
    if (!target) throw new Error("Organization membership not found.");
    this.state.currentOrg = target;
    this.state.preferences = { ...this.state.preferences, activeOrganizationId: target.id };
    await this.savePreferences();
    this.notify("ORGANIZATION_CHANGED");
    await this.recordActivity("preferences_saved", { activeOrganizationId: target.id });
  }

  async setCurrency(currCode) {
    const allowed = ["INR", "USD", "EUR", "GBP", "AED"];
    if (!allowed.includes(currCode)) throw new Error("Unsupported currency.");
    this.state.preferences = { ...this.state.preferences, currency: currCode };
    await this.savePreferences();
    this.notify("CURRENCY_CHANGED");
  }

  async savePreferences() {
    if (!this.state.user?.id) throw new Error("Sign in to save preferences.");
    const { error } = await supabase.from("krim_user_app_preferences").upsert({
      user_id: this.state.user.id,
      preferences: this.state.preferences,
      updated_at: new Date().toISOString()
    }, { onConflict: "user_id" });
    if (error) throw error;
  }

  hasPermission(permission) {
    // Frontend permission checks only affect presentation. Backend authorization remains mandatory.
    return Boolean(this.state.user && this.state.permissions?.includes(permission));
  }

  async markNotificationsRead() {
    // No fake notification mutation: wire this only when the user's notification schema/action contract is confirmed.
    this.notify("NOTIFICATIONS_NOT_CONFIGURED");
  }
}

export const store = new AppStore();
