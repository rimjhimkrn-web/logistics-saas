# KRIM Customer Journey — Step 4: Partner Assignment Lifecycle

**Audit date:** 2026-11-13  
**Disposition:** **BLOCKED — award/acceptance lifecycle contains a conflicting legacy path.**

## Production functions inspected (read-only)

- `krim_award_partner_quote(bigint)`
- `krim_award_partner_quote_for_checkout(bigint,timestamptz)`
- `krim_respond_to_partner_assignment(bigint,boolean,text)`
- `krim_accept_global_quote(bigint)`

All four are SECURITY DEFINER functions. Production privilege inspection shows `authenticated` can execute all four; `anon` cannot. Therefore these are callable authenticated API entry points and their server-side invariants matter independently of UI visibility.

## Positive controls

### Partner award function

`krim_award_partner_quote` checks customer organization access and quote/shipment update permissions; rejects development/test partners; locks the partner quote and opportunity; checks opportunity and partner-quote status/expiry; checks registered-business partner status, verification, lifecycle, compliance and an active verified capability; checks shipment/customer organization alignment and route/mode/weight capability coverage; creates an assignment in `offered` status; and records an audit event.

### Partner response function

`krim_respond_to_partner_assignment` checks authentication, assignment existence, partner organization access and shipment.update permission; accepts/rejects only offered assignments; checks response deadline; checks capability coverage and current partner compliance before acceptance; updates assignment and shipment-leg linkage; and writes tracking/audit events.

These are meaningful safeguards, but they do not close the full end-to-end transaction.

## Critical sequencing conflict

The live `krim_award_partner_quote_for_checkout` function:

1. calls `krim_award_partner_quote`, which creates an assignment with status `offered`;
2. immediately inserts a customer quote with status `accepted`;
3. writes a quote version/event as accepted;
4. the award function may also transition the shipment to `confirmed`.

This can produce a customer quote recorded as accepted and a shipment confirmed while the partner assignment is still only offered and has not yet been accepted by the partner. That conflicts with the intended partner-direct model and with the customer quote page's rule that customer acceptance requires a matching assignment already accepted.

The function is executable by authenticated users in production. Hiding a checkout UI or disabling customer freight checkout does not itself revoke this database API. Do not assume it is harmless or unreachable.

## Additional observations

- `krim_respond_to_partner_assignment` checks that the caller has access to the assignment's partner organization, but the function body should be strengthened/verified to ensure the linked partner quote's partner organization, shipment, opportunity and assignment all match before changing state. It loads the linked quote/opportunity but the visible checks are not a complete explicit equality guard for all those relationships.
- On partner rejection, it withdraws the selected partner quote, reopens the opportunity, and restores other rejected quotes to submitted. The transaction should be checked for existing customer quote/version cleanup and whether the shipment can safely be re-awarded without leaving stale accepted quote records.
- The function returns an already accepted assignment idempotently. This is useful, but it does not itself prove that a corresponding customer quote was accepted consistently.
- The customer acceptance RPC gap from Step 3 remains open: it does not enforce partner quote linkage, amount/currency equality or accepted assignment.
- The customer UI's preflight reads assignment state, but client checks are not a substitute for atomic server enforcement.

## Required target lifecycle

For the selected partner-direct commercial model, use one unambiguous sequence:

1. Customer shipment enquiry is created.
2. Eligible verified partner submits a quote.
3. Customer selects/awards the partner quote, creating a pending/offered assignment and a customer quote in a non-accepted state (or a clearly labelled pending-confirmation state).
4. Partner accepts the exact assignment.
5. Server atomically validates the linked quote, assignment, partner eligibility/capability, customer organization and shipment, then marks the customer quote accepted and transitions the shipment to confirmed.
6. Client re-reads persisted state and only then displays confirmed acceptance.
7. Customer and partner arrange freight payment directly; KRIM does not collect or settle freight charges.

The legacy checkout-oriented RPC should either be retired/restricted through a reviewed migration and grants, or rewritten to follow this exact partner-confirmation sequence. Do not revoke access or modify production grants without controlled staging tests and explicit approval.

## Required tests

- [ ] Customer award creates only a pending/offered assignment; customer quote is not prematurely accepted.
- [ ] Partner can accept only an assignment tied to its own organization, exact quote and shipment.
- [ ] Partner quote, opportunity, assignment and shipment foreign-key relationships are explicitly cross-checked.
- [ ] Ineligible, suspended, expired or capability-revoked partner cannot accept.
- [ ] Rejection does not leave an accepted customer quote or confirmed shipment behind.
- [ ] Re-award after rejection produces a single coherent current assignment and quote version.
- [ ] Competing awards are serialized; no two partners can be awarded to the same opportunity.
- [ ] Customer quote acceptance occurs only after partner assignment acceptance.
- [ ] Legacy checkout RPC cannot bypass partner confirmation.
- [ ] Authenticated non-customer/non-partner callers cannot misuse the respective RPCs.
- [ ] Audit events and shipment legs accurately reflect the final accepted assignment.
- [ ] Client re-reads quote, assignment and shipment from the database after each state-changing RPC.

## Safety boundary

Read-only production SQL inspection only. No quote awards, assignment responses, shipment transitions, customer records, payments, grants, migrations, merges or deployments were changed. Staging remains empty and lacks migration parity.

## Exit decision

**Step 4 is BLOCKED.** Partner award and response functions have useful controls, but the checkout-oriented award function can mark a customer quote accepted and shipment confirmed before partner assignment acceptance. The database lifecycle must be unified and verified in staging before commercial operations.
