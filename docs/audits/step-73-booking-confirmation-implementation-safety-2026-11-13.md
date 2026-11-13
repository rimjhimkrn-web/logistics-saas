# KRIM Launch Readiness — Step 73: Booking Confirmation Implementation Safety

**Date:** 2026-11-13  
**Branch:** `website/global-launch-readiness`  
**Disposition:** **BLOCKED — do not apply either quote-acceptance migration to production.**

## Scope
Read-only review of the two proposed quote-acceptance migrations, the prior production acceptance-RPC audit, the booking-confirmation/dispatch-readiness audit, and the customer quote-comparison client.

## Findings

1. The proposed `20261111120000_secure_global_quote_acceptance_partner_assignment.sql` adds important checks for customer ownership, linked partner quote, amount/currency parity, accepted assignment, and then calls `krim_transition_shipment(..., 'confirmed', ...)`.
2. The live production transition path has a readiness trigger that invokes the execution-readiness evaluator for `confirmed`. That evaluator can require a KRIM-owned paid payment record, compliance/document clearance and customs state. This conflicts with the chosen partner-direct commercial booking model, where KRIM does not collect freight payment.
3. The second proposal `20261113130000_revalidate_partner_eligibility_on_customer_quote_acceptance.sql` patches a live function definition by matching exact text fragments. It checks partner organization status and capability coverage, but is explicitly marked to apply only after migration-history reconciliation and staging tests.
4. Neither proposal has been validated against a migration-parity staging database. Production migration provenance is unresolved; staging currently has no migration parity. Do not run either migration, replay history, or patch the live function directly.
5. The quote-comparison client currently keeps the accept button disabled and explicitly states that no acceptance request is sent. This is the correct safe state while backend integrity remains unresolved.
6. Dispatch/capacity controls are distinct and must remain intact. A booking fix must not bypass the confirmed-capacity reservation/binding checks required before dispatch.

## Required implementation design

- Create a dedicated transactional booking-confirmation path that validates customer ownership, exact quote/partner-offer/assignment linkage, amount and currency, offer validity, partner registered-business status, current verification/compliance, and active capability coverage.
- Separate booking confirmation from execution readiness. Partner-direct freight payment must not be represented as KRIM payment or settlement.
- Preserve the existing dispatch readiness evaluator and dispatch capacity reservation/binding gate.
- Lock all records involved in a consistent order; prevent competing quote acceptance; retain audit, event, status-history and snapshot side effects.
- Re-read persisted quote, shipment and assignment after success in the client before showing confirmation.
- Test unauthorized callers, mismatched IDs/organizations, expired offers, revoked capability, non-compliant/suspended partners, concurrent acceptance, no KRIM freight payment, and dispatch with/without confirmed capacity.

## Exit criteria
1. Recover/reconcile production migration source history and establish a disposable staging database with validated schema parity.
2. Inventory every caller and consumer of shipment status transitions and readiness triggers.
3. Implement and test a dedicated booking path without weakening dispatch controls.
4. Obtain explicit approval before any production migration, function change, merge or deployment.

## Safety boundary
No production SQL writes, migrations, status changes, quote acceptances, assignments, payment calls, merge or deployment were performed. This report records a source-level safety review only.
