import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const PROJECT_ID = "qrpcivhdxobiaofppbkl";
const roles = ["customer_a", "customer_b", "partner_a", "partner_b"] as const;
type FixtureRole = typeof roles[number];
const originAllowed = (origin: string | null) => !!origin && (
  origin === "https://rimjhimkrn-web.github.io" ||
  origin === "https://krim-staging.pages.dev" ||
  /^https:\/\/[a-z0-9-]+\.krim-staging\.pages\.dev$/.test(origin)
);
const cors = (origin: string | null) => ({
  "Access-Control-Allow-Origin": originAllowed(origin) ? origin! : "null",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
  "Content-Type": "application/json",
});
const response = (body: unknown, status: number, origin: string | null) =>
  new Response(JSON.stringify(body), { status, headers: cors(origin) });
function aal(token: string): string | null {
  try {
    const part = token.split(".")[1];
    const value = part.replace(/-/g, "+").replace(/_/g, "/");
    const claims = JSON.parse(atob(value + "=".repeat((4 - value.length % 4) % 4)));
    return typeof claims.aal === "string" ? claims.aal : null;
  } catch { return null; }
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("Origin");
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors(origin) });
  if (req.method !== "POST" || !originAllowed(origin)) return response({ ok: false, error: "Origin or method denied." }, 403, origin);
  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) return response({ ok: false, error: "Authentication required." }, 401, origin);

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (url !== `https://${PROJECT_ID}.supabase.co` || !anon || !service) {
    return response({ ok: false, error: "Exact Staging environment guard failed." }, 503, origin);
  }
  const token = auth.slice(7);
  const userClient = createClient(url, anon, { global: { headers: { Authorization: auth } } });
  const { data: callerData, error: callerError } = await userClient.auth.getUser(token);
  const caller = callerData.user;
  if (callerError || !caller) return response({ ok: false, error: "Valid Staging user required." }, 401, origin);
  if (!caller.email_confirmed_at || aal(token) !== "aal2") return response({ ok: false, error: "Confirmed email and AAL2 required." }, 403, origin);

  const admin = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: superRole, error: roleError } = await admin.from("krim_security_roles").select("id").eq("role_code", "platform_superadmin").single();
  if (roleError || !superRole) return response({ ok: false, error: "Owner role unavailable." }, 503, origin);
  const { data: ownerRows, error: ownerError } = await admin.from("krim_user_role_assignments")
    .select("user_id").eq("role_id", superRole.id).eq("is_active", true);
  if (ownerError) return response({ ok: false, error: "Owner authorization lookup failed." }, 500, origin);
  const owners = [...new Set((ownerRows ?? []).map((x: {user_id:string}) => x.user_id))];
  if (owners.length !== 1 || owners[0] !== caller.id) return response({ ok: false, error: "Single designated Staging owner required." }, 403, origin);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return response({ ok: false, error: "Invalid JSON." }, 400, origin); }
  const runId = body?.run_id;
  if (typeof runId !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(runId)) {
    return response({ ok: false, error: "Valid fixture run UUID required." }, 400, origin);
  }

  const users = new Map<FixtureRole, any>();
  for (let page = 1; page <= 10; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 });
    if (error) return response({ ok: false, error: "Could not verify invited test identities." }, 500, origin);
    for (const u of data.users) {
      const meta = u.app_metadata ?? {};
      if (meta.krim_phase00_fixture === true && meta.krim_fixture_run_id === runId &&
          roles.includes(meta.krim_fixture_role as FixtureRole)) {
        const role = meta.krim_fixture_role as FixtureRole;
        if (users.has(role)) return response({ ok: false, error: "Duplicate fixture identity marker detected." }, 409, origin);
        users.set(role, u);
      }
    }
    if (data.users.length < 200) break;
  }
  if (users.size !== 4 || roles.some(role => !users.has(role))) {
    return response({ ok: false, error: "All four invitation records for this run must exist before organisation provisioning." }, 409, origin);
  }
  for (const role of roles) {
    if (!users.get(role).email_confirmed_at) return response({ ok: false, error: "All four invitees must accept and confirm their email before provisioning." }, 409, origin);
  }
  const ids = roles.map(role => users.get(role).id);
  if (new Set(ids).size !== 4) return response({ ok: false, error: "Four distinct Auth identities are required." }, 409, origin);

  const orgResults: Array<{ role: FixtureRole; organization_id: number; membership: string }> = [];
  for (const role of roles) {
    const isPartner = role.startsWith("partner");
    const label = role.toUpperCase().replace("_", " ");
    const legalName = `KRIM TEST ONLY | ${label} | ${runId}`;
    const { data: found, error: findError } = await admin.from("krim_organizations")
      .select("id,organization_type,legal_name").eq("legal_name", legalName).maybeSingle();
    if (findError) return response({ ok: false, error: "Could not safely check existing fixture organisation." }, 500, origin);
    let organizationId: number;
    if (found) {
      if (found.organization_type !== (isPartner ? "partner" : "customer")) {
        return response({ ok: false, error: "Existing fixture organisation has an unexpected type." }, 409, origin);
      }
      organizationId = found.id;
    } else {
      const row: Record<string, unknown> = {
        organization_type: isPartner ? "partner" : "customer",
        organization_type_code: isPartner ? "partner" : "customer",
        legal_name: legalName,
        display_name: `KRIM TEST ONLY — ${label}`,
        status: "active",
      };
      if (isPartner) {
        row.partner_account_mode = "development_test";
        row.partner_lifecycle_status = "registered";
        row.partner_verification_status = "not_started";
        row.partner_compliance_status = "not_started";
        row.partner_onboarding_status = "not_started";
        row.partner_metadata = { krim_phase00_fixture: true, krim_fixture_run_id: runId, krim_fixture_role: role };
      }
      const { data: inserted, error: insertError } = await admin.from("krim_organizations").insert(row).select("id").single();
      if (insertError || !inserted) return response({ ok: false, error: "Organisation creation failed; retry is safe after reviewing this run." }, 500, origin);
      organizationId = inserted.id;
    }

    const userId = users.get(role).id;
    const { data: member, error: memberError } = await admin.from("krim_organization_members")
      .select("id,role,status").eq("organization_id", organizationId).eq("user_id", userId).maybeSingle();
    if (memberError) return response({ ok: false, error: "Membership verification failed." }, 500, origin);
    let membership = "existing";
    if (member) {
      if (member.role !== "owner" || member.status !== "active") return response({ ok: false, error: "Existing fixture membership conflicts with expected owner role." }, 409, origin);
    } else {
      const { error: insertMemberError } = await admin.from("krim_organization_members")
        .insert({ organization_id: organizationId, user_id: userId, role: "owner", status: "active" });
      if (insertMemberError) return response({ ok: false, error: "Membership creation failed; review audit trail before retrying." }, 500, origin);
      membership = "created";
    }
    orgResults.push({ role, organization_id: organizationId, membership });
  }
  return response({
    ok: true, staging_project: PROJECT_ID, run_id: runId,
    organisations: orgResults,
    partner_state: "development_test / registered / not verified / not compliant; not eligible for real partner marketplace activation",
    next_step: "Sign in separately as each test identity and verify own-organisation access before creating shipment fixtures.",
  }, 200, origin);
});
