# Partner onboarding, verification, capability and service-area revalidation
**Date:** 2026-11-17  
**Scope:** Read-only production catalog/function/data inspection. No production writes, no live partner review, no onboarding, no quote, capacity reservation or shipment actions were executed.

## Decision
**NO-GO for operational partner activation and unrestricted live onboarding.** Current production data does not demonstrate a single verified and compliant partner with an approved capability and service area. Do not treat submitted partner information, an organization record, a capability row, a verification case, or a UI badge as proof of operational eligibility.

This is a revalidation/remediation record, not a production fix. No SQL in this document is a migration.

## Read-only production snapshot
- `krim_organizations`: 14 rows; 0 have `partner_verification_status='verified'`; 14 are not verified. This count includes all organization types and is not a partner-only denominator.
- `krim_partner_capabilities`: 1 row; 0 verified; 1 not verified.
- `krim_partner_service_areas`: 0 rows.
- `krim_partner_verification_cases`: 1 row; 0 approved; 1 not approved.
- `krim_partner_compliance_reviews`: 0 rows.
- `krim_partner_compliance_evidence`: 0 rows.
- The snapshot establishes absence of approved operational evidence in these tables, not whether a real-world provider exists outside KRIM.

## Verified controls observed
1. `krim_admin_review_partner_verification(bigint,text,text)` is SECURITY DEFINER, requires authenticated AAL2 and `admin.platform`, accepts only open/in-review/pending-information cases, and for approval requires registered-business mode, an active logistics organization, core business/location metadata, at least one document path, and matching private-storage objects owned by the original submitter. It updates organization verification/lifecycle/onboarding states and records an audit event.
2. The verification approval body inspected does **not** explicitly reject a reviewer whose user ID equals the original submitter. Unlike the capability and service-area review functions, no submitter-versus-reviewer separation check was observed. Add an independent reviewer requirement before enabling commercial approval.
3. `krim_admin_review_partner_capability` requires AAL2 platform admin, a reasoned decision, prevents submitter self-approval, requires current organization compliance, active country and transport mode, one to five evidence files in private storage owned by the submitter, and valid effective dates/weight. Standard approval explicitly blocks hazardous-goods and refrigerated capability until specialist evidence controls exist.
4. `krim_admin_review_partner_service_area` requires AAL2 platform admin, prevents submitter self-approval, requires active registered-business status and current compliance, an approved country operating pack, active and correctly related country/market/location/mode records, one to five owner-matched private evidence files, and a matching active verified capability.
5. `private.krim_partner_compliance_is_current(bigint)` returns true only when the organization is active, registered-business, verified, compliant, lifecycle approved/active, and its latest compliance review is approved and has a future `valid_until`.
6. `krim_admin_review_partner_compliance` requires AAL2 platform admin, exactly four distinct baseline checks (business registration, tax registration, operating authority, insurance liability), a reasoned reviewer note, expiry for approval, and evidence metadata matching current uploaded storage objects for verified checks. It rejects approval if any baseline check is pending/rejected.

## Findings requiring closure
### P0 — No verified operational partner demonstrated
The live snapshot has no approved verification case, no approved compliance review/evidence, no verified capability, and no service-area record. Therefore no partner should be considered eligible for real matching, quoting, assignment or execution based on current data.

### P1 — Business identity review lacks an observed maker-checker guard
The inspected partner verification approval function validates original document ownership but does not visibly enforce that the reviewer differs from the submitting user. Add a server-side separation-of-duties check and tests. Capability and service-area review already contain explicit self-review prevention.

### P1 — Revalidation must be enforced at every operational boundary
The current-compliance helper is a useful gate, but downstream eligibility must also require exact active verified capability and exact approved service-area scope, current validity, supported mode/service/country/market/location, shipment cargo/weight/temperature/hazard scope, and current jurisdictional operating controls. Do not infer that approval at onboarding permanently authorizes all future lanes or cargo.

### P1 — Evidence integrity and revocation lifecycle
Approval checks storage object existence/ownership for the inspected workflows. The complete lifecycle still needs proof for replacement/revocation, stale evidence, expiry, document authenticity, issuer/authority validation, malware/content validation, reviewer identity, immutable decision history, and immediate invalidation of dependent eligibility after suspension, expiry, changed scope or revoked documents.

### P1 — Status consistency and atomicity
Verify organization, verification case, compliance review, capability and service-area status transitions remain transactionally consistent under concurrent review, retries, suspension and expiry. Add invariant checks so stale approved capability/service-area rows cannot remain operational when the organization or compliance review is no longer current.

## Required implementation and acceptance sequence
1. Reconcile production migration history and schema against repository before any DDL/function/grant change. Do not apply or replay migrations while the known migration-history discrepancy remains unresolved.
2. Prepare a reviewed migration that adds verification-case maker/checker separation, evidence freshness/revocation and status-consistency invariants, and centralizes a canonical partner-eligibility predicate.
3. Make every quote/opportunity/matching/assignment/capacity/dispatch boundary call the canonical predicate with exact shipment leg, route, mode, service, cargo and time scope. Fail closed for missing, ambiguous, expired, suspended or stale evidence.
4. Ensure eligibility reads expose only the minimum data required to authorized roles; audit all SECURITY DEFINER entry points and their EXECUTE grants.
5. Build isolated staging fixtures for positive and negative cases. Test unverified, pending, rejected, suspended, expired, self-reviewed, stale evidence, missing capability, missing service area, mismatched country/market/location/mode/service, weight over limit, hazardous and refrigerated cargo, changed jurisdiction rules, concurrent approvals and replayed requests.
6. Prove full end-to-end flow in staging: partner application → private evidence upload → independent business verification → compliance review → capability approval → service-area approval → matching eligibility → quote → customer acceptance → exact-leg assignment → capacity reservation → dispatch authorization. Use synthetic identities/documents and sandbox services only.
7. Run independent security review, RLS/ACL/advisor checks, static tests, integration tests and regression suite. Record exact commit, migration versions, test evidence and rollback plan.
8. Only after explicit owner approval and a successful controlled pilot may any production activation be considered. Never automatically activate a partner from an application or evidence upload.

## Not verified in this audit
- Full bodies of every partner onboarding, capacity, matching, invitation, quote and payout function.
- Private storage bucket policies and all object upload/download paths.
- All partner-specific RLS policies, triggers, grants and frontend screens.
- Real document authenticity or authority confirmation.
- End-to-end staging behavior; no write tests were run.
- Migration/schema equivalence.

## Permanent operating rule
Partner eligibility is not a one-time permanent flag. It must be continuously derived from current organization state, current independent verification, unexpired compliance, exact approved capability and service-area scope, and current jurisdiction controls. Any material change or missing proof must fail closed and require re-review.
