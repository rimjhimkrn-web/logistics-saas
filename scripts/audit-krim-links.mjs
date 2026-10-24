#!/usr/bin/env node
/**
 * KRIM static route audit.
 * Run from the repository root: node scripts/audit-krim-links.mjs
 * Checks local href/src/action references without changing or deleting files.
 */
import fs from "node:fs";
import path from "node:path";

const ROOT = process.cwd();
const IGNORE_DIRS = new Set([".git", "node_modules", ".github"]);
const HTML_ATTRS = ["href", "src", "action", "formaction", "poster"];
const errors = [];
let htmlCount = 0;

function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (IGNORE_DIRS.has(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (entry.isFile() && entry.name.toLowerCase().endsWith(".html")) {
      htmlCount++;
      inspectHtml(full);
    }
  }
}

function resolveLocalTarget(sourceFile, rawValue) {
  let value = rawValue.trim().replaceAll("&amp;", "&");
  if (!value || value.startsWith("#") || value.startsWith("{{") ||
      /^(?:[a-z][a-z0-9+.-]*:|\/\/)/i.test(value)) return null;

  try {
    value = decodeURIComponent(value.split(/[?#]/, 1)[0]);
  } catch {
    errors.push({ source: rel(sourceFile), target: rawValue, reason: "invalid URL encoding" });
    return null;
  }
  if (!value) return null;

  // GitHub Pages serves this repository beneath /logistics-saas/.
  if (value.startsWith("/logistics-saas/")) value = value.slice("/logistics-saas/".length);
  else if (value.startsWith("/")) value = value.slice(1);

  let target = path.normalize(value.startsWith("/")
    ? path.join(ROOT, value)
    : path.resolve(path.dirname(sourceFile), value));

  if (!target.startsWith(ROOT + path.sep) && target !== ROOT) {
    errors.push({ source: rel(sourceFile), target: rawValue, reason: "path escapes repository root" });
    return null;
  }
  if (fs.existsSync(target) && fs.statSync(target).isDirectory()) target = path.join(target, "index.html");
  return target;
}

function rel(file) {
  return path.relative(ROOT, file).split(path.sep).join("/");
}

function inspectHtml(file) {
  const text = fs.readFileSync(file, "utf8");
  const tagPattern = /<(?:a|link|script|img|iframe|form|source|video|audio|button)\b[^>]*>/gi;
  let tag;
  while ((tag = tagPattern.exec(text))) {
    const attrPattern = /\b(href|src|action|formaction|poster)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/gi;
    let attr;
    while ((attr = attrPattern.exec(tag[0]))) {
      const value = attr[2] ?? attr[3] ?? attr[4] ?? "";
      const target = resolveLocalTarget(file, value);
      if (!target) continue;
      if (!fs.existsSync(target) || !fs.statSync(target).isFile()) {
        errors.push({
          source: rel(file),
          target: value,
          reason: "local target does not exist",
          resolved: rel(target)
        });
      }
    }
  }
}

walk(ROOT);
console.log(JSON.stringify({
  audit: "KRIM static local-link audit",
  root: ROOT,
  html_files_scanned: htmlCount,
  broken_local_references: errors.length,
  findings: errors
}, null, 2));
process.exitCode = errors.length ? 1 : 0;
