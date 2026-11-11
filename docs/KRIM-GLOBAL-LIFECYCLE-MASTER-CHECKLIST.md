# KRIM Global Logistics OS — Master Lifecycle & Ecosystem File Checklist

**Purpose:** a controlled inventory for building and verifying KRIM as a global logistics operating system. This is a target-state checklist, not a claim that every item exists or is operational. Mark a file **EXISTS** only after checking GitHub; mark **WORKING** only after a real end-to-end test. Do not put secrets in frontend files.

## Status key
- [ ] NOT VERIFIED / NOT BUILT
- [x] EXISTS in repository (does not prove it works)
- [~] PARTIAL / needs audit
- [!] SECURITY / production blocker

## A. Repository foundation and delivery engineering
- [ ] `.github/CODEOWNERS` — protected ownership/review
- [ ] `.github/PULL_REQUEST_TEMPLATE.md`
- [ ] `.github/ISSUE_TEMPLATE/bug_report.yml`
- [ ] `.github/ISSUE_TEMPLATE/feature_request.yml`
- [ ] `.github/workflows/validate-html.yml` — HTML/link checks
- [ ] `.github/workflows/security-scan.yml` — dependency/secret scanning
- [ ] `.github/workflows/supabase-migrations-check.yml`
- [ ] `.github/workflows/deploy-preview.yml`
- [ ] `README.md` — architecture, local setup, deployment, limitations
- [ ] `SECURITY.md`
- [ ] `CONTRIBUTING.md`
- [ ] `CHANGELOG.md`
- [ ] `docs/architecture/system-context.md`
- [ ] `docs/architecture/trust-boundaries.md`
- [ ] `docs/architecture/adr/0001-global-first-architecture.md`
- [ ] `docs/architecture/adr/0002-organization-isolation.md`
- [ ] `docs/runbooks/incident-response.md`
- [ ] `docs/runbooks/restore-and-disaster-recovery.md`
- [ ] `docs/runbooks/payment-reconciliation.md`
- [ ] `docs/runbooks/data-subject-request.md`

## B. Shared frontend foundations
- [ ] `core/krim-core.css` — shared tokens and layout
- [ ] `core/krim-components.css` — buttons, forms, cards, tables, dialogs
- [ ] `core/krim-accessibility.css` — focus, reduced motion, contrast
- [ ] `platform/krim-config.js` — environment/base-path-safe configuration
- [ ] `platform/krim-supabase.js` — one Supabase client; publishable key only
- [ ] `platform/krim-routes.js` — central route map
- [ ] `platform/krim-auth.js` — session/auth helpers
- [ ] `platform/krim-api.js` — typed/consistent API wrappers and errors
- [ ] `platform/krim-forms.js` — validation and accessible form helpers
- [ ] `platform/krim-i18n.js` — language selection and translation keys
- [ ] `platform/krim-format.js` — currency, units, dates, time zones
- [ ] `platform/krim-telemetry.js` — privacy-conscious client error reporting
- [ ] `platform/krim-feature-flags.js`
- [ ] `platform/krim-navigation.js` — mobile nav and role-aware links
- [ ] `platform/krim-uploads.js` — signed/private document upload flow

## C. Public discovery, education and conversion
- [ ] `public/index.html` — public home
- [ ] `public/solutions.html` — logistics solutions
- [ ] `public/global-coverage.html` — supported market coverage and limitations
- [ ] `public/network.html` — public network overview
- [ ] `public/tracking.html` — privacy-safe public tracking
- [ ] `public/quote.html` — freight quote entry
- [ ] `public/quote-result.html` — quote review / booking / payment handoff
- [ ] `public/how-it-works.html`
- [ ] `public/pricing.html` — transparent pricing / fee explanation
- [ ] `public/industries.html`
- [ ] `public/industries/manufacturing.html`
- [ ] `public/industries/ecommerce.html`
- [ ] `public/industries/retail.html`
- [ ] `public/industries/agriculture.html`
- [ ] `public/industries/automotive.html`
- [ ] `public/industries/pharma-healthcare.html`
- [ ] `public/industries/high-tech-electronics.html`
- [ ] `public/industries/construction-project-cargo.html`
- [ ] `public/industries/perishable-cold-chain.html`
- [ ] `public/industries/hazardous-goods.html` — gated and compliance-aware
- [ ] `public/industries/oversized-project-cargo.html`
- [ ] `public/partners.html`
- [ ] `public/enterprise.html`
- [ ] `public/integrations.html`
- [ ] `public/security-trust.html`
- [ ] `public/sustainability.html`
- [ ] `public/help.html`
- [ ] `public/contact.html`
- [ ] `public/status.html` — public service status, only when backed by monitoring
- [ ] `public/faq.html`
- [ ] `public/blog/index.html`
- [ ] `public/growth/partner-program.html`
- [ ] `public/growth/acquisition-command.html` — privileged, never public admin navigation
- [ ] `public/growth/prospect-registry.html` — privileged and access-controlled
- [ ] `public/404.html`
- [ ] `public/robots.txt`
- [ ] `public/sitemap.xml`

## D. Identity, access and onboarding (all user types)
- [ ] `auth/login.html`
- [ ] `auth/signup.html`
- [ ] `auth/verify-email.html`
- [ ] `auth/verify-phone.html` — only when provider/configuration exists
- [ ] `auth/mfa-setup.html`
- [ ] `auth/mfa-challenge.html`
- [ ] `auth/passkey-setup.html`
- [ ] `auth/password-recovery.html`
- [ ] `auth/password-reset.html`
- [ ] `auth/invitations/accept.html`
- [ ] `auth/sessions.html`
- [ ] `auth/consent-preferences.html`
- [ ] `auth/account-recovery.html`
- [ ] `onboarding/role-select.html`
- [ ] `onboarding/create-organization.html`
- [ ] `onboarding/organization-profile.html`
- [ ] `onboarding/verification-status.html`
- [ ] `onboarding/first-task.html`
- [ ] `onboarding/checklist.html`
- [ ] `onboarding/pending-review.html`
- [ ] `onboarding/rejected-or-more-info.html`
- [ ] `onboarding/terms-acceptance.html`
- [ ] `onboarding/data-protection-consent.html`
- [ ] Backend policies must enforce role/org isolation; hiding buttons is not authorization.

## E. Customer / shipper lifecycle
- [ ] `app/customer/dashboard.html`
- [ ] `app/customer/profile.html`
- [ ] `app/customer/organizations.html`
- [ ] `app/customer/team-members.html`
- [ ] `app/customer/addresses-locations.html`
- [ ] `app/customer/quote-request.html`
- [ ] `app/customer/quotes.html`
- [ ] `app/customer/quote-detail.html`
- [ ] `app/customer/book-shipment.html`
- [ ] `app/customer/shipments.html`
- [ ] `app/customer/shipment-detail.html`
- [ ] `app/customer/live-tracking.html`
- [ ] `app/customer/documents.html`
- [ ] `app/customer/pickup-delivery-instructions.html`
- [ ] `app/customer/returns-reverse-logistics.html`
- [ ] `app/customer/claims.html`
- [ ] `app/customer/invoices.html`
- [ ] `app/customer/payments.html`
- [ ] `app/customer/refunds.html`
- [ ] `app/customer/statements.html`
- [ ] `app/customer/saved-routes.html`
- [ ] `app/customer/repeat-booking.html`
- [ ] `app/customer/notifications.html`
- [ ] `app/customer/support-tickets.html`
- [ ] `app/customer/feedback.html`
- [ ] `app/customer/api-keys.html` — organization admin only; secrets shown once
- [ ] `app/customer/webhooks.html` — organization admin only
- [ ] `app/customer/data-export.html`
- [ ] `app/customer/close-account.html`

## F. Carrier / truck owner / transport partner lifecycle
- [ ] `app/partner/dashboard.html`
- [ ] `app/partner/company-profile.html`
- [ ] `app/partner/kyc-verification.html`
- [ ] `app/partner/operating-licenses.html`
- [ ] `app/partner/insurance.html`
- [ ] `app/partner/fleet.html`
- [ ] `app/partner/vehicles.html`
- [ ] `app/partner/drivers.html`
- [ ] `app/partner/driver-documents.html`
- [ ] `app/partner/service-areas.html`
- [ ] `app/partner/capacity-calendar.html`
- [ ] `app/partner/available-loads.html`
- [ ] `app/partner/load-detail.html`
- [ ] `app/partner/bid-submit.html`
- [ ] `app/partner/quotes.html`
- [ ] `app/partner/assignments.html`
- [ ] `app/partner/pickup-confirmation.html`
- [ ] `app/partner/trip-management.html`
- [ ] `app/partner/location-sharing.html`
- [ ] `app/partner/proof-of-pickup.html`
- [ ] `app/partner/proof-of-delivery.html`
- [ ] `app/partner/exception-report.html`
- [ ] `app/partner/detention-demurrage.html`
- [ ] `app/partner/claims.html`
- [ ] `app/partner/earnings.html`
- [ ] `app/partner/settlements.html`
- [ ] `app/partner/payout-method.html`
- [ ] `app/partner/ratings.html`
- [ ] `app/partner/compliance.html`
- [ ] `app/partner/support.html`
- [ ] `app/partner/integrations.html`
- [ ] `app/partner/offboarding.html`

## G. Other ecosystem personas and workspaces
### Drivers
- [ ] `app/driver/dashboard.html`
- [ ] `app/driver/assigned-trip.html`
- [ ] `app/driver/route-navigation.html`
- [ ] `app/driver/check-in.html`
- [ ] `app/driver/pickup-proof.html`
- [ ] `app/driver/delivery-proof.html`
- [ ] `app/driver/incident-report.html`
- [ ] `app/driver/expenses.html`
- [ ] `app/driver/safety-checklist.html`
- [ ] `app/driver/offline-sync.html`

### Warehouse / fulfillment / 3PL
- [ ] `app/warehouse/dashboard.html`
- [ ] `app/warehouse/facility-profile.html`
- [ ] `app/warehouse/inventory.html`
- [ ] `app/warehouse/inbound-appointments.html`
- [ ] `app/warehouse/outbound-orders.html`
- [ ] `app/warehouse/receiving.html`
- [ ] `app/warehouse/picking-packing.html`
- [ ] `app/warehouse/cross-dock.html`
- [ ] `app/warehouse/yard-management.html`
- [ ] `app/warehouse/slotting-capacity.html`
- [ ] `app/warehouse/warehouse-billing.html`

### Freight forwarders / customs / brokers
- [ ] `app/forwarder/dashboard.html`
- [ ] `app/forwarder/consignments.html`
- [ ] `app/forwarder/consolidation.html`
- [ ] `app/forwarder/house-master-documents.html`
- [ ] `app/customs/dashboard.html`
- [ ] `app/customs/clearance-cases.html`
- [ ] `app/customs/document-checklist.html`
- [ ] `app/customs/holds-inspections.html`
- [ ] `app/customs/duty-tax-estimate.html` — clearly labelled estimate, never official determination

### Enterprise / manufacturer / retailer
- [ ] `app/enterprise/dashboard.html`
- [ ] `app/enterprise/orders.html`
- [ ] `app/enterprise/bulk-booking.html`
- [ ] `app/enterprise/shipment-planning.html`
- [ ] `app/enterprise/control-tower.html`
- [ ] `app/enterprise/supply-chain-visibility.html`
- [ ] `app/enterprise/erp-integrations.html`
- [ ] `app/enterprise/edi-mapping.html`
- [ ] `app/enterprise/sla-management.html`
- [ ] `app/enterprise/reports.html`

### Finance, insurance, claims and external service partners
- [ ] `app/finance/dashboard.html`
- [ ] `app/finance/receivables.html`
- [ ] `app/finance/payables.html`
- [ ] `app/finance/reconciliation.html`
- [ ] `app/finance/commission-rules.html`
- [ ] `app/finance/tax-documents.html`
- [ ] `app/insurance/policies.html`
- [ ] `app/insurance/claims.html`
- [ ] `app/service-provider/profile.html`
- [ ] `app/service-provider/appointments.html`
- [ ] `app/service-provider/performance.html`

## H. Privileged internal operations (separate access boundary; never public-nav)
- [ ] `control/index.html` — privileged entry, not discoverable through customer nav
- [ ] `control/overview.html`
- [ ] `control/organizations.html`
- [ ] `control/users-access.html`
- [ ] `control/rbac-permissions.html`
- [ ] `control/partner-verification-queue.html`
- [ ] `control/shipment-operations.html`
- [ ] `control/exception-command.html`
- [ ] `control/finance-settlement-oversight.html`
- [ ] `control/reconciliation.html`
- [ ] `control/risk-fraud.html`
- [ ] `control/compliance-sanctions.html`
- [ ] `control/market-country-configuration.html`
- [ ] `control/currency-rates.html`
- [ ] `control/integrations-webhooks.html`
- [ ] `control/automation-jobs.html`
- [ ] `control/automation-executions.html`
- [ ] `control/incident-management.html`
- [ ] `control/audit-log.html`
- [ ] `control/security-posture.html`
- [ ] `control/data-retention-requests.html`
- [ ] `control/feature-flags.html`
- [ ] `control/system-health.html`
- [ ] `control/disaster-recovery.html`
- [ ] `control/growth-partner-pipeline.html`
- [ ] `control/growth-campaign-approval.html`
- [ ] `control/growth-attribution.html`
- [ ] `control/support-escalations.html`

## I. Global transport, shipment and supply-chain domains
- [ ] `domains/shipments.html`
- [ ] `domains/quotes.html`
- [ ] `domains/orders.html`
- [ ] `domains/routes.html`
- [ ] `domains/locations.html`
- [ ] `domains/carriers.html`
- [ ] `domains/capacity.html`
- [ ] `domains/tracking-events.html`
- [ ] `domains/documents.html`
- [ ] `domains/customs.html`
- [ ] `domains/tariffs-duties.html`
- [ ] `domains/warehousing.html`
- [ ] `domains/inventory.html`
- [ ] `domains/returns.html`
- [ ] `domains/claims.html`
- [ ] `domains/invoices.html`
- [ ] `domains/payments.html`
- [ ] `domains/settlements.html`
- [ ] `domains/ratings.html`
- [ ] `domains/notifications.html`
- [ ] `domains/exceptions.html`
- [ ] `domains/analytics.html`
- [ ] `domains/integrations.html`

## J. API / reusable business services (not every service needs a page)
- [ ] `services/auth-service.js`
- [ ] `services/organization-service.js`
- [ ] `services/member-permission-service.js`
- [ ] `services/quote-service.js`
- [ ] `services/shipment-service.js`
- [ ] `services/tracking-service.js`
- [ ] `services/partner-service.js`
- [ ] `services/capacity-matching-service.js`
- [ ] `services/document-service.js`
- [ ] `services/notification-service.js`
- [ ] `services/payment-service.js`
- [ ] `services/ledger-service.js`
- [ ] `services/settlement-service.js`
- [ ] `services/claims-service.js`
- [ ] `services/compliance-service.js`
- [ ] `services/audit-service.js`
- [ ] `services/integration-service.js`
- [ ] `services/analytics-service.js`
- [ ] `services/feature-flag-service.js`
- [ ] `services/idempotency-service.js`

## K. Supabase migrations / database objects
Use sequential migrations; never make a production schema change without a migration, backup/recovery plan, and verification. Exact filenames should be timestamped and follow existing repository conventions.
- [ ] Country/market/region/locale/time-zone/currency master data and market activation flags
- [ ] Organization, legal entity, membership, invitation and organization isolation
- [ ] RBAC role/permission catalog and tenant-scoped assignments
- [ ] Customer profiles, shipper sites, billing profiles and contacts
- [ ] Partner organizations, KYB/KYC status, licences, insurance, service zones
- [ ] Fleet, vehicle, driver, capacity calendar and equipment capabilities
- [ ] Locations, geocoding references, route legs and multimodal segments
- [ ] Quote requests, quote versions, rate cards, surcharges, expiry and acceptance
- [ ] Shipments, cargo items, handling units, parties, legs, milestones and status history
- [ ] Assignment offers, bids, award, reassignment and acceptance deadlines
- [ ] Tracking events, GPS ingestion, proof of pickup/delivery and custody chain
- [ ] Private documents, signed URL policy, malware-scan status and retention
- [ ] Warehouse facilities, inventory, appointments, picking/packing and cross-dock
- [ ] Customs declarations references, holds, tariff estimates and compliance records
- [ ] Invoices, payments, refunds, double-entry ledger, partner payables, settlements
- [ ] Payment provider events, signature verification, idempotency and reconciliation
- [ ] Notifications, templates, preferences, delivery attempts and suppression lists
- [ ] Support tickets, claims, disputes, evidence and resolution workflow
- [ ] Webhook endpoints, delivery attempts, retries and dead-letter queue
- [ ] Audit events, access/security events, retention and export requests
- [ ] Automation definitions, execution logs, retry policy, locks and dead-letter events
- [ ] Partner prospects, consent/legal basis, outreach suppression and campaign audit
- [ ] Analytics aggregates with tenant/privacy protections
- [ ] RLS policies and tests for every tenant-owned table
- [ ] Indexes, constraints, foreign keys, immutable financial records and retention rules
- [ ] Seed/reference data and repeatable test fixtures

## L. Supabase Edge Functions / server-side jobs
- [ ] `create-razorpay-order` — authenticated, server-calculated amount only
- [ ] `verify-razorpay-payment` — signature/order/amount/currency/customer verification
- [ ] `razorpay-webhook` — signature validation, idempotent event processing
- [ ] `payment-reconciliation` — compare provider, orders and ledger
- [ ] `create-global-quote` / quote contract aligned to frontend
- [ ] `create-global-shipment` / shipment creation with authorization
- [ ] `accept-quote-and-book` — atomic state transition and idempotency
- [ ] `partner-onboarding-review` — human review and audit trail
- [ ] `partner-capacity-discovery`
- [ ] `shipment-assignment-engine`
- [ ] `shipment-event-ingest`
- [ ] `tracking-provider-adapter`
- [ ] `notification-dispatcher`
- [ ] `document-upload-finalizer`
- [ ] `compliance-screening-adapter` — provider-backed and fail-closed where required
- [ ] `global-admin-control` — strict server-side platform role verification
- [ ] `automation-runner` — bounded jobs, locks, retries, audit and kill switch
- [ ] `partner-outreach-dispatch` — lawful opt-in/suppression, rate limits, approvals
- [ ] `daily-settlement-runner` — reconciled and approved records only
- [ ] `dead-letter-replay` — privileged, audited and idempotent
- [ ] `health-check` — no secrets in output
- [ ] Every function has authentication mode, CORS, input schema, rate limits, logs and tests documented.

## M. Integrations / adapters
- [ ] Razorpay (test/live separation, webhooks, refunds, reconciliation)
- [ ] Email provider
- [ ] SMS/OTP provider (if enabled)
- [ ] WhatsApp provider (approved templates/consent)
- [ ] Maps/geocoding/distance and route provider
- [ ] GPS/telematics provider
- [ ] Carrier/forwarder APIs and EDI
- [ ] ERP connectors (SAP/Oracle/Dynamics/etc. where commercially justified)
- [ ] E-commerce/marketplace connectors
- [ ] Warehouse management systems
- [ ] Customs/broker systems per jurisdiction
- [ ] Document OCR/classification with human review
- [ ] Identity/KYB provider
- [ ] Sanctions/export-control screening provider
- [ ] Tax/accounting provider per market
- [ ] Customer support/helpdesk
- [ ] Analytics/error monitoring
- [ ] Webhook signing, retries, replay protection and per-tenant credentials for all integrations

## N. Global compliance, risk and trust
- [ ] Country/market availability matrix; never imply every service is live everywhere
- [ ] Terms, privacy notice, cookie preferences and data processing terms
- [ ] Country-specific contracting entity, tax and invoice rules
- [ ] Data residency, cross-border transfer and retention policies
- [ ] KYC/KYB, beneficial ownership, licence and insurance checks
- [ ] Sanctions, export controls, dual-use/hazardous goods and denied-party controls
- [ ] Trade documents, customs responsibilities and Incoterms version/reference
- [ ] Consumer/business complaint and dispute procedures
- [ ] Accessibility (WCAG-oriented), mobile-first and low-bandwidth design
- [ ] Language/localization workflow; currencies, units, date/time and address formats
- [ ] Data minimization, encryption, least privilege, secret rotation and breach response
- [ ] Fraud/risk monitoring, chargebacks, suspicious orders and manual review
- [ ] Insurance/liability limits and clearly stated service scope
- [ ] Vendor risk review, subprocessor list and incident communication process

## O. Reliability, observability and automation
- [ ] Structured server logs with correlation IDs and PII redaction
- [ ] Error capture for frontend and Edge Functions
- [ ] Health checks and alert thresholds
- [ ] Job heartbeat, lock, retry/backoff and max-attempt policy
- [ ] Dead-letter queue and audited replay
- [ ] Idempotency for booking, payment, webhooks, assignment and payout
- [ ] Database backup/restore rehearsal and recovery objectives
- [ ] Rate limits, abuse controls and request-size limits
- [ ] Availability, latency and payment failure dashboards
- [ ] Feature kill switches for payments, campaigns, assignments and automated payouts
- [ ] Automated accessibility, route, security and regression tests
- [ ] Synthetic end-to-end test environment with test provider credentials

## P. Revenue and sustainable operations
- [ ] Quote-to-book conversion and transparent price breakdown
- [ ] Valid customer authorization and booking confirmation
- [ ] Payment captured status verified server-side
- [ ] Ledger records balanced, immutable and idempotent
- [ ] Platform fee and partner payout terms disclosed and contractually accepted
- [ ] Refund, partial refund, cancellation and dispute paths
- [ ] Settlement only against reconciled eligible funds and approved partner records
- [ ] Reconciliation exception queue and human review
- [ ] Unit economics: gross margin per shipment, acquisition cost, support cost, refund/claim loss
- [ ] No claim of revenue from test payments or unverified ledger rows
- [ ] No live key activation until launch gates below pass

## Q. Partner-first growth and acquisition
- [ ] Define target partner segments and service regions
- [ ] Prospect source, lawful basis, consent and suppression rules recorded
- [ ] Partner application and KYB workflow works end-to-end
- [ ] Human approval before any outbound campaign or commercial commitment
- [ ] CRM pipeline: identified → contacted → interested → application → verified → contracted → active
- [ ] Service coverage/capacity verified before demand campaigns
- [ ] Outreach limits, unsubscribe, bounce/complaint monitoring and audit trail
- [ ] Partner activation checklist, training and first-job support
- [ ] Measure response rate, verified activation, first accepted job, on-time delivery and repeat usage
- [ ] Start customer campaigns only when fulfillment capacity, service quality and support are ready
- [ ] AI can assist; it must not fabricate prospects, claim unverified coverage, or autonomously make binding promises.

## R. Quality and test files
- [ ] `tests/routes/route-map.test.js`
- [ ] `tests/auth/organization-isolation.test.sql`
- [ ] `tests/auth/rbac-policy.test.sql`
- [ ] `tests/quotes/quote-lifecycle.test.sql`
- [ ] `tests/shipments/shipment-state-machine.test.sql`
- [ ] `tests/payments/payment-idempotency.test.ts`
- [ ] `tests/payments/razorpay-signature.test.ts`
- [ ] `tests/payments/ledger-reconciliation.test.sql`
- [ ] `tests/automation/retry-dead-letter.test.sql`
- [ ] `tests/integrations/webhook-replay.test.ts`
- [ ] `tests/accessibility/public-and-auth-pages.test.js`
- [ ] `tests/e2e/customer-quote-to-delivery.spec.js`
- [ ] `tests/e2e/partner-onboarding-to-first-job.spec.js`
- [ ] `tests/e2e/refund-and-settlement.spec.js`
- [ ] `tests/fixtures/` — synthetic identities and shipments only, no real personal data
- [ ] `tests/README.md` — how to run and interpret results

## S. Mandatory user journeys to prove before launch
- [ ] Visitor → Get Started → role selection → signup → email verification → organization profile → correct workspace
- [ ] Customer → valid quote request → server-priced quote → accept quote → shipment created → booking confirmation
- [ ] Partner → application → document upload → review → verified status → capacity setup → load offer → accept assignment
- [ ] Operations → assignment → pickup proof → tracking events → exception handling → delivery proof
- [ ] Customer → invoice → payment order → provider checkout → server verification → ledger → receipt
- [ ] Failed/duplicate webhook → no duplicate ledger/settlement; safe retry and reconciliation
- [ ] Refund/cancellation → correct provider state and balanced ledger
- [ ] Partner settlement → eligible reconciled amount → approved payout → auditable result
- [ ] Unauthorized user cannot read another organization’s records or privileged control pages/APIs
- [ ] Keyboard/mobile/slow-network path for core customer and partner workflows
- [ ] Every public button has a real destination or a clearly disabled state; no fake success alerts

## T. Live launch gates — ALL required
- [ ] Audit every current repository file and map it to this inventory.
- [ ] Verify every frontend API call matches a deployed Edge Function/RPC contract.
- [ ] Resolve the payment checkout contract mismatch and remove hardcoded price/placeholder phone.
- [ ] Require a valid user session where intended; never put service-role or provider secret keys in frontend.
- [ ] Server computes amount from accepted quote and currency; browser input is untrusted.
- [ ] Verify Razorpay signature and provider payment status server-side; webhook signature and replay/idempotency tested.
- [ ] Reconcile provider transactions against ledger; prove refunds and settlement flows.
- [ ] Test RLS with at least two organizations and multiple roles.
- [ ] Confirm backups, rollback, logs, alerts, incident contacts and support process.
- [ ] Confirm market-by-market legal/compliance readiness; enable only markets actually supported.
- [ ] Run test-mode end-to-end flows and independent security review.
- [ ] Keep live Razorpay keys disabled until the preceding gates are documented as passed.
- [ ] Launch with a limited, explicitly supported corridor and real partner capacity; expand by verified market readiness.

## Execution rule
This inventory is intentionally broad. It is not a requirement to create hundreds of empty pages before launch. Build in dependency order: security and shared foundations → identity/org isolation → partner verification/capacity → quote/booking/shipment → tracking/proof → payment/ledger/reconciliation → support/observability → carefully approved partner acquisition → customer scale. A page is not functional merely because it exists; it must use a real authorized backend contract and pass its journey test.
