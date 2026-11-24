# KRIM production–staging reference catalogue parity — 2026-11-24

## Scope

Read-only comparison of reference catalogue row counts in Supabase staging and production. No data, schema, grants, migrations, or settings were changed.

## Verified row counts

| Catalogue | Staging total | Staging active/granted | Production total | Production active/granted |
|---|---:|---:|---:|---:|
| Countries | 246 | 0 | 249 | 6 |
| Currencies | 0 | 0 | 156 | 6 |
| Markets | 0 | 0 | 6 | 6 |
| Transport modes | 7 | 7 | 6 | 6 |
| Security roles | 11 | 11 | 11 | 11 |
| Security permissions | 0 | 0 | 23 | 23 |
| Role-permission mappings | 0 | 0 | 155 | 155 |

Staging's India row exists but is inactive. Production's India row is active. Staging contains a seventh active transport mode, WAREHOUSE, which is not present in the six-row production catalogue count; do not delete it without understanding its dependencies and intended status.

## Functional impact

This is a systemic staging seed/catalogue gap, not just a warehouse-specific issue.

- Currency and market catalogues are empty, so flows depending on valid country/market/currency selection cannot be reliably tested.
- Security permissions and role-permission mappings are empty. The role table alone does not authorize any role through the role-permission join.
- All 246 staging country rows are inactive, including India.
- Warehouse eligibility depends on permission resolution and active country/capability data, so its onboarding failures have multiple independent causes.
- The staging transport-mode catalogue differs from production and contains an additional WAREHOUSE mode; its use needs an explicit compatibility decision.

## Recommended remediation

1. Treat production's active reference catalogues as the intended reference source, but do not copy production organizations, users, shipments, partner records, financial data, secrets, or other operational records.
2. Recover the canonical seed definitions from repository history and migration sources first. Compare exact codes and natural keys, not generated numeric IDs.
3. Create a reviewed, idempotent, versioned staging seed-repair migration for reference-only data:
   - restore the six intended active countries and their supported metadata;
   - restore the six active currencies and six active markets;
   - restore all 23 permission definitions and the 155 role-permission mappings with stable natural-key joins;
   - explicitly reconcile the additional WAREHOUSE transport mode rather than silently deleting it.
4. Apply only to staging after the migration-ledger path is approved; verify counts, foreign keys, active states and role mappings after application.
5. Repeat functional tests for customer, partner, driver, warehouse, finance and shipment creation against the repaired staging catalogue.
6. Do not mirror the seed repair to production: production is the current reference snapshot and no production data change is required by this audit.

## Release decision

Staging is not currently a valid production-like environment for full end-to-end verification. The seven reference datasets above are materially incomplete or divergent. The audit does not authorize direct SQL copying or ad hoc production changes. A canonical, versioned seed repair and migration-history reconciliation are required before staging can serve as a reliable acceptance environment.
