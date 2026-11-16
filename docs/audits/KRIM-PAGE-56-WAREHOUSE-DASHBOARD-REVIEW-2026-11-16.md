# KRIM Page 56 — Warehouse Dashboard Review
Date: 2026-11-16

## Canonical page
`app/warehouse/index.html` — Warehouse Control Centre.

## Backend behaviour inspected
The dashboard uses authenticated RPCs:
- `krim_warehouse_dashboard()` computes counts only for active, verified/approved, registered-business warehouse/fulfilment organisations with active membership, compliant lifecycle and `partner.manage` permission.
- `krim_warehouse_list_tasks(p_task_type => null)` returns permission-scoped task records, capped at 250, with task/facility context.
- Dashboard aggregates are calculated independently from the task list, so they can legitimately differ from the bounded task queue.
- Dashboard values are real database aggregates, not seeded/demo metrics.

## Change made
Commit: `df41b15ff27d57e445aa988e58a4011bea66ef3a`

- Added finite, non-negative metric formatting; malformed or missing values display as unavailable rather than NaN.
- Validated the RPC response shapes before rendering metrics and task queue.
- Made task-type rendering null-safe and timestamp rendering safe for malformed dates.
- Clarified that task list results are capped at 250 and the visible queue shows at most 12 open tasks.
- Error state now withholds stale-looking metrics/queue content and clearly reports unavailable data.

## Access and operations
- Page requires an authenticated session; dashboard and task RPCs are server-side permission scoped.
- Page links cover facility, inbound, receipt, put-away, inventory, allocation, dispatch, returns, exceptions, quality, evidence, performance, notifications and audit.
- No warehouse task, inventory movement, receipt, allocation, quality decision, dispatch or evidence operation was invoked.

## Known limitations / cross-page risks
- A zero aggregate can mean no eligible warehouse organisation or genuinely zero activity; the current dashboard RPC does not return an explicit eligibility diagnostic. Do not interpret zeros alone as proof of operational readiness.
- The task queue is capped at 250; the dashboard aggregate is not.
- Earlier audits identified unresolved backend issues including return-receipt NULL validation, reservation/picking interaction and cancellation/release orchestration. Those require migration reconciliation and server-side remediation; this page change does not resolve them.
- Full authenticated warehouse journey and facility approval testing remain outstanding.

## Page 56 status
**Dashboard rendering and bounded-queue messaging hardened. Automated checks pending.** Not production certification.
