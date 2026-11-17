import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { "content-type": "application/json", "cache-control": "no-store" },
});

async function matchesSecret(candidate: string, expected: string): Promise<boolean> {
  if (!expected || expected.length < 32 || candidate.length !== expected.length) return false;
  const [left, right] = await Promise.all([
    crypto.subtle.digest("SHA-256", new TextEncoder().encode(candidate)),
    crypto.subtle.digest("SHA-256", new TextEncoder().encode(expected)),
  ]);
  const a = new Uint8Array(left), b = new Uint8Array(right);
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const expected = Deno.env.get("KRIM_CRON_SECRET") ?? "";
  const supplied = req.headers.get("x-krim-cron-secret") ?? "";
  if (!(await matchesSecret(supplied, expected))) return json({ error: "unauthorized" }, 401);

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return json({ error: "worker_not_configured" }, 503);

  const supabase = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const rawBatch = Number(req.headers.get("x-krim-batch-size") ?? "200");
  const batchSize = Number.isInteger(rawBatch) ? Math.min(2000, Math.max(1, rawBatch)) : 200;

  const { data, error } = await supabase.rpc("krim_internal_expire_capacity_holds", {
    p_batch_size: batchSize,
  });

  if (error) {
    console.error("capacity expiry RPC failed", { code: error.code, message: error.message });
    return json({ error: "capacity_expiry_failed", code: error.code }, 500);
  }

  return json({ ok: true, expired_holds: Number(data ?? 0), batch_size: batchSize });
});
