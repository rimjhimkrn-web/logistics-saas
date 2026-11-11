# KRIM Commercial Launch Readiness — Website, Plans, Trial, Payments and Apps
Date: 11 November 2026
Status: working release checklist. This is an implementation plan and current-state record, not a declaration that commercial launch is approved.

## Commercial model locked for initial rollout
1. Free customer registration, basic shipment enquiry and uncovered-route coverage review.
2. Free partner registration, initial verification and controlled design-partner onboarding.
3. Optional B2B SaaS for logistics operators and warehouses only when the contracted software features are live, useful and supported.
4. Marketplace transaction/coordination revenue is a separate later workstream with its own contract, tax and payment review. Never label freight consideration or commission as SaaS.

## Website work completed in this phase
- Added root `plans.html` with four software plan families: Partner Starter, Partner Professional, Warehouse, Enterprise & API.
- Added 30-day invitation-only guided evaluation terms: no card, no automatic paid conversion, starts only after written feature and date confirmation.
- Explicitly disclosed that prices and SaaS checkout are not yet published or enabled.
- Clarified free customer enquiries and free uncovered-route review.
- Added Plans navigation to the root homepage.

## Current hard blockers
### Marketplace / partner supply
- Production `krim_partner_capabilities` currently has one pending, inactive capability and zero active approved capabilities.
- Customer booking flow has not yet been proven to enforce exact active partner capability matching server-side before a request is presented as serviceable.
- Keep marketplace customer acquisition narrow and free until availability gate and partner acceptance flow pass.

### SaaS subscription engine
- Dedicated SaaS subscription, plan, price, invoice, payment-attempt and entitlement domain is not yet implemented.
- Existing freight payment tables/functions are not a subscription engine and must not be repurposed.
- Production migration history and repository migrations are materially out of sync; no production DDL until full reconciliation.
- Do not expose paid plan prices, paid checkout, automatic renewals or self-serve upgrades until server-side entitlements and billing are tested.

### Payment and tax
- Razorpay freight payment setup does not prove SaaS recurring-payment eligibility.
- Obtain written confirmation of merchant account capability for recurring domestic/international SaaS payments, refund process and settlement.
- Decide app distribution/payment approach under current Google Play policies before enabling paid app features.
- Review Indian GST/income-tax treatment, KRIM's role, invoices, exports, refunds, privacy and consumer terms with a CA/legal professional before paid commercial activation.
- Keep live SaaS checkout disabled until all of the above are approved and test-mode lifecycle passes.

### Mobile apps
- Three apps exist: Customer, Partner and Driver.
- Updated their local logo references and Expo app icon/splash references to use the existing `assets/icon.png`, fixing references to PNG files that were not present in each app folder.
- This is an asset-path correction only. It does not make the apps production-ready.
- Customer app still has preview request flow; backend request, quote, tracking and payment integrations need verification.
- Partner app still needs organization membership, capability onboarding/verification, opportunities, quotations, assignments and document/finance workflows.
- Driver app still needs secure dispatch assignment, consented location handling, POD evidence and completion workflows.
- No APK/AAB or store release was initiated in this phase.

## Remaining implementation sequence
1. Confirm Pages, static-link, production-smoke and mobile-validation workflows for the current commit.
2. Verify deployed Plans page and homepage navigation.
3. Finish route/service/cargo-aware partner availability gate, uncovered-route free coverage review and specific-job partner acceptance.
4. Complete partner onboarding and verification operations, including evidence review, expiry and capability activation.
5. Reconcile migrations and design/deploy dedicated SaaS subscription schema in a safe staged environment.
6. Build server-side plan catalogue, time-limited trial lifecycle, entitlement checks, billing portal, invoices, cancellations, refunds and audit trail.
7. Add Razorpay subscription integration only after merchant recurring-billing approval and tax/legal gates; test webhooks, retries, duplicate events, failed renewals and refunds.
8. Complete each mobile app's real backend workflows and security tests; preserve no-fake-data / fail-closed behaviour.
9. Resolve Google Play billing requirements and app distribution rules for the chosen commercial flow.
10. Run end-to-end tests across website, apps, partner/customer journeys, subscriptions and payment sandbox.
11. Only then enable public paid plans and begin controlled customer acquisition in partner-verified service cells.

## Release rule
A green website deployment or successful app compile is not proof of operational readiness. Public commercial launch requires working workflows, verified partner supply, security and privacy checks, approved payment/tax arrangements, support and refund procedures, and successful end-to-end tests.
