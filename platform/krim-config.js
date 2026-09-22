/* =========================================================
   KRIM PLATFORM CONFIGURATION
   Permanent global platform configuration
   ========================================================= */

(function () {
    "use strict";

    /*
     * -------------------------------------------------------
     * KRIM INSTALLATION ROOT
     * -------------------------------------------------------
     *
     * Detects the root of the deployed KRIM application from
     * the location of this configuration file.
     *
     * Works with:
     *   GitHub Pages:
     *   /logistics-saas/
     *
     * Future custom domain:
     *   /
     */

    function detectBasePath() {
        const scripts = Array.from(document.scripts);

        const configScript = scripts.find(function (script) {
            const src = script.src || "";
            return src.includes("/platform/krim-config.js");
        });

        if (configScript && configScript.src) {
            try {
                const url = new URL(configScript.src);

                const platformMarker = "/platform/krim-config.js";
                const markerIndex = url.pathname.indexOf(platformMarker);

                if (markerIndex !== -1) {
                    const basePath = url.pathname.slice(0, markerIndex);

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

        /*
         * Fallback for normal GitHub Pages deployment.
         */
        const pathname = window.location.pathname || "/";

        if (pathname.startsWith("/logistics-saas/")) {
            return "/logistics-saas/";
        }

        /*
         * Fallback for root/custom-domain deployment.
         */
        return "/";
    }


    const BASE_PATH = detectBasePath();


    /*
     * -------------------------------------------------------
     * ROUTE BUILDER
     * -------------------------------------------------------
     */

    function route(path) {
        const cleanPath = String(path || "")
            .replace(/^\/+/, "");

        return BASE_PATH + cleanPath;
    }


    /*
     * -------------------------------------------------------
     * GLOBAL KRIM CONFIGURATION
     * -------------------------------------------------------
     */

    const KRIM_CONFIG = Object.freeze({

        platform: Object.freeze({
            name: "KRIM Logistics",
            shortName: "KRIM",
            architecture: "global",
            environment: "production",
            version: "1.0.0",
            basePath: BASE_PATH
        }),


        /*
         * ---------------------------------------------------
         * GLOBAL MARKET MODEL
         * ---------------------------------------------------
         */

        market: Object.freeze({
            defaultCountry: "IN",
            defaultCurrency: "INR",
            defaultTimezone: "Asia/Kolkata",
            defaultLanguage: "en-IN"
        }),


        /*
         * ---------------------------------------------------
         * SUPABASE
         * ---------------------------------------------------
         *
         * The publishable/anon client key is intended for
         * browser use. Real security remains enforced by
         * Supabase Auth, RBAC, RLS and backend functions.
         */

        supabase: Object.freeze({
            url: "https://ebltviniygljwwseplph.supabase.co",
            publishableKey:
                "sb_publishable_8xzZUeubYp_nIxVRWEQdiw_2H4RkHAa"
        }),


        /*
         * ---------------------------------------------------
         * PUBLIC ROUTES
         * ---------------------------------------------------
         */

        routes: Object.freeze({

            public: Object.freeze({
                home: route("home.html"),
                index: route("index.html"),

                terms: route("trust/terms.html"),
                privacy: route("trust/privacy.html"),
                refund: route("trust/refund.html"),
                acceptableUse: route(
                    "trust/acceptable-use.html"
                ),
                cookies: route("trust/cookies.html")
            }),


            auth: Object.freeze({
                login: route("auth/login.html"),
                mfa: route("auth/mfa.html"),
                forgotPassword: route(
                    "auth/forgot-password.html"
                ),
                resetPassword: route(
                    "auth/reset-password.html"
                )
            }),


            workspaces: Object.freeze({
                customer: route(
                    "workspaces/customer-workspace.html"
                ),
                partner: route(
                    "workspaces/partner-workspace.html"
                ),
                operations: route(
                    "workspaces/operations-workspace.html"
                )
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
                integrations: route(
                    "domains/integrations.html"
                ),
                ai: route("domains/ai.html")
            })
        }),


        /*
         * ---------------------------------------------------
         * FRONTEND LAYERS
         * ---------------------------------------------------
         */

        frontend: Object.freeze({
            rootPath: BASE_PATH,
            corePath: route("core/"),
            platformPath: route("platform/"),
            authPath: route("auth/"),
            workspacePath: route("workspaces/"),
            domainPath: route("domains/"),
            trustPath: route("trust/")
        }),


        /*
         * ---------------------------------------------------
         * SECURITY POLICY
         * ---------------------------------------------------
         *
         * Frontend code is NEVER treated as the security
         * boundary.
         */

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


        /*
         * ---------------------------------------------------
         * GLOBAL PLATFORM SETTINGS
         * ---------------------------------------------------
         */

        settings: Object.freeze({

            requestTimeoutMs: 30000,

            defaultPageSize: 25,

            maximumPageSize: 100,

            dateFormat: "DD MMM YYYY",

            timeFormat: "24h",

            numberLocale: "en-IN"
        })

    });


    /*
     * -------------------------------------------------------
     * PUBLIC CONFIG API
     * -------------------------------------------------------
     */

    window.KRIM_CONFIG = KRIM_CONFIG;

    window.KRIM_ROUTE = route;

})();
