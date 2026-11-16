# KRIM Third-Party Processor, International Transfer and Vendor-Risk Audit — 2026-11-16

## Executive decision

**NO-GO for claiming a complete, contractually governed processor/subprocessor inventory or cross-border data-transfer assurance.** KRIM has a preliminary privacy notice that openly identifies the production Supabase database region as Tokyo and says vendor/transfer review remains outstanding. The code and deployed service inventory reveal multiple actual or potential external recipients, but KRIM does not yet evidence a complete vendor register, executed data-processing agreements, subprocessor schedule, transfer impact assessment, deletion/return commitments, incident-notification SLAs, or periodic vendor review.

This is a read-only architecture and repository audit. No provider APIs were called, no messages/emails/payments were sent, no credentials or secret values were read, and no production configuration, database or user data was changed.

## Evidence baseline

- Repository HEAD before this report: `a4a29cc6310b3b08c4f895af54ac38beb91fa315`.
- Prior privacy lifecycle audit and external integration inventory were reviewed.
- Live Supabase project: active/healthy, PostgreSQL 17.6, region `ap-northeast-1` (Tokyo, Japan).
- 21 active Edge Functions in the current inventory; relevant providers and public functions are listed below.
- Public privacy notice itself says exact legal-operator details, designated privacy contact, live data flows, processors and cross-border transfers require confirmation.
- The notice correctly distinguishes KRIM's intended role from independent carriers, warehouses, customs brokers and payment providers, but it is not a signed vendor register or contract evidence.

## 1. Vendor and data-flow register

| Provider / system | Observed data path or dependency | Likely role (must confirm contractually) | Current evidence / risk |
|---|---|---|---|
| Supabase | Auth, Postgres, Storage, Edge Functions, logs and operational metadata | Core hosting, database, identity and storage processor | Connected. Project database region Tokyo. DPA, subprocessor list, edge execution/log region, backup region, support access and deletion terms not evidenced in this audit. |
| GitHub / GitHub Pages | Public source repository, deployment workflows and static website hosting | Source-code hosting and static site host; not necessarily a customer-data processor for database records | Connected. Repository is public and Pages deployed. Do not commit personal data, secrets, exports, production payloads or private evidence. Confirm Actions artifact retention and access policy. |
| jsDelivr | Enterprise integrations page loads Supabase JS from `cdn.jsdelivr.net/npm/@supabase/supabase-js@2` | Third-party CDN / software delivery provider | Actual remote dependency observed. Browser IP, request metadata and user-agent may be exposed when that page loads. Version is major-range `@2`, not an immutable exact version. |
| esm.sh | Supabase Edge Functions import `@supabase/supabase-js@2` from `https://esm.sh` | Third-party package CDN/build service used by server-side functions | Actual dependency observed in public inquiry and Razorpay webhook sources. Runtime fetch/build provenance and exact dependency pinning need review. |
| Google Fonts | Public privacy page loads DM Sans and Manrope from Google Fonts | Third-party font delivery provider | Actual browser request. Browser IP and request metadata may be exposed. Self-host fonts if minimizing third-party disclosure is preferred. |
| Telegram | Public inquiry Edge Function sends founder alert to Telegram Bot API | Internal notification provider / independent service recipient | Code path exists and sends name, email, organisation, enquiry reference and selected attribution lines to configured chat. Delivery and human receipt not verified. Treat as personal-data disclosure, not merely an internal log. |
| Razorpay | Order creation, payment verification, webhook and refund reconciliation functions | Payment service provider / independent controller or processor depending on service and terms | Technical functions active. Merchant/settlement readiness is not verified; collection is deferred. Never route freight funds through KRIM under the current non-custodial launch model. |
| Cashfree | Active order, verification and webhook Edge Functions | Legacy payment provider | Functions remain ACTIVE despite decision to discontinue. No use intended. Residual attack surface and unclear data retention; retire only after dependency review and controlled authorization. |
| HubSpot | No deployed adapter/sync evidence found in current function inventory | Prospective CRM processor | Not verified/connected. Earlier account was sample-only. Do not send enquiries until data mapping, lawful purpose, DPA, region, access and deletion propagation are reviewed. |
| Resend | Email adapter exists but sending is disabled | Prospective email processor | Not send-ready. Domain authentication, DPA, region, suppression, bounce/complaint webhooks and deletion controls unverified. |
| WhatsApp / Meta | Business App presence previously reported; no deployed Cloud API adapter/webhook verified | Prospective messaging provider; potentially independent controller | No automated integration verified. Do not send customer/driver data until Cloud API setup, template/opt-in, DPA/controller terms, transfer and retention review. |
| Facebook / Instagram / LinkedIn / YouTube | Business presence or planned links; no publishing/inbox/webhook adapter verified | Social platforms, usually separate controllers for platform accounts | No operational customer-data integration evidenced. Avoid uploading lead lists or private shipment/customer content without separate review and notice. |
| Carriers, warehouses, customs brokers, insurers, ERP/TMS/WMS/GPS vendors | Intended future shipment, identity, document, location and operational exchanges | Often independent controllers for their own services; some may be processors acting on KRIM/customer instructions | Architecture only. No approved partner base or connected vendor E2E evidence. Contract and role allocation required per service/corridor. |

## 2. P0 — Tokyo-hosted production data needs a documented transfer assessment

The live Supabase project is in Tokyo (`ap-northeast-1`). The privacy notice discloses this, which is positive, but a region label alone does not establish where every copy or processing activity occurs.

Before commercial data collection, establish and retain evidence for:
- database primary region and any replicas;
- Auth, Storage, Edge Function execution, logs, telemetry, support and abuse-monitoring regions;
- backup/PITR region and retention (the current free-plan backup limitation is separately documented);
- provider subprocessors and their locations;
- remote support access and onward transfers;
- deletion propagation across primary systems, logs, backups and subprocessors;
- transfer mechanism and applicable India/Japan/other-country legal assessment.

Do not promise India-only data residency, regional segregation or global transfer compliance. The current project is not hosted in India.

## 3. P0 — Telegram enquiry alert discloses identifiable enquiry data

The public inquiry Edge Function constructs a Telegram message containing the person's name, email, organisation and enquiry reference. It can also include selected attribution lines extracted from the message. This is a real code path, not just a planned integration.

Required safeguards before real enquiries:
1. Confirm Telegram's terms, processing role, applicable region, retention, support access and transfer implications.
2. Restrict the destination to a controlled founder/internal chat; verify membership and bot access.
3. Minimize content: prefer enquiry reference and a secure KRIM link; avoid full message, phone, documents or sensitive shipment details.
4. Apply role-based access, retention and deletion procedure to Telegram history and backups.
5. Make the privacy notice and enquiry-specific notice accurately describe this disclosure.
6. Ensure marketing consent is not inferred from an enquiry or privacy acknowledgement.
7. Record provider acceptance separately from human receipt; avoid claiming delivery.
8. Review incident response and bot-token rotation without exposing tokens in code or logs.

Until reviewed, use a minimized internal alert only, or disable personal-detail forwarding.

## 4. P1 — Public code and third-party runtime dependencies

The repository is public. The inspected `config.js` contains a Supabase publishable key and project URL. A publishable key is intended for browser use and is not equivalent to a service-role secret; safety depends on RLS, grants and backend authorization. No secret value was read.

Observed remote dependencies include:
- Google Fonts on the public privacy notice;
- jsDelivr for Supabase JS on the enterprise integrations page;
- esm.sh imports in Edge Functions.

Required controls:
- pin exact dependency versions and integrity where supported; avoid floating major-version CDN URLs;
- consider self-hosting fonts and browser SDK assets to reduce third-party browser disclosures and supply-chain exposure;
- maintain an SBOM/dependency inventory, vulnerability monitoring and update owner;
- review transitive dependencies, lockfiles and Deno import maps;
- ensure public repo history contains no private keys, tokens, customer records, exports or internal-only documents;
- treat public GitHub issue/commit metadata and Actions artifacts as potentially public unless repository/workflow access settings prove otherwise.

The publishable key must remain paired with strict server-side authorization; never place service-role keys, payment secrets, bot tokens or database credentials in frontend files.

## 5. P1 — Contract and vendor due-diligence evidence is missing

No executed agreement evidence was established for the vendors in this audit. Before a vendor receives live personal data, create a vendor file containing:
- legal entity and service description;
- controller/processor/subprocessor role and documented instructions;
- signed DPA or equivalent data protection terms where applicable;
- current subprocessor list, processing locations and change-notice rights;
- permitted data categories, purposes, access controls and confidentiality;
- encryption, security testing, incident notification and cooperation obligations;
- retention, return, deletion and backup-expiry commitments;
- audit / assurance evidence, certifications only where verified;
- international transfer mechanism and onward-transfer restrictions;
- service continuity, exit assistance and secure migration;
- support access, privileged access and breach contact;
- renewal date, risk rating, owner and last review date.

Do not describe a provider as “DPDP compliant”, “GDPR compliant”, certified or contractually approved without current documentary evidence and a scoped legal assessment.

## 6. P1 — Define controller/processor boundaries for logistics partners

A carrier, warehouse, customs broker or insurer may independently determine parts of its processing (for example, statutory transport records, customs filings, driver employment, safety and insurance). It may therefore be an independent controller for some activities and a processor for others. Labels must follow actual purpose and decision-making, not the commercial title “partner”.

For each data exchange, document:
- which party collected the data and gave the notice;
- purpose and lawful basis / applicable permission;
- minimum fields shared and permitted onward recipients;
- who handles access, correction, deletion and objection requests;
- who reports incidents and coordinates regulatory notices;
- cross-border transfer and country/corridor constraints;
- retention and evidence obligations;
- whether driver location or identity documents are necessary at all.

Do not expose a partner to all customer data merely because it has an active organization membership or shipment role.

## 7. P1 — Payment-provider data boundary and non-custodial model

The current commercial decision is that customers contract with and pay logistics partners directly; KRIM does not receive, hold, pool, escrow, split, settle or pay out partner freight funds. KRIM's separate service/referral fee is distinct and should only be implemented after legal, tax, provider and merchant approval.

For any later Razorpay own-fee flow:
- send only necessary payer and KRIM fee data;
- identify KRIM as merchant only for KRIM's own service fee, not partner freight;
- verify merchant category, KYC, settlement account, provider contract and refund/chargeback responsibilities;
- do not treat provider webhook receipt as legal or accounting proof without reconciliation;
- define provider data retention, fraud screening and cross-border access;
- keep historical freight payment endpoints disabled/quarantined until separately remediated.

Cashfree remains a legacy active deployment and should not be used.

## 8. Legal and governance caution

The privacy notice itself correctly says the Digital Personal Data Protection Act, 2023 and Rules, 2025 have phased commencement and the provisions applicable to a particular activity must be checked against current Gazette notifications and commencement dates. This audit does not give a legal opinion or determine whether KRIM is a data fiduciary, processor, significant data fiduciary, intermediary or other regulated entity for every activity.

Before launch, an India-qualified privacy lawyer/CA should confirm the applicable commencement provisions, notices, consent requirements, grievance contact, processor contracts, cross-border restrictions and sector-specific logistics/customs/accounting duties. Also assess the laws of each country where users, partners, drivers, recipients or shipments are located.

## 9. Required evidence and release gates

| Gate | Evidence required | Status |
|---|---|---|
| Canonical vendor register | Named owner, role, service, data categories, locations, enabled state, risk and review date | Not evidenced |
| Supabase contract/region map | DPA, subprocessors, all service regions, backups, support access and deletion | Not evidenced |
| Telegram disclosure review | Data minimization, chat membership, retention, notice, incident and deletion controls | Not evidenced |
| Payment-provider review | Merchant contract/KYC, own-fee boundary, region and data responsibilities | Not ready |
| Email/CRM/messaging | Provider DPA, region, consent, opt-out, webhook verification and deletion propagation | Not connected / not ready |
| Third-party browser inventory | All external scripts, fonts, pixels, embedded content and cookie behavior | Partial; Google Fonts and jsDelivr observed |
| Supply-chain inventory | Pinned versions, lockfiles/SBOM, vulnerability owner, secret scanning | Incomplete |
| Partner data-sharing terms | Controller/processor split, data-sharing agreement, security, rights and transfer clauses | Not evidenced |
| International transfer review | Current law and Gazette review, transfer assessment and approved country/corridor scope | Not complete |
| Exit and deletion test | Verified export/return, account termination, vendor deletion and backup expiry | Not tested |

## 10. Recommended execution order

1. Build a canonical vendor registry and classify each provider as connected, implemented-not-tested, planned, disabled or blocked.
2. Minimize Telegram enquiry alerts immediately in source before accepting real enquiries; keep no live customer notifications until the data-sharing boundary is approved.
3. Obtain Supabase DPA/subprocessor and full region/backup/support evidence; record Tokyo hosting transparently.
4. Pin CDN/runtime dependencies and complete public-repository secret scanning.
5. Keep Cashfree unused; plan retirement only after endpoint and payment-event dependency review.
6. Draft vendor DPA and logistics partner data-sharing addenda; obtain qualified legal review.
7. Add provider deletion/rights/incident workflow to the privacy lifecycle before live data collection.
8. Run staging-only data-flow and deletion tests with synthetic records.

## Release decision

**NO-GO for claiming processor governance, India-only residency, complete international-transfer compliance, or commercial data-sharing readiness.** The system architecture is identifiable, and the current privacy notice is appropriately cautious, but contracts, regional processing evidence, minimization, vendor register and rights/deletion propagation remain unverified.

No production configuration, customer data, database schema, credentials, payment state, notification destination or provider account was changed during this audit.
