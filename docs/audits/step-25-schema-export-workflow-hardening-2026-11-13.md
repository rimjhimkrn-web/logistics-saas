# Step 25 — Schema export workflow hardening

Date: 2026-11-13
Branch: `website/global-launch-readiness`
PR: #65 (draft, unmerged, undeployed)

## Changes made

Hardened `.github/workflows/krim-schema-export.yml`:

1. Removed the unrelated `mobile/krim-partner-app` push trigger. The workflow is now manual-dispatch only, so committing this workflow or an audit report cannot automatically initiate a production database export.
2. Replaced OpenSSL AES-CBC encryption with GnuPG AES-256 symmetric encryption, which uses integrity-protected encrypted packets (MDC) by default.
3. Passphrase is supplied to GnuPG through standard input (`--passphrase-fd 0`) rather than a process argument.
4. Updated artifact filename to `krim-schema-export.sql.gpg`; checksum and one-day artifact retention remain.
5. Existing schema-only export, SQL data-statement scanner, credential-pattern scan, and fail-closed required-secret checks remain in place.

Commits:
- `e6d1f652d105cf3f640e0e40fc51de3b87382eb7` — manual-only trigger and authenticated encryption.
- `cb9b59445299ede023f6f3fded1d5706afd7e44f` — passphrase via stdin, not process arguments.

## Validation and limitations

The workflow source was re-read after edits to confirm the manual-only trigger, GPG output filename, and passphrase-fd invocation. This was a source inspection, not a runtime workflow execution. No export has been produced; GPG compatibility, Supabase CLI remote dump, and scanner behavior on the actual production schema remain untested until a manual run.

Required GitHub secrets remain `KRIM_PRODUCTION_DB_URL` and `KRIM_SCHEMA_EXPORT_PASSPHRASE`. Their presence has not been verified, and no secret values were accessed, printed, or changed.

## Safety status

- No workflow dispatch.
- No production or staging database changes.
- No migration applied.
- No business data copied.
- No production credentials or provider secrets accessed.
- No deployment or merge.

## Next action

Repository administrator: verify both required secrets exist in GitHub Actions, then manually dispatch `KRIM encrypted schema-only export` on `website/global-launch-readiness`. Do not paste credentials into chat. Confirm the run succeeds and the encrypted artifact plus checksum are present before any decryption or staging bootstrap. Decrypt only in a secured local environment and review the schema before use.

## Result

Step 25 completed as a workflow safety-hardening task. The production schema export is still pending; staging remains empty and is not yet ready for lifecycle testing.
