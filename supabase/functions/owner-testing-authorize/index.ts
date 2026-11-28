import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { isKrimStagingProjectUrl } from "../_shared/krim-staging-project-guard.ts";

const allowedExactOrigins = new Set([
  "https://rimjhimkrn-web.github.io",
  "https://krim-staging.pages.dev"
]);
const isAllowedOrigin = (origin: string | null) =>
  !!origin && (allowedExactOrigins.has(origin) ||
    /^https:\/\/[a-z0-9-]+\.krim-staging\.pages\.dev$/.test(origin));
const cors = (origin: string | null) => ({
  "Access-Control-Allow-Origin": isAllowedOrigin(origin) ? origin! : "null",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
  "Content-Type": "application/json"
});
const reply = (body: unknown, status = 200, origin: string | null = null) =>
  new Response(JSON.stringify(body), { status, headers: cors(origin) });

function readVerifiedAal(token: string): string | null {
  try {
    const segment = token.split(".")[1];
    if (!segment) return null;
    const base64 = segment.replace(/-/g, "+").replace(/_/g, "/");
    const padded = base64 + "=".repeat((4 - base64.length % 4) % 4);
    const claims = JSON.parse(atob(padded));
    return typeof claims.aal === "string" ? claims.aal : null;
  } catch {
    return null;
  }
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("Origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origin) });
  if (req.method !== "POST" || !isAllowedOrigin(origin)) return reply({ ok: false, error: "Request origin or method denied." }, 403, origin);

  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return reply({ ok: false, error: "Authentication required." }, 401, origin);

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  if (!isKrimStagingProjectUrl(url)) return reply({ ok: false, error: "Project environment mismatch." }, 503, origin);
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !anonKey || !serviceKey) return reply({ ok: false, error: "Staging function configuration is incomplete." }, 500, origin);

  const token = authorization.slice(7);
  const userClient = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } });
  const { data: userData, error: userError } = await userClient.auth.getUser(token);
  if (userError || !userData.user) return reply({ ok: false, error: "Valid staging account required." }, 401, origin);
  if (!userData.user.email_confirmed_at) return reply({ ok: false, error: "Verified email is required before owner access." }, 403, origin);

  // getUser(token) above validates the JWT signature and expiry; trust its signed AAL claim.
  if (readVerifiedAal(token) !== "aal2") {
    return reply({ ok: false, error: "Verified multi-factor authentication is required.", code: "MFA_REQUIRED" }, 403, origin);
  }

  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: superRole, error: roleError } = await admin.from("krim_security_roles")
    .select("id").eq("role_code", "platform_superadmin").single();
  if (roleError || !superRole) return reply({ ok: false, error: "Staging owner role is not configured." }, 503, origin);

  const { data: owners, error: ownersError } = await admin.from("krim_user_role_assignments")
    .select("user_id").eq("role_id", superRole.id).eq("is_active", true);
  if (ownersError) return reply({ ok: false, error: "Owner authorization lookup failed." }, 500, origin);

  const ownerIds = [...new Set((owners ?? []).map((row: { user_id: string }) => row.user_id).filter(Boolean))];
  if (ownerIds.length !== 1 || ownerIds[0] !== userData.user.id) {
    return reply({ ok: false, error: "This staging account is not the single designated KRIM owner." }, 403, origin);
  }

  return reply({ ok: true, data: { owner_testing: true, mfa: "aal2" } }, 200, origin);
});