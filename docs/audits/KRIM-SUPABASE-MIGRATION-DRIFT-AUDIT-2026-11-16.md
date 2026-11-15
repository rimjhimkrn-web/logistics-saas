# KRIM Supabase Migration Drift Audit — 16 November 2026

**Repository:** `rimjhimkrn-web/logistics-saas`  
**Production project:** `ebltviniygljwwseplph`  
**Method:** read-only comparison of `supabase_migrations.schema_migrations` version/name records with repository migration filenames. No migration, schema or production data was changed.

## 1. Executive result

**Production migration history and repository migration inventory are materially divergent. Do not apply, replay, baseline, squash or generate corrective DDL until the migration history is reconciled.**

| Metric | Result |
|---|---:|
| Production migration-history rows | 558 |
| Unique production migration versions | 558 |
| Latest production version | `20261115231834` — `require_warehouse_handover_before_leg_dispatch` |
| Repository SQL migration files | 363 |
| Unique repository migration timestamps | 348 |
| Latest repository migration filename version | `20261116028000` |
| Shared version timestamps | 82 |
| Production versions with no matching repository file | 476 |
| Repository timestamps not present in production history | 266 |
| Duplicate timestamp groups in repository | 13 |

These are timestamp/version comparisons only. They do not prove that two migration bodies are identical, that a migration ran successfully, or that the current schema matches either side.

## 2. Duplicate repository timestamps

Thirteen timestamp groups contain multiple migration files. Examples include:

| Timestamp | Files sharing the timestamp |
|---|---|
| `20261025150000` | `krim_ensure_initial_shipment_leg`; `seed_country_localization_and_units` |
| `20261104190000` | `allow_driver_profile_transfer_on_valid_invitation`; `driver_carrier_invitation_and_membership_workflow`; `driver_verification_documents_and_review`; `partner_route_scope_and_driver_verification` |
| `20261104191500` | `align_driver_review_with_invitation_gates`; `require_confirmed_email_for_driver_invitation` |
| `20261104192500` | `fix_driver_invitation_profile_branch`; `scope_driver_document_upload_to_pending_profile` |
| `20261104193000` | `reverify_driver_after_identity_changes`; `secure_driver_membership_invitations` |
| `20261104223000` | `krim_country_pack_admin_mobile_performance`; `krim_enforce_market_activation_on_shipment_creation` |
| `20261104230000` | `krim_global_corridor_compliance_engine`; `krim_unify_market_activation_booking_gate` |
| `20261104234500` | `seed_india_domestic_pilot_corridor_candidate`; `seed_proposed_corridor_catalogue` |
| `20261105153000` | `add_evidence_backed_partner_capability_submission`; `enforce_partner_quote_create_permission` |
| `20261106160000` | `create_customs_broker_assignment_foundation`; `linked_goods_receipt_workflow` |
| `20261106180000` | `driver_assignment_acceptance_gate`; `operations_dispatch_readiness_register` |
| `20261106190000` | `driver_assignment_leg_integrity`; `global_vehicle_registry_foundation` |
| `20261115151000` | `require_all_driver_documents_for_verification`; `schedule_private_vehicle_evidence_expiry_worker` |

The timestamp collisions make ordering ambiguous and must be resolved before any future migration chain is considered authoritative. Do not arbitrarily rename existing migration files or mark them applied; first determine whether their SQL has already been applied, in what order, and whether any later migration depends on each body.

## 3. Why this blocks the P0 corrections

The customer-to-partner audit identified two P0 server-side corrections:

1. `krim_internal_evaluate_shipment_readiness` incorrectly marks partner readiness as `not_required` for `confirmed` shipments, allowing six legacy confirmed shipments with no accepted partner assignment to have readiness rows marked `ready`.
2. `krim_create_partner_opportunity` checks active catalogue flags but does not enforce the same market operational gate and approved corridor dossier required by shipment creation and tariff quote creation. A legacy shipment may be passed to this weaker RPC.

Both corrections affect production `SECURITY DEFINER` functions, lifecycle gates and potentially existing records. Applying either through an improvised SQL patch or an unreviewed migration could overwrite later production logic or create duplicate/inconsistent history.

## 4. Required reconciliation procedure

1. Freeze production DDL changes other than approved emergency security fixes; do not use `apply_migration` or direct `CREATE OR REPLACE FUNCTION` as a shortcut.
2. Export the full production migration version/name list and obtain the original SQL bodies for all 558 production versions from the trusted migration source/backup/CI artifacts. The database history table stores version/name metadata, not the original SQL text.
3. Inventory every repository migration file, duplicate timestamp, duplicate body, rename, deleted file and local-only migration.
4. Compare production schema objects and function definitions against the intended final result of the migration sequence; do not assume matching timestamps mean matching bodies.
5. Identify which 476 production versions are absent from the repository and recover their original migration bodies into a controlled archive/reconciliation branch. Do not reconstruct them from memory or current schema alone.
6. Resolve the 13 repository timestamp collision groups using authoritative execution order and dependency evidence. Preserve original SQL and record the chosen canonical ordering; do not silently drop either file.
7. Identify the 266 repository timestamps absent from production. Determine which are pending, superseded, duplicated, intentionally local, or unsafe to apply. Do not bulk-apply them.
8. Produce a baseline/schema-diff report, validate constraints, policies, triggers, functions, grants, extensions, storage policies, cron jobs and Edge Function dependencies.
9. Only after reconciliation, prepare a single reviewed corrective migration for the P0 readiness and market/corridor gates, with a matching repository SQL file, preflight, rollback/forward-recovery plan and regression tests.
10. Apply the approved migration in a controlled window, then verify function definitions, grants, RLS, negative tests and readiness re-evaluation.

## 5. Evidence and limits

- Production history count and version/name list were read from `supabase_migrations.schema_migrations`.
- Repository migration files and filenames were read from the GitHub default branch.
- No production migration history row was inserted, updated or deleted.
- No migration SQL was executed.
- The 558 production migration bodies were not available from the migration-history table itself; obtaining the trusted source artifacts remains required.
- This audit is a blocker report, not a schema-equivalence certification.

## 6. Decision

**Migration execution remains on hold.** Continue read-only schema and function inspection, source corrections and documentation. Do not deploy the P0 database fixes until migration history is reconciled from authoritative source artifacts.
