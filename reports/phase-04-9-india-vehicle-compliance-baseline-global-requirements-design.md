# KRIM Phase 04.9 — India Road Goods-Carriage Compliance Baseline and Global Requirements Design

Date: 2026-11-26
Branch: remediation/phase-03dw-isolation-2026-11-26
Scope: Read-only review of vehicle category/document UI, canonical requirement schema and verification/dispatch logic; review of official India and Jharkhand transport references; design only. No requirements, records, permissions or database objects were changed.

## Decision

**India goods-carriage baseline is suitable as a draft requirements specification, not as a live compliance profile.** No production or staging profile exists. Vehicle verification must remain blocked until an approved, versioned country/category/route profile is reviewed by a qualified transport-compliance adviser and loaded through a controlled migration/admin process.

The existing KRIM vehicle workflow is a configurable document checklist. It is not a live VAHAN/PUCC/permit validation service, legal determination engine, insurer verification system, physical inspection service or roadworthiness certification service.

## 1. Existing KRIM source findings

### Partner vehicle registration
Source: `app/partner/vehicle-registry.html`.
- UI explicitly asks for registration country, registration region, registration number, vehicle category/type, payload and ownership.
- India road freight is instructed to use category code `goods_carriage`; truck/tipper/dumper/mini-truck is captured separately as vehicle type.
- Document types offered: `registration_certificate`, `insurance`, `fitness_roadworthiness`, `operating_permit`, `tax_token`, `emissions_certificate`, `ownership_proof`, `other`.
- The UI warns that registration is not verification and that dispatch eligibility must remain blocked pending independent evidence review.
- The page uploads evidence to private Storage and submits metadata to the vehicle-document registration RPC.

### Admin vehicle verification
Source: `app/admin/vehicle-verification.html`.
- The console itself describes a draft India road goods-carriage baseline: registration certificate, valid insurance, applicable goods-carriage permit, transport-vehicle fitness, valid PUC/emissions certificate and vehicle tax certificate/token.
- It explicitly says permit and tax evidence must match operating route and jurisdiction.
- It instructs admins not to approve hazardous/dangerous-goods vehicles under the ordinary goods-carriage baseline until a separate profile is configured.
- The UI provides a manual country/category/document-type/mandatory-or-optional form. This is powerful but not a governed legal rules catalogue.

### Current database design limitations
The current `krim_vehicle_document_requirements` table is a minimal mapping:
- registration country ISO-2;
- free-text vehicle category;
- free-text document type;
- required boolean;
- creator/audit timestamps.

It does not model:
- state/province and registration authority;
- operating jurisdiction(s), origin/destination or route corridor;
- permit scope, permit class, validity territory or route restrictions;
- vehicle class/GVW/axle/fuel/emission class/use type;
- document issuer/authority, verification reference or live status source;
- effective-from/effective-until and rule version;
- applicability conditions, exemptions and reason codes;
- evidence freshness/revalidation frequency;
- whether the evidence is required for vehicle registration, commercial operation, a specific route, a shipment or a hazardous cargo class.

The verification finalizer requires at least one mandatory rule and an approved/current document of each required type. It does not establish that the document number is valid with its issuer, that a permit covers the specific route, that tax is paid in the relevant jurisdiction, or that the insurer confirms coverage. An absent expiry date is treated as current by the reviewed vehicle checks. These are important limitations, not proof of a vulnerability by themselves.

## 2. India/Jharkhand official-source findings

The following are primary government or statutory references reviewed on 2026-11-26:

1. **Motor Vehicles Act, 1988, section 56:** a transport vehicle is not deemed validly registered for section 39 purposes unless it carries a valid certificate of fitness issued by the prescribed authority or authorised testing station. citeturn162628search12
2. **Jharkhand Transport Department — Vehicle Fitness:** the state department describes fitness as mandatory for transport vehicles and lists registration, insurance, fitness renewal, tax/challan clearance and permit-related evidence in its procedures. Its page also describes commercial-vehicle fitness renewal and inspection criteria. Treat its published page as an operational reference that must be checked for current amendments and vehicle class applicability. citeturn162628search0
3. **Jharkhand Transport Department — Goods-carriage permits:** the state publishes different temporary and permanent goods-carriage permit types and regional/All-Jharkhand scopes, demonstrating that a generic “permit uploaded” flag cannot prove route authorization. Fees and durations are state-published and may change; KRIM should not hard-code them as legal rules. citeturn231040search0
4. **Jharkhand Transport Department — vehicle registration:** the state page lists insurance, PUC, tax/clearance and fitness-related material in specified registration/re-registration processes. The exact checklist varies by transaction and vehicle class; it should not be blindly reused as a universal fleet onboarding list. citeturn162628search1
5. **MoRTH / Central Motor Vehicles Rules, 1989:** the official rules include vehicle-specific documents and local State rules/restrictions; hazardous/dangerous goods are subject to distinct rules, including driver/document and vehicle marking requirements. The exact applicable provisions and current amendments must be checked for each hazardous-goods class. citeturn162628search14turn162628search15
6. **MoRTH guidance on electronic documents:** Rule 139 amendment guidance recognizes production of registration, insurance, fitness, permit, driving licence and pollution-under-check documents in physical or electronic form. KRIM may store digital evidence, but should preserve source authenticity and verification status rather than treating an uploaded image as government-verified. citeturn231040search15turn231040search16
7. **Jharkhand Transport Department official services and notices:** the department links VAHAN, permits, tax, PUCC, fitness and state-specific notices. A production implementation should verify against the live relevant service/notification rather than static fee or FAQ text. citeturn231040search2

### Draft baseline for India ordinary road goods carriage

The following is a **proposed evidence checklist for professional review**, not a legal opinion or final statement that every item is universally mandatory for every vehicle/route:

| Evidence type | Proposed KRIM treatment | Important scope/validation |
|---|---|---|
| Registration certificate (RC) | Mandatory | Match registration number, registered owner/lessee, class, GVW, fuel, chassis/vehicle identity and issuing authority. Verify against VAHAN/authoritative source where possible. |
| Insurance | Mandatory | Capture policy number, insurer, insured name, vehicle/registration match, start/end dates, policy type and exclusions. Do not equate upload approval with coverage for cargo, route or shipment. |
| Fitness certificate | Mandatory for transport vehicle where applicable | Match vehicle class, certificate/fitness validity and authority; re-check before dispatch and after expiry. |
| Goods-carriage operating permit | Conditional mandatory | Determine permit class, territory, route/region, validity, vehicle association, national permit/authorization where relevant and corridor restrictions. |
| Vehicle tax / tax token / tax-paid status | Conditional mandatory | State/jurisdiction and tax period specific; validate current paid-through status, not merely presence of a token image. |
| PUC / emissions certificate | Mandatory where applicable | Verify certificate number, vehicle match, test date, validity and issuing authorized PUC centre. |
| Ownership / lease / contracted-use evidence | Conditional | Require only when RC owner differs from partner or vehicle use is leased/contracted; prove lawful control and authorization for the commercial use. |
| Vehicle identity / inspection evidence | Risk-based / separate control | RC/chassis/engine identity cross-check; physical inspection is separate from document review. |
| Driver-specific licence and hazardous-goods endorsements | Separate driver profile | Do not mix driver evidence into vehicle profile; validate class, transport authorization, validity and hazardous-goods training/authorization where applicable. |

**Not yet approved:** the precise mandatory/conditional status and accepted evidence for every Indian vehicle class, state, route, permit regime and use case. The India baseline must be signed off by a qualified transport compliance adviser before it is encoded.

## 3. Hazardous/dangerous goods — separate control domain

Do not use `goods_carriage` as a catch-all for hazardous cargo.
- Create distinct vehicle/service eligibility categories and cargo hazard classifications.
- Determine applicability under current CMVR provisions (including Rules 132–133 and Rule 137, as relevant), driver training/authorization, prescribed documentation, emergency information panels, placards/class labels, equipment and carrier capability.
- A vehicle being registered and generally fit does not prove that it is approved or equipped for a specific dangerous-goods class.
- Unknown or unsupported hazard class must block booking/assignment/dispatch pending qualified review.
- No hazardous-goods vehicle should be activated using the ordinary India goods-carriage checklist.

## 4. Recommended global requirements architecture

Do not expand the current free-text requirements table into a large static list of country codes. Design a governed, versioned rules model with at least these concepts:

1. **Jurisdiction:** country, state/province, region, registration authority and operating territory.
2. **Vehicle class:** canonical category, subtype, GVW band, axle/configuration, fuel/energy, ownership/use type and any regulated special class.
3. **Operation scope:** domestic/interstate/international, route/corridor, permit territory, transport mode and shipment/cargo hazard class.
4. **Requirement definition:** canonical evidence code, display label, legal reference, authority, required/conditional/optional/prohibited status, applicability predicate and exemption reason.
5. **Rule version:** effective-from/to, published date, source URL/reference, reviewer, approval state, supersedes version and immutable audit history.
6. **Evidence instance:** issuer, document number, registration/vehicle identity match, issue/expiry dates, territory, class/scope, verification method/result, reviewer, source hash and revalidation status.
7. **Operational eligibility:** separate decisions for `vehicle_verified`, `vehicle_legal_for_route`, `vehicle_covered_for_shipment`, `vehicle_safe_for_trip` and `dispatch_authorized`. One green “verified” state must not imply all five.
8. **Revalidation:** expiry, revocation, replacement, vehicle alteration, route change, carrier status change, policy cancellation, permit territory change and regulatory rule update must invalidate relevant eligibility and trigger re-check.
9. **Fail-closed behavior:** unknown country/category/route, no active rule version, missing mandatory rule, conflicting evidence or unavailable verification source => blocked or manual review, never silently clear.
10. **Separation of duties:** partner submits; reviewer independently validates; a different authorized compliance approver activates the rule version. No self-approval or unilateral weakening of a mandatory rule.
11. **Auditability:** immutable rule version, source citation, decision rationale, evidence hash, actor, timestamp and previous/new state.
12. **Data minimization:** store only necessary identifiers and proof; tightly scope access to sensitive documents; avoid collecting unrelated personal data.

The existing document requirements table may remain as a compatibility layer during transition, but should not be the sole legal/operational source of truth.

## 5. Critical control gaps to carry forward

- Zero configured requirement rows in Production and Staging (Phase 04.8 evidence).
- No official authority/VAHAN/PUCC/insurer verification integration established by this audit.
- No route-aware permit authorization in the simple document checklist.
- No robust evidence issuer/identity/vehicle-attribute matching model established.
- No expiry requirement for every evidence type; missing expiry can be treated as non-expiring in the current check.
- No signed-off category-specific hazardous-goods baseline.
- Earlier Phase 00 Gate C3.16 found no canonical vehicle-specific pre-trip roadworthiness inspection and defect stop-work gate; no claim of physical roadworthiness inspection is permitted.
- Earlier Phase 00 Gate C3.16 found insurance evidence is not policy verification or per-shipment coverage authorization.
- Staging still has the Phase 04.8 storage, function ACL and expiry scheduler drift; these remain separate prerequisites.
- The current Admin UI can set a rule optional. Any production rule changes require dual review and a controlled change process; an operator must not make a rule optional to unblock an asset.

## 6. Remediation sequence — design only

### Gate A: legal/compliance approval
- Obtain written review of ordinary goods-carriage evidence requirements for Jharkhand registration and the intended operating corridors.
- Define separate profiles for light/medium/heavy goods carriage, multi-axle/trailer and any other intended vehicle classes only after legal/operational validation.
- Define interstate/national permit scope and applicable state tax/PUC/fitness rules.
- Exclude hazardous/dangerous goods from initial activation.

### Gate B: schema and workflow design
- Design versioned jurisdiction/category/route requirement tables and evidence verification metadata.
- Define conditional requirements and documented exemptions; no silent optionalization.
- Add review/approval workflow for rules, effective dates and supersession.
- Design route-specific legal eligibility and separate insurance coverage verification.

### Gate C: technical control implementation
- Add authoritative verification adapters only where official APIs/permissions exist; otherwise use documented manual verification with source, reviewer and timestamp.
- Enforce expiry/revocation/revalidation on vehicle binding, assignment acceptance, dispatch, pickup and each trip event.
- Add pre-trip inspection/defect stop-work and maintenance release controls in their own source-of-truth workflow.
- Reconcile Staging Storage, ACL and expiry scheduler drift before synthetic testing.

### Gate D: Staging proof
- Load only the approved India baseline in isolated Staging.
- Use synthetic evidence with test-only issuers and clearly marked test documents.
- Prove valid/invalid/expired/mismatched/route-out-of-scope cases and negative cross-tenant access.
- Verify vehicle eligibility turns off after expiry, revocation, route change and partner compliance change.
- No real vehicle, real dispatch, real cargo or real partner onboarding in this phase.

## Status register

| Item | Status |
|---|---|
| Existing India category code and document types | VERIFIED in source |
| Existing admin UI draft India baseline | VERIFIED in source |
| India/Jharkhand official reference review | COMPLETED as desk research; not legal sign-off |
| Live India requirement profiles | FAIL — zero rules in Production and Staging |
| Country/category/route-aware global rules schema | DESIGN REQUIRED |
| Official live RC/PUC/permit/insurance validation | NOT IMPLEMENTED / NOT VERIFIED |
| Hazardous-goods profile | BLOCKED |
| Vehicle roadworthiness inspection and defect stop-work | BLOCKED — separate Phase 00 finding |
| Per-shipment insurance coverage validation | BLOCKED — separate Phase 00 finding |
| Real vehicle onboarding | BLOCKED |
| Synthetic vehicle testing | BLOCKED pending Staging reconciliation and approved rules |

No database, Storage, account, vehicle, requirement, permission or deployment state was modified.
