# KRIM Phase 00 — Environment Routing and Database Catalog Reconciliation

**Date:** 2026-11-25  
**Scope:** Read-only source/configuration and database catalog inspection. Web platform only.  
**Branch:** `qa/phase-00-baseline-2026-11-25`

## 1. Shared environment configuration reviewed

The repository's `config.js` was inspected directly.

Observed behavior:
- `krim-staging.pages.dev` and its subdomains are classified as `preview`.
- `localhost` is classified as `development`.
- GitHub Pages hostname is not specially classified and therefore falls through to `production`.
- Production classification selects the production Supabase URL and publishable key.
- Development and preview classification select the staging Supabase URL and publishable key.
- `window.KRIM_AUTH_DISABLED` is set to true whenever the environment is `preview`.
- The staging hostname therefore selects staging Supabase, but also globally disables the app's auth gate according to this shared configuration.

**Critical design concern:** The current `krim-staging.pages.dev` preview host is not suitable for authenticated acceptance testing while the shared configuration sets `KRIM_AUTH_DISABLED=true`. Before authenticated E2E testing, establish a protected staging environment with real authentication enabled, controlled test identities and no production credentials/data. Do not simply override this flag in an unreviewed deployment.

The public GitHub Pages deployment is classified as production by the current fallback. This is consistent with its production Supabase selection but should be covered by an explicit environment-routing regression test.

## 2. Database catalog reconciliation

Read-only SQL catalog queries were executed independently against production and staging.

| Catalog object | Production | Staging |
|---|---:|---:|
| Non-internal triggers attached to public-schema tables | 113 | 115 |
| Functions in public schema | 366 | 376 |
| Views/materialized views in public schema | 1 | 1 |

These counts supersede the earlier unqualified function counts in informal notes. A previous exploratory staging query had an incorrect namespace join and returned a misleading all-schema count; it is excluded from the audit baseline. The corrected query filters `pg_proc` by the function's own namespace.

**Interpretation:** Counts alone do not establish semantic equivalence. We still need normalized, row-level definitions for functions and triggers, including owner, security-definer status, execute grants, trigger event/timing, attached relation, enabled state and function body fingerprints.

The earlier reported table count was 391 in each environment. Full verbose table listings were retrieved, but a normalized complete table/column/FK/RLS fingerprint comparison has not yet been completed in this continuation. Do not treat equal table counts as proof of schema parity.

## 3. Source-level route map findings

The canonical route registry in `config.js` has 26 entries. Its ecosystem destinations include:
- Customer: `app/customer/index.html`
- Partner: `app/partner/index.html`
- Driver: `app/driver/index.html`
- Warehouse: `app/warehouse/index.html`
- Customs: `app/customs/index.html`
- Finance: `app/finance/index.html`
- Operations: `app/operations/index.html`
- Enterprise: `app/enterprise/index.html`
- Platform Admin: `app/platform-admin/index.html`

Other canonical destinations include customer booking, quote request/result, shipment list, tracking, partner onboarding/marketplace, driver assignment inbox, warehouse receiving/inventory, finance invoicing and support.

This is the canonical route map, not a full list of every legacy/secondary page. Route existence, HTTP reachability, redirect correctness, role authorization and browser behavior remain untested.

## 4. Test-harness source review

The static link audit:
- Walks repository HTML files, excluding `.git`, `node_modules` and `.github`.
- Checks literal local `href`, `src`, `action`, `formaction` and `poster` references.
- Checks canonical route registry targets.
- Emits brand and operational-risk review signals.

The complete static audit:
- Hashes HTML files for exact duplicate content.
- Scans local links, placeholder wording, redirects, noindex and staging pages.
- Looks for backend signals in HTML and linked local scripts.
- Explicitly documents that these are static indicators, not runtime proof.

The production smoke script:
- Checks a large list of required source paths.
- Executes environment-routing regression cases in a VM.
- Checks documented migration timestamp collision rules.
- Checks retired Cashfree endpoint source remains fail-closed.
- Checks a legacy payment endpoint retirement condition.

**Coverage limitation:** These checks provide useful repository regression protection, but do not substitute for browser-driven role journeys, live staging API assertions, RLS tests, payment sandbox workflows, notification delivery tests or load/recovery testing.

## 5. Current Phase 00 decisions

| Item | Status |
|---|---|
| Shared environment config source inspection | PASS (source inspected) |
| Production/staging database catalog counts | PASS (read-only counts captured) |
| Canonical ecosystem route destinations identified | PASS (source inventory) |
| Authenticated staging acceptance path | BLOCKED |
| Function/trigger body-level parity | NOT TESTED |
| Full table/column/FK/RLS parity | NOT TESTED |
| Deployed route HTTP/browser crawl | NOT TESTED |
| Page-to-script/API/table/RPC dependency graph | NOT TESTED |
| Role-based browser journeys | NOT TESTED |

## 6. Safety record

No source files were changed in this inspection step. No schema, table rows, users, secrets, RLS policies, functions, triggers or production configuration were modified. No payment, email, Telegram or customer-facing notification was triggered. No load test was run.

**Release position:** Not approved for unrestricted real-user onboarding. This document records discovery evidence only.
