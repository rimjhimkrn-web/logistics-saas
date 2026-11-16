# KRIM Page 60 — Outbound Dispatch / Warehouse Handover Review
Date: 2026-11-16

## Canonical workflow and boundary
The legacy `public/warehouse/outbound-dispatch.html` is a compatibility redirect to the authenticated warehouse workspace. The actionable warehouse handover workflow is `public/warehouse/dispatch-handover.html`.

This page records a warehouse custody handover checkpoint. It does **not** dispatch a KRIM shipment, authorize a carrier, assign a driver, reserve carrier capacity, or notify a partner. Exact-leg shipment dispatch authorization remains a separate Operations/partner control.

## Source workflow reviewed
- Authenticated Supabase session and active organization membership.
- Eligible warehouse organization filtering (registered-business mode, verified/approved identity, active lifecycle, accepted compliance values, and warehouse organization type or verified warehouse capability).
- Only active, administrator-approved facilities are selectable.
- Shipment legs are loaded through `krim_warehouse_list_assigned_shipment_legs`.
- Picked stock is checked against `krim_warehouse_shipment_allocations` for the selected organization, facility, shipment and exact leg.
- Handover task creation uses `krim_warehouse_create_linked_handover_task`.
- Task transitions use `krim_warehouse_transition_task`.
- Private dispatch proof is registered separately through Warehouse Evidence.
- The source migration `20261116027000_require_picked_allocations_before_dispatch_handover.sql` defines a trigger requiring at least one picked allocation and no remaining reserved allocations on handover insert/completion.
- The source migration `20261115182500_revalidate_private_dispatch_proof_before_warehouse_handover.sql` defines private uploader-owned proof checks before completion.
- The source migration `20261116028000_require_warehouse_handover_before_leg_dispatch.sql` defines a further guard requiring completed exact-leg handover, picked allocations, no outstanding reservations and current private proof before dispatch authorization remains current.

## Findings and changes
Commits:
- `7e63213b7a7c5cff2a8239fea38c866758cf861d`
- `b6d0a24ba71400c54243adab335a6420bab28409`

1. **Corrected stale pick-task instructions.** Earlier page copy required a completed legacy Pick & Pack task. The later allocation-ledger migration explicitly retires that dependency and makes shipment inventory allocations the authoritative pick record. Page copy now explains the current allocation-ledger requirement.
2. **Hardened allocation and shipment-leg response handling.** Unexpected RPC/query response shapes now stop the workflow instead of being treated as empty arrays or silently enabling a misleading UI state.
3. **Hardened task queue handling.** Unexpected task-list responses are rejected before action buttons are rendered.
4. **Safe task rendering.** Malformed timestamps no longer display as invalid dates, and unknown/null statuses render safely.
5. **Clarified operational boundary.** The page now distinguishes warehouse handover from shipment dispatch and avoids implying that this screen assigns drivers or dispatches a shipment.
6. **Qualified production enforcement claims.** Copy now explains that proof enforcement depends on verified deployment of the relevant server-side migrations.

## Important deployment limitation
The repository contains the server-side guard migrations described above, but the production migration-history/source reconciliation remains unresolved. Therefore this page review does not certify that every guard in those source migrations is deployed and active in production. Do not treat frontend allocation checks as authorization; the server-side RPCs/triggers must be verified against the reconciled live database before real dispatch.

## Safety boundary
No handover task was created or transitioned. No allocation was reserved, picked or released. No evidence was uploaded or signed. No dispatch authorization, driver assignment, shipment dispatch or carrier notification was invoked. No production data was changed.

## Remaining validation
- Verify the exact live definitions and deployment status of the handover/dispatch guard functions after migration reconciliation.
- Test with two authorized warehouse users, including maker-checker and evidence ownership cases.
- Confirm all allocation rows for the exact facility/leg are evaluated under server-side locking.
- Complete a controlled end-to-end operational test only after a real partner, route, capacity and authorization are approved.

## Page 60 status
**Warehouse handover source hardened and its stock-authority instructions aligned to the allocation ledger. Production enforcement remains unverified pending migration reconciliation.** Not dispatch certification.
