# KRIM Customer Journey — Step 10: Status Callers & Alternate Acceptance Surfaces

**Audit date:** 2026-11-13  
**Disposition:** **CRITICAL — multiple commercial lifecycle APIs and UI callers exist; one customer UI bypassed the canonical preflight. Acceptance controls are now paused in both customer interfaces on this branch.**

## Scope and method

- Inspected branch `website/global-launch-readiness` repository tree (1,617 paths; 483 shipment/quote/partner/dispatch/operations-related HTML/JS/TS/SQL files identified by filename).
- Reviewed the primary customer booking and quote pages, customer OS quote operations, operations partner-selection page, partner accepted-loads page, driver workspace and shipment status consumer.
- Queried live production Postgres function definitions for functions referencing `krim_transition_shipment` or direct `UPDATE ... krim_shipments` patterns.
- Queried live production EXECUTE privileges for commercial acceptance, award, response and dispatch functions.
- This is a focused inventory, not a complete static call graph of all 483 files or every external/Edge Function consumer.

## Finding 1 — alternate customer quote acceptance UI bypassed the primary preflight

The primary page `public/shipper/quote-comparison.html` performed a client-side preflight requiring:
- quote status `sent`, valid expiry, positive amount and partner quote link;
- matching partner assignment already `accepted`;
- shipment status `quoted`.

It then called `krim_accept_global_quote(bigint)`. The checks were client-side only and the live production RPC was previously found to lack the required linked partner quote, assignment, amount/currency and current partner eligibility checks. Direct RPC calls could bypass the page preflight.

A second customer-facing acceptance route existed in `public/customer-os/assets/quote-operations.js`, used by `public/customer-os/quotes-pricing/quote-acceptance.html`. It called the same RPC without requiring a matching accepted assignment or quoted shipment preflight. After any RPC response with `status='accepted'`, it showed success without re-reading the shipment and assignment. This was a contradictory, weaker acceptance surface.

**Branch correction:** both customer UI acceptance actions have been paused. The Customer OS button is disabled and its alternate RPC handler no longer sends acceptance. The shipper quote-comparison page keeps quote review and status display but does not enable or send acceptance. Users are told that acceptance is temporarily unavailable pending server-side hardening. This is a fail-closed UI safeguard, not a backend security fix.

Commits:
- `1079894e0129095c2e40f939237b4d5e28c8160c` — Customer OS alternate acceptance paused.
- `daca4197b6484ab2d9e64f1190779757e1359450` — primary quote-comparison acceptance paused.

## Finding 2 — live commercial APIs remain callable by authenticated users

Production privilege inspection returned:

| Function | anon | authenticated | service_role |
|---|---:|---:|---:|
| `krim_accept_global_quote(bigint)` | no | yes | yes |
| `krim_award_partner_quote(bigint)` | no | yes | yes |
| `krim_award_partner_quote_for_checkout(bigint,timestamptz)` | no | yes | yes |
| `krim_respond_to_partner_assignment(bigint,boolean,text)` | no | yes | yes |
| `krim_transition_shipment(bigint,text,text,jsonb)` | no | no | yes |
| `krim_dispatch_shipment(...)` | no | no | yes |

The most important risk is `krim_award_partner_quote_for_checkout`: it remains executable by `authenticated` and the prior Step 4/5 production definition inspection found it can create an offered assignment and mark the customer quote accepted before partner acceptance. Hiding checkout UI does not revoke this RPC. It is a separate award/finalization authority from `krim_award_partner_quote` and `krim_respond_to_partner_assignment`.

**Required backend remediation:** make the single canonical partner acceptance transaction the only authenticated finalization authority. Revoke or hard-disable legacy checkout award/acceptance APIs for authenticated callers only after dependent integrations are mapped and safe replacement behavior is verified. Keep service-role access only where justified and tightly controlled. Do not change grants on production as part of this audit.

## Finding 3 — other direct shipment status update paths exist

Production catalog inspection found functions in addition to `krim_transition_shipment` that directly update `krim_shipments`. Relevant examples include:
- `krim_internal.convert_commitment_to_shipment` — changes a draft shipment to confirmed.
- `krim_internal.execute_booking_shipment_conversion` and `krim_internal.create_quote_from_booking` — booking conversion/quote workflows that directly mutate shipment rows.
- `krim_award_partner_quote_for_checkout` — alternate commercial award path.
- `krim_driver_record_trip_event`, `krim_internal_start_shipment_transit`, `krim_internal_arrive_shipment` — execution milestones/transit lifecycle.
- `krim_internal_dispatch_assigned_shipment` and `krim_dispatch_shipment` — dispatch lifecycle.
- `krim_admin_review_delivery_pod`, `krim_internal_authorize_delivery`, `krim_internal_verify_delivery_pod` — delivery authorization paths.
- `krim_assign_driver_to_partner_shipment` / `krim_assign_shipment_leg` — assignment/leg operations.

The text-based catalogue query also returned false positives where a function references a shipment update for non-status fields or contains a related helper. Each function's actual UPDATE columns, grants, callers and trigger side effects must be reviewed before classifying it as a status writer. Direct UPDATE does not automatically bypass table triggers; it does bypass the central transition RPC's catalogue/permission checks unless its own function supplies equivalent checks.

**Required remediation:** classify each direct writer as (a) authorized lifecycle transition, (b) non-status shipment metadata update, or (c) obsolete/duplicate path. For status writers, either route through the central transition policy or prove equivalent authorization, state-transition, readiness and audit invariants. Do not mechanically replace every UPDATE with the generic transition RPC.

## Finding 4 — driver and partner execution consumers

- `app/driver/index.html` uses `krim_driver_record_trip_event` to record trip milestones. The UI reports returned assignment status and does not directly change shipment status.
- `public/partner/accepted-loads.html` uses `krim_respond_to_partner_assignment` for partner accept/reject and `krim_partner_reserve_shipment_leg_capacity` for confirmed capacity binding/reservation.
- `public/operations/partner-selection-assignment.html` supports customer-side partner award and partner-side response in one interface. Its award message correctly says the selected partner must still accept and execution is not yet confirmed.
- `public/customer-os/assets/shipment-operations.js` reads persisted shipment status history and milestones; it is a status consumer, not a status writer.
- `public/customer-os/assets/quote-operations.js` was the weak alternate quote acceptance caller and is now paused on this branch.

## Finding 5 — partner eligibility lifecycle inconsistency remains in partner inbox

The partner accepted-loads UI's eligibility filter accepts lifecycle values `active` and `verified`, but not `approved`. Other recently corrected partner workspaces now recognize `approved`. This can hide legitimate approved partners or deny their assignment actions in this one surface. It is a frontend consistency issue; the backend remains authoritative. Fix after confirming the live partner response function's accepted lifecycle set and all workspace policies.

## Required remediation order

1. Keep both customer quote acceptance UI actions paused until the server-side acceptance and assignment finalizer is deployed and verified.
2. Inspect and neutralize the authenticated `krim_award_partner_quote_for_checkout` legacy path; inventory dependencies first.
3. Complete a per-function status-writer map, including exact columns changed, EXECUTE privileges, caller surfaces and trigger behavior.
4. Reconcile all booking conversion flows with the partner-direct commercial model; do not allow unrelated legacy commitment conversion to silently create a confirmed shipment without partner-direct invariants.
5. Make partner acceptance the only finalization authority, atomically updating assignment, partner quote, customer quote, shipment and leg.
6. Align approved lifecycle eligibility across partner inbox UI and backend without weakening compliance/verification checks.
7. Preserve execution/dispatch readiness, capacity confirmation, POD verification, audit/history/event and customer-ownership controls.
8. Test with migration-parity staging and controlled synthetic records only after staging is provisioned. Current staging is empty.

## Safety boundary

Production inspection was read-only. The only code changes are two fail-closed UI changes on `website/global-launch-readiness`. No production data/function/trigger/grant changes, no test booking, no partner acceptance, no shipment transition, no payment, no migration application, no merge or deployment. PR #65 remains draft/unmerged/undeployed.

## Exit decision

**Step 10 complete.** Both customer UI acceptance surfaces are now paused on the working branch, but the production RPC remains callable by authenticated users and the legacy checkout award API remains callable. Therefore customer quote acceptance is **not yet secure in production**, and KRIM is **not ready for unrestricted commercial launch**.
