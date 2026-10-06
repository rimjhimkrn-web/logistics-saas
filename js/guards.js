/* ==========================================================================
   KRIM LOGISTICS OS — RBAC ROUTE GUARD & TENANT ISOLATOR
   ========================================================================== */

(function executeSecurityGuard() {
  const path = window.location.pathname;

  // 1. Bypass public and auth pages
  const isPublicRoute = path.startsWith("/public/") || path.startsWith("/legal/") || path.startsWith("/docs/") || path === "/" || path === "/index.html";
  const isAuthRoute = path.startsWith("/auth/");

  if (isPublicRoute || isAuthRoute) {
    return;
  }

  // 2. Validate Session
  const session = KrimSession.get();
  if (!session || !KrimSession.isValid()) {
    console.warn("[GUARD] Unauthorized access to protected route. Redirecting to login.");
    KrimSession.clear();
    window.location.href = `/auth/login.html?redirect=${encodeURIComponent(path)}`;
    return;
  }

  // 3. Enforce Role Isolation
  const userRole = session.role;
  const isSuperAdmin = userRole === KRIM_CONFIG.ROLES.SUPER_ADMIN;

  // Global Control Centre lockdown
  if (path.startsWith("/control/") && !isSuperAdmin) {
    console.error("[SECURITY] Access denied: Super Admin privileges required.");
    alert("Access Denied: Restricted Administrative Command Zone.");
    window.location.href = KRIM_CONFIG.ROUTES[userRole] || KRIM_CONFIG.ROUTES.login;
    return;
  }

  // Role-specific folder lockdown
  const rolePrefixes = {
    "/customer/": KRIM_CONFIG.ROLES.CUSTOMER,
    "/partner/": KRIM_CONFIG.ROLES.PARTNER,
    "/enterprise/": KRIM_CONFIG.ROLES.ENTERPRISE,
    "/driver/": KRIM_CONFIG.ROLES.DRIVER,
    "/warehouse/": KRIM_CONFIG.ROLES.WAREHOUSE,
    "/freight/": KRIM_CONFIG.ROLES.FREIGHT,
    "/operations/": KRIM_CONFIG.ROLES.OPERATIONS,
    "/finance/": KRIM_CONFIG.ROLES.FINANCE,
    "/compliance/": KRIM_CONFIG.ROLES.COMPLIANCE,
    "/support/": KRIM_CONFIG.ROLES.SUPPORT
  };

  for (const [prefix, requiredRole] of Object.entries(rolePrefixes)) {
    if (path.startsWith(prefix) && userRole !== requiredRole && !isSuperAdmin) {
      console.warn(`[GUARD] Role mismatch. ${userRole} attempted to access ${prefix}`);
      window.location.href = KRIM_CONFIG.ROUTES[userRole] || KRIM_CONFIG.ROUTES.login;
      return;
    }
  }

  // Update activity timestamp on successful navigation
  KrimSession.updateLastActive();
})();
