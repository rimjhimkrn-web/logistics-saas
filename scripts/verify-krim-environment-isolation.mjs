import { readFileSync } from "node:fs";
import assert from "node:assert/strict";
import { runInNewContext } from "node:vm";

const config = readFileSync("platform/krim-config.js", "utf8");
const client = readFileSync("platform/krim-supabase.js", "utf8");
const shipments = readFileSync("domains/shipments.html", "utf8");

// Execute the real configuration in isolated browser-like contexts.
const cases = [
  {
    hostname: "krim-staging.pages.dev",
    presetEnvironment: "production",
    expectedEnvironment: "preview",
    expectedUrl: "https://qrpcivhdxobiaofppbkl.supabase.co"
  },
  {
    hostname: "feature.krim-staging.pages.dev",
    presetEnvironment: "production",
    expectedEnvironment: "preview",
    expectedUrl: "https://qrpcivhdxobiaofppbkl.supabase.co"
  },
  {
    hostname: "rimjhimkrn-web.github.io",
    presetEnvironment: "",
    expectedEnvironment: "production",
    expectedUrl: "https://ebltviniygljwwseplph.supabase.co"
  },
  {
    hostname: "localhost",
    presetEnvironment: "",
    expectedEnvironment: "development",
    expectedUrl: "https://qrpcivhdxobiaofppbkl.supabase.co"
  }
];

for (const testCase of cases) {
  const window = {
    location: {
      hostname: testCase.hostname,
      pathname: "/logistics-saas/workspaces/customer-workspace.html"
    },
    KRIM_ENVIRONMENT: testCase.presetEnvironment
  };
  const document = {
    scripts: [],
    querySelector: () => null
  };

  runInNewContext(config, { window, document, URL, console });

  assert.equal(
    window.KRIM_CONFIG.platform.environment,
    testCase.expectedEnvironment,
    `Unexpected environment for ${testCase.hostname}`
  );
  assert.equal(
    window.KRIM_CONFIG.supabase.url,
    testCase.expectedUrl,
    `Unexpected Supabase project for ${testCase.hostname}`
  );
}

// Staging hostname must override a conflicting page/global environment value.
assert.ok(
  config.indexOf('hostname === "krim-staging.pages.dev"') <
    config.indexOf("const configured ="),
  "Cloudflare staging host must override page metadata and global environment flags"
);

// Supabase client must fail closed rather than silently default to production.
assert.ok(
  !client.includes('||\n  "https://ebltviniygljwwseplph.supabase.co"'),
  "Supabase client must not silently fall back to production URL"
);
assert.ok(
  !client.includes('||\n  "sb_publishable_8xzZUeubYp_nIxVRWEQdiw_2H4RkHAa"'),
  "Supabase client must not silently fall back to production key"
);
assert.ok(client.includes("throw new Error("), "Missing config must fail closed");

// Shipment page must use the shared environment-aware config, not old hardcoding.
assert.ok(shipments.includes("../platform/krim-config.js"),
  "Shipment page must load canonical environment configuration");
assert.ok(shipments.includes("window.KRIM_CONFIG?.supabase"),
  "Shipment page must use the environment-specific Supabase config");
assert.ok(!shipments.includes("ebltviniygljwwseplph.supabase.co"),
  "Shipment page must not hardcode the production project URL");
assert.ok(!shipments.includes("SUPABASE_ANON_KEY"),
  "Shipment page must not retain its legacy hardcoded anon key");

console.log("PASS: KRIM environment isolation runtime regression checks.");
