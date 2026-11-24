# KRIM production migration-history reconciliation — 2026-11-24

## Scope

Read-only comparison of the Supabase production migration ledger (`supabase_migrations.schema_migrations`, via the Supabase migration listing) against every `supabase/migrations/*.sql` file on GitHub `main` at the time of inspection.

No migration repair, schema change, migration execution, or history mutation was performed.

## Exact inventory

| Measure | Result |
|---|---:|
| Production migration ledger rows | 561 |
| Unique production versions | 561 |
| Repository SQL migration files | 368 |
| Unique repository migration versions | 353 |
| Exact version matches | 82 |
| Production versions with no same-version repository file | 479 |
| Repository versions absent from production ledger | 286 |
| Repository duplicate-version groups | 13 |
| Repository duplicate files beyond unique versions | 15 |
| Unique migration names present on both sides with different version IDs | 209 |

Production ledger range: `20260929043657` through `20261124071550`.

Repository migration file range: `20261016120808` through `20261124120000`.

## Important interpretation

The counts above are **version-ID comparisons**, not a list of migrations safe to replay.

The name-based comparison shows 209 unique migration names represented on both sides with different version IDs (211 repository-to-production version pairings). Many apparent repository-only versions are already represented in production under a different timestamp. Examples:

| Migration name | Repository version | Production version |
|---|---|---|
| `enforce_payment_provider_reference_idempotency` | `20261017120000` | `20261017054157` |
| `krim_warehouse_core_operations` | `20261024080000` | `20261024081234` |
| `driver_carrier_invitation_and_membership_workflow` | `20261104190000` | `20261104123850` |
| `admin_driver_licence_expiry_control` | `20261123100000` | `20261123045209` |
| `krim_report_operational_exception` | `20261124120000` | `20261124071550` |

There are also repository duplicate timestamp groups. A migration ledger keyed by version cannot safely distinguish multiple different SQL files carrying the same version. The 13 duplicate groups must be resolved in repository history with a reviewed, unique version strategy before a clean replayable baseline can be produced.

The repository currently has 76 migration names not found in the production ledger by name, while production has 270 names not found in the repository by name. These need file/content-level comparison and schema-state evidence; they must not be blindly marked applied or replayed.

## Reconciliation procedure — required before database DDL

1. Freeze new production DDL/migration application while the baseline is reconstructed.
2. Export the complete production migration ledger and retain it as immutable evidence.
3. Build a three-way manifest: production version/name, repository filename/version/name, and SQL-content hash.
4. For each same-name/different-version item, compare SQL content hashes and resulting live schema objects. Do not infer equivalence from names.
5. For production-only migrations, recover the exact SQL from trusted historical commits, deployment artifacts or backups; if unavailable, reconstruct from audited schema only with explicit review.
6. For repository-only migrations, determine whether each is unapplied, superseded, renamed, or already represented by a different production migration.
7. Resolve duplicate repository version IDs by assigning unique new versions only where safe and updating references/CI tooling. Never rewrite the production ledger simply to make counts match.
8. Generate a clean baseline and replay it into a disposable Supabase project/branch. Compare resulting schema, function definitions, grants, RLS policies, triggers, indexes and extensions against production.
9. Only after parity is proven, add notification reliability changes as new forward-only migrations, test in staging, then schedule a controlled production rollout.

## Notification work relationship

The deployed notification Edge Function sources have now been captured in:
- `supabase/functions/krim-notification-retry-worker/index.ts`
- `supabase/functions/krim-notification-provider-adapter/index.ts`

Those source snapshots were verified byte-for-byte against the active deployed `index.ts` files at capture time. This does not correct the notification database RPCs or make customer/partner delivery production-ready.

The notification database remediation remains blocked until the migration baseline and caller/grant inventory are verified. Required fixes remain: lease expiry/reclaim, unique per-claim fencing, idempotent delivery-attempt creation, truthful accepted-vs-delivered states, bounded retries/dead-lettering, provider callback verification, and real customer/partner provider dispatch.

## Safety decision

**NO-GO for applying notification DDL or migration-history repair directly to production at this stage.** The mismatch is a source-of-truth problem requiring a controlled baseline reconstruction. No production changes were made during this audit.


## Follow-up: exact repository duplicate-version collision inventory

A fresh GitHub directory inventory confirmed 13 distinct migration version IDs are each assigned to more than one SQL file. These are **version-key collisions**, not merely repeated migration names:

| Version | Files sharing the version |
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

These 13 groups account for 15 additional files beyond one file per unique version. A version-keyed migration ledger cannot unambiguously represent all files in these groups. This is a repository replay blocker even before comparing the contents.

A separate migration-name collision inventory found three names used at multiple repository versions:
- `enforce_active_markets_for_shipment_booking`: `20261025143059`, `20261025143500`.
- `seed_country_localization_and_units`: `20261025143459`, `20261025150000`.
- `add_missing_foreign_key_indexes`: `20261104235000`, `20261115072000`.

### Next forensic gate

For every duplicate-version group, fetch the full SQL bodies and compare normalized and exact content hashes. Classify each as identical duplicate, partial overlap, independent migration, or conflicting rewrite. Then inspect historical commit order and production ledger/name evidence. Do not renumber or delete any file until dependency order and production representation are established.

This inventory is static evidence only. No migration SQL was run and no production history was changed.


## Follow-up: duplicate-version files mapped against production migration names

The 13 duplicate-version groups were compared by filename stem against the live production migration ledger. This is a name/version mapping only; it does not establish SQL-content equivalence.

| Repository duplicate version | Repository migration name | Production ledger match |
|---|---|---|
| `20261025150000` | `krim_ensure_initial_shipment_leg` | Two production entries: `20261025110931`, `20261025112519` |
| `20261025150000` | `seed_country_localization_and_units` | `20261025143459` |
| `20261104190000` | `allow_driver_profile_transfer_on_valid_invitation` | No same-name production row |
| `20261104190000` | `driver_carrier_invitation_and_membership_workflow` | `20261104123850` |
| `20261104190000` | `driver_verification_documents_and_review` | No same-name production row |
| `20261104190000` | `partner_route_scope_and_driver_verification` | No same-name production row |
| `20261104191500` | `align_driver_review_with_invitation_gates` | No same-name production row |
| `20261104191500` | `require_confirmed_email_for_driver_invitation` | `20261104124749` |
| `20261104192500` | `fix_driver_invitation_profile_branch` | `20261104125108` |
| `20261104192500` | `scope_driver_document_upload_to_pending_profile` | `20261104134348` |
| `20261104193000` | `reverify_driver_after_identity_changes` | `20261104134336` |
| `20261104193000` | `secure_driver_membership_invitations` | No same-name production row |
| `20261104223000` | `krim_country_pack_admin_mobile_performance` | `20261104154412` |
| `20261104223000` | `krim_enforce_market_activation_on_shipment_creation` | `20261104153026` |
| `20261104230000` | `krim_global_corridor_compliance_engine` | No same-name production row |
| `20261104230000` | `krim_unify_market_activation_booking_gate` | `20261104153210` |
| `20261104234500` | `seed_india_domestic_pilot_corridor_candidate` | No same-name production row |
| `20261104234500` | `seed_proposed_corridor_catalogue` | No same-name production row |
| `20261105153000` | `add_evidence_backed_partner_capability_submission` | `20261105151950` |
| `20261105153000` | `enforce_partner_quote_create_permission` | `20261105041122` |
| `20261106160000` | `create_customs_broker_assignment_foundation` | `20261106044553` |
| `20261106160000` | `linked_goods_receipt_workflow` | No same-name production row |
| `20261106180000` | `driver_assignment_acceptance_gate` | `20261105072829` |
| `20261106180000` | `operations_dispatch_readiness_register` | No same-name production row |
| `20261106190000` | `driver_assignment_leg_integrity` | No same-name production row |
| `20261106190000` | `global_vehicle_registry_foundation` | `20261105073241` |
| `20261115151000` | `require_all_driver_documents_for_verification` | `20261115093706` |
| `20261115151000` | `schedule_private_vehicle_evidence_expiry_worker` | `20261115093414` |

### What this proves — and what it does not

- Several repository migration files clearly use a timestamp different from the production ledger entry with the same name.
- Ten file-name entries in these duplicate-version groups have no exact same-name production row. They may be superseded, combined into differently named production migrations, unapplied, or missing from the ledger. This cannot be decided from names alone.
- The `20261025150000_seed_country_localization_and_units.sql` file is a 217-character no-op explicitly identifying the production-applied migration as `20261025143459_seed_country_localization_and_units.sql`; this particular duplicate is documented as a superseded no-op.
- The `20261025150000_krim_ensure_initial_shipment_leg.sql` file is substantive and shares its version with that no-op file, so the repository version collision remains material.
- All remaining same-version collisions require exact SQL-body and historical-order comparison. Do not assume the files are safe to combine or renumber.

### Decision

The repository migration directory is not currently a deterministic replay set. Continue with per-file content comparison and historical commit tracing in an isolated reconstruction workflow. Production remains untouched.
