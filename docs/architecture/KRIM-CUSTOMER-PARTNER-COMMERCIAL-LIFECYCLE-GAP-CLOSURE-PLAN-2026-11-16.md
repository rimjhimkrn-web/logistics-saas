# KRIM Customer–Partner Commercial Lifecycle Gap-Closure Plan
**Date:** 16 November 2026  
**Purpose:** Convert the existing audit findings into a safe, dependency-ordered implementation plan for the nine KRIM workspaces and the non-custodial referral/coordination business model.

## Executive decision
**The platform has substantial workflow components, but it is not yet ready for real-world end-to-end shipment execution or repeatable revenue.** The immediate objective is not to activate every feature. It is to create one trustworthy, auditable customer-to-partner-to-service-to-KRIM-fee journey, while keeping unsupported markets, corridors, partners, capacity and finance actions blocked.

This plan is an implementation contract and sequencing document. It does not authorize production database changes, live shipment activity, partner/customer outreach, provider sends, payment collection, or legal/compliance claims.

## A. Hard release gates
1. **Migration-history reconciliation first.** Production reports 558 migration versions; the repository has 363 SQL migration files / 348 unique timestamps, only 82 exact version+name matches, 75 repository migrations absent from production history and 270 production migration names absent from the repository. Resolve the sanitized production schema manifest and produce an approved version/name/content crosswalk before any DDL, grants, policies, triggers, function replacement, migration baseline, replay or squash.
2. **Market and corridor eligibility fail closed.** No market is operationally activated; country operating packs remain research-pending; there are no approved corridor dossiers or corridor controls. Route shape or a “ready” display must never substitute for market activation, current regulatory evidence, customs clearance and corridor approval.
3. **No unverified partner/capacity.** Current active verified partner capabilities and assignments are effectively absent; no confirmed capacity resources/reservations or dispatches exist. Do not imply serviceability or accept a shipment until exact capability, compliance, corridor, capacity and partner acceptance are proven.
4. **Non-custodial finance only.** Customer contracts with and pays the logistics partner directly. KRIM invoices and collects only its separate agreed referral/coordination fee for documented work. Do not enable freight collection, escrow, payment splits, partner payables, payouts or freight-value commission.
5. **No simulated proof.** No fake metrics, test bookings, invented routes/ETAs, assumed partner approvals, “delivered” status from provider acceptance, or revenue labels without evidence.

## B. Target customer-to-revenue lifecycle
Every stage has a separate status and evidence requirement; no stage should be inferred from a prior stage.

| Stage | Required event / evidence | Must not be confused with |
|---|---|---|
| 1. Enquiry received | Unique inquiry ID, timestamp, source/UTM/referrer, privacy notice version, purpose and contact channel | Customer account, quote or booking |
| 2. CRM profile created | One canonical profile linked to the enquiry; individual vs registered business distinguished | Verified identity or active customer |
| 3. Qualification opened | Exactly one canonical qualification case per inquiry/service request | Qualified demand |
| 4. Requirements complete | Origin/destination, mode, cargo/service, weight/volume, dates, frequency, special handling and documents as applicable | Serviceability |
| 5. Market/corridor screened | Active market, approved corridor dossier, current source-backed controls and customs requirements | Route geometry |
| 6. Partner candidates eligible | Active registered partner, verified identity, current compliance review, exact capability and service area | Partner opportunity or directory listing |
| 7. Capacity confirmed | Partner-owned resource, time window, compatible capacity and accepted reservation | Capability alone |
| 8. Partner quote received | Exact partner/leg/currency/terms, expiry and evidence; no self-bid | Indicative platform estimate |
| 9. Customer acceptance | Customer acceptance bound to exact partner quote, provider identity, scope, terms and validity | Quote viewed or admin status |
| 10. Commercial contract | Customer–partner contract and separately signed KRIM referral/coordination agreement, where applicable | A platform-generated status |
| 11. Physical execution | Accepted assignment, handover, dispatch authorization, actual departure, leg events, custody and evidence | Planned route or dispatch authorization |
| 12. Service completion | Independently reviewed, leg-specific POD and all legs complete | POD submitted or unverified tracking |
| 13. KRIM fee earned | Referral attribution + agreement + evidence KRIM performed the agreed service + fee terms | Freight value or partner freight receipt |
| 14. KRIM fee invoiced | Correct legal entity/tax review, invoice and due date | Draft worksheet |
| 15. KRIM fee collected | Reconciled payment receipt in KRIM account and ledger | Invoice issued or provider API accepted |

## C. Workspace-by-workspace target contract

### 1. Customer / Shipper
- Enquiry and signup must distinguish privacy-notice acknowledgement, transactional contact permission, marketing consent, identity verification and organization activation.
- Do not provision a fully active customer organization or booking permission merely because an email callback completed.
- Customer sees only their own organization’s requests, exact partner offers and evidence-backed shipment events.
- Quote acceptance binds to one exact partner quote and a frozen terms snapshot.
- Cancellation after physical dispatch must use disruption/return/claims processes, not generic cancellation.

**Acceptance tests:** unauthenticated intake rate limits; duplicate retry; individual and business profile; email verification; MFA gates for sensitive actions; cross-tenant denial; quote expiry; exact quote binding; post-dispatch cancellation denial.

### 2. Partner / Carrier
- Onboarding application is not approval, capability is not bookability, and a quote is not an assignment.
- Require registered-business mode, verified identity, active lifecycle, current compliance review and individually reviewed evidence-backed capabilities.
- Partner quote submission and driver listing must call the same current-compliance predicate used by award/assignment.
- One exact active partner organization context; block ambiguous multi-org selection.
- Customer pays partner directly; remove freight settlement/payout UI from the lean-launch journey.

**Acceptance tests:** expired/revoked compliance denied at quote submission, candidate listing, assignment and dispatch; capability evidence metadata present; no cross-org data leakage; no quote without exact leg; no payout controls exposed.

### 3. Driver
- Driver identity, active partner membership, accepted assignment, licence validity, vehicle and required documents must be verified before assignment.
- Licence expiry must be blocked at driver assignment, not only later at dispatch authorization.
- GPS remains disabled until lawful purpose, notice, explicit consent, OS permission and active assignment are established.
- Manual milestones, carrier-reported events and consented telemetry must have distinct provenance.

**Acceptance tests:** expired licence; wrong partner; unaccepted assignment; duplicate driver assignment; revoked vehicle documents; no GPS consent; manual coordinate provenance; offline/retry behavior.

### 4. Warehouse
- Facility, staff authority, inventory, receipt, inspection, second-reviewer approval, allocation and custody transfer form one evidence chain.
- Creator cannot approve their own QC; inventory quality states cannot be merged; direct authenticated inventory writes remain blocked.
- Dispatch handover requires completed task, picked allocation, evidence and authorized reviewer.

**Acceptance tests:** creator self-approval denied; second reviewer required; wrong quality state cannot merge; duplicate receipt idempotency; unauthorized inventory mutation denied; dispatch handover evidence ownership and size/MIME validation.

### 5. Customs
- No shipment can be represented as customs-cleared without jurisdiction-specific rules, current evidence, qualified broker and case-level clearance.
- Country operating packs and customs requirements remain research-pending until reviewed; do not infer global customs capability.
- Broker licence, authority, validity, shipment scope and submitted declarations must be auditable.

**Acceptance tests:** missing jurisdiction rule blocks; expired broker licence blocks; incomplete documents block; reviewer independence; clearance evidence and timestamp; cross-border leg handoff.

### 6. Finance
- Separate customer–partner freight accounting from KRIM referral-fee accounting.
- Only record KRIM fee after agreement, attribution, service evidence, invoice and actual collection.
- Restrict financial posting/recovery rows from ordinary organization-member direct mutation after migration reconciliation.
- Keep Razorpay only for an explicitly supported KRIM fee payment use case; no freight split/payout/settlement.

**Acceptance tests:** freight GMV excluded from KRIM revenue; no partner payout path; duplicate fee receipt idempotency; invoice/payment mismatch; refund/chargeback reconciliation; requester/reviewer separation; AAL2; immutable audit trail.

### 7. Operations Control Tower
- Build one actionable queue: shipment/leg, verified issue, priority, accountable owner, SLA due time, latest evidence/source timestamp, next permitted action and customer communication state.
- Snapshot freshness must be visible; stale snapshots suppress health/SLA conclusions.
- Exceptions must link to source event, owner, dedupe key, escalation policy, timer, action, notification attempt and resolution evidence.
- Dispatch readiness, dispatch authorization and physical departure are separate states.
- Rerouting remains a proposal until corridor, compliance, customs, partner, capacity, customer approval and cost are confirmed.

**Acceptance tests:** stale snapshot warning; alert dedupe; owner and SLA; escalation retry/dead-letter; permission-specific actions; dispatch readiness cannot mark departure; post-dispatch cancellation path blocked.

### 8. Enterprise
- Enterprise workspace entry requires active membership and a named permission, not membership alone.
- Enforce organization isolation on analytics, API credentials, user invitations, shipment access and exports.
- Customer volume, pricing and SLA claims must be based on contracted, verified data.

**Acceptance tests:** least-privilege role matrix; tenant boundary; invitation expiry; credential rotation; export audit; no global data from aggregate endpoint.

### 9. Admin / Platform Control
- Platform-admin routes require AAL2, active platform role, explicit action permission and immutable audit record.
- Keep lead PII in a restricted control-plane API; do not broaden RLS for NULL-organization acquisition profiles.
- Deployment source must match checked-in version. Fix live `global-admin-control` drift where the deployed function still accepts the obsolete `converted` follow-up outcome, and reconcile the database constraint only after migration recovery.
- Separate review, approval, finance execution and self-approval.

**Acceptance tests:** AAL1 denied; revoked admin denied; direct API cannot set ambiguous conversion status; UI and deployed function versions agree; every privileged change records actor, reason and request ID.

## D. Cross-cutting P0 work in dependency order
| Order | Work package | Why it precedes others | Exit evidence |
|---:|---|---|---|
| 0 | Production schema/migration reconciliation | Safe foundation for all DB changes | Complete crosswalk, sanitized manifest, duplicate-name/timestamp resolution and reviewed deployment baseline |
| 1 | Auth/RLS/role and admin API consistency | Prevents cross-tenant exposure and unauthorized actions | Role matrix, policies, RPC grants, AAL2 checks and negative tests |
| 2 | Canonical enquiry/profile/qualification/linkage | No duplicate or orphan CRM cases | One profile and one canonical qualification case; durable linkage retry |
| 3 | Consent, purpose and contact preferences | Legal and privacy basis for communication | Versioned evidence, withdrawal, suppression, channel preferences |
| 4 | Market/corridor/customs fail-closed gate | Prevents unsupported route promises | Current approved packs, dossiers, controls, jurisdiction rules and independent approval |
| 5 | Partner verification/capability/compliance | Prevents unsupported supply claims | Evidence-backed current approvals and exact service scope |
| 6 | Quote/assignment/capacity binding | Creates a real customer offer | Exact partner quote, accepted terms, accepted assignment and confirmed capacity |
| 7 | Warehouse/driver/dispatch/custody/POD | Physical service execution | Evidence-backed chain from handover to independently verified delivery |
| 8 | Exception, tracking and notification assurance | Supports safe operation and customer trust | Freshness, owner, provenance, retry, verified callback and audit history |
| 9 | Non-custodial referral agreement and fee lifecycle | Produces actual KRIM revenue | Agreement, attribution, service evidence, invoice and collected fee |
| 10 | End-to-end staging and controlled pilot | Proves all links before scale | Full negative/positive test suite, operational sign-off and one explicitly authorized pilot |

## E. Global invariants (must hold in every workspace)
1. No serviceable route unless exact market, corridor, customs, partner, capability and capacity gates pass at the time of decision.
2. No customer quote acceptance unless the exact partner quote, provider and terms are bound.
3. No physical dispatch unless accepted assignment, confirmed physical capacity, required driver/vehicle documents, handover and corridor gates pass.
4. No delivered status without independent POD review for every required leg.
5. No generic cancellation after physical dispatch.
6. No notification marked delivered based only on provider API acceptance.
7. No prospect, enquiry, opportunity, quote or booking counted as a converted customer.
8. No freight GMV, freight payment or partner payable counted as KRIM revenue.
9. No sensitive data access based on authentication alone; every action requires tenant scope and named permission.
10. Every operational state change is idempotent, attributable, timestamped, evidence-backed and recoverable.

## F. What is deliberately not being activated
Until the relevant licences, providers, legal review and operational evidence exist:
- Freight custody, escrow, settlement, split payments and partner payouts.
- Credit, lending, insurance distribution, remittance or regulated finance.
- Global customs clearance or guaranteed cross-border coverage.
- Live GPS tracking without consent and lawful purpose.
- Automated ETAs, AIS claims or rerouting savings without verified data providers.
- Customer marketing campaigns without separate consent and suppression controls.

## G. Pilot launch definition
The first pilot should be a single, narrowly scoped domestic route/service with:
- One active and independently verified partner organization.
- One approved capability and operating area.
- Current compliance and all required licences/documents.
- Confirmed physical capacity for the requested window.
- Customer and partner contract responsibilities documented.
- KRIM referral/coordination agreement and fee terms documented.
- One real shipment completed with custody and independently verified POD.
- Customer pays partner directly; KRIM separately invoices and collects its fee.
- Incident, exception, notification and refund responsibilities agreed.
- No public promise of wider route coverage.

A pilot is not approved by this plan; it requires the relevant evidence and explicit operational authorization.

## H. Current blocker summary
- Production migration crosswalk is unresolved.
- Markets remain operationally blocked.
- Country operating packs and corridor controls remain pending.
- No approved corridor dossiers.
- No active verified partner capability suitable to prove a live customer route.
- No confirmed capacity, assignments, dispatches or verified PODs.
- No CRM enquiry/conversion/referral fee history.
- General customer notification delivery is unverified.
- Live admin Edge Function and repository source drift on the obsolete `converted` follow-up outcome.

## Recommended next implementation slice
After migration reconciliation, start with **one CRM integrity slice**: eliminate duplicate qualification creation, add durable enquiry-to-request linkage/retry state, align the live admin API and follow-up database status vocabulary, and verify AAL2-only lead visibility. Do not widen scope to live route execution until this slice passes staging tests.
