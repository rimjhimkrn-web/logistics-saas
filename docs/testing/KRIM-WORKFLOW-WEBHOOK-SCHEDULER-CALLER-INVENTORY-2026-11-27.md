# KRIM Staging Workflow, Webhook and Scheduler Caller Inventory — 2026-11-27

## Scope
Read-only continuation of the Phase 00 workflow-isolation audit. Target project: Staging `qrpcivhdxobiaofppbkl`. Production was not queried. No cron jobs changed, no queue items claimed, no HTTP requests sent, no webhook or email invoked, no DB writes.

## 1. Active database schedulers
The Staging `cron.job` catalogue currently reports exactly two active jobs:
- `krim-workflow-runtime-staging`, every minute: `public.krim_internal_process_workflow_runtime_batch('krim-db-cron', 25, 50, 25)`.
- `krim-capacity-hold-expiry-staging`, every minute: `public.krim_internal_expire_capacity_holds(200)`.

No email worker or webhook delivery cron job is present in this catalogue. This does not rule out external schedulers, manual service-role invocations, dashboard scheduled functions or infrastructure outside the database.

## 2. pg_net / HTTP scheduler evidence
- `pg_net` extension is installed.
- Current `net.http_request_queue` count: 0.
- Current `net._http_response` count: 0.
- Targeted routine-source scan found no application SQL routine calling `net.http_post`, `net.http_get`, `http_post` or the webhook enqueue routine. The only returned routine was the Supabase extension access-grant helper.
- This is a point-in-time queue/response snapshot, not proof that no external HTTP caller exists.

## 3. Webhook state and ingress
- `public.krim_webhook_endpoints` currently contains 0 rows.
- The event-webhook enqueue function is SECURITY DEFINER and executable by service_role, not anon/authenticated.
- The earlier audit found no public trigger directly attached to webhook delivery tables and no SQL routine caller in the inspected source.
- No webhook endpoint is currently configured in this Staging project. No delivery was attempted.
- External service-role callers and edge-function callers remain unverified.

## 4. Alternate workflow runtime privilege boundary
The following alternate `krim_internal` runtime/replay entry points were confirmed service_role-executable and not executable by anon or authenticated:
- `claim_workflow_queue_item(text,integer)`
- `create_event_workflow_dispatch(bigint,bigint,text,bigint,text)`
- `dispatch_event_to_workflow(bigint,text)`
- `execute_workflow_queue_item(bigint,text)`
- `process_workflow_queue_item(bigint,text,jsonb,text,text)`
- `approve_and_queue_workflow_dead_letter_replay(bigint,uuid,text)`
- `process_dead_letter_replay(bigint,uuid,text)`
- `krim_internal_enqueue_event_webhook_deliveries(bigint,text)`

These are not public client RPCs, but any service-role process can potentially invoke them. Do not assume this alternate runtime is inert solely because it is not in the two cron commands.

## 5. Repository and deployed-function drift
The Staging Git branch directory `supabase/functions` was enumerated. It contains `krim-notification-email-worker`, `krim-notification-retry-worker`, `krim-notification-provider-adapter`, payment handlers and the owner/admin/test fixture functions. The deployed Staging function `krim-resend-email-worker` reviewed in the previous checkpoint is not present under that name in this branch tree.

This is a material source-of-truth mismatch:
- The deployed worker can send real Resend email and claims the shared partner-verification queue.
- The repository contains a differently named notification email worker; its relationship to the deployed worker has not been established.
- Do not redeploy, rename, disable or replace either worker until the source/version relationship and all callers are mapped.

GitHub code search did not return useful results for the alternate runtime symbols in this branch. The search connector's code index is not a reliable branch-specific callsite inventory. Direct source enumeration and targeted fetches are still required.

## 6. External scheduler status — NOT VERIFIED
The available Staging database evidence cannot enumerate:
- Supabase Dashboard scheduled invocations not represented in `cron.job`;
- Cloudflare Workers/Pages scheduled triggers;
- GitHub Actions workflows using secrets;
- third-party cron services;
- operator scripts, local jobs or manual service-role invocations;
- secrets/Vault values or remote scheduler configuration.

No secret values were read. No external scheduler configuration was changed. The owner must confirm whether any external scheduler or manual runner is configured, or provide read access to its non-secret schedule metadata. Never share cron secrets or service-role keys.

## 7. Architecture gate / next actions
1. Treat `krim_internal` alternate workflow runtime as potentially callable until proven otherwise.
2. Resolve deployed `krim-resend-email-worker` versus repository `krim-notification-email-worker` drift; fetch and compare the repository worker and its imports/callers.
3. Enumerate all Staging Edge Function source files and map function-to-RPC-to-table side effects, especially email/retry/webhook and queue runtime.
4. Obtain external scheduler inventory or owner confirmation; secrets are not required.
5. Build a unified caller matrix and select one canonical runtime. Then design lane propagation and side-effect isolation across every entry point.
6. Do not apply workflow lane migration, invoke test workflow actions, or run notification/webhook tests until these gates pass.

## 8. Current outcome
- Active database cron jobs: 2 (workflow runtime and capacity-hold expiry).
- pg_net pending requests: 0; responses: 0.
- Configured Staging webhook endpoints: 0.
- Alternate workflow queue entry points: service_role-only, still potentially callable.
- External schedulers: unverified.
- Deployed/repository email-worker name drift: confirmed.
- No data writes, queue claims, HTTP calls, emails, webhooks, test events or fixture actions.
- Production untouched. Phase 00 remains OPEN — NOT APPROVED; Phase 01 not authorized.
