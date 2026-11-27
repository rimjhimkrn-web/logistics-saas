import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const PROJECT_ID = "qrpcivhdxobiaofppbkl";
const origins = new Set([
  "https://rimjhimkrn-web.github.io",
  "https://krim-staging.pages.dev",
]);
const allowed = (origin: string | null) => !!origin && (
  origins.has(origin) || /^https:\/\/[a-z0-9-]+\.krim-staging\.pages\.dev$/.test(origin)
);
const headers = (origin: string | null) => ({
  "Access-Control-Allow-Origin": allowed(origin) ? origin! : "null",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
  "Content-Type": "application/json",
});
const reply = (body: unknown, status: number, origin: string | null) =>
  new Response(JSON.stringify(body), { status, headers: headers(origin) });

function tokenAal(token: string): string | null {
  try {
    const part = token.split(".")[1];
    if (!part) return null;
    const normalized = part.replace(/-/g, "+").replace(/_/g, "/");
    const claims = JSON.parse(atob(normalized + "=".repeat((4 - normalized.length % 4) % 4)));
    return typeof claims.aal === "string" ? claims.aal : null;
  } catch { return null; }
}

const roles = ["customer_a", "customer_b", "partner_a", "partner_b"] as const;
type FixtureRole = typeof roles[number];

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("Origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: headers(origin) });
  if (req.method !== "POST" || !allowed(origin)) {
    return reply({ ok: false, error: "Request origin or method denied." }, 403, origin);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) return reply({ ok: false, error: "Authentication required." }, 401, origin);

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url.startsWith("https://" + PROJECT_ID + ".supabase.co") || !anon || !service) {
    return reply({ ok: false, error: "Staging environment guard failed." }, 503, origin);
  }

  const token = authHeader.slice(7);
  const userClient = createClient(url, anon, { global: { headers: { Authorization: authHeader } } });
  const { data: authData, error: authError } = await userClient.auth.getUser(token);
  const caller = authData.user;
  if (authError || !caller) return reply({ ok: false, error: "Valid Staging user required." }, 401, origin);
  if (!caller.email_confirmed_at || tokenAal(token) !== "aal2") {
    return reply({ ok: false, error: "Confirmed email and verified AAL2 session required." }, 403, origin);
  }

  const admin = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: role, error: roleError } = await admin.from("krim_security_roles")
    .select("id").eq("role_code", "platform_superadmin").single();
  if (roleError || !role) return reply({ ok: false, error: "Staging owner role unavailable." }, 503, origin);
  const { data: assignments, error: assignmentError } = await admin.from("krim_user_role_assignments")
    .select("user_id").eq("role_id", role.id).eq("is_active", true);
  if (assignmentError) return reply({ ok: false, error: "Owner authorization lookup failed." }, 500, origin);
  const ownerIds = [...new Set((assignments ?? []).map((x: { user_id: string }) => x.user_id).filter(Boolean))];
  if (ownerIds.length !== 1 || ownerIds[0] !== caller.id) {
    return reply({ ok: false, error: "Only the single designated Staging owner may provision test identities." }, 403, origin);
  }

  let body: unknown;
  try { body = await req.json(); } catch { return reply({ ok: false, error: "Invalid JSON body." }, 400, origin); }
  if (!body || typeof body !== "object" || Array.isArray(body)) return reply({ ok: false, error: "Invalid request body." }, 400, origin);
  const input = body as Record<string, unknown>;
  const runId = input.run_id;
  const emailMap = input.emails;
  if (typeof runId !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(runId)) {
    return reply({ ok: false, error: "A UUID v4 run_id is required." }, 400, origin);
  }
  if (!emailMap || typeof emailMap !== "object" || Array.isArray(emailMap)) {
    return reply({ ok: false, error: "Four test email addresses are required." }, 400, origin);
  }
  const emails = emailMap as Record<string, unknown>;
  const normalized: Record<FixtureRole, string> = {} as Record<FixtureRole, string>;
  for (const roleName of roles) {
    const value = emails[roleName];
    if (typeof value !== "string" || value.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
      return reply({ ok: false, error: "Each of the four role-specific email addresses must be valid." }, 400, origin);
    }
    normalized[roleName] = value.trim().toLowerCase();
  }
  if (new Set(Object.values(normalized)).size !== 4) {
    return reply({ ok: false, error: "All four test email addresses must be different." }, 400, origin);
  }

  // Refuse to adopt existing accounts unless they carry this exact fixture run marker.
  const existingByEmail = new Map<string, any>();
  for (let page = 1; page <= 10; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 });
    if (error) return reply({ ok: false, error: "Could not safely check existing Staging accounts." }, 500, origin);
    for (const u of data.users) if (u.email) existingByEmail.set(u.email.toLowerCase(), u);
    if (data.users.length < 200) break;
  }

  const results: Array<{ role: FixtureRole; user_id: string; status: "invited" | "already_invited" }> = [];
  for (const roleName of roles) {
    const email = normalized[roleName];
    const existing = existingByEmail.get(email);
    if (existing) {
      const meta = existing.user_metadata ?? {};
      if (meta.krim_phase00_fixture !== true || meta.krim_fixture_run_id !== runId || meta.krim_fixture_role !== roleName) {
        return reply({ ok: false, error: "An address already belongs to a non-matching account; no account was adopted.", completed: results.length }, 409, origin);
      }
      results.push({ role: roleName, user_id: existing.id, status: "already_invited" });
      continue;
    }
    const { data, error } = await admin.auth.admin.inviteUserByEmail(email, {
      data: {
        krim_phase00_fixture: true,
        krim_fixture_run_id: runId,
        krim_fixture_role: roleName,
        krim_fixture_label: "KRIM TEST ONLY",
      },
    });
    if (error || !data.user) {
      return reply({ ok: false, error: "Invitation failed. Completed invitations are reported; resolve the issue before retrying.", completed: results.length }, 502, origin);
    }
    results.push({ role: roleName, user_id: data.user.id, status: "invited" });
  }

  return reply({
    ok: true,
    staging_project: PROJECT_ID,
    run_id: runId,
    invitations: results,
    next_step: "Each invitee must accept the invitation and establish a separate authenticated session. Organisations and shipment fixtures are not created by this function.",
  }, 200, origin);
});
