# KRIM frontend architecture

## Existing integrations

- `config.js` remains the existing browser configuration source. It contains the Supabase URL and publishable key; never place a service-role key or other privileged secret in frontend files.
- Authentication uses the existing Supabase client for password sign-in, sign-up, session retrieval, sign-out, password-recovery email, and password update. Supabase controls session persistence and email delivery. Registration creates an Auth identity only; it does not create an organization membership. Password recovery requires the deployed Supabase redirect allowlist to include `/app/reset-password.html`. Live account flows still require a valid project configuration and test account to verify.
- The customer shipment-request form inserts the existing `shipment_requests` contract using its current column names. The workspace shipment list selects from that table and is still governed by backend RLS. A successful insert confirms request submission only; it does not create a priced quote, booking, or shipment.
- The existing finance page uses the Supabase RPC `save_financial` and reads `shipment_financials`. Preserve that integration; its behavior requires a permitted test account and live backend verification before being represented as production-verified.
- Workspace URLs choose presentation only. No safe frontend organization-membership or permission contract is present, so the frontend cannot reliably build role-aware navigation or resolve organization context. RLS remains authoritative; `permissions.can()` and organization context must not be treated as grants.

## Unavailable backend contracts

The following workflows have no verified, safe frontend contract in this repository and must remain unavailable rather than calling guessed tables, RPCs, or Edge Functions:

| Workflow | Missing contract |
| --- | --- |
| Shipment lifecycle / booking | Authorized create, update, assignment, and organization-scoped read contract |
| Quotes / pricing | Quote request, pricing, approval, acceptance, and conversion contract |
| Tracking | Authorized shipment lookup and tracking-event read/write contract |
| Payments / invoices / settlements | Payment-intent, invoice, refund, payout, and settlement contracts |
| Documents / POD | Authorized upload, signed download, metadata, and proof-submission contract |
| Notifications / support | User-scoped notification delivery/read and ticket lifecycle contracts |
| Partner operations | Load discovery, capacity, assignments, compliance, performance, and settlement contracts |
| Enterprise | Membership/role resolution, user administration, analytics, and integration contracts |
| Field operations | Assigned task read, event write, secure POD upload, and idempotent sync contract |
| AI / workflows | Approved AI execution, evidence, approval, automation, and workflow-control contracts |

The customer, partner, enterprise, and field shells display explicit unavailable states for those capabilities. Field drafts remain local and are not synchronized. Do not use generic data helpers or unverified RPC/function names as evidence that a workflow exists.

## Deployment

- Serve the repository root over HTTPS. Local development may use `http://localhost`; do not deploy a production PWA on an insecure origin.
- Configure the host to serve each application directory's `index.html` for its trailing-slash route. The UI uses root-relative URLs.
- The frontend uses the existing Supabase CDN client, Google Fonts, and Unsplash-hosted logistics imagery. The root public site and `/app/` shell use external scripts and styles; several separately added legacy/domain pages still contain inline scripts/styles and need CSP nonces/hashes or extraction before a strict CSP can be enforced.
- `service-worker.js` caches static shell files and the Supabase browser SDK only. Authentication paths, query-string requests, privileged admin/control paths, and same-origin API-like paths bypass caching. Do not extend its cache to authenticated responses or operational data.

## Offline and capability boundaries

- Field updates are IndexedDB drafts on the current device. They are not synchronized, delivered, or confirmed; sign-out clears the local queue. The frontend does not store proof files because no authorized upload endpoint is present.
- Live tracking, payments, invoices, partner loads/capacity, organization users, analytics, AI actions, and most documents remain explicit unavailable states until an authorized backend contract exists.
- The 15-language selector and common-key catalog are present, including Arabic RTL; major page content is not fully translated yet. Do not represent localization as complete.
- Locale preference is stored as `krim-language`; Simplified Chinese uses the shared locale code `zh` (legacy `zh-CN` preferences are normalized), and Arabic sets document direction to RTL.
- Runtime environments are detected as development, preview, or production. Hosting can override detection with `window.KRIM_ENVIRONMENT` or a `krim-environment` meta tag; environment labels do not change backend authorization or grant access.
- `window.KRIM_SUPABASE` and `window.supabaseClient` refer to the same browser client when both platform layers are present. Only the existing publishable configuration is used; organization context and frontend permission checks remain non-authoritative.
- Shared market formatters use the configured market time zone and currency. `KRIM.analytics.track()` and `KRIM.errors.report()` emit low-data browser events only; no analytics or monitoring sink is configured.
- Frontend error and performance events are emitted with low-data categories/durations, but no monitoring sink is configured. No payment or workflow failure telemetry can be claimed as delivered to an observability service.
- The install prompt appears only when the browser emits its installability event. Browser, HTTPS, and manifest support determine whether installation is available.
- India is the initial active market, but each service request requires operational confirmation. Localization and country/currency selection do not make service or regulatory decisions.
- Legal and security entries in `docs/legal/` are document locations only. No policy text, legal approval, retention schedule, or security-reporting contact was supplied in this repository.

## Verification limits

The repository has no package manifest, test runner, browser automation dependency, or installed browser. JavaScript syntax, local route resolution, HTTP responses, and editor diagnostics can be checked locally; screenshot-based responsive and authenticated-backend tests require a browser and valid test account/environment.