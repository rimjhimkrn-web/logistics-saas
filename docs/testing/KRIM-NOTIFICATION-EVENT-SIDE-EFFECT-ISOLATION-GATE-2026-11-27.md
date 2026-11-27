# KRIM Notification Event Side-Effect Isolation Gate — 2026-11-27

## Result
**BLOCKED — do not emit synthetic workflow events into `public.krim_events` yet.**

Read-only inspection of Staging Supabase project `qrpcivhdxobiaofppbkl`. No SQL mutation, queue claim, event insertion, provider call, notification send, or Production access was performed.

## Verified database behavior

### Event triggers
Two AFTER INSERT triggers exist on `public.krim_events`:

- `trg_krim_customer_shipment_in_app_notification` calls `public.krim_internal_create_customer_shipment_in_app_notification()`.
- `trg_krim_enqueue_event_essential_emails` calls `krim_internal.krim_enqueue_event_essential_emails()`.

### Essential email trigger
The trigger currently filters only four event types:
- `shipment.created`
- `shipment.status_changed`
- `partner.assignment_offered`
- `partner.assignment_status_changed`

For matching events with an organization, it enumerates active organization members and calls `krim_internal.enqueue_essential_email_notification`. It does not inspect a typed runtime lane or fixture run identifier.

### In-app notification trigger
The trigger creates real rows in `public.notifications` for shipment, partner-assignment and driver-assignment event types. It resolves actual shipment/assignment and membership records. It does not inspect a typed runtime lane or fixture run identifier.

Therefore adding a test marker only to event JSON metadata is not a safe isolation boundary. Synthetic test events could create customer/partner/driver in-app notifications and essential email outbox entries.

### Email claim function
`krim_internal.claim_email_notification_delivery(text, integer)` is SECURITY DEFINER and claims any due email outbox row with attempts below five, including expired processing leases. It does not filter by runtime lane, fixture run, provider, or notification type. It increments attempts and writes a worker lease before validating the row.

The public wrapper `public.krim_claim_email_notification_delivery` delegates directly to this function. Do not broaden access or run it as a test.

## Required implementation gate

1. Add typed, non-user-controlled `runtime_lane` and nullable `test_run_id` lineage to events and every notification/outbox/delivery/retry record that can be reached from a test event.
2. Validate lane/run identity at trusted event ingress; do not infer it from arbitrary JSON metadata.
3. Update BOTH event triggers so test-lane events cannot create real in-app notifications or enter the production email outbox. Test notifications, if needed, must use an isolated test sink/table and never a live provider.
4. Update the generic email claim lifecycle and every wrapper/caller so production workers claim production rows only. A dedicated test runner must claim one explicitly enabled test run only, and must never call Resend/Telegram or other external providers.
5. Preserve lane/run lineage through retry, lease recovery, cancellation, dead-letter, replay, and reconciliation.
6. Audit all alternate workflow runtimes and external schedulers/callers before applying the schema migration.
7. Add database tests proving test events create zero production notifications/outbox rows and production events retain existing behavior.
8. Only after tests pass, deploy the source to Staging. Do not invoke a live delivery worker.

## Current disposition
- Safe synthetic event insertion: **BLOCKED**
- Generic email claim function: **production-only until scoped**
- Real provider delivery: **disabled / not to be invoked**
- Staging-only changes: required
- Production: untouched

## Related prior evidence
- `KRIM-WORKFLOW-LANE-SCHEDULER-CLAIM-BOUNDARY-DESIGN-2026-11-27.md`
- `KRIM-WORKFLOW-LANE-DEPENDENCY-MIGRATION-GATE-2026-11-27.md`
- `KRIM-ALTERNATE-WORKFLOW-RUNTIME-WEBHOOK-CALLER-INVENTORY-2026-11-27.md`
- `KRIM-NOTIFICATION-OUTBOX-LIFECYCLE-AUDIT-2026-11-27.md`
