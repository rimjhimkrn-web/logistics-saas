# KRIM India Commercial Launch Gate Register

**Snapshot:** 5 November 2026  
**Purpose:** Convert KRIM's India-first ambition into a controlled, evidence-led commercial launch.  
**Decision status:** **NOT CLEARED FOR COMMERCIAL SHIPMENT BOOKINGS.** This is a launch-control register, not legal advice or a certificate of compliance.

## 1. Verified platform snapshot

The following values were read from the connected production Supabase database on 5 November 2026:

| Control | Current evidence-backed state |
|---|---:|
| India country operating pack | 1 pack |
| India country controls | 18 |
| India controls approved | 0 |
| India market readiness assessments | 22 |
| India assessments approved | 0 |
| Active, verified India partner capabilities | 0 |
| Network corridor catalogue | 7 records |
| India corridor records | Ranchi–Kolkata and Ranchi–Jamshedpur are draft candidates |
| Approved India corridor dossiers | 0 |
| Shipments in database | 18 (records do not prove commercial fulfilment) |
| Quotes in database | 7 (records do not prove accepted or fulfilled business) |

A country, market, corridor, partner profile or database record is not proof of operational service coverage. The two domestic corridor records are candidates only. Do not publish availability, rates, transit times or service guarantees for them.

## 2. India launch workstreams and hard gates

### Gate A — Business and legal operating model
- Obtain written Indian counsel opinion on KRIM's actual role(s): marketplace/e-commerce entity, agent/broker, goods-booking intermediary, logistics service provider, common carrier, or a combination.
- Specifically assess the Consumer Protection (E-Commerce) Rules as amended in 2021 and the legal-form/establishment requirements applicable to the actual operating model. Do not rely on an outdated summary of the original 2020 rule.
- Obtain a separate written Carriage by Road Act, 2007 opinion before KRIM books, arranges, brokers or undertakes carriage. Confirm whether registration as a common carrier is required for the actual activities.
- Confirm sole-proprietorship eligibility, contracting party, liability and insurance structure before accepting commercial orders.
- Complete the GST registration application and obtain professional advice on marketplace operator/ECO classification, invoicing, TCS under section 52, section 9(5) notified services, supplier registration and place/time of supply.

**Release evidence:** signed counsel/CA/CS opinions, applicable registration/licence numbers, filed acknowledgements and approved contract model.

### Gate B — Customer funds and payments
- Document who contracts with the shipper, who is merchant of record, who receives customer money, whether KRIM ever holds or controls funds, and who pays the carrier.
- Obtain payment-provider and legal advice confirming that the configured Razorpay flow is permitted for KRIM's actual model.
- Do not pool, hold, route or settle partner/customer funds as a self-operated payment aggregator.
- Test payment success, failure, duplicate webhook, refund, chargeback, reconciliation, ledger posting and partner payout with low-value controlled transactions only after legal/payment sign-off.
- Confirm settlement, invoice, GST and accounting treatment before live collection.

**Release evidence:** approved funds-flow diagram, provider approval, test evidence, reconciled ledger and refund procedure.

### Gate C — Real carrier and service capacity
- Recruit at least one genuine India road carrier for the selected pilot lane.
- Verify legal business identity, applicable common-carrier registration/authority, GST/PAN and bank ownership, insurance, vehicle registration/fitness/permits, driver identity/licence, safety controls, service area, capacity and signed agreement.
- Verify the carrier's named operational contact and escalation path.
- Keep development/test partners separate from commercial eligibility.

**Release evidence:** approved partner verification case, current documents, active capability, signed agreement and validated capacity.

### Gate D — Pilot corridor
- Select one domestic pilot corridor only after the carrier, route, cargo scope and customer demand are verified.
- For the Ranchi–Jamshedpur or Ranchi–Kolkata draft candidate, confirm real origin/destination serviceability, route restrictions, vehicle class, loading/unloading, transit estimate evidence, toll/fuel assumptions, cargo exclusions and emergency handling.
- Complete the corridor dossier and all mandatory controls. The country pack and market readiness gates remain independent and must also pass.
- No invented tariff: use a verified partner quote or a properly approved, evidenced rate card.

**Release evidence:** approved corridor dossier, source-backed route controls, verified carrier coverage, rate evidence and operations sign-off.

### Gate E — Customer, partner and operational safeguards
- Complete customer terms, cancellation/refund policy, privacy notice, grievance contact and complaint/escalation process.
- Complete partner contract, service levels, cargo liability, loss/damage claims, insurance requirements and dispute process.
- Test customer request → quote → acceptance → shipment → dispatch → driver assignment → milestone updates → proof of delivery → invoice → payment reconciliation → cancellation/refund.
- Test access isolation for all nine user types; ensure Admin remains private and privileged actions require appropriate assurance.
- Test document upload/download access, tracking-token privacy, rate limits, audit logs, backups, incident response and recovery.
- Ensure no test data, demo users or sample rates are visible as real commercial supply.

**Release evidence:** signed test report, negative-access tests, incident contacts, support ownership and approved customer-facing disclosures.

### Gate F — State and workforce readiness
- Confirm Jharkhand and each operating state's applicable Shops and Establishments, professional tax, labour, contractor, wage, social-security, occupational safety and local registrations based on KRIM's actual workforce and contractor model.
- Verify driver/vehicle compliance, insurance and road permits for each movement.
- Do not treat independent-contractor wording as a substitute for statutory classification.

**Release evidence:** state-specific CA/CS/labour counsel checklist and current partner/driver/vehicle documents.

## 3. Controlled launch sequence

1. **Legal model first:** written legal and tax opinions; complete GST and applicable transport registration.
2. **Payment model second:** written funds-flow approval and provider confirmation.
3. **Supply third:** verify one real carrier and its vehicles/drivers/insurance.
4. **Lane fourth:** approve one domestic pilot corridor and cargo scope.
5. **Quality fifth:** complete end-to-end, security, refund and reconciliation tests.
6. **Limited launch:** invite-only, low-volume pilot with clear support and incident escalation; no public national coverage claims.
7. **Scale only after evidence:** add a state, service mode or corridor through the same gated process.

## 4. Permitted interim activity

Until the gates above pass, KRIM may continue platform development, partner discovery, non-binding partner discussions, internal test workflows and carefully worded customer-interest collection. Do not accept confirmed transport bookings, promise a carrier/route, issue a fabricated rate or collect shipment money for a service that is not legally and operationally cleared. Have Indian counsel review even public enquiry/marketing language against the actual product.

## 5. Admin control workspaces

- India market readiness assessments: `app/platform-admin/market-readiness.html`
- Country operating packs: `app/platform-admin/country-packs.html`
- Corridor compliance dossiers: `app/platform-admin/corridor-compliance.html`
- Regulatory source register: `app/platform-admin/regulatory-sources.html`
- Partner verification: `app/platform-admin/partner-verification.html`
- Partner capability review: `app/platform-admin/partner-capabilities.html`

These workspaces support evidence capture and approvals. Their existence does not mean the controls have been completed or that the user-facing commercial operation is live.

## 6. Stop conditions

Keep commercial activation blocked if any of the following is true: legal role unresolved; required registration/licence missing; funds flow not approved; carrier not verified; corridor not approved; cargo eligibility unknown; insurance absent/expired; quote unsupported; end-to-end payment/refund reconciliation fails; critical security test fails; customer grievance path unavailable.

**Owner:** KRIM founder and designated legal, tax, finance, partner-verification and operations reviewers.  
**Review cadence:** weekly while preparing launch; immediately after any legal, payment, partner, route or service-scope change.
