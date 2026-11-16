# KRIM Sanitized Schema Manifest Workflow — Operator Guide
**Date:** 16 November 2026  
**Workflow:** `.github/workflows/krim-schema-manifest.yml`  
**Purpose:** Decrypt the existing protected schema-only export inside GitHub Actions and publish only a sanitized object inventory. The raw SQL is never uploaded as an artifact.

## Why a manual run is required
The connected GitHub actions interface available to this session can read runs and artifacts and edit repository files, but it does not expose a workflow-dispatch action. The workflow is therefore committed and ready for an authorized repository operator to launch through GitHub Actions.

## Run inputs
Select **KRIM sanitized production schema manifest** in the repository Actions tab and choose **Run workflow** on the default branch. Enter:
- `source_run_id`: `43793099331`
- `artifact_id`: `14193475858`

These IDs refer to the existing `krim-schema-export-encrypted` artifact, which was last checked as unexpired and expires at `2026-11-17T02:37:47Z`.

## Secret requirement
The workflow reads the existing repository secret `KRIM_SCHEMA_EXPORT_PASSPHRASE`. Do not paste the passphrase into a workflow input, commit, issue, log or chat. Do not expose the raw SQL artifact.

## Expected output
A one-day artifact named `krim-production-schema-manifest` containing:
- `krim-production-schema-manifest.json`: statement categories, object identifiers and SHA-256 hashes; no SQL bodies or values.
- `summary.txt`: statement counts by category.

The workflow checks artifact identity and expiry, verifies the encrypted-file checksum, decrypts only in the runner, rejects common credential patterns, and removes the private working directory. It uploads only the sanitized manifest.

## Important limitations
This first pass is a metadata inventory and statement fingerprint list, not a full semantic equivalence proof. It does not connect to or modify the production database, execute SQL, or repair migration history. After the artifact is produced, compare its object inventory and hashes with the checked-in migration source and separately query live catalog definitions. Do not treat matching object names or hashes of dump statements as proof of migration equivalence.

## Current status
The encrypted source artifact remains unexpired at the last check. The manifest workflow is committed but has not been dispatched from this session. No production database change was made.
