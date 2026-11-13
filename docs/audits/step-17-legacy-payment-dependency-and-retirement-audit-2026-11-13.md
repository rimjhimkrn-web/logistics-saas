# Step 17 — Legacy payment-system dependency and retirement audit

**Date:** 2026-11-13  
**Environment:** Production Supabase, read-only schema/data inspection  
**Scope:** `payments` (legacy), `payment_orders` (current order record), webhook event store, finance ledger, shipment financials, related triggers, constraints and policies.

## Executive decision

**Do not drop, truncate, rename, disable triggers on, or bulk-edit the legacy `payments` table yet.** It contains four historic Razorpay attempts (two locally paid, two pending), and production code still contains a trigger and payment-posting routines that reference it. The table also has downstream invoice-payment-application foreign-key dependencies. Its removal is not a safe launch cleanup.

The legacy payment path is not the same as the newer `payment_orders` path. There is no automatic one-to-one reconciliation between their rows. Preserve both systems as read-only historical records until provider evidence, accounting mapping, and code migration are complete.

## 1. Production data and linkage findings

### Legacy `payments`

Four rows were inspected:
- Shipment request 11: one pending ₹25,000 attempt and one paid ₹25,000 attempt.
- Shipment request 14: one pending ₹5,000 attempt and one paid ₹5,000 attempt.

All four have `krim_shipment_id = NULL`; they are associated through legacy `shipment_id` values. None of their payment transaction IDs matched a `krim_financial_transactions.provider_reference` row. The two paid records therefore have no matching row in that newer ledger under the inspected provider-reference mapping.

No rows were found in `krim_invoice_payment_applications`, but the table has a foreign key to `payments.id` with `ON DELETE RESTRICT`. A zero current row count does not remove this schema dependency.

### Newer `payment_orders`

The six newer rows are separate from the four legacy payment rows. The six newer records do not have a direct FK to `payments`; they have separate shipment/quote/organization FKs and are mirrored into the private `krim_payment_transactions` table by a dedicated trigger.

All six newer orders lack customer organization, customer quote, and partner quote linkage, as recorded in Step 16. This makes them unsuitable for current strict captured-payment reconciliation without a separately approved historical exception/mapping.

### Shipment financials

One row exists in `shipment_financials`: customer amount ₹5,000, partner cost ₹3,000, platform margin ₹2,000, status paid, customer payment paid, partner payout paid. Its `krim_shipment_id` is NULL; it is linked through legacy `shipment_id` (which refers to `shipment_requests`). Do not assume this row is the same as either paid ₹5,000 Razorpay record: the row has no provider/payment reference, and exact ownership/transaction mapping is not established.

## 2. Trigger and function dependencies

The legacy `payments` table has an AFTER INSERT/UPDATE trigger `payment_financial_trigger` invoking `public.create_financial_after_payment()`. When a row is paid, that function attempts to create a `shipment_financials` row using legacy `shipment_id`, `amount`, and paid status.

Other inspected routines still reference `payments`:
- `krim_internal_post_customer_payment_to_ledger(bigint)` reads and locks a legacy payment row and expects `status = 'paid'` plus a non-null `krim_shipment_id` linked to a customer organization.
- `krim_internal_activate_shipment_after_verified_payment`, `krim_internal_authorize_shipment_after_payment`, and `krim_internal_reconcile_customer_receivable` remain present as payment-related SECURITY DEFINER routines; they require a separate complete call-graph and permission review before any retirement.
- `notify_customer_payment_paid()` explicitly supports both `krim_shipment_id` and legacy `shipment_id` by using `COALESCE`.
- `sync_financial_after_payment()` updates `shipment_financials` by legacy `shipment_id`.

The newer `payment_orders` path has separate triggers:
- `private.sync_krim_payment_transaction()` mirrors each order into `private.krim_payment_transactions`.
- `notify_customer_payment_paid()` and `sync_financial_after_payment()` are attached to `payment_orders` as well.
- `sync_krim_payment_transaction()` marks quote linkage completeness in metadata; this is not proof that the provider payment itself was captured or settled.

The newer captured-payment ledger reconciliation routine explicitly requires a paid order with shipment, customer organization, customer quote, partner quote, accepted quote and accepted assignment/capacity binding. The six historic newer orders do not satisfy all those local linkage requirements.

## 3. Constraints and security

- `payments` has foreign keys to legacy `shipment_requests`, `customer_profiles`, `krim_shipments`, `krim_quotes`, and `krim_currencies`.
- `payment_orders` has foreign keys to `krim_shipments`, `krim_quotes`, `krim_partner_quotes`, and `krim_organizations`; refund requests reference it with `ON DELETE RESTRICT`.
- `krim_financial_transactions` has a unique provider/provider-reference index and a separate idempotency index. Never duplicate ledger rows to make the legacy table appear reconciled.
- RLS is enabled on `payments`, `payment_orders`, `payment_webhook_events`, `krim_financial_transactions`, and `shipment_financials`.
- The `payments` authenticated SELECT policy is scoped to the matching customer user ID. `payment_orders` has customer/finance-scoped read access. Authenticated access to webhook events is explicitly denied. Shipment financials explicitly deny anon and authenticated access.
- These policies do not by themselves establish that service-role or SECURITY DEFINER code paths are safe; keep the function-level permission review separate.

## 4. Safe retirement sequence (not executed)

1. Obtain Razorpay-side order/payment/refund/dispute/settlement evidence for all historic IDs from Step 16 and these four legacy payment rows.
2. Establish the canonical shipment, customer, contract, payment and accounting mappings. Resolve the paid ₹5,000 shipment-financials row ambiguity.
3. Review all RPC/function call sites, scheduled jobs, edge functions, frontend references, reports and invoice workflows that read or write `payments`.
4. Design a controlled, auditable legacy-to-canonical mapping. Do not manufacture new provider transactions or duplicate ledger entries. Any accounting backfill requires explicit accounting approval and idempotency.
5. Migrate active UI/API reads and writes away from legacy `payments`; retain historical read access under appropriate authorization.
6. Test in a populated isolated staging environment with copies of schema and synthetic data—not production data—and verify payment history, invoice applications, customer visibility, webhook handling and financial reports.
7. Only then propose a separate migration to revoke obsolete write paths or archive the table. Drop it only after all FK, routine, view, trigger, job and application dependencies are demonstrably removed and a restore plan exists.

## 5. Conclusion

The correct immediate action is **preserve and freeze legacy payment functionality from new commercial use, but do not disable its historical reconciliation/refund obligations or remove the table**. New KRIM freight checkout remains disabled by the partner-direct launch design; historic payment processing paths must remain available only as required to reconcile real prior transactions.

## Safety / scope

Read-only SQL inspection only. No rows, policies, triggers, functions, constraints, secrets, provider records, or environment settings were changed. No webhook was replayed, no customer was contacted, no payment/refund was created, and no deployment or PR merge occurred.
