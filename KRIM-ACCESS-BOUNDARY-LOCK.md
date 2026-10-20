# KRIM Access Boundary Lock

Status: **Security boundary implemented; authenticated end-to-end acceptance test still required.**
Last updated: 2026-10-20

## Frozen access model

### Public entry
- `index.html` and `auth/access.html` are public.
- The public workspace portal contains customer/shipper, logistics partner/carrier, driver, warehouse, customs, finance, operations, and enterprise entry points.
- Public registration never grants platform administration.
- `auth/login.html?role=platform_admin` and `?role=platform_superadmin` are explicitly rejected.

### Privileged entry
- `auth/krim-admin-access.html` is the separate, no-index privileged sign-in.
- Legacy `admin-login.html` redirects to the new privileged sign-in.
- `auth/krim-admin-guard.js` is the shared fail-closed page guard.
- Privileged page access calls the JWT-verified `global-admin-control` Edge Function.
- `global-admin-control` verifies the authenticated user, checks active `platform_admin` or `platform_superadmin` role assignments server-side, and now requires AAL2 (MFA) before any admin action.
- Platform Super Admin-only mutations remain separately restricted by the Edge Function.
- No service-role key is shipped to the browser.

## Guarded privileged HTML routes
- `admin.html`
- `financial-management.html`
- `public/app/admin/control-tower.html`
- `public/operations/control-tower.html`
- `public/control-centre/digital-twin-map.html`
- `public/control-centre/exception-dispatch.html`
- `public/control-centre/facility-matrix.html`
- `public/control-centre/simulation-room.html`
- `public/admin/kms-key-rotation.html`
- `public/admin/platform-health.html`
- `public/admin/rbac-matrix.html`
- `public/admin/security-desk.html`
- `public/admin/siem-audit-logs.html`
- `public/admin/tenant-partitioning.html`
- `public/ai/prompt-governance.html`
- `public/app/shared/security-manager.html`
- `public/production/security-hardening.html`
- `src/admin/control_tower.html`

## Permanent change-control rule
Treat this access boundary as frozen. Do not add public admin links, public admin signup, role selection that grants authorization, client-side-only admin permissions, or privileged operations without server-side authorization and audit logging. Any future access change must be a reviewed, versioned security change followed by negative tests for signed-out, ordinary authenticated, AAL1, and unauthorized-role accounts.

## Acceptance tests still required
- Confirm signed-out direct access to every guarded route redirects to privileged sign-in.
- Confirm a regular customer/partner account and an AAL1-only admin session are denied.
- Confirm an active platform admin with verified MFA can open the control tower.
- Confirm platform-superadmin-only mutations reject platform_admin.
- Verify live GitHub Pages deployment and test the actual authenticated flow in the browser.

Do not describe the entire platform as production-locked until these acceptance tests pass. Static page guards are defense-in-depth; backend role checks, MFA assurance, RLS, and endpoint authorization remain the security boundary.
