# KRIM Staging Migration Ledger Source Reconciliation — 2026-11-24

## Scope and safety

Read-only comparison of the live Supabase migration ledger for the project named **KRIM Logistics Staging** (`qrpcivhdxobiaofppbkl`) against repository migration filenames at commit `e78aa8b607b915cacaac2b118c5149f1d97ce17b`.

No SQL, schema, data, grants, or migration ledger rows were changed. This is not approval to reset, repair, or replay the ledger.

## Result

- Staging ledger rows: **34**
- Exact version + basename matches in repository: **0**
- Basename-only matches: **3**
- Staging ledger rows without a repository basename match: **31**

The three basename matches are:
- `20261117142325_restore_driver_trip_event_rpc_access`
- `20261123044852_admin_driver_licence_expiry_control`
- `20261123044931_refine_admin_driver_licence_expiry_rpc_security`

The 31 unmatched rows are listed below exactly as returned by the staging ledger.

## Staging-only ledger entries with no repository basename match

| Version | Ledger name |
|---|---|
| 20261117135137 | grant_partner_service_area_admin_queue |
| 20261117135331 | grant_partner_capacity_admin_queue_access |
| 20261117135423 | require_verified_capacity_for_partner_matching |
| 20261117135841 | require_current_partner_compliance_for_bids |
| 20261117140013 | recheck_partner_compliance_on_customer_acceptance |
| 20261117140527 | require_warehouse_handover_before_single_leg_dispatch |
| 20261117141052 | add_audited_driver_exception_resolution |
| 20261117141548 | restore_customer_journey_rpc_access |
| 20261117142125 | restore_partner_assignment_rpc_access |
| 20261117142302 | restore_guarded_dispatch_rpc_access |
| 20261117142445 | add_resend_notification_queue_worker |
| 20261117142500 | add_guarded_partner_single_leg_dispatch |
| 20261117142822 | restore_guarded_multileg_custody_rpc_access |
| 20261117143136 | 20261117180000_grant_partner_network_submission_rpcs |
| 20261117143150 | restore_guarded_delivery_pod_rpc_access |
| 20261117143201 | restore_guarded_delivery_pod_workflow_access |
| 20261117143400 | 20261117190000_grant_country_pack_admin_review_rpcs |
| 20261117143847 | seed_country_governance_catalogue |
| 20261117143904 | add_admin_requirement_catalogue_rpc |
| 20261117143951 | add_india_country_governance_pack |
| 20261117144450 | allow_leg_dispatch_authorization_event |
| 20261117144642 | 20261117240000_align_country_pack_readiness_gates.sql |
| 20261117144901 | 20261117240000_align_country_pack_readiness_gates |
| 20261117152122 | restore_canonical_transport_mode_catalogue |
| 20261117152656 | partner_capacity_rejected_resource_resubmission |
| 20261117155425 | require_physical_capacity_before_assignment_finalization |
| 20261117155714 | partner_assignment_capacity_state_read_rpc |
| 20261117160049 | harden_assignment_terminal_capacity_release |
| 20261117161804 | tighten_dispatchable_driver_eligibility |
| 20261117164549 | audit_driver_assignment_acceptance |
| 20261122055153 | customer_shipment_creation_location_rpc |

## Naming anomalies requiring source recovery

Three staging ledger names contain embedded timestamps or file extensions:
- `20261117143136 / 20261117180000_grant_partner_network_submission_rpcs`
- `20261117143400 / 20261117190000_grant_country_pack_admin_review_rpcs`
- `20261117144642 / 20261117240000_align_country_pack_readiness_gates.sql`

A near-duplicate readiness-gates entry also exists at `20261117144901 / 20261117240000_align_country_pack_readiness_gates`. These cannot safely be normalized or rewritten without recovering the original applied SQL and understanding why the ledger contains both entries.

## Required safe recovery sequence

1. Recover the exact SQL bodies that were applied to staging, from the original migration source, deployment artifacts, or database change records. Do not synthesize historical migrations from current schema state.
2. Compare each recovered body against current staging schema, function definitions, ACLs, policies, and seed data.
3. Identify the authoritative canonical repository migration sequence and resolve timestamp/name collisions without rewriting already-applied history.
4. Only after source recovery, create a new forward-only reconciliation migration for any missing current-state objects. Do not edit `supabase_migrations.schema_migrations` manually and do not reset staging.
5. Re-run staging smoke checks and role-scoped positive/negative tests after the reconciliation plan is approved.

## Release implication

Staging's migration history is not currently reproducible from the repository. A schema-only bootstrap must not be rerun against this populated staging project. This remains a release blocker for applying the proposed permission-catalogue and warehouse-ACL repairs to staging, even though their isolated PostgreSQL tests pass.
