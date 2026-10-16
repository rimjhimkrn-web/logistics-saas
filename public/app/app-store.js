/**
 * KRIM OS — Authenticated Application State Store
 * All identity, organization, and UI permission context is derived from Supabase.
 * This store is a presentation aid only; backend RLS and RPC checks remain authoritative.
 */
import { supabase } from "../../platform/krim-supabase.js";

class AppStore {
  constructor() {
    this.state = {
      user: null,
      currentOrg: null,
      availableOrgs: [],
      roleAssignments: [],
      preferences: { currency: "INR", locale: "en-IN", timezone: "Asia/Kolkata", theme: "dark" },
      notifications: [],
      telemetrySocket: { connected: false, latencyMs: null, lastHeartbeat: null }
    };
    this.listeners = new Set();
    this.initFromLocalStorage();
  }

  initFromLocalStorage() {
    try {
      const savedPref = localStorage.getItem("krim_app_preferences");
      if (savedPref) {
        const parsed = JSON.parse(savedPref);
        const allowedCurrencies = ["INR", "USD", "EUR", "GBP", "AED", "SGD", "JPY"];
        this.state.preferences = {
          ...this.state.preferences,
          ...parsed,
          currency: allowedCurrencies.includes(parsed.currency) ? parsed.currency : "INR"
        };
      }
    } catch (error) {
      console.warn("[KRIM Store] Preferences could not be restored.", error);
    }
  }

  async loadAuthenticatedContext(session) {
    if (!session?.user?.id) throw new Error("A valid Supabase session is required.");
    const user = session.user;

    const { data: memberships, error: membershipError } = await supabase
      .from("krim_organization_members")
      .select("organization_id, role, status, created_at")
      .eq("user_id", user.id)
      .eq("status", "active")
      .order("created_at", { ascending: true });
    if (membershipError) throw membershipError;

    const organizationIds = [...new Set((memberships || []).map(item => item.organization_id))];
    let organizations = [];
    if (organizationIds.length) {
      const { data, error } = await supabase
        .from("krim_organizations")
        .select("id, legal_name, display_name, organization_type, default_currency_code, timezone, status")
        .in("id", organizationIds)
        .eq("status", "active");
      if (error) throw error;
      organizations = data || [];
    }

    const membershipByOrg = new Map((memberships || []).map(item => [String(item.organization_id), item]));
    this.state.availableOrgs = organizations.map(org => ({
      id: org.id,
      name: org.display_name || org.legal_name,
      type: org.organization_type,
      currency: org.default_currency_code || "INR",
      timezone: org.timezone || "Asia/Kolkata",
      memberRole: membershipByOrg.get(String(org.id))?.role || "member"
    }));

    const savedOrgId = localStorage.getItem("krim_active_org_id");
    this.state.currentOrg = this.state.availableOrgs.find(org => String(org.id) === savedOrgId)
      || this.state.availableOrgs[0]
      || null;

    const fullName = String(user.user_metadata?.full_name || user.user_metadata?.name || "").trim();
    this.state.user = {
      id: user.id,
      email: user.email || "",
      name: fullName || user.email || "KRIM User",
      avatar: (fullName || user.email || "K").split(/\s+/).map(part => part[0]).join("").slice(0, 2).toUpperCase(),
      role: "member",
      permissions: []
    };

    this.state.roleAssignments = [];
    if (organizationIds.length) {
      const { data: assignments, error: assignmentError } = await supabase
        .from("krim_user_role_assignments")
        .select("organization_id, role_id, is_active")
        .eq("user_id", user.id)
        .eq("is_active", true)
        .in("organization_id", organizationIds);
      if (!assignmentError && assignments?.length) {
        const roleIds = [...new Set(assignments.map(item => item.role_id))];
        const { data: roles, error: rolesError } = await supabase
          .from("krim_security_roles")
          .select("id, role_code")
          .in("id", roleIds);
        const { data: rolePermissions, error: rolePermissionsError } = await supabase
          .from("krim_role_permissions")
          .select("role_id, permission_id, granted")
          .in("role_id", roleIds)
          .eq("granted", true);
        const permissionIds = [...new Set((rolePermissions || []).map(item => item.permission_id))];
        let permissions = [];
        if (permissionIds.length) {
          const result = await supabase
            .from("krim_security_permissions")
            .select("id, permission_code")
            .in("id", permissionIds);
          if (!result.error) permissions = result.data || [];
        }
        if (!rolesError && !rolePermissionsError) {
          const roleMap = new Map((roles || []).map(item => [item.id, item.role_code]));
          const permissionMap = new Map(permissions.map(item => [item.id, item.permission_code]));
          this.state.roleAssignments = assignments.map(assignment => ({
            organizationId: assignment.organization_id,
            roleCode: roleMap.get(assignment.role_id) || "member",
            permissions: (rolePermissions || [])
              .filter(item => item.role_id === assignment.role_id)
              .map(item => permissionMap.get(item.permission_id))
              .filter(Boolean)
          }));
        }
      }
    }

    this.applyCurrentOrganizationAuthorization();
    this.notify("AUTHENTICATED_CONTEXT_LOADED");
    return this.state;
  }

  applyCurrentOrganizationAuthorization() {
    const orgId = this.state.currentOrg?.id;
    const assignments = this.state.roleAssignments.filter(item => String(item.organizationId) === String(orgId));
    const roles = [...new Set(assignments.map(item => item.roleCode))];
    const permissions = [...new Set(assignments.flatMap(item => item.permissions))];
    if (this.state.user) {
      this.state.user.role = roles.join(", ") || this.state.currentOrg?.memberRole || "member";
      this.state.user.permissions = permissions;
    }
  }

  subscribe(listener) {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  notify(key) {
    this.listeners.forEach(listener => listener(this.state, key));
  }

  setOrganization(orgId) {
    const target = this.state.availableOrgs.find(org => String(org.id) === String(orgId));
    if (!target) return false;
    this.state.currentOrg = target;
    localStorage.setItem("krim_active_org_id", String(target.id));
    this.applyCurrentOrganizationAuthorization();
    this.notify("ORGANIZATION_CHANGED");
    return true;
  }

  setCurrency(currency) {
    const allowed = ["INR", "USD", "EUR", "GBP", "AED", "SGD", "JPY"];
    if (!allowed.includes(currency)) return;
    this.state.preferences.currency = currency;
    localStorage.setItem("krim_app_preferences", JSON.stringify(this.state.preferences));
    this.notify("CURRENCY_CHANGED");
  }

  hasPermission(permission) {
    if (!this.state.user || !this.state.currentOrg || !permission) return false;
    const normalize = value => String(value).replace(/:/g, ".").toLowerCase();
    return this.state.user.permissions.some(value => normalize(value) === normalize(permission));
  }

  markNotificationsRead() {
    this.state.notifications.forEach(notification => { notification.unread = false; });
    this.notify("NOTIFICATIONS_UPDATED");
  }
}

export const store = new AppStore();
