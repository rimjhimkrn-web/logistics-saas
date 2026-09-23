/* =========================================================
   KRIM PLATFORM CONFIGURATION
   Permanent global platform configuration
   ========================================================= */

(function () {
    "use strict";

    function detectBasePath() {
        const scripts = Array.from(document.scripts);

        const configScript = scripts.find(function (script) {
            const src = script.src || "";
            return src.includes("/platform/krim-config.js");
        });

        if (configScript && configScript.src) {
            try {
                const url = new URL(configScript.src);
                const marker = "/platform/krim-config.js";
                const index = url.pathname.indexOf(marker);

                if (index !== -1) {
                    const basePath = url.pathname.slice(0, index);

                    return basePath.endsWith("/")
                        ? basePath
                        : basePath + "/";
                }
            } catch (error) {
                console.warn(
                    "KRIM: Could not determine deployment base path.",
                    error
                );
            }
        }

        const pathname = window.location.pathname || "/";

        if (pathname.startsWith("/logistics-saas/")) {
            return "/logistics-saas/";
        }

        return "/";
    }

    const BASE_PATH = detectBasePath();

    function route(path) {
        const cleanPath = String(path || "")
            .replace(/^\/+/, "");

        return BASE_PATH + cleanPath;
    }

    const KRIM_CONFIG = Object.freeze({

        platform: Object.freeze({
            name: "KRIM Logistics",
            shortName: "KRIM",
            architecture: "global",
            environment: "production",
            version: "1.0.0",
            basePath: BASE_PATH
        }),

        market: Object.freeze({
            defaultCountry: "IN",
            defaultCurrency: "INR",
            defaultTimezone: "Asia/Kolkata",
            defaultLanguage: "en-IN"
        }),

        supabase: Object.freeze({
            url: "https://ebltviniygljwwseplph.supabase.co",
            publishableKey:
                "sb_publishable_8xzZUeubYp_nIxVRWEQdiw_2H4RkHAa"
        }),

        routes: Object.freeze({

            public: Object.freeze({
                home: route("home.html"),
                index: route("index.html"),
                terms: route("terms.html"),
                privacy: route("privacy.html"),
                refund: route("refund.html"),
                acceptableUse: route("acceptable-use.html"),
                cookies: route("cookies.html")
            }),

            auth: Object.freeze({
                login: route("auth/login.html"),
                mfa: route("auth/mfa.html"),
                mfaEnroll: route("auth/mfa-enroll.html"),
                forgotPassword:
                    route("auth/forgot-password.html"),
                resetPassword:
                    route("auth/reset-password.html")
            }),

            workspaces: Object.freeze({
                customer:
                    route("workspaces/customer-workspace.html"),
                partner:
                    route("workspaces/partner-workspace.html"),
                operations:
                    route("workspaces/operations-workspace.html")
            }),

            domains: Object.freeze({
                shipments: route("domains/shipments.html"),
                tracking: route("domains/tracking.html"),
                quotes: route("domains/quotes.html"),
                network: route("domains/network.html"),
                partners: route("domains/partners.html"),
                capacity: route("domains/capacity.html"),
                finance: route("domains/finance.html"),
                documents: route("domains/documents.html"),
                compliance: route("domains/compliance.html"),
                exceptions: route("domains/exceptions.html"),
                claims: route("domains/claims.html"),
                analytics: route("domains/analytics.html"),
                integrations:
                    route("domains/integrations.html"),
                ai: route("domains/ai.html")
            })
        }),

        frontend: Object.freeze({
            rootPath: BASE_PATH,
            corePath: route("core/"),
            platformPath: route("platform/"),
            authPath: route("auth/"),
            workspacePath: route("workspaces/"),
            domainPath: route("domains/"),
            trustPath: BASE_PATH
        }),

        security: Object.freeze({
            frontendIsSecurityBoundary: false,
            authorizationSource: "supabase",
            enforceRLS: true,
            enforceRBAC: true,
            requireAuthenticatedSessionForProtectedRoutes:
                true,
            requireMFAForPrivilegedAccess:
                true
        }),

        settings: Object.freeze({
            requestTimeoutMs: 30000,
            defaultPageSize: 25,
            maximumPageSize: 100,
            dateFormat: "DD MMM YYYY",
            timeFormat: "24h",
            numberLocale: "en-IN"
        })
    });

    window.KRIM_CONFIG = KRIM_CONFIG;
    window.KRIM_ROUTE = route;

})();
