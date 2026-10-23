import { readdirSync, readFileSync, existsSync, mkdirSync, writeFileSync } from "node:fs";
import { join, dirname, normalize } from "node:path";
import { createHash } from "node:crypto";
const IGNORE = new Set([".git", "node_modules", ".next", "dist", "build"]);
function walk(dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true }).flatMap(e => {
    if (e.isDirectory() && IGNORE.has(e.name)) return [];
    const p = join(dir, e.name);
    return e.isDirectory() ? walk(p) : e.isFile() ? [p] : [];
  });
}
const files = walk(".").map(p => normalize(p).replace(/^\.\//, ""));
const htmlFiles = files.filter(p => p.toLowerCase().endsWith(".html"));
const fileSet = new Set(files);
const hashOwners = new Map(), duplicateGroups = [], linkIssues = [], pageRows = [], integrationCandidates = [], placeholderPages = [];
const attrRe = /(?:href|src|action|data-href|formaction)\s*=\s*["']([^"']+)["']/gi;
const schemeRe = /^(?:[a-z][a-z0-9+.-]*:|\/\/|#|mailto:|tel:|javascript:|data:)/i;
function existsCandidate(c) {
  c = normalize(c).replace(/^\.\//, "").replace(/\/$/, "");
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
    if (!group) { group = {hash,paths:[owner]}; duplicateGroups.push(group); }
    group.paths.push(file);
  } else hashOwners.set(hash,file);
  let links = 0, bad = 0, absoluteRoot = 0;
  for (const m of html.matchAll(attrRe)) {
    const raw = m[1].trim();
    if (!raw || raw.includes("$"+"{") || raw.includes("{{") || raw.includes("<") || schemeRe.test(raw)) continue;
    const clean = raw.split(/[?#]/)[0];
    if (!clean) continue;
    links++;
    if (clean.startsWith("/logistics-saas/")) {
      const target = clean.slice("/logistics-saas/".length);
      if (!existsCandidate(target)) { bad++; linkIssues.push({type:"missing-project-route",source:file,href:raw}); }
    } else if (clean.startsWith("/")) {
      absoluteRoot++;
      const target = clean.slice(1);
      if (!existsCandidate(target) && !existsCandidate(join("public",target))) {
        bad++; linkIssues.push({type:"unresolved-root-path",source:file,href:raw});
      }
    } else {
      const target = normalize(join(dirname(file),clean));
      if (!existsCandidate(target)) { bad++; linkIssues.push({type:"missing-local-target",source:file,href:raw,resolved:target}); }
    }
  }
  const localScriptSources = [];
  const scriptRe = /<script\b([^>]*)>/gi;
  for (const sm of html.matchAll(scriptRe)) {
    const srcMatch = sm[1].match(/\bsrc\s*=\s*["']([^"']+)["']/i);
    if (!srcMatch) continue;
    const rawSrc = srcMatch[1].trim();
    if (!rawSrc || schemeRe.test(rawSrc)) continue;
    const cleanSrc = rawSrc.split(/[?#]/)[0];
    const candidates = [];
    if (cleanSrc.startsWith("/")) {
      candidates.push(cleanSrc.slice(1), join("public", cleanSrc.slice(1)));
    } else {
      candidates.push(normalize(join(dirname(file), cleanSrc)));
    }
    const resolvedScript = candidates.find(candidate => fileSet.has(candidate));
    if (resolvedScript && /\.(?:m?js|ts|tsx|jsx)$/i.test(resolvedScript)) {
      localScriptSources.push(resolvedScript);
    }
  }
  const backendSignalRe = /createClient|supabase\.from\(|\.rpc\(|functions\.invoke\(|SUPABASE_URL|supabase-js|KRIM_SUPABASE|supabaseClient|fetch\s*\(/i;
  const linkedScriptSignals = [...new Set(localScriptSources)].filter(scriptPath => backendSignalRe.test(readFileSync(scriptPath, "utf8")));
  const directSupabaseSignal = /createClient|supabase\.from\(|\.rpc\(|functions\.invoke\(|SUPABASE_URL|supabase-js|KRIM_SUPABASE|supabaseClient/i.test(html);
  const hasSupabaseSignal = directSupabaseSignal || linkedScriptSignals.length > 0;
  const operational = /(?:dashboard|workspace|shipment|booking|quote|payment|invoice|tracking|warehouse|customs|finance|operations|partner|enterprise|driver|global-operations)/i.test(file);
  const placeholder = /placeholder|coming soon|demo data|sample data|mock data|TODO:.*integrat|connect to supabase/i.test(html);
  if (operational && !hasSupabaseSignal) integrationCandidates.push(file);
  if (placeholder) placeholderPages.push(file);
  pageRows.push({path:file,links,unresolved:bad,absoluteRootPaths:absoluteRoot,directSupabaseSignal,linkedScriptSignals,localScriptSources:[...new Set(localScriptSources)],supabaseSignals:hasSupabaseSignal,placeholderSignals:placeholder,backendReview:operational ? (hasSupabaseSignal ? "signal-found-review-required" : "integration-candidate") : "classify-page-purpose"});
}
const report = {generatedAt:new Date().toISOString(),scope:"Static source scan only; not a browser crawl or live transaction test.",totals:{files:files.length,htmlPages:htmlFiles.length,duplicateGroups:duplicateGroups.length,unresolvedLocalReferences:linkIssues.length,placeholderPages:placeholderPages.length,operationalPagesWithoutVisibleSupabaseSignals:integrationCandidates.length,htmlPagesWithDirectBackendSignals:pageRows.filter(p=>p.directSupabaseSignal).length,htmlPagesWithLinkedScriptBackendSignals:pageRows.filter(p=>p.linkedScriptSignals.length>0).length,operationalPagesWithBackendSignals:pageRows.filter(p=>p.backendReview==="signal-found-review-required").length},duplicateGroups,linkIssues,placeholderPages,integrationCandidates,pages:pageRows};
mkdirSync("audit-output",{recursive:true});
writeFileSync("audit-output/krim-complete-audit.json",JSON.stringify(report,null,2));
const lines = [
"# KRIM Logistics — Automated Static Repository Audit","",
"Generated: "+report.generatedAt,"",
"> Static analysis only. Findings require triage. This is not proof of deployed HTTP status, runtime authorization, or live transactions.","",
"## Summary","",
"- Files scanned: "+files.length,
"- HTML pages scanned: "+htmlFiles.length,
"- Exact duplicate-content groups: "+duplicateGroups.length,
"- Unresolved local/root link references: "+linkIssues.length,
"- Pages with placeholder/demo/TODO wording signals: "+placeholderPages.length,
"- Operational-looking pages without visible Supabase signals in their own HTML: "+integrationCandidates.length,"",
"- HTML pages with direct backend/client signals: "+report.totals.htmlPagesWithDirectBackendSignals,
"- HTML pages with backend-related signals in linked local scripts: "+report.totals.htmlPagesWithLinkedScriptBackendSignals,
"- Operational pages with at least one backend-related signal (requires runtime verification): "+report.totals.operationalPagesWithBackendSignals,"",
"## Exact duplicate content","",
...(duplicateGroups.length ? duplicateGroups.map(g=>"- "+g.paths.join(" ↔ ")) : ["- None detected."]),"",
"## Unresolved link references (first 300)","",
...(linkIssues.length ? linkIssues.slice(0,300).map(x=>"- "+x.type+" — "+x.source+": "+x.href+(x.resolved ? " → "+x.resolved : "")) : ["- None detected by this static parser."]),
...(linkIssues.length>300 ? ["- ... "+(linkIssues.length-300)+" additional findings are in the JSON artifact."] : []),"",
"## Operational-looking pages without visible Supabase references","",
...(integrationCandidates.length ? integrationCandidates.map(p=>"- "+p) : ["- None detected."]),"",
"## Placeholder/demo/TODO wording signals","",
...(placeholderPages.length ? placeholderPages.map(p=>"- "+p) : ["- None detected."]),"",
"## Interpretation","",
"- Do not delete pages solely because their content or basename is similar; inspect inbound links and access boundaries first.",
"- An HTML file without visible Supabase references may use a shared JS module; inspect linked scripts before classifying it as unintegrated.",
"- A locally resolvable path does not guarantee the deployed URL returns HTTP 200.",
"- A passing source-level smoke check does not verify login, RLS, payments, partner payouts or live operational transactions."
];
writeFileSync("audit-output/krim-complete-audit.md",lines.join("\n"));
console.log(JSON.stringify({output:"audit-output/",totals:report.totals,duplicateGroups,linkIssues:linkIssues.slice(0,100),integrationCandidates:integrationCandidates.slice(0,60),placeholderPages:placeholderPages.slice(0,60)},null,2));
