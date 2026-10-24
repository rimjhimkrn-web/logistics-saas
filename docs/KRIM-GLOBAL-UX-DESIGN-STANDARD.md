# KRIM Global Logistics — Global UX & Interface Standard

**Status:** Design baseline for the pre-testing interface consistency pass  
**Updated:** 2026-10-24  
**Scope:** Existing canonical public routes and role workspaces in `logistics-saas`

## Goal

Make KRIM feel like one dependable global logistics operating system, not a collection of unrelated pages. Keep the existing working customer, partner, driver and operations flows. Do not add new product pages merely to make the site look larger. Do not delete a similarly named page until its route, dependencies, auth behavior and canonical replacement have been verified.

## Shared visual language

- **Brand:** KRIM Logistics; white and deep navy foundations, clear blue accents, restrained cyan highlights, readable neutral backgrounds.
- **Typography:** consistent system/Inter-style sans-serif stack; clear page title, section title, supporting text and metadata hierarchy.
- **Layout:** common page width, predictable spacing, aligned cards, consistent borders/radii/shadows, clear empty/loading/error/success states.
- **Navigation:** visible KRIM brand, clear breadcrumb/back path where useful, consistent workspace navigation, functional mobile menu, no public link to privileged administration.
- **Components:** consistent primary/secondary buttons, form labels and validation, status badges, data tables, filter bars, pagination, alerts and confirmation patterns.
- **Responsive behavior:** phone-first layouts; no horizontal page overflow; tables become scrollable or card-based; touch targets are comfortably sized; actions remain reachable without hover.
- **Accessibility:** semantic headings and landmarks, keyboard-visible focus, labels for controls, meaningful link names, sufficient contrast, reduced-motion respect, no color-only status communication.
- **International readiness:** use language/region-aware formatting where implemented; label currency and units explicitly; do not imply every route or market is operational merely because the UI has a country selector.
- **Trust:** no invented shipment, revenue, capacity, tracking, partner or payment data; distinguish live data from unavailable, demo, stale or not-yet-connected states.

## Canonical entry routes

- Public homepage: `index.html`
- Access portal / login: `auth/access.html`, `auth/login.html`
- Customer: `app/customer/index.html`
- Logistics Partner: `app/partner/index.html`
- Driver: `app/driver/index.html`
- Warehouse: `app/warehouse/index.html`
- Customs & Trade: `app/customs/index.html`
- Finance & Treasury: `app/finance/index.html`
- Operations: `app/operations/index.html`
- Enterprise: `app/enterprise/index.html`
- Privileged Platform Administration: `app/platform-admin/index.html`

These are entry points, not a claim that every linked module or workflow is complete.

## Audit and implementation order

1. Preserve the homepage and all currently working role journeys.
2. Review each canonical entry page on desktop and narrow mobile widths; record layout, navigation, typography, control, accessibility and status-state issues.
3. Fix shared navigation, spacing, component consistency and responsive defects in small audited batches.
4. Review module pages reached from each workspace; align typography and components without flattening role-specific workflows.
5. Check every visible link/button/menu and ensure destinations are canonical and actions have real outcomes or an honest unavailable state.
6. Compare same-basename pages and trace incoming links/scripts/auth/backend dependencies before redirecting or retiring any page.
7. Run the static link audit, production smoke checks and deployment checks after each batch.
8. Only then start authenticated end-to-end tests, because visual consistency is not proof of backend functionality.

## Acceptance checklist

- [ ] All ten entry points share the same visual language while retaining role-specific content.
- [ ] Public pages never expose a privileged admin route as ordinary navigation.
- [ ] Mobile navigation and page layouts work at narrow viewport widths.
- [ ] Forms have labels, inline errors, submission/loading states and success/error feedback.
- [ ] Tables, empty states, loading states and permission-denied states are readable.
- [ ] No fabricated operational metrics or false “success” states.
- [ ] Every local link resolves to an intended canonical page.
- [ ] Duplicate candidates are mapped to canonical routes before any deletion.
- [ ] Automated checks pass on the exact latest commit.
- [ ] Authenticated user tests confirm role access and Supabase persistence separately.

## Current limitations

The repository inventory found 805 HTML files outside `node_modules`, with multiple same-basename groups. These counts do not equal 805 unique user-facing routes. A successful static link audit does not establish consistent visual quality, working interactions, tenant isolation, database persistence or launch readiness. This standard is the checklist for the next audited UI implementation batches; it is not a completion certificate.

## Implementation batch 1 — shared baseline

**Shared stylesheet:** `assets/css/krim-global-interface.css`

The shared baseline is now linked from these canonical entry pages:
- `index.html`
- `auth/access.html`
- `auth/login.html`
- `app/customer/index.html`
- `app/partner/index.html`
- `app/driver/index.html`
- `app/warehouse/index.html`
- `app/customs/index.html`
- `app/finance/index.html`
- `app/operations/index.html`
- `app/enterprise/index.html`
- `app/platform-admin/index.html`

The stylesheet establishes common KRIM design tokens, consistent focus visibility, mobile form sizing, overflow safeguards for wide data tables, reduced-motion support, and reusable empty-state/surface utilities. It is deliberately conservative: it does not replace each workspace's navigation or application logic, and it does not claim all subpages have been redesigned. Role-specific layouts and Supabase workflows remain in their existing page files.

### Batch 1 verification status
- [x] Shared stylesheet created and linked to all twelve canonical entry pages listed above.
- [ ] Confirm published stylesheet and HTML assets are served by GitHub Pages after deployment.
- [ ] Run static-link audit and production smoke checks on the exact resulting commit.
- [ ] Visual review at narrow mobile and desktop widths.
- [ ] Extend the design-system integration to module pages in audited batches.
- [ ] Audit and map duplicate routes before any deletion.

