# C3.34 — Global Partner, Customer & Driver Acquisition Readiness Audit

**Date:** 25 November 2026  
**Immutable source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**QA branch:** `qa/phase-00-baseline-2026-11-25`  
**Method:** Read-only review of partner-first activation policy, partner acquisition/onboarding and verification journeys, public customer enquiry funnel, founder/admin acquisition workspace, outreach/runtime modules, driver onboarding and C3.20–C3.22 findings. Historical Production counts are explicitly dated; source inspection is not runtime testing. No accounts, prospects, CRM records, messages, calls, campaigns, uploads or operational assignments were created.

## Executive verdict

**FAIL / BLOCKED — NO-GO for scaled or automated acquisition, and NO-GO for representing any partner, customer or driver as commercially active without independent evidence.**

KRIM has useful foundations: supply-first activation policy, differentiated partner pathways (development/test, individual interest and registered business), private evidence and independent review stages, a public customer enquiry endpoint with privacy/abuse controls, and a restricted founder enquiry desk. But none of the three acquisition funnels is proven end-to-end in runtime. The historical customer funnel was empty; partner pipeline rows did not represent verified capacity; driver operational records were empty; and the CRM/notification and commercial hand-off have material workflow gaps.

The correct strategy remains **partner-first, one exact service cell at a time**, then customer acquisition only after verified supply exists. Driver acquisition must be carrier-sponsored and linked to a verified partner, eligible vehicle, exact route/leg and lawful driver checks—not a generic driver signup campaign.

## 1. Evidence reviewed

- `docs/commercial/KRIM-PARTNER-FIRST-NETWORK-ACTIVATION-PLAN.md`
- `docs/growth/KRIM-FIRST-PARTNER-ACQUISITION-SPRINT-AND-QUALIFICATION-PLAYBOOK-2026-11-16.md`
- `docs/growth/KRIM-FIRST-PARTNER-OUTREACH-AND-VERIFICATION-PACK-2026-11-16.md`
- `docs/growth/KRIM-PUBLIC-ENQUIRY-TO-CUSTOMER-ACQUISITION-PIPELINE-AUDIT-2026-11-16.md`
- `docs/growth/KRIM-FOUNDER-ADMIN-ACQUISITION-WORKSPACE-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-PARTNER-ACQUISITION-WORKSPACE-AND-VERIFICATION-JOURNEY-ASSURANCE-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-CRM-CUSTOMER-CONVERSION-AND-COMMERCIAL-HANDOFF-VERIFICATION-ADDENDUM-2026-11-16.md`
- `docs/audits/KRIM-CRM-CONSENT-NOTIFICATION-AND-EXTERNAL-COMMUNICATION-ASSURANCE-AUDIT-2026-11-16.md`
- `docs/growth/KRIM-RANCHI-PARTNER-PROSPECT-SHORTLIST-2026-11-11.md`
- `docs/growth/KRIM-RANCHI-ROAD-PILOT-PARTNER-ACTIVATION-READINESS-2026-11-16.md`
- Source: `public/growth/acquisition-runtime.js`, `customer-growth-runtime.js`, `activation-runtime.js`, `partner-outreach.html`, `customer-acquisition.html`, and `app/driver/index.html`.
- Prior C3.20 Partner, C3.21 Customer, C3.22 Driver, C3.30 Notification, C3.32 Privacy and C3.33 Legal/Commercial gates.

## 2. Partner acquisition

### Positive controls
- The supply-first plan defines a service cell by origin, destination, mode, service, cargo/equipment/capacity and operating dates.
- Development/test, individual-interest and registered-business pathways are separated; test and individual-interest profiles remain non-commercial.
- Registered-business onboarding requires identity and operating information, private evidence, and human verification. Identity approval does not automatically approve compliance, capability or service area.
- Independent privileged/AAL2 review exists for identity, compliance, capability and service area; evidence ownership and expiry are part of the intended model.
- Recruitment page copy was corrected to remove unsupported shipper counts, guaranteed loads, international corridor and escrow payout claims.
- Acquisition policy correctly prohibits fabricated rates, capacity, transit times, leads, exclusivity or guaranteed revenue.

### P0/P1 blockers
1. C3.20 historical snapshot found zero verified active partner capabilities, zero approved service areas, zero capacity commitments and zero executed contracts/SLA. One open verification case related to a development/test account and is not a commercial carrier.
2. Partner onboarding and capability review contract is inconsistent: onboarding-created capability rows lacked `submitted_by` and evidence metadata expected by the approval RPC. Do not bypass independent review.
3. Identity, compliance, capability, service area, commercial contract, corridor and current capacity remain separate approvals. A single “verified” badge cannot represent all of them.
4. Individual-interest profiles are not a complete commercial due-diligence path. Driver/individual providers need identity, permits, insurance, vehicle, safety, tax and contract checks appropriate to jurisdiction and service.
5. Invitation delivery, lifecycle suspension/expiry/renewal, transfer/offboarding, partial failure and notification reliability remain unproven.
6. Static `acquisition-runtime.js` explicitly marks duplicate detection and prospect creation as backend-required and automated outreach disabled. It only initializes the page module; it does not create prospects or send outreach.
7. Prospect research documents explicitly say candidates are unverified and uncontacted. Public listings and company marketing are discovery signals only.

**Decision:** Continue manual, transparent, low-volume discovery. No prospect is an active KRIM partner until exact legal entity, authority, service capability, geography, capacity, compliance, insurance, contract and corridor approvals are complete.

## 3. Customer acquisition and conversion

### Positive controls
- Public contact form asks for privacy consent, links the notice, includes a honeypot, applies input validation and rate limits, and says an enquiry is not a booking or quote.
- Public enquiry table is deny-by-default to client roles; submission and rate-limit RPCs are restricted to service role/postgres in the reviewed snapshot.
- Founder enquiry desk uses a protected admin function with AAL2 and platform-admin role checks in checked-in source; it provides enquiry status and internal follow-up notes.
- The acquisition overview distinguishes recorded pipeline counts from actual leads, customers, bookings and revenue.

### P0 blockers
1. The 16 November historical Production funnel snapshot had zero public enquiries, customer accounts, acquisition profiles/events, qualification cases, service requests, follow-ups, referrals, consent-ledger rows, partner match runs/results, partner quotes and shipment assignments. Three partner opportunities were historical/expired/cancelled—not qualified customer demand or available capacity.
2. The public enquiry submission RPC creates an acquisition profile without an organisation binding, so normal authenticated RLS-based admin screens cannot read the profile. A dedicated narrowly scoped admin read path or safe owner/org binding is required; never solve this by broadening PII access.
3. The public submission RPC creates an initial pending qualification case, then downstream service-request linkage can create a second qualification case. Establish exactly one canonical qualification case per enquiry/request.
4. If service-request linkage fails after enquiry storage, the endpoint still returns a successful receipt but the audit did not establish a durable retry/reconciliation record. A lead may be saved but stranded downstream.
5. The founder/admin workspace audit found audit writes best-effort rather than atomic; the UI may claim an action was audited when the audit insert failed. Lead status/follow-up write and audit must be transactionally consistent.
6. No lead owner/assignment, team hand-off, priority, SLA, due/overdue escalation or reassignment model exists. Follow-up notes are not an accountable work queue.
7. “Qualified” and “converted” follow-up outcomes are notes, not canonical qualification/customer conversion. A converted customer must be bound to a verified user and organisation; first completed business requires shipment completion evidence; revenue requires a separately earned and received KRIM fee.
8. Customer-growth runtime logs that consent rules are enforced but is only a lightweight initializer; source inspection does not prove campaign consent enforcement or a live acquisition automation engine.

### P1 blockers
- Dedicated customer consent ledger was empty in the historical snapshot even though the form stores checkbox/notice-version fields on the inquiry; capture purpose, channel, notice version, timestamp, source and withdrawal evidence correctly.
- Attribution, enquiry category, phone, country and reference were embedded in free text rather than typed structured fields.
- IP throttling depends on trusted edge IP header presence; verify and fail safely if unavailable.
- Follow-up APIs differ in status behaviour and past-time validation; consolidate to one canonical backend workflow.
- Status transitions lack reason and prior-state controls; due/overdue queue and reminder delivery are not fully proven.
- Deployed admin function byte-for-byte parity with checked-in source was not established in the historical audit.
- CRM integration, lead sync, deduplication, consent suppression, delivery receipts and recovery are not end-to-end verified.

**Decision:** Public non-binding enquiry intake may be retained with accurate disclosure, but do not scale campaigns or claim a complete CRM/customer conversion funnel until the P0 defects are remediated and staging tests pass.

## 4. Driver acquisition and activation

### Positive controls
- Driver admission is designed around carrier invitation and exact partner/assignment context, with identity/licence evidence and review, active membership, vehicle binding and dispatch eligibility.
- C3.22 source review found newer SHA-256, email-bound, expiring invitation flow and later independent multi-document review.
- Driver self-approval is blocked in the reviewed control path; licence expiry is checked in dispatch-related logic.
- Driver route aliases resolve to the canonical dashboard, but the word “staging” in a page path is not proof of environment isolation.

### P0/P1 blockers
1. C3.22 historical Production snapshot had zero driver profiles, identity/licence documents, assignments, vehicles, vehicle documents/bindings, tracking, dispatches, POD and driver events. There is no live operational driver cohort.
2. Competing invitation implementations/signatures exist (newer SHA-256 private invitation path vs legacy MD5 organisation invitation path); atomicity, recovery, replay and delivery acknowledgement are unproven.
3. An older aggregate profile-review path may not enforce the newer three-document review requirement; reviewer independence needs consistent enforcement.
4. Carrier invitation and driver membership lifecycle lacks complete transfer/offboarding, revocation, suspension, in-flight stop-work and recovery handling.
5. Per-trip roadworthiness/pre-trip inspection is not a proven mandatory dispatch gate. Licence/vehicle records alone do not prove the vehicle is safe and available for a particular job.
6. Driver acquisition must not be opened as an independent supply marketplace: a driver is not a carrier, does not independently establish partner authority, and must be tied to the contracting carrier, verified vehicle and exact shipment leg.
7. Driver earnings/payroll are not a KRIM-managed ledger or payout feature (C3.15). Do not promise KRIM driver payouts; compensation remains between carrier and driver unless a separately approved legal/payroll model is established.

**Decision:** No public promise of driver jobs, earnings, route availability or dispatch. Driver onboarding only through a verified carrier's controlled invitation and exact operational eligibility checks.

## 5. Cross-ecosystem acquisition governance

- The three funnels must have distinct, auditable lifecycle states. Prospect ≠ invited ≠ registered ≠ verified ≠ contracted ≠ activation-ready ≠ active.
- A customer enquiry is not a qualified lead; a qualified lead is not a customer account; a customer account is not a booking; a booking is not a completed shipment; a completed shipment is not KRIM revenue.
- A partner profile is not a verified capability; a verified capability is not an approved corridor; a corridor is not current capacity; a capacity record is not a confirmed shipment acceptance.
- A driver account is not an eligible driver for every carrier, vehicle, country, route or shipment.
- Consent must be purpose/channel specific. No cold automated messaging, scraped contact campaigns, bulk WhatsApp/email or Telegram customer notifications without lawful basis, applicable consent, suppression, provider policy and an approved workflow.
- Founder alerts are internal operational notices, not customer delivery receipts. Telegram API acceptance is not proof that a human received/read a message.
- All acquisition metrics must be sourced from canonical backend records with freshness and provenance; no hard-coded performance metrics or unsupported “network size” claims.

## 6. Recommended execution sequence

1. Fix partner onboarding/capability submission metadata and reviewer independence; prove one complete registered-business partner lifecycle in isolated staging.
2. Select one narrowly scoped service cell (initial candidate: Ranchi ↔ Jamshedpur, road, ordinary non-hazardous/non-temperature-controlled cargo) but do not advertise it until legal/corridor/partner approvals exist.
3. Fix public enquiry profile binding, one-case idempotency and durable service-request linkage retry; add structured fields and consent ledger.
4. Make founder lead writes and audit atomic; add owner assignment, SLA, status transitions, due/overdue queue and canonical follow-up API.
5. Establish customer qualification → verified account/org binding → partner referral → customer-provider contract → shipment completion → separate KRIM fee recognition evidence.
6. Resolve driver invitation signature/version conflict, invitation atomicity and recovery; enforce independent identity/licence/vehicle review, pre-trip checks, offboarding and in-flight stop-work.
7. Verify CRM integration and all email/Telegram/WhatsApp delivery, consent, retry, suppression and audit paths in staging; no bulk outreach until approved.
8. Run end-to-end synthetic journeys separately for partner, customer and driver, then cross-ecosystem hand-offs. No production writes or real communications in these tests.

## Gate decision

**C3.34 FAIL / BLOCKED.** Partner-first strategy is sound, and meaningful intake/onboarding components exist, but acquisition and conversion are not ready for scaled real-user onboarding. A small number of manually managed, non-binding partner discovery conversations may continue; do not mark anyone active or promise commercial opportunity until the evidence gates pass.

**Safety record:** No Production/Staging changes, new users, prospects, CRM records, partner/driver onboarding, evidence uploads, outreach, marketing campaigns, emails, WhatsApp, Telegram or payments were performed. Historical counts are dated snapshots, not current live measurements. No browser runtime journey was executed.
