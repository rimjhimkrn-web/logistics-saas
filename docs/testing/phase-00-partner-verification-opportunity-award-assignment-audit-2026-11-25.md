# Phase 00 — Partner verification, opportunity, award and assignment audit

Date: 2026-11-25  
Branch: `qa/phase-00-baseline-2026-11-25`  
Scope: read-only Production/Staging catalog and function-source review, aggregate state snapshot, and static UI-to-RPC inspection. No RPC invocations or data changes.

## Decision

**Partner acquisition and carrier assignment are not ready for live commercial onboarding.** The current live dataset has no verified commercial partner, no active verified capability, no approved service area, no partner bid, no partner assignment and no driver assignment. Staging is also empty for these records. The code contains meaningful controls, but the end-to-end flow has not been executed.

## Live data snapshot

### Production
- Partner verification cases: 1, status `open`.
- The open case belongs to organization 14, which is active but uses `development_test` account mode; verification is pending, lifecycle is `verification_pending`, compliance is `pending`, onboarding is `in_progress`.
- Partner capabilities: 1, belonging to organization 2; inactive and pending verification.
- Partner service areas: 0.
- Partner opportunities: 3 — 2 cancelled, 1 expired; none open.
- Partner quotes: 0.
- Shipment partner assignments: 0.
- Driver assignments: 0.
- Active verified/approved partner organizations: 0 (previous Phase 00 snapshot).

The open verification case cannot be approved through the reviewed admin approval RPC while the organization remains in `development_test` mode: approval explicitly requires `registered_business`. Do not change this account mode or approve the case simply to make QA pass. Establish a separate, synthetic registered-business Staging fixture with owned fake documents instead.

### Staging
- Verification cases: 0.
- Partner capabilities: 0.
- Service areas: 0.
- Opportunities: 0.
- Partner quotes: 0.
- Partner assignments: 0.
- Driver assignments: 0.

## Partner onboarding and verification controls

The partner onboarding page `public/partner/partner-onboarding.html` calls:
- `krim_set_partner_account_mode`
- `krim_submit_partner_onboarding_global_multi_v1`

Both functions are SECURITY DEFINER, empty-search-path, and authenticated-executable in both environments.

Staging's `krim_submit_partner_onboarding_global_multi_v1` adds an AAL2/MFA requirement before submission; Production does not. This is a material environment-policy difference. Do not relax Staging; review whether Production should adopt the stronger gate before any production release.

The approval function `krim_admin_review_partner_verification` matches byte-for-byte across environments. It requires:
- authenticated user, AAL2 and `admin.platform`;
- case in an eligible open/review/pending-information state;
- registered-business partner account and active logistics organization;
- required registration authority, country, operating country, category, registered address and city;
- at least one submitted registration document;
- every document path scoped to organization and original submitter, with a matching object in the private `krim-partner-verification` bucket owned by that submitter.

Approval changes organization verification to verified, but deliberately leaves compliance pending. Thus verification approval alone must not be treated as commercial eligibility. A capability must be independently verified and active, compliance current, and service area approved.

The admin verification-case listing function differs between environments: Staging returns additional partner review notes and onboarding status. Both versions use SECURITY DEFINER with `search_path=public, pg_temp`; harden after dependency review.

## Opportunity and bid controls

`krim_create_partner_opportunity` source matches across environments and requires:
- authenticated customer organization access and `quote.create`;
- shipment in draft/quoted state;
- explicit transport mode;
- active origin/destination locations, countries and markets;
- no active multi-leg plan until leg-specific sourcing is supported;
- response deadline between one hour and 30 days;
- existing open opportunity reuse to avoid creating repeated open opportunities.

This SECURITY DEFINER function uses `search_path=public, pg_temp`, unlike the empty-search-path pattern. Its table references are schema-qualified in inspected source, but it should be hardened after dependency review.

`krim_submit_partner_quote` has a previously reported Production/Staging mismatch:
- Production permits authenticated EXECUTE; Staging does not.
- Staging requires `private.krim_partner_compliance_is_current` in addition to verification, active capability, organization compliance and coverage checks.
- The partner quote UI calls this RPC directly. Staging browser bidding therefore fails at the privilege boundary until a reviewed ACL decision is made.

## Award and assignment controls

`krim_award_partner_quote` is service_role-only in both environments. The Staging body adds a verified route-capacity check for the requested service date before award; Production does not. Keep the stricter Staging control and reconcile the intended Production policy before launch.

`krim_respond_to_partner_assignment` is authenticated-executable in both environments and source differs:
- Production finalizes a confirmed-shipment partner assignment directly.
- Staging first checks that the linked capacity leg binding and reservation are both confirmed; otherwise it returns a deferred result with next step `partner_capacity_reservation`.
This Staging gate prevents final assignment without reserved capacity. It must be preserved and the Production difference reviewed before deployment.

The internal finalization RPC is service_role-only in both environments. The assignment/driver chain should be tested for concurrency and retry idempotency; source inspection alone cannot prove those runtime properties.

## Driver acceptance controls

`krim_driver_accept_assignment` matches across environments and requires:
- assignment belongs to the authenticated driver;
- active driver membership in the assignment organization;
- verified driver profile and unexpired licence;
- independently accepted licence-front, licence-back and identity documents;
- linked verified/active vehicle bound to the driver;
- all required vehicle documents approved and unexpired;
- accepted partner assignment matching shipment, leg and organization;
- shipment in an allowed assigned state (or the explicitly supported active multi-leg transit case);
- positive shipment weight and vehicle payload capacity with recognized units;
- road transport leg and matching verified partner capability plus approved active service area for pickup location.

This is a strong control set, but current data contains no driver assignments, and no runtime test has exercised it.

## UI / route observations

- `public/partner/partner-onboarding.html` is the full onboarding form and calls the two onboarding RPCs.
- `public/partner/services-capabilities.html` submits capability through the v2 capability RPC.
- `public/partner/submit-quote.html` submits bids through `krim_submit_partner_quote`.
- `public/growth/shipment-matching.html` and `public/shipments/carrier-assignment.html` are redirect/compatibility pages, not transaction forms. Test canonical destinations rather than assuming these legacy paths implement matching or assignment.
- Admin capability review route inspected is a staging workspace page; its visible source did not contain inline RPC references. The canonical admin review route and linked scripts need a separate browser wiring check.

## Blocking items

1. Do not promote the current `development_test` verification case to commercial approval. Create a separate isolated synthetic Staging partner with registered-business mode and test-owned private documents.
2. Resolve Staging authenticated EXECUTE gap for `krim_submit_partner_quote` through a reviewed ACL/migration decision; do not apply an unreviewed grant.
3. Reconcile Staging's stronger MFA submission gate, capacity-at-award gate and capacity-reservation-before-finalization gate with Production. Prefer the safer behavior, but do not deploy without migration/source review and explicit approval.
4. Review and harden SECURITY DEFINER functions with `search_path=public, pg_temp`, especially `krim_create_partner_opportunity` and `krim_admin_list_partner_verification_cases`.
5. Provision isolated Staging customer, registered-business partner, platform admin with AAL2, driver, verified vehicle and approved service-area fixtures.
6. Test onboarding submit → admin review → capability verification → service-area approval → opportunity creation → partner bid → award → capacity reservation → partner acceptance → driver/vehicle assignment → driver acceptance.
7. Negative-test missing MFA, incomplete/foreign-owned evidence, wrong org membership, unverified partner, inactive capability, expired opportunity/quote, uncovered route, over-capacity vehicle, wrong driver, and concurrent award/assignment attempts.
8. Verify audit events and essential notifications throughout; prior notification audits show current workflow preparation is not proof of message delivery.

## Evidence boundary

All findings derive from read-only SQL catalog/source and SELECT queries plus static page inspection. No RPC was invoked. No user, organization, document, capability, service area, opportunity, quote, assignment, or driver record was created or changed. No provider was called. Production and Staging remained unchanged.
