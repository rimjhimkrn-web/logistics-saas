# KRIM Complete Platform Testing & Verification Programme
## Phase 00 — Consolidated Platform Readiness Register

Date: 2026-11-25
Repository: rimjhimkrn-web/logistics-saas
Branch: qa/phase-00-baseline-2026-11-25
Scope: Web platform only. Native/mobile applications excluded.
Safety: Read-only Production/Staging discovery and QA-branch documentation only. No database writes, synthetic users, real provider operations, merge or deployment.

## 1. Executive status

**Phase 00: IN PROGRESS — NOT RELEASE-READY.**

The QA branch has source-level checks and a Chromium environment-routing smoke test. These are useful foundations, not proof of authenticated end-to-end business workflows.

Verified baseline:
- Recursive Git tree inspected; response not truncated; 2,256 blob entries in the reviewed snapshot.
- Earlier source inventory counted 1,218 HTML/JS/TS-family source files: 1,023 HTML, 143 JS/MJS, 52 TS/TSX/JSX.
- Relevant automation scripts: audit-krim-links.mjs, krim-complete-static-audit.mjs, krim-environment-isolation.test.mjs, krim-production-smoke.mjs.
- QA workflow run 45573579009 (2026-11-25) completed successfully: critical workflow assertions, auth module syntax, fail-closed environment test, static audit and artifact upload.
- QA workflow run 45573578911 completed successfully: Playwright/Chromium installation, local HTTPS fixture and Chromium environment-isolation checks.
- These runs did not test a deployed Staging website, real Supabase Auth sessions, any nine-workspace E2E workflow, provider delivery or load capacity.

**No evidence = no pass.**

## 2. Phase 00 baseline matrix

| Area | Evidence / finding | Status |
|---|---|---|
| GitHub repository | QA branch and recursive tree inspected | PASS — repository access only |
| CI automation | Smoke, syntax, environment isolation and static audit scripts found | PASS — inventory only |
| GitHub Actions | Specific QA smoke and Chromium runs succeeded | PASS — those jobs only |
| Public routes | Large source inventory exists; route-by-route verification incomplete | IN PROGRESS |
| Interactive controls | Complete button/form/function inventory not yet established | NOT TESTED |
| Frontend/backend map | Multiple workspace audits exist; consolidated map incomplete | IN PROGRESS |
| Production catalog | Prior read-only catalog/security reviews exist | IN PROGRESS |
| Staging catalog | Prior read-only reviews exist; acceptance environment not approved | BLOCKED |
| Migration/schema parity | Material migration-history and permission/reference-data differences remain | BLOCKED |
| Staging deployment origin | krim-staging.pages.dev was not proven deployed/reachable | BLOCKED |
| Browser environment routing | Chromium passed against a local HTTPS fixture | PASS — local fixture only |
| Synthetic identities | None created; intentionally deferred pending isolation | NOT TESTED |
| Nine-workspace E2E | No complete synthetic-user journey evidence | NOT TESTED |
| Runtime tenant isolation | Source/catalog review exists; cross-org runtime tests absent | NOT TESTED |
| Payment/notification delivery | Real provider actions intentionally not run | NOT TESTED |
| Performance and recovery | No approved staging load baseline or restore drill evidence | NOT TESTED |

## 3. Existing automated tests and workflows

Scripts:
1. scripts/audit-krim-links.mjs — literal local HTML link and asset audit.
2. scripts/krim-complete-static-audit.mjs — static page, redirect, placeholder and integration-signal audit.
3. scripts/krim-environment-isolation.test.mjs — source-level fail-closed environment routing assertions.
4. scripts/krim-production-smoke.mjs — critical workflow source assertions.

Relevant workflows:
- .github/workflows/krim-static-link-audit.yml
- .github/workflows/krim-production-smoke.yml
- .github/workflows/krim-browser-environment-smoke.yml

CI limitations:
- No full Playwright suite against a deployed Staging URL is evidenced.
- No authenticated role suite, API contract suite, database integration suite or k6 load suite is evidenced.
- The static-link workflow has a preliminary scanner command using '|| true'; its output must be checked in the JSON/artifact and must not be assumed clean. A later step enforces the broken-local-reference count.
- CI success is not commercial readiness.

## 4. Consolidated release-blocking risk register

Severity: P0 = release blocker; P1 = must resolve before enabling affected workflow; P2 = controlled follow-up. Status: OPEN / BLOCKED / IN PROGRESS / NOT TESTED.

| ID | Severity | Area | Finding | Required acceptance evidence | Status |
|---|---|---|---|---|---|
| KR-001 | P0 | Staging parity | Prior discovery: Production 561 migration ledger entries vs Staging 34; same table count does not prove schema equivalence | Explain schema, extension, grant, policy, function, trigger, index, constraint and reference-data deltas; reviewed safe reconciliation plan; repeat diff | BLOCKED |
| KR-002 | P0 | Staging deployment | Staging Pages origin not proven reachable; Auth redirect settings previously mismatched | Prove exact deployed commit, HTTPS origin, DNS/TLS/HTTP; then review Auth Site URL and redirect allowlist | BLOCKED |
| KR-003 | P0 | Staging Storage | Prior audit found permissive AAL2 INSERT policy on krim-partner-verification that may OR-compose around stricter path/org policy | Correct in isolated environment; prove same-tenant allowed and wrong-path/cross-tenant/direct API denied | OPEN |
| KR-004 | P0 | Tenant isolation | No runtime two-tenant cross-org suite | Synthetic tenant tests for reads, writes, RPCs, Storage, signed links, exports and admin boundaries | NOT TESTED |
| KR-005 | P0 | Notifications | Universal nine-workspace event-to-delivery chain incomplete; legacy triggers mainly create in-app rows | Event → recipient → outbox → dispatcher → controlled sink → status/retry/dead-letter/monitoring tests | OPEN |
| KR-006 | P0 | Partner supply | Prior catalog showed zero verified partner orgs/capabilities and no accepted assignments | Verified onboarding, document review, capability/service-area approval and assignment evidence | OPEN |
| KR-007 | P0 | Customer booking | Booking release flag was fail-closed; no complete booking-to-assignment journey proof | Staging registration, org membership, booking validation, quote, acceptance, assignment, idempotency, audit and notification tests | BLOCKED |
| KR-008 | P0 | Payments | Historical pending/unprocessed webhook states require read-only reconciliation; double-entry ledger had no transaction entries in prior snapshot; refunds unproven | Provider dashboard reconciliation, sandbox order/signature/duplicate/failure/refund and balanced ledger tests | OPEN |
| KR-009 | P0 | Document lifecycle | Signed-link authorization/revocation/audit and orphan cleanup not proven; partner compliance upload can leave unregistered private objects | Lifecycle state machine, safe orphan reconciliation, reviewer auth, short-lived links, access audit, retention and tenant tests | OPEN |
| KR-010 | P0 | POD evidence | pod-documents bucket lacked bucket-level size/MIME limits in prior audit; complete intended upload path not proven | Keep disabled until strict bucket constraints, byte validation, malware quarantine and tenant authorization are verified | OPEN |
| KR-011 | P1 | Driver | Prior snapshots had no driver profiles, assignments, trips, GPS sessions or POD evidence; GPS consent gate disabled | Synthetic assignment → pickup → transit → POD journey; consent, expiry, revocation, rate limits and audit tests | NOT TESTED |
| KR-012 | P1 | Warehouse/Customs | Prior snapshots had no warehouse tasks/inventory/evidence or customs assignments/docs/custody runtime data | Receiving, QC dual review, inventory, custody, broker assignment, clearance and dispatch tests | NOT TESTED |
| KR-013 | P1 | Finance | Refund, reconciliation and ledger lifecycle incomplete; approval governance concerns | Invoice/payment/refund/fee/payable/reconciliation tests; balanced double-entry and dual-control proof | NOT TESTED |
| KR-014 | P1 | Enterprise/Admin | Approval writes and enterprise-specific authorization need stronger DB-level proof; some queues lacked grants | Permission-specific enforcement, AAL2/step-up, dual approval, separation of duties and audit | OPEN |
| KR-015 | P1 | Public tracking | Prior source review found Production endpoint/key hardcoding and no explicit rate-limit/observability proof | Safe environment routing, token entropy/expiry, rate limits, PII minimization, abuse controls and stale-client tests | OPEN |
| KR-016 | P1 | Browser security | Live response headers/CSP/Referrer-Policy/cache/frame controls not verified; sampled pages contain inline scripts/DOM sinks | Deployed header inspection, DOM data-flow review, CSP strategy, XSS/clickjacking/cache/referrer tests | NOT TESTED |
| KR-017 | P1 | Auth lifecycle | Recovery/session/MFA config and runtime flows not proven | Synthetic signup/login/logout/recovery/PKCE/session expiry/MFA/AAL1/AAL2/invite tests | NOT TESTED |
| KR-018 | P1 | Data export | User-scoped queue exists; dedicated worker, org-scoped selection, secure download broker and export bucket not identified | Scoped export worker, server authorization, signed download, expiry and audit tests | OPEN |
| KR-019 | P1 | Dependencies/CI | Floating external dependency versions; one scanner command masks failure; full lock/SBOM process absent | Pin dependencies, lockfile/SBOM and vulnerability scan; scanner failures must fail CI | OPEN |
| KR-020 | P1 | Monitoring/recovery | Complete alerting, incident response and restore-drill evidence absent | Health/error/queue/payment/notification alerts, backup verification, restore drill and runbook | NOT TESTED |
| KR-021 | P2 | Globalization | Full currency, locale, timezone and rounding test coverage absent | Supported-market matrix, ISO codes, DST/timezone boundaries, currency precision/formatting tests | NOT TESTED |
| KR-022 | P2 | Compatibility/performance | Broad browser/device and load evidence absent | Browser matrix and staged k6 ramps with explicit capacity limits | NOT TESTED |

## 5. Prior subsystem snapshots (refresh before release decisions)

- Production previously showed 18 shipments, 6 confirmed, 6 accepted customer quotes, zero partner assignments and zero verified capabilities.
- Partner verification had one open case; no verified partner organization was established in that snapshot.
- Driver profiles, assignments, vehicles, trip events, tracking sessions and POD evidence were zero in sampled catalogs.
- Warehouse tasks/inventory/evidence and customs assignments/documents/custody records were zero in sampled catalogs.
- Generic notification outbox/config was empty in the prior snapshot; workflow event triggers did not prove outbound delivery.
- Payment/webhook tables contained historical pending/unprocessed states; no replay or mutation was performed.
- Five Production Storage buckets were private; POD bucket controls and Staging policy composition need further verification.
- These are dated snapshots, not current live guarantees.

## 6. Fastest safe execution order

1. Finish Phase 00 repository, deployment, route, function, backend-map and test inventory.
2. Prove a real Staging deployment and reconcile schema/reference-data parity without resetting either environment.
3. Establish test isolation: dedicated project or verified disposable boundary, controlled notification sinks, payment sandbox, cleanup and project-identity assertions.
4. Add repeatable Playwright route/smoke tests. Do not create synthetic users before step 3 passes.
5. Run two-tenant Auth/RLS/Storage/API authorization tests.
6. Execute five commercial journeys: customer booking; partner verification/quote/assignment; driver delivery/POD; warehouse/customs; finance.
7. Complete essential notification delivery and operational monitoring.
8. Run security, globalization, browser compatibility, performance, failure/recovery and regression suites.
9. Conduct independent release review; permit a limited pilot only for routes/capabilities with verified partners and support coverage.

## 7. Evidence required for every test

Each test record must include: unique test ID; requirement; environment/project identity; commit SHA; synthetic identity/org/role; preconditions and fixture IDs; exact steps and expected result; actual machine assertion; database/audit evidence reference (never secrets or bearer tokens); timestamp; browser/runtime version; artifact; status PASS/FAIL/BLOCKED/NOT TESTED; defect severity; remediation commit and retest reference.

A test is PASS only when the assertion and independent evidence are both present. Source assertions and CI checks must not be described as end-to-end tests.

## 8. Mandatory safety controls

- No destructive tests against Production.
- No synthetic users/data writes until Staging identity and isolation are proven.
- No real money movement; use provider sandbox or mocked payment boundary.
- No real external notifications; use controlled test sinks, allowlists and dry-run assertions.
- No production secrets in browser code or test logs.
- No Production/Staging schema, policy, Auth, Storage, function, secret or deployment changes without explicit review and approval.
- No load testing against Production.
- No migration reset, blind copy or schema push based only on migration counts.
- Native/mobile application testing remains outside this programme.

## 9. Phase 00 exit criteria

- [ ] Full repository tree/source inventory with machine-readable output.
- [ ] All deployment targets and branch-to-deployment relationships/live origins verified.
- [ ] Complete route/page inventory: canonical, alias, protected, prototype and retired classifications.
- [ ] Complete interactive control/function inventory.
- [ ] Frontend-to-RPC/Edge Function/table/Storage map for all nine workspaces.
- [ ] Production/Staging schema, migrations, grants, policies, functions, triggers, extensions and reference-data differences explained.
- [ ] Existing test scripts, workflows and exact latest results catalogued.
- [ ] No ambiguity remains about which environment is safe for synthetic testing.

**Phase 00 disposition: OPEN.** Staging acceptance is blocked by deployment reachability, parity and security gaps. Continue read-only discovery and QA-branch evidence work until a reviewed remediation plan is approved.

## 10. Underlying evidence

This register indexes the detailed Phase 00 reports already committed under docs/testing/phase-00-*-2026-11-25.md, covering infrastructure, routes, environment/migrations, SQL/RLS/RPCs, Auth, notifications, shipment/partner/driver/warehouse/customs/finance, tracking/GPS, public APIs, Storage/documents, dependencies/browser security and data exports. The detailed reports remain the primary evidence; this register is the central release-control summary.

## 11. Change record

Documentation-only commit to QA branch. No application source, database, Storage, Auth, secrets, external providers, Production deployment or Staging deployment changed.