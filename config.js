const SUPABASE_URL = "https://ebltviniygljwwseplph.supabase.co";

const SUPABASE_PUBLISHABLE_KEY =
  "sb_publishable_8xzZUeubYp_nIxVRWEQdiw_2H4RkHAa";

function detectKrimEnvironment() {
  const configured = window.KRIM_ENVIRONMENT ||
    document.querySelector('meta[name="krim-environment"]')?.content;
  const supported = ["development", "preview", "production"];

  if (supported.includes(configured)) return configured;

  const hostname = window.location.hostname.toLowerCase();
  if (hostname === "localhost" || hostname === "127.0.0.1" || hostname === "::1") {
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

window.KRIM_ENVIRONMENT = detectKrimEnvironment();

const supabaseClient =
  window.KRIM_SUPABASE ||
  window.supabaseClient ||
  window.supabase.createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);

window.KRIM_SUPABASE = supabaseClient;
window.supabaseClient = supabaseClient;