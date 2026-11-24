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

const has = (source, fragment, message) => assert.ok(source.includes(fragment), message || `Missing source contract: ${fragment}`);

test("partner gateway derives organisations from authenticated active memberships", () => {
  has(gateway, 'from("krim_organization_members")');
  has(gateway, '.eq("user_id",data.user.id).eq("status","active")');
  has(gateway, 'from("krim_organizations")');
  has(gateway, '.in("id",ids)');
  has(gateway, 'String(org.status||"").toLowerCase()==="active"');
});

test("multiple organisations require explicit selection and a fresh active match", () => {
  has(gateway, 'id="organisation-picker"');
  has(gateway, 'matches.filter(org=>String(org.status||"").toLowerCase()==="active")');
  has(gateway, 'String(org.id)===savedId&&String(org.status||"").toLowerCase()==="active"');
  has(gateway, "krim_user_app_preferences");
  has(gateway, "No workspace was opened.");
});

test("each partner pathway revalidates the saved selection against active memberships", () => {
  for (const source of workspaces) {
    has(source, 'from("krim_organization_members")');
    has(source, 'from("krim_user_app_preferences")');
    has(source, 'String(o.status||"").toLowerCase()==="active"');
    has(source, 'String(o.id)===selectedId&&String(o.status||"").toLowerCase()==="active"');
    has(source, 'location.replace("../../../app/partner/index.html")');
    assert.doesNotMatch(source, /if\(matches\.length>1\)\{setError\("Organisation selection required"/);
  }
});

test("shared app store exposes only active memberships attached to active organisations", () => {
  has(store, "krim_organizations(id,display_name,legal_name,status,default_currency_code,timezone)");
  has(store, 'm.status === "active" && String(m.krim_organizations?.status || "").toLowerCase() === "active"');
  has(store, 'this.state.availableOrgs.find(o => String(o.id) === String(this.state.preferences.activeOrganizationId))');
});

test("organisation preference is persisted before shared UI context changes", () => {
  const persist = store.indexOf('await supabase.from("krim_user_app_preferences").upsert');
  const update = store.indexOf("this.state.currentOrg = target", persist);
  assert.ok(persist >= 0 && update > persist, "preference write must precede currentOrg mutation");
});
