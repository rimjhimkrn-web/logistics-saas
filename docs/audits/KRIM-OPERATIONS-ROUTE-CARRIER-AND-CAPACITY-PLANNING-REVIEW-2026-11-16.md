# KRIM Operations Route Planning, Carrier Coordination and Capacity Planning Review — 2026-11-16

## Scope
Static source review of:
- `app/operations/route-planning.html`
- `app/operations/carrier-coordination.html`
- `app/operations/capacity-planning.html`

Read-only production findings from the previously recorded operational RPC review were considered. No production business RPCs were invoked and no shipment, route, assignment, capacity reservation or dispatch record was created or changed during this review.

## Route & Lane Planning
**Status: Draft workflow available; activation intentionally blocked.**
- The page reads authorised shipment and reference data, creates versioned draft plans, evaluates plans, and previously exposed an activation action.
- Existing operational RPC review found that `krim_evaluate_shipment_leg_plan` does not establish all required market activation, approved corridor dossier/control and customs/regulatory clearance gates. The activation RPC trusts that evaluator.
- This is a critical prerequisite gap for creating physical shipment-leg records. A successful structural route evaluation must not be represented as global operational eligibility.
- **Correction:** removed the activation RPC call from this page and disabled the activation control. The page now explains that activation remains blocked pending verified backend enforcement of market, corridor, customs and compliance prerequisites.
- Draft creation and evaluation remain distinct from activation, partner assignment, capacity reservation and dispatch.

## Carrier Coordination
**Status: preparation-only placeholder.**
- Authenticates the user and checks for at least one active organization membership.
- Does not load carrier assignment, handoff, partner confirmation or shipment data.
- The form is browser-only and does not save or coordinate a real carrier handoff.
- The page correctly warns against representing a carrier as connected or assigned without source evidence, but must not be counted as an operational carrier coordination workflow.

## Capacity & Network Planning
**Status: preparation-only placeholder.**
- Authenticates the user and checks for at least one active organization membership.
- Does not read capacity resources, lane availability, partner/facility capacity or reservations.
- The form is browser-only and does not save or reserve capacity.
- Capacity must continue to be treated as unavailable unless verified capacity source records and authorized reservation workflows exist.

## Changes
- `588864c57beae2e9f6fee5dcc647b3e8eb2344de` — route-plan activation is blocked in the page until the missing backend global-control gates are enforced and verified.

## Verification
- Source change committed. GitHub static-link audit, production smoke checks and Pages deployment are triggered by the commit; final results must be checked before this batch is declared green.
- No live route-plan activation or other production business operation was executed.
- No claim is made that carrier coordination or capacity planning is operational.

## Required follow-up
1. After full migration-history reconciliation, implement and test a fail-closed backend evaluator for active market, current approved corridor dossier and controls, approved country operating packs, customs/regulatory clearance and route/partner capability.
2. Make activation independently re-check those gates transactionally; do not trust a prior UI evaluation.
3. Build carrier coordination from verified assignment and handoff source records with fine-grained permissions and audit events.
4. Build capacity planning from real capacity resource records and idempotent reservations that account for shipment reservations and cancellations.
5. Test organization isolation, unauthorized roles, stale evidence, expired approvals, race conditions and idempotent retries in staging before enabling production execution.
