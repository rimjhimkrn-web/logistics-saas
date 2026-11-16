# Page 74 — Shipment Exceptions & Escalations Review
Date: 2026-11-16

## Canonical route
`app/operations/exception-management.html`

## Findings
- Reads exception and escalation registers under database policies, each capped at 100.
- The page includes user-triggered acknowledgement and resolution actions through `krim_acknowledge_exception_escalation` and `krim_resolve_operational_exception`.
- These actions were not invoked in this audit. Source indicates backend `compliance.manage` enforcement; production enforcement must be verified against reconciled live definitions.
- Resolution requires a non-trivial explanation and records an audit event according to the UI's stated workflow.
- Previously the page accepted any active organization membership. It now requires active membership in an active operations organization.
- Both successful query results are validated as arrays before rendering/action buttons are built.

## Change
Commit: `ef7147366eaa7cd6e7c435fd1420766fcb9f5bce`
Added operations-organization membership gate and fail-closed validation for exception and escalation response shapes.

## Safety
No acknowledgement, resolution, escalation, exception status change or audit write was performed.

## Remaining gate
Confirm the live RPC authorization, role mapping, maker-checker requirements, exception lifecycle and audit immutability after migration reconciliation. Acknowledgement is not resolution; resolution is not proof of physical recovery.
