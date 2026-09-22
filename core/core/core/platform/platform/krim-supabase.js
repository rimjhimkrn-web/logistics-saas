/* =========================================================
   KRIM SUPABASE CLIENT
   Permanent Browser Client
   ========================================================= */

(function () {

    "use strict";

    if (typeof window.supabase === "undefined") {
        console.error(
            "KRIM: Supabase JavaScript library is not loaded."
        );
        return;
    }

    if (typeof KRIM_CONFIG === "undefined") {
        console.error(
            "KRIM: Platform configuration is not loaded."
        );
        return;
    }

    const {
        url,
        publishableKey
    } = KRIM_CONFIG.supabase;

    if (!url || !publishableKey) {
        console.error(
            "KRIM: Supabase configuration is incomplete."
        );
        return;
    }

    window.KRIM_SUPABASE =
        window.supabase.createClient(
            url,
            publishableKey,
            {
                auth: {
                    autoRefreshToken: true,
                    persistSession: true,
                    detectSessionInUrl: true
                }
            }
        );

})();
