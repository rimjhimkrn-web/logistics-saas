# KRIM Phase 00 — Database Definition Diff Checkpoint 03

**Date:** 25 November 2026  
**Scope:** Read-only catalog comparison of `public`, `private`, and `krim_internal` in production and staging.  
**Projects:** Production `ebltviniygljwwseplph`; staging `qrpcivhdxobiaofppbkl`.  
**No database changes were made.**

## 1. Function definition manifest comparison

Compared stable function identity (schema, name, identity arguments), MD5 hash of `pg_get_functiondef`, SECURITY DEFINER flag, configured search_path, and EXECUTE privilege for anon/authenticated.

| Result | Count |
|---|---:|
| Functions in production across the three application schemas | 504 |
| Functions in staging across the three application schemas | 517 |
| Production-only signatures | 1 |
| Staging-only signatures | 14 |
| Shared signatures with different definition hashes | 21 |

Production-only signature:
- `public.krim_report_operational_exception(p_shipment_id bigint, p_exception_type text, p_severity text, p_description text)`

Examples of staging-only signatures:
- `public.krim_create_global_shipment_from_locations_idempotent(...)`
- `public.krim_partner_dispatch_assigned_shipment(...)`
- `public.krim_partner_list_assignment_capacity_states(...)`
- `public.krim_partner_resolve_driver_exception(...)`
- `public.krim_admin_request_partner_verification_information(...)`
- `public.krim_admin_list_market_readiness_requirements()`
- `public.krim_internal_claim_resend_email_batch(...)`
- `public.krim_internal_finish_resend_email(...)`

Examples of shared functions with different definition hashes:
- `public.krim_accept_global_quote(bigint)`
- `public.krim_award_leg_partner_quote(bigint)`
- `public.krim_award_partner_quote(bigint)`
- `public.krim_customer_prepare_partner_quote(bigint, timestamp with time zone)`
- `public.krim_admin_list_country_packs()`
- `public.krim_admin_list_partner_verification_cases()`
- `public.krim_admin_review_partner_service_area(bigint, text, text)`
- `private.krim_partner_capability_covers_shipment(bigint, bigint)`
- `private.krim_partner_capability_covers_shipment_leg(bigint, bigint)`

The list above is representative, not the complete 21-function list. The full manifest should be retained in the QA evidence store before any remediation. Do not overwrite either environment based only on name or count.

## 2. Trigger comparison

For non-internal triggers attached to the three application schemas:

| Result | Count |
|---|---:|
| Production triggers | 113 |
| Staging triggers | 115 |
| Production-only | 0 |
| Staging-only | 2 |
| Shared trigger definitions with changed hashes | 0 |

Staging-only triggers:
- `public.krim_driver_assignments.trg_krim_audit_driver_assignment_acceptance`
- `public.krim_shipments.trg_krim_require_warehouse_handover_before_shipment_dispatch`

These may reflect intentional newer staging migrations, but their production parity and business-critical implications must be assessed before release.

## 3. Policy comparison

For `pg_policies` rows in `public`, `private`, and `krim_internal`:

| Result | Count |
|---|---:|
| Production policies | 412 |
| Staging policies | 412 |
| Production-only policies | 0 |
| Staging-only policies | 0 |
| Shared policies with changed definition hashes | 0 |

This filtered policy comparison is not the same metric as the broader advisor/catalog totals in checkpoint 02, which include other schemas. It does show that the policy definitions in these three application schemas match in this snapshot. Grants, role inheritance, exposed schemas, views, functions and Edge Functions still need independent authorization review.

## 4. Next required reconciliation

1. Preserve complete machine-readable function manifests (including definition hashes, security mode, search_path and grants).
2. Retrieve and review full source for all 21 changed functions and 15 one-sided signatures.
3. Trace the two staging-only triggers to their migration files and confirm whether production is intentionally missing them.
4. Compare function EXECUTE privileges and table/sequence grants by role; do not assume identical RLS policies mean identical effective access.
5. Reconcile migration ledger entries with repository migrations and the actual catalog state. Do not bulk replay or reset.
6. Verify deployed Edge Function source/version parity and each function's caller, JWT mode, secrets and staging deployment need.

## 5. Phase status

**PHASE 00 remains IN PROGRESS.** This checkpoint is catalog-diff evidence only. It is not runtime testing, a security certification, or a production-readiness approval.
