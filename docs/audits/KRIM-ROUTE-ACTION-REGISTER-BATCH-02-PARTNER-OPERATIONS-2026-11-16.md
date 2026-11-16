# KRIM Route-and-Action Register — Batch 02: Partner and Operations
**Date:** 16 November 2026  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Scope:** Static inspection of 12 partner, operations and platform-admin pages. No live actions executed.

## Page-level findings

| Page | Direct calls/data observed | Verification focus |
|---|---|---|
| `app/partner/index.html` | Reads `krim_organization_members`, `krim_organizations`; session/user checks | Confirm membership is active, role matches partner workspace and organization is not merely self-selected from client state. |
| `app/partner/carrier/index.html` | Reads organization membership, organizations, `krim_partner_capabilities`, `krim_transport_modes` | Capability catalogue must not be represented as approved/active operating authority. Verify approval status, scope and evidence expiry. |
| `app/partner/driver-vehicle-assignment.html` | Reads organization membership; no direct RPC/Edge Function call found by literal scan | Assignment action may be indirect or absent. Verify the actual UI handler and server-side authorization before enabling operational use. |
| `app/partner/carrier/active-shipments.html` | Reads `krim_shipment_partner_assignments`, `krim_shipments`, `krim_locations`, membership and organization | Confirm partner sees only shipments assigned to its own organization and current assignment status; no client-side tenant filter as sole control. |
| `app/partner/carrier/milestone-updates.html` | Calls `krim_record_operational_milestone`; reads tracking events, partner assignments, shipments and locations | High-risk state mutation. Enforce actor identity, shipment assignment, allowed state transition, monotonic milestone ordering, evidence and idempotency. Existing audit flagged out-of-order milestone risk. |
| `app/operations/index.html` | Calls `krim_operations_list_shipment_snapshots`; reads shipments, exceptions, tracking events, warehouse transfers and shipment returns | Verify control-tower visibility is permission-scoped and sensitive partner/driver data is minimized. |
| `app/operations/capacity-planning.html` | Reads organization membership; no direct RPC/Edge Function call found by literal scan | Capacity workflow may be static, indirect or not wired. Do not treat displayed/planned capacity as a confirmed reservation. |
| `app/operations/dispatch-control.html` | Calls `krim_operations_dispatch_readiness`; reads membership and shipments | Readiness result must be fail-closed and revalidated atomically at dispatch. Require partner assignment, accepted capacity, valid driver/vehicle, route/corridor controls, customs/compliance clearance and shipment custody prerequisites. |
| `app/operations/shipment-control.html` | Reads membership and `krim_shipments`; no direct RPC/Edge Function call found by literal scan | Verify all state-changing buttons use approved transition RPCs, require reason/evidence where applicable and reject invalid/out-of-order transitions. |
| `app/operations/route-planning.html` | Calls `krim_create_shipment_leg_plan`, `krim_evaluate_shipment_leg_plan`; reads routes, plans, shipments, locations and transport modes | Structural route evaluation must not be treated as corridor activation or legal/operational clearance. Revalidate country packs, approved corridor dossier/controls, customs and partner capability before activation. |
| `app/platform-admin/partner-verification.html` | Calls `krim_admin_list_partner_verification_cases`, `krim_admin_review_partner_verification`; invokes `global-admin-control`; MFA signal present | Verify AAL2, dedicated admin permission, independent reviewer, evidence integrity, audit trail, status transition and no self-approval. |
| `app/platform-admin/partner-capabilities.html` | Calls `krim_admin_list_partner_capabilities`, `krim_admin_review_partner_capability`; invokes `global-admin-control`; MFA signal present | Capability approval must be distinct from partner verification and bound to service mode, geography, validity, evidence and operating controls. |

## Cross-cutting findings
1. Partner and operations pages commonly read membership and organization records directly. This is not by itself proof of server-side tenant isolation.
2. Several pages have no literal direct RPC or Edge Function call in the scanned HTML. This is not proof that the feature is broken; shared scripts, inline handlers, or indirect modules may provide the action. Those handlers need explicit tracing before certification.
3. Route planning's create/evaluate functions do not, by their names alone, establish market/corridor authorization. Prior backend audit found route structural evaluation does not fully enforce country operating packs, approved corridor dossiers/controls and customs clearance.
4. Dispatch readiness is a read/check endpoint; readiness is not dispatch authorization. The actual dispatch mutation must repeat critical checks transactionally.
5. Partner verification and capability approval are separate trust decisions. Neither should imply global coverage or confirmed capacity.

## Required staging tests
- Partner organization A cannot view or mutate organization B's shipments, assignments, capability evidence or milestones.
- Revoked partner membership and revoked shipment assignment immediately remove access, including active sessions.
- Partner cannot record milestones for an unassigned shipment, as a different actor, out of order, or with a conflicting retry.
- Partner verification cannot be approved by the submitter or same reviewer identity; evidence replacement and expiry are audited.
- Capability approval is scoped to exact mode, geography, service, validity dates and evidence; expired/suspended capability blocks matching work.
- Capacity displayed as indicative cannot be converted to reservation without an atomic server-side availability check and idempotency key.
- Dispatch fails closed for missing partner assignment, capacity binding, driver/vehicle compliance, route controls, corridor approval, customs clearance or custody prerequisite.
- Route evaluation rejects unsupported/unactivated corridor for booking/dispatch even if a structurally valid leg plan exists.
- Operations users cannot use broad shipment reads to retrieve finance, identity or private evidence fields outside their permissions.
- State transitions require valid predecessor state, permission, reason/evidence and audit event; cancellation after dispatch requires an explicit reason and controlled workflow.

## Release status
**Not certified.** This report is a static source register and test plan, not evidence of successful staging tests. No production mutations, partner approvals, capacity reservations, route activations, dispatches, shipments or financial transactions were executed. Production DDL remains blocked pending complete migration reconciliation. Live own-service-fee setup remains deferred to the final phase.
