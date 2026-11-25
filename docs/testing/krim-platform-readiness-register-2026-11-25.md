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
| KR-001 | P0 | Staging parity | Refreshed live migration history: Production 561 vs Staging 34 (527-record difference); this is not a schema diff. Staging has selective/later-starting migration history; Postgres minor versions differ (17.6.1.165 vs 17.11.0.018) | Classify both ordered manifests; explain extension/schema/grant/policy/function/trigger/index/constraint/reference-data deltas; reviewed forward-only reconciliation plan; repeat diff. No reset or blind replay | BLOCKED |
| KR-002 | P0 | Staging deployment | Supabase project identity is verified (Production ebltviniygljwwseplph; Staging qrpcivhdxobiaofppbkl, distinct healthy projects). Candidate krim-staging.pages.dev deployment/commit remains unverified; main workflow deploys GitHub Pages only; QA config mapping is source-only | Obtain hosting deployment record, exact deployed SHA, domain/DNS/TLS/HTTP evidence; verify deployed config points to Staging; then review Auth Site URL and redirect allowlist | BLOCKED |
| KR-003 | P0 | Staging Storage | Prior audit found permissive AAL2 INSERT policy on krim-partner-verification that may OR-compose around stricter path/org policy | Correct in isolated environment; prove same-tenant allowed and wrong-path/cross-tenant/direct API denied | OPEN |
| KR-004 | P0 | Tenant isolation | No runtime two-tenant cross-org suite | Synthetic tenant tests for reads, writes, RPCs, Storage, signed links, exports and admin boundaries | NOT TESTED |
| KR-005 | P0 | Notifications | Refreshed live snapshot: Production legacy in-app 5; generic outbox/deliveries/retries/preferences/provider configs/operational runs all 0. Staging all 0. Eight triggers cover selected legacy shipment/payment/payout/support events only; no generic nine-workspace dispatcher proven | Canonical KRIM Core event map; recipient/tenant resolver; mandatory service-notice rules; provider dispatcher; controlled-sink delivery, retry, callback, dead-letter and alert evidence | OPEN |
| KR-006 | P0 | Partner supply | Prior catalog showed zero verified partner orgs/capabilities and no accepted assignments | Verified onboarding, document review, capability/service-area approval and assignment evidence | OPEN |
| KR-007 | P0 | Customer booking | Booking release flag was fail-closed; no complete booking-to-assignment journey proof | Staging registration, org membership, booking validation, quote, acceptance, assignment, idempotency, audit and notification tests | BLOCKED |
| KR-008 | P0 | Payments | Refreshed snapshot: payment_orders 6 (1 paid/5 created); payments 4 (2 paid/2 pending); webhook events 10 (6 processed/4 unprocessed); revenue_ledger 1; double-entry ledger 14 accounts but 0 transactions/entries; refunds 0; one legacy payout marked paid is not bank settlement evidence | Read-only correlate four unprocessed webhook events; sandbox order/signature/duplicate/failure/refund tests; canonical payment model; balanced double-entry posting/reversal and independently verified payout settlement | OPEN |
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

## 12. Refreshed evidence and consolidated remediation execution register — 2026-11-25

This section supersedes older snapshot wording where newer subsystem audits provide a fresher count or more precise source-level finding. It does not convert source/catalog inspection into runtime PASS.

### 12.1 Refreshed high-priority evidence

| Domain | Current evidence from latest focused audit | Release disposition |
|---|---|---|
| RLS / tenant boundaries | Production and Staging: 391 public tables, 6 private tables; 0 public tables with RLS disabled; 367 public tables with policies; 24 without policies (sampled grants are service_role-only or absent). Production finance-control tables have broad authenticated write grants and organization-level policies. Staging critical-table authenticated grants are absent. | BLOCKED — runtime tenant tests absent; finance control writes unsafe until narrowed |
| Privileged RPCs | Production: 632 non-system functions, 474 SECURITY DEFINER; 0 anon-executable, 174 authenticated-executable; no unpinned search_path found. Fourteen authenticated-executable definer functions lack literal auth.uid in their own body and require delegated-authorization review. Staging: 626 total, 488 definer; one anon-executable trigger function has default ACL hygiene issue; no unpinned search_path found. | NOT CERTIFIED — source/catalog review only; delegated identity and caller-supplied actor/org tests absent |
| Payments | Production: 6 payment_orders (5 created, 1 paid); 4 payments (2 paid, 2 pending); 10 webhook events (6 processed, 4 unprocessed); 1 revenue_ledger row; 14 ledger accounts but 0 double-entry transactions and 0 entries; 0 refund requests/events; 1 legacy payout marked paid without bank-settlement proof. Staging payment tables sampled at zero. | BLOCKED — four unprocessed events need safe correlation; accounting/refund/payout lifecycle unproven |
| Notifications | Production: 5 legacy in-app rows; generic outbox, delivery, retry, preference, provider-config, operational-run and run-event tables all zero. Staging all zero. Eight legacy triggers cover selected shipment/payment/payout/support events. Reviewed provider adapter is diagnostic/test-oriented; retry worker is founder Telegram-specific; Resend worker is partner-application follow-up-specific. | BLOCKED — no generic nine-workspace dispatcher or delivery evidence |
| Staging readiness | Staging deployment origin remains unverified/inconclusive; previous migration ledger snapshot 561 Production vs 34 Staging; permission/reference data and auth/storage parity gaps remain. Do not reset or blindly copy environments. | BLOCKED — no synthetic identities or writes until acceptance |
| Browser security | Sampled source has inline scripts/handlers and DOM HTML sinks; no common repo header config/CSP meta in samples; live response headers not verified. | NOT VERIFIED — deployed header and full data-flow tests required |
| Document and Storage | Private buckets in prior snapshot; POD bucket lacked bucket-level size/MIME limits; byte-signature validation/malware quarantine, signed-link revocation/audit and orphan cleanup not proven; enterprise vault includes static/prototype routes. | BLOCKED for affected evidence workflows |
| Booking / supply | Booking release flag was fail-closed in prior source review; prior catalog had zero verified partner orgs/capabilities and zero accepted assignments. | BLOCKED — only verified route/service can be piloted after end-to-end proof |
| Driver / warehouse / customs | Prior snapshots show no operational driver assignments/tracking/POD, warehouse task/inventory evidence or customs assignment/custody evidence. | NOT TESTED — isolated synthetic journeys required |
| CI / browser automation | QA smoke workflows passed source assertions and local Chromium environment fixture. No deployed-Staging authenticated Playwright E2E, API contract, RLS adversarial or k6 capacity suite is evidenced. | PASS only for named CI jobs; business journeys remain NOT TESTED |

### 12.2 Ordered remediation backlog

The order below minimizes risk and avoids building test evidence on an untrusted environment. A later item must not be treated as permission to skip an earlier gate.

| Order | Work item | Priority | Required completion evidence | Gate |
|---:|---|---|---|---|
| 1 | Freeze release-sensitive changes; name canonical Production and Staging project/origin/branch ownership; capture immutable commit and environment fingerprints | P0 | Signed-off environment map, deployed commit and origin, project IDs, DNS/TLS/HTTP proof; no secrets in artifacts | Gate A — environment identity |
| 2 | Reconcile Staging migrations/schema without reset or blind copy; compare extensions, tables/columns, indexes, constraints, triggers, functions, grants, RLS, Storage policies and reference data | P0 | Reviewed delta report, migration lineage explanation, approved safe plan and repeatable parity diff | Gate B — staging parity |
| 3 | Fix Staging Storage partner-verification policy composition and verify least-privilege bucket/path/tenant boundaries | P0 | Same-tenant allow + wrong-path/cross-tenant/anonymous/direct-API deny evidence | Gate C — storage isolation |
| 4 | Close Production financial-control direct-write gap using narrow server/RPC transitions; enforce finance permission, AAL2 where required, maker-checker and creator/approver separation | P0 | Catalog/grant/policy proof plus negative tests for ordinary member, wrong org, creator-self-approval, stale role and non-AAL2 | Gate D — privileged finance controls |
| 5 | Review all authenticated-executable SECURITY DEFINER functions, delegated guards and caller-supplied actor/org IDs; remove unintended anon/default ACLs | P0 | Function-by-function authorization matrix and adversarial RPC tests | Gate E — RPC authorization |
| 6 | Reconcile four unprocessed Razorpay webhook events read-only; establish canonical payment/order/ledger model | P0 | Provider-side correlation evidence; no blind replay; idempotent sandbox webhook tests | Gate F — payment integrity |
| 7 | Implement and verify balanced double-entry posting, fee/commission/payable, refund reversal and payout settlement reconciliation | P0 | Debit=credit evidence for all test cases, duplicate/reversal/retry cases, bank/provider settlement status | Gate G — financial correctness |
| 8 | Build canonical notification event contract and recipient resolver for all nine workspaces and new KRIM Core lifecycle | P0 | Event catalog, recipient/tenant/role tests, mandatory service notice vs marketing preference rules | Gate H — notification correctness |
| 9 | Complete generic notification dispatcher, controlled providers/sinks, idempotency, retries, dead-letter, callbacks and operational alerting | P0 | Synthetic event → scoped recipient → outbox → provider test sink → accepted/delivered/failure/retry/dead-letter evidence | Gate I — communication reliability |
| 10 | Verify customer booking → quote → payment → partner assignment → shipment milestones; retain fail-closed behavior until all steps pass | P0 | Repeatable staging Playwright/API/DB audit trace with duplicate and unauthorized attempts | Gate J — customer booking |
| 11 | Verify partner onboarding, evidence review, capability/service-area approval and partner quote/assignment acceptance | P0 | Verified synthetic partner journey and reviewer/tenant audit trail | Gate K — supply activation |
| 12 | Secure document/POD lifecycle: byte validation, size/MIME limits, malware quarantine, signed-link broker/revocation, access audit and orphan reconciliation | P0 | Allowed/denied file matrix, expired/revoked URL denial, tenant isolation and cleanup evidence | Gate L — evidence integrity |
| 13 | Complete driver pickup/transit/delivery/POD journey with consent, GPS expiry/revocation and rate limiting | P1 | Synthetic driver journey and consent/security negative tests | Gate M — driver operations |
| 14 | Complete warehouse QC/custody/inventory and customs dossier/clearance/hold workflows | P1 | Dual-review, inventory quality segregation, custody chain and customs state-transition evidence | Gate N — operational custody |
| 15 | Complete enterprise/admin permission matrix, export worker and signed-download lifecycle | P1 | Tenant-scoped role matrix, least-privilege export and audit trail | Gate O — enterprise governance |
| 16 | Verify browser response headers, CSP strategy, DOM sink data flow, redirect validation, auth storage and token non-leakage | P1 | Captured deployed headers and harmless adversarial browser tests | Gate P — browser security |
| 17 | Add monitoring, backup verification, restore drill, incident runbooks and queue/payment/notification alerts | P1 | Alert injection, owner acknowledgement, backup integrity and restore evidence | Gate Q — operations resilience |
| 18 | Complete locale/currency/time-zone and supported-route rules | P2 | India-first supported market matrix and rounding/time-zone test suite | Gate R — market correctness |
| 19 | Run compatibility, accessibility and staged performance tests only on approved isolated Staging | P2 | Browser/device matrix and staged load results; no Production load | Gate S — scale confidence |
| 20 | Independent regression/security/release review and controlled pilot approval | P0 final gate | All P0 gates closed; affected P1 gates closed; no unresolved critical/high defects; signed evidence pack | Gate T — pilot authorization |

### 12.3 Release policy

- **No unrestricted onboarding, public booking release, real payment collection for unverified flows, or general partner activation** while any P0 gate remains open.
- A limited India-first pilot may be considered only after all relevant P0 gates close and the exact route, mode, partner capability, capacity, pricing, insurance/compliance, service support and exception ownership are independently verified.
- Payment success, a legacy payout status, an in-app notification row, a successful source-level CI job or an empty error table is not proof of the full business outcome.
- Runtime tests remain NOT TESTED until executed with approved synthetic identities and controlled provider sinks in an accepted Staging environment.
- Any production change requires its own explicit approval and rollback plan; this register is not change authorization.

### 12.4 Evidence index — primary detailed reports

The following focused reports are primary evidence and should be read alongside this register:

- `phase-00-live-rls-grants-and-tenant-isolation-audit-2026-11-25.md`
- `phase-00-security-definer-and-privileged-rpc-authorization-audit-2026-11-25.md`
- `phase-00-razorpay-payment-webhook-ledger-refund-payout-audit-2026-11-25.md`
- `phase-00-notification-communication-delivery-reliability-audit-2026-11-25.md`
- `phase-00-staging-deployment-origin-and-callback-reachability-2026-11-25.md`
- `phase-00-browser-security-headers-storage-and-dom-injection-audit-2026-11-25.md`
- `phase-00-storage-upload-evidence-ownership-signed-url-security-audit-2026-11-25.md`
- `phase-00-document-route-authentication-authorization-boundary-audit-2026-11-25.md`
- `phase-00-shared-authentication-session-lifecycle-source-audit-2026-11-25.md`
- `phase-00-warehouse-customs-operations-custody-chain-audit-2026-11-25.md`

### 12.5 Current disposition

**Phase 00 remains IN PROGRESS. Staging remains BLOCKED. KRIM is NOT RELEASE-READY.** The next safe engineering action is not to enable live features or generate test users: it is to establish and approve the Staging environment identity/parity baseline, then close the P0 authorization and financial-control defects in a controlled non-production workflow.

No application, database, Storage, Auth, provider, deployment or Production configuration was changed by this register update.


## 13. Gate A execution result — 2026-11-25

The focused report `phase-00-gate-a-staging-environment-identity-baseline-2026-11-25.md` is committed on this QA branch.

- Production Supabase identity: PASS — `ebltviniygljwwseplph`, region `ap-northeast-1`, ACTIVE_HEALTHY.
- Staging Supabase identity: PASS — `qrpcivhdxobiaofppbkl`, region `ap-south-1`, ACTIVE_HEALTHY.
- Project refs/API URLs are distinct; both belong to organization `mwvzahnqzveoapjggsug`.
- Migration history reconfirmed: Production 561, Staging 34. This is a migration-history difference, not a complete schema diff.
- GitHub `main` SHA: `72d75a18f985ceb09e468839435ee95700e11e46`; QA branch SHA at inspection: `b28c8e8251297ba1923b1de2c5d7fd327e91eb6b`.
- The inspected main deployment workflow deploys GitHub Pages from `main`; no Cloudflare Pages deployment step is present.
- QA `config.js` maps `krim-staging.pages.dev` to the Staging project, but deployed hosting identity and deployed commit are not proven.

**Gate A disposition: PARTIAL PASS / BLOCKED.** Project identity is proven; staging website-to-project binding is not. No synthetic users or authenticated tests are authorized. Continue with obtaining the actual hosting deployment record, then Gate B migration/schema reconciliation. No Production/Staging changes were made.


## 14. Gate B execution result — live schema/migration parity (2026-11-25)

Focused report: `phase-00-gate-b-live-production-staging-schema-migration-parity-2026-11-25.md`.

**Gate B: BLOCKED.** Read-only live comparison found:
- Production migration history 561; Staging 34; **zero shared migration version identifiers**.
- Public tables 391 and public columns 4,964 in both; table-name, column-definition and public RLS policy fingerprints match.
- Public functions differ (366 vs 376 and different definitions fingerprint); public triggers differ (113 vs 115); public index and constraint fingerprints differ despite equal counts (1,561 indexes; 1,807 constraints).
- All-schema inventory differs (443 vs 439 base tables; 5,516 vs 5,483 columns; 118 vs 24 non-system schemas).
- Production has `pg_cron` and `pg_net`; Staging does not.

**Interpretation:** Staging is not simply a later/earlier point in the same recorded migration chain. Establish its bootstrap provenance and create exact object-level diffs before any repair. No reset, blind replay, rebase, merge, DDL/DML or deployment. Synthetic identities remain BLOCKED until Gate A deployment binding and Gate B reconciliation are accepted.


## 15. Gate B1 execution result — Staging migration provenance (2026-11-25)

Focused report: `phase-00-gate-b1-staging-migration-provenance-investigation-2026-11-25.md`.

**B1: BLOCKED.** Current `supabase/migrations` contains 368 files on both `main` and QA, with identical filenames and blob SHAs. Comparing live migration ledger names to exact current SQL filenames:
- Production: 291/561 exact name matches; 270 ledger names have no exact current file.
- Staging: 3/34 exact name matches; 31 ledger names have no exact current file.
- Staging's three exact-name matches: `restore_driver_trip_event_rpc_access`, `admin_driver_licence_expiry_control`, `refine_admin_driver_licence_expiry_rpc_security`.

Some Staging ledger names appear timestamp-prefixed or malformed; this requires historical provenance investigation. Current repository files do not prove the SQL that was applied. Search deleted/renamed Git history and obtain the original Staging bootstrap/provisioning evidence before proposing changes. Do not edit migration ledgers or reset/replay migrations. No DB changes were made.


## 16. Gate B1b — historical Git provenance search (2026-11-25)

Focused report: `phase-00-gate-b1b-historical-git-provenance-search-2026-11-25.md`.

**B1b: PARTIAL PASS; B1 remains BLOCKED.** The 31 Staging migration names without exact current source files were each checked against exact GitHub `supabase/migrations/<name>.sql` path history; all 31 returned zero commits. The repository migration-directory history returned 466 commits from 2026-10-16 through 2026-11-24, so it does not cover Production's initial 2026-09-29 migration history. A 2026-11-17 historical tree and ten Staging-named branches were also inspected; none supplied the missing 31-file Staging bundle. One historical driver-trip migration matches by name but has a different timestamp from the Staging ledger version. Two other name matches have source files dated 2026-11-23, also with different ledger timestamps.

This is not proof that no external/local SQL bundle exists or that SQL was never applied manually. Original Staging provisioning records and applied SQL checksums remain NOT TESTED. Do not edit or replay migration ledgers. No database writes or deployments were made.


## 16. Gate B1.1 — historical Git provenance search (2026-11-25)

Focused report: `phase-00-gate-b1-1-staging-migration-git-history-search-2026-11-25.md`.

**Result: BLOCKED; no historical source recovered.** GitHub exact-path commit-history queries for all 27 normal-form unmatched Staging migration names returned no commits. Eight representative exact-name code searches against the repository default branch returned no matches. This does not exclude alternate filenames, deleted/renamed files, inaccessible branches/tags, other repositories, operator workstations, backups, SQL editor history, or external deployment bundles.

Four unusual ledger records remain for separate inspection, including two timestamp-prefixed country-pack entries. Staging migration provenance is still not established. Required next evidence: exhaustive accessible branch/tag tree and rename search, then the original Staging bootstrap source and historical SQL/checksums from the project operator. No database writes, migration execution, ledger edits, reset, or deployment occurred.


## 17. Gate B1.2 — repository branch and alternate migration-path sweep (2026-11-25)

Focused report: `phase-00-gate-b1-2-all-branches-migration-path-sweep-2026-11-25.md`.

GitHub branch pagination returned **256 visible branches** (100 + 100 + 56). Targeted migration-related refs inspected:
- `main`: 368 migrations
- QA baseline: 368 migrations, same inventory/blob SHAs as main
- `audit/migration-baseline-collision-inventory-2026-11-24`: 368, no missing Staging names
- `audit/migration-collision-content-review-2026-11-24`: 368, no missing Staging names
- `testing/secure-staging-supabase-target`: 368, no missing Staging names
- `fix/platform-admin-canonical-schema`: 26, no missing Staging names

This was a targeted branch/path check, not a recursive all-branch/all-tag tree scan. Several staging-named branches do not contain `supabase/migrations` at the inspected ref. No original Staging SQL source or bootstrap provenance was recovered. **B1 remains BLOCKED.** Next required source is the original Staging provisioning/bootstrap evidence or an exhaustive recursive branch/tag object search. No database or provider changes occurred.


## 18. Gate B1.3 — historical migration-recovery artifacts and schema-export path (2026-11-25)

Focused report: `phase-00-gate-b1-3-historical-schema-export-recovery-path-2026-11-25.md`.

**Important discovery:** Existing repository history contains a guarded encrypted Production schema-only export workflow, operator instructions, and historical successful export records. The latest documented run is GitHub Actions run `43793099331`, artifact ID `14193475858`, created 2026-11-16 and expired 2026-11-17. Its archive and encrypted SQL checksums were verified, but the SQL was not decrypted. The earlier 2026-11-09 artifact also expired. Neither historical export is evidence of an import into the current Staging project.

The existing workflow requires the GitHub repository secrets `KRIM_PRODUCTION_DB_URL` and `KRIM_SCHEMA_EXPORT_PASSPHRASE`, exports only `public,private,krim_internal,graphql_public`, runs data-statement and common-credential scans, encrypts the dump, and uploads ciphertext/checksum only for one day. It does not automatically apply SQL. Manual offline secret/ownership/grant/extension review is still mandatory.

Historical 2026-11-07 documents described an earlier Staging snapshot with zero application tables; that historical state is not current. Current 2026-11-25 live Staging has 391 public tables and 34 migration records. A Production schema export can support a controlled baseline reconstruction but cannot prove the exact SQL provenance of each Staging ledger row.

**Disposition: B1 BLOCKED.** Next step is operator verification of existing secrets and a manually authorized fresh export, followed by private offline review and isolated baseline reconstruction. This audit did not dispatch the workflow, access secrets, decrypt SQL, modify either database, or deploy anything.


## 19. Gate B1.4 — export workflow execution and artifact availability (2026-11-25)

Focused report: `phase-00-gate-b1-4-export-workflow-and-artifact-availability-2026-11-25.md`.

Read-only GitHub verification confirms the encrypted schema export workflow exists on `main` and the QA baseline with identical blob SHA `1cb04eaa45b4a2a77ef42a4885c3418ace6a5835`. Historical Actions run `43793099331` (run attempt 2) completed successfully on 2026-11-16. Its secret-check, CLI install, URI validation, schema export/encryption, and artifact upload steps all succeeded. This establishes secrets were present at that historical time only.

The current artifact inventory for that run returns zero artifacts. The historical export cannot currently be downloaded. The GitHub connector does not expose the repository Secrets API; current secret presence remains NOT TESTED. An authorized owner must privately verify `KRIM_PRODUCTION_DB_URL` and `KRIM_SCHEMA_EXPORT_PASSPHRASE`, then manually dispatch a fresh export. No dispatch was performed because it creates a sensitive artifact and reads the Production schema.

**Disposition: B1 BLOCKED.** Workflow implementation and historical execution verified; current secret presence, fresh export, and private review pending. No secrets were read, no workflow was run, and no Production/Staging database or deployment changes occurred.


## 18. Gate C — Live Edge Function Deployment Parity (25 Nov 2026)
- Production and Staging Supabase projects both report `ACTIVE_HEALTHY`.
- Live deployed Edge Function inventory: Production 22 ACTIVE; Staging 3 ACTIVE.
- Only common slug: `global-admin-control`; function deployment parity is therefore not established.
- Production still contains legacy Cashfree order, verification and webhook functions; no deletion or invocation performed.
- Staging-only functions include `krim-resend-email-worker` and `owner-testing-authorize`.
- Gate C: **BLOCKED** pending canonical manifest, source/version provenance, endpoint dependency mapping, JWT policy review and approved Staging deployment plan.
- Evidence: [Gate C report](phase-00-gate-c-edge-function-deployment-parity-2026-11-25.md).
- Safety: metadata inventory only; no function invocation, secrets, SQL, auth/provider operation, workflow dispatch or environment write.


## 20. Gate A2 — website deployment and environment-routing source verification (2026-11-25)

Focused report: `phase-00-gate-a2-website-deployment-and-environment-routing-2026-11-25.md`.

**Gate A2: BLOCKED.** Read-only GitHub inspection confirms the `main` Pages workflow deploys GitHub Pages from `main` only; it has no Cloudflare Pages/Staging deployment job. The current `main` `config.js` accepts a page-injected environment override, defaults unknown hostnames to Production, and reuses a pre-existing global Supabase client. The QA branch version is safer (explicit host allowlist, fail-closed unknown hosts, clears injected client globals, and maps the candidate Staging hostname to the Staging Supabase project), but it is not deployed by the inspected workflow.

Live origin fetches were inconclusive: available web retrieval returned errors and direct DNS resolution was unavailable from the execution environment. This is NOT evidence that either origin is down. Production served commit/config and Staging hosting project/deployment SHA/DNS/TLS/HTTP remain NOT TESTED.

**Required:** verify the real Staging hosting project and deployment record, served config and Supabase project ref; confirm Auth Site URL/redirect allowlists; separately review and remediate the main-branch fail-open environment selection before deploying the safer allowlist. No merge, deployment, workflow dispatch, database write, secret access or provider operation occurred. No synthetic users are authorized.


## 21. Gate A3 — authentication redirect and client-initialization source audit (2026-11-25)

Focused report: `phase-00-gate-a3-authentication-redirect-and-client-audit-2026-11-25.md`.

**Gate A3: BLOCKED.** Main `auth-core.js` creates a separate Supabase client using a hardcoded Production URL/key, bypassing the environment resolver and potentially connecting non-production pages to Production Auth/data. Main config also retains page/meta override, unknown-host Production fallback and pre-existing global client reuse. QA source instead imports a shared client whose project ref and URL are checked against the approved Production/Staging project IDs; this is source-only and is not deployed by the inspected Pages workflow. Main auth-core also imports a floating Supabase JS v2 CDN URL.

Production and Staging Supabase Auth Site URL/redirect allowlists were not inspected. Exact runtime callback flows and deployed Auth journeys remain NOT TESTED. Guessed callback source paths were not present at those exact paths; this does not prove callbacks are absent.

Required: privately verify both projects' Auth URL settings; map every actual auth redirect target; unify all pages on one hostname-verified client; pin the Supabase JS version; then run isolated PKCE/recovery/invitation/MFA redirect tests only after Staging acceptance. No Auth settings, secrets, users, emails, databases or deployments were changed.


## 22. Gate C1 — frontend-to-backend integration inventory baseline (2026-11-25)

Focused report: `phase-00-gate-c1-frontend-backend-integration-inventory-2026-11-25.md`.

Main baseline commit `72d75a18f985ceb09e468839435ee95700e11e46` was enumerated using the recursive Git tree API (`truncated=false`): 2,180 blobs, 1,023 HTML, 134 JS, 377 SQL, and 20 Edge Function entrypoints. Workspace nested HTML counts: Customer 2; Partner 19; Driver 39; Warehouse 26; Customs 29; Finance 24; Operations 28; Enterprise 14; Admin 22. Counts include staging/workflow copies and are not unique deployed route counts.

Twenty Edge Function entrypoints include Razorpay order/webhook/refund/verification, legacy Cashfree aliases, notification adapter/retry worker, driver GPS/tracking, public shipment tracking, global admin, KRIM AI and public inquiry. No deployed status or runtime behavior inferred.

Targeted page samples show Enterprise referencing both canonical `krim_shipments` and legacy `shipment_requests`; Cashfree aliases remain tracked despite Razorpay-only direction; notification function surface remains limited and generic all-workspace delivery is not proven. Exhaustive route-to-RPC/function/table/bucket mapping remains NOT TESTED. Gate C1 is PARTIAL PASS / BLOCKED pending full static extraction and accepted Staging runtime validation. No code or environment changed.


## 23. Gate C2 — complete HTML page-route manifest (2026-11-25)

Generated `phase-00-page-route-manifest-2026-11-25.csv` from immutable main tree commit `72d75a18f985ceb09e468839435ee95700e11e46`. GitHub recursive tree returned `truncated=false`; all 1,023 tracked HTML files are represented as individual CSV rows. Path-based primary candidates: 103 staging-only, 13 workflow, 38 index/dashboard entry candidates, 869 active/other candidates. Zero explicit legacy path candidates detected.

These are structural filename/path candidates only. Redirect behavior, inbound-link/orphan status, deployed routes, actual legacy use and browser functionality have not been verified. All rows remain NOT TESTED at runtime. No deletion/retirement is authorized. Gate C2 PARTIAL PASS / BLOCKED. Method and limits are documented in `phase-00-gate-c2-page-route-manifest-method-and-disposition-2026-11-25.md`.


## 24. Gate C3 — HTML internal-link graph sample (2026-11-25)

Inspected eight representative public/workspace entry pages against the complete tracked Git tree at immutable main commit `72d75a18f985ceb09e468839435ee95700e11e46`. Extracted 289 literal local href/src references; all 289 resolve to tracked targets after correctly normalizing GitHub Pages `/logistics-saas/` base-path links. The first raw pass flagged 20 such base-path assets, but these were false positives and were resolved after base-prefix normalization. No fetch errors.

Sample includes homepage, about, contact, admin shell, Customer, Partner, Warehouse and Enterprise entry pages. Whole-repository links, JS-generated navigation, CSS references, form actions, redirects, deployed HTTP and orphan detection remain NOT TESTED. Gate C3 PARTIAL PASS / BLOCKED. Detailed evidence: `phase-00-gate-c3-html-link-graph-sample-2026-11-25.md`. No app or environment changes.


## 25. Gate C3.1 — repository-wide static link graph audit execution

Reviewed existing QA branch scripts `scripts/audit-krim-links.mjs`, `scripts/krim-complete-static-audit.mjs`, and workflow `.github/workflows/krim-static-link-audit.yml`. They recursively scan HTML, resolve literal local paths and GitHub Pages base-prefix references, check canonical route registry destinations, count static inbound HTML edges, and produce zero-inbound candidate lists and artifacts. Zero-inbound is not proof of orphan status. The first link-audit command uses `|| true`, but a later enforcement step fails if the reported broken reference count is positive.

A new QA-branch documentation commit triggers the existing push workflow. Repository-wide counts and findings remain PENDING until its run and artifacts are inspected; no results are inferred. Deployed HTTP routes, runtime redirects and genuine orphan status remain NOT TESTED. Detailed note: `phase-00-gate-c3-1-repository-wide-static-link-audit-2026-11-25.md`.


## 25. Gate C3 — repository-wide static link graph (2026-11-25)

GitHub Actions run `45593997090` completed SUCCESS at QA branch source commit `3f37e0817bee4ba1ae773f18f9ef5a7ed0e934c0`. Complete static audit scanned 2,131 files / 1,018 HTML pages, generated 9,453 literal static HTML-to-HTML edges, found 0 unresolved local/root references, 0 exact duplicate groups and 0 placeholder/demo/TODO signals. Independent local-link audit also found 0 broken references and validated 27 canonical route destinations.

Graph results: 757 HTML pages have inbound literal static links; 89 zero-inbound candidates remain NOT TESTED as true orphans. There are 343 redirect/compatibility routes, 523 noindex pages, 103 staging pages (48 without visible backend signals), 67 operational-looking non-staging pages without visible Supabase signals, and 194 operational pages with backend-related signals. These are source-level review classifications, not runtime proof.

Gate C3 static link resolution PASS; true orphan status, deployed HTTP/redirect behavior and runtime navigation NOT TESTED. Overall PARTIAL PASS / BLOCKED. No application pages deleted, no live deployment, database or provider state changed. Detailed report: `phase-00-gate-c3-repository-wide-link-graph-2026-11-25.md`.


## 25. Gate C3 — repository-wide static link and route graph audit (2026-11-25)

GitHub Actions run `45594126547` completed SUCCESS on QA commit `6306bf1b65fa5b6fffb99986efe0b5603b23a6c1`. Static local-link artifact: 1,018 HTML pages scanned, 27 canonical routes checked, zero broken literal local references, zero legacy-brand references, zero operational-risk heuristic findings. Complete route graph artifact: 2,133 files, 1,018 HTML pages, 9,453 static HTML edges, zero unresolved references, 757 pages with inbound static links, 89 zero-inbound candidates, 343 compatibility redirect routes, zero exact duplicate groups, zero placeholder/TODO wording signals, 523 noindex pages, 103 staging pages. Integration review signals: 67 operational-looking pages without visible Supabase signal in own HTML; 48 staging pages without visible backend signals; 194 operational pages with backend-related signals in own HTML or linked local scripts.

The 89 zero-inbound results are candidates, not confirmed orphans. 26 have noindex; two are under staging paths. Auth callbacks, emailed deep links, bookmarks, JS navigation and external links may be legitimate entry mechanisms. No route deletion recommended. Redirects were inventoried but not runtime-tested. CI scan count is 1,018 versus prior Git-tree manifest 1,023; CI excludes .github and other ignored directories, so coverage discrepancy remains noted. No merge/deployment or Production/Staging writes. Gate C3 PARTIAL PASS / BLOCKED pending candidate triage and runtime route checks in accepted Staging. Full report: `phase-00-gate-c3-repository-wide-static-link-audit-results-2026-11-25.md`.


## 26. Gate C3.1 — repository-wide static link audit RESULTS (2026-11-25)

GitHub Actions run `45594112014` completed SUCCESS on QA commit `47d38c9bc96266f4c02167500e0f2da79ad4667f`. The run scanned 2,132 repository files / 1,018 HTML pages and extracted 9,453 literal static HTML edges. It found 0 unresolved local/root references, checked 27 canonical route entries, 0 exact duplicate groups and 0 placeholder wording candidates. The independent link-audit JSON also reports 0 broken references, 0 legacy-brand findings and 0 operational-risk pattern findings. Both audit artifacts uploaded successfully.

Graph findings: 757 HTML pages have inbound static HTML links; 89 have zero inbound static HTML edges and are only orphan *candidates* (not confirmed orphans). The 89 comprise 39 public, 28 auth, 7 app, 5 src, and 10 other/root paths; 26 of 89 carry noindex, and 2 are staging paths. 343 compatibility redirect candidates detected, 335 with noindex. 103 staging pages; 48 without visible Supabase/backend signals. 67 operational-looking pages without visible backend signals, and 194 operational pages with some backend-related signal. These signal counts are heuristics and are not runtime proof.

Gate C3.1 PASS for repository-wide literal static reference scan and canonical route existence. Redirect-chain/browser checks, genuine orphan classification, and backend/runtime verification remain NOT TESTED. Overall PARTIAL PASS / BLOCKED. Full results and all 89 candidates: `phase-00-gate-c3-1-repository-wide-static-link-audit-results-2026-11-25.md`. Workflow: run 45594112014.


## 27. Gate C3.2 — zero-inbound route and redirect classification

Classified all 89 zero-inbound HTML candidates from the repository-wide CI artifact: auth 28; public 39; app 7; root 5; src 5; control/docs/platform/scripts/templates 1 each. 26 carry noindex, 63 do not; 42 show direct backend signals and 47 do not; two are staging paths. Auth routes and system fallbacks are likely legitimate direct-entry routes, not public-navigation orphans. Public routes require discoverability/route-owner review. src/platform/template/test fixtures require explicit internal-vs-live classification.

Reviewed all 343 redirect candidates by namespace: public 324, app 11, partner 3, root 2, legal 2, auth 1. 335/343 are noindex; eight are not. All eight non-noindex destinations exist in the tracked source tree after relative-path normalization, but browser redirects, status codes, query/hash preservation, auth context and loops are NOT TESTED. Two of the eight target a staging-named driver page and need release scrutiny. No route was removed or changed.

Gate C3.2 PARTIAL PASS / BLOCKED. No page is confirmed orphaned or approved for deletion. Full classification: `phase-00-gate-c3-2-zero-inbound-route-and-redirect-classification-2026-11-25.md`.


## 28. Gate C3.3 — canonical route registry and auth/email deep-link reconciliation

Read `config.js` canonical `window.KRIM_ROUTES` (27 routes). Exactly one of the 89 zero-inbound candidates is explicitly registered: `app/driver/module-01-assignment-inbox.html`. This confirms zero-inbound does not mean orphan. The registry is not a complete catalogue of all HTML routes.

Source-backed direct-entry routes: customer signup `auth/signup.html` sends confirmation to `auth/auth-callback.html`; callback exchanges the code and routes by account type to role-specific sign-in, not direct workspace. `auth/forgot-password.html` sends reset links to `auth/reset-password.html`. `auth/verify-email.html` implements manual OTP/resend. Driver invite token is handed from callback query to sessionStorage then accepted in driver sign-in RPC. Organization invitation UI exists but issuer/template and completed backend acceptance are not proven. `auth/partner-redirect.html` has no inbound from inspected partner sign-in.

Prior auth follow-up records corrected callback authorization bypass and driver MFA AAL2 issue; nevertheless Supabase Site URL, redirect allowlist, email templates, rate limits and MFA settings remain unverified. No emails or Auth actions were executed. Legacy `app/index.html` remains a weaker customer route than `app/customer/index.html`; other duplicate/unconfirmed paths require owner review.

Gate C3.3 PARTIAL PASS / BLOCKED. Full evidence: `phase-00-gate-c3-3-canonical-route-and-auth-deeplink-reconciliation-2026-11-25.md`.


## 29. Gate C3.4 — complete zero-inbound route disposition register

All 89 candidates from the repository-wide C3.1 list are individually assigned one conservative disposition: KEEP, KEEP AS DIRECT ENTRY, RESTRICT, CONSOLIDATE REVIEW, or RETIRE REVIEW. The full route-by-route register is `phase-00-gate-c3-4-zero-inbound-route-disposition-register-2026-11-25.md`.

Key controls: do not retire any route without owner/dependency approval; `app/index.html` remains a weaker legacy customer workspace; auth callback/reset are direct-entry routes; invitation sender/acceptance remains unverified; staging preview routes remain restricted; internal control/admin/growth/developer/chaos surfaces require server-side access controls; preserve all 343 compatibility redirects pending runtime chain tests.

Gate C3.4 PARTIAL PASS / BLOCKED. Static route disposition is complete, but full 89-page dependency review, owner approvals and browser/HTTP/auth runtime tests remain NOT TESTED/BLOCKED. No page or environment was changed.


## 30. Gate C3.5 — compatibility redirect safety register

Parsed all 343 redirect records from successful static-audit artifact run `45594112014` (artifact SHA-256 `bc8b73df21ee0cca5d0066435f7fb8dd2be184cb7dacc14b9411fed889e38c39`). 338 static targets resolve to HTML paths in repository inventory; five redirects are script-driven and were source-inspected. Static redirect-map traversal found 22 redirect-chain edges and zero static cycles. These are source/path checks, not deployed HTTP proof.

**Critical risk:** 33 aliases point into `app/driver/staging/*` (two app-level and 31 legacy public driver routes). Their targets exist in the repository but their deployed environment isolation, authentication and backend status are unverified. Treat as blocked for production driver workflow release until resolved. Five dynamic redirects: auth/login role=driver; SIEM admin guard; facility matrix admin guard; pickup confirmation (staging preview vs production redirect); shipment milestones (query/hash forwarding).

Gate C3.5 PARTIAL PASS / BLOCKED. Full route-family findings and runtime test matrix: `phase-00-gate-c3-5-compatibility-redirect-safety-register-2026-11-25.md`. No route, alias or environment changed.
