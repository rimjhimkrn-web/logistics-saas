/* ==========================================================================
   KRIM LOGISTICS OS — SECURE SESSION MANAGER
   ========================================================================== */

const KRIM_SESSION_STORE_KEY = "KRIM_SESSION_STATE_V1";

const KrimSession = {
  set(sessionData) {
    const payload = {
      ...sessionData,
      initializedAt: new Date().toISOString(),
      lastActive: new Date().toISOString()
    };
    localStorage.setItem(KRIM_SESSION_STORE_KEY, JSON.stringify(payload));
  },

  get() {
    const raw = localStorage.getItem(KRIM_SESSION_STORE_KEY);
    if (!raw) return null;
    try {
      return JSON.parse(raw);
    } catch (e) {
      this.clear();
      return null;
    }
  },

  updateLastActive() {
    const current = this.get();
    if (current) {
      current.lastActive = new Date().toISOString();
      localStorage.setItem(KRIM_SESSION_STORE_KEY, JSON.stringify(current));
    }
  },

  clear() {
    localStorage.removeItem(KRIM_SESSION_STORE_KEY);
    sessionStorage.clear();
  },

  isValid() {
    const session = this.get();
    if (!session || !session.token) return false;
    // Check session timeout (24 hour max default)
    const elapsedHours = (new Date() - new Date(session.lastActive)) / (1000 * 60 * 60);
    return elapsedHours < 24;
  }
};
