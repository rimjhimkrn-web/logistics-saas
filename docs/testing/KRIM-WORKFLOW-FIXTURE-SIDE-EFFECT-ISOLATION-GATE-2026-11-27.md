# KRIM Workflow Fixture Provisioner — Side-Effect and Execution Isolation Gate
Date: 2026-11-27
Environment: Staging Supabase project `qrpcivhdxobiaofppbkl` only.

## Scope and result
Read-only inspection of existing Phase 00 fixture provisioners, workflow schema, workflow runtime routines, and event triggers. No schema/data changes, worker invocation, invitations, emails, notifications, or operational records were created. Production was not accessed.

Decision: **Do not implement or invoke a workflow fixture provisioner against the existing runtime tables yet.** The current event and worker paths have side effects that a fixture-only marker or owner-only Edge Function would not automatically contain.

## 1. Existing Phase 00 fixture provisioner review
The existing organization provisioner:
- Checks exact Staging project URL, confirmed user, AAL2 token, and a single active `platform_superadmin` assignment at the Edge Function boundary.
- Calls a service-role-only database function with run ID, fixture role, user ID, and actor ID.
- The database function rechecks the actor's active platform-superadmin assignment and the confirmed Auth identity's app_metadata fixture marker.
- Uses a private idempotency ledger and creates real rows in `krim_organizations` and `krim_organization_members`.

It is not a suitable workflow-only fixture primitive: invoking it creates actual tenant organizations and memberships. No organization fixture should be created just to test workflow mechanics.

## 2. Critical event-trigger side effects
Catalog inspection found two AFTER INSERT triggers on `public.krim_events`:
- `trg_krim_customer_shipment_in_app_notification` calls `krim_internal_create_customer_shipment_in_app_notification()`.
- `trg_krim_enqueue_event_essential_emails` calls `krim_internal.krim_enqueue_event_essential_emails()`.

Therefore, inserting a synthetic row into the live event table can invoke customer notification/email enqueue logic. A synthetic payload is not by itself proof of isolation. The current design must not insert test events into `krim_events` until these triggers have a tested fixture-safe branch or a separate test-only event ingress is provided.

## 3. Runtime action side effects
The currently deployed `krim_internal_execute_workflow_action(bigint,uuid)` implementation confirms:
- `record_workflow_checkpoint`: updates workflow run-step and action execution state; no external service call in the inspected branch.
- `evaluate_delay_risk`: records a bounded result indicating operational ETA/tracking evidence is awaited; no external prediction service is called in the inspected branch.
- `create_exception_case`: inserts into `public.krim_exceptions` with a shipment ID derived from event payload or workflow entity ID. This is not safe for a workflow-only synthetic event unless an explicit fixture-specific path prevents references to real shipment records and isolates the exception row.
- `prepare_customer_notification` and `prepare_partner_notification`: deliberately fail closed as unsupported; no verified record-enqueue handler exists.
- Unknown actions fail closed.

The dispatcher reads `public.krim_events`; the dispatch materializer creates normal workflow runs, run steps, and action execution rows. The executor requires a current lease ID and a live running lease.

## 4. Scheduler interaction
The existing workflow runtime and capacity-hold expiry jobs run automatically on a schedule (previous Staging audit: once per minute). Thus, simply inserting fixture actions into the ordinary queue could cause background workers to claim them before a test harness is ready. A safe test harness needs an explicit claim boundary, not merely a run UUID in metadata.

## 5. Required isolation architecture before implementation
A workflow-only test harness must:
1. Use an isolated private fixture registry and immutable run ledger.
2. Avoid `krim_events` until event-trigger side effects are explicitly controlled and verified.
3. Add a worker claim filter or dedicated test queue so scheduled workers cannot claim fixtures unless the specific run is explicitly enabled.
4. Use a dedicated test-only event/dispatch ingress and prove it cannot reference real shipment, quote, partner assignment, customer notification, or payment IDs.
5. Permit only `record_workflow_checkpoint` and `evaluate_delay_risk` in the first test slice. Exclude `create_exception_case` until its shipment dependency is safely fixture-scoped.
6. Keep notification actions and all external providers unreachable.
7. Reuse current service-role-only internal worker boundary; do not grant direct client table access.
8. Provide explicit owner AAL2 authorization, exact Staging URL/project guard, idempotency, per-run enable/disable, concurrency-safe claims, and fixture-owned cleanup.
9. Test that ordinary scheduled jobs skip disabled fixture runs and that enabling a run affects only its own fixture rows.
10. Preserve production untouched and require a separately reviewed migration and staging verification before any worker execution.

## 6. Exit status
- Existing tenant fixture provisioner: reviewed; not reused.
- Event trigger side effects: confirmed; isolation gap.
- Action executor: inspected; two actions appear suitable for an initial isolated slice; exception creation is not.
- Scheduled worker isolation: not yet implemented or proven.
- No workflow fixture provisioner created or deployed.
- No tests executed; no rows changed.
- Phase 00 remains OPEN — NOT APPROVED. Phase 01 is not authorized.
