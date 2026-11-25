import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";

const configSource = readFileSync("config.js", "utf8");

function boot(hostname, search = "") {
  let created = null;
  const window = {
    location: { hostname, pathname: "/logistics-saas/", search },
    KRIM_ENVIRONMENT: "production",
    KRIM_SUPABASE: { legacy: true },
    supabaseClient: { legacy: true },
    supabase: {
      createClient(url, key, options) {
        created = { url, key, options };
        return created;
      },
    },
  };
  const sandbox = { window, document: { querySelector: () => ({ content: "production" }) }, URL, URLSearchParams, Object, String };
  return { window, created: () => created, sandbox };
}

const allowed = [
  ["krim-staging.pages.dev", "preview", "qrpcivhdxobiaofppbkl"],
  ["pr-42.krim-staging.pages.dev", "preview", "qrpcivhdxobiaofppbkl"],
  ["localhost", "development", "qrpcivhdxobiaofppbkl"],
  ["127.0.0.1", "development", "qrpcivhdxobiaofppbkl"],
  ["rimjhimkrn-web.github.io", "production", "ebltviniygljwwseplph"],
];

for (const [host, environment, projectRef] of allowed) {
  const state = boot(host);
  runInNewContext(configSource, state.sandbox);
  assert.equal(state.window.KRIM_ENVIRONMENT, environment, host + " environment");
  assert.equal(state.window.KRIM_SUPABASE_PROJECT_REF, projectRef, host + " project ref");
  assert.equal(state.created()?.url, "https://" + projectRef + ".supabase.co", host + " project URL");
  assert.equal(state.window.KRIM_SUPABASE, state.created(), host + " shared client");
  assert.equal(state.window.KRIM_AUTH_DISABLED, false, host + " authentication remains enabled");
  assert.equal(state.window.KRIM_STAGING_REVIEW_MODE, false, host + " defaults to authenticated/non-review mode");
  assert.notEqual(state.window.KRIM_SUPABASE?.legacy, true, host + " legacy client must not be reused");
}

for (const host of ["unknown.example", "random.pages.dev", "krimlogistics.com"]) {
  const state = boot(host);
  assert.throws(() => runInNewContext(configSource, state.sandbox), /not allowlisted/, host + " must fail closed");
  assert.equal(state.created(), null, host + " must not initialize a client");
  assert.equal(state.window.KRIM_SUPABASE, null, host + " must clear stale client");
  assert.equal(state.window.supabaseClient, null, host + " must clear legacy alias");
}


for (const [search, expected] of [["?mode=review", true], ["?mode=authenticated", false], ["", false]]) {
  const state = boot("krim-staging.pages.dev", search);
  runInNewContext(configSource, state.sandbox);
  assert.equal(state.window.KRIM_STAGING_REVIEW_MODE, expected, "explicit staging review selector " + search);
  assert.equal(state.window.KRIM_AUTH_DISABLED, false, "review selector never disables Supabase auth");
}

const partnerOnboarding = readFileSync("public/partner/partner-onboarding.html", "utf8");
assert.ok(partnerOnboarding.includes("window.KRIM_STAGING_REVIEW_MODE === true"),
  "partner onboarding must use explicit review-mode flag");
assert.equal(partnerOnboarding.includes('location.hostname === "krim-staging.pages.dev" ||'), false,
  "partner onboarding must not force review mode for every staging visitor");
const partnerSignup = readFileSync("auth/partner-signup.html", "utf8");
assert.ok(partnerSignup.includes("window.KRIM_STAGING_REVIEW_MODE===true"),
  "partner signup must use explicit review-mode flag");
assert.equal(partnerSignup.includes('location.hostname.endsWith(".pages.dev")'), false,
  "partner signup must not treat every Pages preview hostname as review mode");

const partnerSignIn = readFileSync("auth/partner-signin.html", "utf8");
assert.ok(partnerSignIn.includes("window.KRIM_STAGING_REVIEW_MODE===true"),
  "partner sign-in must use explicit review-mode flag");
assert.equal(partnerSignIn.includes('location.hostname==="krim-staging.pages.dev"||'), false,
  "partner sign-in must not disable credentials for every staging visitor");

const staticGuards = [
  ["app/platform-admin/index.html", "https://ebltviniygljwwseplph.supabase.co"],
  ["auth/krim-admin-guard.js", "https://ebltviniygljwwseplph.supabase.co"],
  ["auth/krim-admin-access.html", "https://qrpcivhdxobiaofppbkl.supabase.co"],
  ["platform/krim-config.js", "https://ebltviniygljwwseplph.supabase.co"],
];
for (const [path, forbidden] of staticGuards) {
  assert.equal(readFileSync(path, "utf8").includes(forbidden), false, path + " must not hard-code a project URL");
}

const bootstraps = [
  ["public/admin/security-desk.html", "../../config.js"],
  ["public/app/shared/security-manager.html", "../../../config.js"],
  ["public/production/security-hardening.html", "../../config.js"],
];
for (const [path, relativeConfig] of bootstraps) {
  const page = readFileSync(path, "utf8");
  const sdk = page.indexOf("cdn.jsdelivr.net/npm/@supabase/supabase-js@2");
  const config = page.indexOf('src="' + relativeConfig + '"');
  const guard = page.indexOf("krim-admin-guard.js");
  assert.ok(sdk >= 0 && config > sdk && guard > config, path + " SDK/config must load before admin guard");
}

console.log("KRIM environment isolation tests passed: " + allowed.length + " allowed hosts, 3 blocked hosts, explicit review/authenticated staging mode checks, 4 static guards, 3 privileged bootstraps.");
