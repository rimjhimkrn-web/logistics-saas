"use strict";

const CACHE_NAME = "krim-shell-v1";
const LOCAL_SHELL = [
  "/",
  "/index.html",
  "/app/customer/index.html",
  "/app/partner/index.html",
  "/app/enterprise/index.html",
  "/app/field/index.html",
  "/public/offline.html",
  "/public/manifest.webmanifest",
  "/public/icons/krim-mark.svg",
  "/core/styles/main.css",
  "/core/components/ui.js",
  "/core/localization/catalog.js",
  "/core/js/platform.js",
  "/core/js/site.js",
  "/core/js/sign-in.js",
  "/core/js/portal.js",
  "/config.js",
  "/config/markets.js",
  "/core/js/auth-flows.js"
];
const REMOTE_SDK = "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2";
const ROUTE_PATHS = new Set(["/app/customer/", "/app/partner/", "/app/enterprise/", "/app/field/", "/docs/legal/"]);
const AUTH_PATHS = new Set([
  "/app/sign-in.html",
  "/app/register.html",
  "/app/forgot-password.html",
  "/app/reset-password.html"
]);

self.addEventListener("install", (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    await Promise.all(LOCAL_SHELL.map(async (path) => {
      try { await cache.add(path); } catch (error) { console.warn("Offline asset unavailable:", path); }
    }));
    try {
      const response = await fetch(REMOTE_SDK, { mode: "cors", cache: "no-cache" });
      if (response.ok && response.type === "cors") await cache.put(REMOTE_SDK, response);
    } catch (error) {
      console.warn("Authentication SDK unavailable for offline cache.");
    }
    await self.skipWaiting();
  })());
});

self.addEventListener("activate", (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter((key) => key.startsWith("krim-shell-") && key !== CACHE_NAME).map((key) => caches.delete(key)));
    await self.clients.claim();
  })());
});

self.addEventListener("fetch", (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== "GET") return;

  if (url.origin !== self.location.origin && request.url !== REMOTE_SDK) return;
  if (url.origin === self.location.origin && (AUTH_PATHS.has(url.pathname) || url.search)) return;
  if (url.origin === self.location.origin && (/^\/admin(?:-login)?\.html$/i.test(url.pathname) || /^\/control(?:\/|$)/i.test(url.pathname))) return;
  if (url.origin === self.location.origin && !LOCAL_SHELL.includes(url.pathname) && !ROUTE_PATHS.has(url.pathname)) return;
  if (url.origin === self.location.origin && /\/(rest|auth|functions|storage|api)\//i.test(url.pathname)) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    try {
      const response = await fetch(request);
      if (response.ok && (url.origin === self.location.origin || request.url === REMOTE_SDK)) {
        await cache.put(request, response.clone());
      }
      return response;
    } catch (error) {
      const cached = await cache.match(request) || await cache.match(url.pathname);
      if (cached) return cached;
      if (request.mode === "navigate") return (await cache.match("/public/offline.html")) || Response.error();
      return Response.error();
    }
  })());
});