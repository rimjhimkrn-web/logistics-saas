# KRIM customer / partner / driver / warehouse RPC tenant-boundary review — 2026-11-24

## Status
Read-only source review of selected production RPC definitions and effective EXECUTE privileges. No production or staging data/schema changed. This is not a dynamic cross-tenant penetration test or release sign-off.

## Customer path
### `krim_customer_list_partner_quotes(bigint[])`
- Requires `auth.uid()`.
- Rejects null/empty/oversized arrays, invalid IDs and duplicate shipment IDs.
- Resolves each shipment and requires `private.krim_has_organization_access(user, shipment.customer_organization_id)` for every requested shipment before returning any quote rows.
- Quote rows are joined back to the exact shipment/opportunity/customer organization and only currently eligible verified partner data is exposed.
- This is a strong static tenant-boundary pattern. Still test one valid customer shipment + one foreign shipment in the same array: entire request must fail, with no partial quote response.

### `krim_accept_global_quote(bigint)`
- Requires active organization access and `shipment.update` permission for the quote's customer organization before status updates.
- Requires exact shipment/partner quote/assignment binding, verified partner organization, current compliance and verified capability before finalization.
- Follow-up negative tests should attempt a foreign customer's quote ID, a quote with mismatched shipment ID, and an accepted quote with a different partner assignment.

## Partner path
### `krim_submit_partner_quote(...)`
- Derives partner organization IDs from the authenticated user's active organization memberships; caller cannot supply an arbitrary partner organization ID.
- Requires exactly one eligible registered-business partner organization, current verification/lifecycle/compliance and active verified capability.
- Requires `quote.create` permission, an open opportunity, route/mode/weight capability coverage and rejects bidding on the partner's own customer shipment.
- Follow-up negative tests: foreign/unrelated user, suspended membership, two eligible partner org memberships, inactive/unverified capability, own-shipment bid, closed opportunity.

### `krim_partner_register_capacity_resource_for_lane(...)`
- Wrapper does not itself read `auth.uid()`; it delegates to the base capacity registration RPC, which checks authenticated identity, active organization membership, `partner.manage`, partner type/status/compliance and private evidence object ownership.
- Wrapper adds lane binding after base registration. Negative tests must prove lane belongs to the same partner/mode/location and that failed lane binding rolls back the resource insert.

## Driver path
### `krim_driver_accept_assignment(uuid)`
- Requires `auth.uid()`; selects the assignment only where `user_id = auth.uid()`.
- Requires active driver membership in the assignment organization.
- Requires independently verified driver profile and accepted front/back licence plus identity evidence.
- Requires the assigned vehicle to be verified, active and actively bound to the same driver and organization; validates mandatory vehicle documents and payload capacity.
- Revalidates exact accepted partner assignment, shipment, exact leg, partner organization and ROAD mode.
- Follow-up negative tests: another driver's assignment ID, wrong partner organization, inactive driver membership, expired licence, unverified vehicle, over-capacity shipment and mismatched leg.

### Driver trip event / POD
- Both selected RPCs require authenticated identity and membership/assignment scoping in their source. Dynamic checks still needed for foreign assignment IDs, forged storage/signature references and terminal-state transitions.

## Warehouse path
### `krim_warehouse_list_tasks(text)`
- Requires authenticated identity and filters every task through `private.krim_warehouse_is_operator(user, organization_id, facility_id)`.
- Joins shipment and leg context from the task's own organization/facility scope.

### `krim_warehouse_register_evidence(...)`
- Requires authenticated identity and warehouse-operator authorization for the task's organization/facility.
- Requires storage path organization ID and user ID to match the task and current actor.
- Requires a private evidence object owned by the same user, in the expected bucket, with approved MIME types and a 10 MB maximum.
- Follow-up negative tests: foreign task ID, foreign facility, different user's path, wrong bucket, unowned object, unsupported MIME type and oversized object.

### `krim_warehouse_transition_task(...)`
- Requires authenticated identity and `krim_warehouse_is_operator` for the task's actual organization/facility before any state transition.
- Uses a task-scoped idempotency event; rejects reuse for a different status/note.
- Enforces legal task transitions and requires shipment-linked receipt/picking prerequisites for sensitive completion actions.
- Follow-up negative tests: foreign task ID, wrong facility operator, replay with altered status, invalid terminal transition and cross-shipment linked task.

## Execution grants
The selected customer, partner, driver and warehouse RPCs are authenticated-executable and not anon-executable in the production catalog. Their SECURITY DEFINER bodies use explicit empty search_path and schema-qualified object references.

## Dynamic regression matrix still required
| Actor | Foreign object attempt | Expected result |
| --- | --- | --- |
| Customer A | List quotes for Customer B shipment | Entire request denied |
| Customer A | Accept Customer B quote | Denied; quote/shipment unchanged |
| Partner A | Submit bid on Partner B-only opportunity without eligible membership | Denied; no quote inserted |
| Partner A | Register capacity against another partner's lane | Denied; no resource/lane binding persists |
| Driver A | Accept Driver B assignment | Denied; assignment unchanged |
| Driver A | Record event / POD for Driver B assignment | Denied; no event/POD persisted |
| Warehouse A | List tasks from Warehouse B | No foreign rows |
| Warehouse A | Transition Warehouse B task | Denied; task/inventory unchanged |
| Warehouse A | Attach evidence stored under User B | Denied; no evidence/event inserted |

## Release decision
Static guards look well-structured in this selected set, but no synthetic two-tenant dynamic negative tests were run in this pass. Build and run those tests in isolated staging using disposable users/organizations and rolled-back transactions. Keep PR #245 draft and do not claim tenant-isolation certification until the negative tests pass.


## Dynamic staging negative test executed
A two-user synthetic test was executed in Supabase staging inside one explicit transaction:
1. Created two synthetic, email-confirmed Auth users with `.example.invalid` addresses.
2. User A provisioned a new partner organization through the actual `krim_provision_partner_organization` RPC.
3. Switched the JWT subject to user B and attempted `krim_vehicle_register` against user A's organization.
4. The RPC raised the expected insufficient-privilege error; the test would fail if the insert succeeded.
5. Verified no vehicle row was created for the foreign organization.
6. Rolled back the complete transaction.

Post-rollback catalog/data check returned the original staging counts: 1 auth user, 0 organizations, 0 vehicles, and 0 partner-registration audit rows. No persistent staging test data remains.

Reproducible staging-only script:
`tests/sql/staging-tenant-boundary-vehicle-registration.sql`

This is one proven negative case (partner vehicle registration). It does not replace the remaining customer quote, driver assignment, warehouse facility/evidence and partner capacity cross-tenant test matrix.
