#!/usr/bin/env node
/**
 * Read-only heuristic inventory of JavaScript/TypeScript navigation expressions.
 * Does not execute application code or prove route reachability.
 * Usage: node scripts/krim-js-route-dependency-audit.mjs <source-root> <output-dir>
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const IGNORE = new Set([".git","node_modules","dist","build",".next","coverage","vendor"]);
const EXT = new Set([".js",".mjs",".cjs",".jsx",".ts",".tsx"]);
const ROUTE_EXT = /\.(?:html?|php|aspx?)(?:[?#]|$)/i;
const PATTERNS = [
  {kind:"location-navigation",re:/\b(?:(?:window|document)\.)?location\s*(?:\.\s*(?:href|assign|replace))?\s*(?:=|\()\s*([^;\n)]{1,240})/g},
  {kind:"window-open",re:/\b(?:window\.)?open\s*\(\s*([^,;\n)]{1,240})/g},
  {kind:"history-navigation",re:/\bhistory\s*\.\s*(?:pushState|replaceState)\s*\([^,]*,\s*[^,]*,\s*([^);\n]{1,240})/g},
  {kind:"router-navigation",re:/\b(?:router|navigate|navigation)\s*\.\s*(?:push|replace|navigate|go)\s*\(\s*([^);\n]{1,240})/g},
  {kind:"navigate-function",re:/\b(?:navigate|redirect|routerPush)\s*\(\s*([^);\n]{1,240})/g},
  {kind:"href-assignment",re:/\.(?:href|action)\s*=\s*([^;\n]{1,240})/g},
  {kind:"set-attribute-navigation",re:/\.setAttribute\s*\(\s*["'](?:href|action|formaction)["']\s*,\s*([^);\n]{1,240})/g},
  {kind:"route-literal",re:/["'`]([^"'`\n]{1,240}(?:\.html?|\/auth\/|\/app\/|\/public\/)[^"'`\n]{0,120})["'`]/gi}
];
function walk(root,dir=root,out=[]) {
  for(const ent of fs.readdirSync(dir,{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name))) {
    if(ent.isDirectory() && IGNORE.has(ent.name)) continue;
    const full=path.join(dir,ent.name);
    if(ent.isDirectory()) walk(root,full,out);
    else if(ent.isFile() && EXT.has(path.extname(ent.name).toLowerCase()) && !/\.min\./i.test(ent.name)) out.push(path.relative(root,full).split(path.sep).join("/"));
  }
  return out.sort();
}
function cleanExpression(expr) {
  return String(expr).trim().replace(/\s+/g," ").slice(0,240);
}
function classifyTarget(expr) {
  const s=cleanExpression(expr);
  const literal=s.match(/^(\x22|\x27)([\s\S]*?)\1$/);
  if(literal) return {target:literal[2],target_type:"literal",route_like:ROUTE_EXT.test(literal[2]) || /\/(?:auth|app|public|customer|partner|driver|warehouse|customs|finance|operations)(?:\/|\?|#|$)/i.test(literal[2])};
  const template=s.match(/^`([\s\S]*?)`$/);
  if(template) return {target:template[1],target_type:/\$\{/.test(template[1])?"template-dynamic":"template-static",route_like:ROUTE_EXT.test(template[1]) || /\/(?:auth|app|public|customer|partner|driver|warehouse|customs|finance|operations)/i.test(template[1])};
  return {target:s,target_type:/\b(?:window|document|location|router|navigate|params|URL)\b/.test(s)?"expression":"unknown",route_like:ROUTE_EXT.test(s) || /\/(?:auth|app|public|customer|partner|driver|warehouse|customs|finance|operations)/i.test(s)};
}
export function extractNavigation(source,sourcePath) {
  const found=[];
  for(const p of PATTERNS) {
    p.re.lastIndex=0;
    for(const m of source.matchAll(p.re)) {
      const before=source.slice(0,m.index);
      const line=before.split("\n").length;
      const expr=cleanExpression(m[1] ?? m[0]);
      const target=classifyTarget(expr);
      found.push({source:sourcePath,line,mechanism:p.kind,expression:expr,...target,confidence:target.target_type==="literal"?"medium":"low"});
    }
  }
  const dedupe=new Map();
  for(const row of found) {
    const key=[row.source,row.line,row.mechanism,row.expression].join("|");
    dedupe.set(key,row);
  }
  return [...dedupe.values()].sort((a,b)=>a.source.localeCompare(b.source)||a.line-b.line||a.mechanism.localeCompare(b.mechanism));
}
export function auditJavaScriptFiles(fileMap) {
  const files=[...fileMap.keys()].sort(), findings=[];
  for(const file of files) findings.push(...extractNavigation(fileMap.get(file),file));
  const routeLike=findings.filter(x=>x.route_like);
  return {
    schema_version:1,
    scope:"Static regex inventory of JS/TS navigation expressions and route-like string literals. No execution, AST/type resolution, bundler analysis, network calls, or proof of runtime navigation.",
    totals:{source_files:files.length,navigation_findings:findings.length,route_like_findings:routeLike.length,unique_source_files_with_findings:new Set(findings.map(x=>x.source)).size},
    findings
  };
}
function main() {
  const root=path.resolve(process.argv[2]||process.cwd());
  const out=path.resolve(process.argv[3]||path.join(root,"audit-output"));
  const files=walk(root), map=new Map(files.map(f=>[f,fs.readFileSync(path.join(root,f),"utf8")]));
  const report=auditJavaScriptFiles(map);
  fs.mkdirSync(out,{recursive:true});
  fs.writeFileSync(path.join(out,"krim-js-route-dependencies.json"),JSON.stringify(report,null,2)+"\n");
  const header=["source","line","mechanism","expression","target","target_type","route_like","confidence"];
  const quote=v=>'"'+String(v??"").replaceAll('"','""')+'"';
  fs.writeFileSync(path.join(out,"krim-js-route-dependencies.csv"),[header.join(","),...report.findings.map(x=>header.map(k=>quote(x[k])).join(","))].join("\n")+"\n");
  console.log(JSON.stringify({output:out,totals:report.totals,sample:report.findings.slice(0,30)},null,2));
}
if(process.argv[1] && path.resolve(process.argv[1])===fileURLToPath(import.meta.url)) main();
