/**
 * KRIM OS — Shared Component Runtime
 * Phase 19: Shared UI Foundation & Component Layer
 * 
 * Drives universal layout state, organization switching, and session security helpers.
 */

class SharedRuntime {
  constructor() {
    this.initialized = false;
  }

  init() {
    if (this.initialized) return;
    console.log("🧩 [KRIM Shared Runtime] Initializing Shared Application Shell & Components...");
    this.initialized = true;
    console.log("✅ [KRIM Shared Runtime] Shared Component Foundation Active.");
  }
}

export const sharedRuntime = new SharedRuntime();

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => sharedRuntime.init());
} else {
  sharedRuntime.init();
}
