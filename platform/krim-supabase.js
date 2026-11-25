/**
 * KRIM OS — Shared Supabase Client Access
 * Requires config.js to resolve the current hostname and initialize the
 * approved project client first. No production fallback is permitted.
 */
const config = globalThis.KRIM_SUPABASE_CONFIG;
const client = globalThis.KRIM_SUPABASE;
const expectedProjectRef = config?.projectRef;

if (!config || !expectedProjectRef || !client ||
    globalThis.KRIM_SUPABASE_PROJECT_REF !== expectedProjectRef) {
  throw new Error("KRIM shared Supabase client is unavailable or its project identity is unverified.");
}

const approvedRefs = new Set(["ebltviniygljwwseplph", "qrpcivhdxobiaofppbkl"]);
if (!approvedRefs.has(expectedProjectRef) ||
    config.url !== "https://" + expectedProjectRef + ".supabase.co") {
  throw new Error("KRIM Supabase project mapping failed identity validation.");
}

export const supabase = client;
export const SUPABASE_URL = config.url;
export const SUPABASE_PROJECT_REF = expectedProjectRef;
