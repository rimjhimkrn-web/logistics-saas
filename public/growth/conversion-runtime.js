/**
 * KRIM customer conversion readiness preview.
 *
 * This module intentionally performs no automated outreach, serviceability
 * matching, quotation generation or booking. Those operations require verified
 * partner, corridor, pricing and authorization data in the production workflows.
 */
class ConversionRuntime {
  constructor() {
    this.initialized = false;
  }

  init() {
    if (this.initialized) return;
    this.initialized = true;
    document.documentElement.dataset.krimConversionRuntime = "readiness-preview";
    console.info("[KRIM] Customer conversion readiness preview loaded. No live matching, quote generation, outreach or booking was performed.");
  }
}

export const conversionRuntime = new ConversionRuntime();

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => conversionRuntime.init(), { once: true });
} else {
  conversionRuntime.init();
}
