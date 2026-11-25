# Phase 00 — Gate B1.4 Export workflow execution and artifact availability verification

**Date:** 2026-11-25  
**Scope:** Read-only GitHub Actions run metadata, job-step summaries, artifact inventory, and workflow-file presence on `main` and the QA baseline branch.  
**No workflow was dispatched or rerun. No GitHub secrets were read. No Production or Staging database was modified.**

## 1. Current workflow-file presence

The file `.github/workflows/krim-schema-export.yml` is present on:
- `main`
- `qa/phase-00-baseline-2026-11-25`
- `audit/migration-baseline-collision-inventory-2026-11-24`

All three refs resolve to the same file blob SHA:
`1cb04eaa45b4a2a77ef42a4885c3418ace6a5835`.

The workflow supports `workflow_dispatch` and has a push trigger scoped to changes on `mobile/krim-partner-app` for this workflow file. The current main and QA copies are present, so the manual dispatch definition is available from the default branch. This does not prove that the current repository secrets exist or are valid.

## 2. Historical run #8 verified from GitHub Actions API

Run: `43793099331`  
Workflow: `KRIM encrypted schema-only export`  
Branch: `mobile/krim-partner-app`  
Commit: `3da04091614e4825796726d3e2428e5bf0078134`  
Event: `push`  
Run attempt: `2`  
Created: `2026-11-16T02:35:30Z`  
Started: `2026-11-16T04:43:13Z`  
Completed: `2026-11-16T04:45:56Z`  
Conclusion: `success`.

The job `export-schema` (ID `133096086283`) completed successfully. All six substantive steps were successful:
1. Check required repository secrets
2. Install Supabase CLI
3. Validate database URL format without printing credentials
4. Export schema-only SQL and encrypt it
5. Upload encrypted export only

This proves the required secrets were available to that historical run at that time. It does **not** prove the secrets are currently configured, unchanged, or valid.

## 3. Current artifact availability

A fresh query of the GitHub Actions artifact inventory for run `43793099331` returned **zero artifacts**. The historical run metadata remains available, but the export ZIP is no longer available from the run's artifact inventory.

This independently confirms that the prior artifact cannot be downloaded through the current Actions artifact listing. The earlier documented artifact ID and checksum are historical evidence only, not a currently retrievable export.

## 4. Security boundary and next operator action

The GitHub connector does not expose the repository Secrets API, and this audit must not request, reveal, or copy secret values. Current secret presence therefore remains **NOT TESTED**.

An authorized repository owner must privately verify that both secret names exist:
- `KRIM_PRODUCTION_DB_URL`
- `KRIM_SCHEMA_EXPORT_PASSPHRASE`

Do not share either value in chat, issue comments, repository files, or logs. After private verification, the owner may manually dispatch the workflow from the default branch. Dispatch is intentionally not performed by this audit because it creates a new sensitive export artifact and reads the Production schema, even though the database operation itself is read-only.

## 5. Gate result

| Check | Result |
|---|---|
| Workflow file present on main | PASS |
| Workflow file present on QA baseline | PASS |
| Workflow file blob identical across main and QA | PASS |
| Historical run #8 completed successfully | PASS |
| Historical secret-check step succeeded at that time | PASS |
| Historical export/encryption/upload steps succeeded | PASS |
| Historical artifact currently downloadable | FAIL — zero artifacts returned |
| Current required secret presence | NOT TESTED — secrets API unavailable |
| New workflow dispatch | NOT TESTED — owner action required |
| New export decrypted and manually reviewed | BLOCKED |

## Disposition

**B1 remains BLOCKED.** The export automation itself has a verified historical successful run and is present on both main and QA. The remaining operator-controlled gate is current private secret verification followed by an explicitly initiated fresh export. No secrets were read, no workflow was run, and no database or deployment state was changed.
