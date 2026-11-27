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
const hashOwners = new Map(), duplicateGroups = [], linkIssues = [], pageRows = [], integrationCandidates = [], stagingIntegrationCandidates = [], placeholderPages = [], redirectRoutes = [], noindexPages = [], stagingPages = [], missingLanguageBootstrap = [];
const attrRe = /(?:^|\s)(?:href|src|action|data-href|formaction)\s*=\s*["']([^"']+)["']/gi;
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
  // Avoid interpreting HTML-like strings inside JavaScript as real navigation attributes.
  const htmlForLinkScan = html.replace(new RegExp("<script[^>]*>[\\s\\S]*?</script>", "gi"), "<script></script>");
  for (const m of htmlForLinkScan.matchAll(attrRe)) {
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
  // Some KRIM pages load the shared Supabase client through a dynamic module import
  // rather than a <script src> or inline createClient() call. Treat that explicit
  // shared-client import as a backend signal, but keep it separate from runtime proof.
  const backendSignalRe = /createClient|supabase\.from\(|\.rpc\(|functions\.invoke\(|SUPABASE_URL|supabase-js|KRIM_SUPABASE|supabaseClient|platform\/krim-supabase\.js|krim-supabase\.js|fetch\s*\(/i;
  const linkedScriptSignals = [...new Set(localScriptSources)].filter(scriptPath => !/krim-global-language\.js$/i.test(scriptPath) && backendSignalRe.test(readFileSync(scriptPath, "utf8")));
  const directSupabaseSignal = /createClient|supabase\.from\(|\.rpc\(|functions\.invoke\(|SUPABASE_URL|supabase-js|KRIM_SUPABASE|supabaseClient|platform\/krim-supabase\.js|krim-supabase\.js/i.test(html);
  const hasSupabaseSignal = directSupabaseSignal || linkedScriptSignals.length > 0;
  const hasLanguageBootstrap = /krim-global-language\.js/i.test(html) ||
    [...new Set(localScriptSources)].some(scriptPath => /krim-global-language\.js/i.test(readFileSync(scriptPath, "utf8")));
  const operational = /(?:dashboard|workspace|shipment|booking|quote|payment|invoice|tracking|warehouse|customs|finance|operations|partner|enterprise|driver|global-operations)/i.test(file);
  const visiblePageText = html
    .replace(/<!--[\s\S]*?-->/g, " ")
    .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, " ")
    .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&(?:nbsp|amp|lt|gt|quot|#39);/gi, " ");
  // A page inviting an administrator to connect a secured backend is not itself
  // a placeholder. Flag explicit demo/sample/mock data and incomplete integration
  // states instead; all matches still require human triage.
  const headMarkup = (html.match(/<head\b[\s\S]*?<\/head>/i) || [])[0] || "";
  const titleText = (headMarkup.match(/<title[^>]*>([\s\S]*?)<\/title>/i) || [])[1] || "";
  const robotsContent = (headMarkup.match(/<meta[^>]+name=["']robots["'][^>]+content=["']([^"']+)/i) || [])[1] || "";
  const refreshTag = (headMarkup.match(/<meta\b(?=[^>]*http-equiv=["']?refresh["']?)[^>]*>/i) || [])[0] || "";
  const refreshTarget = (refreshTag.match(/content=["'][^"']*url=([^"']+)/i) || [])[1] || "";
  const headRedirect = /(?:window\.)?location\.replace\(/i.test(headMarkup) && /(?:redirect|continue|moved|replaced|consolidat)/i.test(titleText + " " + visiblePageText);
  const compatibilityRedirect = Boolean(refreshTag) || headRedirect;
  if (!hasLanguageBootstrap && !compatibilityRedirect) missingLanguageBootstrap.push(file);
  const noindex = /\bnoindex\b/i.test(robotsContent);
  const isStaging = /(?:^|\/)staging(?:\/|$)/i.test(file);
  if (noindex) noindexPages.push(file);
  if (isStaging) stagingPages.push(file);
  if (compatibilityRedirect) redirectRoutes.push({path:file,target:refreshTarget || "script-driven redirect"});
  const explicitPlaceholderWording = /\b(?:coming soon|demo data|sample data|mock data|TODO:.*integrat)\b/i.test(visiblePageText.replace(/\bno demo data is used\b|\bnot replaced with sample data\b/gi, " "));
  const placeholder = !compatibilityRedirect && (explicitPlaceholderWording || (!hasSupabaseSignal && /\bconnect to supabase\b/i.test(visiblePageText)));
  if (operational && !hasSupabaseSignal && !compatibilityRedirect) {
    if (isStaging) stagingIntegrationCandidates.push(file);
    else integrationCandidates.push(file);
  }
  if (placeholder) placeholderPages.push(file);
  const backendReview = compatibilityRedirect ? "compatibility-redirect" : isStaging ? (operational && !hasSupabaseSignal ? "staging-integration-review" : "staging-review-required") : operational ? (hasSupabaseSignal ? "signal-found-review-required" : "integration-candidate") : "classify-page-purpose";
  pageRows.push({path:file,links,unresolved:bad,absoluteRootPaths:absoluteRoot,directSupabaseSignal,linkedScriptSignals,localScriptSources:[...new Set(localScriptSources)],supabaseSignals:hasSupabaseSignal,placeholderSignals:placeholder,noindex,compatibilityRedirect,redirectTarget:refreshTarget || null,isStaging,hasLanguageBootstrap,backendReview});
}
const report = {generatedAt:new Date().toISOString(),scope:"Static analysis only. Compatibility redirects and staging routes are classified separately; integration candidates exclude both. Not a browser crawl or live transaction test.",totals:{files:files.length,htmlPages:htmlFiles.length,duplicateGroups:duplicateGroups.length,unresolvedLocalReferences:linkIssues.length,placeholderPages:placeholderPages.length,redirectRoutes:redirectRoutes.length,noindexPages:noindexPages.length,stagingPages:stagingPages.length,stagingPagesWithoutVisibleSupabaseSignals:stagingIntegrationCandidates.length,operationalPagesWithoutVisibleSupabaseSignals:integrationCandidates.length,htmlPagesWithDirectBackendSignals:pageRows.filter(p=>p.directSupabaseSignal).length,htmlPagesWithLinkedScriptBackendSignals:pageRows.filter(p=>p.linkedScriptSignals.length>0).length,htmlPagesWithLanguageBootstrap:pageRows.filter(p=>p.hasLanguageBootstrap).length,htmlPagesMissingLanguageBootstrap:missingLanguageBootstrap.length,operationalPagesWithBackendSignals:pageRows.filter(p=>p.backendReview==="signal-found-review-required").length},duplicateGroups,linkIssues,placeholderPages,redirectRoutes,noindexPages,stagingPages,stagingIntegrationCandidates,integrationCandidates,missingLanguageBootstrap,pages:pageRows};
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
"- Compatibility redirect routes (excluded from integration candidates): "+redirectRoutes.length,
"- Staging pages (not counted as production integration gaps): "+stagingPages.length,
"- Staging pages without visible backend signals: "+stagingIntegrationCandidates.length,
"- noindex routes: "+noindexPages.length,
"- Operational-looking pages without visible Supabase signals in their own HTML: "+integrationCandidates.length,"",
"- HTML pages with direct backend/client signals: "+report.totals.htmlPagesWithDirectBackendSignals,
"- HTML pages with backend-related signals in linked local scripts: "+report.totals.htmlPagesWithLinkedScriptBackendSignals,
"- HTML pages with shared language bootstrap: "+report.totals.htmlPagesWithLanguageBootstrap,
"- HTML pages missing language bootstrap (redirects excluded): "+report.totals.htmlPagesMissingLanguageBootstrap,
"- Operational pages with at least one backend-related signal (requires runtime verification): "+report.totals.operationalPagesWithBackendSignals,"",
"## Exact duplicate content","",
...(duplicateGroups.length ? duplicateGroups.map(g=>"- "+g.paths.join(" ↔ ")) : ["- None detected."]),"",
"## Unresolved link references (first 300)","",
...(linkIssues.length ? linkIssues.slice(0,300).map(x=>"- "+x.type+" — "+x.source+": "+x.href+(x.resolved ? " → "+x.resolved : "")) : ["- None detected by this static parser."]),
...(linkIssues.length>300 ? ["- ... "+(linkIssues.length-300)+" additional findings are in the JSON artifact."] : []),"",
"## HTML pages missing shared language bootstrap","",
...(missingLanguageBootstrap.length ? missingLanguageBootstrap.map(p=>"- "+p) : ["- None detected."]),"",
"## Operational-looking pages without visible Supabase references","",
...(integrationCandidates.length ? integrationCandidates.map(p=>"- "+p) : ["- None detected."]),"",
"## Staging routes requiring release review","",
...(stagingPages.length ? stagingPages.map(p=>"- "+p) : ["- None detected."]),"",
"## Compatibility redirect routes","",
...(redirectRoutes.length ? redirectRoutes.map(r=>"- "+r.path+" → "+r.target) : ["- None detected."]),"",
"## Placeholder/demo/TODO wording signals","",
...(placeholderPages.length ? placeholderPages.map(p=>"- "+p) : ["- None detected."]),"",
"## Interpretation","",
"- Do not delete pages solely because their content or basename is similar; inspect inbound links and access boundaries first.",
"- An HTML file without visible Supabase references may use a shared JS module; inspect linked scripts before classifying it as unintegrated.",
"- A locally resolvable path does not guarantee the deployed URL returns HTTP 200.",
"- A passing source-level smoke check does not verify login, RLS, payments, partner payouts or live operational transactions."
];
writeFileSync("audit-output/krim-complete-audit.md",lines.join("\n"));
console.log(JSON.stringify({output:"audit-output/",totals:report.totals,duplicateGroups,linkIssues:linkIssues.slice(0,100),redirectRoutes:redirectRoutes.slice(0,100),stagingIntegrationCandidates:stagingIntegrationCandidates.slice(0,100),integrationCandidates:integrationCandidates.slice(0,100),missingLanguageBootstrap:missingLanguageBootstrap.slice(0,300),placeholderPages:placeholderPages.slice(0,60)},null,2));
