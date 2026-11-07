# KRIM Payment and Partner Settlement RPC Review — 2026-11-07

Read-only review of selected live production function definitions and ACLs. No payment was initiated, no payout was recorded, and no database state or permission was changed.

## Scope reviewed

Selected SECURITY DEFINER routines:
- `krim_internal_reconcile_razorpay_captured_payment(uuid,text)`
- `krim_internal_activate_shipment_after_verified_payment(bigint)`
- `krim_internal_create_partner_payable(bigint)`
- `krim_internal_authorize_partner_settlement(bigint,text)`
- `krim_internal_record_partner_payout(bigint,text,text)`
- Legacy `create_partner_payout` and `complete_partner_payout`

## Positive controls observed

- All selected routines are not executable by `anon` or `authenticated` in the inspected ACL checks.
- The Razorpay reconciliation routine explicitly requires the JWT role `service_role`.
- Razorpay reconciliation checks paid order state, provider, payment ID, shipment/customer/quote bindings, accepted quote, amount/currency, accepted partner assignment, and confirmed capacity reservation before creating the financial transaction.
- The reconciliation insert is idempotent on provider/payment reference and verifies that any existing transaction matches the expected shipment, organization, amount, currency, status, and direction.
- Partner payable creation requires delivered shipment, completed assignment, independently verified delivery POD, accepted partner quote, and partner/assignment consistency.
- Settlement authorization requires an approved payable and checks treasury controls and (when required) a separate financial approval with matching amount/currency.
- Legacy payout functions are not client-executable in the inspected ACL checks.

## Risks / unresolved controls

1. `krim_internal_authorize_partner_settlement` and `krim_internal_record_partner_payout` do not visibly perform an in-function JWT role check in the reviewed excerpts. Their client-role ACLs are denied, which is a meaningful control, but their complete effective EXECUTE ACL and intended service-role-only caller path must be verified before any live settlement operation.
2. These two internal routines use non-empty search paths (`public, krim_internal, pg_temp` and `public, pg_temp`). Confirm every schema in each path is not writable by untrusted roles and that all sensitive object references are schema-qualified. Prefer a hardened empty search_path where practical.
3. `krim_internal_activate_shipment_after_verified_payment` checks that a payment row is already marked paid and validates quote/shipment amount and currency, but its direct caller ACL and trigger/edge-function invocation path need to be mapped. The separate Razorpay reconciliation function has stronger service-role and partner-assignment/capacity checks; do not assume these different payment paths are interchangeable.
4. Legacy payout functions refer to legacy `user_roles`, `shipment_requests`, `partner_payouts`, and `shipment_financials`. Keep them out of the KRIM Global payment/settlement flow unless a separate migration and reconciliation plan proves they remain required.
5. SQL function review does not validate Razorpay signature verification, webhook retry behavior, duplicate/conflicting payment IDs, edge-function secrets, ledger reconciliation, bank payout execution, or actual withdrawal.

## Required next tests

- Enumerate exact function ACL grantees (including service_role, postgres, and owner) and all trigger/edge-function callers.
- Verify the `krim_internal` schema and any search_path schemas are not writable by anon/authenticated.
- In isolated staging, assert anon/authenticated cannot call internal settlement/reconciliation routines, while the intended service role can.
- Test invalid payment ID, wrong provider, wrong amount/currency, quote mismatch, shipment mismatch, missing accepted assignment, unconfirmed capacity, duplicate webhook, conflicting existing transaction, and retry/idempotency.
- Test payable creation fails without verified POD, completed assignment, accepted quote, or delivered shipment.
- Test settlement fails without approval/treasury control, wrong amount/currency, wrong status, and duplicate execution reference.
- Reconcile payment order → Razorpay captured payment → company ledger transaction → partner payable → approved settlement → provider execution reference → final reconciliation.
- No live payout or real-money test until staging and accounting/tax checks are approved.

## Release decision

The reviewed SQL shows useful authorization and financial-integrity controls, but this is not proof of a complete money-flow E2E. No actual payment, bank withdrawal, partner payout, or settlement was tested. Keep production live-money launch NO-GO until isolated authenticated/service-role tests and a real approved accounting reconciliation are complete.


## Follow-up ACL and schema verification

A second read-only check confirmed the exact EXECUTE grantees for all five KRIM internal payment/settlement functions listed above are `postgres` and `service_role` only. Neither `anon` nor `authenticated` nor `PUBLIC` is granted EXECUTE.

Schema privileges:
- `krim_internal`: `anon` and `authenticated` have neither USAGE nor CREATE; `service_role` has USAGE but not CREATE.
- `private`: `anon` has neither USAGE nor CREATE; `authenticated` has USAGE but not CREATE; `service_role` has USAGE but not CREATE.
- `public`: client roles have USAGE but not CREATE.

This materially reduces the search-path concern for the internal settlement functions: untrusted client roles cannot create shadow objects in `krim_internal` or `public`, and cannot use `krim_internal` directly. Keep the search_path hardening review as defense-in-depth, but the inspected schema ACLs do not show client CREATE access in those schemas.
