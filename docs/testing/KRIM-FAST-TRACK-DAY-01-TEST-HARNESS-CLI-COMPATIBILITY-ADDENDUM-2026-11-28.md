# KRIM Fast-Track Day 01 — Test Harness Follow-up and CLI Compatibility Addendum
Date: 2026-11-28
Branch: `staging/phase00-env-isolation`
Reviewed branch HEAD: `1835b61f06e812ea5d0f41ba620fa8242493d5ba`
Target database: KRIM Logistics Staging (`qrpcivhdxobiaofppbkl`)
Production project: not accessed or changed

## New repository evidence
Rechecked the current branch HEAD after the earlier harness gate report.

- Branch HEAD is `1835b61f06e812ea5d0f41ba620fa8242493d5ba`.
- Recursive tree response was complete (`truncated=false`), with 2,611 entries.
- `supabase/` contains `functions/` and `migrations/`; no `config.toml` or `config.jsonc` was present.
- The repository root still has no project `package.json`.
- The Deno policy-test workflow remains narrowly scoped to `policy_test.ts`; it does not start PostgreSQL or Supabase.
- The Node 22 environment-isolation workflow remains a static environment mapping/consumer check, not a database integration test.
- A Playwright package subtree is present under tracked `node_modules/`, but it does not provide a Supabase CLI, PostgreSQL server, database migrations harness, or JWT-backed database test environment.
- No safe, already-existing CI job was identified that can be reused for Partner A/B database authorization tests without introducing an unreviewed database target or secrets.

## Current Supabase CLI compatibility
The official Supabase changelog records CLI v3 as a breaking change: database commands target the local stack by default; hosted changes require explicit confirmation; unattended hosted changes require `--yes`; `--remote` is the current explicit hosted-target flag. The migration guide was updated 2026-11-20. The changelog also records that CLI v3.4.0 (2026-11-24) makes `supabase init` create `supabase/config.jsonc` by default; existing TOML projects remain supported.

References:
- https://supabase.com/changelog/supabase-cli-v3
- https://supabase.com/docs/guides/local-development/cli/migrating-to-v3
- https://supabase.com/changelog

Implications for KRIM:
- Do not assume `config.toml` is the only valid config format.
- When a local CLI environment becomes available, first record the exact CLI version and inspect `supabase --help` and `supabase init --help`.
- Initialize only after confirming the working tree and intended staging branch; do not overwrite existing configuration.
- Any future hosted migration operation must explicitly name the Staging target and receive separate explicit approval. No command should rely on CLI defaults.
- Do not add `--remote` or `--yes` to any workflow that could point at Production.

## Owner-only dashboard verification remains outstanding
The connected project metadata and SQL inspection do not reveal the effective Data API exposed-schema settings. The owner must inspect the Staging project dashboard and provide:
1. Project ref visible in the dashboard: `qrpcivhdxobiaofppbkl`.
2. Exact Exposed schemas value.
3. Exact Extra search path value.
4. Confirmation that the dashboard page is for Staging, not Production.

Do not expand the exposed schemas as part of this verification. Redact API keys and secrets from any screenshot.

## Updated gate decision
- Reproducible local Supabase/Postgres test harness: **NOT ESTABLISHED**.
- CLI version/config format in repository: **NOT PINNED / NOT CONFIGURED**.
- Partner A/B JWT authorization tests: **NOT RUN**.
- Staging Data API exposed-schema settings: **OWNER VERIFICATION REQUIRED**.
- Proposed `krim_partner_list_capabilities(bigint)`: **DESIGN ONLY; NOT CREATED**.
- No migration, grant, fixture, invitation, RPC invocation, notification, deployment, or database mutation performed in this follow-up.
- Phase 00: **OPEN — NOT APPROVED**.
- Production: **NOT ACCESSED OR CHANGED**.

## Next execution step
Once the owner supplies the Staging-only Data API settings and a supported local CLI/runtime is available, initialize a disposable local test harness using the installed CLI's documented syntax, pin the selected version, then add deterministic authorization tests. Keep all test data local until the suite passes. Only then prepare a reviewed Staging migration for explicit approval.
