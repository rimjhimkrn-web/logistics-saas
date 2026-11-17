# KRIM Owner Testing Hub — implementation record

**Date:** 17 November 2026  
**Status:** OWNER-ONLY VISUAL PAGE REVIEW IMPLEMENTED; FULL WORKFLOW TESTING PENDING ISOLATED STAGING.

## Owner access boundary

- Entry point: `/owner-testing.html`.
- The hub reuses the existing KRIM platform administrator sign-in; it does not create a new account or ask the owner to register separately for each workspace.
- Access is checked by the production `global-admin-control` Edge Function with JWT verification enabled.
- The dedicated `owner_testing_authorize` action requires a valid signed-in user, AAL2 MFA, an active `platform_superadmin` role assignment, and exactly one distinct active platform-superadmin user in the role assignment table. If a second superadmin identity is added, the owner-testing action fails closed until the owner boundary is deliberately reviewed.
- The authorization action returns no privileged business records and does not grant cross-tenant data permissions.
- The hub is linked from the Global Control Centre.

## Page inventory and visual review

- Static manifest: `assets/krim-owner-testing-manifest.json`.
- Inventory includes **870 HTML pages** in the current repository, including the hub itself. Dependency files under `node_modules` are excluded.
- Search/filter by page path and folder; choose desktop, tablet or mobile preview width.
- Preview fetches the selected public HTML source and removes scripts, embedded frames/objects, refresh redirects, inline event handlers and active form controls before placing it in a script-disabled sandboxed iframe. Links and controls are inert in preview.
- `Open live page` opens the actual route in a separate tab. Existing page authentication, workspace role checks, MFA, RLS and server authorization remain in force.
- This is a safe **visual inspection** mode, not a universal authentication bypass. Some script-generated UI sections may not appear in the static preview.

## Functional testing boundary

- The owner hub does not bypass backend authorization or simulate real permissions.
- The separate Supabase project **KRIM Logistics Staging** currently has zero public tables and no migration history; it is not yet a usable workflow-test environment.
- Production has a populated schema, but repository migration files and production migration history are not reconciled (363 repository SQL migration files versus 558 production migration records). Do not replay repository migrations blindly.
- Full end-to-end testing requires a reconciled isolated staging schema, synthetic data and role-scoped test identities/memberships. No production customer/partner data should be used as test fixtures.
- No production DDL, RLS, grants, user roles, or customer/partner data were changed for this implementation. The only production backend change is the additive owner-testing authorization action in the existing Edge Function.

## Required verification before calling the full testing system complete

1. Confirm latest GitHub Pages deployment and smoke/static checks.
2. Sign in with the existing owner account and complete MFA; verify the owner hub opens.
3. Verify a platform-admin account without the unique superadmin role is denied.
4. Verify a signed-out visitor is redirected to privileged sign-in.
5. Preview representative root, customer, partner, driver, warehouse, finance, operations, customs, enterprise and admin pages at desktop/mobile widths.
6. Reconcile the migration history and build the isolated staging environment before exercising real backend workflows.
