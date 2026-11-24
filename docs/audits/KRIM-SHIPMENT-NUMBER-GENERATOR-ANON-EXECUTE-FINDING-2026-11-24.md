# KRIM shipment-number generator anonymous EXECUTE finding — 2026-11-24

## Severity and status
**Status: confirmed privilege exposure; proposed fix prepared, not applied.**
This is a focused catalog finding. Production database is unchanged.

## Evidence from production catalog
- `public.generate_krim_shipment_number()` is a normal invoker PL/pgSQL scalar function, not a trigger function and not SECURITY DEFINER.
- It returns a new `KRIM-YYYY-########` value by calling `nextval('public.krim_shipment_number_seq')`.
- The function is the column default for `public.krim_shipments.shipment_number`.
- The current ACL explicitly grants EXECUTE to `PUBLIC`, `anon`, `authenticated`, `service_role` and `postgres`.
- The sequence currently grants anon USAGE and UPDATE, as well as authenticated and service_role.
- No trigger depends on this function; it is the shipment-number column default.

## Impact
An anonymous caller with RPC execution access can invoke the generator and advance the shipment-number sequence without creating a shipment. This allows sequence consumption/number gaps and can interfere with predictable operational numbering. It does not by itself create or access shipment rows, but the function exposes a mutation that anonymous callers do not need.

## Proposed least-privilege fix
Prepared but **not applied**:
`docs/proposed-migrations/20261124_restrict_public_shipment_number_generator.sql`
- Revoke EXECUTE from PUBLIC and anon.
- Preserve EXECUTE for authenticated and service_role, required for normal shipment inserts/default evaluation.
- Revoke anon sequence privileges; preserve authenticated/service_role sequence privileges.
- Include transactional SQL and a regression assertion file:
  `tests/sql/shipment-number-generator-acl-assertions.sql`

## Verification required before release
1. Apply only to isolated staging after migration baseline reconciliation.
2. Confirm anon cannot execute the function or advance the sequence.
3. Confirm authenticated and service_role retain function and sequence privileges.
4. Run a normal authenticated shipment insert and verify the default shipment number is generated successfully.
5. Run existing shipment create/quote/assignment workflows and rollback synthetic data.
6. Re-run Supabase security advisors and inspect effective ACLs.

## Related observations
Other functions with anon EXECUTE in the shipment query were trigger functions (`calculate_shipment_margin`, `krim_assign_active_market_to_location`, `validate_shipment_status_transition`) or not SECURITY DEFINER. PostgreSQL trigger functions cannot be invoked as ordinary scalar RPCs. Their grants should still be checked against trigger ownership/creation requirements, but this audit does not classify them as the same exposure.

## Decision
Do not apply directly to production. Keep PR #245 draft until this ACL change is staged and verified and broader migration/security gates are cleared.


## Production/staging comparison and least-privilege refinement
A second read-only comparison confirmed:
- Production: anon, authenticated and service_role can execute the generator; anon and authenticated have sequence USAGE/UPDATE.
- Staging: only service_role can execute the generator; only service_role has sequence USAGE/UPDATE.
- Both environments deny direct INSERT on `public.krim_shipments` to anon/authenticated and grant INSERT to service_role.

The proposed migration and assertions were refined to match the actual service-role-only shipment insertion model. It now removes EXECUTE and sequence privileges from PUBLIC, anon and authenticated, while preserving service_role. This avoids granting authenticated users a capability they do not need.


## Wider anonymous-function scan
A read-only production scan of all ordinary functions in the exposed `public` schema that anon can execute, excluding functions attached to triggers, returned exactly one function: `generate_krim_shipment_number()`. It is the sequence-consuming function described above. The other anon-executable functions seen in the focused shipment scan were trigger functions; trigger functions are not ordinary RPC endpoints.
This scan is limited to `public` ordinary functions and does not claim that all schemas, views, operators or storage policies have been audited.
