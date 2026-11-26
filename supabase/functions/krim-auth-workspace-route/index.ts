import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("Origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origin) });
  if (req.method !== "POST" || !isAllowedOrigin(origin)) {
    return reply({ ok: false, error: "Request origin or method denied." }, 403, origin);
  }
  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return reply({ ok: false, error: "Authentication required." }, 401, origin);
  }
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !anonKey || !serviceKey) {
    return reply({ ok: false, error: "Platform routing service is not configured." }, 500, origin);
  }
  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false }
  });
  const token = authorization.slice(7);
  const { data: userData, error: userError } = await userClient.auth.getUser(token);
  if (userError || !userData.user) {
    return reply({ ok: false, error: "Valid signed-in account required." }, 401, origin);
  }
  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false }
  });
  const { data: assignments, error } = await admin
    .from("krim_user_role_assignments")
    .select("is_active,krim_security_roles!inner(role_code)")
    .eq("user_id", userData.user.id)
    .eq("is_active", true);
  if (error) {
    console.error("Workspace role routing lookup failed:", error.message);
    return reply({ ok: false, error: "Workspace role could not be verified." }, 503, origin);
  }
  const roles = [...new Set((assignments ?? [])
    .map((row: any) => row.krim_security_roles?.role_code)
    .filter((role: unknown): role is string => typeof role === "string"))];
  const isPlatformAdmin = roles.includes("platform_superadmin") || roles.includes("platform_admin");
  return reply({
    ok: true,
    is_platform_admin: isPlatformAdmin,
    is_platform_superadmin: roles.includes("platform_superadmin")
  }, 200, origin);
});
