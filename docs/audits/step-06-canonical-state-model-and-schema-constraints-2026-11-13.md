# KRIM Customer Journey — Step 6: Canonical State Model & Schema Constraints

**Audit date:** 2026-11-13  
**Disposition:** **DESIGN DECISION REQUIRED BEFORE SQL PATCH — current schema does not include a dedicated pending-partner-confirmation customer quote status.**

## Read-only production schema inspection

Inspected CHECK constraints, foreign keys and relevant columns for:

- `krim_quotes`
- `krim_partner_quotes`
- `krim_partner_opportunities`
- `krim_shipment_partner_assignments`
- `krim_shipments`
- `krim_shipment_legs`

### Current state constraints

- Customer quote status is restricted to `draft`, `sent`, `accepted`, `rejected`, `expired`, `cancelled`. There is no `pending_partner` or `awaiting_partner` status.
- Partner quote status supports `draft`, `submitted`, `under_review`, `shortlisted`, `accepted`, `rejected`, `withdrawn`, `expired`.
- Opportunity status supports `draft`, `open`, `shortlisted`, `awarded`, `cancelled`, `expired`.
- Assignment status supports `offered`, `accepted`, `rejected`, `cancelled`, `active`, `completed`, `failed`.
- Shipment status supports `draft`, `requested`, `quoted`, `confirmed`, `assigned`, `dispatched`, `in_transit`, `delivered`, `closed`, `cancelled`, `exception`.

### Relationship schema

- Customer quote has shipment_id, nullable customer_organization_id and nullable partner_quote_id.
- Partner quote has opportunity_id, shipment_id and partner_organization_id.
- Opportunity has shipment_id and customer_organization_id.
- Assignment has shipment_id, non-null shipment_leg_id, partner_organization_id and nullable partner_quote_id.
- Shipment leg has its own shipment_id, partner_organization_id and assignment_status.
- The inspected foreign keys do not by themselves guarantee the composite equality rules needed between quote, opportunity, partner, assignment and leg. Those must be asserted inside the SECURITY DEFINER transaction or represented by carefully designed composite constraints after checking existing data.

## Canonical state model recommendation

Do not invent a new status casually or reuse `accepted` to mean partner acceptance.

A lower-risk first implementation can use the existing statuses consistently:

| Business event | Partner quote | Assignment | Customer quote | Shipment |
|---|---|---|---|---|
| Partner submits offer | submitted | — | — | quoted |
| Customer selects offer | accepted/awarded | offered | sent | quoted |
| Partner accepts exact assignment | accepted | accepted | accepted | confirmed |
| Partner rejects offer | withdrawn | rejected | cancelled/expired as applicable | quoted |
| Customer cancels before partner acceptance | no longer eligible | cancelled | cancelled | quoted/requested per lifecycle policy |

In this model, customer quote status `sent` means the commercial offer has been presented and is awaiting partner confirmation; the customer has already selected it. The UI must explicitly label this state “Awaiting partner confirmation” so it is not confused with a quote the customer still needs to accept. A future schema change could add a dedicated `pending_partner` state, but that requires a full audit of every status constraint, RPC, trigger, view, dashboard, notification, report and client filter.

## Required implementation architecture

1. **Customer award RPC:** one transactional authority creates the assignment as `offered`, marks the selected partner offer/opportunity as awarded, and creates or updates exactly one customer quote as `sent`. It must not transition shipment to `confirmed`.
2. **Partner response RPC:** lock assignment, partner quote, opportunity, shipment, customer quote and linked leg in a consistent lock order. Assert exact equality of all foreign-key relationships and caller's partner organization. On acceptance, revalidate partner compliance/capability and exact amount/currency binding; update assignment, leg, customer quote and shipment atomically. On rejection, do not leave an accepted quote or confirmed shipment; reconcile customer quote/version/events and reopen the opportunity only after checking no conflicting active assignment exists.
3. **Single finalization authority:** make partner response the sole function that confirms the shipment and accepts the customer quote. The old customer acceptance RPC should become a compatibility function that safely rejects unsupported calls or delegate only after proving the exact assignment is already accepted; it must not be a second independent state-transition path.
4. **Legacy checkout RPC:** remove all live callers, then revoke authenticated EXECUTE through a reviewed migration after staging tests; or rewrite it as a pending-offer creator. It must never create an accepted customer quote before partner acceptance.
5. **Client:** display “Awaiting partner confirmation” after customer selection, show “Confirmed” only after partner acceptance, and re-read authoritative persisted state after both RPCs.

## Important schema detail

`krim_shipment_partner_assignments.shipment_leg_id` is NOT NULL. The award path currently tries to use the first existing shipment leg and passes that ID into the assignment insert. Before rewriting it, establish the invariant that a valid leg exists and belongs to the same shipment, or create a correctly configured pending leg first. Do not create a placeholder leg with fabricated transport mode or route details. A composite relationship between assignment (shipment_leg_id, shipment_id) and leg (id, shipment_id) is a possible integrity improvement, but existing data must be checked before adding it.

## Safe next steps

- Inspect all application callers and triggers/views on the PR branch, not just default-branch search results.
- Check existing live data for orphaned/mismatched assignment, quote, opportunity and shipment-leg relationships (read-only).
- Inspect every client/status consumer before selecting the existing `sent` state or proposing a new enum/check value.
- Build migration-parity staging before writing or applying the state-transition migration.
- Write SQL regression tests for each state transition, relationship mismatch, duplicate/concurrent action, rejection/re-award, cancellation, expiry and rollback.
- Keep the production launch gate closed until the full transaction is proven.

## Safety boundary

Read-only production schema inspection only. No table data was changed, no migrations/grants were applied, no customer/partner records or test transactions were created, and no merge/deployment occurred. Staging remains empty.

## Exit decision

**Step 6 is design-complete, implementation-blocked.** Existing schema can represent the intended pending state using customer quote `sent` plus assignment `offered`, provided the UI explicitly communicates that this is awaiting partner confirmation. This avoids a schema status expansion as the first patch, but still requires a full caller/consumer audit and migration-parity staging.
