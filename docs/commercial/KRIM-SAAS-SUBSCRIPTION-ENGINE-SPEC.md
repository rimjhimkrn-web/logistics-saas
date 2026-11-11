# KRIM SaaS Subscription Engine — Architecture & Build Specification
Date: 11 November 2026
Status: design only; no production schema or payment activation authorised by this document.

## Purpose
Add a recurring software revenue line without confusing software subscriptions with freight charges, partner payouts, shipment commissions or customer funds. The subscription engine must support global organisations, multi-currency price versions, recurring billing, entitlements, auditability and jurisdiction-specific commercial gates.

## Existing-system findings
- Production has mature freight payment and financial-ledger infrastructure, including `payment_orders`, `payment_webhook_events`, `krim_financial_transactions` and payment capability controls.
- Freight payment records are shipment/quote-bound; they must not be repurposed as subscription records.
- No dedicated subscription, subscription-plan, billing-cycle or entitlement tables were found in the public schema inventory.
- Existing finance reporting is not yet connected to verified recurring SaaS revenue.
- Production migration history is materially ahead of the repository migration set. Do not run production DDL or apply migrations until migration drift is reconciled.

## Product model
Sell KRIM's own software access to business organisations. The initial target segments are:
1. Freight forwarders and logistics partners.
2. Transport operators.
3. Warehouse operators.
4. Enterprise logistics teams.

Do not charge for a feature unless the customer receives a clearly described KRIM software capability. Do not relabel freight commission, referral compensation or transaction consideration as a software subscription.

## Proposed plan catalogue (commercial hypotheses only)
The following names are packaging concepts, not approved prices or active offers:
- **Partner Starter:** organisation profile, enquiry inbox, limited team seats and basic operational workspace.
- **Partner Professional:** quote management, shipment visibility, document workflows, team permissions and reporting.
- **Warehouse:** receiving, QC, inventory and dispatch workflows.
- **Enterprise:** multi-branch governance, role controls, audit, consolidated analytics and API/integrations.
- **API & Integrations:** separately contracted access with usage limits and support terms.

Keep free registration and non-commercial onboarding separate from paid entitlements. Do not publish price points until discovery interviews, support-cost modelling, tax review and payment-provider eligibility are complete.

## Core data model to design
Create new dedicated tables only after migration-history reconciliation and security review:
1. `krim_saas_products` — product catalogue and product family.
2. `krim_saas_plans` — plan identity, product, version, public/private status and lifecycle.
3. `krim_saas_prices` — immutable price versions with currency, interval, amount in minor units, effective dates, tax treatment reference and provider price reference.
4. `krim_saas_subscriptions` — organisation, plan/price version, provider, status, period start/end, trial, grace period, cancel-at-period-end and lifecycle timestamps.
5. `krim_saas_subscription_items` — optional seats/add-ons/usage quantities.
6. `krim_saas_entitlements` — server-enforced feature access, quantity limits and validity.
7. `krim_saas_invoices` — issued billing records with immutable line snapshots, currency, subtotal, tax decision reference, total, due date and status.
8. `krim_saas_payment_attempts` — provider order/payment references, idempotency key, amount, currency, attempt state and reconciliation references.
9. `krim_saas_refunds` — refund request/provider state and reconciled ledger reference.
10. `krim_saas_webhook_events` — provider event ID, event type, payload hash, processing state, attempts and timestamps; unique provider/event ID.
11. `krim_saas_audit_events` — append-only actor, action, object, before/after hash and reason.

Do not duplicate or overload `payment_orders`, which is tied to shipment/quote payments. Reuse shared finance ledger posting patterns only through an explicitly reviewed integration that preserves source type and idempotency.

## Required lifecycle
- Draft plan and price version → reviewed → published → retired.
- Trial (optional) → active → past_due → grace_period → suspended → cancelled/expired.
- Renewal must create a new invoice/payment attempt for the correct period and be idempotent.
- Failed renewal must not silently create duplicate provider orders.
- Cancellation must preserve access through paid-through date unless contract terms say otherwise.
- Upgrade/downgrade/proration policy must be explicit; no surprise prorations.
- Refunds must be provider-confirmed and ledger-reconciled before marking completed.
- Webhook retries must be idempotent; out-of-order events must not downgrade a paid invoice or active paid period.
- Entitlements must be computed server-side and never trusted from user-editable metadata.

## Security and access model
- All exposed public-schema tables must have RLS enabled.
- Organisation members may read only their organisation's subscription, invoice and entitlement summaries.
- Only authorised billing administrators may change billing contacts or request plan changes.
- No client may set subscription status, payment status, entitlement status, tax status or provider IDs directly.
- Provider webhooks must verify signatures and event identity; privileged reconciliation must run server-side.
- Never expose service-role credentials in browser/mobile clients.
- Sensitive administrative changes require appropriate platform permission, MFA/AAL2 and immutable audit events.
- Use least-privilege grants; review SECURITY DEFINER functions carefully and run database advisors after implementation.

## Tax, payment and merchant eligibility gates
- Account registration and free onboarding should not require GSTIN by default; collect tax identifiers only when legally required for the customer, supplier, jurisdiction and transaction.
- A country/transaction may be billed only when KRIM's actual supplier role, place-of-supply/export treatment, registration requirement, invoice treatment and payment provider's merchant eligibility are reviewed and documented.
- Export/foreign-customer status is not itself proof of exemption from Indian GST or other Indian obligations.
- Keep software subscription invoices distinct from freight invoices and marketplace settlement records.
- A Merchant of Record may handle customer-facing indirect tax collection where contracted and supported, but does not erase KRIM's own Indian income-tax, GST, FEMA, accounting or permanent-establishment obligations.
- If a legal or payment gate is unresolved, checkout is disabled for that market; do not bypass the gate with a foreign currency or foreign provider.

## Payment provider requirements
- Keep Razorpay freight checkout separate from SaaS billing unless the provider explicitly approves the subscription use case and the integration is separately implemented.
- For each provider/country/currency, require evidence for merchant eligibility, presentment, settlement, refunds, chargebacks, recurring mandate support (where applicable), supported business category and settlement bank account.
- Never advertise an international payment option based only on API integration or a test key.
- No live charge until written provider approval and low-value controlled end-to-end test are complete.

## Revenue accounting and proof
Record and report separately:
- Gross subscription billings.
- Collected subscription cash.
- Provider fees.
- Refunds and chargebacks.
- Recognised software revenue.
- Tax collected/payable where applicable.
- Net subscription revenue.
- Direct support/hosting/payment costs.
- Contribution margin.
- MRR, ARR, logo churn, revenue churn, expansion and contraction.

Do not count sign-ups, free trials, quotes, gross freight value, uncollected invoices or partner GMV as KRIM revenue.

## Acceptance gates before paid pilot
1. Legal/tax opinion for the precise software supply model and current proprietor structure.
2. Written payment-provider approval for SaaS subscriptions and supported recurring payment method.
3. Migration drift reconciled; reviewed migrations created and deployed through the controlled release process.
4. RLS, grants, webhook verification, idempotency, audit and negative-access tests passed.
5. Terms, refund/cancellation policy, billing disclosures and support process published.
6. At least one real test business completes a low-value paid pilot transaction after all approvals.
7. Payment, provider settlement, invoice, ledger and bank credit reconcile exactly.
8. Renewal, failed payment, cancellation, refund and chargeback scenarios tested.
9. Customer can self-serve billing changes without gaining access to another organisation's records.

## Build sequence
1. Discovery and packaging validation with 10–15 target logistics businesses.
2. Reconcile migration history and existing finance interfaces.
3. Implement schema and RLS in a non-production environment.
4. Implement server-side subscription lifecycle and webhook processing.
5. Implement organisation billing and entitlement UI.
6. Implement reconciled SaaS finance reporting.
7. Complete legal/provider gates and controlled paid pilot.
8. Measure retention and contribution margin for at least three consecutive billing cycles.
9. Expand plan catalogue and then activate marketplace fees only through a separate approved workstream.

## Revenue sustainability proof threshold
KRIM may claim recurring revenue proof only after:
- At least three unrelated paying organisations;
- Three consecutive successful monthly billing cycles;
- Provider settlements matched to ledger and bank records;
- Renewals, refunds and failed payments reconciled;
- Positive contribution margin after directly attributable costs;
- Measured retention and churn; and
- No unresolved critical security, legal, tax or payment issue.

These are internal proof standards, not a revenue guarantee.

## Production baseline findings added 11 November 2026
- No dedicated SaaS plan, price, feature, subscription, trial, entitlement, SaaS invoice, SaaS payment event or SaaS refund tables were found in the inspected public/private catalog.
- Existing organisation IDs are bigint; the private organization access helper accepts `uuid, bigint`.
- Existing roles include `organization_owner`, `organization_admin`, `finance_manager`, `platform_admin` and `platform_superadmin`.
- The current permission catalogue has `finance.view/manage` and `organization.view/manage`, but no explicit SaaS billing, subscription, plan, trial or refund permission codes. Do not assume `finance.manage` alone is sufficient.
- All 27 matching public/private tables in the catalog baseline had RLS enabled, but this does not grant a new SaaS table any inherited protection.
- Read-only baseline details: `docs/audits/KRIM-PRODUCTION-SCHEMA-BASELINE-SAAS-READINESS-2026-11-11.md`.
