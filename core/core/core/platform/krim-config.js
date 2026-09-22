/* =========================================================
   KRIM GLOBAL PLATFORM CONFIGURATION
   Permanent Frontend Configuration
   ========================================================= */

const KRIM_CONFIG = Object.freeze({

    platform: Object.freeze({
        name: "KRIM Logistics",
        shortName: "KRIM",
        environment: "production",
        architecture: "global",
        version: "1.0.0"
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
            home: "../home.html",
            terms: "../trust/terms.html",
            privacy: "../trust/privacy.html",
            refund: "../trust/refund.html"
        }),

        auth: Object.freeze({
            login: "../auth/login.html",
            mfa: "../auth/mfa.html",
            forgotPassword: "../auth/forgot-password.html",
            resetPassword: "../auth/reset-password.html"
        }),

        workspace: Object.freeze({
            customer: "../workspaces/customer-workspace.html",
            partner: "../workspaces/partner-workspace.html",
            operations: "../workspaces/operations-workspace.html"
        })

    }),

    domains: Object.freeze({

        shipments: "../domains/shipments.html",
        tracking: "../domains/tracking.html",
        quotes: "../domains/quotes.html",
        network: "../domains/network.html",
        partners: "../domains/partners.html",
        capacity: "../domains/capacity.html",
        finance: "../domains/finance.html",
        documents: "../domains/documents.html",
        compliance: "../domains/compliance.html",
        exceptions: "../domains/exceptions.html",
        claims: "../domains/claims.html",
        analytics: "../domains/analytics.html",
        integrations: "../domains/integrations.html",
        ai: "../domains/ai.html"

    }),

    frontend: Object.freeze({
        corePath: "../core/",
        platformPath: "./",
        authPath: "../auth/",
        workspacePath: "../workspaces/",
        domainPath: "../domains/",
        trustPath: "../trust/"
    }),

    security: Object.freeze({
        frontendIsSecurityBoundary: false,
        authorizationSource: "supabase",
        enforceRLS: true,
        enforceRBAC: true,
        requireAuthenticatedSessionForProtectedRoutes: true
    })

});
