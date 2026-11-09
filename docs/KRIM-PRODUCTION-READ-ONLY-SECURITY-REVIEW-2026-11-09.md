# KRIM Production Read-Only Security Review — 2026-11-09

## Scope and safety
- Read-only catalog queries against production project `logistics-saas`.
- No schema, rows, grants, secrets, payment settings, or production configuration were changed.
- No decrypted SQL was committed or uploaded.
- Encrypted schema artifact was checksum-verified and decrypted only inside an ephemeral GitHub Actions runner.
- Sanitized inventory artifact: `krim-sanitized-schema-review`, run `42622968711` (an updated inventory run was triggered after removing an unreliable text-only heuristic).

## Direct PostgreSQL catalog findings

### SECURITY DEFINER inventory
| Schema | SECURITY DEFINER functions | Without function-level config | Without search_path config | Executable by anon | Executable by authenticated |
|---|---:|---:|---:|---:|---:|
| graphql_public | 0 | 0 | 0 | 0 | 0 |
| krim_internal | 82 | 0 | 0 | 0 | 0 |
| private | 35 | 0 | 0 | 0 | 21 |
| public | 307 | 0 | 0 | 0 | 126 |

The direct `pg_proc.proconfig` check is authoritative for this point: all 424 SECURITY DEFINER functions in the reviewed schemas have a function-level `search_path` configuration. The first text-only scanner's inline-definition heuristic incorrectly flagged these because it did not associate separate ALTER FUNCTION configuration statements; that heuristic was removed from the report generator.

No reviewed SECURITY DEFINER function was executable by `anon`. 126 public and 21 private SECURITY DEFINER functions were executable by `authenticated`; this is an API surface that still requires function-by-function authorization review. SECURITY DEFINER is not itself a vulnerability, but every callable function must enforce the intended user, organization, permission, and MFA boundaries.

### Public table RLS
- Public tables/partitioned tables: 378
- RLS enabled: 378
- RLS disabled: 0
- RLS forced: 35
- RLS-enabled tables with no policies: 21
- All 21 tables with no policies had no table-level SELECT/INSERT/UPDATE/DELETE privileges for either `anon` or `authenticated` in the inspected privilege checks.

The 21 no-policy tables are therefore not currently exposed through those direct client table grants. Keep them restricted; do not add blanket policies. Their ownership and intended service-only access should be documented and verified separately.

### Targeted SECURITY DEFINER call-chain review
Reviewed the candidate public RPCs that did not contain a direct `auth.uid()`, `auth.jwt()`, or permission-helper token in their own source:
- Partner capacity registration delegates to an underlying routine that requires authenticated user, active organization membership, `partner.manage`, registered/compliant partner status, verified capability coverage, and evidence paths under the caller's private organization folder.
- Partner service-capability submission delegates to an underlying routine that requires authenticated user, `partner.manage`, active registered-business partner organization, current compliance, active transport mode/country, and caller-owned evidence paths.
- Lane-aware admin capacity listing delegates to an admin listing routine that requires authenticated user, AAL2 MFA, and `admin.platform`.
- Vehicle administration RPCs call `krim_vehicle_admin_guard()`, which requires authenticated user, AAL2 MFA, and `admin.platform`. The guard itself is not executable by anon or authenticated directly in the inspected ACL check.

This was a targeted call-chain review, not a complete review of all 147 SECURITY DEFINER functions executable by authenticated across public/private schemas.

## Sanitized export scan
The ephemeral inventory scanner reported no matches for the specific credential markers it checks (provider-key prefixes, JWT-like literals, private-key headers, and a narrow quoted credential-assignment pattern). This is only a pattern-based precaution and is not proof that the schema contains no sensitive literals. Manual offline review remains required.

## Remaining gates
1. Review the remaining authenticated-executable SECURITY DEFINER functions and their full call chains.
2. Review view security modes, grants, default privileges, and storage policies.
3. Reconcile the production migration ledger with the incomplete repository migration history.
4. Build a reviewed staging baseline from the sanitized schema, not by replaying incomplete migrations.
5. Run synthetic authenticated positive/negative tests in isolated staging before enabling mobile writes.

## Decision
Production remains untouched. Do not import the export into staging yet. Do not enable customer bookings, partner quotations/assignments, driver trip-event writes, POD uploads, payouts, or partner onboarding until the remaining security and staging gates pass.
