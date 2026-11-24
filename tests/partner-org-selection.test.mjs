import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const read = (path) => readFileSync(path, "utf8");
const gateway = read("app/partner/index.html");
const store = read("public/app/app-store.js");
const workspaces = [
  "app/partner/development/index.html",
  "app/partner/individual/index.html",
  "app/partner/business/index.html"
].map(read);

test("partner gateway derives organisations from authenticated active memberships", () => {
  assert.match(gateway, /from\("krim_organization_members"\)[\s\S]{0,180}\.eq\("user_id",data\.user\.id\)[\s\S]{0,80}\.eq\("status","active"\)/);
  assert.match(gateway, /from\("krim_organizations"\)[\s\S]{0,250}\.in\("id",ids\)/);
  assert.match(gateway, /String\(org\.status\|\|"\)\.toLowerCase\(\)!=="active"/);
});

test("multiple organisations require an explicit selection and a fresh active membership match", () => {
  assert.match(gateway, /id="organisation-picker"/);
  assert.match(gateway, /matches\.filter\(org=>String\(org\.status\|\|"\)\.toLowerCase\(\)==="active"\)/);
  assert.match(gateway, /String\(org\.id\)===savedId&&String\(org\.status\|\|"\)\.toLowerCase\(\)==="active"/);
  assert.match(gateway, /krim_user_app_preferences/);
  assert.match(gateway, /if\(saveError\)[\s\S]{0,120}No workspace was opened/);
});

test("each partner pathway revalidates the saved selection against active memberships", () => {
  for (const source of workspaces) {
    assert.match(source, /from\("krim_organization_members"\)/);
    assert.match(source, /from\("krim_user_app_preferences"\)/);
    assert.match(source, /String\(o\.id\)===selectedId&&String\(o\.status\|\|"\)\.toLowerCase\(\)==="active"/);
    assert.match(source, /location\.replace\("\.\.\/\.\.\/\.\.\/app\/partner\/index\.html"\)/);
    assert.doesNotMatch(source, /if\(matches\.length>1\)\{setError\("Organisation selection required"/);
  }
});

test("shared app store exposes only active memberships attached to active organisations", () => {
  assert.match(store, /krim_organizations\(id,display_name,legal_name,status,default_currency_code,timezone\)/);
  assert.match(store, /m\.status === "active" && String\(m\.krim_organizations\?\.status \|\| ""\)\.toLowerCase\(\) === "active"/);
  assert.match(store, /this\.state\.availableOrgs\.find\(o => String\(o\.id\) === String\(this\.state\.preferences\.activeOrganizationId\)\)/);
});

test("organisation preference is persisted before shared UI context changes", () => {
  const persist = store.indexOf("await supabase.from(\"krim_user_app_preferences\").upsert");
  const update = store.indexOf("this.state.currentOrg = target", persist);
  assert.ok(persist >= 0 && update > persist, "preference write must precede currentOrg mutation");
});
