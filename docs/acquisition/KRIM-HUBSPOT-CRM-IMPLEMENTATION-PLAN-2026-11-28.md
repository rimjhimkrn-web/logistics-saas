# KRIM HubSpot CRM implementation plan
Date: 2026-11-28
Status: design prepared; CRM writes blocked by HubSpot permissions.

## Purpose
Use HubSpot as the acquisition and relationship-management workspace for KRIM Logistics. Supabase remains the operational source of truth for onboarding, verification, capabilities, service areas, shipment eligibility, and operational status. Do not duplicate operational authority in HubSpot.

## Verified portal state
- Portal: KRIM Logistics
- Portal ID: 247844782
- UI domain: app-na2.hubspot.com
- Account currency: USD
- Account timezone: US/Eastern
- Contacts: 2 total; the returned records are starter/sample contacts.
- Deals: 0
- Existing deal pipeline: Sales Pipeline
- Stages: Appointment Scheduled, Qualified To Buy, Presentation Scheduled, Decision Maker Bought-In, Contract Sent, Closed Won, Closed Lost.
- Read access: available for CONTACT, COMPANY, DEAL, TICKET.
- Write access: REQUIRES_PERMISSION_MODIFICATION for all four types.
- User identity section was not returned due missing permissions. The connected app may need reauthorization for user information as well.
- No CRM records, pipelines, properties, or settings were changed.

## Recommended CRM operating model
Keep the three acquisition funnels distinct using standard CRM records and explicit segmentation:
1. Partner / carrier acquisition
2. Customer / shipper acquisition
3. Driver acquisition

Use CONTACT for people, COMPANY for registered businesses, and DEAL for a qualified commercial opportunity or onboarding opportunity. Do not create deals for unqualified directory listings. Use TICKET only for support/escalation after a real service relationship exists.

### Contact properties to use where available
- firstname, lastname, email, phone, jobtitle, company
- lifecyclestage
- hs_lead_status
- hubspot_owner_id
- source/channel fields if present in portal schema

Recommended custom contact properties (create only after write access and schema review):
- krim_ecosystem: PARTNER | CUSTOMER | DRIVER
- krim_acquisition_stage: IDENTIFIED | CONTACTED | RESPONDED | QUALIFICATION | DOCUMENTS_PENDING | VERIFIED | ACTIVE | DECLINED | DORMANT
- krim_country, krim_state, krim_city, krim_locality
- krim_preferred_language
- krim_contact_consent_status, krim_consent_captured_at
- krim_next_follow_up_at
- krim_source_campaign

### Company properties to use where available
- name, domain, website, phone, city, country, industry, numberofemployees, type, description
- hs_is_target_account, hs_ideal_customer_profile
Recommended custom company properties:
- krim_business_type: CARRIER | TRANSPORTER | WAREHOUSE | FREIGHT_FORWARDER | SHIPPER | MANUFACTURER | MSME | OTHER
- krim_service_modes
- krim_service_regions
- krim_verification_status: NOT_STARTED | PENDING | VERIFIED | REJECTED | EXPIRED
- krim_compliance_review_date
- krim_operational_activation: INACTIVE | ACTIVE | SUSPENDED
- krim_supabase_org_id (reference only; never credentials)

### Deal usage
Use a deal only when there is a genuine commercial opportunity with a named party, service scope, owner, next step and expected decision. Keep the current Sales Pipeline stages; do not rename stages until the team confirms the sales process and permissions allow it.
Suggested deal naming: [Ecosystem] – [Company/Contact] – [Service/Route].
Do not set Closed Won merely because a partner is verified or a customer expressed interest. Closed Won means a documented commercial agreement/earned revenue event consistent with KRIM's referral/coordination model.

## Safety and business rules
- KRIM's initial India model is a referral / lead-generation / coordination marketplace.
- Customers contract and pay logistics partners directly.
- KRIM must not collect or hold freight payments, issue partner freight invoices, or settle freight on partners' behalf.
- KRIM's own referral / marketing / coordination fee must be separately agreed and documented.
- Do not record or imply GST registration where the application was rejected.
- Do not mark a partner, driver, service capability, market, corridor, or route as verified/active based only on a HubSpot CRM stage.
- Supabase remains the authority for KYC, documents, compliance, partner capability, service areas, country packs, corridor activation, and dispatch eligibility.
- Do not store identity documents, bank credentials, passwords, payment-card data, or sensitive verification files in HubSpot notes/properties. Store approved references only.
- Do not bulk import public-directory leads or send unsolicited marketing. First validate identity, relevance, source, lawful basis/consent, and outreach policy.

## Required HubSpot permission gate
Before any CRM setup writes:
1. Reauthorize the HubSpot app if needed.
2. Grant CRM create/edit permissions for Contacts, Companies, Deals and (only if needed) Tickets.
3. Grant user-information read permission if the current-user identity section is required.
4. Re-run schema discovery and confirm writeAccess is AVAILABLE.
5. Review the exact proposed custom properties and pipeline changes before applying them.
6. Confirm portal currency/timezone settings with the account owner before changing them. The current USD / US-Eastern values were observed; they were not changed.

## Activation checklist
- [ ] HubSpot write access confirmed for required objects.
- [ ] India business timezone/currency reviewed and corrected by authorized portal admin if appropriate.
- [ ] Three acquisition segments and consent/source fields configured.
- [ ] Contact/company associations tested.
- [ ] Deal pipeline semantics agreed and configured.
- [ ] Website enquiry integration mapped to Supabase first, with a reliable, consent-aware HubSpot sync/outbox and retry handling.
- [ ] Duplicate detection and idempotency tested.
- [ ] Test records created only in a test/sandbox context or clearly labelled test data.
- [ ] End-to-end form-to-CRM test passes; failure/retry and audit history verified.
- [ ] No live service activation until partner, route, compliance and operational checks pass.

## Current blocker and next action
The connected HubSpot app can read CRM data but cannot create/update CONTACT, COMPANY, DEAL or TICKET records. HubSpot returned REQUIRES_PERMISSION_MODIFICATION for writeAccess. This is an account/app permission gate; it cannot be bypassed from the connector. No writes have been attempted. After permissions are updated, rerun schema discovery and implement in small, auditable batches.
