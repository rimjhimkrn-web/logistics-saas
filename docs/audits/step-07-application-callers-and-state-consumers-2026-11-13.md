# KRIM Customer Journey — Step 7: Application Callers & State Consumers

**Audit date:** 2026-11-13  
**Disposition:** **BLOCKED — multiple customer-facing quote acceptance surfaces remain; do not implement finalization migration until they are reconciled.**

## Branch inspected

Inspected branch `website/global-launch-readiness` at commit `634cc86c91db1eb5aa3fad57650c5d342626fab7`. This was a branch-specific file/tree inspection, not a default-branch-only code search.

## Confirmed application callers

### 1. Canonical shipper quote comparison

File: `public/shipper/quote-comparison.html`

- Loads quotes scoped to the shipment and customer organization.
- Shows the accept action only for a `sent`, unexpired, positive-value quote linked to a partner quote.
- Performs a client-side preflight requiring the latest matching partner assignment to be `accepted` and shipment to remain `quoted`.
- Calls `krim_accept_global_quote(p_quote_id)`.
- Re-reads quote, shipment and assignment after the RPC and checks persisted state.

This client-side gate is useful UX, but not a security boundary. The server RPC remains authoritative.

### 2. Customer OS quote details / acceptance surface

Files:
- `public/customer-os/assets/quote-operations.js`
- `public/customer-os/quotes-pricing/quote-acceptance.html` (page uses the shared script)

The shared script:
- Loads customer quotes and shipment details scoped to active customer organizations.
- In acceptance view, enables the action for a quote that is not accepted/expired, has positive amount and a readable shipment.
- Does not require an accepted partner assignment in its client preflight.
- Calls the same `krim_accept_global_quote(p_quote_id)` RPC.
- Displays “Accept quote securely” and then treats a successful RPC return of status `accepted` as success.

This surface is inconsistent with the proposed meaning of `sent` = customer has selected the partner and is awaiting partner confirmation. It can present a misleading customer action while the assignment is still only `offered`. The database guard in migration `20261111120000_secure_global_quote_acceptance_partner_assignment.sql` should reject premature acceptance, but this is still a misleading and confusing user journey. After partner acceptance, this page can act as a second finalization surface.

### 3. Partner assignment response

File: `public/partner/accepted-loads.html`

- Loads assignments visible to the authenticated partner organization.
- Allows response only for `offered` assignments assigned to the partner organization and before the deadline.
- Calls `krim_respond_to_partner_assignment(p_assignment_id,p_accept,p_reason)`.
- Verifies the returned assignment ID, status, shipment and partner organization.

This is the intended partner-response surface. It does not itself prove that customer quote acceptance and shipment confirmation are atomically synchronized; that remains a database function responsibility.

### 4. Operations award / assignment desk

File: `public/operations/partner-selection-assignment.html`

- Operations UI calls `krim_award_partner_quote(p_partner_quote_id)` to create the assignment.
- The same page can call `krim_respond_to_partner_assignment` for assignment response when the current user belongs to the selected partner organization.
- It verifies returned assignment and relationship IDs before showing the award/response as confirmed.

This is a dual-purpose operations surface; its UI checks do not replace server-side relationship and permission guards.

### 5. Partner quote submission

File: `public/partner/submit-quote.html`

- Reads open opportunities and submits partner quote records through the partner quote workflow.
- No direct customer acceptance RPC caller was identified in this page inspection.

## Migration interaction

Branch contains:
- `supabase/migrations/20261111120000_secure_global_quote_acceptance_partner_assignment.sql`
- `supabase/migrations/20261113130000_revalidate_partner_eligibility_on_customer_quote_acceptance.sql`

The first migration adds server-side requirements that a linked partner quote exist, match the shipment, be valid, match amount/currency, and have an accepted assignment before `krim_accept_global_quote` can accept the customer quote and confirm the shipment. The second revalidates partner organization and capability eligibility at that RPC boundary.

These files are migration proposals in the branch; their presence in Git does not prove they were applied to production. Production migration history and function definitions must be reconciled separately.

## Required UI/state correction

If the selected design is `customer quote sent + assignment offered + shipment quoted` while waiting for the partner:

1. Change customer-facing acceptance view from “Accept quote” to a read-only “Awaiting partner confirmation” state when the exact linked assignment is `offered`.
2. Keep customer selection/award in the award workflow, not in a second post-award accept button.
3. If the exact assignment is `accepted`, show the saved confirmed state and direct partner payment instructions; do not offer a second customer acceptance action.
4. Retain the database guard as defense in depth; never rely on hiding buttons.
5. Ensure the canonical partner response RPC performs the atomic transition of assignment, leg, customer quote and shipment. The customer quote acceptance RPC must no longer independently finalize the same workflow; retire it or turn it into a strictly read-only/idempotent compatibility endpoint after all callers are migrated.
6. Audit every remaining route and shared script before removing any RPC grant. The current audit confirms these callers but is not yet an exhaustive repository-wide call graph.

## Next checks before implementation

- Inspect the full SQL definitions and exact migration history for both customer acceptance and partner response functions.
- Identify all triggers, views, notifications and status consumers that react to quote `accepted`, shipment `confirmed`, assignment `accepted`, and partner quote `accepted`.
- Inspect existing records read-only for inconsistent historical states before proposing constraints.
- Build migration-parity staging and run browser + RPC regression tests, including direct RPC calls that bypass the UI.
- Only then decide whether to keep `krim_accept_global_quote` as a compatibility wrapper or revoke authenticated execution.

## Safety boundary

No production data was changed, no migrations/grants were applied, no customer/partner records were created, no assignment was awarded/responded to, and no quote or shipment was accepted/confirmed. No merge or deployment occurred. Staging remains empty.

## Exit decision

**Step 7 is complete as a caller/state-consumer discovery pass, not as an exhaustive repository-wide call graph.** The Customer OS acceptance surface is a confirmed conflicting UX path and must be corrected before finalization logic is changed.
