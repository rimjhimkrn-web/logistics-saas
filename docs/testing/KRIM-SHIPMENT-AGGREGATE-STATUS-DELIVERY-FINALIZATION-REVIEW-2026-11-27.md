# KRIM Shipment Aggregate Status and Delivery Finalization Review — 2026-11-27

## Scope
Read-only review of Staging project `qrpcivhdxobiaofppbkl`. No DDL, data, permission, or production changes.

## Findings

### 1. Shipment status is an aggregate, not an exact-leg lifecycle
The inspected driver trip routine writes the exact linked leg to `in_transit`, but also promotes the shipment status from `dispatched` to `in_transit`. This is currently a one-way aggregate signal; it does not prove all legs in a route generation have started transit.

The internal dispatch routine writes shipment status `dispatched` while its tracking event is linked to the exact assignment leg. Multi-leg dispatch semantics therefore need an explicit aggregate rule: dispatching one leg must not imply that every leg or the entire route generation has dispatched.

### 2. Delivery finalization has a generation-mixing risk
`public.krim_internal_authorize_delivery(bigint,uuid)` validates the exact POD, assignment, shipment and leg, and for an active multi-leg plan checks the corresponding plan item. However, its final-completion predicate also requires that there be no shipment leg anywhere on the shipment with a status outside completed/delivered. That is shipment-wide and can mix historical/superseded route generations with the active plan.

The routine also counts completed materialized legs against the active plan's items, but the additional shipment-wide nonterminal-leg check is not generation-scoped. This must be reconciled before route-plan replacement is supported.

### 3. Generic shipment transition catalogue is empty
The Staging query of `public.krim_shipment_status_transitions` returned zero rows. The generic `krim_transition_shipment(bigint,text,text,jsonb)` routine therefore has no configured allowed transitions in this environment. Do not treat that generic routine as a functioning lifecycle path until its transition catalogue and authorization model are intentionally populated and tested.

### 4. Access boundary
The inspected internal dispatch and delivery authorization routines are SECURITY DEFINER with empty search_path and deny direct EXECUTE to anon/authenticated. This is a structural grant check only; it does not prove all external invocation paths.

## Required design before implementation
1. Define shipment aggregate semantics separately from route-generation and exact-leg status.
2. Scope final delivery completion to the active route generation and its exact plan-item-to-leg mapping; historical/superseded generations must remain immutable history and must not block or falsely complete the active generation.
3. Define behavior for a generation with partial dispatch, exceptions, cancelled legs, and approved route replacement.
4. Decide whether generic `krim_transition_shipment` is retired, configured, or replaced by narrowly scoped lifecycle commands.
5. Add transactional tests for one-leg dispatch in a multi-leg route, later-leg transit, final POD on active generation with historical legs present, superseded-generation isolation, duplicate POD authorization, and cross-tenant access.

## Status
No implementation was applied. Runtime tests remain blocked by the absence of shipment, leg, assignment, route-plan and POD fixtures. Phase 00 remains open. Production was not accessed.
