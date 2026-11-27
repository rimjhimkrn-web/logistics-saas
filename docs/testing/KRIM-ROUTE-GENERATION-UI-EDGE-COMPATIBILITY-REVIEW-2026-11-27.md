# KRIM Route-Generation UI and Edge Function Compatibility Review
Date: 2026-11-27
Scope: Staging project qrpcivhdxobiaofppbkl; repository branch staging/phase00-env-isolation.
Production was not accessed or changed.

## Edge Function inventory
The Staging Edge Function catalog contained five active functions:
- global-admin-control (v2)
- krim-resend-email-worker (v1)
- owner-testing-authorize (v5)
- krim-phase00-provision-test-organizations (v2)
- krim-phase00-test-user-invites (v3)

Fetched deployed source for all five. None contains references to shipment-leg or route-plan identifiers (shipment_leg, leg_sequence, leg_plan_item_id). The two Phase 00 fixture functions are owner/test provisioning only; they have not been invoked and have not created fixtures. This is a bounded finding for the current deployed function catalog, not proof that no other external worker or client exists.

## Frontend review
Fetched and inspected current Staging branch files:
- public/shipper/quote-comparison.html
- workspaces/partner-workspace.html

### Customer quote comparison
- Loads customer shipment context and partner quotes through krim_customer_list_partner_quotes and related customer-scoped queries.
- Uses krim_get_partner_response_evidence for partner response history.
- Uses server-side RPCs krim_accept_global_quote and krim_customer_prepare_partner_quote for commercial actions.
- Does not directly query krim_shipment_legs, leg_sequence, or krim_shipment_leg_plan_items.
- Its visible route context is shipment-level origin/destination and transport information. It does not expose generation-specific route history.

### Partner workspace
- Uses krim_get_partner_response_evidence and organization-scoped membership/organization reads in the inspected page.
- Does not directly query operational shipment-leg or route-plan tables in this page.
- Detailed opportunity and assignment workflows may be loaded by other linked pages or server-side routines; this review does not claim those have been exhaustively inspected.

## Compatibility implications
1. The two inspected pages do not require a direct schema migration for route-generation IDs based on their current source.
2. Their server-side RPCs and linked workflows still depend on backend route/leg guards and must be included in end-to-end compatibility tests.
3. Customer quote UI currently provides shipment-level route context, not explicit route-generation history. A future UI enhancement may be required if customers need to compare route revisions.
4. Partner workspace evidence is response history, not route-generation history or a signed contract.
5. No Edge Function changes are indicated by this bounded inventory.

## Next required work
- Continue frontend inventory across every linked opportunity, assignment, dispatch, driver, POD, warehouse and operations page.
- Inspect server-side RPC bodies called by those pages and map every write/read to operational leg identity.
- Build route-generation schema only after the complete consumer matrix is signed off.
- Preserve immutable historical leg IDs and audit history; do not delete/resequence existing operational legs.
- Add runtime JWT-backed tenant isolation, multi-user and route replacement tests after implementation.

## Status
- Current Staging Edge Function inventory reviewed: PASS (bounded to deployed catalog).
- Two high-value frontend pages reviewed: PASS (bounded).
- Complete frontend/linked-page inventory: OPEN.
- Complete RPC compatibility matrix: OPEN.
- Route-generation implementation: NOT STARTED.
- Runtime E2E: PENDING.
- Phase 00: OPEN — NOT APPROVED.
