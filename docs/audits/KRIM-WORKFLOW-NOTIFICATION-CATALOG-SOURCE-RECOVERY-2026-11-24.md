# KRIM workflow / notification catalog source recovery — 2026-11-24

## Purpose
Recover verifiable source evidence for production workflow and notification objects whose original migration files are missing from the current repository. This is a read-only catalog comparison; it does not alter either database or migration ledger.

## Current migration-source gap
The production migration ledger contains 215 rows whose names relate to workflow, notification, shipment, customer, identity or partner:
- 24 have exact repository version + basename matches.
- 84 have a matching repository basename but a different timestamp.
- 107 have no matching repository basename.

A list of the 107 missing-source entries is retained in the migration-ledger reconciliation update and was re-queried from the live production ledger on 2026-11-24. Examples include foundational migrations:
- `add_global_partner_lifecycle`
- `add_shipment_partner_assignments`
- `harden_global_notification_delivery`
- `harden_global_workflow_automation`
- `harden_workflow_retry_dlq_runtime`
- `complete_workflow_action_dead_letter_quarantine_and_retry_runtime`
- `krim_customer_org_provisioning`
- `complete_customer_partner_quote_and_assignment_lifecycle`

These missing SQL files cannot be safely recreated from migration names alone. Current catalog definitions can recover present-day behavior, but not necessarily the original sequence, intermediate states, data backfills or dropped objects.

## Production ↔ staging catalog fingerprints
A direct read-only comparison was run against production project `ebltviniygljwwseplph` and staging project `qrpcivhdxobiaofppbkl`.

The following eight critical tables had identical ordered column fingerprints and constraint fingerprints in both databases:

| Table | Columns | Constraints | Column fingerprint | Constraint fingerprint |
|---|---:|---:|---|---|
| `krim_workflow_action_executions` | 23 | 6 | `2ff3adcbe9c8cc6e9eb86a23e9a92705` | `b96b78261265ad2bf1d27fe22782ad46` |
| `krim_workflow_dead_letter_events` | 10 | 3 | `6733802c4f2b9f648ebcf72c392a3d2d` | `7eca1ce38f95b8de7584e3de21bd6609` |
| `krim_workflow_dead_letters` | 23 | 8 | `d8f49ef00c2dafe7e16f1a1a38415e4f` | `c9b1b4cd1d4d849d09399e9655a560a4` |
| `krim_workflow_run_steps` | 10 | 4 | `13a299ffebceacc034f3a27aa0df1ae7` | `b3ab1df37874c6dbe7296a753ab4874b` |
| `krim_workflow_runs` | 18 | 5 | `adb98461e10f290fd09ba699472db5bf` | `848cd4d10c93323b2322eab900dea0ae` |
| `krim_workflow_steps` | 11 | 3 | `653e1a8c3abb6ca42d4eb1bc2e5facaa` | `9eb7401fd65f1444b4f391603106135d` |
| `krim_workflows` | 16 | 2 | `70483b3a7663e35534e4e3a38778e100` | `0305a511933fc95db8bac79de99491f9` |
| `notifications` | 9 | 5 | `f615300616b81752001937ece9c9e195` | `4c9c3e2e685c97f1fe188cad2985ab60` |

The fingerprints cover ordered column ordinal/name/type/nullability/default and named constraint definitions. They do not cover indexes, triggers, RLS policies, grants, table ownership, publications or data.

## Runtime function source fingerprints
The following nine runtime function definitions had identical MD5 fingerprints in production and staging. All are SECURITY DEFINER; catalog privilege checks confirmed `anon=false`, `authenticated=false`, `service_role=true` for each.

| Schema/function | Definition fingerprint |
|---|---|
| `public.krim_internal_claim_workflow_actions(text,integer,integer)` | `d2f51d4941ee91de12cfe9dd3a7dc1eb` |
| `public.krim_internal_execute_workflow_action(bigint)` | `6596cd34248457949912fcfdcf5ffb11` |
| `public.krim_internal_process_workflow_action_batch(text,integer,integer)` | `8b602866d2c3df1a046a7460c22037d3` |
| `public.krim_internal_quarantine_workflow_action(bigint,text)` | `2d826b2e92fdb5020a18b511a12b92d8` |
| `public.krim_internal_recover_expired_workflow_actions(integer)` | `ab07e1c6ff8377421a8f870032539666` |
| `krim_internal.quarantine_workflow_action_dead_letter(bigint,text,text,text,text)` | `4f43d655b705111bedd932203cfc5555` |
| `krim_internal.quarantine_workflow_action_failure(bigint,text,text,jsonb,text)` | `bedd6b1350732ad21cf38e0b904819c6` |
| `krim_internal.transition_workflow_action(bigint,text,text,text,text,text,jsonb)` | `96e68cb40d454f898079e4f3bcc87c77` |
| `krim_internal.transition_workflow_action(bigint,text,text,text,jsonb,text,text,text)` | `0dccf8502ca6dcd1406fa6d6cdd0801f` |

## What this establishes
- The staging database's core workflow tables and nine selected runtime functions match production at the catalog-definition level.
- This supports using staging for the PR #245 transactional compatibility tests on the exercised paths.
- It does not prove the complete database schemas, all dependent objects, row data, storage policies, edge-function secrets, or migration histories are identical.
- Identical present-day catalog fingerprints do not reconstruct the missing historical SQL migration source.

## Next recovery steps
1. Capture the complete definitions and dependency/ACL metadata for every production workflow, notification, shipment and partner function/table/trigger/policy, not only the nine functions above.
2. Export current catalog DDL from the connected project through supported database catalog queries and retain it as a clearly labelled current-state baseline, never as historical migration SQL.
3. For each missing ledger row, compare the current catalog with the repository source and available Git history; classify as source recoverable, catalog-only reconstruction, superseded, or unresolved.
4. Keep migration ledger repair and production deployment blocked until all relevant rows and their effects are accounted for.

## Release decision
No migration repair, production DDL, or ledger mutation is authorized by this audit. PR #245 remains draft.


## Additional index / trigger / RLS policy comparison
A second catalog comparison covered indexes, non-internal triggers and RLS policies on the same eight tables:
- All eight tables have identical index counts and index-definition fingerprints in production and staging.
- Neither database has user-defined triggers on these eight tables (zero each).
- Policy definitions, commands, permissive flags and role names were normalized and compared. All eight policy fingerprints match exactly, including both authenticated ownership policies on `notifications`.
- Initial raw policy hashes differed only because the first comparison included database-specific role OIDs; re-hashing with role names removed that false difference.
- `notifications` has 7 indexes and 2 policies; each workflow table has its matching single organization-access policy.

This closes the table-level comparison for columns, constraints, indexes, user-defined triggers and RLS policy definitions on these eight objects. It still does not compare grants, ownership, publication membership, all dependent objects or the full schema.


## Table privilege difference discovered
The normalized table-grant comparison found one intentional-or-unresolved environment difference:
- Production grants `authenticated SELECT` on the seven workflow metadata/execution tables covered here (`krim_workflows`, `krim_workflow_steps`, `krim_workflow_runs`, `krim_workflow_run_steps`, `krim_workflow_action_executions`, `krim_workflow_dead_letters`, `krim_workflow_dead_letter_events`).
- Staging does not grant `authenticated SELECT` on those seven tables.
- Both environments have matching `authenticated SELECT, UPDATE` grants on `notifications`, with RLS policies restricting users to their own `user_id`.
- Both environments grant `service_role` the same listed table privileges on these eight tables.

This is a real staging/prod API-access difference. The workflow UI/API must not assume staging authenticated users can read workflow tables. Before changing grants, verify which admin/control-tower pages require them and confirm the production RLS policies provide the intended organization boundary. No grant was added or removed in this work.


## Git history recovery attempt
For five high-impact missing ledger entries, I checked the exact expected migration paths against GitHub file history and inspected three related lifecycle/foundation/audit branch trees:
- `20260929043657_add_global_partner_lifecycle.sql`
- `20260929044040_add_shipment_partner_assignments.sql`
- `20260929044351_harden_global_notification_delivery.sql`
- `20260929044417_harden_global_workflow_automation.sql`
- `20261011161742_complete_workflow_action_dead_letter_quarantine_and_retry_runtime.sql`

No exact-path commit history or matching files were found in those inspected branches. A commit search for the notification hardening name returned a large UI release commit, but its available diff did not contain the migration SQL. This means these five files were not recovered from the inspected Git history; it does not prove no other uninspected branch or external backup contains them.

Do not reconstruct historical migrations from the current catalog and pretend they are originals. Retain a current-state schema/function export separately and label it as a baseline snapshot.
