import { readFileSync } from "node:fs";
import assert from "node:assert/strict";

const config = readFileSync("platform/krim-config.js", "utf8");
const client = readFileSync("platform/krim-supabase.js", "utf8");

assert.match(config, /hostname\s*===\s*"krim-staging\.pages\.dev"/,
  "Cloudflare staging hostname must be explicitly recognized");
assert.match(config, /hostname\.endsWith\("\.krim-staging\.pages\.dev"\)/,
  "Cloudflare staging preview subdomains must be recognized");
assert.match(config, /ENVIRONMENT === "production"\s*\?/,
  "Supabase project selection must be environment-dependent");
assert.match(config, /qrpcivhdxobiaofppbkl\.supabase\.co/,
  "Non-production configuration must point to the staging Supabase project");
assert.match(config, /ebltviniygljwwseplph\.supabase\.co/,
  "Production configuration must retain the production Supabase project");
assert.doesNotMatch(client, /\|\|\s*"https:\/\/ebltviniygljwwseplph\.supabase\.co"/,
  "Supabase client must not silently fall back to production");
assert.doesNotMatch(client, /\|\|\s*"sb_publishable_8xzZUeubYp_nIxVRWEQdiw_2H4RkHAa"/,
  "Supabase client must not silently fall back to the production publishable key");
assert.match(client, /throw new Error\(/,
  "Missing environment config must fail closed");

console.log("PASS: static KRIM environment-isolation safeguards verified.");
