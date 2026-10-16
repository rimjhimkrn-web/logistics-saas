/**
 * KRIM OS — shared Supabase client.
 *
 * Load platform/krim-config.js as a classic script before importing this
 * module. The configuration file exposes window.KRIM_CONFIG; it is not an
 * ES module and therefore must not be imported with a named import.
 */
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const config = window.KRIM_CONFIG;
if (!config?.supabase?.url || !config?.supabase?.publishableKey) {
  throw new Error(
    "KRIM configuration is missing. Load platform/krim-config.js before this module."
  );
}

export const supabase =
  window.KRIM_SUPABASE ||
  window.supabaseClient ||
  createClient(config.supabase.url, config.supabase.publishableKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true
    }
  });

window.KRIM_SUPABASE = supabase;
window.supabaseClient = supabase;
