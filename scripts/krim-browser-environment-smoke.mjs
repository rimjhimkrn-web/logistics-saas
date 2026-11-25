import assert from "node:assert/strict";
import { chromium } from "playwright";

const browser = await chromium.launch({
  headless: true,
  args: ["--no-sandbox", "--no-proxy-server", "--ignore-certificate-errors", "--host-resolver-rules=MAP krim-staging.pages.dev 127.0.0.1,MAP unknown.krim-test.invalid 127.0.0.1"]
});

const pageErrors = [];
try {
  const context = await browser.newContext();
  const page = await context.newPage();
  page.on("pageerror", error => pageErrors.push(error.message));

  // Use the exact allowlisted Staging hostname while routing it to the local
  // static fixture server. No request is sent to the real Staging site.
  await page.goto("https://krim-staging.pages.dev:4173/scripts/browser-environment-smoke.html?mode=review");
  const staging = await page.evaluate(() => ({
    loaded: window.__krimFixtureLoaded === true,
    environment: window.KRIM_ENVIRONMENT,
    projectRef: window.KRIM_SUPABASE_PROJECT_REF,
    clientUrl: window.KRIM_SUPABASE?.url,
    callCount: window.__krimCreateClientCalls?.length,
    authDisabled: window.KRIM_AUTH_DISABLED,
    reviewMode: window.KRIM_STAGING_REVIEW_MODE,
    legacyClientReplaced: window.KRIM_SUPABASE?.fixture === true,
    persistSession: window.KRIM_SUPABASE?.options?.auth?.persistSession,
    flowType: window.KRIM_SUPABASE?.options?.auth?.flowType
  }));
  assert.deepEqual(staging, {
    loaded: true,
    environment: "preview",
    projectRef: "qrpcivhdxobiaofppbkl",
    clientUrl: "https://qrpcivhdxobiaofppbkl.supabase.co",
    callCount: 1,
    authDisabled: false,
    reviewMode: true,
    legacyClientReplaced: true,
    persistSession: true,
    flowType: "pkce"
  }, "Staging hostname must select Staging and retain enabled authentication");
  assert.equal(pageErrors.length, 0, "Staging fixture must not emit browser errors");

  // Unknown host is deliberately mapped to the local fixture server. The
  // config must throw before createClient; no external Supabase request exists.
  await page.goto("https://unknown.krim-test.invalid:4173/scripts/browser-environment-smoke.html");
  const blocked = await page.evaluate(() => ({
    loaded: window.__krimFixtureLoaded === true,
    environment: window.KRIM_ENVIRONMENT ?? null,
    projectRef: window.KRIM_SUPABASE_PROJECT_REF ?? null,
    callCount: window.__krimCreateClientCalls?.length ?? 0,
    client: window.KRIM_SUPABASE ?? null,
    legacyClient: window.supabaseClient ?? null
  }));
  assert.equal(blocked.loaded, false, "Unknown host must stop before fixture completion");
  assert.equal(blocked.environment, null, "Unknown host must not resolve an environment");
  assert.equal(blocked.projectRef, null, "Unknown host must not select a project");
  assert.equal(blocked.callCount, 0, "Unknown host must not initialize Supabase");
  assert.equal(blocked.client, null, "Unknown host must clear any stale client");
  assert.equal(blocked.legacyClient, null, "Unknown host must clear legacy client alias");
  assert.equal(pageErrors.length, 1, "Unknown host should produce exactly the expected fail-closed page error");
  assert.match(pageErrors[0], /hostname is not allowlisted/, "Unknown host error must identify the allowlist block");

  console.log("KRIM Chromium environment smoke passed: Staging hostname mapping, PKCE/auth flags, explicit review mode, stale-client replacement, and unknown-host fail-closed behavior.");
} finally {
  await browser.close();
}
