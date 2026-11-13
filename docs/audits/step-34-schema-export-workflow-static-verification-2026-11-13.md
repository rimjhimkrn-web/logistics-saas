# Step 34 — Production schema-export workflow static verification (2026-11-13)

## Scope
Static source audit of `.github/workflows/krim-schema-export.yml` on `website/global-launch-readiness`, with current Supabase CLI v3 documentation checked.

## Verified
- Workflow is manual-dispatch only; repository commits do not trigger a production export.
- Required secrets are checked without printing values: `KRIM_PRODUCTION_DB_URL` and `KRIM_SCHEMA_EXPORT_PASSPHRASE` (minimum 24 characters).
- PostgreSQL URI format is validated without logging credentials.
- Supabase CLI target syntax `--remote=<postgres-url>` is valid for CLI v3; current documentation confirms the URL form and that `--remote` must be attached with `=`.
- Export is schema-only for selected application schemas: `public,private,krim_internal,graphql_public`.
- SQL scanner includes self-tests for comments, quoted function bodies, INSERT and COPY statements; detected data statements stop the workflow.
- Credential-pattern scan runs before encryption.
- Plain SQL is removed before artifact upload; only GPG-encrypted SQL and SHA-256 checksum are uploaded, with one-day retention.
- Passphrase is supplied over stdin via `--passphrase-fd 0`, not a process argument.

## Change made
Pinned Supabase CLI from floating `latest` to `3.1.0` to make export behavior reproducible against the current CLI v3 line.
- Commit: `52d76fa98fd5f1fff26cb24f07abc5ccac2381b4`
- Re-fetched source and verified the version pin and all checks above.

## Important limitations
- This is a static source audit only. No workflow was dispatched and no production database connection was attempted.
- The two GitHub Actions secret names/values have not been verified; values were not accessed.
- No encrypted artifact or checksum exists yet.
- This export is not a complete Supabase project backup: it does not by itself recreate Auth/Storage managed schemas, extensions, project settings, buckets/objects, Edge Functions/secrets, cron/queues, or all managed service configuration. These require separately reviewed staging setup.
- If Supabase CLI reports a network-ban removal requirement for a read-only remote dump, do not add `--yes` blindly; review and authorize that separate network change explicitly.
- Workflow action reference `supabase/setup-cli@v1` remains a major-tag reference; exact action-SHA pinning is a separate supply-chain hardening item.

## Safety
No workflow dispatch, database query, production/staging schema or data change, secret access, artifact creation, migration, merge, or deployment occurred.

## Result
**Workflow source is materially safer and its CLI v3 remote-target syntax is correct. Runtime export remains unverified.** Staging remains empty and cannot yet support end-to-end or tenant-isolation certification.
