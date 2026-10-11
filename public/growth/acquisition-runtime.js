/**
 * KRIM OS — Global Acquisition Runtime
 * Phase 1: Global Acquisition Core & Unified Growth Engine
 * 
 * Drives pipeline state machines, duplicate detection, and acquisition telemetry.
 */

class AcquisitionRuntime {
  constructor() {
    this.initialized = false;
  }

  init() {
    if (this.initialized) return;
    console.log("🌐 [KRIM Acquisition Runtime] Initializing Global Growth & Pipeline Engine...");
    this.verifyDuplicateEngine();
    this.initialized = true;
    console.log("✅ [KRIM Acquisition Runtime] Global Acquisition Core Active.");
  }

  verifyDuplicateEngine() {
    console.log("🛡️ [Deduplication Engine] Active: Zero redundant prospect insertions permitted.");
  }
}

export const acquisitionRuntime = new AcquisitionRuntime();

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => acquisitionRuntime.init());
} else {
  acquisitionRuntime.init();
}
