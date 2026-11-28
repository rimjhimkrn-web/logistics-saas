# KRIM Day 1 — CI Schema Export History Recovery Finding
Date: 2026-11-28
Repository: rimjhimkrn-web/logistics-saas
Branch examined: mobile/krim-partner-app

## Confirmed historical workflow
Inspected the repository's .github/workflows/krim-schema-export.yml and its GitHub Actions history.

The workflow:
- Exports schema-only SQL from the database URL held in repository secret KRIM_PRODUCTION_DB_URL.
- Runs Supabase CLI db dump for public, private, krim_internal and graphql_public schemas.
- Checks for executable data statements and credential-like material.
- Encrypts the schema dump with AES-256-CBC/PBKDF2 before upload.
- Uploads only the encrypted SQL file and checksum as a GitHub Actions artifact with one-day retention.

## Successful historical run
Run ID: 44072524850
Branch: mobile/krim-partner-app
Commit: 817ca6c65a0526bf03db71d29906a97acc982dd4
Created: 2026-11-17 11:16:29 UTC
Conclusion: success
Job: export-schema
Job ID: 134002053103

The successful job log explicitly records:
- Supabase CLI dumped schema to private-export/schema.sql.
- SQL data-statement safety check passed.
- Encrypted artifact uploaded successfully.
- Artifact ID: 14323377203
- Artifact size: 3,372,129 bytes
- Retention configured as one day.

## Current artifact availability
A current artifact-list request for run 44072524850 returned an empty artifact list. The artifact is no longer available through the GitHub Actions artifact endpoint. The run log remains available, but it does not contain the encrypted archive bytes or SQL definition.

## Important provenance boundary
The workflow source explicitly identifies KRIM_PRODUCTION_DB_URL as its source. This historical artifact is therefore a production schema export, not a Staging backup. It was not downloaded, decrypted, restored, or used to alter any project. No Production database was queried in this investigation.

## Next safe recovery path
- Search any owner-retained download of artifact 14323377203 and its matching passphrase/checksum.
- Search authorised CI retention/archive storage or organisation backup for the encrypted artifact.
- If recovered, obtain explicit owner authorisation before inspecting the production-derived schema artifact; inspect offline/read-only and extract only the exact RPC definition.
- If unavailable, use the current Staging function definition plus independently reviewed source to design a versioned replacement, but do not claim original migration provenance recovered.

## Safety
No database queries or writes, no RPC invocation, no artifact download, no decryption, no restore, no deployment. Phase 00 remains OPEN. Phase 01 is not authorised.
