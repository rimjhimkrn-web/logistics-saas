# KRIM Backup, Disaster Recovery and Business Continuity Audit
**Date:** 16 November 2026  
**Project:** `logistics-saas` / Supabase project `ebltviniygljwwseplph`  
**Method:** Read-only Supabase project/organization metadata, PostgreSQL catalog/data-size checks, Storage metadata counts, repository workflow and recovery-document review. No backup, restore, pause, branch mutation, database mutation or user-data export was initiated.

## Executive decision
**P0 — KRIM does not currently have verified production backup and restore protection.** The Supabase organization is on the **Free** plan. Supabase's current documentation states that Free projects do not include automatic database backups or Point-in-Time Recovery (PITR). The repository contains a protected encrypted **schema-only** export process, but that artifact is not a data backup and cannot restore customer records, auth users, Storage files or operational history. No completed restore drill or independently stored full data backup was evidenced.

Do not launch live logistics operations or collect commercial fees until a recoverable backup process and a successful isolated restore test exist.

## 1. Verified platform and backup plan
- Supabase organization plan: `free`.
- Project state: `ACTIVE_HEALTHY`.
- PostgreSQL: 17.6.1.165.
- Project region: `ap-northeast-1` (Tokyo).
- Current database size: approximately 75 MB.
- Supabase official documentation states that automatic daily database backups are included on Pro, Team and Enterprise plans; Free projects do not include automatic backups or PITR. Free projects should regularly export their data using Supabase CLI `db dump`.
- No backup-list or restore-history API is exposed by the connected Supabase tools in this session. Therefore, no platform snapshot availability or restoration completion is claimed.
- A single read-only project health-advisor check returned no health lints. This is not backup or recovery certification.

## 2. Existing export workflow is schema-only
The repository workflow `.github/workflows/krim-schema-export.yml`:
- runs `supabase db dump` for schemas `public,private,krim_internal,graphql_public`;
- rejects executable top-level data statements and scans for selected credential patterns;
- encrypts the schema SQL with OpenSSL AES-256-CBC/PBKDF2 (600,000 iterations);
- uploads only encrypted SQL and checksum, with one-day artifact retention.

The protected manifest workflow decrypts inside an ephemeral GitHub runner and publishes only a metadata inventory. It does not publish SQL bodies or restore a database.

**Coverage limitations:** the application schema export explicitly excludes row data, Auth users, Storage objects, Vault contents, custom database roles and Supabase-managed schemas such as `auth`, `storage`, `realtime`, `vault`, `cron` and `net`. This is an architecture-review artifact only—not a recoverable backup.

The latest operator guide identifies encrypted export run `43793099331`, artifact `14198261776`, and asks an authorized operator to manually dispatch the sanitized manifest workflow. That workflow dispatch was not verified as completed in this audit. Even if completed, the manifest would not create a data backup.

## 3. Branch and restore evidence
- Supabase branch inventory returned only the default `main` branch, `with_data=false`, `persistent=false`.
- A schema-only or empty preview branch is not a production backup.
- No isolated recovery project with restored production data was identified.
- No documented restore exercise, restore duration, post-restore validation report, rollback plan or tested cutover procedure was found in the reviewed repository material.
- The connected tools do not expose a safe backup-list or restore-history query. We did not attempt a production restore.

## 4. Storage and identity recovery coverage
- Five private Storage buckets exist: driver evidence, driver verification, partner verification, warehouse evidence and POD documents.
- The read-only Storage object query returned zero rows across buckets at inspection time. This means no stored objects were found in that query snapshot; it does not remove the need for future object backup.
- Supabase database backups do not include Storage object bytes; they preserve only database metadata. A recovery plan must separately preserve Storage objects and their metadata/path/ownership relationships.
- Auth users: 9. Auth identity recovery, MFA/recovery factors, email provider configuration and custom role/password reset steps need a separate tested procedure. The schema export does not include Auth user data.
- Secrets and provider credentials are not included in the schema export. Maintain a secure inventory of required secret names, owners, rotation steps and provider reauthorization procedures without copying secret values into GitHub artifacts or reports.

## 5. Audit history and operational recovery
- `krim_audit_events`: 203 rows, oldest observed 19 September 2026, newest observed 15 November 2026.
- Other critical history includes shipment status history, tracking events, workflow execution logs, notification outbox/delivery/retry state, claims, customs reviews and warehouse custody events.
- These records need an explicit retention, backup and restore consistency policy. Do not treat short-lived platform logs or GitHub Actions logs as a substitute for durable business audit history.
- Nine active `pg_cron` jobs were observed in the database. Their successful execution does not provide backup coverage or prove a recoverable queue state after data loss.
- No defined KRIM Recovery Point Objective (RPO) or Recovery Time Objective (RTO) was evidenced. Current RPO/RTO must be recorded as **undefined / untested**, not zero.

## 6. P0/P1 recovery gaps
1. **P0 — No verified full production data backup.** Free plan does not include automatic daily backups or PITR; no independent full backup artifact or backup schedule was evidenced.
2. **P0 — No restore drill.** No isolated full restore and validation proof exists.
3. **P1 — Storage object recovery absent.** Object bytes require a separate backup path and integrity/ownership reconciliation.
4. **P1 — Auth and access recovery absent.** Auth user data, MFA recovery, custom roles and secret reauthorization need explicit recovery steps.
5. **P1 — Schema/data version consistency.** Production migration history remains materially mismatched with repository migration files; the schema-only manifest is still a prerequisite for safe reconstruction, not a substitute for backup.
6. **P1 — No RPO/RTO commitments.** Set business-appropriate targets before accepting real customer shipments.
7. **P1 — No tested failover/cutover procedure.** Define how to validate restored data, stop writes, preserve evidence, communicate outage and safely resume.
8. **P2 — Audit and log retention.** Verify platform log retention separately from application audit-event retention and ensure required records can be exported off-site.

## 7. Recommended recovery design (low-cost first)
### Before any live operations
- Create a documented, repeatable **data-bearing logical backup** using the supported Supabase CLI/backup guidance, stored encrypted in a private off-site location independent of the production project and GitHub repository.
- Define backup scope for application data, Auth identity data, schema/roles/grants and configuration. Use Supabase-supported export procedures for managed schemas; do not assume the schema-only workflow covers them.
- Back up Storage object bytes separately, with a manifest of bucket, object path, size, checksum, content type and ownership metadata. Encrypt and restrict access.
- Keep encryption keys/passphrases in a password manager or managed secret store, separate from the backup artifacts. Test key recovery without exposing secrets.
- Establish at least daily full logical backup and a documented incremental/WAL strategy only if the platform and budget support it. Until then, explicitly document the larger data-loss window and keep live transactions disabled.
- Keep multiple generations (for example, 7 daily and 4 weekly copies) in a private off-site location; apply retention and deletion controls.

### Restore drill
- Restore into a new isolated project, never over production for the first test.
- Restore database/schema/data and Auth identity records using supported procedures; restore Storage objects separately.
- Verify schema object counts, row counts for critical tables, FK validity, RLS/policies/grants, function definitions, auth identity linkage, Storage object checksums/paths, scheduled jobs and Edge Function configuration.
- Run read-only smoke checks and isolated synthetic staging workflows.
- Record actual restore duration, data-loss boundary, missing dependencies and operator steps. Only then set measured RPO/RTO.
- Rehearse a production cutover/rollback plan before any real operational workload.

### Paid backup option
Supabase Pro currently includes daily database backups with seven-day retention; PITR is a separately priced add-on. Upgrade only after reviewing actual billing and business need. PITR does not remove the need for separate Storage object backups or restore testing.

## Release decision
**NO-GO for real shipment execution and financial collection until P0 backup/restore gates are closed.** KRIM currently has an active, small production database but no verified full data backup/restore chain. The encrypted schema-only artifact is valuable for schema reconciliation and must not be described as a production backup.

## Change boundary
Only read-only metadata, catalog, statistics, Storage metadata counts, GitHub repository and public Supabase documentation were reviewed. No production records were changed, no backup artifact was generated, no provider was contacted, no project was paused/restored, and no user data or secret values were exported.
