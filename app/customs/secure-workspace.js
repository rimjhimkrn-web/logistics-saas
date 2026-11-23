(() => {
  "use strict";
  const gate = document.getElementById("krimCustomsAuthGate");
  const loginUrl = "../../../auth/login.html?role=customs";
  function deny(title, detail) {
    if (!gate) return;
    document.documentElement.classList.remove("krim-customs-auth-pending");
    document.documentElement.classList.add("krim-customs-auth-denied");
    gate.innerHTML = '<div class="gate-card"><div class="gate-kicker">KRIM · CUSTOMS & TRADE</div><h1>' + title + '</h1><p>' + detail + '</p><a class="gate-button" href="' + loginUrl + '">Open secure sign in</a><p class="gate-foot">A direct page URL does not grant access. An active customs organization membership, AAL2 session and compliance.view permission are required.</p></div>';
  }
  async function verify() {
    try {
      const db = window.KRIM_SUPABASE || window.supabaseClient;
      if (!db) throw new Error("Secure authentication configuration is unavailable.");
      const { data: sessionData, error: sessionError } = await db.auth.getSession();
      if (sessionError) throw sessionError;
      const session = sessionData?.session;
      if (!session) { deny("Sign in required", "Sign in with your KRIM account to access this protected customs workflow."); return; }
      const { data: assurance, error: assuranceError } = await db.auth.mfa.getAuthenticatorAssuranceLevel();
      if (assuranceError) throw assuranceError;
      if (assurance?.currentLevel !== "aal2") { deny("Multi-factor authentication required", "This workspace requires an AAL2 session. Complete authenticator verification, then reopen this page."); return; }
      const { data: memberships, error: membershipError } = await db
        .from("krim_organization_members")
        .select("organization_id,krim_organizations(organization_type,status)")
        .eq("user_id", session.user.id)
        .eq("status", "active");
      if (membershipError) throw new Error("Organization membership could not be verified.");
      const organizations = (memberships || []).filter(row =>
        String(row.krim_organizations?.organization_type || "").toLowerCase() === "customs" &&
        String(row.krim_organizations?.status || "").toLowerCase() === "active"
      );
      if (!organizations.length) { deny("Customs organization access required", "No active customs organization membership was found for this account."); return; }
      const permissionChecks = await Promise.all(organizations.map(row =>
        db.rpc("krim_has_permission", {
          p_user_id: session.user.id,
          p_organization_id: row.organization_id,
          p_permission_code: "compliance.view"
        })
      ));
      if (permissionChecks.some(result => result.error)) throw new Error("Customs permissions could not be verified. Access remains blocked.");
      if (!permissionChecks.some(result => result.data === true)) { deny("Customs permission required", "Your organization membership does not include compliance.view. Ask an authorized organization administrator."); return; }
      window.KRIM_CUSTOMS_ACCESS = {
        userId: session.user.id,
        organizationIds: organizations.map(row => row.organization_id)
      };
      document.documentElement.classList.remove("krim-customs-auth-pending", "krim-customs-auth-denied");
      if (gate) gate.remove();
    } catch (error) {
      deny("Access verification failed", error?.message || "Secure access could not be verified. Please sign in again.");
    }
  }
  verify();
})();