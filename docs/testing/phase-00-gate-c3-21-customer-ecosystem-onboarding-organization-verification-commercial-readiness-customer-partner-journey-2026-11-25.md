# Phase 00 Gate C3.21 — Customer ecosystem onboarding, organization verification, commercial readiness and customer-to-partner journey

**Date:** 2026-11-25  
**Source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**Method:** Read-only source and migration inspection plus reconciliation with prior customer/partner onboarding audit. No runtime customer account was created, no SQL/RPC was invoked, no quote or shipment was created/accepted, and no Production/Staging data or configuration was changed.

## Executive decision

**PARTIAL PASS / BLOCKED — customer information and quote workspaces have useful organization-scoping patterns, but KRIM does not yet have a fully proven customer admission, verification, contracting, booking and partner-confirmation journey.**

The customer onboarding page is an instructional navigation hub rather than a complete registration/provisioning/profile/verification workflow. A customer organization provisioning RPC exists and uses authenticated identity, an advisory transaction lock, owner membership/role assignment and an audit event. Quote read surfaces filter by active customer/shipper/enterprise organization IDs and avoid inventing sample prices in Production. The customer quote acceptance page adds partner-acceptance and expiry checks. These are positive source controls, not end-to-end runtime proof.

## Scope inspected

- `public/customer-os/customer-services/onboarding.html`
- `public/customer-os/customer-services/index.html`
- `public/customer-os/customer-services/company-profile.html`
- `public/customer-os/customer-services/team-members.html`
- `public/customer-os/customer-services/quote-request.html`
- `public/customer-os/assets/quote-operations.js`
- Customer signup terms-consent migration `20261111190000_record_customer_signup_terms_consent.sql`
- Customer/partner organization provisioning hardening migration `20261115111500_harden_customer_and_partner_organization_provisioning.sql`
- Secured shipment booking grant migration `20261105114500_enable_secured_customer_shipment_booking_rpc.sql`
- Prior audit `docs/audits/KRIM-CUSTOMER-AND-PARTNER-ONBOARDING-VERIFICATION-AND-ACTIVATION-AUDIT-2026-11-16.md`

## Positive source controls

1. **Provisioning authorization and idempotency pattern:** `krim_provision_customer_organization(text)` rejects unauthenticated calls and invalid names, obtains a per-user advisory transaction lock, reuses an existing active customer/enterprise membership if found, otherwise creates a customer organization, owner membership, organization-owner role assignment and audit event in one transaction.
2. **No direct anonymous booking RPC:** the reviewed booking grant explicitly grants the five-argument shipment creation function to authenticated users and revokes it from anon. The function's documented body checks membership, shipment.create permission and operational market/location gates.
3. **Organization-scoped quote listing:** quote operations resolve active memberships and active customer/shipper/enterprise organizations, then filter quote rows by those organization IDs.
4. **Quote detail binding:** quote detail is selected by quote ID and authorized organization ID; linked shipment is separately fetched under the same organization IDs. Missing/out-of-scope quote or shipment data is not rendered as an authorized record.
5. **Partner confirmation before customer acceptance:** quote acceptance is disabled unless the corresponding partner assignment exists in accepted/active state; expiry, non-positive amount, missing shipment and partner-assignment lookup errors also block the button. Historical accepted rows without a matching accepted partner assignment are labelled legacy/unverified.
6. **No invented Production quote data:** the quote request page has an explicit illustrative Staging mode and does not show sample shipment/price records in Production.
7. **Customer onboarding clarity:** the onboarding page states that opening a workflow does not mean approval, does not invent completion percentages, and separates essential service communications from optional marketing preferences.

## Findings and blockers

### P1 — Customer onboarding is not a complete executable journey
The canonical onboarding page links to company profile, verification, locations, cargo profiles, shipping preferences and team access. However, the inspected page itself does not create/provision an organization, capture a complete profile, submit verification, record billing/contact details, establish authorized contacts or prove a support handoff. The company profile page is primarily explanatory and routes users to sign-in; the team page describes roles and explicitly says it does not create invitations or change permissions. Treat these as guidance pages, not evidence of completed onboarding.

### P1 — Organization reuse can silently select an enterprise tenant
The provisioning function selects the earliest active customer **or enterprise** membership and returns that organization without validating that its legal name/type matches the requested new customer context. This may be intended shared customer/enterprise behavior, but must be made explicit and tested. Do not attach a new customer flow to an unintended tenant or silently treat an enterprise organization as a standalone customer.

### P1 — Customer signup consent is sourced from editable user metadata
The consent migration's Auth trigger checks `raw_user_meta_data.terms_accepted` and records a `terms_and_privacy` event using a metadata-supplied version (or fallback). User metadata is user-editable and must not be treated as authoritative proof of contractual acceptance. The trigger should record server-validated, versioned policy identity/hash and actor/time from a controlled signup contract; marketing and analytics consent remain separate, purpose-specific and revocable. Do not use user_metadata claims for authorization.

### P1 — Customer organization verification/commercial admission is not evidenced
Prior audit found no complete customer business verification, organization profile, billing contact, authorized team, consent preference or support handoff journey. An active organization/membership is not itself proof of verified legal entity, authorized contracting representative, credit approval or permission to transact. Define a customer admission policy proportionate to customer type and transaction risk.

### P1 — Tenant isolation and membership ambiguity need runtime negative tests
Quote pages query membership and organization rows, but client-side filtering is not the security boundary. RLS and RPC authorization must independently prevent cross-tenant reads/writes. The customer quote page also gathers all active memberships and accepts all active customer/shipper/enterprise organizations, which may be broader than an explicitly selected tenant. Test multiple memberships, removed membership, suspended organization, role downgrade, stale JWT, forged organization IDs and direct REST/RPC calls.

### P1 — Shipment creation and quote-to-booking chain is not end-to-end proven
The booking grant is present and quote acceptance source checks a partner assignment, but no authenticated journey was executed. Verify shipment create authorization, active market/country/location and mode gates, idempotency, partner quote matching, partner acceptance, customer acceptance, assignment creation, capacity reservation, cancellation/expiry and final dispatch prerequisites in Staging before real customer booking.

### P1 — Customer acceptance must not be mistaken for freight payment or dispatch
The quote UI explicitly says partner acceptance and customer acceptance do not establish final dispatch readiness; freight payment is arranged directly with the contracting provider and is not collected/verified by KRIM. Preserve this limitation in UI, terms and operational scripts. Do not advertise KRIM escrow, payment settlement or confirmed carrier booking unless a separately verified capability exists.

### P2 — Customer team access and role matrix are illustrative
The team page labels its access matrix illustrative and does not create invitations or modify permissions. The actual invitation lifecycle, role grant/revocation, tenant boundary, AAL/step-up requirements for sensitive actions and offboarding must be proven in backend and staging.

### P2 — Billing, invoice and credit controls are not part of a proven admission flow
Customer invoice, payment, credit and refund pages exist elsewhere in the workspace, but this gate did not establish customer billing identity, tax treatment, credit terms, invoice delivery, refund eligibility or finance authorization end to end. Do not infer commercial credit or payment readiness from account creation or a quote.

### P2 — Operational communications and consent boundaries
The onboarding page distinguishes essential service updates from optional marketing, which is positive. Actual customer preference persistence, versioned consent/withdrawal, channel delivery, suppression, retry/dead-letter and acknowledgement are not verified here. A displayed notification preference does not prove delivery.

## Readiness matrix

| Journey component | Result | Evidence boundary |
|---|---|---|
| Customer onboarding information architecture | PARTIAL PASS | Source inspected; guidance/navigation only |
| Customer organization provisioning | PARTIAL PASS | Migration definition inspected; RPC not invoked |
| Organization type and tenant selection | BLOCKED | Enterprise/customer reuse ambiguity |
| Signup terms/privacy consent | FAIL / BLOCKED | User-metadata-derived acceptance |
| Business verification and customer admission | NOT TESTED / BLOCKED | Complete journey not evidenced |
| Customer company profile persistence | NOT TESTED / BLOCKED | Page primarily explanatory |
| Customer team invitation and permissions | NOT TESTED / BLOCKED | Illustrative matrix; no invitation workflow on inspected page |
| Quote listing/detail organization scoping | PARTIAL PASS | Client source filters; RLS runtime not tested |
| Customer shipment booking | NOT TESTED / BLOCKED | Grant and documented RPC gates only |
| Partner quote acceptance dependency | PARTIAL PASS | Source control; no runtime journey |
| Customer quote acceptance/payment/dispatch distinction | PARTIAL PASS | UI disclaimers and source gates; no real booking |
| Billing/credit/refund readiness | NOT TESTED / BLOCKED | Outside completed evidence in this gate |
| Customer notifications and consent delivery | NOT TESTED / BLOCKED | No end-to-end provider delivery |

## Required remediation and test order

1. Define customer organization types and an explicit organization-selection/reuse confirmation; reject ambiguous or mismatched tenant selection instead of silently returning the first eligible membership.
2. Replace user-metadata-derived terms acceptance with a server-controlled, immutable, versioned consent record and explicit policy hash/actor/time; separate contractual terms, privacy acknowledgement and optional marketing consent.
3. Complete the customer admission workflow: legal/business profile as appropriate, authorized representative, billing/contact identity, organization verification rules, support handoff and visible persisted progress.
4. Implement and verify customer team invitation, least-privilege role assignment, revocation and offboarding.
5. Audit RLS and all SECURITY DEFINER/booking RPC grants for customer organization, shipment, quote, invoice, payment and evidence tables; ensure direct REST calls cannot bypass tenant/permission checks.
6. In isolated Staging, test multiple organizations, enterprise/customer reuse, wrong tenant, suspended/removed membership, stale sessions, forged IDs, direct RPC calls, duplicate submissions and recovery after partial signup.
7. Execute the full synthetic customer → quote request → partner offer → partner acceptance → customer acceptance → assignment/capacity → shipment dispatch-readiness journey, with payment and external notifications mocked or controlled.
8. Keep real customer booking and paid commercial launch restricted to routes/services with verified partner, approved corridor, current capability/compliance, confirmed capacity, executed commercial terms and clear payment responsibility.

## Safety boundary

No Production or Staging SQL, RPC, Auth, organization, consent, shipment, quote, booking, payment, notification, provider or deployment operation was executed. No synthetic or real customer account was created. This gate is source-level review only; all runtime journey and RLS negative tests remain NOT TESTED.

## Evidence references

- `docs/audits/KRIM-CUSTOMER-AND-PARTNER-ONBOARDING-VERIFICATION-AND-ACTIVATION-AUDIT-2026-11-16.md`
- `supabase/migrations/20261111190000_record_customer_signup_terms_consent.sql`
- `supabase/migrations/20261115111500_harden_customer_and_partner_organization_provisioning.sql`
- `supabase/migrations/20261105114500_enable_secured_customer_shipment_booking_rpc.sql`
- `public/customer-os/customer-services/onboarding.html`
- `public/customer-os/customer-services/company-profile.html`
- `public/customer-os/customer-services/team-members.html`
- `public/customer-os/customer-services/quote-request.html`
- `public/customer-os/assets/quote-operations.js`

**Gate C3.21: PARTIAL PASS / BLOCKED. Broad customer commercial onboarding and real shipment booking remain NO-GO pending remediation and staged runtime proof.**
