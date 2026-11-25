# Phase 00 Gate C3.20 — Partner ecosystem onboarding, verification, commercial eligibility, coverage, contracts and lifecycle reliability

**Assessment date:** 2026-11-25  
**Source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**Method:** Read-only source and prior-audit evidence reconciliation. No live RPC, SQL mutation, upload, approval, invitation, notification, partner activation or deployment was performed in this gate.

## Executive decision

**PARTIAL PASS / BLOCKED — NO-GO for broad self-service commercial partner activation, partner bookability claims, paid referrals, route quoting or real shipment assignment.**

KRIM contains a substantial partner admission control design: distinct registered-business, individual-interest and development/test pathways; authenticated organization provisioning; private evidence storage; independent capability review; AAL2/platform-admin approval gates; service-area review; capacity-aware matching foundations; and contract-party read isolation. But this is not yet an end-to-end proven partner operating lifecycle. The reviewed production snapshot recorded one verification case, one pending/inactive capability, zero compliance evidence/reviews, zero approved service areas, zero capacity commitments, zero service contracts and zero SLA rows. Legacy active partner-directory rows do not establish verified partner organizations or current bookable capacity.

## Scope and evidence reviewed

- Partner signup, organization provisioning, account-mode selection and partner gateway.
- Registered-business onboarding, identity verification and compliance evidence/review.
- Capability submission and independent administrator approval.
- Service-area submission, country/market/location and operating-pack dependencies.
- Capacity and exact-leg partner matching foundations.
- Contract/SLA schema access and commercial lifecycle.
- Organization membership, invitation and authorization design as represented in prior audits.
- Partner-facing pages and administrator verification/compliance/capability/service-area review surfaces.
- Prior source audits listed under **Evidence references**.

This is a source-level audit and synthesis, not an independent rerun of every underlying migration or function. Runtime behavior, live browser journeys, database negative tests, and provider delivery remain NOT TESTED in this gate.

## Positive controls found

1. **Pathway separation:** Registered business is distinct from individual interest and development/test. Non-commercial pathways are designed to return `commercial_access=false`; they must not be treated as approved carriers.
2. **Organization provisioning:** The provisioning RPC requires authenticated identity, serializes per-user provisioning, avoids ambiguous multiple active partner organizations, creates owner membership/role assignments, a pending verification case and audit event.
3. **Identity review:** Business approval is separate from signup and requires AAL2/platform-admin authorization, registered-business mode, active eligible organization, identity details, private registration evidence and original-submitter storage ownership. Rejection requires a reason.
4. **Compliance review:** Evidence submission/review uses private storage, jurisdiction and baseline compliance categories; approval requires reviewer rationale, evidence provenance, validity dates and independent review controls in the reviewed pathway.
5. **Capability review:** Approval requires AAL2/platform-admin permission, reviewer independence, current verified/compliant registered-business status, active country/mode, private evidence owned by the submitter, approval rationale and effective scope. Hazardous-goods and refrigerated capabilities are held outside the standard approval path pending specialist controls.
6. **Service-area review:** Submission uses canonical country/market/location/mode catalogues, private evidence and server-side partner-manager/organization/compliance/scope checks. Administrator approval checks approved country operating pack, active catalogue rows, matching verified capability and independent review.
7. **Matching safeguards:** Partner matching is designed to fail closed without active verified capability and capacity; quote matching subtracts active reservations; route and shipment execution require additional exact-leg and lifecycle checks. A capability or city-level coverage entry is not blanket corridor authority.
8. **Sensitive commercial data:** Contract/SLA records have RLS and party-scoped read access in the reviewed audit; direct authenticated writes were absent. This is safer than exposing contract mutation directly to the browser.

## Findings and release blockers

### P1 — Onboarding-to-capability handoff is incomplete
Multi-category onboarding can create capability rows without the `submitted_by` and evidence metadata expected by the independent capability-review RPC. A partner may need a separate capability evidence submission step, and the applicant journey does not clearly explain this handoff. This can strand otherwise valid onboarding in pending state.

### P1 — Reviewer independence is inconsistent across high-impact approvals
Capability and service-area review enforce submitter/reviewer separation in the reviewed paths. Earlier review found identity-verification and compliance-review routines did not visibly apply the same separation consistently. Require reviewer != original submitter and evidence contributor, or a documented second-person exception, across identity, compliance and other material approvals.

### P1 — Terms acceptance is not a durable consent/contract ledger
Signup stores terms acceptance/version in editable user metadata. That is not authoritative contractual evidence. A server-controlled, immutable, versioned record is needed for terms/privacy version and hash, purpose, actor, timestamp, acceptance event and later change/withdrawal. Marketing consent must remain separate from contractual acceptance.

### P1 — Initial evidence submission ownership check is weaker than final review
The onboarding submission RPC checks organization/user path structure and object existence, while later approval checks Storage owner metadata. Submission should reject wrong-owner/cross-tenant objects immediately; test path spoofing, MIME/size mismatch, object replacement and tenant substitution.

### P1 — Capability approval metadata handoff and evidence recovery
The onboarding-created capability metadata gap must be reconciled. Staging must also prove upload failure cleanup, ambiguous RPC timeout handling, duplicate prevention, signed preview expiry, wrong-tenant denial and evidence retention. A browser crash between upload and RPC still lacks a proven durable upload-session reconciliation flow.

### P0/P1 — Service-area approval contains a schema mismatch
The prior read-only audit found the live country operating-pack table exposes `pack_status`, while `krim_admin_review_partner_service_area` checks `cp.status`. The approval branch is therefore expected to fail with an undefined-column error. Do not hot-patch production; reconcile migrations/schema and fix through a reviewed migration followed by isolated staging verification.

### P1 — Service-area effective dates are not enforced at approval
The reviewed approval branch did not enforce `effective_from <= now()` and `effective_until IS NULL OR effective_until > now()`. An approved status must not be treated as current coverage unless the effective window is also valid at approval and every downstream matching/dispatch boundary.

### P1 — Geographic coverage is not corridor authorization
Country/city service areas do not prove a specific origin-destination corridor, route, schedule, cargo class, customs permission, capacity or service date. Country operating packs were reported as research-pending and corridors as draft in the earlier snapshot. Keep corridor eligibility fail-closed until all applicable market, corridor, partner, capability, compliance, customs and capacity controls are linked and approved.

### P1 — No executed commercial agreement evidence
The reviewed snapshot contained zero service contracts and zero SLA rows. The reviewed contract schema did not establish first-class signed-document object/version/hash, signatory authority, acceptance timestamps, counterparty acceptance and immutable amendment chain. Do not activate paid referrals, commission/coordination commitments or partner commercial obligations without a mutually executed agreement and evidence of both parties' acceptance.

### P1 — No proven end-to-end partner suspension, expiry and renewal barrier
Source controls exist for portions of verification, capability and compliance validity, but the full lifecycle across expiry, suspension, revocation, in-flight assignment protection, reactivation, renewal and notifications is not proven end to end. Every consequential quote/accept/assignment/dispatch boundary must revalidate current organization, compliance, capability, service area, capacity and agreement state.

### P1 — Multi-step registration recovery is not fully reconciled
Auth signup, organization provisioning and account-mode selection are separate network operations. A partial failure can leave an Auth identity without completed organization/pathway state. The user-facing retry guidance is helpful but does not prove an idempotent resume/reconciliation dashboard or safe duplicate prevention.

### P2 — Service quality, notifications and operational ownership
Partner lifecycle notifications, acknowledgement, retries, dead-letter handling, support ownership and escalation are not proven as a complete durable pipeline. Do not equate an in-app notification row or a displayed status with successful delivery or acknowledgement.

### P2 — Capacity and operational evidence are absent
A capacity-aware matching design is present, but no capacity commitments were present in the prior snapshot and concurrency/release behavior has not been runtime tested. A verified capability or service area alone is not a confirmed available service.

## Readiness disposition

| Area | Gate result | Evidence boundary |
|---|---|---|
| Pathway and organization provisioning design | PARTIAL PASS | Source-reviewed; recovery runtime NOT TESTED |
| Business identity verification | PARTIAL PASS / BLOCKED | Source controls; reviewer separation and official-source validation gaps |
| Compliance evidence and review | PARTIAL PASS / BLOCKED | Baseline checks exist; jurisdictional completeness and segregation gaps |
| Capability approval | PARTIAL PASS / BLOCKED | Independent approval design; onboarding metadata handoff gap |
| Service-area submission/review | FAIL / BLOCKED | Prior audit identifies approval schema mismatch and effective-date gap |
| Corridor and market eligibility | FAIL / BLOCKED | No approved corridor/operating pack evidence in prior snapshot |
| Capacity and bookability | NOT TESTED / BLOCKED | Zero commitments in prior snapshot; no concurrency runtime proof |
| Contract and SLA execution | FAIL / BLOCKED | Zero contract/SLA rows; no complete signed counterparty evidence |
| Suspension/expiry/renewal lifecycle | NOT TESTED / BLOCKED | No full end-to-end runtime proof |
| Notifications and escalation | NOT TESTED / BLOCKED | No complete durable partner lifecycle delivery proof |

## Required remediation order

1. Reconcile current migration history and canonical schema before changing any backend function.
2. Correct the service-area `pack_status` reference and add approval-time effective-window checks in a reviewed migration.
3. Repair onboarding-created capability metadata/evidence handoff; make the partner next-step state explicit.
4. Enforce independent reviewer separation for identity and compliance approvals.
5. Replace editable metadata-only terms acceptance with server-controlled versioned consent/contract evidence.
6. Enforce storage object ownership at submission, then stage-test MIME, size, object immutability/version, cross-tenant denial, signed URL expiry and recovery.
7. Implement explicit counterparty contract execution and signed-document evidence before paid commercial activation.
8. Reconcile suspension, expiry, revocation, renewal and in-flight work behavior; revalidate all gates at quote, acceptance, assignment and dispatch.
9. Prove service area + corridor + market + compliance + capability + capacity + contract eligibility as a single route-specific decision.
10. Run isolated staging tests with synthetic organizations/users only after staging isolation is demonstrated. Include negative cross-tenant, expired/future, wrong reviewer, wrong evidence owner, replay, timeout, concurrency, suspension-during-quote and suspension-during-active-work scenarios.

## Safety and execution boundary

No Production or Staging writes, SQL mutations, RPC invocations, partner approvals, document uploads/deletions, invitations, notifications, provider calls, shipment operations or deployments were performed for C3.20. No real partner was onboarded or activated. Findings are source/prior-audit evidence only and must not be represented as fresh runtime verification.

## Evidence references

- `docs/audits/KRIM-PARTNER-ONBOARDING-VERIFICATION-AND-CAPABILITY-LIFECYCLE-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-PARTNER-IDENTITY-COMPLIANCE-CAPABILITY-AND-COMMERCIAL-AGREEMENT-INTEGRITY-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-PARTNER-GEOGRAPHIC-COVERAGE-SERVICE-AREA-APPROVAL-AND-RECOVERY-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-CUSTOMER-AND-PARTNER-ONBOARDING-VERIFICATION-AND-ACTIVATION-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-PARTNER-COMPLIANCE-EVIDENCE-EXPIRY-AND-RENEWAL-ASSURANCE-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-PARTNER-WORKSPACE-ACCESS-AND-COMMERCIAL-GATE-HARDENING-AUDIT-2026-11-16.md`

**Gate C3.20: PARTIAL PASS / BLOCKED. Broad partner commercial activation remains NO-GO.**
