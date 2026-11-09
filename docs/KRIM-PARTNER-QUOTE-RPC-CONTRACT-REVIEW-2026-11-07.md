# KRIM Partner Quote RPC — Contract Review (2026-11-07)

## Scope
Static review of the proposed `public.krim_submit_partner_quote_for_organization` function against the live Supabase catalog. This review did not execute the proposed function, alter production schema, insert test rows, or change grants.

## Confirmed live contracts
- `krim_organization_members`: `organization_id bigint`, `user_id uuid`, `status` values include active/inactive/suspended.
- `krim_organizations.organization_type` permits customer, partner, enterprise, carrier, forwarder, warehouse, platform, customs, finance, operations.
- `partner_account_mode` permits registered_business, development_test, individual_interest.
- `partner_verification_status` permits not_started, pending, in_review, verified, rejected, expired.
- `partner_lifecycle_status` permits not_applicable, registered, verification_pending, under_review, approved, active, restricted, suspended, closed.
- `partner_compliance_status` permits not_started, pending, in_review, compliant, restricted, non_compliant, expired.
- `krim_partner_capabilities.verification_status` permits pending, verified, rejected, expired, suspended.
- `krim_partner_capabilities.service_type` permits transport, warehouse, freight_forwarding, last_mile, first_mile, customs, other.
- `krim_partner_opportunities` status values include draft, open, shortlisted, awarded, cancelled, expired.
- `krim_partner_quotes` status values include draft, submitted, under_review, shortlisted, accepted, rejected, withdrawn, expired.
- `krim_currencies` uses `code` and `is_active`.
- `krim_audit_events` includes actor_user_id, organization_id, event_type, entity_type, entity_id, source and metadata.

## Important authorization observation
The live helper `private.krim_partner_capability_covers_shipment(bigint,bigint)` is SECURITY DEFINER and does not grant EXECUTE to authenticated directly. The proposed RPC itself is SECURITY DEFINER, so its owner context can call the helper if the function owner retains EXECUTE. Confirm ownership and owner privileges during migration review; do not grant this helper to client roles merely to make the RPC work.

The live `private.krim_has_permission(uuid,bigint,text)` is SECURITY DEFINER and executable by authenticated; the proposal calls it with the explicit selected organization ID.

## Corrections applied
- Partner eligibility now requires exact live states: verification = verified; lifecycle = approved or active; compliance = compliant.
- Organization type limited to partner, carrier, forwarder, matching the existing live quote RPC.
- Readiness indicators in Partner app no longer treat unknown or non-compliant values as compliant/verified.
- Partner organization list is limited to supported partner types for this quote workflow.

## Not yet proven
No authenticated staging fixtures were available in this pass. Therefore these are NOT marked passed:
1. User membership in two organizations; quote must be written to the explicitly selected organization.
2. Missing `quote.create` permission on selected organization.
3. Verification/compliance/lifecycle failures.
4. Capability route/mode/weight mismatch and expiry.
5. Closed, awarded or expired opportunity.
6. Concurrent submission and duplicate handling.
7. Quote row and audit event organization IDs agree.
8. Client-role execute grants are correct after migration.
9. Legacy RPC compatibility during client rollout.

## Required before production migration
- Verify the proposal against the exact function owner and grants.
- Review quote row schema, triggers, required columns, indexes and uniqueness rules.
- Run positive and negative tests using authenticated staging users and two partner organizations.
- Test concurrent submissions and rollback behavior.
- Run all three mobile app CI jobs on the final PR head.
- Keep partner quote submission disabled until the tests pass.

## Decision
STATIC CONTRACT REVIEW: PARTIAL PASS after status and type corrections.
AUTHENTICATED INTEGRATION TESTS: NOT RUN.
PRODUCTION MIGRATION: NOT AUTHORIZED / NOT APPLIED.
