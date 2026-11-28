# KRIM partner quote and driver acceptance caller trace — 2026-11-24

## Scope and result
Read-only source inspection on branch `feat/notification-recipient-resolver-draft-2026-11-24`. This trace verifies the direct browser caller for partner quote submission and driver assignment acceptance. It deliberately does not infer callers for the other reviewed RPCs.

## Verified direct callers

| User action | Browser file | RPC invoked | Input contract / confirmation |
|---|---|---|---|
| Partner submits a quote against an opportunity | `public/partner/submit-quote.html` | `public.krim_submit_partner_quote` | Sends opportunity ID, amount, currency code, validity timestamp and optional notes. The page checks the returned quote has an ID before treating submission as successful. |
| Driver accepts an assignment | `app/driver/module-03-assignment-acceptance.html` | `public.krim_driver_accept_assignment` | Sends assignment ID, requires server response status `accepted`, then re-reads the assignment scoped to the signed-in driver and verifies accepted status. |

## Important consequence for the parity audit
The driver acceptance page does **not** call `krim_respond_to_partner_assignment`. It calls the distinct `krim_driver_accept_assignment` RPC. Therefore the previously reviewed `krim_respond_to_partner_assignment` ACL/definition is not evidence that the browser driver acceptance action is ready. The actual `krim_driver_accept_assignment` function, its caller role, grants, tenant/assignment guards and tests must be audited separately.

The partner quote page does directly call `krim_submit_partner_quote`. The production-versus-staging authenticated EXECUTE mismatch for that RPC is therefore directly relevant to a real browser workflow. Do not change the staging grant until the full function authorization contract and intended account role are verified.

## Not yet established
This source pass does not establish direct callers for:
- `krim_award_partner_quote`
- `krim_list_dispatchable_drivers`
- `krim_respond_to_partner_assignment`
- `private.krim_partner_capability_covers_shipment`

Their callers may be in other pages, shared modules, Edge Functions or admin-only workflows. A repository-wide call graph and role-aware integration tests remain required.

## Required next checks
1. Inspect `krim_driver_accept_assignment` in production and staging: full definition, ACL, auth identity, active driver membership, exact assignment ownership, eligibility, vehicle/readiness, custody and audit behavior.
2. Inspect `krim_submit_partner_quote` in both environments: full control-flow comparison, membership/partner verification, opportunity state, capability/corridor coverage, currency, validity, idempotency and duplicate submission behavior.
3. Add isolated positive and negative SQL tests for both actual browser RPCs, including cross-tenant denial and invalid lifecycle states.
4. Keep production untouched. Only apply a staging correction after source-history reconciliation and test proof.

## Change boundary
No code, SQL, ACL, database data, migration ledger, or production/staging object was modified by this trace. This is a source-level caller evidence document, not a release sign-off.
