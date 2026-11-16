# KRIM Page 61 — Warehouse Alerts & Reviews
Date: 2026-11-16

## Canonical page
`public/warehouse/notifications.html` — Warehouse Alerts & Queue. This is an in-workspace attention view, not an outbound email/SMS/push notification service.

## Data sources and scope
- Authenticated Supabase session required.
- Tasks: `krim_warehouse_list_tasks({p_task_type:null})`, permission-scoped server RPC; source contract returns up to 250 recent tasks.
- Inventory quality attention: `krim_warehouse_inventory` rows with quality status pending/hold/rejected, limited to 300 and subject to RLS.
- Evidence: `krim_warehouse_list_evidence({p_task_id:null})`, permission-scoped server RPC.
- The page derives open/in-progress/on-hold task attention, quality-state inventory rows, and candidate missing inspection-report follow-ups from those returned datasets.
- No notification provider, external delivery, or notification preference/consent flow is invoked by this page.

## Changes made
Commits:
- `09dbd48ef1cc2bfd783216a0044282d106750ee3`
- `da798ad14105b9f692d384efe79adcbf97860f34`

1. Validates all three data-source response shapes; unexpected payloads withhold the partial attention view instead of silently rendering empty queues.
2. Adds safe date formatting and null-safe task-type labels.
3. Clarifies that task and inventory sections are bounded (250 recent tasks; 300 quality rows), not complete/lifetime queues.
4. Reports returned-record counts and explicitly states that the page does not send external notifications.
5. Makes the “missing inspection report” result a candidate follow-up derived from the returned tasks/evidence rather than claiming a complete global exception list.

## Safety boundary
No task was created or transitioned. No inventory quality status was changed. No evidence was uploaded, opened or signed. No email, SMS, push or Telegram notification was sent. No production data was changed.

## Limitations and follow-up
- Task, inventory and evidence queries are bounded and may have different visibility/scope; an absent row is not proof of a global absence.
- A candidate missing inspection report must be verified in the task's exact evidence context before a reviewer makes a decision.
- This is a polling page with a manual refresh, not a real-time event subscription or durable alert-delivery system.
- External notification delivery, retries, consent/preferences and delivery confirmation are separate platform capabilities and were not tested here.
- Facility-level and multi-role user acceptance testing remains outstanding.

## Page 61 status
**Warehouse attention queue hardened and its bounded scope made explicit.** No production operation or external notification was performed. Not a complete alerting-system certification.
