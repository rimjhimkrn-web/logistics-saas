/* KRIM Global Navigation Runtime
 * Handles GitHub Pages project-base paths and canonical internal routes.
 * This is a frontend navigation convenience only; backend authorization remains authoritative.
 */
(function () {
  "use strict";
  function detectBasePath() {
    const script = Array.from(document.scripts).find(item => (item.src || "").includes("/platform/krim-navigation.js"));
    if (script && script.src) {
      try {
        const pathname = new URL(script.src, window.location.href).pathname;
        const marker = "/platform/krim-navigation.js";
        const index = pathname.indexOf(marker);
        if (index >= 0) {
          const prefix = pathname.slice(0, index);
          return prefix ? prefix.replace(/\/?$/, "/") : "/";
        }
      } catch (_) {}
    }
    const pathname = window.location.pathname || "/";
    if (pathname === "/logistics-saas" || pathname.startsWith("/logistics-saas/")) return "/logistics-saas/";
    return "/";
  }
  const BASE = detectBasePath();
  const LEGACY = Object.freeze({
    "/portal.html": "auth/login.html",
    "/platform.html": "public/solutions.html",
    "/network.html": "public/network.html",
    "/tracking.html": "public/tracking.html",
    "/customer/workspace.html": "app/customer/index.html",
    "/partner/workspace.html": "app/partner/index.html",
    "/enterprise/portal.html": "app/enterprise/index.html",
    "/driver/app.html": "app/field/index.html",
    "/warehouse/workspace.html": "app/field/index.html",
    "/app/app-shell.html": "public/app/app-shell.html",
    "/app/app-runtime.js": "public/app/app-runtime.js",
    "/js/app/app-runtime.js": "public/app/app-runtime.js",
    "/app/app-store.js": "public/app/app-store.js",
    "/app/dashboard-framework.html": "public/app/dashboard-framework.html",
    "/app/global-search.html": "public/app/global-search.html",
    "/app/messaging-center.html": "public/app/messaging-center.html",
    "/app/document-vault.html": "public/app/document-vault.html",
    "/app/org-switcher.html": "public/app/org-switcher.html",
    "/app/profile-settings.html": "public/app/profile-settings.html",
    "/app/app-settings.html": "public/app/app-settings.html",
    "/app/notifications.html": "public/app/notifications.html",
    "/partner/partner-directory.html": "public/partner/partner-directory.html",
    "/partner/partner-onboarding.html": "public/partner/partner-onboarding.html",
    "/partner/load-marketplace.html": "public/partner/load-marketplace.html",
    "/shipper/booking-request.html": "public/shipper/booking-request.html",
    "/shipper/active-shipments.html": "public/shipper/active-shipments.html",
    "/shipper/spot-approvals.html": "public/shipper/spot-approvals.html",
    "/shipper/rate-calculator.html": "public/shipper/rate-calculator.html"
  });
  const API_PREFIXES = ["/rest/","/auth/v1/","/storage/v1/","/realtime/v1/","/functions/v1/","/graphql/v1/","/.well-known/"];
  function route(input) {
    if (input === null || input === undefined) return BASE;
    const value = String(input).trim();
    if (!value || value.startsWith("#") || value.startsWith("?") || /^(?:[a-z][a-z0-9+.-]*:|\/\/)/i.test(value)) return value;
    const splitAt = value.search(/[?#]/);
    const rawPath = splitAt < 0 ? value : value.slice(0, splitAt);
    const suffix = splitAt < 0 ? "" : value.slice(splitAt);
    let path = rawPath;
    if (path.startsWith(BASE)) path = path.slice(BASE.length);
    path = path.replace(/^\/+/, "");
    path = LEGACY["/" + path] || path;
    return BASE + path + suffix;
  }
  function shouldSkip(path) {
    return API_PREFIXES.some(prefix => path.startsWith(prefix)) || path.startsWith("/logistics-saas/rest/") || path.startsWith("/logistics-saas/functions/");
  }
  function rewriteElement(element) {
    const tags = [["a","href"],["link","href"],["script","src"],["img","src"],["source","src"],["iframe","src"],["form","action"],["video","poster"]];
    tags.forEach(([tag,attr]) => {
      if (element.tagName.toLowerCase() !== tag || !element.hasAttribute(attr)) return;
      const value = element.getAttribute(attr);
      if (!value || !value.startsWith("/") || value.startsWith("//") || value.startsWith(BASE)) return;
      if (shouldSkip(value.split(/[?#]/)[0])) return;
      element.setAttribute(attr, route(value));
    });
  }
  function rewrite(root) {
    if (!root || !root.querySelectorAll) return;
    ["a[href]","link[href]","script[src]","img[src]","source[src]","iframe[src]","form[action]","video[poster]"].forEach(selector => root.querySelectorAll(selector).forEach(rewriteElement));
    if (root.nodeType === 1) rewriteElement(root);
  }
  window.KRIM_ROUTE = route;
  window.KRIM_NAV = Object.freeze({basePath:BASE,route,go:path=>window.location.assign(route(path)),rewrite:()=>rewrite(document)});
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded",()=>rewrite(document)); else rewrite(document);
  if (window.MutationObserver && document.documentElement) new MutationObserver(records=>records.forEach(record=>record.addedNodes.forEach(node=>{if(node.nodeType===1)rewrite(node);}))).observe(document.documentElement,{childList:true,subtree:true});
})();