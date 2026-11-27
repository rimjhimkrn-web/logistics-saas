# KRIM Workflow and Webhook Alternate Runtime Inventory — 2026-11-27

## Audit boundary
Read-only audit against Staging Supabase project `qrpcivhdxobiaofppbkl`. No Production access, SQL writes, migrations, worker invocations, deliveries, or fixture records.

## 1. Important discovery: two workflow execution designs coexist
In addition to the active public workflow runtime, Staging contains a second queue/lease architecture in schema `krim_internal` that also reads/writes the same public workflow tables.

Observed internal functions include:
- `dispatch_event_to_workflow(bigint,text)`
- `create_event_workflow_dispatch(bigint,bigint,text,bigint,text)`
- `claim_workflow_queue_item(text,integer)`
- `execute_workflow_queue_item(bigint,text)`
- `process_workflow_queue_item(bigint,text,jsonb,text,text)`
- `approve_and_queue_workflow_dead_letter_replay(bigint,uuid,text)`
- `process_dead_letter_replay(bigint,uuid,text)`
- `request_workflow_dead_letter_replay(...)`
- `transition_workflow_action(...)` overloads
- `transition_workflow_dispatch(...)`
- `transition_workflow_run(...)`
- `finalize_workflow_action_result(...)`
- `propagate_workflow_run_after_action(...)`
- workflow queue lease heartbeat/release and concurrency-lock helpers
- multiple quarantine/replay helpers.

These functions use `krim_workflow_queue_leases`, action result tables and shared workflow tables. They are SECURITY DEFINER and the inspected ACLs grant EXECUTE to postgres/service_role, not anon/authenticated. They have not been proven unreachable. Their existence means a migration that only updates the currently scheduled public runtime would leave alternate privileged processing paths potentially capable of operating on test rows.

## 2. Scheduler and deployed Edge Function inventory
Staging cron catalog currently has two active jobs:
- `krim-workflow-runtime-staging` every minute: public workflow runtime batch.
- `krim-capacity-hold-expiry-staging` every minute: capacity hold expiry.

Staging Edge Functions currently listed:
- `krim-phase00-test-user-invites` (JWT required)
- `krim-resend-email-worker` (JWT not required)
- `owner-testing-authorize` (JWT required)
- `global-admin-control` (JWT required)
- `krim-phase00-provision-test-organizations` (JWT required)

No dedicated workflow queue worker Edge Function appeared in this deployed list. This does not prove there are no external/manual service-role callers; repository and deployment configuration callsites still need review.

## 3. Webhook delivery findings
- `public.krim_internal_enqueue_event_webhook_deliveries(bigint,text)` reads an event and active endpoint subscriptions, then inserts pending rows into `krim_webhook_deliveries`.
- It is SECURITY DEFINER; inspected ACL is postgres/service_role only.
- Database routine source scan found no SQL routine directly calling this enqueue routine.
- Webhook completion/retry helpers exist in `krim_internal`: `complete_webhook_delivery`, `schedule_webhook_retry`, `record_webhook_endpoint_result`.
- No public webhook-table triggers were returned by the targeted trigger catalog query.
- Therefore external callers, Edge Function source, repository callers and any scheduled HTTP workers remain unverified. The test lane must fail closed in the enqueue function itself and in any delivery worker, not rely on the workflow dispatcher.

## 4. Event producer expansion
In addition to shipment/partner/driver lifecycle trigger writers, the routine source scan found an inquiry follow-up scheduler that inserts an internal customer-inquiry event and a founder notification outbox record. The public contact inquiry submission routine also writes event/outbox data. These are not automatically workflow test events, but reinforce that `krim_events` is a shared operational event bus with multiple ingress paths.

## 5. Migration blocker
Do not apply a lane migration yet. The coexistence of:
- public workflow runtime,
- alternate `krim_internal` queue/lease runtime,
- several replay/quarantine pathways,
- event notification/email triggers,
- webhook delivery helpers,
means the full privileged call graph and intended active architecture must be resolved first.

Required next steps:
1. Search the Staging branch repository for every alternate runtime function name, queue table, webhook function and RPC invocation.
2. Inspect source for the five deployed Edge Functions, especially email worker and owner/global admin endpoints, for service-role RPC calls or webhook delivery.
3. Inspect all cron jobs, pg_net/net/http jobs, Vault-backed scheduled requests and external scheduler configuration available in the project.
4. Establish which workflow architecture is canonical; document whether the other is disabled, legacy, or still callable. Do not revoke/drop functions without impact analysis and explicit approval.
5. Build a complete privilege/caller matrix before implementing lane isolation across both architectures.

## 6. Current status
- Additional privileged alternate workflow runtime discovered.
- Webhook enqueue routine has no SQL routine caller in inspected source scan; external callers are not yet established.
- Email worker remains deployed without JWT; its authorization and event-lane protections need source audit.
- No migrations, writes, fixture events, webhook deliveries, or worker invocations.
- Production untouched.
- Phase 00 OPEN — NOT APPROVED; Phase 01 not authorized.
