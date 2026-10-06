/* ==========================================================================
   KRIM LOGISTICS OS — SUPABASE BACKEND INTEGRATION ENGINE
   ========================================================================== */

class KrimBackendDriver {
  constructor() {
    this.client = null;
    this.init();
  }

  init() {
    if (typeof window.supabase !== "undefined") {
      this.client = window.supabase.createClient(
        KRIM_CONFIG.SUPABASE_URL,
        KRIM_CONFIG.SUPABASE_ANON_KEY,
        {
          auth: {
            persistSession: true,
            autoRefreshToken: true,
            detectSessionInUrl: true
          }
        }
      );
      console.log("[KRIM CORE] Supabase backend engine initialized successfully.");
    } else {
      console.warn("[KRIM CORE] Supabase client SDK missing from global window. Running in fallback mode.");
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
