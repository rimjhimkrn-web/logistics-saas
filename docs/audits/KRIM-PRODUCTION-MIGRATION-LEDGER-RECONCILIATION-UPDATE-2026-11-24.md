# KRIM production migration ledger reconciliation — live update 2026-11-24

## Status
**NO-GO for production migration deployment.** This is a read-only inventory of the current repository, production ledger and staging ledger. No migration metadata or schema was changed.

## Current counts
Snapshot gathered from the repository's `main` branch and the two connected Supabase projects:

| Source | SQL files / ledger rows | Distinct versions |
|---|---:|---:|
| Repository `supabase/migrations/` | 368 files | 353 |
| Production Supabase migration ledger | 561 rows | 561 |
| Staging Supabase migration ledger | 34 rows | 34 |

## Exact version intersection
- Repository versions also present in production: **82**.
- Repository-only versions not present in production: **271** distinct versions.
- Production-only versions absent from the repository: **479**.
- Repository versions also present in staging: **0**.
- No duplicate version values were found in either Supabase ledger.

The 82 shared production/repository versions have matching version-derived migration names.

## Repository timestamp collisions
There are **13 duplicate version groups** among repository SQL files (15 excess files over the distinct-version count). The collisions are:

- `20261025150000`: `krim_ensure_initial_shipment_leg`; `seed_country_localization_and_units`
- `20261104190000`: `allow_driver_profile_transfer_on_valid_invitation`; `driver_carrier_invitation_and_membership_workflow`; `driver_verification_documents_and_review`; `partner_route_scope_and_driver_verification`
- `20261104191500`: `align_driver_review_with_invitation_gates`; `require_confirmed_email_for_driver_invitation`
- `20261104192500`: `fix_driver_invitation_profile_branch`; `scope_driver_document_upload_to_pending_profile`
- `20261104193000`: `reverify_driver_after_identity_changes`; `secure_driver_membership_invitations`
- `20261104223000`: `krim_country_pack_admin_mobile_performance`; `krim_enforce_market_activation_on_shipment_creation`
- `20261104230000`: `krim_global_corridor_compliance_engine`; `krim_unify_market_activation_booking_gate`
- `20261104234500`: `seed_india_domestic_pilot_corridor_candidate`; `seed_proposed_corridor_catalogue`
- `20261105153000`: `add_evidence_backed_partner_capability_submission`; `enforce_partner_quote_create_permission`
- `20261106160000`: `create_customs_broker_assignment_foundation`; `linked_goods_receipt_workflow`
- `20261106180000`: `driver_assignment_acceptance_gate`; `operations_dispatch_readiness_register`
- `20261106190000`: `driver_assignment_leg_integrity`; `global_vehicle_registry_foundation`
- `20261115151000`: `require_all_driver_documents_for_verification`; `schedule_private_vehicle_evidence_expiry_worker`

## Interpretation
The migration histories are not interchangeable:
- The production ledger contains 479 versions for which the current repository has no matching migration file.
- The repository contains 271 distinct versions not recorded in production.
- Staging has a separate 34-row migration ledger with no version overlap with the repository, even though the 13 critical tables used by the notification implementation matched production's 209-column catalog signature.

A matching schema slice is not proof of a matching full schema history. The recent PR #245 transaction test proves the proposed notification migrations execute against the staging catalog for the exercised workflow paths; it does not reconcile migration history.

## Required safe reconciliation
1. Preserve a read-only snapshot of the current production catalog: table/column definitions, constraints, indexes, policies, triggers, views, function definitions, ownership, ACLs, extensions, cron jobs and storage policies.
2. Map each of the 561 production ledger entries to its original SQL source where recoverable, and separately map the resulting catalog changes where source files are missing.
3. Classify each of the 271 repository-only versions as unapplied, superseded, duplicate implementation, or intentionally excluded. Do not mark them applied solely to silence migration drift.
4. Resolve all 13 repository timestamp collisions by assigning new timestamps only to files confirmed not applied anywhere. Never rewrite a version already recorded in a Supabase ledger.
5. Build a clean baseline/replay strategy and verify it on a disposable or transactional staging environment before changing either live ledger.
6. Only after the ledger is reconciled should PR #245 migrations be promoted into the canonical migration directory and production deployment considered.

## Release gate
Do not run `apply_migration`, migration repair, `db push`, or any production DDL as a shortcut. No production migration should be applied until source-to-catalog reconciliation is complete and reviewed.


## Basename/source mapping refinement
A second comparison matched Supabase ledger `name` values against repository migration basenames (the filename suffix after the timestamp), not only the timestamp version:
- 289 distinct production migration names have at least one exact repository basename match, representing 291 production ledger rows.
- Of those, 82 have exact version + name matches; 207 distinct migration names map to repository files whose timestamp differs from the production ledger version.
- 270 production ledger rows have no matching repository basename.
- Repository has 365 distinct migration basenames; 76 have no matching production ledger name.
- Repository has 3 duplicate basenames: `enforce_active_markets_for_shipment_booking`, `seed_country_localization_and_units`, and `add_missing_foreign_key_indexes`.
- Production has 2 duplicate migration-name groups: `krim_warehouse_atomic_inventory_movements` and `krim_ensure_initial_shipment_leg`, each recorded under two different versions.
- Staging has 3 basename matches but still zero exact version matches with repository files.

This refines the interpretation: 479 production versions have no exact repository timestamp file, but many are not entirely source-less—207 distinct migration names can be matched to a file by basename despite timestamp drift. Do not rename or mark these applied automatically: compare file contents and the actual production catalog before treating them as equivalent.
