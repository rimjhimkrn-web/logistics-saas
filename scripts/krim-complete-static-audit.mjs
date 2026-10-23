import { readdirSync, readFileSync, existsSync, mkdirSync, writeFileSync } from "node:fs";
import { join, dirname, resolve, extname, basename } from "node:path";
import { createHash } from "node:crypto";

const ROOT = process.cwd();
const IGNORE = new Set([".git", "node_modules", ".next", "dist", "build"]);
function walk(dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    if (e.isDirectory() && IGNORE.has(e.name)) return [];
    const p = join(dir, e.name);
    return e.isDirectory() ? walk(p) : e.isFile() ? [p] : [];
  });
}
const files = walk(ROOT).map(p => p.replaceAll("\\\\", "/").replace(/^\.\//, ""));
const htmlFiles = files.filter(p => p.toLowerCase().endsWith(".html"));
const fileSet = new Set(files);
const hashOwners = new Map();
const duplicateGroups = [];
const linkIssues = [];
const pageRows = [];
const integrationCandidates = [];
const placeholderPages = [];
const attrRe = /(?:href|src|action|data-href|formaction)\\s*=\\s*["']([^"']+)["']/gi;
const schemeRe = /^(?:[a-z][a-z0-9+.-]*:|\\/\\/|#|mailto:|tel:|javascript:|data:)/i;
function existsCandidate(c) {
  c = c.replace(/^\\.\\//, "").replace(/\\/$/, "");
  if (!c) c = "index.html";
  const opts = [c, join(c, "index.html")];
  if (c.startsWith("public/")) opts.push(c.slice(7), join(c.slice(7), "index.html"));
  else opts.push(join("public", c), join("public", c, "index.html"));
  return opts.some(x => fileSet.has(x) || fileSet.has(x + ".html"));
}
for (const file of htmlFiles) {
  const html = readFileSync(file, "utf8");
  const hash = createHash("sha256").update(html).digest("hex");
  if (hashOwners.has(hash)) {
    const owner = hashOwners.get(hash);
    let group = duplicateGroups.find(g => g.hash === hash);
    if (!group) { group = { hash, paths: [owner] }; duplicateGroups.push(group); }
    group.paths.push(file);
  } else hashOwners.set(hash, file);

  let links = 0, local = 0, bad = 0, absoluteRoot = 0;
  for (const m of html.matchAll(attrRe)) {
    const raw = m[1].trim();
    if (!raw || raw.includes("${") || raw.includes("{{") || raw.includes("<") || schemeRe.test(raw)) continue;
    const clean = raw.split(/[?#]/)[0];
    if (!clean) continue;
    links++;
    let candidates = [];
    if (clean.startsWith("/logistics-saas/")) candidates = [clean.slice("/logistics-saas/".length)];
    else if (clean.startsWith("/")) {
      absoluteRoot++;
      candidates = [clean.slice(1), join("public", clean.slice(1))];
      if (!existsCandidate(candidates[0]) && !existsCandidate(candidates[1])) {
        bad++; linkIssues.push({ type: "unresolved-root-path", source: file, href: raw });
      }
    } else {
      candidates = [resolve(dirname(file), clean).replaceAll("\\\\", "/")];
      if (!existsCandidate(candidates[0])) {
        bad++; linkIssues.push({ type: "missing-local-target", source: file, href: raw, resolved: candidates[0] });
      }
    }
    local++;
  }
  const hasSupabaseSignal = /createClient|supabase\\.from\\(|\\.rpc\\(|functions\\.invoke\\(|SUPABASE_URL|supabase-js/i.test(html);
  const looksOperational = /(?:dashboard|workspace|shipment|booking|quote|payment|invoice|tracking|warehouse|customs|finance|operations|partner|enterprise|driver|global-operations)/i.test(file);
  const placeholder = /placeholder|coming soon|not connected|demo data|sample data|mock data|TODO:.*integrat|connect to supabase/i.test(html);
  if (looksOperational && !hasSupabaseSignal) integrationCandidates.push(file);
  if (placeholder) placeholderPages.push(file);
  pageRows.push({ path: file, links, localLinks: local, unresolved: bad, absoluteRootPaths: absoluteRoot, supabaseSignals: hasSupabaseSignal, placeholderSignals: placeholder });
}
const report = {
  generatedAt: new Date().toISOString(),
  scope: "Static repository scan. Not a browser crawl; JS-built links, runtime authorization, external services and real transactions require separate tests.",
  totals: { files: files.length, htmlPages: htmlFiles.length, duplicateGroups: duplicateGroups.length, unresolvedLocalReferences: linkIssues.length, pagesWithPlaceholderSignals: placeholderPages.length, operationalPageCandidatesWithoutSupabaseSignals: integrationCandidates.length },
  duplicateGroups, linkIssues, placeholderPages, integrationCandidates, pages: pageRows
};
mkdirSync("audit-output", { recursive: true });
writeFileSync("audit-output/krim-complete-audit.json", JSON.stringify(report, null, 2));
const md = [
  "# KRIM Logistics — Automated Static Repository Audit",
  "",
  `Generated: ${report.generatedAt}`,
  "",
  "> Static analysis only. Findings require triage; similar names, absent client-side Supabase references, or placeholder wording are not alone proof of a defect. Server-side/shared-client integration and runtime tests may not be visible in a single HTML file.",
  "",
  "## Summary",
  "",
  `- Files scanned: ${files.length}`,
  `- HTML pages scanned: ${htmlFiles.length}`,
  `- Exact duplicate-content groups: ${duplicateGroups.length}`,
  `- Unresolved local/root link references: ${linkIssues.length}`,
  `- Pages with placeholder/demo/TODO wording signals: ${placeholderPages.length}`,
  `- Operational-looking pages without visible Supabase signals in their own HTML: ${integrationCandidates.length}`,
  "",
  "## Exact duplicate content",
  "",
  ...(duplicateGroups.length ? duplicateGroups.map(g => `- ${g.paths.join(" ↔ ")}`) : ["- None detected."]),
  "",
  "## Unresolved local link references (first 300)",
  "",
  ...(linkIssues.length ? linkIssues.slice(0,300).map(x => `- **${x.type}** — ${x.source}: \`${x.href}\`${x.resolved ? ` → ${x.resolved}` : ""}`) : ["- None detected by this static parser."]),
  ...(linkIssues.length > 300 ? [`- ... ${linkIssues.length-300} additional findings are in the JSON artifact.`] : []),
  "",
  "## Operational-looking pages without visible Supabase references",
  "",
  ...(integrationCandidates.length ? integrationCandidates.map(p => `- ${p}`) : ["- None detected."]),
  "",
  "## Placeholder/demo/TODO wording signals",
  "",
  ...(placeholderPages.length ? placeholderPages.map(p => `- ${p}`) : ["- None detected."]),
  "",
  "## Interpretation",
  "",
  "- Do not delete pages solely because their content or basename is similar; inspect inbound links and access boundaries first.",
  "- An HTML file without visible Supabase references may use a shared JS module; check referenced scripts before classifying it as unintegrated.",
  "- A locally resolvable path does not guarantee the deployed URL returns HTTP 200.",
  "- A passing source-level smoke check does not verify login, RLS, payments, partner payouts or live operational transactions."
].join("\\n");
writeFileSync("audit-output/krim-complete-audit.md", md);
console.log(JSON.stringify({ output: "audit-output/", totals: report.totals }, null, 2));
