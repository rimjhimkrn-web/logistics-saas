# KRIM Driver Assignment Acceptance RPC Audit — 2026-11-24

## Scope
Read-only comparison of production and staging for `public.krim_driver_accept_assignment(uuid)`, plus inspection of its live browser caller at `app/driver/module-03-assignment-acceptance.html`.

Projects:
- Production: `ebltviniygljwwseplph`
- Staging: `qrpcivhdxobiaofppbkl`

## Result
The function definition returned by PostgreSQL is identical in production and staging. Both environments report:
- `SECURITY DEFINER`, owner `postgres`
- Explicit empty `search_path`
- `anon` EXECUTE: denied
- `authenticated` EXECUTE: allowed
- `service_role` EXECUTE: allowed

The browser caller invokes the same RPC with `p_assignment_id`, then verifies the resulting assignment status using both assignment ID and authenticated user ID. It does not directly update assignment status.

## Server-side acceptance gates observed
The function enforces, in order:
1. Authenticated caller and assignment ownership (`user_id = auth.uid()`), with row lock.
2. Active driver membership in the assignment organization.
3. Verified driver profile, nonblank licence number, unexpired licence, and independently accepted front/back licence plus identity documents.
4. A linked vehicle that is verified, active, and actively bound to the same driver and organization.
5. At least one required vehicle-document rule for the vehicle's country/category, and every required document approved and unexpired.
6. Pending `assigned` state, or a consistent idempotent return for an already accepted assignment owned by the same driver.
7. Accepted/active partner assignment matching the exact shipment, leg, partner organization, and driver assignment.
8. Shipment state eligibility, including the active multi-leg/in-transit exception.
9. Positive shipment weight and known vehicle payload unit; normalized kg/tonne capacity comparison.
10. Exact leg still assigned to the partner, and the leg must be ROAD.
11. Current partner compliance plus active, verified/approved ROAD capability and approved active service-area coverage for the pickup location.
12. Only then does the function update the driver assignment to accepted.

## Browser-to-RPC trace
The inspected page:
- Reads the authenticated session.
- Requires exactly one active driver organization membership.
- Requires that organization to be active.
- Reads assignments scoped to the authenticated user.
- Offers acceptance only for rows in `assigned` state.
- Calls `db.rpc('krim_driver_accept_assignment', { p_assignment_id: id })`.
- Requires the RPC response to report `accepted`, then performs a second owner-scoped read to verify persisted status.
- Does not mark pickup, departure, delivery, or proof-of-delivery as complete.

## Findings and remaining verification
- No production/staging definition or ACL drift was detected for this RPC in this comparison.
- The function is deliberately fail-closed: missing compliance, vehicle binding, required document configuration/evidence, partner capability, service-area approval, or valid ROAD leg prevents acceptance.
- Production currently has no driver assignments and no verified driver profiles/vehicles in the readiness snapshot. Therefore, there is no legitimate production record on which to perform a successful end-to-end acceptance test.
- Static caller inspection and catalog inspection are not substitutes for authenticated positive/negative integration tests. Those tests still need controlled fixtures in an isolated test database or a dedicated non-production environment.
- This audit made no database, permission, assignment, customer, partner, driver, payment, or dispatch changes. No external notifications were sent.

## Release gate
Do not treat driver acceptance as end-to-end verified until isolated tests prove: unauthenticated rejection; cross-driver assignment rejection; inactive membership rejection; missing/expired licence rejection; missing/unapproved vehicle evidence rejection; wrong/unaccepted partner assignment rejection; non-ROAD leg rejection; stale/invalid partner coverage rejection; overweight rejection; and successful exact-leg acceptance followed by an owner-scoped persisted-status read.
