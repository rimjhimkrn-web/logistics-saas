# KRIM Secure Schema Export Result — 2026-11-09

## Result

The encrypted schema-only export completed successfully on the feature branch.

- Repository: `rimjhimkrn-web/logistics-saas`
- Branch: `mobile/krim-partner-app`
- Workflow run: [42619599274](https://github.com/rimjhimkrn-web/logistics-saas/actions/runs/42619599274)
- Source commit: `befe199024d1ecc208e58dd560717b13502d9776`
- Workflow result: **success**
- Artifact: `krim-schema-export-encrypted`
- Artifact ID: `13676480195`
- Artifact size: 3,242,114 bytes
- Expiry shown by GitHub: 2026-11-10 12:47:56 UTC
- Artifact contents: encrypted schema export and SHA-256 checksum manifest only.

## Verified workflow gates

- Required repository secrets present: passed.
- Supabase CLI installation: passed.
- PostgreSQL URI format validation: passed.
- Schema-only export: passed.
- SQL data-statement scanner self-tests: passed.
- SQL data-statement scan: passed.
- Encryption: passed.
- Encrypted artifact upload: passed.

The SQL scanner ignores SQL comments and quoted literals/function bodies while still detecting executable top-level `INSERT INTO` and `COPY ... FROM stdin;` statements. It is a precaution, not a complete proof that a schema contains no sensitive literals.

## Changes made to the workflow

The scanner initially failed its own self-test because of escaped newline and regex patterns. Those were corrected in commit `befe199024d1ecc208e58dd560717b13502d9776`. The corrected workflow completed successfully.

## Security and staging status

- No database password, export passphrase, connection URI, decrypted SQL, production row data, or provider credential was added to this document or repository.
- The encrypted artifact remains sensitive and should be downloaded only by an authorized operator.
- Do not publish or commit the decrypted SQL.
- No schema was applied to production or staging.
- Staging project `qrpcivhdxobiaofppbkl` remains active but has zero application tables and zero recorded migrations.
- The export still requires manual security review before any staging import. In particular, inspect function definitions, ownership, grants, RLS policies, extension dependencies, and any hard-coded configuration literals.
- Do not replay the incomplete repository migration history as a substitute for the reviewed baseline.

## Next gate

1. Download the encrypted artifact from the workflow run before it expires.
2. Verify `SHA256SUMS`.
3. Decrypt only in a trusted private environment using the separately stored export passphrase.
4. Review and sanitize the schema offline.
5. Reconstruct the baseline in isolated staging only.
6. Compare staging catalog metadata and privileges against production before running synthetic end-to-end tests.

Production remains unchanged. The three mobile apps remain read-only for operational writes until staging authorization and lifecycle tests pass.
