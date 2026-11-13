# Step 47 — Schema-export workflow prerequisite and execution check

Date: 2026-11-13
Branch: website/global-launch-readiness
Scope: inspect the encrypted schema-only export workflow and available GitHub Actions run history. No workflow dispatch performed.

## Workflow source inspection

File: `.github/workflows/krim-schema-export.yml`
Blob SHA at inspected branch: `e45478680d334fc69ced5aa38d32fc808fb72739`

The workflow is manual-only (`workflow_dispatch`) and requires two repository Actions secrets:

- `KRIM_PRODUCTION_DB_URL` — PostgreSQL connection URI for the production database.
- `KRIM_SCHEMA_EXPORT_PASSPHRASE` — at least 24 characters.

It validates URI structure without printing credentials, pins Supabase CLI to 3.1.0, runs a schema-only dump for `public,private,krim_internal,graphql_public`, scans for executable INSERT/COPY data statements and likely credential patterns, encrypts with GPG AES-256, creates a SHA-256 checksum, removes plaintext SQL, and uploads only encrypted SQL plus checksum for one day.

## Runtime / secret verification

- The GitHub integration cannot read repository Actions secret values or confirm whether a named secret is configured. Secret values must never be pasted into chat or logs.
- The inspected Actions run history contains no run for `krim-schema-export.yml`.
- Therefore no encrypted export artifact or checksum has been produced/verified.
- The workflow file is on the PR branch; the PR is still draft/unmerged. The manual dispatch target must be the intended branch and exact production source, not a guessed/default branch.
- A successful schema-only dump is not a complete Supabase project backup and does not capture Auth/Storage managed state, buckets/objects, Edge Functions/secrets, project settings or all platform configuration.

## Workflow safety review

The source has sensible protections: manual-only trigger, required secret checks, no credential echo, schema-only scope, data-statement scanner self-tests, credential-pattern scan, encrypted-only artifact upload, short retention and plaintext cleanup.

Before dispatch, verify that the database URI belongs to production project `ebltviniygljwwseplph` and that its password is current. Verify the passphrase is strong and stored safely outside the repository. Do not share either value with ChatGPT. Verify the GitHub workflow file is the reviewed version on the branch being dispatched.

## Required owner action

In GitHub repository Settings → Secrets and variables → Actions, check only that both exact secret names exist and are current. Do not reveal their values. Then, if the owner is comfortable with a one-day encrypted schema-only artifact, manually run the workflow from the reviewed `website/global-launch-readiness` branch. After it finishes, verify the run succeeded and that the artifact contains exactly the encrypted SQL and checksum. Preserve the passphrase separately; the one-day artifact retention is intentionally short.

If the owner does not want to perform that action now, do not substitute an unencrypted export or copy credentials into chat.

## Step 47 verdict

**NOT EXECUTED — prerequisites cannot be verified through the connected GitHub read interface.** Workflow source review passed at a static level, but secrets, runtime export, checksum and artifact remain unverified. No workflow dispatch, secret access, DB connection, schema/data change, project change, merge or deployment occurred.
