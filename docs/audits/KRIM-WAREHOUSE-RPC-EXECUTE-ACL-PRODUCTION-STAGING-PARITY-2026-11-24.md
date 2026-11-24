# KRIM warehouse RPC EXECUTE ACL production/staging parity finding — 2026-11-24

## Scope and method
Read-only catalog inspection in production project `ebltviniygljwwseplph` and isolated staging project `qrpcivhdxobiaofppbkl`. For selected SECURITY DEFINER functions, compared `pg_proc.proacl` and effective `has_function_privilege(role, function_oid, 'EXECUTE')` for `anon`, `authenticated` and `service_role`. No grants or schema were changed.

## Verified result

| RPC family / representative functions | Production authenticated EXECUTE | Staging authenticated EXECUTE | anon EXECUTE |
|---|---:|---:|---:|
| Driver accept / trip event / delivery POD | Yes | Yes | No |
| Warehouse task list | Yes | No | No |
| Warehouse evidence registration | Yes | No | No |
| Warehouse task transition | Yes | No | No |
| Warehouse task creation | Yes | No | No |
| Warehouse facility registration | Yes | No | No |

Staging warehouse RPCs in the inspected SECURITY DEFINER family are granted to `service_role` and postgres, but not `authenticated`. Production has explicit `authenticated` EXECUTE grants for the representative warehouse functions above. This is a real environment parity mismatch, not merely a source-code difference.

The reviewed warehouse function bodies include `auth.uid()` and facility/operator authorization checks. However, those checks are only exercised when a caller can execute the RPC. The production grant does not itself prove the whole browser-to-database workflow is safe, and the staging denial does not prove the UI is correctly mediated through an Edge Function.

## Required next work
1. Trace all warehouse UI call sites and any Edge/server functions to establish the intended call path.
2. If browser clients are intended to call these RPCs directly, verify every function's actor, organization, facility, evidence ownership and input checks, then add only the exact required staging grants via a reviewed migration and test both allowed and denied users.
3. If a trusted Edge/server mediation layer is intended, keep browser EXECUTE denied and prove the Edge Function authenticates the caller, derives identity from verified JWT context, enforces membership/facility scope, never trusts caller-supplied user IDs, and returns only scoped data.
4. Reconcile the production/staging ACL difference through the migration ledger before changing either environment. Do not bulk grant or revoke based only on this snapshot.
5. Add staging tests for authorized warehouse operator success, foreign organization/facility denial, foreign task transition denial, and foreign evidence object rejection.

## Release impact
Warehouse authenticated-user workflow readiness is not signed off. Keep PR #245 draft. Do not apply broad grants or alter production ACLs until the intended call path and historical migration state are understood.

## Evidence boundaries
This finding records effective ACL state at the time of inspection. It does not establish whether the frontend uses RPC directly or a trusted server-side wrapper, and it does not replace dynamic RLS/tenant tests.


## Frontend call-path trace — confirmed direct browser RPC calls
Inspected the current branch's warehouse pages and confirmed the browser uses the Supabase publishable client directly for warehouse operations, rather than routing these calls through a server/Edge Function:
- `public/warehouse/facility-management.html` calls `krim_warehouse_register_facility` through `c.rpc(...)`.
- `public/warehouse/goods-receipt.html` calls `krim_warehouse_list_tasks`, `krim_warehouse_transition_task`, `krim_warehouse_create_linked_goods_receipt_task` and `krim_warehouse_list_assigned_shipment_legs` directly through `c.rpc(...)`.
- `public/warehouse/inbound-receiving.html` calls `krim_warehouse_list_tasks`, `krim_warehouse_transition_task`, `krim_warehouse_create_linked_inbound_task` and `krim_warehouse_list_assigned_shipment_legs` directly through `c.rpc(...)`.
- `public/warehouse/dispatch-handover.html` calls `krim_warehouse_list_tasks`, `krim_warehouse_transition_task`, `krim_warehouse_create_linked_handover_task` and `krim_warehouse_list_assigned_shipment_legs` directly through `c.rpc(...)`.

Therefore the staging service_role-only ACLs for these user-facing warehouse RPCs are not consistent with the current browser implementation. The pages are expected to fail with permission denied in staging unless an alternate grant path exists. Do not work around this by exposing service_role keys in the browser. The next safe fix is a narrowly scoped staging migration that grants EXECUTE only on the user-facing RPCs whose full function bodies have been verified to derive the actor from `auth.uid()` and enforce organization/facility authorization, followed by authenticated positive/negative staging tests. Production remains unchanged. The migration-history drift still must be reconciled before any production rollout.


## Follow-up: staging browser execution path and table grants — 2026-11-24

A further read-only pass checked the staging project after tracing the actual current-branch browser pages.

### Direct browser path confirmed
The warehouse pages use the publishable Supabase client in the browser. Examples verified on this branch:
- `public/warehouse/warehouse-evidence.html`: direct `c.rpc("krim_warehouse_list_tasks", ...)`, direct `c.rpc("krim_warehouse_list_evidence", ...)`, browser upload to the private `krim-warehouse-evidence` Storage bucket, then browser-side evidence registration RPC.
- `public/warehouse/goods-receipt.html`: direct RPC calls for assigned shipment legs, task listing, task transition and linked goods-receipt creation.
- `public/warehouse/inbound-receiving.html`: direct RPC calls for assigned shipment legs, task listing, task transition and linked inbound-task creation.
- `public/warehouse/quality-control.html`: direct table SELECTs from `krim_warehouse_tasks` and `krim_warehouse_inventory`, direct evidence-list RPC, direct signed-URL creation, and direct inventory quality-review RPC.

No warehouse-specific Edge Function exists in the staging deployment. The three deployed staging Edge Functions are `global-admin-control`, `krim-resend-email-worker`, and `owner-testing-authorize`; none is a warehouse request adapter. The warehouse browser calls are therefore not being mediated by a warehouse server function in this deployment.

### Staging effective privileges
Catalog checks show all 20 `public.krim_warehouse_*` RPC overloads/functions currently inspected are executable by `service_role`, but not by `authenticated`. This includes task list, evidence list/register, task create/transition, facility registration, inventory review, linked shipment operations and warehouse dashboard functions.

Separately, all 10 warehouse base tables checked have RLS enabled, but effective table-level privileges for `authenticated` are false for SELECT, INSERT, UPDATE and DELETE. RLS policies exist for scoped SELECT, but policies do not themselves grant SQL table privileges. This means a policy cannot make a direct browser table query work without the corresponding GRANT.

### Impact and decision
This is not merely an unproven alternate route: the current warehouse UI directly invokes RPCs and, on the quality-control page, directly queries warehouse tables. In the inspected staging environment those calls are blocked by effective ACLs. No warehouse Edge Function was found to provide the intended mediation path. The current staging warehouse UI is therefore not functionally wired to the deployed database access model.

Do not expose service_role credentials to the browser. Do not bulk grant authenticated access to every warehouse RPC/table. The correct remediation decision remains open between:
1. A narrowly reviewed browser-to-RPC model: grant only the exact browser-required RPC overloads after verifying every function's actor, tenant, facility, evidence and lifecycle checks; add only the minimum read privileges needed for direct table reads, with RLS policies validated; or
2. A trusted warehouse Edge Function adapter: verify JWT with `auth.getUser()`, derive actor from verified token, enforce current membership and facility scope on every action, call only explicitly allow-listed RPCs using user-scoped authorization (never trust caller-supplied user IDs), and return tenant-scoped data. Any service-role use must be paired with complete explicit authorization in the adapter.

Because staging seed/catalogue parity and migration-history reconciliation are still unresolved, neither route was deployed. No production or staging schema, grants, policies, data, or Edge Functions were changed by this review.


## Production ACL baseline confirmed — 2026-11-24

A read-only production comparison now confirms the intended browser access pattern for the warehouse module:

- All 10 `krim_warehouse_*` base tables inspected have RLS enabled and authenticated SELECT privilege in production; authenticated INSERT/UPDATE/DELETE are denied on all 10.
- Of the 20 `krim_warehouse_*` RPC signatures inspected, 19 have authenticated EXECUTE in production. The remaining function, `krim_warehouse_record_movement(...)`, is an internal movement helper and remains service_role-only.
- In staging, all 10 inspected tables have authenticated SELECT/INSERT/UPDATE/DELETE denied, and all 20 inspected warehouse RPCs have authenticated EXECUTE denied; service_role retains EXECUTE on the functions.

This confirms a consistent production model: browser users receive RLS-filtered read access to warehouse tables and invoke only the intended authenticated, actor-checking RPCs for writes; internal inventory movement remains unavailable directly to browser users. Staging currently does not match that model.

This is effective-privilege catalog evidence, not a successful browser E2E. It does not justify blindly copying every production grant: the exact frontend-required overloads and RLS predicates still need a reviewed migration, plus authorized same-tenant and denied cross-tenant tests. No grants, policies, data or functions were changed in either environment.


## Warehouse RLS policy parity confirmed — 2026-11-24

Compared normalized `pg_policies` contents (policy name, command, roles, USING expression and WITH CHECK expression) for every `public.krim_warehouse_%` table in production and staging. All 10 table policy hashes match exactly, with one SELECT policy per table in both environments.

The reviewed SELECT predicates are tenant/facility scoped:
- Evidence, inventory, inventory movements, receipts, task events and tasks require an active membership in the row's organization, an active approved facility matching the row's facility, and `private.krim_warehouse_org_eligible(organization_id)`.
- Facilities require active membership in the facility organization plus warehouse organization eligibility.
- Shipment allocations require either `partner.manage` for the allocation organization or `shipment.view` for the shipment's customer organization.
- Transfer quality reviews use `private.krim_warehouse_is_operator(auth.uid(), organization_id, facility_id)`.
- Transfers require operator authorization for the source or destination facility.

This narrows the confirmed environment drift: the ten RLS policy definitions are identical, but staging lacks authenticated table SELECT grants and the exact browser-facing RPC EXECUTE grants present in production. The existing ACL proposal covers only the 14 browser-facing RPC overloads; it intentionally does not grant the internal movement helper. A separate least-privilege table SELECT grant set must be validated against the full browser call-site inventory before staging remediation.

No policy, grant, schema, or data was changed. Hash parity is not a dynamic tenant-isolation test; the staging project still has no synthetic warehouse users, eligible warehouse organizations, approved facilities, or tasks with which to prove same-tenant allow and cross-tenant deny behavior.



## Complete browser table-read call-site inventory and least-privilege proposal — 2026-11-24

Inspected all 32 HTML pages under `public/warehouse/` on this branch and inventoried direct Supabase `.from(...)` calls. The warehouse-owned tables directly read by browser pages are:
- `krim_warehouse_facilities` — facility management and related workspace context.
- `krim_warehouse_inventory` — inventory ledger and quality-control views.
- `krim_warehouse_tasks` — quality-control task detail reads.
- `krim_warehouse_shipment_allocations` — dispatch handover allocation reads.

The facility-management, goods-receipt, inbound-receiving, picking/packing, putaway, damage-exceptions and dispatch-handover pages also read shared organization/member/partner-capability tables; these are not warehouse-owned tables and are not included in the warehouse grant proposal. Evidence storage bucket access is separate from SQL table privileges.

Added `docs/proposed-migrations/20261124_warehouse_browser_table_read_acl.sql`. It grants authenticated SELECT only on the four warehouse tables with direct browser reads, explicitly revokes PUBLIC/anon access and authenticated direct DML, and refuses to proceed if RLS or a SELECT policy is absent. It does not alter RLS policies, grant writes, or modify service_role privileges. This is intentionally narrower than production's current authenticated SELECT grants on all ten warehouse tables.

Extended the isolated PostgreSQL 16 warehouse ACL fixture/assertions/workflow to start from over-permissive grants, apply both exact RPC and table-read proposals, verify authenticated SELECT / anon denial / authenticated DML denial / service_role preservation, and verify tenant filtering under fixture RLS policies. These tests validate the grant mechanics and a synthetic RLS fixture; they do not substitute for dynamic tests against the actual staging policy expressions and real authorized warehouse membership.

No grants, policies, schema, functions, or data were changed in production or staging. Migration-ledger reconciliation remains a hard blocker to applying either proposal to staging. The staging warehouse seed prerequisites and lack of real warehouse test identities/facilities remain unresolved.


## Isolated ACL verification result — 2026-11-24

Commit `62dffade424bc97d1beb0f8f56db8628d563a6ec` completed all nine associated GitHub Actions workflows successfully:
- Warehouse RPC ACL isolated PostgreSQL test (run 45448493233): passed. Steps confirmed fixture creation, exact RPC proposal application, browser table-read proposal application, and ACL/RLS assertions.
- Staging security permission seed isolated test (run 45448493440): passed.
- Static link audit (run 45448493173): passed.
- Production smoke checks (run 45448493210): passed.
- Partner organization selection, shipment-number ACL, notification resolver, shipment notification handoff and workflow-action batch isolated tests: passed.

These are repository CI and isolated database tests. They do not mean the proposed warehouse grants or permission seed have been applied to either Supabase environment, and they do not prove live authenticated warehouse workflows.

## Historical migration source recovery checkpoint — 2026-11-24

Searched GitHub commit history and pull-request metadata for all five missing migration version/name identifiers, then inspected the relevant historical onboarding, verified-audit and automation PR file lists. No exact source SQL for the five missing migrations was recovered from the inspected repository commits/PRs. Later migration files and current database definitions are not valid substitutes for original migration source.

The five missing source files therefore remain unresolved:
- `20260929043657_add_global_partner_lifecycle.sql`
- `20260929044040_add_shipment_partner_assignments.sql`
- `20260929044351_harden_global_notification_delivery.sql`
- `20260929044417_harden_global_workflow_automation.sql`
- `20261011161742_complete_workflow_action_dead_letter_quarantine_and_retry_runtime.sql`

Next recovery source must be the original deployment artifact, archived SQL export, Supabase migration/deployment logs, or the original authoring environment. Until exact source is recovered and checked against production schema/function/policy/ACL state, do not synthesize historical files, edit migration ledgers, reset staging, or replay migrations into populated projects.


## Supabase migration-ledger source check — 2026-11-24

Read-only Supabase MCP migration inventory was retrieved directly from both connected projects.

**Production project** `ebltviniygljwwseplph` is healthy and its migration ledger contains all five previously identified missing version/name entries:
- `20260929043657 / add_global_partner_lifecycle`
- `20260929044040 / add_shipment_partner_assignments`
- `20260929044351 / harden_global_notification_delivery`
- `20260929044417 / harden_global_workflow_automation`
- `20261011161742 / complete_workflow_action_dead_letter_quarantine_and_retry_runtime`

**Staging project** `qrpcivhdxobiaofppbkl` is healthy, but its ledger contains only 34 entries beginning `20261117135137`; it does not contain the September foundational versions above. Its current ledger therefore does not provide an original SQL recovery source.

This confirms the five names/versions are recorded as applied in production, but the migration ledger stores metadata, not the SQL bodies. No migration SQL was recovered by this check. No database changes were made.

**Next recovery route:** obtain the original SQL from the deployment machine/artifact or the source-control commit that executed these migrations. If those artifacts are unavailable, perform a separately reviewed forward-only baseline/reconciliation plan based on exact production schema, function definitions, triggers, policies, grants, extensions and seed data. Do not insert synthetic ledger rows or replay guessed SQL.


## Production-to-staging schema/security baseline comparison — 2026-11-24

Read-only catalog inventories were collected directly from both healthy Supabase projects. Scope: `public`, `private`, and `storage` relations; public/private function signatures and definitions; RLS policies; non-internal triggers; extensions; and Supabase security advisor findings. No database changes were made.

### Structural inventory

| Catalog item | Production | Staging |
|---|---:|---:|
| Relations (tables/views/materialized views/foreign tables) | 408 | 408 |
| Base tables / partitioned tables | 407 | 407 |
| Views/materialized views | 1 | 1 |
| RLS policies in inspected schemas | 438 | 415 |
| Public/private functions | 422 | 435 |
| SECURITY DEFINER functions | 386 | 400 |
| Non-internal triggers | 124 | 126 |
| Extensions | 7 | 5 |
| Relations with RLS disabled | 1 | 0 |

All common table/column definitions in the inspected schemas have matching structural fingerprints (0 common-table column-definition differences). One relation has a security-state difference: `private.krim_driver_invitations` exists in both projects with the same table columns, but production has RLS disabled while staging has RLS enabled. This needs explicit intent review; do not automatically copy either state.

### Object inventory deltas

**Functions**
- Production-only signatures (2): `public.krim_customer_prepare_partner_quote(...)` and `public.krim_report_operational_exception(...)`.
- Staging-only signatures (15): private verified-capacity/service-area helpers, a warehouse dispatch guard trigger function, market-readiness admin list, partner verification information request, driver assignment audit trigger function, location-based shipment creation, resend worker internals, partner dispatch/capacity state and partner resubmission RPCs.
- Twenty shared function signatures have different function-definition hashes.
- One security-critical difference among those is `public.krim_customer_prepare_partner_quote(bigint,timestamptz)`: production is SECURITY INVOKER; staging is SECURITY DEFINER. The same signature is also reported production-only/staging-only in the function security-state inventory because its SECURITY DEFINER attribute differs. This must be investigated as a high-priority parity/security drift; do not assume either body/privilege state is correct without reviewing the full function body and grants.
- The remaining 19 shared function body differences are not yet classified as harmless or behavior/security relevant. They require function-by-function diff and call-site review before any reconciliation.

**Policies**
- Production has 24 storage.objects policies not present in staging, covering scoped customer POD, customs documents/licenses, driver evidence, claims, partner capacity/service-area/verification evidence, and warehouse evidence read/upload/cleanup.
- Staging has one storage.objects policy not present in production: `krim_partner_verification_upload_require_aal2`.
- The 23-policy net difference is concentrated in Storage object authorization, not just ordinary table RLS. Storage policy reconciliation is a release blocker for evidence upload/read workflows. Do not blindly copy production policies; compare bucket names, object path conventions, membership predicates and MFA/evidence lifecycle rules first.

**Triggers**
- Staging has two non-internal triggers not present in production:
  - `public.trg_krim_audit_driver_assignment_acceptance` on `krim_driver_assignments`.
  - `public.trg_krim_require_warehouse_handover_before_shipment_dispatch` on `krim_shipments`.
- No production-only trigger was found in this inspected schema scope. These staging-only triggers may be intentional forward changes, but they must be matched to their source migrations and tested for duplicate effects before release.

**Extensions**
- Production has `pg_cron 1.6.4` and `pg_net 0.20.4`; staging does not.
- Both projects share `pg_stat_statements 1.11`, `pgcrypto 1.3`, `plpgsql 1.0`, `supabase_vault 0.3.1`, and `uuid-ossp 1.1`.
- Since staging lacks pg_cron/pg_net, scheduler and outbound HTTP-dependent workflows cannot be considered equivalent based on schema alone. Verify required jobs, net usage and secret configuration before enabling extensions or migrating scheduled work.

### Security advisor snapshot

Supabase security advisor counts at inspection time:
- Production: 29 `rls_enabled_no_policy` informational findings; 151 `authenticated_security_definer_function_executable` warnings; 1 leaked-password-protection warning.
- Staging: 30 `rls_enabled_no_policy` informational findings; 45 `authenticated_security_definer_function_executable` warnings; 1 leaked-password-protection warning.

The SECURITY DEFINER warning counts are not automatically vulnerabilities: many functions are intentional authenticated RPCs with explicit actor/tenant checks. Each exposed function needs review of body, EXECUTE grants, search_path, input validation and row authorization. The 106-count difference reinforces that staging's callable RPC surface is materially different from production. Leaked-password protection is a common outstanding Auth hardening item in both environments; enablement requires an intentional Auth configuration change and validation.

### Release-blocking conclusions

1. **No wholesale schema replay.** The matching relation counts and common column fingerprints do not mean the projects are functionally equivalent.
2. **Resolve function drift first.** Review the 20 changed shared function bodies, especially the SECURITY INVOKER vs SECURITY DEFINER difference in customer quote preparation, plus the two/15 signature-only deltas.
3. **Resolve storage authorization.** Review the 24 production-only and one staging-only Storage policies against real bucket paths and evidence ownership.
4. **Resolve trigger provenance.** Confirm source migrations and idempotency for the two staging-only triggers.
5. **Resolve extension/runtime parity.** Determine whether staging must host pg_cron/pg_net-backed workflows and, if so, use reviewed enablement and job/secret setup.
6. **Review private driver invitation RLS divergence** and ensure schema/table grants do not accidentally expose the private table through the Data API.
7. **Keep historical migration ledger reconciliation open.** The catalog snapshot is evidence for a forward-only reconciliation plan, not permission to invent old migration files, edit migration ledgers, reset staging, or bulk copy production ACLs.

### Verification boundary

This is a read-only structural and security metadata comparison. It does not compare row data, sequence states, cron job definitions, Vault secrets, Auth provider settings, Storage bucket configuration/objects, Edge Function environment variables, realtime publication membership, or runtime behavior. Those require separate scoped checks. No production or staging data, schema, grants, policies, functions, triggers, extensions or secrets were modified.
