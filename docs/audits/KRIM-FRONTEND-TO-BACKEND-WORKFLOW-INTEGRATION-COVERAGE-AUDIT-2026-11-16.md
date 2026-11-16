# KRIM Frontend-to-Backend Workflow Integration Coverage Audit
**Date:** 2026-11-16  
**Scope:** Static source review of the nine workspace landing pages and shared browser runtime. This audit checks whether visible controls are wired to backend operations, whether errors are represented accurately, and whether UI claims are consistent with backend authority. No browser session was authenticated; no RPC, Edge Function, upload, shipment, payment, notification, or production mutation was executed.

## Executive summary
The workspaces are not merely static mockups: driver, finance, operations, customs, enterprise and platform-admin pages contain real Supabase reads/writes or Edge Function calls. However, a visible button or successful page load is not proof of a complete end-to-end business journey. Several material integration gaps and misleading fallback/partial-success states remain. Release remains NO-GO for unrestricted operational execution.

## Scope inspected
- Shared browser runtime: `js/guards.js`, `js/session.js`, `app/krim-foundation.js`, `js/public/public-runtime.js`.
- Workspace entry pages: Customer, Partner, Driver, Warehouse, Customs, Finance, Operations, Enterprise and Platform Admin.
- Relevant event handlers, Supabase table reads/writes, RPC calls, storage operations, sign-out paths, loading/error states and data fallbacks.
- Prior live database and RPC audits were used as context; no production data was modified.

## Positive integration evidence
1. **Customer:** dashboard validates the Supabase session, active organization membership and organization type before loading organization-scoped shipment and quote metrics. It separately checks MFA assurance and displays an explicit unavailable/unknown state when that check fails.
2. **Partner:** gateway resolves authenticated user, active organization memberships, organization type/status and partner account pathway. It does not itself grant commercial permission.
3. **Driver:** profile, assignment, trip-event and evidence operations call Supabase; assignment ownership is scoped to the signed-in user; uploads are removed if metadata persistence fails; milestone and POD errors are surfaced; sign-out is wired.
4. **Customs:** page performs session validation, data reads and document upload/metadata persistence; user-facing error states exist.
5. **Finance:** workspace checks active finance organization membership and calls `krim_has_permission(..., 'finance.view')`; restricted datasets are intentionally withheld and described as such.
6. **Operations:** reads shipments, exceptions, tracking events, warehouse transfers and returns; separately reports query failures rather than silently treating all errors as empty results.
7. **Enterprise:** requires active enterprise organization membership and offers refresh, search, export and sign-out. Data access remains subject to database policies.
8. **Platform Admin:** uses the `global-admin-control` Edge Function rather than treating browser UI as the authorization boundary; privileged forms have client-side guardrails and server-side checks documented in prior audit.
9. **Partner and other pages:** the UI consistently signals that onboarding, verification and market readiness are separate gates from simply opening a workspace.

## Findings

### P1 — Enterprise shipment source fallback can conceal canonical-source failure
`app/enterprise/index.html` first queries `krim_shipments`, but on any query error it falls back to legacy `shipment_requests`. This conflates permission denial, schema/source failure and transient errors with an acceptable alternative source. It can present stale or semantically different legacy data as the enterprise shipment register and obscure the canonical-source failure. Remove silent fallback; show a clear source-unavailable state and retain the original error reference. Any legacy transition should be explicit, versioned and reconciled.

### P1 — Operations page can show a partially successful dashboard without a single overall readiness signal
`app/operations/index.html` runs multiple independent reads and correctly surfaces several individual failures, but successful portions remain visible while other operational datasets may be unavailable. Users may interpret the overall page as a complete control-tower picture. Add a prominent per-domain data freshness/availability matrix and an overall PARTIAL state whenever a required source fails. This is especially important given the previously identified mismatch in `krim_operations_list_shipment_snapshots` permission scope.

### P1 — Warehouse landing page is a summary surface, not an end-to-end workflow
`app/warehouse/index.html` currently renders a narrow summary using a compact client-side loader. The actual receipt, QC, allocation, pick, transfer, return and custody workflows live on separate pages and must be independently verified. The landing page must not be treated as evidence that those operations are available or complete. Link every metric to the underlying authorized register and display explicit empty/unavailable/error states; staging-test each transaction journey separately. Prior warehouse audits identified reserved-stock transfer/picking and NULL-return validation concerns.

### P1 — Customer dashboard navigation does not prove the destination pages are protected or functional
The customer dashboard's links lead to booking, quotes, invoices, document vault, support and tracking pages. Its own membership check does not propagate authorization to destination pages. Each destination must independently validate tenant membership, organization type, permission and record ownership. Existing database/RPC audits already identify customer lifecycle, support ticket insert-field constraints, consent and canonical shipment access gaps. A dashboard click-through is not an end-to-end customer journey.

### P1 — Driver evidence operations require atomicity and staging verification
Driver page uploads evidence to private buckets and then inserts metadata; it attempts cleanup if metadata insertion fails, which is a useful compensation pattern. Cleanup can itself fail, and no cross-request transaction spans object storage and database metadata. Staging tests must verify orphan-object cleanup, duplicate submissions, wrong assignment/tenant, expired session, file type/size mismatch and reviewer visibility. Do not infer delivery completion from upload success.

### P1 — Customs document submission is not authority clearance
The customs workspace can submit and review broker/customer documents, but this is not government customs clearance. Prior customs audit found no callable workflow binding official release authority, reference, issuer, jurisdiction, evidence, verifier, timestamp and revocation. UI labels and completion states must continue to distinguish internal document review from legally effective clearance.

### P1 — Privileged admin UI can still report misleading success if audit persistence fails
The platform-admin page invokes the server control function for privileged operations, but prior server audit found the audit helper may not propagate insert failure after a privileged mutation. The UI therefore cannot guarantee durable audit evidence merely because the request returned success. Fix the server-side atomicity/transaction boundary after migration reconciliation, then test action plus audit event together.

### P2 — Shared legacy browser guard is not a trusted authorization layer
`js/guards.js` and `js/session.js` use local browser session state and role metadata for routing. This can improve navigation but cannot authorize database operations or protect direct URLs. Current workspace pages mostly use Supabase Auth directly, so the shared guard must not be relied on for security. Consolidate or clearly deprecate it to avoid conflicting session sources and stale role behavior.

### P2 — Session behavior is inconsistent across workspace pages
Some pages use `getSession()`, others `getUser()`, and sign-out redirects vary. Confirm token refresh, revoked membership, global sign-out, stale tabs, expired refresh tokens and browser back/forward behavior across all workspaces. A local route redirect is not proof that a server-side session or role was revoked.

### P2 — Static event-handler presence is not functional proof
Handlers exist for key controls (refresh, search, export, upload, milestone, sign-out and admin actions), but static inspection cannot establish successful execution, accessible error handling, correct state transitions or idempotency. Each control requires a safe staging test with expected backend result and audit evidence.

## Required staging acceptance suite (not executed)
1. One test identity per workspace; also test wrong-tenant and multi-membership identities.
2. Load every landing page, refresh, search, export, sign out, expire/revoke session, and use browser back/forward.
3. Verify every button has a real handler, correct backend target, loading lock, success state, failure state and retry semantics.
4. Customer: booking request -> quote -> customer acceptance -> partner assignment; use isolated staging records only.
5. Partner: onboarding -> independent verification -> capability -> capacity -> quote; no live service commitments.
6. Driver: assignment -> accepted trip -> ordered milestones -> POD submission -> independent review; GPS stays disabled.
7. Warehouse: receipt -> QC -> released inventory -> allocation -> pick -> handover; concurrent reservations must preserve committed stock.
8. Customs: broker/doc submission and independent review; explicitly prove no internal status is labelled government clearance.
9. Operations/Enterprise: prove tenant and role scopes, partial-data state, source freshness and no silent canonical-to-legacy fallback.
10. Finance: read-only authorization only; no payment, ledger, settlement, invoice posting or refund in this phase.
11. Admin: privileged action must fail closed if its durable audit record cannot be committed.
12. Repeat each test with duplicate request, network interruption and stale/revoked session.

## Release decision
**NO-GO for unrestricted production execution.** Static integration evidence is substantial, but functional staging journeys, exact deployed-source parity, canonical tenant access, workflow atomicity, notification delivery and migration reconciliation are still outstanding. Financial collection remains deferred to the final phase.

## Change boundary
This was a read-only static source audit. No source files were changed, no production schema or data was modified, no RPC or Edge Function was invoked, and no external communication or payment was initiated.
