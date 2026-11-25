#!/usr/bin/env node
/**
 * Deterministic, read-only HTML route graph audit.
 * Usage: node scripts/krim-route-graph-audit.mjs [repository-root] [output-dir]
 * Static evidence only: does not execute JavaScript or prove deployed reachability.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const IGNORE_DIRS = new Set([".git", "node_modules", ".next", "dist", "build"]);
const ATTR_RE = /(?:^|\s)(href|src|action|data-href|formaction)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/gi;
const SCRIPT_RE = /(<script\b[^>]*>)[\s\S]*?<\/script\s*>/gi;
const STYLE_RE = /<style\b[^>]*>[\s\S]*?<\/style\s*>/gi;
const COMMENT_RE = /<!--[\s\S]*?-->/g;

function decodePath(value) {
  try { return decodeURIComponent(value); }
  catch { return null; }
}
function stripSuffix(value) { return value.split(/[?#]/, 1)[0]; }
function isExternal(value) {
  return /^(?:[a-z][a-z0-9+.-]*:|\/\/|#)/i.test(value);
}

/** Normalize a literal local reference to a tracked HTML path. */
export function normalizeLocalTarget(sourcePath, rawValue, knownPaths) {
  const raw = String(rawValue ?? "").trim().replaceAll("&amp;", "&");
  if (!raw || isExternal(raw) || raw.includes("${") || raw.includes("{{")) return { kind: "skip" };
  const clean = stripSuffix(raw);
  if (!clean) return { kind: "skip" };
  const decoded = decodePath(clean);
  if (decoded === null) return { kind: "unresolved", reason: "invalid-url-encoding" };
  let candidate;
  if (decoded.startsWith("/logistics-saas/")) candidate = decoded.slice("/logistics-saas/".length);
  else if (decoded.startsWith("/")) candidate = decoded.slice(1);
  else candidate = path.posix.join(path.posix.dirname(sourcePath), decoded);
  const parts = [];
  for (const part of candidate.split("/")) {
    if (!part || part === ".") continue;
    if (part === "..") {
      if (!parts.length) return { kind: "unresolved", reason: "path-escapes-repository" };
      parts.pop();
    } else parts.push(part);
  }
  candidate = parts.join("/");
  const candidates = [candidate];
  if (candidate && !candidate.endsWith(".html")) candidates.push(candidate + ".html");
  candidates.push(candidate ? candidate.replace(/\/$/, "") + "/index.html" : "index.html");
  if (candidate.startsWith("public/")) {
    const short = candidate.slice("public/".length);
    candidates.push(short, short + ".html", short + "/index.html");
  } else {
    candidates.push("public/" + candidate, "public/" + candidate + ".html", "public/" + candidate + "/index.html");
  }
  const target = candidates.find(item => knownPaths.has(item));
  return target ? { kind: "local", target } : { kind: "unresolved", reason: "target-not-in-html-inventory", candidate };
}

function attributes(tag) {
  const result = {};
  for (const match of tag.matchAll(/([\w:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/g)) {
    result[match[1].toLowerCase()] = match[2] ?? match[3] ?? match[4] ?? "";
  }
  return result;
}
export function extractHtmlReferences(html) {
  const clean = html.replace(COMMENT_RE, " ").replace(SCRIPT_RE, "$1").replace(STYLE_RE, " ");
  const refs = [];
  for (const match of clean.matchAll(/<(?:a|area|link|script|img|iframe|form|source|video|audio|button)\b[^>]*>/gi)) {
    const tag = match[0];
    const tagName = (tag.match(/^<([\w-]+)/) || [,""])[1].toLowerCase();
    const attrs = attributes(tag);
    for (const name of ["href", "src", "action", "data-href", "formaction"]) {
      if (attrs[name] !== undefined) refs.push({ attribute: name, tag: tagName, raw: attrs[name] });
    }
  }
  return refs;
}
function hasNoindex(html) {
  const head = (html.match(/<head\b[\s\S]*?<\/head\s*>/i) || [html])[0];
  for (const tag of head.matchAll(/<meta\b[^>]*>/gi)) {
    const attrs = attributes(tag[0]);
    if ((attrs.name || "").toLowerCase() === "robots" && /\bnoindex\b/i.test(attrs.content || "")) return true;
  }
  return false;
}
function redirectCandidates(html) {
  const results = [];
  const head = (html.match(/<head\b[\s\S]*?<\/head\s*>/i) || [html])[0];
  for (const tag of head.matchAll(/<meta\b[^>]*>/gi)) {
    const attrs = attributes(tag[0]);
    if ((attrs["http-equiv"] || "").toLowerCase() === "refresh") {
      const match = (attrs.content || "").match(/(?:^|;)\s*\d+\s*;\s*url\s*=\s*["']?([^"']+)["']?/i);
      results.push({ mechanism: "meta-refresh", target: match ? match[1].trim() : null });
    }
  }
  for (const match of html.matchAll(/(?:window\.)?location\.replace\s*\(\s*["'`]([^"'`]+)["'`]\s*\)/gi))
    results.push({ mechanism: "location.replace-literal", target: match[1] });
  for (const match of html.matchAll(/(?:window\.)?location(?:\.href)?\s*=\s*["'`]([^"'`]+)["'`]/gi))
    results.push({ mechanism: "location-assignment-literal", target: match[1] });
  return results;
}
function walk(root, dir = root) {
  const output = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true }).sort((a,b)=>a.name.localeCompare(b.name))) {
    if (entry.isDirectory() && IGNORE_DIRS.has(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) output.push(...walk(root, full));
    else if (entry.isFile() && entry.name.toLowerCase().endsWith(".html")) output.push(path.relative(root, full).split(path.sep).join("/"));
  }
  return output.sort();
}
export function auditHtmlFiles(fileMap) {
  const paths = [...fileMap.keys()].sort();
  const known = new Set(paths);
  const inbound = new Map(paths.map(p => [p, []]));
  const unresolved = [], redirects = [], noindex = [];
  for (const source of paths) {
    const html = fileMap.get(source);
    if (hasNoindex(html)) noindex.push(source);
    const redirect = redirectCandidates(html);
    if (redirect.length) redirects.push({ path: source, candidates: redirect });
    for (const ref of extractHtmlReferences(html)) {
      const resolved = normalizeLocalTarget(source, ref.raw, known);
      if (resolved.kind === "local") inbound.get(resolved.target).push({ source, attribute: ref.attribute, raw: ref.raw });
      else if (resolved.kind === "unresolved") unresolved.push({ source, attribute: ref.attribute, raw: ref.raw, reason: resolved.reason, candidate: resolved.candidate ?? null });
    }
  }
  const pages = paths.map(p => {
    const edges = inbound.get(p);
    return { path: p, inbound_edges: edges.length, unique_inbound_sources: new Set(edges.map(e=>e.source)).size, inbound: edges };
  });
  const zero = pages.filter(p => p.inbound_edges === 0).map(p=>p.path);
  return {
    schema_version: 1,
    scope: "Literal HTML attributes only; script bodies are excluded. JavaScript-generated navigation, runtime redirects, HTTP status, authentication and deployed behavior are not tested.",
    totals: {
      html_pages: paths.length,
      inbound_edges: pages.reduce((n,p)=>n+p.inbound_edges,0),
      pages_with_inbound: pages.filter(p=>p.inbound_edges>0).length,
      zero_inbound_pages: zero.length,
      redirect_candidate_pages: redirects.length,
      noindex_pages: noindex.length,
      unresolved_local_references: unresolved.length
    },
    pages, zero_inbound_paths: zero, redirects, noindex_paths: noindex, unresolved
  };
}
function main() {
  const root = path.resolve(process.argv[2] || process.cwd());
  const outDir = path.resolve(process.argv[3] || path.join(root, "audit-output"));
  const paths = walk(root);
  const map = new Map(paths.map(p=>[p,fs.readFileSync(path.join(root,p),"utf8")]));
  const report = auditHtmlFiles(map);
  fs.mkdirSync(outDir,{recursive:true});
  fs.writeFileSync(path.join(outDir,"krim-route-graph.json"),JSON.stringify(report,null,2)+"\n");
  const csv = ["path,inbound_edges,unique_inbound_sources,noindex,redirect_candidate",...report.pages.map(p=>[
    p.path,p.inbound_edges,p.unique_inbound_sources,report.noindex_paths.includes(p.path),report.redirects.some(r=>r.path===p.path)
  ].map(v=>'"'+String(v).replaceAll('"','""')+'"').join(","))].join("\n")+"\n";
  fs.writeFileSync(path.join(outDir,"krim-route-graph.csv"),csv);
  console.log(JSON.stringify({output:outDir,totals:report.totals},null,2));
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
