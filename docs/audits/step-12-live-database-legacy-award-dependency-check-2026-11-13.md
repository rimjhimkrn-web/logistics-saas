# KRIM Customer Journey — Step 12: Live Database Dependency Check for Legacy Checkout Award RPC

**Audit date:** 2026-11-13  
**Disposition:** **DATABASE-INTERNAL DEPENDENCY CHECK PASSED — EXTERNAL/API DEPENDENCY AND SAFE RETIREMENT STILL BLOCKED.**

## Read-only production catalog results

Inspected the production database project using read-only catalog queries for the exact deployed routine:

`public.krim_award_partner_quote_for_checkout(p_partner_quote_id bigint, p_valid_until timestamp with time zone)`

Confirmed:
- Function exists in `public`.
- It is `SECURITY DEFINER`.
- Owner is `postgres`.
- `authenticated` has EXECUTE.
- `service_role` has EXECUTE.
- No other stored function source in the inspected `pg_proc.prosrc` catalogue textually references this function.
- No direct `pg_depend` function dependency was returned for this target.
- No trigger definition text references this function.

These results narrow the risk: no direct database-internal caller or trigger dependency was identified by these catalog checks.

## Important limitations

PostgreSQL does not reliably track dependencies embedded in every PL/pgSQL/dynamic SQL body, and catalog text scans do not prove absence of:
- external clients calling the exposed RPC through PostgREST;
- Edge Functions or deployed code outside the repository branch;
- generated/minified bundles or stale app versions;
- third-party integrations or operator scripts;
- dynamic SQL assembled at runtime.

The routine remains callable by authenticated users. The previous Step 4/5 function-body inspection found that it can create an offered assignment and mark a customer quote accepted before partner acceptance. That is still incompatible with the approved partner-direct lifecycle.

## Decision

Do **not** revoke or replace the function in production yet. Before a retirement migration:
1. Complete a full repository and deployment-artifact scan for the RPC name and related wrapper names.
2. Review Edge Function deployments and any external integrations.
3. Confirm the routine's complete deployed body and all overloads, owners, ACLs and grants, including inherited PUBLIC privileges.
4. Provision migration-parity staging; current staging is empty.
5. Test the replacement canonical partner-acceptance transaction and legacy-call failure behavior.
6. Then add a migration that makes the legacy public RPC fail closed or revokes authenticated EXECUTE, retaining only narrowly justified private internal execution if needed.

## Safety boundary

Only read-only production catalog queries and branch documentation were used. No function body, grants, migration history, records, partner assignments, quotes, shipment statuses, payments, merge or deployment were changed.

## Exit decision

**Step 12 complete.** No database-internal function or trigger dependency was found by the checks performed. The RPC remains an exposed authenticated SECURITY DEFINER endpoint; production retirement is not approved until external dependency checks and migration-parity tests pass.
