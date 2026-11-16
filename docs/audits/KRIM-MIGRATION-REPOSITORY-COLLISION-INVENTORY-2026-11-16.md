# KRIM Migration Repository Collision Inventory
**Date:** 16 November 2026  
**Scope:** Read-only inventory of the checked-in `supabase/migrations` directory. This is a supporting artifact for production migration-history reconciliation, not authorization to change migration files or database history.

## Inventory result
- SQL migration files: **363**
- Unique version timestamps: **348**
- Duplicate timestamp groups: **13**
- Duplicate logical migration-name groups: **3**
- Git tree response was complete (`truncated=false`).

## 1. Duplicate version timestamps
Supabase migration history identifies migrations by version timestamp. Multiple different SQL files sharing one timestamp cannot be represented as separate unique migration versions in the normal version/name crosswalk. These must be resolved against the actual production schema, migration history and historical deployment records; do not arbitrarily rename, merge, delete, replay or baseline them.

| Timestamp | Files sharing the timestamp |
|---|---|
| 20261025150000 | `20261025150000_krim_ensure_initial_shipment_leg.sql`; `20261025150000_seed_country_localization_and_units.sql` |
| 20261104190000 | `20261104190000_allow_driver_profile_transfer_on_valid_invitation.sql`; `20261104190000_driver_carrier_invitation_and_membership_workflow.sql`; `20261104190000_driver_verification_documents_and_review.sql`; `20261104190000_partner_route_scope_and_driver_verification.sql` |
| 20261104191500 | `20261104191500_align_driver_review_with_invitation_gates.sql`; `20261104191500_require_confirmed_email_for_driver_invitation.sql` |
| 20261104192500 | `20261104192500_fix_driver_invitation_profile_branch.sql`; `20261104192500_scope_driver_document_upload_to_pending_profile.sql` |
| 20261104193000 | `20261104193000_reverify_driver_after_identity_changes.sql`; `20261104193000_secure_driver_membership_invitations.sql` |
| 20261104223000 | `20261104223000_krim_country_pack_admin_mobile_performance.sql`; `20261104223000_krim_enforce_market_activation_on_shipment_creation.sql` |
| 20261104230000 | `20261104230000_krim_global_corridor_compliance_engine.sql`; `20261104230000_krim_unify_market_activation_booking_gate.sql` |
| 20261104234500 | `20261104234500_seed_india_domestic_pilot_corridor_candidate.sql`; `20261104234500_seed_proposed_corridor_catalogue.sql` |
| 20261105153000 | `20261105153000_add_evidence_backed_partner_capability_submission.sql`; `20261105153000_enforce_partner_quote_create_permission.sql` |
| 20261106160000 | `20261106160000_create_customs_broker_assignment_foundation.sql`; `20261106160000_linked_goods_receipt_workflow.sql` |
| 20261106180000 | `20261106180000_driver_assignment_acceptance_gate.sql`; `20261106180000_operations_dispatch_readiness_register.sql` |
| 20261106190000 | `20261106190000_driver_assignment_leg_integrity.sql`; `20261106190000_global_vehicle_registry_foundation.sql` |
| 20261115151000 | `20261115151000_require_all_driver_documents_for_verification.sql`; `20261115151000_schedule_private_vehicle_evidence_expiry_worker.sql` |

## 2. Duplicate logical migration names at different timestamps
These may represent replays, corrections, revised versions or duplicated intent. The filename alone cannot establish which SQL body is reflected in production.

| Logical name | Repository versions |
|---|---|
| `enforce_active_markets_for_shipment_booking` | `20261025143059`, `20261025143500` |
| `seed_country_localization_and_units` | `20261025143459`, `20261025150000` |
| `add_missing_foreign_key_indexes` | `20261104235000`, `20261115072000` |

## 3. Required reconciliation method
1. Preserve this exact repository snapshot and record the commit SHA used for the comparison.
2. Obtain the sanitized production schema manifest using the committed operator workflow and the existing encrypted export. Never expose the raw SQL or passphrase.
3. Build a row-level production/repository crosswalk by version, logical name, statement category, object identifiers and statement fingerprints.
4. For every duplicate timestamp, establish which file(s), if any, were actually applied and in what order using deployment logs, schema effects and source-control history. A timestamp collision cannot be resolved by filename ordering.
5. For every duplicate logical name, compare full statement fingerprints and resulting catalog definitions; identify additive, corrective, repeated and superseded content.
6. Query live PostgreSQL catalogs for the current definitions of affected functions, triggers, policies, constraints, indexes and tables. Compare semantic definitions, not only object names.
7. Record each repository-only, production-only and divergent object; classify as intentionally retired, out-of-repository hotfix, unapplied, superseded or unresolved.
8. Have a database owner review the proposed forward-only migration strategy and recovery/rollback plan before any production change.

## 4. Explicit prohibitions while unresolved
- Do not delete, rename, combine or retimestamp migration files to make the list look clean.
- Do not run `db push`, replay migrations, baseline, squash, reset, or alter migration history.
- Do not apply ad-hoc production DDL, grants, policies, triggers, function replacements or constraint changes.
- Do not assume that a matching migration name proves its SQL body ran.
- Do not use the production database as a test environment.

## 5. Current status and next dependency
The previously measured production history contains 558 versions, while this repository snapshot contains 363 SQL files / 348 unique timestamps; only 82 were exact version+name matches in the earlier crosswalk. Production schema export artifact `14193475858` from workflow run `43793099331` is encrypted. The sanitized-manifest workflow and operator guide are committed, but an authorized repository operator still needs to run it with the documented inputs before the semantic crosswalk can proceed.

**Status: BLOCKED — awaiting sanitized production manifest and full semantic crosswalk.** No production database changes were made for this inventory.
