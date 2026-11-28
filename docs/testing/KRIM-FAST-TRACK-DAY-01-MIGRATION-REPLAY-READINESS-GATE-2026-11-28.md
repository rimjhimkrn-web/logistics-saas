# KRIM Fast-Track Day 01 — Migration Replay Readiness Addendum
Date: 2026-11-28
Branch: `staging/phase00-env-isolation`
Target: KRIM Logistics Staging (`qrpcivhdxobiaofppbkl`)
Production: not accessed or changed

## Result
**LOCAL RESET / REPLAY IS NOT YET SAFE TO ATTEMPT.** Repository inspection shows a large migration history, but not a self-contained baseline that can currently be proven to recreate the Staging schema from an empty local Supabase stack.

## Evidence
- Current branch head at inspection: `7b5c799fa5e78df1550dc8b537b577062dcde15f`.
- Complete Git tree response: 2,607 entries; not truncated.
- `supabase/migrations/` contains 499 SQL files.
- Earliest tracked migration: `20261016120808_krim_user_app_backend_modules.sql`.
- That first file's own header says it was applied to project `ebltviniygljwwseplph` (Production) and creates user-app tables; it does not establish the KRIM core application schema.
- The next early migration, `20261017093454_fix_revenue_allocation_idempotency_and_recognition.sql`, alters existing finance functions and references existing revenue rules, allocations, shipments and invoices. It is a delta, not a clean bootstrap.
- Later migrations likewise assume pre-existing KRIM tables and functions.
- The prior Staging migration-ledger inspection reported 163 entries, with earliest recorded Staging migration `20261117135137`. This does not match the repository's October-start migration file history and does not prove a clean replay path.
- No `supabase/config.toml`, seed file or local test harness was found in the inspected repository paths.

## Safety decision
Do **not** run `supabase db reset`, `supabase db pull`, `supabase db push`, or a remote schema bootstrap as a shortcut:
- A local reset would apply the 499 tracked migration files in order, but the chain appears to depend on a pre-existing baseline that is not represented by the first migration.
- A remote pull/dump requires explicit target selection and can accidentally link to or read Production if the project is misconfigured.
- The existing schema-bootstrap workflow consumes an encrypted schema export from a separate workflow and applies it to an empty Staging database; it is not a local test harness and was not invoked.
- No Production credentials, database or export artifact were accessed in this review.

## Correct next implementation path
1. Obtain an owner-approved, retained **schema-only Staging baseline** (no user rows, auth users, secrets, storage objects, or provider credentials), or create a clean, explicitly versioned baseline from Staging using a separately reviewed process.
2. Confirm that baseline is safe to use locally and does not contain sensitive literals or environment-specific production configuration.
3. Build an isolated local database from that baseline, then apply only the migrations that are demonstrably subsequent to that baseline. Do not guess the cutoff from filenames; reconcile migration ledger and schema state first.
4. Add local pgTAP tests for the proposed partner capability read RPC and authorization boundaries.
5. Only after repeatable local tests pass, review a Staging-only migration and request explicit approval before applying it.

## Status
- Migration count: 499 tracked SQL files.
- Self-contained clean baseline: **NOT ESTABLISHED**.
- Safe local reset/replay: **BLOCKED**.
- Disposable local Postgres stack: **NOT AVAILABLE in current connected execution environment**.
- Partner A/B authenticated tests: **NOT RUN**.
- Proposed capability list RPC: **DESIGN ONLY**.
- Phase 00: **OPEN — NOT APPROVED**.
- Production: **NOT ACCESSED OR CHANGED**.
