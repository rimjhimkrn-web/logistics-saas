# KRIM Workflow Runtime and Quote-Acceptance Dependency Audit — 2026-11-27

## Scope and environment
Read-only inspection of KRIM Staging Supabase project `qrpcivhdxobiaofppbkl` and branch `staging/phase00-env-isolation`. Production project was not accessed. No database, application, or Edge Function changes were made.

## Verified runtime topology
Two active pg_cron jobs were returned:
- Every minute: `public.krim_internal_process_workflow_runtime_batch('krim-db-cron', 25, 50, 25)`.
- Every minute: `public.krim_internal_expire_capacity_holds(200)`.

The runtime batch orchestrates event processing, workflow dispatch materialization, dead-letter replay processing/synchronization, action batch processing, and workflow-run reconciliation. It uses bounded batches and `FOR UPDATE SKIP LOCKED` in its event/dispatch selection paths; dispatch and action failures are retried and eventually dead-lettered.

## Registry and fixture state
A direct count query returned:
- `krim_events`: 0
- `krim_workflows`: 0
- `krim_workflow_triggers`: 0
- `krim_workflow_runs`: 0
- `krim_workflow_action_executions`: 0
- `krim_event_workflow_dispatches`: 0

Therefore the runtime is scheduled but no configured workflow registry or operational event/action fixture exists in Staging. No handler can be proven end-to-end from live records in this environment.

## Handler / action registry findings
The event-to-workflow dispatcher matches active workflow triggers against event type, organization scope, and JSONB payload containment. It creates idempotent dispatch records keyed by event and trigger, then marks the source event processed with a no-match/matched outcome.

The action executor is a hard-coded allowlist, not dynamic SQL:
- `record_workflow_checkpoint`
- `create_exception_case`
- `evaluate_delay_risk`

Notification action names `prepare_customer_notification` and `prepare_partner_notification` deliberately fail as unsupported because there is no verified record-enqueue handler. Unknown action types also fail and are quarantined through the batch processor. This is a positive fail-closed behavior; notification delivery remains unverified and unavailable through this workflow executor.

No dynamic SQL execution path was identified in the inspected dispatcher/action executor definitions. This is a bounded finding for those functions, not a claim that the entire database has no dynamic SQL.

## SECURITY DEFINER and grants
The inspected internal runtime functions are SECURITY DEFINER and set `search_path=public, pg_temp`:
- `krim_internal_process_workflow_runtime_batch(text,integer,integer)`
- `krim_internal_dispatch_event_to_workflows(uuid)`
- `krim_internal_execute_workflow_action(bigint,uuid)`
- `krim_internal_process_workflow_action_batch(text,integer,integer)`

Their observed ACLs grant EXECUTE to postgres and service_role only; authenticated and anon were not present in the returned ACLs. This limits direct API invocation, but the mutable `public, pg_temp` search path remains a hardening concern. Before changing it, review all unqualified object references and function dependencies; do not apply a blind search_path replacement.

## Quote acceptance and assignment dependency
`public.krim_accept_global_quote(bigint)` is SECURITY DEFINER with an empty search_path. Its observed ACL grants EXECUTE to authenticated and service_role, not anon. It:
1. Locks the quote and shipment.
2. Requires authenticated organization access and `shipment.update`.
3. Requires a matching accepted partner quote and accepted assignment, an active/verified/compliant partner, verified capability, shipment coverage, and current compliance.
4. Transitions the shipment to confirmed, invokes `krim_internal_finalize_partner_assignment`, updates the accepted quote version, and records customer acceptance evidence.
5. Explicitly records direct customer-to-provider freight payment and `krim_collects_freight_payment=false`.

The finalizer validates the exact shipment leg, assignment partner, confirmed capacity binding, reservation and commitment. Its multi-leg path joins active plan items to exact operational legs and assignments. However, it does not yet use a route-generation identity because that schema does not exist. The quote-acceptance path therefore remains a route-generation migration dependency. Full end-to-end helper verification is still open; this audit did not execute the quote acceptance function.

## Required follow-up / blockers
1. Create controlled workflow registry and event fixtures only through approved application workflows; do not insert arbitrary operational business records to make the worker appear tested.
2. Add a safe test harness for the three supported action types and verify retry, lease expiry, idempotency, dead-letter quarantine, and replay under authenticated/service-role boundaries.
3. Implement a verified notification enqueue handler and delivery worker before enabling notification actions.
4. Harden internal SECURITY DEFINER search paths after dependency/unqualified-reference review.
5. Extend quote acceptance/finalization, workflow dispatch/action context, and event payloads to carry immutable route-generation identity.
6. Do not activate route-generation schema migration until all operational writers/readers and legacy reconciliation rules are inventoried and rehearsed.

## Result
This is a documentation-only checkpoint. No migration, deployment, test fixture, quote acceptance, shipment mutation, or notification was executed. Phase 00 remains OPEN — NOT APPROVED; Phase 01 is not authorized.
