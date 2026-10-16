/**
 * KRIM OS — Supabase Client Initializer
 * Uses the canonical browser configuration from platform/krim-config.js.
 * Load krim-config.js before importing this module.
 */
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const config = window.KRIM_CONFIG;
const supabaseConfig = config?.supabase;

if (!supabaseConfig?.url || !supabaseConfig?.publishableKey) {
  throw new Error(
    "KRIM Supabase configuration is missing. Load platform/krim-config.js before this module."
  );
}

export const supabase =
  window.KRIM_SUPABASE ||
  createClient(supabaseConfig.url, supabaseConfig.publishableKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true
    }
  });

window.KRIM_SUPABASE = supabase;
window.supabaseClient = supabase;
