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

A second query across all schemas returned 55 RLS-enabled tables without policies: auth 16, private 5, public 24, realtime 1, and storage 9. This is not directly comparable to the Security Advisor's earlier count of 29 because the catalog query includes system/managed schemas and may count objects outside the Advisor's scope. Within the public schema, 24 were found. No anon or authenticated data privileges were found on those 24. The all-schema query did find anon and authenticated data privileges on one realtime object and six storage objects; these may be expected managed-service grants and require object-level review rather than blanket revocation. The earlier Advisor count of 29 remains a separate snapshot until its exact object list can be retrieved.

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

## Cross-schema catalog summary\n\n| Schema | RLS-enabled tables without policies | Tables with anon data privilege | Tables with authenticated data privilege |\n|---|---:|---:|---:|\n| auth | 16 | 0 | 0 |\n| private | 5 | 0 | 0 |\n| public | 24 | 0 | 0 |\n| realtime | 1 | 1 | 1 |\n| storage | 9 | 6 | 6 |\n| **Total** | **55** | **7** | **7** |\n\nThe realtime and storage grants must be checked against the managed service's expected ACL model and specific object identities. They are not grounds for blanket revocation.\n\n## SECURITY DEFINER spot checks

1. `krim_accept_driver_invitation(text)`: checks authenticated user, confirmed email, a 64-character token format, token hash, invitation expiry/revocation/reuse, exact invited-email match, and current carrier eligibility before accepting.
2. `krim_vehicle_requirement_list()` and `krim_vehicle_set_document_requirement(...)`: delegate authorization to `krim_vehicle_admin_guard()`; the guard requires an authenticated AAL2 session and `admin.platform` permission. The mutation writes an audit event.
3. `krim_admin_list_capacity_resources()`: requires an authenticated user, AAL2, and platform-admin permission. `krim_admin_list_capacity_resources_lane_aware()` delegates to this guarded function before enriching the result.

These are spot checks only, not a complete audit of all 151 authenticated-callable SECURITY DEFINER functions.

## Next steps — zero-cost and read-only until proven

1. Retrieve the Security Advisor's exact 29-object finding list and reconcile it against the 55 all-schema catalog rows, separating managed auth/realtime/storage objects from application-owned tables.
2. Enumerate effective grants for all affected objects and verify no unintended roles inherit privileges.
3. Review service-role access paths and Edge Function secret boundaries.
4. Continue the 151-function review by classifying direct authorization, delegated guard, tenant scoping, MFA requirements, and dynamic SQL.
5. Keep production DDL and grant changes NO-GO until each affected object's intended access model is confirmed.

## Explicit safety decision

No broad policy creation, grant revocation, SECURITY DEFINER alteration, or service-role permission change is justified by the current evidence. A blanket policy or revoke could either expose tenant data or break legitimate server workflows.