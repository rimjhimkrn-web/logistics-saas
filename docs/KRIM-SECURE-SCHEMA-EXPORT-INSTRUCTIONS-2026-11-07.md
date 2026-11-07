# Secure KRIM Production Schema Export — Operator Instructions

## Purpose

The production migration history is incomplete in the repository. This workflow obtains a schema-only PostgreSQL export from production so it can be reviewed and reconstructed in isolated staging.

The repository is public. Therefore, the workflow encrypts the SQL dump before creating an Actions artifact. The artifact contains ciphertext only and is retained for one day.

## Required one-time GitHub repository secrets

Open the repository on GitHub, then Settings → Secrets and variables → Actions → New repository secret.

Create these two secrets:

1. KRIM_PRODUCTION_DB_URL
   - In Supabase Dashboard, open the production project Logistics SaaS.
   - Go to Project Settings → Database → Connection string.
   - Select the URI connection string and use the database password privately.
   - Save the complete URI as this GitHub secret.
   - Never paste the URI or database password into ChatGPT, an issue, a commit, or a workflow log.

2. KRIM_SCHEMA_EXPORT_PASSPHRASE
   - Generate a unique random passphrase of at least 24 characters using a password manager.
   - Save it in your password manager and as this GitHub secret.
   - Do not reuse your GitHub or Supabase account password. Do not send it in chat.

Do not add either value as a repository variable or commit it to a file.

## Run the export

The workflow is .github/workflows/krim-schema-export.yml.

A run is triggered when this workflow file is pushed to mobile/krim-partner-app. The first run may fail if the two secrets were not yet configured. After adding both secrets, open Actions → KRIM encrypted schema-only export, select the failed run, and choose Re-run all jobs. If the workflow is available on the default branch, it can also be started with Run workflow.

The export explicitly includes only these application schemas:

- public
- private
- krim_internal
- graphql_public

It does not request row data, auth users, storage objects, Vault contents, or custom database roles. Supabase-managed schemas such as auth, storage, realtime, vault, cron, and net are not included in this application-schema export. Extension prerequisites will be reviewed separately.

The workflow fails closed if it detects data statements or common live credential formats. This is a precaution, not a guarantee that every possible hard-coded secret will be detected. The SQL must still receive a manual security review before use.

## Download and verify

After a successful run:

1. Open the run in GitHub Actions.
2. Download artifact krim-schema-export-encrypted.
3. Keep the encrypted artifact private. It is ciphertext, but treat it as sensitive.
4. Verify its checksum before decrypting:

    sha256sum -c SHA256SUMS

## Decrypt only in a trusted private environment

With OpenSSL installed, run:

    read -s -p "Export passphrase: " KRIM_SCHEMA_EXPORT_PASSPHRASE
    echo
    export KRIM_SCHEMA_EXPORT_PASSPHRASE
    openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 \
      -in krim-schema-export.sql.enc \
      -out schema.sql \
      -pass env:KRIM_SCHEMA_EXPORT_PASSPHRASE
    unset KRIM_SCHEMA_EXPORT_PASSPHRASE

Do not upload the decrypted SQL to this public repository, paste it into chat, or place it in a public artifact. Keep it in a private working directory. The schema may contain function definitions or configuration literals that need manual secret review.

## What happens after export

The SQL will not be applied automatically. It must first be reviewed for:
- literal credentials or sensitive configuration embedded in function bodies;
- ownership, grants, default privileges, and RLS policies;
- extension dependencies and schema prerequisites;
- unsupported or Supabase-managed objects;
- references to roles or objects that do not exist in staging.

Only after review should we split it into deterministic, dependency-ordered staging migrations. Production remains read-only throughout this process.
