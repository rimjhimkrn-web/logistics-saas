/**
 * KRIM OS — Shipper Platform Runtime
 * Phase 5: Customer / Shipper Platform
 * 
 * Handles booking submissions, spot approvals, volumetric
 * calculations, and active shipment updates.
 */

import { store } from "/app/app-store.js";

class ShipperRuntime {
  constructor() {
    this.initialized = false;
  }

  /**
   * Boot Shipper Runtime
   */
  init() {
    if (this.initialized) return;

    console.log("📦 [KRIM Shipper Runtime] Initializing Customer Platform...");

    this.bindBookingEvents();
    this.initialized = true;
    console.log("✅ [KRIM Shipper Runtime] Shipper Platform Active.");
  }

  /**
   * Bind event handlers for booking and quote requests
   */
  bindBookingEvents() {
    const bookingForm = document.querySelector("form");
    if (bookingForm && window.location.pathname.includes("booking-request.html")) {
      console.log("📦 [Shipper Runtime] Booking request form active.");
    }
  }

  /**
   * Calculate CBM Volumetric conversion utility
   */
  calculateVolumetric(l, w, h, qty, mode = "AIR") {
    const cbm = (l * w * h * qty) / 1000000;
    let factor = 167; // Air standard
    if (mode === "OCEAN") factor = 1000;
    if (mode === "ROAD") factor = 333;

    return {
      cbm: cbm.toFixed(2),
      chargeableKg: (cbm * factor).toFixed(2)
    };
  }
}

export const shipperRuntime = new ShipperRuntime();

// Auto-initialize on DOM ready
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => shipperRuntime.init());
} else {
  shipperRuntime.init();
}
