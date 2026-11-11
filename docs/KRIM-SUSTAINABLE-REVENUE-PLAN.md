# KRIM Sustainable Revenue & Commercial Activation Plan
Date: 11 November 2026
Status: strategy and readiness baseline; not a claim of commercial launch readiness.

## Objective
Prove recurring, repeatable revenue from real paying businesses while preserving the long-term global logistics marketplace. KRIM must measure collected cash, recognised revenue, refunds, fees, operating costs, churn and contribution margin from reconciled records. Sign-ups, quotes, gross freight value and illustrative dashboard figures are not revenue.

## Recommended business model
Build a hybrid platform with two distinct commercial lines:
1. **KRIM SaaS / enterprise software** — subscriptions for logistics partners, forwarders, warehouse operators and enterprise customers to use KRIM's own software.
2. **KRIM marketplace** — later, transaction/commission revenue only after the actual contracting, payment, tax and operating model is approved for each jurisdiction.

SaaS is the first commercial product to validate because recurring subscriptions are easier to measure and are not dependent on KRIM owning vehicles or warehouses. Marketplace remains the long-term scale opportunity, not a shortcut around compliance.

## Product packages to validate (proposed hypotheses, not live offers)
- Partner Starter: basic organisation workspace, lead/enquiry management and limited operational tools.
- Partner Professional: quote workflow, shipment visibility, document vault, operational reporting and team access.
- Enterprise: multi-branch controls, integrations/API, audit, roles and consolidated reporting.
- Warehouse add-on: inventory, receiving/QC and dispatch workflows.
- API/integration add-on: metered or contracted technical access.

Do not publish prices or charge customers until interviews and willingness-to-pay tests validate packaging, support cost, tax treatment, merchant eligibility and payment rails. Free onboarding/pilot access may be used for product validation.

## Commercial safeguards
- Account creation and non-commercial partner onboarding must not require a GSTIN by default; collect tax identifiers only where legally necessary for that user's role, jurisdiction and transaction.
- Keep software subscription contracts and invoices separate from freight contracts, freight invoices and partner settlements.
- Do not disguise freight commissions as software subscriptions or route payments through KRIM to avoid tax obligations.
- Do not calculate, collect or display a tax amount unless a reviewed jurisdictional rule applies.
- Do not activate paid SaaS or marketplace checkout until the legal entity's eligibility, tax treatment, payment provider approval, settlement, refund and accounting flows are evidenced and reviewed.
- India-based management/operations remain subject to applicable Indian law even when users are overseas or infrastructure is hosted abroad.
- Country-specific controls must be based on qualified advice; global architecture is not a legal exemption.

## Verified readiness baseline (11 November 2026)
- Existing freight quote and payment infrastructure is present, but it is not proof of a working subscription product.
- Production contains no dedicated SaaS subscription/plan/entitlement table found in the public schema search.
- Payment capability registry has 42 rows across configured countries/providers; all foreign options are planned and disabled.
- INR/Razorpay is implemented and checkout_enabled is true in the registry, but merchant_eligibility_verified, settlement_supported, refunds_supported, evidence_reference and reviewed_at are false/empty. Checkout must remain blocked.
- Existing commercial pricing audit found zero active global rate cards, zero positive approved rate cards, zero partner rate cards, zero partner quotes, zero verified active partner capabilities, zero FX rates and zero tax rules.
- No real paying subscription customers or reconciled subscription revenue were established by this audit.
- Production migration history is materially ahead of the repository migration set. Do not apply schema migrations or production DDL until migration drift is reconciled.

## Implementation sequence
1. **Truthful financial reporting:** remove invented/sample figures and show only reconciled production revenue. (Finance report page updated 11 Nov 2026.)
2. **Truthful tax configuration:** remove hard-coded EU/UK rates presented as active; display unconfigured status until reviewed rules exist. (Tax settings page updated 11 Nov 2026.)
3. **SaaS product discovery:** interview 10–15 logistics companies; identify one painful recurring workflow and confirm willingness to pay before finalising packages.
4. **Subscription data model:** design organisations, products, plans, price versions, subscriptions, entitlements, invoices, payment attempts, refunds, webhook events and audit history with idempotency and RLS. Do not deploy until migration drift is reconciled and security-reviewed.
5. **Subscription lifecycle:** trials, activation, renewals, failed-payment grace period, cancellation, plan changes, proration policy, refunds and access entitlement.
6. **Merchant and tax clearance:** confirm proprietor's ability to sell the defined SaaS service, GST registration position/exemption, export treatment, income-tax and foreign-exchange/banking requirements; obtain payment provider written approval for the actual business model.
7. **Paid pilot:** only after steps 4–6, onboard a small number of real businesses, charge transparently, and reconcile each payment to provider settlement and accounting.
8. **Retention and scale:** measure activation, weekly active organisations, trial-to-paid conversion, monthly recurring revenue, churn, net revenue retention, support cost, gross margin and customer acquisition cost/payback.
9. **Marketplace expansion:** only after verified providers, lane-level rates, tax opinions, contract allocation, claims/refunds and payment settlement controls are in place.

## Revenue proof criteria
KRIM should not claim sustainable revenue until it has:
- At least 3 unrelated paying business customers in a controlled pilot;
- At least 3 consecutive monthly billing cycles with successful collection;
- Each payment matched to provider settlement and an internal ledger entry;
- Refunds, chargebacks and failed renewals reconciled;
- Monthly recurring revenue and churn computed from actual subscription records;
- Positive contribution margin after payment fees, support and directly attributable operating costs;
- No unresolved critical security, tax, payment or customer-data issues.

These are internal proof gates, not guarantees of profitability.

## Current decision
Continue global product development and free partner/customer onboarding. Keep commercial checkout and marketplace money flows fail-closed. Prioritise discovery and design of the recurring SaaS product, but do not invent prices, activate payments or alter production schema until the legal/payment and migration prerequisites are met.
