# Step 38 — India-first pilot workflow and partner onboarding audit

Date: 2026-11-13  
Branch: `website/global-launch-readiness`  
Scope: read-only source review of customer booking, quote, payment guidance, partner onboarding and public partner standards. No live account or transaction was created.

## Findings

### 1. Customer booking is aligned with partner-direct launch model (source-level)
- `public/shipper/booking-request.html` clearly states that route search does not confirm active market/serviceability, no payment is taken on the page, and freight payment is arranged directly between customer and contracted partner.
- The form requires an authenticated session and active organization before enabling submission. The source describes idempotent retry handling.
- These are positive design controls, but the real submit flow and backend response have not been exercised with an authorized test account.

### 2. Quote experience avoids fabricated prices (source-level)
- `public/customer/quote-request.html` describes quotes as shipment- and organization-scoped and displays only saved partner offers; it explicitly says no sample quotes are invented.
- Actual partner quote generation/acceptance remains unverified because there are no verified operational partners and no authorized end-to-end test.

### 3. Payment page is currently guidance-only for partner-direct model
- `public/shipper/payment-checkout.html` states customers pay the contracted partner directly and KRIM freight checkout is disabled.
- It checks accepted quote, shipment ownership and partner assignment before any continuation. Source text says the interface does not open KRIM freight checkout.
- Keep the freight checkout environment gate disabled. Do not activate KRIM freight collection for this launch model.

### 4. Critical partner onboarding blocker: new organisation provisioning
- `public/partner/partner-onboarding.html` tells applicants that the verification form requires an active partner organisation already linked to the account.
- It explicitly instructs users who have no active partner organisation to stop and contact KRIM support for account setup, and not to create duplicate accounts or upload documents to another organisation.
- This creates a manual provisioning dependency for every new partner. There is no verified self-service path from a new partner login to a linked organisation in the reviewed source.
- The page offers Development/Test and Individual/Independent pathways, but Development/Test is explicitly non-commercial and Individual/Independent interest is not approval. Neither should be treated as operational activation.

### 5. Public partner standards are appropriately cautious, but not a signed contract
- `partner-standards.html` says the framework is not a signed partner contract, carrier appointment, licence, guarantee of work or promise of payment.
- It requires separate written agreement and shipment-specific acceptance, with verification of actual capabilities and regulatory prerequisites.
- This is a useful public framework, but a signed partner agreement/commercial schedule and CA/legal review are still required before paid referrals or live assignments.

## Step 38 decision
Customer-facing source copy broadly reflects the intended partner-direct model. The immediate operational bottleneck is not another feature: it is the partner organisation provisioning/verification path and the absence of a genuinely verified, activated partner.

## Required next actions
1. Define and verify a controlled partner-organisation provisioning process for new applicants (manual support process is acceptable for a tiny pilot if staffed, documented and access-controlled).
2. Onboard at least one real India partner; verify business identity, authority, service scope, operating area, licences/insurance as applicable, bank/tax details and authorised contact.
3. Sign a partner agreement and separate commercial/referral schedule after CA/legal review.
4. Run authorized test: customer request → partner quote → customer acceptance → partner-direct contract/payment → shipment status/POD → support/exception handling.
5. Verify the website links and live production behavior only after the PR is reviewed and deliberately deployed.

## Limitations
This was a static source review of the PR branch, not browser E2E testing, live API validation, partner verification, legal opinion, payment settlement test or production certification. PR #65 remains unmerged and undeployed. No database, secrets, production data, or payment settings were changed.
