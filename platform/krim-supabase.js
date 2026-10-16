/**
 * KRIM OS — Shared Supabase Client Initializer
 * Requires platform/krim-config.js to be loaded first.
 * Only the public publishable key is used in browser code.
 */
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const config = window.KRIM_CONFIG;
if (!config?.supabase?.url || !config?.supabase?.publishableKey) {
  throw new Error("KRIM configuration is missing. Load platform/krim-config.js first.");
}
export const supabase = window.KRIM_SUPABASE || createClient(
  config.supabase.url,
  config.supabase.publishableKey,
  { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, flowType: "pkce" } }
);
window.KRIM_SUPABASE = supabase;
