# KRIM Live Public Schema Access Snapshot
**Captured:** 16 November 2026  
**Project:** Logistics SaaS production (`ebltviniygljwwseplph`)  
**Method:** Read-only PostgreSQL catalog queries through Supabase MCP. No DDL, grants, policy changes, data writes or migration operations were performed.

## Current catalog counts
| Object category | Count |
|---|---:|
| Ordinary public tables | 391 |
| Public views | 1 |
| Public functions/procedures | 364 |
| Public triggers | 161 |
| Public RLS policies | 412 |
| Public enum types | 0 |

The ordinary-table count differs from an earlier 343-table snapshot recorded on 31 October. Treat this as a new point-in-time catalog observation, not evidence that all new tables are complete or correctly configured.

## RLS coverage
- 391 of 391 ordinary public tables have row-level security enabled.
- 367 tables have one or more policies.
- 24 tables have RLS enabled but no policies.
- For all 24 policy-less tables, the catalog checks returned no direct `SELECT` or `INSERT` privilege for either `anon` or `authenticated`.

The 24 tables are:
`krim_corridor_compliance_controls`,
`krim_corridor_compliance_dossiers`,
`krim_corridor_compliance_events`,
`krim_corridor_compliance_legs`,
`krim_country_operating_packs`,
`krim_country_pack_control_events`,
`krim_country_pack_controls`,
`krim_country_pack_events`,
`krim_inquiry_followups`,
`krim_market_activation_controls`,
`krim_market_activation_events`,
`krim_market_readiness_assessments`,
`krim_market_readiness_events`,
`krim_market_readiness_requirements`,
`krim_market_regulatory_source_events`,
`krim_market_regulatory_sources`,
`krim_partner_compliance_evidence`,
`krim_partner_compliance_reviews`,
`krim_partner_shipment_capacity_commitments`,
`krim_pricing_rate_cards`,
`krim_shipment_leg_custody_transfer_events`,
`krim_shipment_leg_custody_transfers`,
`krim_shipment_leg_dispatch_authorizations`,
`shipment_pod_documents`.

## Interpretation and action
1. The 24 tables are presently fail-closed for direct `anon`/`authenticated` table access under the privileges checked. This is not evidence of a data leak. It may be intentional for tables accessed only through narrowly authorized server-side functions.
2. Do not add broad policies or grants to make these tables appear complete. First map every intended access path, including SECURITY DEFINER RPCs, service-role workers, storage and views.
3. Review the single public view for `security_invoker` semantics and grants separately; this snapshot did not inspect its definition.
4. Review all 364 public functions and 161 triggers for effective role access, SECURITY DEFINER ownership/search_path, side effects, and callers. Counts alone do not establish safety.
5. Compare this live catalog with the encrypted schema export after the protected manifest workflow is run. Migration-history reconciliation remains a separate blocker.

## Limits
This is a catalog/privilege snapshot, not a penetration test or semantic RLS audit. It does not establish that policies are correct, that SECURITY DEFINER functions enforce tenant boundaries, or that application UI routes use the intended RPCs. The migration history remains unreconciled; do not replay migrations or make production schema changes on the basis of this report.
