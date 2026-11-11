# KRIM End-to-End Readiness Audit — 11 November 2026

## Purpose
This is a read-only production snapshot to establish the actual completion baseline before implementing the remaining KRIM business and software lifecycles. No production data, schema, payment settings, secrets, or user accounts were changed by this audit.

## Executive status
KRIM is **not yet ready for unrestricted real-world shipment operations or paid SaaS subscriptions**. The public website and plans page can collect enquiries, and the production database contains substantial workflow foundations, but several critical lifecycle stages have no verified live execution path.

## Verified production observations

### Project
- Supabase project: `ebltviniygljwwseplph`
- Project status: `ACTIVE_HEALTHY`
- PostgreSQL: 17.6.1.165
- No separate staging branch was available at audit time. The only listed branch was the production `main` branch.

### Partner / shipment operations
Read-only counts from production:
- Partner capability rows: **1**
- Active partner capabilities: **0**
- Active, currently effective, verified partner capabilities: **0**
- Partner match result rows: **0**
- Partner quotes: **0**
- Shipment-partner assignments: **0**
- Proof-of-delivery records: **0**
- Financial transactions: **1**
- Invoices: **0**

A database function named `krim_internal_create_partner_matching_run` exists, but the production counters above do not demonstrate a successful partner match, quote, assignment or delivery lifecycle. With zero active verified capabilities, KRIM must fail closed: do not promise provider availability, quote, booking or delivery for a route unless a specific provider has been independently verified and accepts the job.

### SaaS subscriptions
- No dedicated production subscription, trial, plan-entitlement or SaaS billing lifecycle tables were found. The one table name matching a broad "subscription" search is an API webhook-subscription table, not a SaaS billing subscription.
- No production trial activation/expiry and paid conversion lifecycle was verified.
- The plans page displays proposed introductory prices, but paid checkout remains disabled. These prices must remain clearly marked proposed until approved.

### Edge Functions
The production project currently lists 19 Edge Functions. The list includes Razorpay payment functions, notification functions, admin control, public contact inquiry, and legacy Cashfree functions:
- `create-global-cashfree-order`
- `verify-global-cashfree-payment`
- `cashfree-payment-webhook`

Cashfree should not be removed blindly. First inspect all frontend and backend references, webhook configuration and historical payment records; then disable/remove only after proving there are no live dependencies and after an explicit safe change plan.

### Security advisor snapshot
The Supabase security advisor reported:
- **26** RLS-enabled tables without policies. Findings include private-schema internal tables and some public-schema tables. A blanket policy must not be added: some tables may intentionally be service-role-only. Each table needs an owner/access-model review.
- **126** authenticated-callable SECURITY DEFINER functions. This is a review queue, not proof that every function is vulnerable. Each function must be inspected for explicit identity, organisation, role, permission and object-level checks before changing grants.
- Leaked-password protection is disabled and should be enabled after confirming the appropriate Auth settings.
- Performance advisor also reports unused indexes, six multiple-permissive-policy findings and one duplicate-index finding. These require measured, reviewed remediation; do not drop indexes or rewrite policies blindly.

## Release-blocking work, in order

### P0 — Security and release controls
1. Build a function-by-function SECURITY DEFINER inventory and verify authentication, tenant isolation, permission checks, input validation and fixed search paths.
2. Classify all 26 no-policy RLS findings as intentionally service-only or requiring an explicit policy; test both allowed and denied access.
3. Enable leaked-password protection.
4. Review storage buckets, signed URL scope, secrets, webhook signature verification, rate limits, idempotency and audit logging.
5. Keep payment and booking operations fail-closed until tests pass.

### P1 — Partner onboarding and provider network
1. Complete organisation onboarding and verification.
2. Validate partner legal/business evidence and capability records.
3. Add explicit service area, mode, cargo, capacity, effective dates and compliance checks.
4. Implement server-side route matching with outcomes `matched`, `no_verified_provider`, or `review_required`.
5. Prevent customer shipment requests from being treated as confirmed bookings.
6. Test expired, inactive, wrong-route, wrong-mode, wrong-cargo, insufficient-capacity, unauthorised and cross-organisation cases.

### P2 — Shipment execution lifecycle
1. Customer enquiry and booking qualification.
2. Provider match and invitation.
3. Partner quote creation, versioning and expiry.
4. Customer acceptance of a specific quote.
5. Partner assignment and explicit acceptance.
6. Dispatch, driver assignment and consent-based tracking.
7. Pickup, milestones, exceptions and notifications.
8. Delivery evidence submission and independent verification.
9. Invoice, payment, settlement, dispute and refund.
10. Customer closure, feedback and repeat shipment.

### P3 — SaaS lifecycle
1. Dedicated SaaS products, plans and feature entitlements.
2. Admin-reviewed pilot request and written approval.
3. Trial start, expiry and reminder events.
4. Explicit paid conversion; no automatic conversion.
5. Billing profile, invoice and tax treatment.
6. Recurring payment mandate/provider eligibility.
7. Webhook signature verification and idempotent payment events.
8. Failed payment, retry, grace period, suspension, cancellation and reactivation.
9. Refunds, credits, invoices, audit and reconciliation.
10. Tenant-isolated feature enforcement in every web and mobile client.

Freight payment records must remain separate from SaaS subscriptions. Do not repurpose freight orders, invoices or partner settlement tables for software billing.

### P4 — User workspaces and communications
Validate the customer, partner, driver, warehouse, customs, finance, operations control tower, enterprise and admin journeys separately. Test signup, sign-in, recovery, permissions, empty states, notifications, document access, mobile layouts and support escalation. Do not describe an app as production-ready based only on a successful Expo export.

### P5 — Commercial and legal launch gates
Confirm Indian tax/GST treatment, invoice wording, refunds, privacy, customer/partner contracts, data retention and service liability with a qualified Indian CA/legal professional. Do not enable paid subscriptions or represent KRIM as the freight carrier unless the actual contracting and operating model supports that representation.

## Verification standard
A lifecycle is complete only when:
- a real test user can start it from the relevant UI;
- the server enforces the permitted state transition and organisation boundary;
- the expected database records and audit events are written exactly once;
- notifications are delivered or safely retried;
- failures, retries, duplicate webhooks and unauthorised access are tested;
- the final state is visible to the correct user roles only;
- the test is repeated on the deployed build.

## Safety constraints during implementation
- Do not run unreviewed production DDL or bulk data changes.
- Do not expose service-role credentials or secrets in browser/mobile code.
- Do not enable live paid checkout until merchant eligibility, tax, settlement, refund and recurring billing tests are complete.
- Do not charge customers for uncovered routes or imply confirmed availability without an accepted provider.
- Do not create paid staging infrastructure without the user's explicit approval of its quoted cost.
