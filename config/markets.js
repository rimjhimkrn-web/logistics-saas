/**
 * KRIM global market catalogue and activation guard.
 *
 * A country being present in the catalogue is not proof that KRIM has
 * verified providers, legal approval, rates, payments, support or live
 * fulfilment there. Commercial activation must be driven by the server-side
 * market-readiness workflow, never by this static frontend catalogue.
 */
export const MARKETS_CONFIG = Object.freeze({
  // India is the initial operating focus. These are catalogue entries only.
  catalogMarkets: Object.freeze(['IN', 'AE', 'DE', 'GB', 'SG', 'US']),
  plannedMarkets: Object.freeze(['BR', 'ZA', 'JP', 'AU', 'MX']),
  defaultMarket: 'IN',

  // Keep empty until a market has passed the documented activation gates.
  commerciallyEnabledMarkets: Object.freeze([]),

  getMarketCapabilities(countryCode) {
    const code = String(countryCode || '').trim().toUpperCase();
    const inCatalogue = this.catalogMarkets.includes(code);
    const commerciallyEnabled = this.commerciallyEnabledMarkets.includes(code);

    return Object.freeze({
      countryCode: code,
      inCatalogue,
      commerciallyEnabled,
      instantQuoting: commerciallyEnabled,
      liveTracking: false,
      localCurrencyPayouts: commerciallyEnabled,
      status: commerciallyEnabled
        ? 'ACTIVE'
        : inCatalogue
          ? 'CATALOG_ONLY'
          : this.plannedMarkets.includes(code)
            ? 'PLANNED'
            : 'UNCONFIGURED',
      activationNotice: commerciallyEnabled
        ? 'Market activation is recorded. Confirm current route and provider eligibility before offering a service.'
        : 'Country catalogue presence does not mean KRIM services are commercially available in this market.'
    });
  }
});
