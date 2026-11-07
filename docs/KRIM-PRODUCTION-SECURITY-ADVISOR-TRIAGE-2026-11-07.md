# KRIM Production Security Advisor Triage — 2026-11-07

Read-only snapshot of the connected production project. No schema, grants, rows, functions, or secrets were changed.

## Advisor snapshot

- Supabase security advisor reports 26 RLS-enabled tables with no policies.
- Supabase advisor reports 126 SECURITY DEFINER functions callable by the authenticated role.
- Read-only ACL query across `public` and `private` found:
  - `public`: 307 SECURITY DEFINER functions; 126 executable by authenticated; 0 executable by anon; 0 with PUBLIC EXECUTE.
  - `private`: 35 SECURITY DEFINER functions; 21 executable by authenticated; 0 executable by anon; 0 with PUBLIC EXECUTE.
- Performance advisor reports five tables with multiple permissive SELECT policies and one duplicate-index finding on `krim_capacity_reservations`.

## RLS-without-policy triage

A read-only privilege check found that every RLS-enabled, no-policy table in the `public` schema has no direct SELECT, INSERT, UPDATE, or DELETE privilege for either `anon` or `authenticated`. The five private application tables flagged by the advisor likewise have no direct privileges for those roles.

The advisor also enumerates Supabase-managed `auth`, `storage`, and `realtime` relations. Do not change Supabase-managed schema permissions or policies as part of application cleanup.

Interpretation: the current public application tables flagged by this particular rule are deny-by-default for the client roles based on both missing policies and missing table grants. They still need an owner/intent inventory, but this finding alone is not evidence that client data is exposed. Do not add broad policies just to silence the advisor.

## SECURITY DEFINER triage

The 126 authenticated-callable public SECURITY DEFINER functions require function-by-function review of:
- authentication and role/org membership checks;
- object-level authorization for the exact requested record;
- validation of state transitions and immutable ownership fields;
- safe `search_path` and fully qualified object references;
- sensitive return values and error messages;
- whether the function is actually required by a client.

Do not blanket-revoke EXECUTE from authenticated: some functions are intentional, permission-checked RPCs used by the application. Prioritize write/approval/payment/admin functions, then read RPCs that return sensitive data. Keep anon and PUBLIC execution denied.

## Performance triage

- Review the five duplicate permissive SELECT-policy pairs for semantic equivalence before consolidating. Multiple permissive policies are OR-combined; careless consolidation can change access.
- Review the duplicate indexes on `krim_capacity_reservations` using index definitions, constraints, and usage history before dropping either one. Do not drop an index solely from the advisor message.
- Unused-index findings are not sufficient reason to remove indexes from a young or low-traffic platform.

## Required follow-up

1. Create an owner-reviewed inventory of the 126 public SECURITY DEFINER RPCs and their authorization contracts.
2. Verify admin-only RPCs deny ordinary authenticated users using negative tests in staging.
3. Confirm each public no-policy table is intentionally inaccessible, and record its owner/system purpose.
4. Review the five permissive policy pairs and duplicate index in staging.
5. Re-run advisors after any approved remediation.

## Release implication

This snapshot is not a full security certification. It confirms there are no advisor-detected anon/PUBLIC EXECUTE grants on the reviewed SECURITY DEFINER functions and no client table grants on the public no-policy tables. It does not prove every authenticated SECURITY DEFINER function is correctly authorized. Production public launch remains NO-GO until the high-impact RPC authorization review and staging tests pass.
