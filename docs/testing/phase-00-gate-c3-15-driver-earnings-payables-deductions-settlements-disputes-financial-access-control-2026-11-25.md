# Gate C3.15 — Driver earnings, payables, deductions, settlements, disputes and financial access control

**Programme:** KRIM GLOBAL PLATFORM — AI QUALITY ASSURANCE, SIMULATION & RELIABILITY PROGRAMME  
**Gate:** Phase 00 / C3.15  
**Source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**QA branch:** `qa/phase-00-baseline-2026-11-25`  
**Review date:** 2026-11-25  
**Disposition:** **FAIL / BLOCKED for a KRIM-managed driver earnings or payout capability. PARTIAL PASS for the safer partner-direct model and finance controls.**

## 1. Scope and method

Read-only source review of:
- Driver earnings and settlement workspace `app/driver/module-13-earnings-settlements.html`
- Driver earnings legacy route `public/driver/driver-earnings.html`
- Driver expense-submission legacy route `public/driver/expense-submission.html`
- Partner earnings, deductions and payout legacy routes
- Finance partner settlements, accounts payable, revenue/commission, refunds/disputes and treasury audit workspaces
- Payable idempotency migration `20261017134500_enforce_partner_payable_assignment_idempotency.sql`
- Revenue allocation and recognition migrations `20261017093454_fix_revenue_allocation_idempotency_and_recognition.sql`, `20261017133000_enforce_revenue_allocation_idempotency.sql`
- Finance read-policy consolidation `20261105100500_consolidate_finance_and_exception_read_policies.sql`
- Finance write restrictions `20261107210000_restrict_direct_finance_table_writes.sql`
- Dispute register hardening `20261107221000_harden_dispute_register_access.sql`
- Finance chart/mapping and multileg posting controls `20261106055441_configure_finance_inr_account_mappings_and_posting_rules.sql`, `20261107230000_initialize_finance_chart_of_accounts_inr.sql`, `20261115151545_block_unallocated_multileg_finance_postings.sql`
- Payment registry RLS and anonymous-access restrictions.

This is source inspection only. No database query, RPC, browser sign-in, payable creation, expense submission, dispute, payout, bank transfer, provider call or financial mutation was executed. No Production or Staging records were accessed or changed.

## 2. Critical business-model distinction

The current driver page explicitly describes a **partner-direct payment model**: the driver's contracting carrier/employer agrees and pays wages or trip earnings directly; KRIM does not hold or disburse driver wages through this page. This is the safer and more accurate current operating position.

The repository contains KRIM finance/partner payable concepts, but their existence does not establish a driver-level payable contract, approved driver rate, earned amount, deduction authorization, payroll obligation or driver payout. A partner payable to a carrier is not automatically a payable to that carrier's individual driver.

## 3. Positive source controls

1. Driver earnings page deliberately avoids estimating pay from trip count, distance or shipment value. It displays assignment activity only and explicitly says the earnings feed is not connected.
2. Driver page checks an authenticated Supabase session, requires exactly one active driver membership, verifies the organization is active, and queries assignments scoped to the signed-in user. No monetary amounts or settlement status are displayed.
3. Driver earnings and expense-submission legacy URLs redirect into the driver operations workflow rather than exposing their former standalone pages.
4. Partner earnings, penalties/deductions and payout-history legacy routes explicitly state that the prior interfaces were not verified database-backed workflows and redirect to the authenticated Partner Workspace.
5. Finance partner-settlements page checks authenticated identity, active organization membership and `finance.view`; it explicitly withholds partner payable data pending dedicated backend isolation and settlement authorization. It does not create invoices, payments, payouts, refunds or journal entries.
6. Accounts-payable and revenue/commission finance pages are review-preparation interfaces. Their browser forms validate fields only and explicitly do not save or execute financial actions.
7. Finance table writes for payment orders, ledger accounts and reconciliation exceptions are revoked from browser roles; authenticated read is granted. This reduces the risk of direct client-side financial mutation.
8. Private payment registry RLS and anonymous-access revocations exist; anonymous users are denied access to payment orders, financial transactions and partner payables.
9. Finance read policies scope invoices and settlements by organization permission or authorized finance organization membership. Dispute tables have forced RLS, anonymous/public access revoked, and authenticated access limited to select.
10. Partner payable idempotency is reinforced by a unique index on non-null `krim_partner_payables.assignment_id`, preventing more than one payable row per assignment at the index level.
11. Revenue allocation references and runs have uniqueness/idempotency constraints. Delivered revenue recognition locks the shipment, requires delivered state and a financially eligible customer invoice, and avoids repeating already recognized allocation references.
12. Finance configuration includes INR chart-of-account roles for bank, receivable, revenue, partner payable and partner funds. This is configuration, not proof of live balances, payout funding or reconciled books.
13. Multi-leg shipment financial postings are blocked until leg-level commercial allocation, partner invoicing and KRIM fee recognition are reconciled.

## 4. Findings and release risks

### P1 — No driver earnings source of truth or driver-level payable contract
No reviewed source establishes a canonical driver earnings ledger linked to a verified driver contract/rate card, completed eligible work, approved trip evidence, currency, tax treatment, earning period and payable amount. The driver workspace says the feed is not connected and intentionally displays no balances.

**Impact:** KRIM cannot truthfully show a driver an earned balance, amount due or settlement estimate. A shipment/assignment or carrier payable cannot substitute for a driver payroll record.

### P1 — No driver payout or settlement execution workflow
No driver-level settlement batch, payment instruction, payout provider integration, bank beneficiary verification, payout status reconciliation, returned-payment handling or payment reference is established. Current partner-direct model places wage payment with the contracting carrier/employer, not KRIM.

**Impact:** Do not claim KRIM pays drivers or offers driver wallet, instant payout, escrow or settlement services. Partner-direct payments should remain explicit until a separately approved driver payment model is designed and legally reviewed.

### P1 — No approved driver deduction/expense policy and workflow
The standalone driver expense submission and partner deduction pages are retired/redirected. The reviewed driver earnings page directs drivers to their carrier/employer and refers to documented, authorized adjustments, but no complete expense claim approval, receipt validation, deduction category/legal basis, driver consent/notice, dispute window, cap or payroll reconciliation workflow is established.

**Impact:** No deductions, penalties, advances, fuel/maintenance recovery or expense reimbursement should be calculated or applied by KRIM without contract/policy authority, evidence, review and appeal controls.

### P1 — Partner payables are not driver payables
The unique assignment index prevents duplicate partner payable rows for a given assignment, but does not prove correct payable calculation, partner invoice acceptance, source contract/rate version, tax/withholding, currency conversion, dispute hold, approval separation, payment execution or reconciliation. Nor does it identify a driver beneficiary or split a partner payable into driver payroll.

**Impact:** A unique row is only an idempotency guard; it is not proof that the payable is valid, correctly calculated or settled.

### P1 — Partner settlement workspace deliberately does not load financial records
The finance partner-settlements UI verifies a session, active membership and `finance.view`, then explicitly withholds payable data pending dedicated backend isolation and settlement authorization. It is a review placeholder, not a live settlement register.

**Impact:** Finance users must not rely on this interface as a complete partner payable or settlement control tower.

### P1 — Dispute and refund workflows do not prove driver-pay dispute resolution
Dispute tables have strong access restrictions, and the refund workspace describes historical KRIM-collected payment requests while refund execution is disabled. No end-to-end driver wage dispute process is established: driver complaint intake, amount/period/contract evidence, employer response, independent decision, appeal, statutory timelines, correction and payout adjustment.

**Impact:** Do not market the generic dispute/refund module as a driver payroll dispute service.

### P2 — Finance read policy is permission-scoped but effective tenant isolation needs runtime tests
Finance policies permit reads where a user has `finance.view` on relevant organization identifiers and allow finance organization membership with that permission. Correctness depends on the full permission function, organization membership lifecycle, table grants, policy composition and related views/functions. The source review does not prove cross-tenant isolation for every payable, invoice, settlement, journal and dispute relation.

### P2 — Deduction and expense evidence retention/integrity is not established
No complete evidence lifecycle was established for receipts, trip expense proofs, approval records, immutable versions, hashes, malware scanning, retention, legal holds and deletion controls.

### P2 — Global payroll, tax, currency and employment classification are not in scope of a verified workflow
No jurisdiction-aware driver employment/contractor classification, payroll tax, withholding, social contribution, minimum wage, overtime, payslip, FX conversion or country-specific payout controls are established by this gate. KRIM should not generalize an India/INR finance chart into global payroll readiness.

### P2 — Ledger setup does not prove live balanced books or payout cash availability
The chart-of-accounts migration explicitly creates account definitions and mappings only. No evidence in this gate proves live balances, fully posted double-entry journals for every financial event, bank reconciliation, payout funding or a completed settlement.

## 5. Required remediation / operating decision

1. Preserve partner-direct driver pay as the current operating model. Display a clear statement that the carrier/employer is responsible for agreed driver pay and KRIM is not the driver's payroll provider.
2. Keep driver earnings feed and KRIM driver payout actions disabled until a documented business/legal decision authorizes KRIM to become a paymaster or payment intermediary.
3. If driver-level visibility is needed, build a read-only statement import/attestation model first: contracting partner, driver, assignment, rate agreement version, gross earned, authorized adjustments, net payable, currency, earning period, statement source and dispute status. Do not calculate from shipment revenue alone.
4. If KRIM-managed payouts are later approved, implement a separate driver-pay ledger and beneficiary identity verification, source-of-funds controls, double-entry journal, approval separation, idempotent payout instructions, provider webhook reconciliation, failure/return recovery and audit.
5. Create documented, jurisdiction-specific rules for expenses, advances, deductions, penalties, reimbursement, evidence, notice, consent where required, appeal and dispute windows. Never permit unilateral arbitrary deductions.
6. Build driver dispute intake with scoped access, evidence, response deadlines, independent review, appeal, correction entries and mandatory notification/acknowledgement.
7. Complete full partner payable calculation and settlement verification: source contract/rate card snapshot, assignment/leg and verified completion, invoice matching, taxes, currency precision, deductions/credits, approval, payable release, payment reference and bank reconciliation.
8. Verify RLS, grants, views, SECURITY DEFINER ACLs, permission freshness and cross-tenant negative cases in isolated Staging before any finance data is exposed.
9. Run concurrency/idempotency tests for duplicate assignment payable, competing invoice revisions, repeat settlement, provider webhook duplicates, partial/failed payout, dispute hold, FX rounding and retry/reconciliation. Use synthetic data only.
10. Keep all financial UI language aligned to actual capability: “partner payable” is not “driver earnings”; “request recorded” is not “refund paid”; “settlement status” is not “bank payout confirmed”.

## 6. Verification matrix

| Check | Result | Evidence / limitation |
|---|---|---|
| Driver page avoids fabricated earnings | SOURCE PASS | Explicitly shows no earnings feed; assignment activity only. |
| Driver identity/membership scope | SOURCE PASS / PARTIAL | Auth session, exactly one active driver membership and active organization; table RLS runtime not tested. |
| Driver-level earnings ledger/rate contract | FAIL / NOT ESTABLISHED | No verified driver payable source of truth found in reviewed paths. |
| Driver payout workflow | FAIL / NOT ESTABLISHED | No beneficiary/payout execution and reconciliation flow established. |
| Driver expense submission | BLOCKED | Legacy route redirects; no active persisted workflow established. |
| Driver deductions/penalties | BLOCKED | Legacy partner page retired; no approved deduction workflow established. |
| Partner payable assignment idempotency | SOURCE PASS | Unique index on non-null assignment_id. |
| Partner payable calculation validity | NOT TESTED / BLOCKED | Contract/rate/tax/approval/payment calculation not established by idempotency index. |
| Partner settlement UI | SOURCE PASS for fail-closed posture | Requires finance.view then withholds data; no settlement records loaded. |
| Finance browser write restrictions | SOURCE PASS | Direct writes revoked on selected payment/ledger/reconciliation tables. |
| Finance and settlement RLS tenant isolation | PARTIAL / NOT TESTED | Policies inspected; effective grants/policy composition and negative runtime cases untested. |
| Dispute table access restrictions | SOURCE PASS / PARTIAL | FORCE RLS and client-role revocations; complete dispute workflow not established. |
| Driver payroll dispute/appeal | BLOCKED | No end-to-end workflow established. |
| INR chart/mappings | SOURCE PASS for configuration only | Chart and account-role mappings; no proof of live balances or settled funds. |
| Multileg finance posting guard | SOURCE PASS | Trigger blocks unallocated multi-leg finance postings. |
| Ledger balance and bank reconciliation | NOT TESTED | No live reconciliation performed. |
| Cross-tenant, concurrency and payout failure tests | NOT TESTED | Requires isolated Staging synthetic identities and provider mocks. |
| Global payroll/tax compliance | NOT TESTED | Jurisdiction-specific legal/accounting review required. |

## 7. Change and safety record

- No Production or Staging SQL, RPC, RLS, grant, table, row, account, secret, provider, deployment or Storage object was changed or invoked.
- No payable, expense, deduction, settlement, refund, dispute, journal entry or payout was created or modified.
- No real money moved and no provider webhook or bank transfer was triggered.
- No notification was sent and no driver/partner was contacted.
- Documentation-only QA branch change.

**Gate C3.15 result: FAIL / BLOCKED for KRIM-managed driver earnings/payout. PARTIAL PASS for partner-direct model and source-level finance access controls.** Maintain partner-direct driver pay and do not expose driver earnings balances, deductions or payout claims until a verified contract-backed workflow and isolated runtime tests exist.
