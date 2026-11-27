# KRIM Domain Event Ingress and Workflow Test-Lane Boundary — 2026-11-27

## Disposition
**Do not implement a shared event-table test lane by simply adding a defaulted column and inserting synthetic rows.** Existing event producers are business lifecycle triggers and must remain production-lane by construction.

Inspection was read-only against Staging Supabase project `qrpcivhdxobiaofppbkl`. No DDL, DML, workflow claims, or external delivery occurred. Production was not accessed.

## Verified event producers
The Staging database contains SECURITY DEFINER trigger functions that emit rows into `public.krim_events` from real business lifecycle changes:

- `krim_internal_emit_shipment_created_event`
- `krim_internal_emit_shipment_status_event`
- `krim_internal_emit_partner_assignment_event`
- `krim_internal_emit_driver_assignment_event`
- `krim_internal_emit_driver_assignment_status_event`

They create event payloads from real shipment, partner assignment, or driver assignment records. Their metadata values identify trigger names but are not a trustworthy lane authority. The event row currently has no typed lane/run columns. Existing constraints validate event ID uniqueness, organization FK, actor FK, event version, processing attempts and processing status; none enforce a test-run boundary.

## Safety conclusion
A test harness must not create test events by mutating real shipment/assignment records merely to activate these triggers. That would create business lifecycle side effects and downstream customer notifications/essential email queue work. Nor may a caller mark an event as test by supplying arbitrary `metadata` or `payload` JSON.

## Recommended architecture
1. Keep all existing business lifecycle trigger emissions unconditionally `production`.
2. Add a separate, trusted test-event ingress function that requires an owner-authorized, enabled test-run UUID and validates a narrow event/action schema. It must not accept arbitrary event metadata as lane authority.
3. Test ingress writes only test-lane event records with immutable run lineage, using an explicit database-controlled lane field.
4. Route test events to a dedicated test dispatch/queue path, or to fully lane-scoped shared tables only after both workflow runtimes, notifications, webhooks, retries, replay and reconciliation are proven isolated.
5. Production schedulers and workers must filter production lane explicitly; test runner must filter the exact enabled run ID and must never call external providers.
6. Ensure test ingress cannot impersonate real shipment/partner/driver events or trigger business notification/email triggers.
7. Add database tests proving: normal business triggers always produce production lane; test ingress requires an enabled run; arbitrary metadata cannot set lane; disabled/unknown run is rejected; production worker cannot claim test rows; test worker cannot claim production or another run; retry/replay/recovery preserve lineage.
8. Inventory every caller and alternate runtime before applying migration. The existing alternate `krim_internal` queue-lease runtime is service-role executable and also requires lane/run scoping or a verified disablement.

## Current checkpoint
- Business event source functions identified: PASS.
- Typed lane/run absent from event schema: CONFIRMED.
- Existing downstream event triggers create notifications/outbox side effects: CONFIRMED by prior audit.
- Safe test ingress implementation: NOT YET IMPLEMENTED.
- Workflow lane migration: NOT APPLIED.
- Synthetic event execution: BLOCKED.
- Production: untouched.

## Related records
- `KRIM-WORKFLOW-RUNTIME-LANE-ISOLATION-INVENTORY-2026-11-27.md`
- `KRIM-NOTIFICATION-EVENT-SIDE-EFFECT-ISOLATION-GATE-2026-11-27.md`
- `KRIM-WORKFLOW-LANE-DEPENDENCY-MIGRATION-GATE-2026-11-27.md`
