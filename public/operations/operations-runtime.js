/**
 * KRIM OS — Operations & Control Tower Runtime
 *
 * External AIS telemetry, automated rerouting and predictive ETA are NOT
 * configured. This module deliberately does not generate sample vessel
 * positions, pretend to receive provider events, or calculate fictional
 * savings/costs. Only verified records returned by connected KRIM services
 * may be shown as operational facts.
 */

export class OperationsRuntime {
  constructor() {
    this.initialized = false;
  }

  init() {
    if (this.initialized) return;
    this.initialized = true;
    return {
      status: "provider_not_connected",
      ais: "disabled",
      automated_rerouting: "disabled",
      predictive_eta: "disabled"
    };
  }

  listenAISSatelliteStream() {
    return {
      available: false,
      reason: "No verified AIS provider is configured."
    };
  }

  calculateRerouteProposal(shipmentId, disruptType) {
    return {
      available: false,
      shipmentId: shipmentId ?? null,
      disruptionType: disruptType ?? null,
      reason: "Automated rerouting is disabled until live route, compliance, capacity and partner data are verified."
    };
  }
}

export const operationsRuntime = new OperationsRuntime();

// Safe initialization only; no timers, simulated events, network calls or writes.
if (typeof document !== "undefined") {
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", () => operationsRuntime.init(), { once: true });
  } else {
    operationsRuntime.init();
  }
}
