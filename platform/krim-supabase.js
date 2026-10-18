/**
 * KRIM OS — Supabase Client Initializer
 * Uses the shared browser configuration from platform/krim-config.js
 * or the legacy config.js globals. Never place service-role secrets here.
 */
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const sharedConfig = globalThis.KRIM_CONFIG;
const supabaseConfig = sharedConfig?.supabase;

const SUPABASE_URL =
  supabaseConfig?.url ||
  "https://ebltviniygljwwseplph.supabase.co";

const SUPABASE_PUBLISHABLE_KEY =
  supabaseConfig?.publishableKey ||
  "sb_publishable_8xzZUeubYp_nIxVRWEQdiw_2H4RkHAa";

if (!SUPABASE_URL || !SUPABASE_PUBLISHABLE_KEY) {
  throw new Error("KRIM Supabase configuration is missing.");
}

export const supabase =
  globalThis.KRIM_SUPABASE ||
  globalThis.supabaseClient ||
  createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true
    }
  });

globalThis.KRIM_SUPABASE = supabase;
globalThis.supabaseClient = supabase;
