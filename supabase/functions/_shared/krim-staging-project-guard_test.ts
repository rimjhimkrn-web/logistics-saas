import { isKrimStagingProjectUrl, KRIM_STAGING_PROJECT_URL } from "./krim-staging-project-guard.ts";

Deno.test("accepts only the exact KRIM Staging Supabase URL", () => {
  if (!isKrimStagingProjectUrl(KRIM_STAGING_PROJECT_URL)) {
    throw new Error("Exact Staging URL must be accepted");
  }
  if (!isKrimStagingProjectUrl(KRIM_STAGING_PROJECT_URL + "/")) {
    throw new Error("Trailing slash should normalize to the same URL");
  }
});

Deno.test("rejects Production and lookalike project URLs", () => {
  const rejected = [
    "https://ebltviniygljwwseplph.supabase.co",
    "https://qrpcivhdxobiaofppbkl.supabase.co.attacker.example",
    "http://qrpcivhdxobiaofppbkl.supabase.co",
    "https://qrpcivhdxobiaofppbkl.supabase.co/rest/v1",
    "https://user@qrpcivhdxobiaofppbkl.supabase.co",
    "",
    null,
    undefined,
    "not-a-url"
  ];
  for (const value of rejected) {
    if (isKrimStagingProjectUrl(value)) {
      throw new Error(`Unexpectedly accepted project URL: ${String(value)}`);
    }
  }
});


Deno.test("all deployed Staging privileged workers use the shared project guard before clients", async () => {
  const functions = [
    "global-admin-control",
    "owner-testing-authorize",
    "krim-resend-email-worker",
    "krim-phase00-test-user-invites",
    "krim-phase00-provision-test-organizations",
  ];
  for (const name of functions) {
    const source = await Deno.readTextFile(`supabase/functions/${name}/index.ts`);
    if (!source.includes('import { isKrimStagingProjectUrl } from "../_shared/krim-staging-project-guard.ts";')) {
      throw new Error(`${name} does not import the shared exact-project guard`);
    }
    const guardIndex = source.indexOf("isKrimStagingProjectUrl(url)");
    const clientIndex = source.indexOf("createClient(url,");
    if (guardIndex < 0 || clientIndex < 0 || guardIndex > clientIndex) {
      throw new Error(`${name} does not validate the project URL before creating a Supabase client`);
    }
  }
});
