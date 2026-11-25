# Phase 00 — Gate B1.1 Historical Git provenance search for Staging migrations

**Date:** 2026-11-25  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Related report:** `phase-00-gate-b1-staging-migration-provenance-investigation-2026-11-25.md`  
**Scope:** Read-only GitHub history and code-search investigation for the 31 Staging migration ledger names that have no exact current source-file match.

## Result

**Historical repository provenance: NOT FOUND in the paths/searches examined. B1 remains BLOCKED.**

The GitHub commit-history endpoint was queried for the exact expected path `supabase/migrations/<migration_name>.sql` for all 27 distinct unmatched names without embedded timestamp/extension anomalies, in three batches. All 27 queries returned an empty commit list. GitHub code search was also run for eight representative exact migration names against the repository's default branch; it returned no matches.

This is negative evidence only for the queried repository/path/search scope. It does not prove the SQL never existed in another repository, branch inaccessible to the connector, local workspace, backup, dashboard editor, external deployment artifact, or under a different/renamed filename.

## Coverage

The 27 normal-form names queried in commit history:
```text
grant_partner_service_area_admin_queue
grant_partner_capacity_admin_queue_access
require_verified_capacity_for_partner_matching
require_current_partner_compliance_for_bids
recheck_partner_compliance_on_customer_acceptance
require_warehouse_handover_before_single_leg_dispatch
add_audited_driver_exception_resolution
restore_customer_journey_rpc_access
restore_partner_assignment_rpc_access
restore_guarded_dispatch_rpc_access
add_resend_notification_queue_worker
add_guarded_partner_single_leg_dispatch
restore_guarded_multileg_custody_rpc_access
restore_guarded_delivery_pod_rpc_access
restore_guarded_delivery_pod_workflow_access
seed_country_governance_catalogue
add_admin_requirement_catalogue_rpc
add_india_country_governance_pack
allow_leg_dispatch_authorization_event
restore_canonical_transport_mode_catalogue
partner_capacity_rejected_resource_resubmission
require_physical_capacity_before_assignment_finalization
partner_assignment_capacity_state_read_rpc
harden_assignment_terminal_capacity_release
tighten_dispatchable_driver_eligibility
audit_driver_assignment_acceptance
customer_shipment_creation_location_rpc
```

Four additional unusual ledger records were not treated as normal filenames:
- `20261117143136 / 20261117180000_grant_partner_network_submission_rpcs`
- `20261117143400 / 20261117190000_grant_country_pack_admin_review_rpcs`
- `20261117144642 / 20261117240000_align_country_pack_readiness_gates.sql`
- `20261117144901 / 20261117240000_align_country_pack_readiness_gates`

These require searching for alternate names and examining the exact ledger rows and any operator records. The two `align_country_pack_readiness_gates` rows may be related, but no duplicate application or SQL equivalence is inferred.

## Existing matching files

The three Staging ledger names that did map to current source files remain:
- `restore_driver_trip_event_rpc_access`
- `admin_driver_licence_expiry_control`
- `refine_admin_driver_licence_expiry_rpc_security`

This confirms only name-level correspondence. It does not prove historical content/checksum equality.

## Next provenance evidence required

1. Search every accessible repository branch and tag, not only the default branch, using recursive Git trees and commit history; inspect renamed/deleted migration paths.
2. Ask the project operator to identify the exact Staging bootstrap source: SQL editor history/export, migration bundle, backup/restore origin, CLI logs, CI/CD logs, or original machine/repository.
3. Obtain authoritative migration SQL text/checksums for the 31 entries and compare them with the actual live object definitions.
4. Inspect the two near-duplicate country-pack ledger entries and the timestamp-prefixed network/country-pack records.
5. Preserve the existing migration ledger and do not repair timestamps, mark migrations applied/reverted, replay, reset, or run SQL to force parity.

## Gate decision

| Check | Result |
|---|---|
| Exact-path commit-history search for 27 normal-form missing names | PASS — queried; no commits returned |
| Representative exact-name GitHub code search | PASS — queried; no default-branch matches returned |
| Alternate names, all branches/tags and deleted/renamed path sweep | NOT TESTED |
| Original Staging bootstrap source located | BLOCKED |
| Historical applied SQL text/checksums recovered | BLOCKED |
| Migration ledger provenance established | BLOCKED |
| Safe reconciliation authorized | BLOCKED |

## Safety

Only GitHub repository metadata and search endpoints were read. No Production or Staging database writes, migration execution, ledger edits, resets, deployments, Auth operations, or external provider calls occurred.
