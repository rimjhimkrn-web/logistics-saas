# KRIM Customer Journey — Step 5: Server-Side Assignment Confirmation

**Audit date:** 2026-11-13  
**Disposition:** **BLOCKED — the production RPCs still permit premature confirmation and do not enforce a single consistent lifecycle.**

## Production inspection (read-only)

Inspected current definitions of:

- `public.krim_award_partner_quote(bigint)`
- `public.krim_award_partner_quote_for_checkout(bigint,timestamptz)`
- `public.krim_respond_to_partner_assignment(bigint,boolean,text)`
- `public.krim_accept_global_quote(bigint)`

All four are SECURITY DEFINER functions with an empty/fixed search_path. Previous privilege inspection found `authenticated` can execute all four and `anon` cannot. These are server-side API boundaries; hidden UI controls do not protect them.

## Confirmed state sequencing defects

### 1. Partner award confirms the shipment too early

`krim_award_partner_quote` creates a partner assignment with status `offered`, then, when the shipment is `quoted`, immediately calls `krim_transition_shipment(..., 'confirmed', ...)`. The partner has not yet accepted the assignment. This contradicts the desired partner-direct workflow.

### 2. Checkout-oriented award creates an accepted customer quote too early

`krim_award_partner_quote_for_checkout` calls the award function, then inserts a customer quote with status `accepted`, writes an accepted quote version and event, while the newly created assignment can still be `offered`. It also has authenticated EXECUTE privilege. Disabling checkout UI is not sufficient to close this database entry point.

### 3. Partner acceptance does not complete the customer lifecycle

`krim_respond_to_partner_assignment` validates current partner compliance/capability on acceptance and updates the assignment and shipment leg, but the inspected body does not atomically find and accept the matching customer quote or transition the shipment from its pending state to confirmed. The workflow can therefore be split across inconsistent states.

### 4. Relationship checks are incomplete in partner response

The response function loads the partner quote and opportunity, but the inspected function body does not explicitly assert every relationship before mutation:
- assignment.partner_quote_id = loaded partner quote.id;
- assignment.partner_organization_id = partner quote.partner_organization_id;
- partner quote.shipment_id = assignment.shipment_id;
- opportunity.shipment_id = assignment.shipment_id;
- opportunity.customer_organization_id = shipment.customer_organization_id;
- the assignment's linked shipment leg, if present, belongs to the same shipment.

These should be explicit server-side guards, not inferred from UI state or assumed foreign keys alone.

### 5. Rejection/re-award path can leave stale customer quote state

On rejection, the response function withdraws the partner quote, restores other rejected partner quotes to submitted, and reopens the opportunity. The inspected body does not visibly reconcile any customer quote/version that may already have been created by the checkout-oriented function. A later re-award can therefore encounter stale accepted customer quote records or conflicting quote history.

### 6. Customer acceptance RPC remains insufficient

`krim_accept_global_quote` still accepts a sent quote and confirms its shipment without checking partner offer linkage, amount/currency equality, exact accepted assignment, or current partner eligibility. The client preflight cannot replace atomic database checks.

## Required canonical lifecycle

Adopt one state transition authority, preferably partner response after a customer selects an offer:

1. Customer enquiry and partner opportunity exist.
2. Verified partner submits an eligible offer.
3. Customer selects the offer. Server creates one assignment in `offered` status and a customer quote in a non-accepted pending state. Shipment remains unconfirmed.
4. Partner responds to the exact assignment.
5. On acceptance, one database transaction locks and validates assignment, partner quote, opportunity, shipment, customer quote, partner organization and capability; verifies all relationship IDs and amount/currency binding; then marks assignment accepted, customer quote accepted and shipment confirmed, and updates/creates the matching shipment leg and audit events.
6. On rejection/expiry, the assignment is closed, no customer quote is left accepted, shipment remains unconfirmed, and the opportunity can be reopened only after reconciling stale quote/version records.
7. Client re-reads persisted records and shows success only when the exact quote, assignment and shipment all agree.
8. Freight payment remains directly between customer and partner; KRIM does not collect or settle freight charges.

## Safe remediation order

1. Build a staging environment with migration parity. Current staging has no migrations, tables or functions; it is not a safe place to test a patch yet.
2. Inventory every SQL and application caller of the four RPCs, including legacy/hidden routes and admin workflows.
3. Decide whether `krim_award_partner_quote_for_checkout` can be retired. If so, revoke authenticated EXECUTE only after all callers are removed and staging regression tests pass. Otherwise rewrite it as a pending-offer creator; it must never create an accepted quote before partner acceptance.
4. Rewrite `krim_award_partner_quote` so awarding creates an offered assignment but does not confirm the shipment.
5. Strengthen `krim_respond_to_partner_assignment` with explicit relationship guards and atomic finalization of the customer quote + shipment only on acceptance; rejection must reconcile quote state and safely reopen.
6. Harden `krim_accept_global_quote` as a strict idempotent finalization function or retire it if partner acceptance becomes the sole finalization authority. Do not leave two competing state-transition authorities.
7. Add concurrency, duplicate retry, expired offer, revoked capability, mismatch, rejection/re-award and rollback tests. Verify audit trail and shipment leg state.

## Client-side improvement recorded separately

Commit `ab900eda427f914e8d2075248b6907e6df676fec` updates the quote comparison page to re-read the exact customer quote, shipment and matching partner assignment after the acceptance RPC returns. It displays success only when all persisted statuses and IDs agree; otherwise it shows a reconciliation warning and instructs the customer not to pay or retry. This is a useful confirmation safeguard, but it does not repair the database sequencing defects above.

## Safety boundary

Only read-only production SQL inspection and GitHub branch changes were performed. No production SQL writes, grants, partner awards/responses, quote acceptances, shipment transitions, payment actions, migration application, merge or deployment occurred. Staging remains empty and lacks migration parity.

## Exit decision

**Step 5 is BLOCKED.** Do not start real commercial shipment acceptance or claim end-to-end booking readiness until the canonical lifecycle is implemented and tested in migration-parity staging, then separately approved for production.
