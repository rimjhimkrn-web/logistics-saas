# KRIM Global Partner Network, Marketplace Discovery, Capability Matching and Customer Trust Audit
**Date:** 16 November 2026  
**Scope:** Read-only production review of partner organizations, discovery profiles, capabilities, service areas, verification, opportunities, partner quotes, matching, capacity, market/corridor activation and quote customer UI. No provider was contacted, no customer/partner notification was sent, no quote/opportunity/assignment/capacity was created, and no production data or schema was changed.

## Executive decision
**NO-GO for a live searchable global provider marketplace or broad route-level booking.** KRIM has strong foundations for verified partner admission, evidence-backed capability review, tenant-scoped opportunity access, partner quote submission and customer quote comparison. The customer quote path deliberately avoids invented prices and checks current partner eligibility. However, the live network is not operational: there are no discovery profiles, no approved capabilities, no service areas, no capacity, no partner-submitted quotes, no match results, no accepted quotes or assignments. All seven corridor candidates are draft; market catalogue rows are active metadata, not proof of operational market activation. The public “partner directory” route is retired and redirects to a partner recruitment page, not a customer-facing directory.

## 1. Live production evidence baseline
Read-only counts:

| Data | Rows |
|---|---:|
| Legacy partner records | 10 |
| KRIM organizations | 14 |
| Partner discovery profiles | 0 |
| Partner capabilities | 1 |
| Approved/active capabilities | 0 (the single record is inactive and pending) |
| Partner service areas | 0 |
| Partner verification cases | 1 |
| Partner compliance evidence | 0 |
| Partner opportunities | 3 |
| Open opportunities | 0 (two cancelled, one expired) |
| Partner-submitted quotes | 0 |
| Partner match runs / results | 0 / 0 |
| Capacity availability / shipment commitments | 0 / 0 |
| Customer quote records (`krim_quotes`) | 7 |
| Quote acceptances | 0 |
| Partner assignments | 0 |
| Markets | 6 |
| Market activation control rows | 6 |
| Network corridors | 7 |
| Corridor compliance dossiers | 0 |

The only capability row is for organization 2, a legacy test transport partner: Road/transport, India coverage, inactive, pending review. The 14 organizations include test and journey-verification organizations; none of the returned partner organizations is currently verified, compliant and activated for registered-business commercial execution. The live data therefore does not establish a usable provider network.

The six market catalogue rows (India, UAE, Germany, UK, Singapore and USA) are marked active at the catalogue level. Prior market readiness audit established all country operating packs remain research_pending, readiness assessments are pending, no requirement source is approved and no market/corridor is approved for operations. All seven corridor candidates currently have status draft, including domestic Ranchi–Kolkata and Ranchi–Jamshedpur candidates and international Ranchi–London, Singapore, Dubai, New York and Frankfurt candidates.

## 2. Customer-facing discovery and directory
### Finding MKT-01 — P1: no customer-facing live partner directory
The legacy `public/partner/partner-directory.html` redirects to `public/growth/partner-network.html`. That destination is an indexed partner recruitment/application page, not a searchable customer directory. The public page correctly describes a developing network and explicitly says application does not imply verification, coverage, demand or activation. This avoids publishing unverified provider claims, but customers currently cannot browse or compare a verified provider catalogue by region, mode, service, capacity or evidence status.

The dedicated `krim_partner_discovery_profiles` table is empty and has no customer-public read policy. Its authenticated policy is organization/platform-admin scoped. No customer discovery/search RPC was found among the reviewed public partner-match/discovery functions; the partner matching engine is internal/private and not an exposed customer directory endpoint.

**Recommendation:** keep provider profiles private until review and market activation are complete. Later build a customer-facing directory from a deliberately minimized, approved public projection, never from raw partner organization, compliance evidence or onboarding tables. Show only verified identity labels, approved service scope, current coverage, last-reviewed date and availability state, with clear “indicative only” language.

## 3. Partner admission and verification
### Positive controls
- Partner network recruitment copy distinguishes application, verification and activation.
- The partner workspace separates development/test, individual-interest and registered-business pathways and warns that registration alone does not grant commercial access.
- Capability submission is through a SECURITY DEFINER RPC requiring an active registered-business organization, partner.manage permission, current organization compliance, active transport mode, active country and 1–5 evidence files in the submitting user's own organization folder.
- Capability approval requires AAL2, platform-admin permission, an independent reviewer (submitter cannot approve), evidence ownership/existence, active country/mode and current verified/compliant organization state.
- Service-area approval similarly requires AAL2, independent reviewer, active verified compliant registered business, approved country operating pack, consistent active market/location/mode, 1–5 owned private evidence files and a matching active verified capability.
- Partner opportunity RLS only exposes an open opportunity to an eligible registered-business partner when verification/lifecycle/compliance and the shipment capability-coverage helper pass.

### Finding MKT-02 — P1: zero evidence of an approved partner supply base
No discovery profile, service area, compliance evidence, verified capability, capacity or accepted assignment exists. One pending capability is inactive and belongs to a test organization. The existence of verification and approval functions is not evidence that a real partner has passed them. No public copy or customer screen should imply live coverage, verified carrier density or guaranteed service availability.

### Finding MKT-03 — P1: organization-level verification is not enough to advertise every service
The platform correctly distinguishes organization verification from capability approval. Continue to keep each transport mode, service type, country, region, special handling claim and effective date independently reviewable. A verified legal entity must not be presented as approved for refrigerated, hazardous, customs, warehousing or cross-border work unless the relevant capability and regulatory evidence are separately approved and current.

## 4. Capability and service-area matching
The private helper `private.krim_partner_capability_covers_shipment` checks:
- active origin/destination locations and countries;
- requested active transport mode;
- a current active verified partner capability for the shipment mode and weight at both origin and destination countries;
- optional coverage-region compatibility against the country/state/region label.

The exact-leg quote function uses a leg-specific capability helper and rejects non-empty special cargo requirements until a reviewed canonical evaluator exists. The service-area approval function additionally requires an approved country operating pack and a matching verified capability.

### Finding MKT-04 — P1: shipment-wide capability matching does not explicitly require an approved service-area row
The shipment-wide capability helper checks country/region capability records but does not join to an approved `krim_partner_service_areas` record. The service-area table is a separate governed workflow with its own approval gate. Clarify whether service-area approval is a mandatory commercial gate or whether capability approval is intentionally the authoritative coverage approval. If both are required, the quote, match and award functions must enforce both. Avoid two conflicting sources of truth for the same coverage claim.

### Finding MKT-05 — P1: corridor and country operating readiness remain a separate hard dependency
The capability helper does not prove a corridor dossier, market operating pack, customs route, carrier interchange, local licence or cross-border legal clearance. Service-area approval checks country operating pack status, but the live country packs are research_pending and corridor dossiers are empty. An active market catalogue flag is not an operating approval. Do not allow the marketplace to represent a route as serviceable merely because a partner has a country-level capability row.

## 5. Partner matching and customer quote visibility
### Positive controls
- Matching run/result tables are read-only to the customer organization that owns the shipment (or platform admin); there are no customer direct-write policies.
- Partner opportunity read policy checks eligible organization type, registered-business mode, verification, lifecycle, compliance evidence currentness and capability coverage before showing open opportunities to a partner.
- Customer quote listing is a SECURITY DEFINER RPC that requires authentication, validates every requested shipment is accessible to the user, joins quotes to the exact opportunity/shipment/customer organization, and computes separate booleans for partner verification, current compliance, capability and `eligible_now`.
- The customer comparison page loads the selected shipment only within the active customer/shipper/enterprise organization and calls the server quote-list RPC. It renders only partner-submitted offers that the backend marks eligible now, with valid status and expiry. It has a separately labelled illustrative preview mode with disabled actions.
- Awarding an offer is not treated as provider acceptance or dispatch. Provider acceptance and customer quote acceptance are distinct steps; the customer screen explains that KRIM does not collect freight payments and that the customer contracts/pays the provider directly.

### Finding MKT-06 — P1: legacy shipment-wide quote submission does not visibly re-check current compliance evidence
The reviewed `krim_submit_partner_quote` SECURITY DEFINER function checks partner organization status fields, registered-business mode, verified capability and route coverage, but the inspected function body does not call `private.krim_partner_compliance_is_current` before inserting/updating the partner quote. The partner opportunity RLS policy does call this helper, but a SECURITY DEFINER function does not rely on caller RLS as its authorization boundary. By contrast, the leg-specific quote submission path explicitly checks current compliance. The customer quote-list RPC later suppresses offers that fail current compliance, which is a useful defense, but the legacy quote submission path should still fail closed itself. Reconcile this function after migration history is reconciled; do not patch production directly.

### Finding MKT-07 — P1: matching engine has no live execution evidence
There are zero matching runs/results and no live eligible partners. Internal matching functions are not customer-facing search APIs. No production ranking quality, recall, explainability, conflict handling, route fit or match fairness has been validated. Any match score must remain advisory until validated against real, permissioned partner capability and route evidence.

### Finding MKT-08 — P2: comparison UX can only compare submitted offers, not independently validate the full service contract
The quote comparison screen shows price, currency, validity, status, partner legal name and notes. Before commercial rollout, comparison must also make the included/excluded scope visible: pickup/delivery endpoints, mode and transshipment, cargo limits/handling, customs responsibilities, insurance, transit-time estimate and assumptions, detention/storage, surcharges/taxes, cancellation/claims, service-level commitments, quote validity and contracting party. The UI's current route/capability checks do not themselves constitute a signed customer–partner service contract.

## 6. Quote and award lifecycle
- No partner-submitted quote or quote acceptance exists in production.
- Seven customer quote rows exist, but they do not represent seven live partner offers; `krim_partner_quotes` has zero rows.
- The three opportunities are all closed (two cancelled, one expired).
- There are no partner assignments, so award/provider acceptance/assignment is not operationally proven.
- Quote submission functions validate positive finite amount, currency, response deadline and capability; exact-leg quoting additionally validates active route-plan item, leg mode/endpoints and special cargo requirement handling.
- Quote acceptance/assignment, capacity reservation and dispatch remain separate. Do not equate a quote, customer award or assignment offer with provider acceptance, reserved capacity or confirmed departure.

## 7. Data access and marketplace privacy
- `krim_partner_capabilities`, `krim_partner_service_areas` and `krim_partner_capacity_availability` have authenticated organization-scoped SELECT policies; no direct authenticated write path was observed in the inspected policies.
- Partner discovery profiles are organization/platform-admin scoped.
- Partner quotes are readable by the submitting partner organization or customer organization on the linked opportunity; direct customer writes are not exposed.
- Opportunity read is narrowly scoped to customer, awarded partner, platform admin or an eligible partner for an open opportunity.
- Matching result/run rows are scoped to the owning customer shipment or platform admin.
- No anonymous directory read policy was found in the reviewed discovery/capability tables.

These are positive privacy boundaries. They also mean that a public partner directory needs an explicit safe projection and cannot simply query the internal partner tables.

## 8. Required staging-only acceptance tests
1. Development/test and individual-interest accounts cannot access commercial discovery, open opportunities, quote submission or customer marketplace listing.
2. Pending, rejected, suspended, expired, restricted or non-compliant partners are not returned as eligible and cannot submit quotes.
3. A verified organization with a pending/inactive/expired capability cannot bid for that mode/service.
4. A partner with origin coverage but no destination coverage cannot quote the full shipment.
5. A partner with capability coverage but no approved service area is rejected if service-area approval is designated mandatory.
6. A country with research_pending or expired operating pack cannot be represented as active coverage.
7. A corridor without approved dossier and controls cannot produce an executable cross-border offer.
8. Hazardous, refrigerated, oversized, controlled or otherwise special cargo is rejected unless the exact requirement has a reviewed capability evaluator.
9. Partner A cannot view Partner B's private onboarding documents, capacity, quote notes or internal match records.
10. Customer A cannot list or compare quotes for Customer B's shipment; guessed shipment IDs must fail closed.
11. Expired, withdrawn, rejected or ineligible quotes disappear from award actions immediately after revalidation.
12. A compliance/capability revocation between quote submission and award prevents award/acceptance.
13. Quote retries and concurrent partner submissions preserve one authoritative current quote/version and audit history.
14. Multi-leg shipment quote matching must be exact-leg, route-plan bound and not silently fall back to shipment-wide quoting.
15. Customer comparison must expose currency, quote scope, exclusions, assumptions and validity; no implicit FX conversion or service guarantee.
16. Award, partner acceptance, capacity reservation, customer acceptance and dispatch are independently tested and independently represented.
17. Verify safe public directory projection never exposes personal contact data, private evidence, compliance documents, exact capacity or non-public partner notes.

None of these staging tests was executed.

## 9. Remediation order
1. Resolve whether approved service-area rows are mandatory for matching and enforce one authoritative coverage model.
2. Add the missing current-compliance evidence check to the legacy shipment-wide quote submission function, after migration reconciliation.
3. Keep the customer-facing directory closed until verified partner profiles, service-area approvals, current capacity and market/corridor activation are real.
4. Build a safe customer search projection and explainable matching criteria, with strict tenant/role boundaries.
5. Add end-to-end quote scope/terms comparison and signed customer–partner contract evidence before broad commercial use.
6. Populate and verify real partner supply, capability, service area, operating market, route and capacity evidence before enabling marketplace claims.
7. Run all acceptance tests in isolated staging only; no production customer/partner business transactions for test purposes.

## 10. Change control and release decision
Read-only review only. No matching run, RPC business action, quote, award, assignment, capacity reservation, provider contact, customer communication or production mutation was executed. No schema or function was changed.

The migration-history mismatch and sanitized schema-manifest gate remain unresolved. No migration replay or corrective production DDL is authorized.

**Release status: NO-GO for a live public provider directory, global partner discovery, unrestricted marketplace quoting or route-level commercial booking.** The verified quote comparison design is promising, but the operating supply network, route readiness, coverage approvals, capacity and real partner offer evidence do not yet exist.
