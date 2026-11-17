# KRIM Global Logistics Operating System — Global Operations Readiness

Audit date: 2026-11-07  
Environment reviewed: Supabase production project `ebltviniygljwwseplph`, GitHub PR branch `strategy/future-ready-foundation`  
Purpose: separate software capability from verified operational, commercial, legal and country readiness.

> **Decision: NOT APPROVED for unrestricted commercial shipment operations or global launch.**  
> KRIM has a substantial technical foundation and passing source-level CI checks, but the live operating network, country compliance, partner verification, rates, capacity, payment settlement evidence and end-to-end execution are not yet established. Do not treat seeded/test/legacy records as proof of real completed operations.

## 1. Executive status

| Readiness domain | Current status | Evidence / blocker |
|---|---|---|
| Repository QA | PASS — static only | PR CI production smoke and local-link audit both succeeded. No browser-based live-user test. |
| Database foundation | AMBER | Small healthy database snapshot, RLS on all public tables, but policy/function advisor items remain. |
| Identity and roles | PARTIAL | Role/permission architecture exists; cross-tenant adversarial tests across all nine user groups not completed. |
| Customer enquiry intake | PARTIAL | Public enquiry endpoint has input validation and rate-limit controls; downstream CRM/notification delivery still needs real delivery tests. |
| Partner onboarding | NOT READY FOR EXECUTION | 10 active legacy partner records, only 1 capability record and it is pending; 1 open verification case; no compliance evidence or reviews. |
| Verified service network | BLOCKED | 0 service areas, 0 capacity commitments, 0 lanes, 0 partner assignments, 0 rate cards; 7 corridors remain draft. |
| Shipment execution | BLOCKED | 18 shipment rows (8 draft, 3 quoted, 6 confirmed, 1 closed), but 0 partner assignments and only 1 shipment leg. Confirmed status alone does not prove partner acceptance or physical execution. |
| Driver operations | NOT READY | 0 driver profiles and 0 driver assignments. |
| Warehouse operations | NOT READY | 0 facilities, 0 tasks and 0 inventory rows. |
| Customs operations | NOT READY | 0 customs broker licenses, 0 broker assignments and 0 customs document submissions. |
| Tracking/POD | PARTIAL | Secure public tracking endpoint and controlled POD design exist; only 1 tracking event, no end-to-end delivery run evidenced. |
| Finance and payments | BLOCKED FOR LIVE COMMERCIAL USE | Razorpay INR adapter exists, but merchant eligibility, settlement and refund capabilities are not verified in the registry. No bank settlement proof. |
| India regulatory readiness | NOT VERIFIED | GST application was reported pending; no verified tax classification/invoice workflow or e-way bill operational proof. |
| International regulatory readiness | NOT READY | Six markets exist in catalog but all six operational activation controls are blocked; country packs are research-pending. |
| Disaster recovery | UNVERIFIED | Backup/PITR retention and successful restore test not established. |
| Customer acquisition/CRM | PARTIAL | HubSpot was previously found sample-only/read-only; Telegram test and Resend send/domain verification remain outstanding. |

## 2. Live operating-network snapshot

Read-only SQL snapshot:

- Partner records: 10, all marked active in the legacy `partners` table. This is not equivalent to verified, dispatchable KRIM partner organisations.
- Partner capabilities: 1, verification status `pending`.
- Partner verification cases: 1, status `open`.
- Partner compliance evidence: 0.
- Partner compliance reviews: 0.
- Partner service areas: 0.
- Partner capacity commitments: 0.
- Network corridors: 7, all `draft`.
- Network lanes: 0.
- Rate cards: 0.
- Partner shipment assignments: 0.
- Shipment legs: 1.
- Shipment execution readiness records: 0.
- Shipment compliance gates: 0.
- Tracking events: 1.

### Operational conclusion

The current network cannot yet substantiate a live customer promise for a route, mode, service level, transit time, capacity or rate. Keep public availability and price claims conditional on a verified partner, active service area, lane, rate card, capacity reservation and applicable compliance evidence.

## 3. Country and cross-border readiness

Six countries/markets are present: India, United Arab Emirates, Singapore, Germany, United Kingdom and United States.

- All 6 markets have operational status `blocked`, even though their catalog records are marked active.
- Country operating packs: 249, all `research_pending`.
- Country pack controls: 4,482, all `pending`.
- FX rate records: 0.
- Market readiness assessments: 82 exist, but their existence does not establish approval or activation.

### Launch rule

A market may be shown as catalogued, but must not be treated as operational until a designated compliance owner has reviewed current primary legal sources, attached evidence, completed mandatory controls, approved the market and at least one real lane, and confirmed local partner and payment capability.

For every country/lane/mode, the operating pack must cover:
1. Entity and tax registrations, invoicing, VAT/GST/sales tax and tax reporting.
2. Transport/freight-forwarding licensing and local operating restrictions.
3. Customs, import/export declarations, broker authority and trade-document rules.
4. Sanctions, restricted-party screening, export controls and prohibited/restricted cargo.
5. Dangerous goods rules by mode (road, air, ocean, rail).
6. Insurance, liability limits, claims and cargo custody.
7. Data protection, cross-border transfers, retention and breach handling.
8. Payment acceptance, merchant eligibility, FX, settlement, refunds, chargebacks and reconciliation.
9. Local partner identity, licences, insurance, fleet/facility and service-area verification.
10. Emergency contacts, incident response, continuity and customer disclosures.

Do not launch all six markets because they appear in a dropdown. India should be the first market activation only after its own control set is approved.

## 4. Payment and financial readiness

Live registry snapshot for Razorpay / India / INR:

- Integration status: `implemented`.
- Checkout flag: `true`.
- Merchant eligibility verified: `false`.
- Presentment supported: `true`.
- Settlement supported: `false`.
- Refunds supported: `false`.
- FX supported: `false`.
- Evidence reference: absent.

Other provider/currency capabilities are still planned and checkout-disabled. The registry contains 45 provider/currency capability rows; only the INR Razorpay row is marked implemented.

Payment data snapshot:
- Payment orders: 1 paid and 5 still created.
- Canonical KRIM financial transactions: 1 completed INR payment.
- Partner payout rows: 1 marked paid.
- Previous audit found four captured/order-paid webhook events that do not match current canonical payment orders, and five old created payment orders without KRIM quote binding or payment ID. These require reconciliation against the Razorpay dashboard and bank records; do not convert or delete them based only on age.

### Payment go-live gates

Before charging a customer:
1. Confirm Razorpay account/KYC/merchant eligibility for the actual KRIM legal entity and business model.
2. Confirm settlement bank account, settlement cycle, fees, refund/chargeback handling and provider terms.
3. Obtain evidence and update the INR capability registry only after verification.
4. Resolve old unmatched webhook and stale payment-order exceptions against provider records.
5. Verify GST treatment and invoice issuer/merchant-of-record role.
6. Run sandbox end-to-end payment, duplicate/out-of-order webhook, failed-then-captured retry, refund, idempotency and reconciliation tests.
7. Perform one explicitly approved low-value live transaction only after sandbox and legal gates pass, then reconcile the provider settlement to the bank statement.

A `paid` database row or an old payout row is not proof of withdrawable bank funds. Do not enable global currencies or PayPal/Stripe/Adyen until each provider's merchant eligibility, presentment, settlement, refunds and FX evidence is verified.

## 5. India legal and operating readiness

Business facts reported by the owner:
- Sole proprietorship, KRIM Logistics.
- Udyam registration successfully submitted.
- GST registration application was in progress/pending at the last reported checkpoint. Recheck current GST portal status and certificate before issuing tax invoices or charging GST.

### India checklist

- Confirm the precise legal role: disclosed agent/intermediary, marketplace, freight forwarder, logistics service provider, carrier/principal, or a combination. Contract wording, money flow, invoice issuer and control over service determine the tax and licensing treatment.
- Obtain CA advice on GST registration, place/time of supply, commission vs freight/service turnover, reverse charge, input tax credit, customer/partner invoices, TDS/TCS if applicable, and interstate/export services. The commonly cited Section 22 threshold is not a universal permission to operate without registration; statutory exceptions and notifications matter.
- Keep the GST application/certificate, PAN, business bank proof, Udyam certificate, address/NOC and books aligned.
- Design GST invoice, credit/debit note, refund, e-invoice applicability and return workflows before revenue scale.
- Add e-way bill capture/validation to shipment records. CBIC Rule 138 generally requires e-way bill information before movement for consignments above ₹50,000, subject to prescribed exceptions and responsibility depending on consignor/consignee/transporter facts.
- Verify the actual carrier's goods-carriage permit, registration, fitness, insurance, PUC, driver licence and applicable state/national permit before dispatch. KRIM should not represent itself as the physical carrier unless it holds the required authority and assumes that role.
- For import/export of goods, confirm IEC applicability and obtain/link the IEC where required. DGFT materials state IEC is generally required for import/export of goods, with specific exemptions; service exporters have different treatment and IEC may be needed when claiming Foreign Trade Policy benefits.
- Use properly licensed customs brokers for customs representation/clearance; do not offer brokerage as KRIM's own service unless the legal licensing requirements are met.
- Prepare privacy notices, purpose limitation, data-subject request handling, processor/vendor agreements, retention schedule, breach response and access logs for India's DPDP framework. Rules were notified in November 2025 with phased commencement; build compliance ahead of the applicable dates.
- Keep partner contracts, customer terms, limitation of liability, cargo insurance terms, claims procedure, dispute resolution, cancellation/refund and grievance contact consistent with the real operating model.

Official starting points:
- CBIC GST Act/registration guidance: https://cbic-gst.gov.in/
- GST e-way bill rules: https://cbic-gst.gov.in/ewaybill-rules.html
- E-way bill portal FAQs: https://docs.ewaybillgst.gov.in/html/ewb_qna.html
- DGFT IEC portal and guidance: https://dgft.gov.in/
- MeitY DPDP Rules and commencement material: https://www.meity.gov.in/

This is a launch checklist, not a legal opinion. A CA and relevant transport/customs counsel must confirm KRIM's actual contracts, invoicing and service model.

## 6. International mode-specific readiness

Do not advertise or accept international shipments until a lane-specific operating file is approved.

- Road: local carrier permits, vehicle/driver credentials, cargo insurance, cabotage, transit permits and customs/transit documents.
- Air: airline/forwarder contracts, security controls, air waybill handling, dangerous-goods acceptance and applicable IATA/ICAO requirements.
- Ocean: carrier/NVOCC/forwarder role, bill of lading authority, SOLAS verified gross mass, IMDG dangerous-goods controls, port/terminal charges and demurrage/detention terms.
- Rail: operator/railway access, wagon/container requirements, dangerous-goods rules, border/transit formalities and interchange responsibilities.
- Warehousing: facility authority, fire/safety requirements, inventory custody, security, insurance, temperature controls where relevant and auditable stock movements.
- Customs: licensed broker responsibility, importer/exporter-of-record identity, tariff/HS classification, valuation, origin, permits and documentary evidence.

KRIM can orchestrate verified licensed providers; it must not imply that the software itself holds every carrier, customs, warehouse or freight-forwarding licence.

## 7. Automated testing evidence and gaps

### Passing CI evidence

For PR #55 head commit `b0c986b57030150cb442e59d4a41f6445ff3997c`, two GitHub Actions runs completed successfully:
- `KRIM production smoke checks`: PASS. It checked 69 required paths, 67 inline scripts, 52 Customer OS pages / 433 links, and 192 HTML pages / 1,332 site links. It confirmed key source guards for checkout, partner files, pricing fail-closed behavior and privileged RPC ACL migration.
- `KRIM static link audit`: PASS. No unresolved local link references were detected by the static parser.

A repository-wide static scan covered 1,314 files and 858 HTML pages:
- 0 unresolved local references detected.
- 281 pages contained placeholder/demo/TODO wording signals (triage required; not all necessarily unfinished).
- 317 operational-looking pages had no visible Supabase/backend signal in their own HTML (shared scripts may provide integration; inspect individually).
- 182 operational pages had at least one backend-related signal (this is not proof of functional integration).
- 3 growth pages were exact duplicate content: partner-activation, partner-intelligence and partner-outreach.

### Not yet proven

- Browser-based tests across Android/mobile and desktop.
- Authenticated tests for all nine user groups and cross-tenant data isolation.
- Real partner registration, document verification, approval and service activation.
- Quote -> partner award -> capacity reservation -> assignment -> dispatch -> tracking -> POD -> invoice -> payment -> settlement -> payout.
- Warehouse receipt/QC/inventory/handover, customs broker/document lifecycle, driver app/offline sync and exception recovery.
- Payment provider sandbox tests and bank settlement reconciliation.
- Backup restoration, disaster recovery, load/concurrency, penetration and accessibility tests.
- Live external notification delivery (Telegram/email) and CRM sync.

Static smoke tests are useful regression guards, not end-to-end operational certification.

## 8. Nine user-group readiness

| User group | Current gate |
|---|---|
| Customer/Shipper | Enquiry and account flow may be demonstrated; live booking/quote only on approved lane and verified capacity. |
| Partner/Carrier | Registration/document collection can start; no partner should be dispatch-enabled before independent verification, capability, service area, insurance and capacity evidence. |
| Driver | Not operationally ready; no driver profiles/assignments in live tables. |
| Warehouse | Not operationally ready; no facilities/tasks/inventory records. |
| Customs broker | Not operationally ready; no broker licences/assignments/documents. |
| Finance | Not live-ready; merchant eligibility/settlement/refund evidence and reconciliation remain open. |
| Operations Control Tower | Platform modules exist, but no assigned partner execution network or real shipment event stream. |
| Enterprise | Workspace/features require role/tenant, billing, approval and integration validation before enterprise claims. |
| Admin | Privileged controls exist; keep AAL2/MFA and separation-of-duties requirements, and complete independent security testing. |

## 9. Launch decision and safe operating envelope

### Allowed now
- Internal demonstrations and controlled staff testing.
- Partner recruitment, registration and document collection.
- Customer enquiry capture with clear wording that routes, capacity, rates and service are confirmed only after partner verification.
- Manual partner verification and manual lane activation only after evidence and authorised review.
- Sandbox payment tests using test credentials and test data.

### Not approved yet
- Unrestricted public shipment bookings or guaranteed coverage/rates.
- Dispatching any shipment without verified partner, lane, capacity, compliance and insurance.
- Treating draft corridors, active catalog markets or legacy partner records as operating coverage.
- Live commercial checkout until merchant eligibility, settlement, refund, tax and reconciliation gates are met.
- International shipment execution in any of the six currently blocked markets.
- Representing KRIM as a licensed carrier, customs broker, warehouse operator or global freight forwarder without the relevant legal authority and contractual role.

## 10. Prioritised completion plan

1. **Partner activation:** independently verify the first real partner organisation; collect and review business, tax, bank, insurance, licences and fleet/facility evidence.
2. **India pilot lane:** activate one real origin-destination lane and mode only after compliance and operational approval.
3. **Commercial setup:** approve partner buy rate, customer sell rate, fees/commission, tax treatment, quote validity and cancellation terms.
4. **Capacity:** record evidenced capacity, reservation and assignment controls.
5. **Shipment E2E:** run one controlled shipment through all milestones and independently verified POD.
6. **Payments:** complete Razorpay merchant eligibility, settlement/refund evidence, sandbox tests and reconciliation; then controlled live transaction.
7. **Finance/legal:** GST certificate/status, invoice model, returns, bank reconciliation, partner payable/payout control and claims.
8. **Operational teams:** onboard at least one verified driver and any required warehouse/customs providers for the pilot mode/lane.
9. **Technical assurance:** tenant isolation, browser/mobile, API abuse, file upload, monitoring, backup restore and load tests.
10. **Expansion:** complete each country's operating pack, local partner, licensing, tax, payment and lane proof before activating UAE or any further market.

## 11. Audit boundary

This readiness assessment is based on read-only database queries, Supabase advisors and function source inspection, existing GitHub Actions results, and a static repository audit. No production records, market activation flags, partner approvals, rates, payment capability flags, Edge Functions, secrets, indexes, policies or cron jobs were changed. No live payment, shipment, refund, payout, customer notification or partner message was initiated.

**Reassessment trigger:** repeat this audit after the first verified partner, first approved India lane, first successful end-to-end shipment and first reconciled bank settlement.
