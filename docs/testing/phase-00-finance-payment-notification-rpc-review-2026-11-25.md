# Phase 00 — Finance, Payment and Notification RPC Exposure Review
Date: 2026-11-25
Branch: `qa/phase-00-baseline-2026-11-25`
Scope: Read-only catalog and source review of Production/Staging SECURITY DEFINER functions with payment, Razorpay, ledger, payout, settlement, invoice and notification names. No payment, payout, webhook, email, notification or database function was invoked.

## Executive result
**No anonymous execution privilege was found for the inspected finance/payment/notification SECURITY DEFINER functions.** Internal payment, ledger, payout and notification routines are not executable by `anon` or `authenticated` in the inspected grants. Two finance-facing read RPCs are authenticated-executable in Production and have explicit authorization checks in their source. Staging currently does not grant authenticated execution to those two read RPCs, which is a parity gap to resolve against the intended test role matrix.

## 1. Function exposure inventory
The following categories were found in both Production and Staging:
- Internal payment authorization/reconciliation routines.
- Internal customer payment and revenue ledger posting routines.
- Internal partner settlement/payout authorization and reconciliation routines.
- Trigger-style notification routines for customer payment paid and partner payout paid.
- Finance read RPCs for payment webhook reconciliation and revenue ledger.

For the internal functions in this name-based inventory, catalog privilege checks report:
- `anon EXECUTE = false`
- `authenticated EXECUTE = false`

This includes `krim_internal_*`, `create_financial_after_payment`, `create_partner_payout`, `complete_partner_payout`, `notify_customer_payment_paid`, `notify_partner_payout_paid`, `sync_financial_after_payment` and `sync_financial_after_partner_payout`. Their intended trigger/service-role invocation chains still need separate trigger and Edge Function review. The name-based list is not a complete audit of all functions that may affect finance.

## 2. Finance-facing read RPC source review
### `krim_finance_list_payment_webhook_events(p_only_unprocessed, p_limit)`
Production grants authenticated EXECUTE; Staging does not.
Source requires:
- Authenticated user.
- AAL2 session.
- `admin.platform` permission.

It returns a bounded list (maximum 100) of webhook event metadata, masks provider event/order identifiers, and shows reconciliation state. This is a sensitive platform-admin view and should be tested for AAL1 rejection, non-admin rejection, and no raw payment/customer payload leakage.

### `krim_finance_list_revenue_ledger(p_limit)`
Production grants authenticated EXECUTE; Staging does not.
Source requires:
- Authenticated user.
- Active membership in an active organization of type `finance`.
- `finance.view` permission for that organization.

It returns the revenue ledger fields and applies a 1–100 row limit. The source query returns the latest rows from the revenue ledger globally after the finance-org permission check, rather than filtering by a ledger organization. Confirm that this is the intended central-finance model; if finance users are meant to be tenant-scoped, this is a potential cross-organization data-scope defect requiring design review and negative tests. No runtime access was attempted.

## 3. Payment/ledger safety boundaries
The internal payment routines are SECURITY DEFINER and often use trusted schemas/search paths. Their lack of anon/authenticated EXECUTE grants is a positive exposure control. However, this does not establish:
- Correct webhook signature and event-id idempotency at runtime.
- Correct mapping of Razorpay payment/order IDs.
- Correct exactly-once posting to customer/revenue/partner ledgers.
- Correct 10/90 split calculations, currency precision, rounding and tax treatment.
- Correct settlement eligibility, duplicate payout prevention or reconciliation.
- Correct customer/partner notification queue creation after payment or payout.

These must be tested in a fully isolated staging setup with provider test credentials or mocked webhook payloads. Do not invoke real provider operations or internal financial routines in Production.

## 4. Notification finding
The inventory includes trigger-style functions named `notify_customer_payment_paid`, `notify_partner_payout_paid`, `krim_log_shipment_alert`, and financial sync functions. Their anon/authenticated execute grants are false. This is consistent with server-side/trigger execution, but it does **not** prove notifications are reliably queued, delivered, retried or recorded.

KRIM's required customer-journey notifications remain unverified. Tests must trace event → notification record/queue → recipient/channel selection → delivery attempt → provider response → retry/dead-letter status, without sending real messages.

## 5. Production–Staging parity
| Function | Production authenticated EXECUTE | Staging authenticated EXECUTE |
|---|---:|---:|
| `krim_finance_list_payment_webhook_events` | Yes | No |
| `krim_finance_list_revenue_ledger` | Yes | No |
| Internal payment/ledger/payout/notification routines sampled | No | No |

Do not copy Production grants into Staging automatically. First verify the finance workspace call sites and decide which synthetic staging role should exercise these read paths.

## 6. Evidence status
| Check | Result |
|---|---|
| Finance/payment/notification function inventory | PASS — name-pattern catalog snapshot |
| Internal routines anon EXECUTE | PASS — none found |
| Internal routines authenticated EXECUTE | PASS — none found |
| Webhook reconciliation read RPC auth/AAL2/admin guard | PASS — source review |
| Revenue ledger read RPC finance permission guard | PASS — source review |
| Revenue ledger tenant-scope intent | REVIEW REQUIRED |
| Staging finance RPC grant parity | GAP — not yet resolved |
| Real webhook/payment/payout execution | NOT TESTED (intentionally) |
| Ledger exactly-once and 10/90 calculations | NOT TESTED |
| Notification delivery/retry/reconciliation | NOT TESTED |
| Full finance function and trigger chain review | INCOMPLETE |

## 7. Required next work
1. Trace finance workspace frontend call sites and intended role matrix for both read RPCs.
2. Confirm whether the finance workspace is a central platform finance function or organization-scoped; test ledger row isolation accordingly.
3. Inspect triggers and Edge Function call chains for internal payment, payout and notification functions.
4. Build a staging-only financial test harness with deterministic fake payment events and no external provider calls.
5. Verify duplicate webhook replay, mismatched order/payment IDs, failed/authorized/captured/refunded states, currency precision, ledger balancing, commission split, payout double-submit and rollback behavior.
6. Trace notification queues for payment, payout, shipment and driver milestones; assert mandatory event coverage and delivery-state observability with provider delivery mocked.

## Safety boundary
Only read-only catalog/source queries were used. No financial function was invoked; no real or simulated payment was sent; no payout, email, SMS, Telegram, webhook or notification was triggered; no database data or configuration was modified.

## Readiness decision
The inspected finance/payment function exposure is restricted at the database EXECUTE layer. Finance data scope, staging parity, financial correctness and notification reliability remain open. Phase 00 remains IN PROGRESS. NO EVIDENCE = NO PASS.
