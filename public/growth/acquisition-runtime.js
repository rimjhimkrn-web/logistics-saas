/**
 * KRIM OS — Acquisition UI Runtime
 *
 * This file only initializes the page-side module. It does not perform
 * duplicate detection, create prospects, send outreach, or run background jobs.
 * Those actions must be implemented and verified by the secured backend.
 */
class AcquisitionRuntime {
  constructor() {
    this.initialized = false;
    this.capabilities = Object.freeze({
      duplicateDetection: "backend_required",
      prospectCreation: "backend_required",
      automatedOutreach: "disabled"
    });
  }

  init() {
    if (this.initialized) return;
    this.initialized = true;
    console.info("[KRIM Acquisition UI] Page module initialized. Backend capabilities are not asserted by this module.");
  }
}

export const acquisitionRuntime = new AcquisitionRuntime();

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => acquisitionRuntime.init(), { once: true });
} else {
  acquisitionRuntime.init();
}
