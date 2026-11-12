/**
 * KRIM legacy billing runtime — intentionally inactive.
 *
 * Partner-direct launch: KRIM does not rate, invoice, collect, escrow,
 * settle or disburse partner freight. This module must not claim that a
 * ledger has been verified or that a financial engine is operational.
 */
class BillingRuntime {
  constructor() {
    this.initialized = false;
    this.available = false;
  }

  init() {
    this.initialized = true;
    this.available = false;
    return false;
  }

  verifyLedgerIntegrity() {
    // No ledger-integrity assertion is made by this legacy browser module.
    return false;
  }

  calculateRatedTotal() {
    throw new Error(
      "KRIM freight rating is disabled in partner-direct launch. Obtain the confirmed price directly from the contracting logistics partner."
    );
  }
}

export const billingRuntime = new BillingRuntime();
