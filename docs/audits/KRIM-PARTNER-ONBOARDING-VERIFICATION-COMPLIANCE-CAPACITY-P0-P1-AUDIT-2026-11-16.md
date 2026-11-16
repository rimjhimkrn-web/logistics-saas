# KRIM Partner Onboarding, Verification, Compliance, Capability and Capacity Audit
Date: 2026-11-16

## Executive result

**NO-GO for real partner activation, provider matching or capacity-backed service commitments.** The database has a layered onboarding design with useful controls, but production has only one open verification case, one pending inactive capability, no approved service areas, no capacity resources, no capacity availability and no reservations. In addition, two confirmed workflow defects prevent safe completion or independent review.

## Production evidence (aggregate only)

- Organizations: 14 total; 12 with partner lifecycle/verification/compliance not applicable or not started; 1 onboarding in progress; 1 verification pending.
- Partner verification cases: 1 (open).
- Partner compliance evidence: 0.
- Partner compliance reviews: 0.
- Partner capabilities: 1 (pending, inactive).
- Partner service areas: 0.
- Capacity resources: 0.
- Partner capacity availability: 0.
- Capacity reservations: 0.
- Partner capacity commitments: 0.

These counts are a point-in-time snapshot, not proof that every workflow branch is operational.

## Positive controls confirmed

### Business identity onboarding
- The current multi-category onboarding routine requires authentication, active membership in a registered-business logistics organization and a registration document path bound to the caller and organization.
- It validates unique supported categories and requires one coverage entry for each selected category.
- The underlying global v2 routine checks required business identity/location fields, validates country codes, confirms submitted objects exist in the private verification bucket, binds the path to the submitting user and records the verification case and audit event.
- Submission moves the organization to pending verification/compliance and does not grant commercial activation.

### Capability review
- Platform-admin AAL2 is required.
- Approval requires a different user from the capability submitter, current partner compliance, active country and transport mode, one to five private evidence files owned by the original submitter and valid capability dates/weight.
- Standard approval explicitly blocks hazardous-goods and refrigerated capability pending specialist safety/equipment controls.

### Compliance review
- Platform-admin AAL2 is required.
- The reviewer must provide exactly four baseline checks: business registration, tax registration, operating authority and insurance liability.
- Approval requires evidence for verified checks, reasoned not-applicable decisions, an expiry within the next 365 days and no pending/rejected baseline checks.
- A compliance clearance is explicitly not itself commercial activation.

### Capacity registration
- Capacity registration checks active organization membership, partner.manage permission and current partner compliance.
- It requires an active mode/location and a currently verified matching capability.
- Resource evidence must exist in private storage and belong to the submitting user.
- New resource status is `pending_review`; the paired availability record starts as `unavailable`, so partner-reported capacity is not immediately advertised as bookable.

## Confirmed P0/P1 defects

### P0 — Service-area approval references a non-existent country-pack column

The live `krim_admin_review_partner_service_area` routine checks `krim_country_operating_packs.status='approved'`. The live table exposes `pack_status`, not `status`. This SQL reference is invalid and the approval routine will fail at runtime when that branch is evaluated. This was also identified in the prior service-area audit.

**Impact:** service-area requests cannot complete their intended approval path until the function is reconciled with the actual schema. Do not work around this by weakening the country operating-pack gate.

### P1 — Business identity verification approval lacks reviewer/submitter separation

`krim_admin_review_partner_verification` requires AAL2 platform-admin permission and validates required business fields and private registration-document ownership. However, unlike capability and service-area approval, it does not reject approval when the reviewer is the original onboarding submitter. It reads the submitting user from organization metadata but does not compare that user with the reviewer before setting verification to verified.

**Impact:** a user who is both onboarding submitter and platform administrator could approve their own business identity case. Add explicit reviewer != submitter, with an immutable audit trail, before any production activation is allowed.

### P1 — Capacity evidence review must be proven end-to-end before availability can be trusted

The registration routine deliberately marks resource pending_review and availability unavailable, which is a positive fail-closed control. But production has no resource-review or availability evidence rows, so there is no live proof that review approval, resource-to-availability binding, expiry, suspension, document revocation and capacity reservations remain synchronized. This audit did not execute those workflows.

### P1 — Partner verification is not equivalent to operational eligibility

The workflow is intentionally staged: business verification -> jurisdictional compliance -> capability verification -> service-area approval -> capacity resource review/availability -> market/corridor authorization -> matching. No single approval should be treated as sufficient. The earlier matching and global market/corridor audits found stored compliance status can be stale in some paths and there are no approved corridor dossiers or market activations.

### P1 — Multi-category onboarding is not proof of full service coverage

The multi-category routine maps selected categories to mode/service types and creates pending capabilities. It does not itself prove route-level service-area authorization, operating licences in every jurisdiction, current equipment capacity or corridor permission. Country catalogue presence alone is not permission to operate.

## Required remediation — not applied

1. Correct the service-area country-pack column reference only after migration/schema reconciliation; add a database-backed regression test for approval and rejection paths.
2. Add independent reviewer/submitter enforcement to business identity verification approval, and verify the same separation for compliance evidence review and every privileged approval surface.
3. Audit capacity-resource review, availability publication, suspension, expiry and reservation consumption as one linked lifecycle. Availability must never become bookable solely because a partner submitted a resource.
4. Bind resource and availability status transitions to the same resource, lane, transport mode, location, evidence and validity window.
5. Revalidate partner compliance, capability and service-area status at match, quote, assignment, reservation and dispatch time—not only at initial registration.
6. Require jurisdiction-specific authority/licence and insurance evidence by service and operating country; define renewal reminders, expiry holds and re-verification.
7. Add staging negative tests: wrong tenant, non-member, revoked member, unverified business, stale compliance, expired evidence, self-approval, wrong-country capability, wrong mode, inactive location/lane, missing resource evidence, expired capacity, overlapping reservations, duplicate retries and post-approval revocation.
8. Reconcile production migrations before any schema or function modification. Do not activate real partners, service areas or capacity merely to make workflows appear complete.

## Release impact

**NO-GO for provider onboarding completion, partner matching, customer price/availability promises or capacity-backed booking.** A submitted registration is not a verified provider; a verified business is not necessarily compliant; a compliant business is not automatically authorized for a service or route; a verified capability is not an approved service area; and reported capacity is not bookable capacity.

The platform should continue to present onboarding as an application/review process and must not claim partner coverage, verified capacity or service availability until every relevant gate is passed.

## Evidence boundaries

Read-only inspection of live function definitions, table columns, ACL metadata and aggregate counts. No partner records, verification cases, documents, capability, service area, capacity resource, availability or reservation were created or changed. No onboarding, review, approval or capacity RPC was executed. No production schema or settings were modified.
