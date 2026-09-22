/* =========================================================
   KRIM SUPABASE CLIENT
   Permanent shared Supabase connection layer
   ========================================================= */

(function () {
    "use strict";

    /*
     * -------------------------------------------------------
     * DEPENDENCY CHECKS
     * -------------------------------------------------------
     */

    if (typeof window.supabase === "undefined") {
        console.error(
            "KRIM: Supabase JavaScript library is not loaded."
        );
        return;
    }

    if (
        typeof window.KRIM_CONFIG === "undefined" ||
        !window.KRIM_CONFIG.supabase
    ) {
        console.error(
            "KRIM: Platform configuration is not loaded."
        );
        return;
    }


    /*
     * -------------------------------------------------------
     * PREVENT DUPLICATE INITIALIZATION
     * -------------------------------------------------------
     */

    if (window.KRIM_SUPABASE) {
        return;
    }


    /*
     * -------------------------------------------------------
     * CONFIGURATION
     * -------------------------------------------------------
     */

    const supabaseConfig = window.KRIM_CONFIG.supabase;

    const url = supabaseConfig.url;
    const publishableKey = supabaseConfig.publishableKey;


    if (!url || !publishableKey) {
        console.error(
            "KRIM: Supabase configuration is incomplete."
        );
        return;
    }


    /*
     * -------------------------------------------------------
     * CREATE SINGLE SHARED CLIENT
     * -------------------------------------------------------
     */

    try {

        window.KRIM_SUPABASE = window.supabase.createClient(
            url,
            publishableKey,
            {
                auth: {
                    autoRefreshToken: true,
                    persistSession: true,
                    detectSessionInUrl: true,
                    flowType: "pkce"
                },

                global: {
                    headers: {
                        "X-KRIM-Platform": "KRIM Logistics"
                    }
                }
            }
        );

    } catch (error) {

        console.error(
            "KRIM: Failed to initialize Supabase client.",
            error
        );

        return;
    }


    /*
     * -------------------------------------------------------
     * CLIENT STATUS
     * -------------------------------------------------------
     */

    window.KRIM_SUPABASE_READY = true;

})();
