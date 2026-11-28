# KRIM partner / driver RPC production–staging parity check — 2026-11-24

## Scope and method
Read-only catalog inspection on:
- Production project `ebltviniygljwwseplph`
- Staging project `qrpcivhdxobiaofppbkl`

Compared function signatures, SECURITY DEFINER flags, normalized function-definition MD5 values from `pg_get_functiondef`, and effective EXECUTE privileges for `anon`, `authenticated`, and `service_role`.

No SQL was applied. No data or grants were changed.

## Function-definition comparison

| Signature | Production MD5 | Staging MD5 | Exact match? |
|---|---|---|---|
| `private.krim_partner_capability_covers_shipment(bigint,bigint)` | `4d5b3e0452bb0d83e5aa73f6d16bf16a` | `adf44a8651cbbcec70b92fe486aa4c6f` | No |
| `public.krim_admin_list_driver_verification_cases()` | `02c62748d539e56f58a22c1625ca9313` | `02c62748d539e56f58a22c1625ca9313` | Yes |
| `public.krim_admin_review_driver_verification(uuid,text,text)` | `f3a44b535d5064169e56c1095d69db50` | `f3a44b535d5064169e56c1095d69db50` | Yes |
| `public.krim_assign_driver_to_partner_shipment(bigint,uuid)` | `ab3333bd0d5044b118e80ebea7900edc` | `ab3333bd0d5044b118e80ebea7900edc` | Yes |
| `public.krim_award_partner_quote(bigint)` | `e0874bf1f9d952ee0cda461786f77678` | `e7c1d50e2cef487751f8bac30364518b` | No |
| `public.krim_list_dispatchable_drivers(bigint)` | `3824dad50dff8adebaa195a910b0a6ff` | `23b304d77cbd112ebbee42785a08dafa` | No |
| `public.krim_respond_to_partner_assignment(bigint,boolean,text)` | `e3be9e6d3bd539e4f6c5fa15365bb361` | `1b7409ec80210819508ea5b41ff97079` | No |
| `public.krim_submit_partner_quote(bigint,numeric,text,timestamptz,text)` | `bf96fd4c59acb3974df74e27adea42e1` | `84b3d5c1f4cb3b3e19754757ea61f808` | No |

All eight routines are SECURITY DEFINER in both environments and have an explicit empty search_path setting. Three exact body matches and five body mismatches are confirmed. A hash mismatch is a review trigger, not proof of a defect; each differing body requires a semantic diff before any forward migration is prepared.

## Effective EXECUTE privilege comparison

| Signature | Production anon/authenticated/service_role | Staging anon/authenticated/service_role |
|---|---|---|
| `private.krim_partner_capability_covers_shipment(bigint,bigint)` | no / yes / no | no / no / yes |
| `public.krim_award_partner_quote(bigint)` | no / no / yes | no / no / yes |
| `public.krim_list_dispatchable_drivers(bigint)` | no / yes / yes | no / yes / yes |
| `public.krim_respond_to_partner_assignment(bigint,boolean,text)` | no / yes / yes | no / yes / yes |
| `public.krim_submit_partner_quote(bigint,numeric,text,timestamptz,text)` | no / yes / yes | no / no / yes |

## Release implications

1. `krim_submit_partner_quote` has a confirmed production/staging EXECUTE mismatch: authenticated users can execute in production but not staging. Before proposing a grant, verify the actual partner browser call path and whether the app intentionally routes this action through a trusted server/Edge Function. Do not grant solely to make staging resemble production.
2. The private capability helper has the opposite mismatch. Keep it internal unless a documented direct client caller is found; production's authenticated EXECUTE grant is not automatically a desired security posture.
3. `krim_award_partner_quote` is service-role-only in both environments. Do not widen it without a verified authorized caller path.
4. Four function bodies differ (helper, award, dispatchable-driver list, assignment response, quote submission); compare full source definitions and migration history before declaring parity.
5. The three exact body matches are positive parity evidence for those signatures only, not a complete driver/partner sign-off.

## Safe next actions
- Trace every browser/Edge Function call site for the five differing functions and record caller identity.
- Compare full production/staging function definitions in a dedicated diff, including branch-specific capacity reservation and multi-leg conditions.
- Map the definitions to exact migration history and source commits.
- Build isolated SQL positive/negative tests for partner tenant isolation, route capability, current compliance, driver evidence, multi-leg assignment, and quote lifecycle.
- Prepare a forward-only staging repair only after the call path and intended ACL are approved. Keep production untouched.

## Decision
**No grants or function definitions changed.** This audit adds a focused, verified parity gate to the staging readiness backlog; it does not authorize staging or production writes.
