# KRIM partner / driver RPC semantic feature matrix — 2026-11-24

## Scope
Read-only comparison of production project `ebltviniygljwwseplph` and staging project `qrpcivhdxobiaofppbkl`. Compared normalized function-definition MD5 values and presence of selected safety/eligibility feature markers in five SECURITY DEFINER routines. This is a targeted source-feature inventory, not a full semantic equivalence proof.

No SQL, data, grants, function definitions, or migration ledgers were changed.

## Feature matrix

| Routine | Production MD5 | Staging MD5 | Current compliance check | Exact-leg capability | Capacity binding check | Multi-leg guard | Permission gate |
|---|---|---|---|---|---|---|---|
| private.krim_partner_capability_covers_shipment(bigint,bigint) | 4d5b3e0452bb0d83e5aa73f6d16bf16a | adf44a8651cbbcec70b92fe486aa4c6f | neither | neither | neither | neither | neither |
| public.krim_award_partner_quote(bigint) | e0874bf1f9d952ee0cda461786f77678 | e7c1d50e2cef487751f8bac30364518b | neither | neither | neither | both | both |
| public.krim_list_dispatchable_drivers(bigint) | 3824dad50dff8adebaa195a910b0a6ff | 23b304d77cbd112ebbee42785a08dafa | neither | neither | neither | neither | both |
| public.krim_respond_to_partner_assignment(bigint,boolean,text) | e3be9e6d3bd539e4f6c5fa15365bb361 | 1b7409ec80210819508ea5b41ff97079 | both | both | staging only | both | both |
| public.krim_submit_partner_quote(bigint,numeric,text,timestamptz,text) | bf96fd4c59acb3974df74e27adea42e1 | 84b3d5c1f4cb3b3e19754757ea61f808 | staging only | neither | neither | both | both |

Additional inspected markers:
- All five functions have explicit empty search_path settings and SECURITY DEFINER in both environments.
- Verification and registered-business checks are present in both versions of award, dispatchable-driver listing, assignment response and quote submission.
- The capability helper includes verified capability checks in both environments; its route/weight/region implementation differs and needs a full semantic diff.
- The assignment-response staging definition includes a capacity-binding check not detected in the production definition.
- The staging quote-submission definition includes a current-compliance check not detected in production.
- The production assignment-response definition includes exact-leg and multi-leg validation markers; staging also includes these and adds capacity-binding validation.
- Marker detection is case-insensitive substring inspection of pg_get_functiondef. It does not prove control-flow reachability, equivalent semantics, or correct business behavior.

## ACL findings retained from the companion parity audit
- `krim_submit_partner_quote`: authenticated EXECUTE allowed in production, denied in staging; anon denied in both; service_role allowed in both.
- `private.krim_partner_capability_covers_shipment`: authenticated EXECUTE allowed in production, denied in staging; anon denied in both; service_role allowed in both.
- `krim_award_partner_quote`: service_role-only in both.
- `krim_list_dispatchable_drivers` and `krim_respond_to_partner_assignment`: authenticated and service_role allowed, anon denied in both.

## Required next implementation work
1. Recover and compare the complete production/staging definitions for all five routines, especially the capability helper, award, dispatchable-driver list, assignment response and quote submission.
2. Trace actual frontend and Edge Function call sites for every RPC and identify the caller's JWT role. GitHub code search on the repository default branch did not return these symbols; this is inconclusive and is not evidence that callers do not exist. Inspect the exact PR branch source and relevant Edge Function directories before changing ACLs.
3. Build PostgreSQL 16 isolated positive and negative tests for verified partner eligibility, cross-tenant quote submission, active capability route/weight coverage, exact-leg assignment, capacity binding, driver verification and quote award lifecycle.
4. Reconcile each function's source to recovered migration history before any staging change. Do not copy production definitions over staging or change grants based only on MD5/feature markers.
5. Keep production untouched. Apply only reviewed forward-only staging corrections after the migration baseline is reconciled.

## Decision
**No database change is authorized by this audit.** Staging and production contain meaningful implementation differences. The staging assignment-response and quote-submission definitions show additional controls by marker inspection, so blindly copying production would risk removing safeguards. The correct next step is full source/control-flow review plus caller tracing and isolated behavior tests.
