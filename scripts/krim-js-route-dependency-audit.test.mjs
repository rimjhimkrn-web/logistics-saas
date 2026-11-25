import test from "node:test";
import assert from "node:assert/strict";
import {extractNavigation,auditJavaScriptFiles} from "./krim-js-route-dependency-audit.mjs";

test("extracts location assignments and replace calls",()=>{
 const rows=extractNavigation('window.location.href = "/auth/login.html";\nlocation.replace("/app/customer/index.html");',"a.js");
 assert(rows.some(x=>x.mechanism==="location-navigation" && x.target==="/auth/login.html"));
 assert(rows.some(x=>x.mechanism==="location-navigation" && x.target==="/app/customer/index.html"));
});
test("extracts history, router and window.open navigation",()=>{
 const src='history.pushState({}, "", "/public/about.html");\nrouter.push("/app/driver/");\nwindow.open("/auth/invitation.html");';
 const rows=extractNavigation(src,"b.ts");
 assert(rows.some(x=>x.mechanism==="history-navigation"));
 assert(rows.some(x=>x.mechanism==="router-navigation"));
 assert(rows.some(x=>x.mechanism==="window-open"));
});
test("flags dynamic templates as low-confidence candidates",()=>{
 const rows=extractNavigation('window.location.href = `/src/shipments/details.html?id=${id}`;',"c.js");
 assert(rows.some(x=>x.target_type==="template-dynamic" && x.route_like && x.confidence==="low"));
});
test("records href assignment and setAttribute targets",()=>{
 const rows=extractNavigation('link.href = "../auth/reset-password.html";\nnode.setAttribute("href", "/public/tracking.html");',"d.js");
 assert(rows.some(x=>x.mechanism==="href-assignment"));
 assert(rows.some(x=>x.mechanism==="set-attribute-navigation"));
});
test("aggregates file and finding counts deterministically",()=>{
 const report=auditJavaScriptFiles(new Map([["z.js",'location.href="/index.html"'],["a.ts",'navigate("/auth/login.html")']]));
 assert.equal(report.totals.source_files,2);
 assert(report.totals.navigation_findings>=2);
 assert.equal(report.totals.unique_source_files_with_findings,2);
});
