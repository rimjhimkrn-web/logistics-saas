/**
 * KRIM OS — Supabase Client Initializer
 * Provides the unified database and auth client for all frontends.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { KRIM_CONFIG } from "./krim-config.js";

export const supabase = createClient(
  KRIM_CONFIG.SUPABASE_URL,
  KRIM_CONFIG.SUPABASE_ANON_KEY,
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true
    }
  }
);
