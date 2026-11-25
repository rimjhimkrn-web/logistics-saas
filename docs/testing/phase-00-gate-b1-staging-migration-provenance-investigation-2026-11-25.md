# Phase 00 — Gate B1 Staging migration provenance investigation

**Date:** 2026-11-25  
**Scope:** Read-only comparison of live Supabase migration ledgers against the source-controlled `supabase/migrations` directory on GitHub `main` and QA branches.  
**Production project:** `ebltviniygljwwseplph`  
**Staging project:** `qrpcivhdxobiaofppbkl`  
**Safety:** No migration, DDL, DML, reset, ledger repair, deployment, Auth or provider operation was performed.

## Executive finding

**B1: BLOCKED — the Staging migration ledger is not reproducible from the current repository migration directory.**

Current source-controlled directory inventory:
- `main`: 368 migration SQL files.
- `qa/phase-00-baseline-2026-11-25`: 368 files.
- The filename and blob-SHA inventories matched exactly between those branches.

Live migration ledger comparison by migration **name** (not version timestamp):
- Production: 561 ledger records; **291** names have an exact corresponding SQL filename in the current repo; **270** names do not.
- Staging: 34 ledger records; only **3** names have an exact corresponding SQL filename in the current repo; **31** names do not.
- The 3 Staging name matches are:
  - `restore_driver_trip_event_rpc_access`
  - `admin_driver_licence_expiry_control`
  - `refine_admin_driver_licence_expiry_rpc_security`

This explains why comparing version identifiers alone was misleading: the Staging ledger versions differ from repository timestamps, and some Staging ledger names are not present in the source-controlled migration directory. However, name matching is only a provenance clue; it does not prove that the SQL file contents that were applied match the present file contents.

## 1. Exact source inventory

The GitHub Contents API returned the complete `supabase/migrations` directory listing on both branches:
- Main branch directory: 368 SQL files.
- QA branch directory: 368 SQL files.
- Filename inventories and Git blob SHAs matched between main and QA.
- No Staging-specific migration files were found in that directory on either branch.

The directory listing is not a complete history of every migration ever applied to the live databases. The live ledger itself contains more records than the repository currently stores.

## 2. Staging ledger names missing from the current repository

All 31 unmatched names are listed below. These are not currently reproducible by an exact filename lookup in `main/supabase/migrations`:

```text
20261117135137 grant_partner_service_area_admin_queue
20261117135331 grant_partner_capacity_admin_queue_access
20261117135423 require_verified_capacity_for_partner_matching
20261117135841 require_current_partner_compliance_for_bids
20261117140013 recheck_partner_compliance_on_customer_acceptance
20261117140527 require_warehouse_handover_before_single_leg_dispatch
20261117141052 add_audited_driver_exception_resolution
20261117141548 restore_customer_journey_rpc_access
20261117142125 restore_partner_assignment_rpc_access
20261117142302 restore_guarded_dispatch_rpc_access
20261117142445 add_resend_notification_queue_worker
20261117142500 add_guarded_partner_single_leg_dispatch
20261117142822 restore_guarded_multileg_custody_rpc_access
20261117143136 20261117180000_grant_partner_network_submission_rpcs
20261117143150 restore_guarded_delivery_pod_rpc_access
20261117143201 restore_guarded_delivery_pod_workflow_access
20261117143400 20261117190000_grant_country_pack_admin_review_rpcs
20261117143847 seed_country_governance_catalogue
20261117143904 add_admin_requirement_catalogue_rpc
20261117143951 add_india_country_governance_pack
20261117144450 allow_leg_dispatch_authorization_event
20261117144642 20261117240000_align_country_pack_readiness_gates.sql
20261117144901 20261117240000_align_country_pack_readiness_gates
20261117152122 restore_canonical_transport_mode_catalogue
20261117152656 partner_capacity_rejected_resource_resubmission
20261117155425 require_physical_capacity_before_assignment_finalization
20261117155714 partner_assignment_capacity_state_read_rpc
20261117160049 harden_assignment_terminal_capacity_release
20261117161804 tighten_dispatchable_driver_eligibility
20261117164549 audit_driver_assignment_acceptance
20261122055153 customer_shipment_creation_location_rpc
```

Two records have suspicious name formatting:
- `20261117143136` has a migration name that itself begins with a timestamp.
- `20261117144642` and `20261117144901` use near-identical timestamp-prefixed names, one including a `.sql` suffix. This may represent duplicate/repaired/renamed migration history, but the underlying SQL and applied effects are not known.

Do not infer the applied SQL from these names.

## 3. Production provenance gap

Production has 270 ledger names not present as exact current repository filenames. Its first records include foundational migrations dated 2026-09-29 (for example `add_global_partner_lifecycle`, `add_partner_verification_cases`, `add_partner_global_service_areas`) that are absent from the current directory listing. There are also later records absent from the repository. This indicates that the current migration directory is not a complete archive of Production's applied migration history.

The current repository therefore cannot independently reconstruct either environment's full historical migration chain.

## 4. What this establishes — and what it does not

Established:
1. The Staging migration ledger is not source-reproducible from the current checked-in migration directory by exact migration name.
2. Production's ledger also contains substantial migration history not archived in the current directory.
3. Main and QA currently share the same migration directory inventory and blob SHAs.
4. The live migration histories differ not only by version identifiers but also by names and source-file availability.

Not established:
- Whether Staging was created by manual SQL, a schema snapshot, a different repository/branch, an external pipeline, or a selective migration bundle.
- Whether the 31 unmatched Staging records correspond to SQL that exists elsewhere (old commits, deleted files, another repo, dashboard history, backup, or operator workstation).
- Whether the present three matching SQL files are byte-for-byte the SQL that was applied at the time.
- Whether any migration was recorded without applying, applied without recording, or manually modified afterward.
- Whether the 270 unmatched Production records are safely reconstructable from older Git history.

## 5. Required evidence to close B1

1. Locate historical migration files through Git history (including deleted/renamed files) for each missing Production and Staging migration name.
2. Obtain the original Staging bootstrap source: Supabase project creation/provisioning record, initial schema dump, backup/restore origin, and any manual SQL or deployment bundle.
3. Obtain an authoritative record of how each Staging ledger entry was applied and verify its SQL checksum/content against the corresponding historical source file.
4. Inspect the suspicious timestamp-prefixed/duplicate Staging ledger names and determine whether they are duplicate applications, ledger repairs, or naming mistakes.
5. Preserve all original ledgers. Do not edit `supabase_migrations.schema_migrations` to make counts or timestamps look aligned.
6. Once provenance is established, generate a forward-only, reviewed reconciliation plan based on actual object differences, not on ledger count subtraction.

## 6. B1 checklist

| Check | Result |
|---|---|
| Current main migration directory inventory | PASS — 368 files |
| Current QA migration directory inventory | PASS — same 368 files and blob SHAs |
| Production ledger exact-name source coverage | PARTIAL — 291/561 |
| Staging ledger exact-name source coverage | FAIL — 3/34 |
| Staging unmatched names enumerated | PASS — 31 enumerated |
| Historical deleted/renamed files searched across full Git history | NOT TESTED |
| Original Staging bootstrap/provisioning evidence obtained | NOT TESTED |
| Applied SQL checksums proven | NOT TESTED |
| Staging provenance established | BLOCKED |
| Safe migration reconciliation authorized | BLOCKED |

## Safety statement

Only live migration metadata and GitHub repository directory metadata were read. No migration SQL was executed, no database table changed, no migration ledger was edited, and no reset/rebase/merge/deployment or external provider action was performed.

**Disposition: B1 BLOCKED.** Next safe task is read-only Git-history provenance search for the 31 Staging ledger names, followed by locating the original Staging bootstrap source.