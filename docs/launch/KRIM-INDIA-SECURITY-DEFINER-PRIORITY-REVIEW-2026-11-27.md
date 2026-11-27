# KRIM India Launch — SECURITY DEFINER Priority Function Review
**Date:** 27 November 2026  
**Environment:** Staging only (`qrpcivhdxobiaofppbkl`)  
**Production:** Not accessed  
**Disposition:** Static review only; no function changes or invocations.

## Scope
Reviewed the first launch-critical subset of authenticated-callable SECURITY DEFINER functions identified in the current Staging advisor inventory: partner verification, quote preparation/acceptance, shipment creation/leg planning, driver assignment/acceptance, partner dispatch, and shipment tracking.

The subset query returned 17 functions. All 17 showed an explicit empty search path (`SET search_path TO ''`). This is a positive hardening signal, not proof of authorization correctness.

## Findings by flow

### Partner verification — guarded, but has real side effects
- `krim_admin_list_partner_verification_cases()` checks authenticated identity, AAL2 and `admin.platform` permission before returning a limited review queue.
- `krim_admin_request_partner_verification_information(bigint,text)` checks identity, AAL2, platform-admin permission, validates request text, locks the case/organization, updates review state and audit history.
- The information-request function also inserts an in-app notification and may enqueue an email outbox record. Do not invoke it with fixtures until notification/email test isolation is proven.
- `krim_admin_review_partner_verification(bigint,text,text)` checks identity, AAL2 and platform-admin permission. Approval is constrained to registered-business partner accounts, active logistics organizations, required registration/location fields, and submitted private-storage evidence owned by the original submitter.
- Static review does not prove every downstream helper, storage policy or state transition. Full approval/rejection E2E remains required.

### Quote selection and acceptance — authorization checks present
- `krim_customer_prepare_partner_quote(bigint,timestamptz)` checks that a user is authenticated and delegates to `krim_award_partner_quote_for_checkout`.
- The delegated function checks customer organization access plus `quote.update` and `shipment.update`, verifies the opportunity/quote/shipment relationship, state, validity, pricing and idempotent existing-award conditions. It creates a partner assignment and customer quote/version/event records.
- `krim_accept_global_quote(bigint)` checks customer organization access and `shipment.update`; it requires an accepted partner quote/assignment, active verified/compliant partner, verified capability, route coverage and current compliance. The function's terms indicate customer payment is arranged directly with the provider; KRIM freight collection remains disabled by design.
- Do not test acceptance on live business records. Downstream triggers and notification effects require isolated test ingress.

### Driver assignment and acceptance — strong ownership/evidence checks visible
- `krim_assign_driver_to_partner_shipment(bigint,uuid)` checks partner dispatch permission, accepted partner assignment and matching assigned shipment leg before assigning a driver.
- `krim_driver_accept_assignment(uuid)` scopes the row to `auth.uid()` and checks the exact linked partner assignment before delegating.
- `krim_driver_accept_assignment_unchecked(uuid)` independently checks assignment ownership, active driver membership, verified profile, valid licence, accepted licence-front/back and identity documents, assigned verified/active vehicle, required vehicle documents and exact accepted partner assignment.
- These checks look appropriately restrictive in the inspected definitions. Driver onboarding and acceptance still require negative tests for cross-user, expired-document, wrong-vehicle and stale-assignment cases.

### Tracking and dispatch — scoped access checks visible
- `krim_get_shipment_tracking(text)` checks authenticated identity and requires customer organization tracking permission or active partner membership with tracking permission. GPS exposure is further constrained to active, consented, verified in-transit driver sessions.
- `krim_partner_dispatch_assigned_shipment(bigint,text)` checks partner dispatch permission, accepted exact-leg assignment, shipment state, single-active-leg restriction and dispatch authorization before dispatch.
- Need regression tests for cross-tenant shipment references, revoked membership, wrong partner, multi-leg dispatch and stale GPS consent.

## Triage conclusion
- No immediate missing-authentication issue was established in the reviewed subset.
- Empty search_path was present for all 17 functions inspected.
- Several functions perform real state changes and may emit notifications/outbox records; this reinforces the existing ban on invoking them with synthetic fixtures before event and notification isolation is complete.
- The Supabase advisor warning for authenticated-callable SECURITY DEFINER functions must not be “fixed” by bulk revoking execute. Each function needs a documented intended caller, permission boundary, dependent helper review and regression test.
- The broader 55-function advisor set remains open; this is a prioritized subset review, not closure of the full finding.

## Next P0 actions
1. Continue function-by-function review of remaining authenticated-callable SECURITY DEFINER functions, prioritizing public/admin and finance-sensitive RPCs.
2. Inspect downstream trigger/helper behavior for quote award, quote acceptance, driver assignment and dispatch before test execution.
3. Complete isolated test-run/event/notification architecture and prove no production queue or external provider can claim test work.
4. Build negative authorization tests with separate customer, partner, driver and owner identities.
5. Re-run advisors and verify only after narrowly scoped changes are approved.

## Safety
No SQL mutation, function invocation, fixture creation, event insertion, queue claim, email/provider call, payment call or Production access occurred during this review.
