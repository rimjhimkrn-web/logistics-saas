# KRIM Ranchi Road Partner Activation & First-Corridor Readiness
**Date:** 16 November 2026  
**Scope:** Read-only production review of partner account pathways, business verification, compliance evidence, capability and service-area submissions/reviews, commercial contracts, active India locations/modes, and preliminary public prospect research for a controlled Jharkhand road pilot.

## Executive decision
**The partner onboarding product exists, but there is no verified, compliant, contracted, route-ready partner in production. KRIM should not accept a real freight booking yet.**

The most practical first corridor to validate is **Ranchi ↔ Jamshedpur, Jharkhand, India**, limited initially to road transport and ordinary, non-hazardous commercial cargo. This is a proposed pilot corridor only, not a live KRIM service. Both cities already exist as active locations in the India market catalogue and the ROAD mode is active. This removes a catalogue setup dependency, but does not prove partner coverage, capacity, pricing, route permissions or customer demand.

A preliminary public prospect shortlist is included below. These are research leads, not approved partners. No contact was made, no outreach was sent, no organisation was created, and no document was uploaded or verified.

## 1. Production partner snapshot

| Item | Current state |
|---|---:|
| Partner/carrier organisations found in primary types | 3 |
| Registered-business partners with verified status | 0 |
| Development/test partner accounts | 1 |
| Open verification cases | 1 |
| Submitted compliance evidence rows | 0 |
| Compliance review rows | 0 |
| Partner service-area requests | 0 |
| Partner capability records | 1 |
| Active and verified capabilities | 0 |
| Partner onboarding checklist rows | 0 |
| Signed/active service contracts | 0 |
| Open partner opportunities with current deadline | 0 |
| Partner bids | 0 |
| Accepted assignments | 0 |

Current partner organisations:
- Organisation #2, KRIM Test Transport Partner: account mode unset, verification not started, compliance not started, lifecycle not applicable. This is not a production partner.
- Organisation #14, ABC Logistics: explicitly marked `development_test`, sample-data-only, commercial access false, verification pending, compliance pending. Its single capability is inactive and pending verification.
- Organisation #17, KRIM Driver Account: a driver-individual carrier record, not an independently verified freight business.

One open verification case exists for organisation #14. It is a development/test account and must not be approved for commercial access.

## 2. Partner onboarding pathways

The public `public/partner/partner-onboarding.html` form offers three clearly differentiated paths:

### Development / Test
- Uses `krim_set_partner_account_mode`.
- Marks sample/test-only and commercial access false.
- No business documents are required.
- Correctly avoids treating a test account as an operational carrier.

### Individual / Independent
- Collects display name, country, city and service category.
- Stores the interest profile in organisation metadata with `review_status=interest_recorded`.
- Explicitly returns commercial access false.
- This is an expression of interest, not identity verification or approval. It still needs a defined country-specific legal/permit/insurance review before an individual can be commercially activated.

### Registered Business
- Requires an active partner organisation membership and registered-business account mode.
- Requires legal name, country, authority/registration ID, registered address, operating location, service categories and category-specific coverage.
- Requires at least one registration document in the private verification bucket.
- Calls `krim_submit_partner_onboarding_global_multi_v1`.
- Creates/updates capability records as inactive and pending verification, not immediately bookable.
- Displays a clear message that human compliance review is required and commercial access remains restricted.

**Positive finding:** the public flow distinguishes testing, independent interest and registered business. The registered-business path does not automatically enable commercial access.

**P1-A — Independent interest is stored in organisation metadata.** It is not a full individual verification case or a dedicated due-diligence workflow. Before individual providers can carry live freight, define required identity, permit, vehicle, insurance, safety, tax and contracting checks by jurisdiction and service type.

**P1-B — Category-to-capability mapping needs careful review.** The multi-category RPC maps selected categories to transport modes and service types, then creates inactive pending capability rows. It uses the first selected category as the legacy single-category value passed into the older onboarding RPC. Staging tests must confirm multiple categories persist consistently and that no legacy single-category field silently misrepresents the partner's actual scope.

## 3. Verification and activation gates

The verification review RPC is SECURITY DEFINER and checks:
- authenticated reviewer;
- AAL2;
- platform-admin permission;
- open/reviewable case;
- registered-business account mode for approval;
- active logistics organisation;
- required legal identity and registered/operating address metadata;
- registration document path and private storage ownership by the original submitting user.

Approval changes business verification to verified and lifecycle to approved, but explicitly leaves compliance pending. Therefore business verification alone is not sufficient for commercial activation.

The capability review queue is separately protected by privileged MFA verification. Service-area review is a separate admin workflow. Partner service-area submission itself requires:
- active partner manager permission;
- registered-business mode;
- active organisation;
- current compliance;
- valid country/market/location scope;
- active transport mode;
- one to five private, submitter-owned evidence files;
- non-backdated effective dates.

The capability submission RPC is also a separate flow and creates pending verification evidence. The only current capability is inactive and pending.

**P0-A — No production-ready partner.** All three inspected organisations are either test/driver records or unverified. Do not open partner matching or show customer-facing coverage until each relevant verification, compliance, capability and service-area gate is satisfied.

**P0-B — Commercial contract layer is empty.** `krim_service_contracts` contains zero rows. The existing partner platform needs a signed and versioned agreement, authority/signature verification, service scope, liability/insurance, service levels, referral economics, data protection, complaint/claim processes and expiry/renewal controls before customer referrals.

**P1-C — Independent approval must remain independent.** Keep founder/submitter self-approval blocked. Review legal identity, compliance evidence, capability and service area as distinct decisions, with reviewer, evidence, date, rationale and expiry.

## 4. First corridor: Ranchi ↔ Jamshedpur

Production catalogue confirms:
- India market is active (INR, Asia/Kolkata).
- Ranchi is an active Jharkhand location in the India market.
- Jamshedpur is an active Jharkhand location in the India market.
- ROAD transport mode is active.
- Both endpoints therefore exist in the current KRIM market/location catalogue.

Recommended pilot boundary:
- Route: Ranchi ↔ Jamshedpur, both directions.
- Mode: road only.
- Cargo: ordinary, non-hazardous, non-temperature-controlled commercial cargo only, subject to partner capability and cargo acceptance.
- Start with one specific shipment profile and one named provider; do not claim general FTL/LTL coverage.
- No dangerous goods, high-value cargo, cold-chain, ODC, customs, rail, ocean, air or multimodal legs in the first pilot.
- No rate published until the selected partner submits and KRIM/customer validates a live written offer.
- Partner contracts directly with the shipper and collects freight charges directly. KRIM does not collect or settle freight money.
- Any KRIM referral fee is a separate written agreement and subject to CA/legal review. Do not assume GST exemption.

The corridor is a sensible first operational test because the catalogue already supports both cities and road mode. It is not yet approved for customer bookings: no matching partner service area, capability, capacity or rate exists.

## 5. Preliminary Ranchi prospect research (uncontacted / unverified)

The following prospects surfaced in public local listings and corporate-information searches. Public listings and directory claims are not due diligence. Verify the exact legal entity, current MCA status, GST/PAN where appropriate, authorised signatory, insurance, permits, service scope, lane, fleet and subcontractor controls through secure channels before onboarding.

| Prospect | Public evidence found | Initial fit hypothesis | Main verification question |
|---|---|---|---|
| R3 Carriers Private Limited | Third-party corporate directory lists it as an active Ranchi company under road freight transport; CIN shown as U60231JH2016PTC009333 | Potential registered road-carrier lead | Does it currently operate Ranchi–Jamshedpur general cargo, and what fleet/capacity is controlled directly? |
| JRW Transfreight Private Limited | Third-party company profile describes an active Ranchi-based road transport/carrier-services company | Potential established carrier lead | Verify latest MCA filings, exact service and operating lanes, insurance and subcontracting |
| Agrawal Transport, Upper Bazar | Local business listing describes transportation, logistics, truck rental and trucking services | Potential local transport operator | Confirm legal identity, whether it carries commercial freight itself, vehicle ownership and intercity lanes |
| Bhardwaj Road Carrier, Upper Bazar | Local listing identifies a goods-carrier/transport service in Ranchi | Potential local/regional carrier lead | Confirm legal constitution, freight categories, lane coverage, capacity and claims process |
| NGT Freight Carrier's Pvt Ltd, H.B. Road | Local listing describes a transport service and claims FTL capability; listing has no reviews | Possible larger road-carrier lead | Independently verify company registration, actual fleet, operating office, customer references and Ranchi–Jamshedpur availability |
| VRL Logistics Ltd, Kathal More | Local branch listing identifies a VRL Logistics location in Ranchi | Potential established network/benchmark prospect | Confirm whether the branch accepts third-party platform referrals or has a formal partner programme |

**Priority for a first discovery call:** R3 Carriers, JRW Transfreight and Agrawal Transport. This is a research priority, not a quality ranking. No prospect is approved or represented as a KRIM partner.

### Public source register
- R3 Carriers corporate directory profile: https://www.zaubacorp.com/R3-CARRIERS-PRIVATE-LIMITED-U60231JH2016PTC009333
- Ranchi transport/logistics listings: https://pinkbazaar.in/services/ranchi/transport-logistics/
- JRW Transfreight company profile: https://www.thecompanycheck.com/company/jrw-transfreight-private-limited/U60222JH2018PTC011499
- Ranchi transport business listing for Agrawal Transport and other local operators: https://pinkbazaar.in/services/ranchi/transport-logistics/

## 6. Exact partner onboarding sequence for one pilot provider

1. Introductory call; confirm exact legal entity and authorised partnership contact.
2. Confirm provider is willing to contract directly with customers and collect freight payments directly.
3. Confirm exact lane, cargo exclusions, vehicle types, service days, lead times, cut-offs and emergency contacts.
4. Obtain legal registration and authorised signatory evidence through KRIM's private onboarding form.
5. Verify applicable permits, vehicle fitness/registration, driver credentials, insurance and cargo liability; validate evidence expiry and issuing source.
6. Confirm owned fleet versus subcontractors and controls over subcontracted capacity.
7. Obtain customer references and review claims, loss, damage, delay and dispute handling.
8. Complete partner verification decision by an independent AAL2 platform reviewer.
9. Complete compliance review with current evidence and expiry dates.
10. Submit capability with mode, service type, coverage country/region, maximum weight, equipment and operational constraints.
11. Submit route-specific service area for Ranchi and Jamshedpur with evidence; independently review and activate only the supported scope.
12. Agree operational capacity and a repeatable availability-confirmation process.
13. Sign a reviewed non-exclusive partner/referral agreement; store signed version, signatory authority, fee trigger, invoice process, term, termination, liability, data and complaint rules.
14. Test a dummy opportunity in staging, then a real low-risk customer requirement only after customer consent and partner confirmation.
15. Confirm partner directly contracts with shipper, partner collects freight, delivery evidence is returned, and KRIM separately invoices only an earned contractual referral fee under CA-approved tax treatment.

## 7. Go-live checklist for the first route

All must be true:
- [ ] Partner is a real registered business or separately approved eligible independent provider.
- [ ] Legal identity and authorised signatory independently verified.
- [ ] Required permits, insurance and safety evidence current.
- [ ] Partner verification approved; compliance cleared.
- [ ] ROAD capability approved and active.
- [ ] Ranchi and Jamshedpur service areas approved and active.
- [ ] Capacity confirmation received for the actual shipment and vehicle.
- [ ] Written quote includes currency, validity, inclusions, exclusions, taxes and cancellation terms.
- [ ] Signed provider/customer service terms and separate KRIM referral agreement are in place as applicable.
- [ ] Customer consent to share details with the named provider captured.
- [ ] Customer contracts and pays provider directly.
- [ ] Dispatch, driver/vehicle, tracking, exception and verified POD workflow tested.
- [ ] Claims, cancellation, failed delivery and support contacts documented.
- [ ] KRIM does not hold freight funds or recognise freight GMV as KRIM revenue.

## 8. Required staging tests
1. Development/test account cannot submit live bids or receive commercial shipments.
2. Individual-interest account remains non-commercial until a jurisdiction-specific identity and compliance review is complete.
3. Registered-business submission requires private registration evidence owned by the submitting user.
4. Another organisation's user cannot submit or alter a partner's verification packet.
5. Duplicate onboarding submissions do not create duplicate cases/capabilities or overwrite a previously reviewed record.
6. Multi-category submissions persist each selected category and coverage accurately, independent of category order.
7. Verification approval requires AAL2, platform-admin role, evidence existence and reviewer independence.
8. Verification approval alone does not activate commercial access.
9. Compliance approval requires all jurisdiction-specific mandatory checks and valid evidence dates.
10. Expired, revoked or replaced evidence removes current compliance eligibility until reviewed again.
11. Capability cannot become active without independent review and matching evidence.
12. Service area cannot be submitted before current compliance, and cannot be active without separate review.
13. Service-area scope must reference active country/market/location and a valid mode.
14. Matching requires the active capability and approved service area to both cover the exact shipment.
15. Capacity confirmation is shipment-specific and expires/locks correctly under concurrency.
16. Partner cannot view unrelated customer data or another partner's private evidence.
17. Signed agreement version, parties, signature authority, commercial terms, term and expiry are auditable.
18. A partner cannot accept work beyond its verified capacity or declared exclusions.
19. Cancellation, failed delivery, claims and customer complaints produce traceable case records.
20. Referral revenue is not recognised from lead creation, quote submission, freight GMV or shipment booking alone.
21. Two-tenant RLS and private-storage access tests cover every partner RPC and signed URL.
22. All notification retries and outbox recovery are tested without exposing customer data to unapproved partners.

## 9. Safety, legal and migration constraints
- No outreach, call, email, WhatsApp message or contract has been sent or signed.
- Do not create partner organisations or mark existing organisations verified based on a public listing.
- Do not upload partner documents into the repository; use restricted private storage only.
- Keep the unresolved repository/production migration-history mismatch as a hard blocker for production DDL, grants, function edits or RLS changes.
- The platform's partner-direct referral model still needs Indian CA/legal review for GST, TDS, invoicing and intermediary treatment.

## 10. Decision and next action
**Current decision: NOT READY FOR LIVE ROUTE BOOKINGS.**

The first target corridor to validate is Ranchi–Jamshedpur road freight. The immediate commercial task is a discovery conversation with one prospective carrier, followed by evidence-backed onboarding and an independently reviewed service-area/capability activation. Do not build another public route promise before that partner evidence exists.

No production writes or operational actions were performed in this review.
