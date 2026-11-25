import test from "node:test";
import assert from "node:assert/strict";
import { normalizeLocalTarget, extractHtmlReferences, auditHtmlFiles } from "./krim-route-graph-audit.mjs";

const known = new Set(["index.html","public/index.html","public/about.html","app/customer/index.html","nested/page.html","nested/child.html","assets/app.js"]);
test("resolves relative HTML and query/hash suffixes",()=>{
  assert.deepEqual(normalizeLocalTarget("nested/page.html","child.html?x=1#top",known),{kind:"local",target:"nested/child.html"});
});
test("resolves GitHub Pages project-prefixed root path",()=>{
  assert.deepEqual(normalizeLocalTarget("nested/page.html","/logistics-saas/public/about.html",known),{kind:"local",target:"public/about.html"});
});
test("resolves ordinary root-relative path from repository root",()=>{
  assert.deepEqual(normalizeLocalTarget("nested/page.html","/app/customer/",known),{kind:"local",target:"app/customer/index.html"});
});
test("resolves public mirror and directory index candidates",()=>{
  assert.deepEqual(normalizeLocalTarget("index.html","about",known),{kind:"local",target:"public/about.html"});
});
test("skips external, fragment and dynamic template references",()=>{
  for(const value of ["https://example.com","//cdn.example.com/a.js","#section","mailto:a@b.com","{{route}}","/x/${id}"])
    assert.equal(normalizeLocalTarget("index.html",value,known).kind,"skip");
});
test("rejects paths escaping repository root and invalid encoding",()=>{
  assert.equal(normalizeLocalTarget("index.html","../../secret.html",known).reason,"path-escapes-repository");
  assert.equal(normalizeLocalTarget("index.html","/%E0%A4%A",known).reason,"invalid-url-encoding");
});
test("extracts literal attributes but ignores scripts, styles and comments",()=>{
  const html='<a href="about.html">A</a><script>location.href="/fake.html";</script><style>.x{}</style><!-- <a href="fake.html"> -->';
  assert.deepEqual(extractHtmlReferences(html).map(x=>x.raw),["about.html"]);
});
test("builds per-page inbound graph, noindex and redirect evidence",()=>{
  const report=auditHtmlFiles(new Map([
    ["index.html",'<head><meta name="robots" content="noindex,nofollow"><meta http-equiv="refresh" content="0; url=/public/about.html"></head><a href="/app/customer/">C</a>'],
    ["public/about.html","<title>About</title>"],
    ["app/customer/index.html","<a href=\"/public/about.html\">About</a>"]
  ]));
  assert.equal(report.totals.html_pages,3);
  assert.equal(report.totals.inbound_edges,2);
  assert.equal(report.totals.pages_with_inbound,2);
  assert.deepEqual(report.zero_inbound_paths,["index.html"]);
  assert.deepEqual(report.noindex_paths,["index.html"]);
  assert.equal(report.redirects[0].candidates[0].mechanism,"meta-refresh");
});

test("excludes static assets and non-navigation resource attributes",()=>{
  assert.equal(normalizeLocalTarget("index.html","/assets/logo.svg",known).kind,"skip");
  const html='<script src="assets/app.js"></script><img src="logo.png"><link rel="stylesheet" href="site.css"><a href="about.html">About</a>';
  assert.deepEqual(extractHtmlReferences(html).map(x=>x.raw),["about.html"]);
});
