# KRIM Logistics — India Controlled Launch Gate
**Date:** 27 November 2026  
**Environment:** Staging planning artifact; no production changes  
**Decision:** NOT CLEARED for live transactions or unrestricted onboarding

## Purpose
This is the single launch-control checklist for the first controlled India activation. It prioritizes only work that can block safe onboarding and the first real customer-to-partner logistics transaction. Global expansion features are deliberately outside this initial gate unless they affect an India route.

## Launch model and non-negotiable boundaries
- Initial model: referral, marketing and coordination marketplace, subject to written CA/legal confirmation.
- Partners publish eligible services and quote/contract directly with customers.
- Customers pay freight charges directly to the contracted partner.
- KRIM does not collect or hold freight money, issue partner freight invoices, or settle partner freight.
- KRIM may collect only separately documented and legally approved KRIM fees through its own business account.
- No paid transactions until the business bank account, tax treatment, contracts, fee invoicing and accounting process are confirmed.
- No production database, payment gateway, or live provider activation as part of this checklist without explicit approval.

## Gate A — Legal, tax and business readiness (HARD GATE)
| Item | Current known position | Evidence required to pass |
|---|---|---|
| Proprietorship and Udyam | Completed | Registration records retained |
| GST position | Application rejected 11 Nov 2026 due to address-proof issue; no active GST established | CA confirms whether GST registration is currently required and the lawful route to operate |
| Marketplace/agency treatment | Not confirmed | Written CA/legal opinion covering referral/coordination model, ECO/agency exposure, invoicing and tax |
| Customer and partner contracts | Legal review required | Approved partner terms, customer terms, service scope, liability, cancellation, claims and dispute process |
| Privacy and data protection | Launch review required | Published and reviewed privacy notice, consent/retention and grievance contact |
| Business bank account | Not confirmed | Account ownership and permitted business receipts verified |
| KRIM fee policy | Not final-approved | Written fee schedule, trigger, payer, tax treatment, invoice/receipt and refund rules |

**Pass rule:** All legal/tax items affecting the proposed transaction model are documented and approved by the appropriate CA/legal professional. Do not infer clearance from Udyam or a website disclaimer.

## Gate B — Financial controls (HARD GATE)
- [ ] Business account is active and suitable for KRIM business receipts.
- [ ] KRIM fee collection is separate from freight payment.
- [ ] Fee calculation, approval, invoice/receipt and ledger entries are tested.
- [ ] Refund, cancellation, chargeback/dispute and reconciliation procedures are documented.
- [ ] No live gateway or freight collection path is enabled accidentally.
- [ ] Cashfree legacy routes are disabled or proven unreachable for the launch scope.
- [ ] Razorpay or another provider is not activated until account, domain, KYC and legal prerequisites are satisfied.
- [ ] Finance owner can reconcile every KRIM receipt to a customer/partner agreement and invoice.

**Pass rule:** A controlled test of KRIM's own fee lifecycle passes without moving or holding freight funds.

## Gate C — Platform security and environment safety (HARD GATE)
- [ ] Phase 00 exit criteria are independently rechecked on Staging.
- [ ] Staging and Production project IDs, secrets, URLs and deployment targets are isolated.
- [ ] RLS/RBAC gaps are closed or formally proven out of launch scope; no broad grants to make testing easier.
- [ ] Owner/admin privileged actions require the approved strong-authentication and role checks.
- [ ] Workflow test lane/queue is isolated from production business events, notifications and workers.
- [ ] Production workers cannot claim test work; test workers cannot claim production work.
- [ ] Notification and email workers are scoped; no real provider sends during tests.
- [ ] Secrets, logs, error responses and audit trails are reviewed for leakage.
- [ ] Backup, restore and rollback procedures are demonstrated.
- [ ] No unresolved critical/high security finding remains in launch scope.

**Current known status:** Phase 00 remains OPEN. Workflow lane isolation and notification side-effect isolation are blockers. No live workflow or provider test should be run until safe isolation is implemented and verified.

## Gate D — Minimum India operating workflow (HARD GATE)
Run separate test accounts for customer, partner, driver and owner/admin. Use non-production fixtures only.
- [ ] Customer registration, verification, organization membership and access controls.
- [ ] Partner registration, document review, capability and route/coverage verification.
- [ ] Partner is not marketplace-eligible until required verification/compliance checks pass.
- [ ] Customer request creation and validation.
- [ ] Partner opportunity delivery and quote submission.
- [ ] Customer quote review and acceptance with clear partner identity and direct-payment terms.
- [ ] Booking/shipment creation, status history and audit evidence.
- [ ] Driver assignment, acceptance/rejection and reassignment controls.
- [ ] Tracking/status updates and exception handling.
- [ ] Cancellation, failed assignment, quote expiry and dispute paths.
- [ ] Mandatory transactional/security notifications, in-app history, retry and failure visibility.
- [ ] Essential service notifications cannot be disabled; marketing preferences remain separate.
- [ ] No duplicate booking, quote acceptance, assignment, fee or event on retry.
- [ ] End-to-end regression passes on supported India launch routes.

**Pass rule:** All critical scenarios pass with recorded evidence, no cross-tenant access and no external side effects from test data.

## Gate E — Real network and operating readiness (HARD GATE)
- [ ] At least one partner per initially activated service/route is verified and contractually approved.
- [ ] Partner service area, capacity, operating hours, pricing/quote method and escalation contact are confirmed.
- [ ] Partner onboarding records and documents are reviewed by an authorized operator.
- [ ] Driver onboarding/verification and assignment responsibility are clear wherever KRIM coordinates drivers.
- [ ] Customer support contact, response hours and escalation owner are published.
- [ ] Operations owner can monitor enquiries, quotes, bookings, exceptions and cancellations.
- [ ] A route is marked available only after its partner and service readiness are confirmed.
- [ ] Prospective leads are clearly distinguished from verified/eligible participants.

## Gate F — Production release and controlled activation (HARD GATE)
- [ ] Release candidate is tagged and tested; Staging evidence is retained.
- [ ] Production environment configuration is reviewed without exposing secrets.
- [ ] Production migrations are reviewed, backed up and approved separately.
- [ ] Smoke tests, monitoring, alerting and rollback are ready.
- [ ] Production deployment receives explicit owner approval.
- [ ] First activation is limited to approved India routes, service types and a small cohort.
- [ ] Manual operations fallback and incident contact are available.
- [ ] First live transaction is monitored from enquiry through completion and KRIM fee reconciliation.
- [ ] Expansion is paused if a critical defect, financial mismatch, security incident or partner-service failure occurs.

## Launch decision
**No-go today.** The business has Udyam registration, but GST/CA/legal treatment, bank confirmation, platform security, workflow isolation, end-to-end acceptance and verified operating partners are not yet all evidenced as complete.

### Minimum viable controlled-launch sequence
1. Obtain CA/legal and bank confirmation for the no-freight-collection referral/coordination model.
2. Close Phase 00 security/environment and workflow/notification isolation blockers on Staging.
3. Complete the minimum customer → partner → quote → acceptance → shipment → driver (where applicable) → notification → fee-record E2E suite.
4. Verify KRIM fee accounting and ensure freight payment/settlement remains disabled.
5. Verify at least one real partner and service-ready route, plus support/operations coverage.
6. Approve and deploy a limited production release with rollback and explicit owner sign-off.

## Work priority — fast-track only launch blockers
**P0:** Legal/tax/bank confirmation; Phase 00 security and isolation; core booking/quote/onboarding E2E; fee accounting and payment boundary.  
**P1:** Verified partner/route supply; driver readiness where applicable; notifications, support, cancellation and dispute handling; production rollback/monitoring.  
**Later:** UAE/global rollout, broad currency/time-zone coverage, nonessential advanced analytics, large-scale automation and features not needed for the first India routes.

## Evidence discipline
Each checkbox is PASS only when there is dated evidence (test result, approved document, configuration review or operational record). “Built”, “deployed”, “present in code” or “page exists” is not proof of operational readiness. Keep Production untouched until the separate release gate is explicitly approved.
