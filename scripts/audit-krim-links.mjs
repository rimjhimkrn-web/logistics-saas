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
  const rootRelative = value.startsWith("/");
  if (value.startsWith("/logistics-saas/")) value = value.slice("/logistics-saas/".length);
  else if (rootRelative) value = value.slice(1);

  // Root-relative URLs resolve from the repository/publishing root, not from
  // the directory containing the current HTML file.
  let target = path.normalize(rootRelative
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
    const attrPattern = /(?:^|\s)(href|src|action|formaction|poster)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/gi;
    let attr;
    while ((attr = attrPattern.exec(tag[0]))) {
      const value = attr[2] ?? attr[3] ?? attr[4] ?? "";
      // JavaScript-built hrefs appear as fragments such as "'+base+'..."; they are not literal paths.
      if (value.includes("+") || value.includes("${") || value.includes("`")) continue;
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

// Verify every destination declared in the canonical route registry exists.
// This catches route-map drift even when a page is not linked by a static anchor.
const canonicalRoutes = [];
const configPath = path.join(ROOT, "config.js");
if (fs.existsSync(configPath)) {
  const configText = fs.readFileSync(configPath, "utf8");
  const registryMatch = configText.match(/window\.KRIM_ROUTES\s*=\s*Object\.freeze\(\s*\{([\s\S]*?)\n\}\s*\)/);
  if (!registryMatch) {
    errors.push({ source: "config.js", target: "window.KRIM_ROUTES", reason: "canonical route registry not found" });
  } else {
    const routePattern = /([A-Za-z_$][\w$]*)\s*:\s*["']([^"']+)["']/g;
    let routeMatch;
    while ((routeMatch = routePattern.exec(registryMatch[1]))) {
      const key = routeMatch[1];
      const routePath = routeMatch[2];
      canonicalRoutes.push({ key, path: routePath });
      const target = path.resolve(ROOT, routePath);
      if (!target.startsWith(ROOT + path.sep) || !fs.existsSync(target) || !fs.statSync(target).isFile()) {
        errors.push({ source: "config.js", route: key, target: routePath, reason: "canonical route target does not exist" });
      }
    }
  }
} else {
  errors.push({ source: "config.js", target: "config.js", reason: "shared configuration file missing" });
}

console.log(JSON.stringify({
  audit: "KRIM static local-link audit",
  root: ROOT,
  html_files_scanned: htmlCount,
  canonical_routes_checked: canonicalRoutes.length,
  broken_local_references: errors.length,
  findings: errors
}, null, 2));
process.exitCode = errors.length ? 1 : 0;
