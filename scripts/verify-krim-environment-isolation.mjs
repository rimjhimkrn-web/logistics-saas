import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
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
    hostname: "pr-123--krim.netlify.app",
    presetEnvironment: "",
    expectedEnvironment: "preview",
    expectedUrl: "https://qrpcivhdxobiaofppbkl.supabase.co"
  },
  {
    hostname: "krim-git-feature.vercel.app",
    presetEnvironment: "",
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


function collectFiles(directory, extension, results = []) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    if (entry.name === "node_modules" || entry.name === ".git" ||
        entry.name === "audit-output" || entry.name === "_site") continue;
    const fullPath = join(directory, entry.name);
    if (entry.isDirectory()) collectFiles(fullPath, extension, results);
    else if (entry.isFile() && entry.name.endsWith(extension)) results.push(fullPath);
  }
  return results;
}

const htmlFiles = collectFiles(".", ".html");
const jsFiles = collectFiles(".", ".js");
const unsafeReferences = [];
const clientWithoutConfig = [];
const sharedModuleNames = [
  "krim-account-actions.js",
  "auth-core.js",
  "app-store.js",
  "backend-modules.js"
];
const sharedModuleConsumers = [];
const sharedModulePagesWithoutConfig = [];

for (const path of htmlFiles) {
  const html = readFileSync(path, "utf8");
  const referencedModules = sharedModuleNames.filter(name => html.includes(name));
  if (referencedModules.length) {
    sharedModuleConsumers.push({ path, modules: referencedModules });
    const configTag = html.search(/<script[^>]+src=["'][^"']*platform\/krim-config\.js[^"']*["'][^>]*>/i);
    const moduleTag = html.search(/<script[^>]*type=["']module["'][^>]*>/i);
    if (configTag === -1 || (moduleTag !== -1 && configTag > moduleTag)) {
      sharedModulePagesWithoutConfig.push(path);
    }
  }
  if (
    html.includes("ebltviniygljwwseplph.supabase.co") ||
    html.includes("sb_publishable_8xzZUeubYp_nIxVRWEQdiw_2H4RkHAa")
  ) unsafeReferences.push(path);

  const configIndex = html.indexOf("platform/krim-config.js");
  const clientIndex = html.indexOf("platform/krim-supabase.js");
  if (clientIndex !== -1 && (configIndex === -1 || configIndex > clientIndex)) {
    clientWithoutConfig.push(path);
  }
}

for (const path of jsFiles) {
  // These two files are the approved environment-to-project mapping sources.
  if (path === "platform/krim-config.js" || path === "config.js") continue;
  const source = readFileSync(path, "utf8");
  if (
    source.includes("ebltviniygljwwseplph.supabase.co") ||
    source.includes("sb_publishable_8xzZUeubYp_nIxVRWEQdiw_2H4RkHAa")
  ) unsafeReferences.push(path);
}

const adminGuard = readFileSync("auth/krim-admin-guard.js", "utf8");
assert.ok(adminGuard.includes("platform/krim-config.js"),
  "Admin guard must load the canonical environment configuration");
assert.ok(adminGuard.includes("config.url") && adminGuard.includes("config.publishableKey"),
  "Admin guard must use environment-specific Supabase settings");
assert.ok(!adminGuard.includes("ebltviniygljwwseplph.supabase.co"),
  "Admin guard must not hardcode the production Supabase URL");
assert.ok(!adminGuard.includes("sb_publishable_8xzZUeubYp_nIxVRWEQdiw_2H4RkHAa"),
  "Admin guard must not hardcode the production publishable key");

assert.deepEqual(unsafeReferences, [],
  "First-party HTML/JS must not hardcode production Supabase credentials");
assert.deepEqual(clientWithoutConfig, [],
  "Pages importing the shared Supabase client must load environment config first");
const sharedModulePaths = [
  ["auth/krim-account-actions.js", "../platform/krim-config.js"],
  ["auth-core.js", "./platform/krim-config.js"],
  ["public/app/app-store.js", "../../platform/krim-config.js"],
  ["public/app/backend-modules.js", "../../platform/krim-config.js"]
];
for (const [path, relativeConfigPath] of sharedModulePaths) {
  const source = readFileSync(path, "utf8");
  assert.ok(source.includes("KRIM.platformConfigLoad"),
    `${path} must coordinate a single shared config-load promise`);
  assert.ok(source.includes(`new URL("${relativeConfigPath}", import.meta.url)`),
    `${path} must resolve canonical config relative to its own module URL`);
  assert.ok(source.includes("await globalThis[loadKey]"),
    `${path} must await config initialization before creating a Supabase client`);
  assert.ok(source.indexOf("const config = await") < source.indexOf("createClient("),
    `${path} must initialize config before createClient`);
}

console.log(`Scanned ${htmlFiles.length} HTML and ${jsFiles.length} JS files for environment leakage.`);
console.log(`Found ${sharedModuleConsumers.length} HTML pages referencing repaired shared modules; those modules now bootstrap canonical config themselves.`);

console.log("PASS: KRIM environment isolation runtime regression checks.");
