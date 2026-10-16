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

    function detectEnvironment() {
        const configured =
            window.KRIM_ENVIRONMENT ||
            document.querySelector(
                'meta[name="krim-environment"]'
            )?.content;
        const supported = [
            "development",
            "preview",
            "production"
        ];

        if (supported.includes(configured)) {
            return configured;
        }

        const hostname =
            window.location.hostname.toLowerCase();

        if (
            hostname === "localhost" ||
            hostname === "127.0.0.1" ||
            hostname === "::1"
        ) {
            return "development";
        }

        if (
            hostname.includes(".preview.") ||
            /^pr-\d+--.+\.netlify\.app$/.test(hostname) ||
            /-git-[^.]+\.vercel\.app$/.test(hostname)
        ) {
            return "preview";
        }

        return "production";
    }

    const BASE_PATH = detectBasePath();
    const ENVIRONMENT = detectEnvironment();
    window.KRIM_ENVIRONMENT = ENVIRONMENT;

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
            environment: ENVIRONMENT,
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
                home: route("index.html"),
                index: route("index.html"),
                solutions: route("public/solutions.html"),
                network: route("public/network.html"),
                tracking: route("public/tracking.html"),
                terms: route("terms.html"),
                privacy: route("privacy.html"),
                refund: route("refund.html"),
                acceptableUse: route("public/legal/acceptable-use.html"),
                cookies: route("public/legal/cookie-policy.html")
            }),

            auth: Object.freeze({
                login: route("auth/login.html"),
                signup: route("auth/signup.html"),
                partnerSignup: route("auth/partner-signup.html"),
                callback: route("auth/auth-callback.html"),
                mfa: route("auth/mfa.html"),
                mfaChallenge: route("auth/mfa-challenge.html"),
                mfaEnroll: route("auth/mfa-enroll.html"),
                forgotPassword: route("auth/forgot-password.html"),
                resetPassword: route("auth/reset-password.html")
            }),

            workspaces: Object.freeze({
                customer: route("app/customer/index.html"),
                partner: route("app/partner/index.html"),
                enterprise: route("app/enterprise/index.html"),
                driver: route("app/field/index.html"),
                warehouse: route("app/field/index.html"),
                operations: route("public/operations/control-tower.html"),
                finance: route("domains/finance.html"),
                compliance: route("domains/compliance.html"),
                support: route("public/support/ticket-desk.html"),
                developer: route("public/developer/api-docs.html"),
                superAdmin: route("public/admin/control-tower.html")
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
