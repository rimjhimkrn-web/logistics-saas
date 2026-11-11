# KRIM Production Migration Reconciliation — Read-only Inventory
Date: 11 November 2026
Project: Logistics SaaS production
Status: NOT reconciled; production DDL remains blocked.

## Inventory
The current Supabase migration list and GitHub `main` tree were compared by version and descriptive migration name.

| Measure | Count |
|---|---:|
| Production migration history entries | 425 |
| SQL migration files in repository | 263 |
| Exact version overlap | 64 |
| Repository versions absent from production history | 199 |
| Production versions absent from repository | 361 |
| Descriptive names appearing in both inventories | 203 |

The exact-version comparison is distinct from the earlier descriptive-name comparison. Many migrations share a descriptive name but use different version timestamps. Therefore, the earlier overlap by name does not establish that the repository and production contain the same migration sequence or SQL content.

## Interpretation
- This is substantial migration-history divergence.
- The comparison is metadata-only; it does not prove that any particular schema change is missing or incorrectly applied.
- A repository migration version absent from production history may have been deployed under another timestamp, applied manually, or not applied.
- A production migration version absent from the repository may be a generated/deployed migration not committed to this repository, or may have been applied through another workflow.
- Do not replay, mark-as-applied, squash, reset, or fabricate migration history to make the counts match.
- Do not run production DDL for the SaaS subscription engine until each relevant migration has been mapped to its SQL source and the actual schema state has been inspected.

## Safe reconciliation procedure
1. Export the complete production migration metadata list and repository migration file list as immutable audit artifacts.
2. Build a name-to-version crosswalk for all 203 shared descriptive names, then inspect the SQL source for every differing version.
3. Retrieve the deployed SQL/source history from the authoritative deployment workflow or backups where repository copies are absent.
4. Compare relevant DDL against the live catalog: tables, columns, constraints, indexes, policies, grants, triggers, functions and extensions.
5. Classify each migration as exact match, equivalent under another version, production-only, repository-only, manually applied, or unresolved.
6. Have a second reviewer approve the crosswalk and schema baseline.
7. Only then create a new, forward-only SaaS migration using the verified production baseline and test it in a non-production environment first.

## Commercial impact
The subscription engine remains design-only. No SaaS tables, recurring billing, trials, subscription invoices, or paid entitlements were created in production. Existing freight payment tables remain separate and must not be repurposed.

## Verification boundary
This inventory comparison was read-only. No production schema, data, migration history, payment settings or customer records were modified.
