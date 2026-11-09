# KRIM Privileged RPC Review — Inventory Update — 2026-11-09

## Scope
Read-only PostgreSQL catalog analysis of SECURITY DEFINER functions in `public`, `private`, and `krim_internal` that authenticated users can execute. No database changes were made.

## Inventory
147 SECURITY DEFINER functions are executable by `authenticated` across the inspected schemas. None of these 147 were executable by `anon` in the catalog privilege checks.

Name-based grouping:
| Domain | Count |
|---|---:|
| Driver / vehicle / dispatch | 30 |
| Identity / organization / admin | 37 |
| Partner / carrier / capability | 25 |
| Shipment / quote / tracking / POD | 17 |
| Warehouse / inventory / quality | 17 |
| Finance / payment / ledger | 3 |
| Other | 18 |
| Total | 147 |

Pattern scan of function source:
| Domain | Total | Direct auth.uid/auth.jwt/auth.role marker | Permission/membership/admin marker | Explicit rejection marker |
|---|---:|---:|---:|---:|
| Driver / vehicle / dispatch | 30 | 23 | 26 | 24 |
| Identity / organization / admin | 37 | 37 | 34 | 34 |
| Partner / carrier / capability | 25 | 21 | 17 | 22 |
| Shipment / quote / tracking / POD | 17 | 17 | 14 | 17 |
| Warehouse / inventory / quality | 17 | 16 | 5 | 16 |
| Finance / payment / ledger | 3 | 3 | 2 | 3 |
| Other | 18 | 17 | 14 | 17 |

## Interpretation
- A missing direct auth marker in a SECURITY DEFINER wrapper is not automatically a vulnerability: it may delegate to an internal routine that enforces authorization.
- Conversely, the presence of an auth or permission marker is not proof of correct authorization. Call-chain review and negative tests are required.
- The 147 functions are not yet all individually source-reviewed. In particular, the warehouse domain has relatively few obvious permission-helper markers; its authorization may be enforced by internal routines, table guards, or other mechanisms and needs priority call-chain inspection.
- The finance functions must be reviewed for idempotency, ownership, webhook-only privileged actions, and separation of customer/partner payout visibility.
- Do not bulk revoke EXECUTE, convert functions to SECURITY INVOKER, or change grants without checking dependencies and intended API contracts.

## Priority remaining work
1. Individually inspect all warehouse, finance, shipment, partner, and driver write RPC call chains.
2. Verify every function checks organization membership, ownership, role/permission, allowed state transitions, and any required MFA.
3. Add staging negative tests for cross-organization reads/writes, replayed transitions, forged IDs, and unauthorized role access.
4. Review the 18 functions grouped as other; name-based grouping is approximate.

## Status
This is an inventory and triage report, not a completed privileged-RPC security audit. Production remains read-only and untouched.
