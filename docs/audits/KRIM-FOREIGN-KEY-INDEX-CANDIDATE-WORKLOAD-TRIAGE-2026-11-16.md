# KRIM Foreign-Key Index Candidate Workload and Size Triage
**Date:** 16 November 2026  
**Scope:** Read-only PostgreSQL statistics and relation-size review of tables containing the 49 FK index candidates. No schema/data changes.

## Executive finding
The catalog screen identified 49 foreign-key constraints without a matching leading index. The follow-up sampled 20 affected public tables using `pg_stat_user_tables`, `pg_class.reltuples`, and `pg_total_relation_size`.

Most operational tables are currently empty or near-empty and all sampled relations are small (16–208 kB). The only non-zero estimated row counts are small: `krim_quotes` 7, `payment_orders` 6, `payments` 4, `partners` 10, and `krim_partner_opportunities` 3. Several core dispatch/warehouse/custody/returns tables report zero estimated rows.

## Sampled table observations
| Table | Estimated rows | Total relation size |
|---|---:|---:|
| payment_orders | 6 | 208 kB |
| payments | 4 | 120 kB |
| krim_partner_opportunities | 3 | 104 kB |
| krim_driver_assignments | 0 | 96 kB |
| krim_quotes | 7 | 88 kB |
| krim_partner_quotes | 0 | 64 kB |
| krim_vehicle_driver_bindings | 0 | 64 kB |
| partners | 10 | 64 kB |
| krim_driver_tracking_sessions | 0 | 56 kB |
| krim_partner_compliance_evidence | 0 | 48 kB |
| krim_warehouse_shipment_allocations | 0 | 48 kB |
| krim_warehouse_transfers | 0 | 48 kB |
| krim_shipment_leg_custody_transfers | 0 | 40 kB |
| krim_shipment_leg_dispatch_authorizations | 0 | 40 kB |
| krim_shipment_return_quality_reviews | 0 | 32 kB |
| krim_shipment_return_receipt_items | 0 | 32 kB |
| krim_warehouse_transfer_quality_reviews | 0 | 32 kB |
| krim_shipment_return_receipts | 0 | 24 kB |
| krim_shipment_returns | 0 | 24 kB |
| krim_shipment_leg_custody_transfer_events | 0 | 16 kB |

Statistics counters showed some scans and writes on the small quote/payment/partner tables, but these counters are cumulative since statistics reset and do not by themselves establish a performance bottleneck. Several operational tables showed zero index scans and no inserts/updates/deletes in the reported counters.

## Decision
**Do not add all 49 indexes now.** On current observed table sizes, blanket index creation would add write/storage overhead without demonstrated performance benefit. The FK coverage gaps should remain tracked as conditional optimization candidates, not production defects requiring immediate DDL.

When real workloads grow, prioritize:
1. quote/payment/partner relationships after checking query plans and payment workflow design;
2. driver assignment and dispatch authorization relationships when real assignments are activated;
3. warehouse allocation/transfer and custody/return relationships when those operations have genuine records.

Before creating any index, inspect query plans, table growth, index duplication, FK delete/update behavior and write rates. Use concurrent index creation only through a reviewed, migration-safe deployment plan if appropriate; do not run ad hoc production DDL.

## Limitations
- `n_live_tup` and `reltuples` are estimates, not exact counts.
- `pg_stat_user_tables` counters are cumulative since the last stats reset and are not a time-windowed workload profile.
- This review does not use production query plans, `pg_stat_statements` samples, lock history, or peak-period telemetry.
- The earlier 559-FK / 510-indexed / 49-uncovered count remains a structural screen, not a performance incident count.

## Safety
Read-only inspection only. No indexes, tables, functions, policies, grants, data, or migration-history records were changed. The production migration reconciliation blocker remains open pending the sanitized schema-manifest workflow.
