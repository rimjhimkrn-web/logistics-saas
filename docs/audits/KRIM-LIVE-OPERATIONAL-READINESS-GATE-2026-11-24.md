# KRIM live operational readiness gate — 2026-11-24

## Scope
Read-only checks against the Supabase production project `ebltviniygljwwseplph` on 2026-11-24. The staging project was also checked for environment separation. No production or staging schema, data, grants, functions, Edge Functions, or schedules were modified.

## Production database status
- Production project: `logistics-saas`, region `ap-northeast-1`, status `ACTIVE_HEALTHY`, PostgreSQL 17.6.
- Active organizations: 14.
- Active organization members: 13.
- Shipments: 18.
- Shipment-partner assignments: 0.
- Driver assignments: 0.
- Active registered-business partner organizations: 0.
- Verified active partner capabilities: 0.
- Open partner opportunities: 0.
- Submitted/under-review/shortlisted partner quotes: 0.
- Active driver memberships: 1.
- Verified driver profiles with unexpired licence: 0.
- Accepted driver verification documents: 0.
- Verified active vehicles: 0.
- Active driver/vehicle bindings: 0.
- Customer identity links: 0.
- Active pilot countries/currencies/markets: 6 / 6 / 6.
- Notification outbox/deliveries: 0 / 0.
- Communication providers/recipients: 0 / 0.
- Security permission definitions / role mappings: 23 / 155.

## Staging environment
The staging project is healthy but intentionally isolated and currently has zero active members, shipments, assignments, notification outbox/deliveries, communication providers/recipients, permission definitions and role mappings. It is not a production data mirror and must not be treated as a ready-to-use live test environment until its security catalogue and controlled test identities are provisioned.

## Direct caller and RPC verification
- Partner quote submission page `public/partner/submit-quote.html` calls `krim_submit_partner_quote`.
- Production allows authenticated EXECUTE on this RPC; staging currently denies it.
- Staging implementation of this SECURITY DEFINER RPC requires authenticated identity, exactly one active eligible registered-business partner organization, current compliance, verified active capability, `quote.create`, active currency, open opportunity and route/weight capability coverage. The function has an explicit empty search_path.
- Driver assignment acceptance page `app/driver/module-03-assignment-acceptance.html` calls `krim_driver_accept_assignment(uuid)`, not `krim_respond_to_partner_assignment`.
- Production and staging definitions of `krim_driver_accept_assignment(uuid)` have matching MD5 and length in this check. The function requires the authenticated assignment owner, active driver membership, verified driver profile, accepted licence/identity documents, assigned verified active vehicle, current mandatory vehicle documents, accepted partner assignment and valid shipment/leg state. It has an explicit empty search_path.
- Neither environment has a driver assignment to exercise the acceptance path.

## Release decision
**NOT READY for real commercial operations or a revenue/profit claim.** This is not a UI-only gap: production currently has no verified commercial partner, verified capability, open opportunity, quote, verified driver, accepted driver evidence, verified vehicle or assignment. The 18 existing shipment rows are not proof of operational fulfillment.

## Required real-world inputs that cannot be fabricated by a deployment
1. At least one genuine registered-business logistics partner, with real legal/compliance evidence independently reviewed and approved.
2. A verified, active partner capability and route/mode/weight coverage that matches an actual serviceable corridor.
3. A real customer organization and authorized customer identity, plus a genuine shipment request and an open opportunity.
4. At least one genuine driver identity/licence review, vehicle registration/insurance/permit evidence as applicable, vehicle verification and active driver/vehicle binding.
5. Provider configuration and verified recipient destinations for mandatory transactional notifications. Essential service notices must be delivered and delivery outcomes recorded; marketing consent remains separate.
6. A real payment test using an authorized low-value transaction/refund procedure and verified Razorpay webhook/ledger reconciliation. No real charge should be initiated as a synthetic test without the operator's explicit transaction approval.

## Safe next implementation sequence
1. Finish source/control-flow and caller tests for partner quote award, assignment response, dispatchable driver listing and capability matching.
2. Reconcile missing migration history from exact source artifacts; do not forge historical migrations or edit migration ledgers manually.
3. Provision staging security catalogues and pilot reference catalogues through reviewed forward-only migrations; create controlled test identities using non-production evidence.
4. Run full isolated positive/negative integration tests including cross-tenant denial, stale status, invalid currency, invalid capability, duplicate quote, multi-leg restrictions, driver/vehicle evidence and notification idempotency.
5. Only then deploy approved forward-only production changes. Keep production customer/partner records, money, and real dispatch actions untouched until genuine onboarding and explicit operational approvals are in place.

## Explicit non-actions
No synthetic partner/customer/driver identities, fake compliance evidence, fabricated routes/capacity, invented quotes, test shipments, fake delivery proofs, test payments, or external notification messages were created or sent. No production access control was relaxed to make the dashboard appear operational.
