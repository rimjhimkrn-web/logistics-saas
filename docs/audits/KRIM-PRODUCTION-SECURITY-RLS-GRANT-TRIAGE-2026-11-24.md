# KRIM production security triage — RLS tables without policies

**Inspection date:** 2026-11-24  
**Project:** Production Supabase project (read-only inspection)  
**Change type:** Audit evidence only. No grants, policies, functions, or settings changed.

## Live catalog query

A direct catalog query on public tables with RLS enabled and no matching `pg_policies` row returned:

| Measure | Result |
|---|---:|
| Public RLS-enabled tables with no policies (direct query) | 24 |
| Those tables with anon SELECT/INSERT/UPDATE/DELETE privilege | 0 |
| Those tables with authenticated SELECT/INSERT/UPDATE/DELETE privilege | 0 |
| Those tables with service_role data privilege | 21 |

RLS enabled with no policies denies ordinary roles by default. The direct privilege check found no anon or authenticated data grants on this set. The 21 service_role grants are consistent with server-side service access, which bypasses RLS by design and must remain restricted to trusted backend code.

The Supabase Security Advisor previously reported 29 RLS-enabled tables without policies. The direct public-schema query returned 24. The five-object discrepancy is unresolved; the Advisor may include a different object scope or a different snapshot. Re-run the Advisor and enumerate all schemas/object types before closing the discrepancy.

## Objects returned by the public-schema query

- krim_corridor_compliance_controls
- krim_corridor_compliance_dossiers
- krim_corridor_compliance_events
- krim_corridor_compliance_legs
- krim_country_operating_packs
- krim_country_pack_control_events
- krim_country_pack_controls
- krim_country_pack_events
- krim_inquiry_followups
- krim_market_activation_controls
- krim_market_activation_events
- krim_market_readiness_assessments
- krim_market_readiness_events
- krim_market_readiness_requirements
- krim_market_regulatory_source_events
- krim_market_regulatory_sources
- krim_partner_compliance_evidence
- krim_partner_compliance_reviews
- krim_partner_shipment_capacity_commitments
- krim_pricing_rate_cards
- krim_shipment_leg_custody_transfer_events
- krim_shipment_leg_custody_transfers
- krim_shipment_leg_dispatch_authorizations
- shipment_pod_documents

## SECURITY DEFINER spot checks

1. `krim_accept_driver_invitation(text)`: checks authenticated user, confirmed email, a 64-character token format, token hash, invitation expiry/revocation/reuse, exact invited-email match, and current carrier eligibility before accepting.
2. `krim_vehicle_requirement_list()` and `krim_vehicle_set_document_requirement(...)`: delegate authorization to `krim_vehicle_admin_guard()`; the guard requires an authenticated AAL2 session and `admin.platform` permission. The mutation writes an audit event.
3. `krim_admin_list_capacity_resources()`: requires an authenticated user, AAL2, and platform-admin permission. `krim_admin_list_capacity_resources_lane_aware()` delegates to this guarded function before enriching the result.

These are spot checks only, not a complete audit of all 151 authenticated-callable SECURITY DEFINER functions.

## Next steps — zero-cost and read-only until proven

1. Reconcile the 29 Security Advisor findings with the 24 public catalog rows, including schema and object scope.
2. Enumerate effective grants for all affected objects and verify no unintended roles inherit privileges.
3. Review service-role access paths and Edge Function secret boundaries.
4. Continue the 151-function review by classifying direct authorization, delegated guard, tenant scoping, MFA requirements, and dynamic SQL.
5. Keep production DDL and grant changes NO-GO until each affected object's intended access model is confirmed.

## Explicit safety decision

No broad policy creation, grant revocation, SECURITY DEFINER alteration, or service-role permission change is justified by the current evidence. A blanket policy or revoke could either expose tenant data or break legitimate server workflows.