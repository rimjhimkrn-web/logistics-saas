export const MARKETS_CONFIG = {
  activeMarkets: ['US', 'IN', 'DE', 'SG', 'AE', 'GB'],
  plannedMarkets: ['BR', 'ZA', 'JP', 'AU', 'MX'],
  defaultMarket: 'US',
  
  getMarketCapabilities(countryCode) {
    const isAvailable = this.activeMarkets.includes(countryCode.toUpperCase());
    return {
      instantQuoting: isAvailable,
      liveTracking: true, // Tracking works globally if reference exists
      localCurrencyPayouts: isAvailable,
      status: isAvailable ? 'ACTIVE' : 'PLANNED'
    };
  }
};
