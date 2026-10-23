# KRIM Global Interface Standard
**Version:** 1.0  
**Approved:** 2026-10-23  
**Scope:** All public pages, customer/partner/driver/warehouse/customs/finance/operations/enterprise workspaces, platform administration, and shared identity flows.

## 1. Institutional design rule

KRIM is one global logistics operating system, not a collection of unrelated websites. Every page must use the same design system, interaction standards, accessibility baseline, navigation conventions, and truthful-status language. Workspaces may use different accent colours for recognition, but must never look like separate products.

## 2. Shared visual language

- **Core palette:** deep navy for authority/navigation; blue for primary actions; white/light-neutral surfaces; slate for supporting text; cyan for focus/telemetry; green for confirmed success; amber for warnings; red for errors and critical exceptions.
- **Typography:** system-safe sans-serif stack; consistent heading scale, body size, line height, and readable contrast.
- **Components:** consistent KRIM identity/brand mark, page header, navigation, content container, cards, tables, form controls, primary/secondary/destructive actions, alerts, badges, empty states, loading states, and confirmation dialogs.
- **Layout:** consistent spacing scale, borders, corner radius, shadows, and content widths. Pages must remain responsive from small phones to desktop displays.
- **Colour variation:** allowed for workspace identity and data visualization only when semantic meaning remains consistent. Do not assign contradictory meanings to status colours.

## 3. Navigation and behaviour

- Every internal link must resolve to a canonical page; avoid duplicate pages and ambiguous routes.
- Use shared header/navigation patterns appropriate to the user's role. Never expose privileged administrator navigation in public/customer entry.
- Every interactive control must have a clear action, visible focus, loading/disabled state where needed, success/error feedback, and a working destination or handler.
- Preserve current task/context through authentication only via a same-origin, explicit allowlist. Never accept arbitrary redirect destinations.
- Provide clear routes back to the previous safe step and to support/recovery when an operation fails.

## 4. Accessibility, global readiness and trust

- Use semantic landmarks, labelled fields, keyboard navigation, visible focus, accessible live feedback, and mobile touch targets.
- Support long international names, addresses, postal formats, phone numbers, currencies, time zones, languages, and slower connections without assuming one country's conventions.
- Do not imply that a service, rate, booking, payment, partner, tracking event, or delivery is confirmed until the authoritative backend confirms it.
- Authentication and authorization must be enforced by Supabase/server-side policy, not by the interface alone.
- Keep user data organization-scoped; never reveal another organization's shipments or profile data.

## 5. Engineering governance

1. New or rebuilt pages must consume the canonical design tokens/components rather than inventing a new visual system.
2. Existing pages are migrated in controlled batches, starting with customer entry/authentication and then each operational workspace.
3. A page is not compliant merely because its colors match. Verify route integrity, mobile layout, keyboard/focus behaviour, loading/error/empty states, role access, and core interactions.
4. Do not mass-delete or replace existing pages before dependency and route review.
5. Record exceptions with a reason and a follow-up task. No unreviewed one-off styles in newly built pages.
6. Automated source/link checks are not substitutes for live browser and backend tests.

## 6. Initial adoption order

- **Batch 1:** public homepage and customer identity entry (access, signup, login, email verification/callback, MFA, recovery/reset, logout).
- **Batch 2:** customer workspace and canonical customer shipment/quote/booking routes.
- **Batch 3:** logistics partner and driver workspaces.
- **Batch 4:** warehouse and customs/trade.
- **Batch 5:** finance and operations.
- **Batch 6:** enterprise workspace and platform control centre.
- **Batch 7:** remaining public pages, secondary workflows, error/empty states, and legacy-route retirement.

Each batch must pass the shared visual, route, security, responsive and interaction checks before being marked compliant.
