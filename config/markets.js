(function (global) {
  "use strict";

  const languages = [
    { code: "en", label: "English", dir: "ltr" },
    { code: "hi", label: "Hindi", dir: "ltr" },
    { code: "ar", label: "Arabic", dir: "rtl" },
    { code: "es", label: "Spanish", dir: "ltr" },
    { code: "fr", label: "French", dir: "ltr" },
    { code: "pt", label: "Portuguese", dir: "ltr" },
    { code: "de", label: "German", dir: "ltr" },
    { code: "it", label: "Italian", dir: "ltr" },
    { code: "nl", label: "Dutch", dir: "ltr" },
    { code: "tr", label: "Turkish", dir: "ltr" },
    { code: "zh-CN", label: "Chinese (Simplified)", dir: "ltr" },
    { code: "ja", label: "Japanese", dir: "ltr" },
    { code: "ko", label: "Korean", dir: "ltr" },
    { code: "ru", label: "Russian", dir: "ltr" },
    { code: "bn", label: "Bengali", dir: "ltr" }
  ];

  global.KRIM_MARKETS = Object.freeze({
    defaultMarket: "IN",
    languages: Object.freeze(languages.map(Object.freeze)),
    countries: Object.freeze([
      Object.freeze({
        code: "IN",
        name: "India",
        market: "IN",
        currency: "INR",
        timeZone: "Asia/Kolkata",
        languages: Object.freeze(["en", "hi", "bn"]),
        marketStatus: "active",
        serviceAvailability: "confirm-per-request"
      })
    ]),
    markets: Object.freeze([
      Object.freeze({
        code: "IN",
        country: "IN",
        status: "active",
        serviceAvailability: "confirm-per-request"
      })
    ]),
    currencies: Object.freeze([
      Object.freeze({ code: "INR", country: "IN", status: "active" })
    ]),
    timeZones: Object.freeze([
      Object.freeze({ code: "Asia/Kolkata", country: "IN" })
    ]),
    serviceAvailability: Object.freeze({
      authority: "backend-and-operations",
      defaultPolicy: "confirm-per-request",
      markets: Object.freeze({ IN: "confirm-per-request" })
    }),
    futureMarketStatus: "future-activation",
    availabilityAuthority: "backend-and-operations"
  });
})(window);