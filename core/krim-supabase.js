/* ==========================================================================
   KRIM LOGISTICS OS — SUPABASE BACKEND INTEGRATION ENGINE
   ========================================================================== */

class KrimBackendDriver {
  constructor() {
    this.client = null;
    this.init();
  }

  init() {
    // Legacy core modules must reuse the single hostname-validated platform client.
    // No independent URL/key or Production fallback is permitted here.
    const client = window.KRIM_SUPABASE;
    const config = window.KRIM_SUPABASE_CONFIG;
    if (
      client &&
      config &&
      window.KRIM_SUPABASE_PROJECT_REF === config.projectRef
    ) {
      this.client = client;
      console.log("[KRIM CORE] Shared environment-validated Supabase client attached.");
    } else {
      this.client = null;
      console.error("[KRIM CORE] Approved shared Supabase client unavailable; backend operations are blocked.");
    }
  }

  // Auth wrappers
  async signUp(email, password, metadata) {
    if (!this.client) throw new Error("Backend driver not initialized.");
    return await this.client.auth.signUp({
      email,
      password,
      options: { data: metadata }
    });
  }

  async signIn(email, password) {
    if (!this.client) throw new Error("Backend driver not initialized.");
    return await this.client.auth.signInWithPassword({ email, password });
  }

  async signOut() {
    if (!this.client) return;
    return await this.client.auth.signOut();
  }

  async getSession() {
    if (!this.client) return null;
    const { data: { session } } = await this.client.auth.getSession();
    return session;
  }

  // Realtime Telemetry Channels
  subscribeToShipmentUpdates(shipmentId, callback) {
    if (!this.client) return null;
    return this.client
      .channel(`public:shipments:id=eq.${shipmentId}`)
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'shipments', filter: `id=eq.${shipmentId}` }, 
        payload => callback(payload.new)
      )
      .subscribe();
  }
}

window.KrimBackend = new KrimBackendDriver();
