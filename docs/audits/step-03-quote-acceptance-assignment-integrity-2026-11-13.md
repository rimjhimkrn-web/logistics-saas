# KRIM Customer Journey — Step 3: Quote Acceptance & Partner Assignment Integrity

**Audit date:** 2026-11-13  
**Branch:** `website/global-launch-readiness`  
**Disposition:** **BLOCKED — deployed acceptance RPC does not enforce the partner-offer and accepted-assignment invariants shown in the client and proposed migration.**

## Scope inspected

- `public/shipper/quote-comparison.html`
- Live production definition of `public.krim_accept_global_quote(bigint)` obtained by read-only SQL inspection.
- RLS enabled state of `krim_quotes`, `krim_partner_quotes`, `krim_shipment_partner_assignments` and `krim_shipments`.

## Positive controls in the current client

1. Customer must have an authenticated session and active customer/shipper organization membership.
2. Shipment lookup is filtered by the user's organization IDs.
3. Quotes are loaded for the selected shipment and exact customer organization.
4. The UI only enables acceptance for a sent, unexpired, positive-amount quote with a linked partner quote.
5. Before enabling the button, the UI reads a matching assignment and requires `status='accepted'`.
6. The UI requires the shipment to be in `quoted` status.
7. Acceptance is submitted to the database RPC, not performed by direct browser table updates.
8. All four relevant production tables currently have RLS enabled.

## Critical production finding

The live production function definition for `krim_accept_global_quote(bigint)` was inspected directly. It currently:

- Locks and loads the quote and shipment.
- Checks quote/shipment existence.
- Requires a non-null customer organization on the quote.
- Checks organization access and `shipment.update` permission.
- Requires quote status `sent`.
- Expires an elapsed quote.
- Requires shipment status `quoted`.
- Marks the quote accepted and transitions the shipment to `confirmed`.

**But the deployed function does not:**

- Verify that the shipment's customer organization equals the quote's customer organization.
- Require a non-null `partner_quote_id`.
- Load and validate the linked partner quote belongs to the same shipment.
- Check partner offer status or expiry.
- Bind customer quote amount and currency to the partner offer.
- Require an accepted assignment for the same shipment, partner quote and partner organization.
- Revalidate the partner organization's current verification/compliance/lifecycle state or capability at acceptance time.

This is a material mismatch: the client-side assignment check is only a preflight and can be bypassed by calling the RPC directly. RLS being enabled on the tables does not compensate for checks omitted inside a SECURITY DEFINER RPC.

A proposed migration file exists in the branch to enforce some of these invariants, but this audit did not find evidence that it is deployed. Do not assume the proposal protects production.

## Client confirmation issue

After the RPC returns an accepted quote, the page changes its in-memory quote status to `accepted` and shipment status to `confirmed`, then calls `updateSelection()`. That function only re-evaluates the local objects; it does not re-read the quote and shipment from the database. The page therefore does not independently verify the final persisted state before presenting the success message.

**Required:** after RPC success, re-fetch the exact quote and shipment under the same organization filters, verify quote status `accepted` and shipment status `confirmed`, and only then show final success. If the re-read fails or differs, show a reconciliation warning and do not claim the transaction is fully confirmed.

## Required backend acceptance invariant

The server transaction must atomically lock and validate:

1. authenticated caller and active organization membership/access;
2. quote's customer organization equals shipment's customer organization and caller's authorized organization;
3. quote is sent, unexpired, positive-value and linked to a partner offer;
4. partner offer belongs to the same shipment and partner organization, is eligible and unexpired;
5. customer quote amount and currency exactly match the partner offer;
6. assignment is accepted for the same shipment + partner quote + partner organization;
7. partner organization remains approved/active, verified and compliant under current policy;
8. required partner capability remains active/verified for the shipment's route, mode and cargo, where applicable;
9. shipment remains quoted and has no conflicting accepted quote/assignment;
10. quote acceptance and shipment transition to confirmed occur atomically and idempotently.

Do not loosen existing permissions, bypass RLS, or rely on browser checks for authorization.

## Test matrix before closure

- [ ] Direct RPC call without accepted assignment is rejected.
- [ ] Assignment for a different partner quote is rejected.
- [ ] Assignment for a different shipment is rejected.
- [ ] Partner offer for another shipment is rejected.
- [ ] Quote/shipment customer organization mismatch is rejected.
- [ ] Amount mismatch is rejected.
- [ ] Currency mismatch is rejected.
- [ ] Expired quote and expired partner offer are rejected.
- [ ] Suspended/unverified/non-compliant partner is rejected.
- [ ] Revoked capability is rejected.
- [ ] Unauthorized organization member cannot accept.
- [ ] Concurrent acceptance of two competing quotes cannot confirm both.
- [ ] Successful acceptance produces exactly one accepted quote and one confirmed shipment with the matching assignment.
- [ ] Client re-reads authoritative persisted quote and shipment state after RPC success.
- [ ] Same successful acceptance retry returns a safe, consistent outcome or a clear already-accepted response.

## Safety boundary

This was a read-only production inspection. No SQL writes, quote acceptance, shipment transition, partner assignment, payment, customer data mutation, migration application, merge or deployment was performed. Staging has no migration parity; do not apply a proposed migration to production as a shortcut.

## Exit decision

**Step 3 is BLOCKED.** The UI preflight is useful but the currently deployed SECURITY DEFINER acceptance RPC does not enforce the required partner linkage/assignment invariants. Backend hardening, controlled staging verification and client authoritative re-read are mandatory before real customer quote acceptance can be treated as safe.
