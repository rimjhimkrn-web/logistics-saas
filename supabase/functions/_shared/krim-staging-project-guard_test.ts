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
