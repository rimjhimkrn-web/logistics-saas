# KRIM Live SECURITY DEFINER, Trigger and Finance Writer Audit
**Captured:** 16 November 2026  
**Project:** Production Supabase project `ebltviniygljwwseplph`  
**Method:** Read-only PostgreSQL catalog inspection. No function was invoked, no trigger was disabled, and no database objects or permissions were changed.

## Executive result
The public schema contains 364 functions/procedures. Of these:
- 332 are `SECURITY DEFINER`.
- 150 of those are executable by `authenticated`.
- 0 are executable by `anon` according to effective privilege checks.
- All 332 have a function-level `search_path` setting; 187 set it to the empty path and 145 use a non-empty path.
- 8 authenticated-executable SECURITY DEFINER functions set a `public`-first search path and need targeted review of writable-schema exposure and object qualification.

This is a large privileged-code surface. The absence of anon EXECUTE is a positive control, but it does not establish that the 150 authenticated-callable functions enforce correct tenant, role, object and state-transition authorization.

## Trigger inventory
The public schema has 113 enabled non-internal triggers and no disabled non-internal triggers in this snapshot. 100 enabled trigger attachments call SECURITY DEFINER functions.

### Finance/payment/payout trigger attachments observed live
| Trigger | Table | Function | Enabled | SECURITY DEFINER |
|---|---|---|---|---|
| `payment_financial_trigger` | `payments` | `create_financial_after_payment` | Yes | Yes |
| `sync_krim_payment_transaction` | `payment_orders` | `sync_krim_payment_transaction` | Yes | Yes |
| `trg_sync_financial_after_payment` | `payment_orders` | `sync_financial_after_payment` | Yes | Yes |
| `trg_notify_customer_payment_paid` | `payment_orders` | `notify_customer_payment_paid` | Yes | Yes |
| `trg_complete_shipment_financial` | `partner_payouts` | `complete_shipment_financial` | Yes | Yes |
| `trg_sync_financial_after_partner_payout` | `partner_payouts` | `sync_financial_after_partner_payout` | Yes | Yes |
| `trg_notify_partner_payout_paid` | `partner_payouts` | `notify_partner_payout_paid` | Yes | Yes |
| `trg_krim_financial_transaction_audit` | `krim_financial_transactions` | `krim_log_financial_transaction` | Yes | Yes |
| `trg_calculate_shipment_margin` | `shipment_financials` | `calculate_shipment_margin` | Yes | No |

The legacy `payments.payment_financial_trigger` and the payment-order / payout synchronization triggers remain enabled in production. This confirms the live write paths are present; it is not by itself proof that a payment or payout can currently be initiated from the UI.

The earlier finance audit identified the legacy payment-to-margin and revenue-recognition design as unsafe for KRIM's intended non-custodial referral model. This live trigger inventory reinforces the need to keep payment collection, partner payouts, freight settlements, automated shipment margin, and freight-value revenue recognition disabled until the entire path is reconciled and independently tested.

**Do not disable or alter these triggers ad hoc.** First determine dependencies and current callers, create a staging reproduction, test rollback and historical data integrity, and then plan a reviewed forward-only change after migration recovery.

## SECURITY DEFINER search-path review
Eight authenticated-executable functions were identified with `public` first in their configured search path:
- `krim_admin_list_partner_verification_cases`
- `krim_admin_schedule_inquiry_followup`
- `krim_admin_set_global_rate_card_status`
- `krim_create_global_shipment_from_places`
- `krim_create_partner_opportunity`
- `krim_create_tariff_quote`
- `krim_record_operational_milestone`
- `krim_submit_customer_service_request`

These are a review queue, not confirmed vulnerabilities. Inspect function bodies, schema CREATE privileges, object qualification, temporary-object handling, caller authorization, and tenant predicates. The 187 functions configured with an empty search path also need confirmation that all referenced objects are schema-qualified.

## Policy-less table confirmation
The previous snapshot's 24 RLS-enabled tables without policies were checked across direct SELECT, INSERT, UPDATE and DELETE privileges. Neither `anon` nor `authenticated` has those direct table privileges for any of the 24 tables. This is currently fail-closed for those direct access paths. It does not rule out access through privileged functions or service-role workers.

## Public view
The single public view is `partner_rating_summary`. Its `reloptions` include `security_invoker=true`; both `anon` and `authenticated` have SELECT privilege. Review its definition and returned columns to ensure it exposes only deliberately public, appropriately aggregated information.

## Required next actions (ordered)
1. Keep production financial movement and legacy financial triggers gated; do not execute test payments or payout RPCs.
2. Recover and compare the encrypted production schema export against repository migration history. No migration replay, baseline, squash or DDL until reconciliation.
3. Review all 150 authenticated-callable SECURITY DEFINER functions, prioritizing shipment creation, quote acceptance, partner sourcing, dispatch, customer/admin actions and finance.
4. Review the eight public-first search-path functions and all 187 empty-search-path functions for schema qualification and authorization.
5. Trace the active payment/payout trigger chain on staging and establish a safe forward-only deactivation/replacement plan if required by the approved non-custodial commercial model.
6. Verify `partner_rating_summary` is safe for anonymous reads.

## Limits
This is a catalog/metadata audit, not a source-code proof, tenant-isolation penetration test, payment E2E test, or legal/accounting approval. It does not certify production readiness. No production changes were made.
