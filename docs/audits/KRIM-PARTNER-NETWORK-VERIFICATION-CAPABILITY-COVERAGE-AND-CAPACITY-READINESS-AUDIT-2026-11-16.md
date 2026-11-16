# KRIM Partner Network, Verification, Capability, Coverage and Capacity Readiness Audit
**Date:** 16 November 2026  
**Scope:** Read-only review of production partner, verification, capability, service-area, capacity, assignment and performance records, plus previously inspected onboarding/verification/capacity/dispatch RPC definitions. No partner was contacted, approved, assigned, contracted, or modified; no capacity was registered or reserved.

## Executive decision
**NO-GO for representing KRIM as having a verified, dispatch-ready partner network.** The database contains 10 legacy partner rows, one partner verification case, and one capability row. The sole capability is pending and inactive. There are zero partner service-area records, zero capacity resources, zero capacity reservations, zero capacity bookings, zero shipment-partner assignments, and zero performance metrics/events. The existence of partner rows is not evidence of a verified provider or live service coverage.

## 1. Production network baseline
| Object | Rows | Interpretation |
|---|---:|---|
| Legacy `partners` | 10 | Existence only; status distribution not returned by the read-only query |
| Partner verification cases | 1 | Verification not established by row count alone |
| Partner capabilities | 1 | `verification_status=pending`, `active=false` |
| Partner service areas | 0 | No service geography recorded |
| Capacity resources | 0 | No declared/approved fleet, vehicle, warehouse or other resource |
| Capacity reservations | 0 | No committed capacity |
| Capacity bookings | 0 | No capacity bookings |
| Shipment-partner assignments | 0 | No partner currently assigned to a shipment |
| Performance metrics | 0 | No measured operational track record |
| Performance events | 0 | No evidence-backed performance history |

## 2. Positive workflow controls found in prior RPC review
- Partner capability review requires AAL2, platform-admin permission, no self-approval, evidence ownership and current partner compliance, plus active country/mode.
- Capacity resource registration requires active organization membership, `partner.manage`, registered business, current compliance, approved capability and private evidence; new resources begin pending/unavailable.
- Capacity resource approval is an independent AAL2 review and prohibits self-approval.
- Capacity reservation locks relevant shipment/leg/resource rows, validates exact leg and assignment, approved capability, physical capacity and overlap, and uses idempotency.
- Driver acceptance checks user ownership, active membership, verified driver, current licence, accepted evidence, active verified vehicle, mandatory documents and partner capability.
- Dispatch authorization requires shipment.dispatch, accepted exact-leg assignment, confirmed exact-leg capacity binding/reservation, road driver/vehicle evidence and later-leg custody; live trigger review confirmed additional current compliance/capability and warehouse handover guards.

These are meaningful design controls, but they are not evidence that a real partner has completed them or that staging E2E tests have passed.

## 3. Critical gaps
1. **No verified and active capability:** the only capability record is pending and inactive.
2. **No geography/service coverage:** service-area table is empty; no partner can be truthfully advertised for a specific origin/destination/service.
3. **No physical capacity:** no approved resources or capacity reservations; availability cannot be promised.
4. **No active assignment or service evidence:** no shipment-partner assignments or partner performance events/metrics.
5. **No executed commercial agreements:** no executed partner service contract was verified in the current evidence set. Do not imply that onboarding acceptance equals a signed service agreement.
6. **Legacy and canonical records may diverge:** legacy `partners`, `partner_documents`, `partner_drivers` and `partner_fleet` coexist with newer organization-scoped verification, capability, capacity and driver evidence. All user-facing service claims must use the canonical approved organization-scoped records, not stale legacy rows.
7. **Insurance and licence evidence need lifecycle enforcement:** partner compliance and private evidence controls exist, but exact document categories, jurisdiction/mode applicability, renewal, expiry/revocation, insurer/coverage scope and claims verification need staging and legal review.
8. **Partner onboarding evidence owner/path:** previous RPC inspection found user/org path scoping but did not establish an explicit comparison with storage object owner_id in every upload path; verify bucket policies and object ownership in staging.
9. **Performance metrics have no empirical basis:** ratings/performance UI must not imply reliability or service levels while metrics are empty.

## 4. First domestic pilot partner acceptance standard
For a proposed India domestic pilot only, require:
- Legal identity and business registration verification, entity/owner/authorized signatory checks.
- Relevant GST/tax status and invoice treatment reviewed by a qualified CA; KRIM must not infer exemption.
- Applicable transport permits/licences and vehicle/driver documents, verified against official sources and effective dates.
- Insurance certificate, insurer, policy number, coverage type, limits, territory, cargo exclusions, validity and claims contact; validate directly with issuer where feasible.
- Written service scope, operating locations, cargo restrictions, mode, handling requirements, operating hours, cut-off times and emergency contacts.
- Evidence-backed service area for the exact corridor, not generic city/state claims.
- Fleet/resource details with capacity units, availability windows, maintenance/fitness and independent approval.
- Rate card, accessorials, fuel/toll/waiting/detention, cancellation, claims and liability allocation.
- Signed partner agreement and data-protection/confidentiality terms.
- Named operational escalation owner and proof-of-delivery process.
- Staging test of quote, acceptance, assignment, capacity binding, dispatch, tracking, exception, POD and settlement-free closeout.

## 5. Network operating policy
- Do not publish a partner as verified until legal/compliance review and required evidence are current.
- Do not show a mode or service as available without an approved capability.
- Do not show a geography as covered without an approved effective service-area record.
- Do not show capacity as available unless a current approved resource and time-window calculation support it.
- Do not promise dispatch until assignment, driver/vehicle and capacity binding are confirmed.
- Re-check licence, insurance, capability, partner compliance and route/corridor activation at quote, assignment and dispatch boundaries.
- Suspend new bookings immediately when evidence expires, is revoked, or a partner is suspended; preserve audit history and handle in-flight shipments through controlled exception processes.
- Make partner self-approval impossible; preserve AAL2 maker-checker decisions and evidence provenance.

## 6. Recommended acquisition sequence
1. Recruit one established regional logistics operator for the proposed Jharkhand–West Bengal domestic pilot candidate.
2. Confirm exact legal entity, service scope, route, transport mode, equipment, insurance and rate.
3. Complete organization-scoped onboarding and private evidence submission.
4. Independently review and approve partner verification and each applicable capability.
5. Approve exact service areas and physical capacity resources.
6. Sign partner service agreement and define customer-facing terms.
7. Run synthetic staging E2E tests without real shipment or money movement.
8. Only after market/corridor activation and all other release gates pass, seek explicit approval for a limited live pilot.

## 7. Change control and release gate
This was read-only. No partner rows or documents were created/modified; no partner was contacted, verified, approved, contracted, or assigned. No capacity or shipment was created. Production migration reconciliation remains unresolved; do not implement schema/function fixes until the migration crosswalk and sanitized schema manifest are reconciled.

**Release status: NO-GO for verified-network claims, live service availability, partner assignment or dispatch.** KRIM has partner onboarding and dispatch control workflows, but no operational partner capacity is evidenced in production.
