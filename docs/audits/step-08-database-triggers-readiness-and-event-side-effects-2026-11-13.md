# KRIM Customer Journey — Step 8: Triggers, Readiness Gates & Event Side Effects

**Audit date:** 2026-11-13  
**Disposition:** **CRITICAL BLOCKER — current shipment confirmation readiness gate is incompatible with the partner-direct, no-KRIM-freight-payment launch model.**

## Scope

Read-only production inspection of non-internal triggers attached to:
- `krim_quotes`
- `krim_partner_quotes`
- `krim_partner_opportunities`
- `krim_shipment_partner_assignments`
- `krim_shipments`
- `krim_shipment_legs`

Inspected the trigger functions for partner rejection, initial shipment leg creation, assignment integrity, capacity commitment, shipment readiness enforcement, shipment status events, and operational snapshots. Also inspected the live shipment readiness evaluator.

## Finding 1 — confirmed shipment requires KRIM-recognized payment

The live trigger `krim_shipment_readiness_enforcement` runs before shipment status changes to `confirmed`, `assigned` or `dispatched`. It calls `krim_internal_evaluate_shipment_readiness`.

The evaluator currently marks payment as:
- `not_required` only while shipment is `draft` or `requested`;
- `paid` only if a `payments` row is `paid`, or a completed Razorpay company-owned credit exists in `krim_financial_transactions`;
- otherwise `missing`, adding `verified_payment_missing`.

For a `quoted` shipment, payment is therefore required before it can transition to `confirmed`. The evaluator returns `blocked` when payment is missing, and the BEFORE trigger rejects the transition unless readiness is exactly `ready`.

This conflicts with KRIM's chosen initial commercial model: customer pays the logistics partner directly; KRIM does not collect or settle freight charges. The partner-direct flow must not be forced through a KRIM-owned Razorpay payment record. The current award RPC's attempted `quoted` → `confirmed` transition is therefore likely to fail for a partner-direct transaction unless a legitimate supported payment-evidence path already exists. This needs controlled staging proof; do not test against a real production shipment.

**Required decision:** distinguish *commercial booking confirmation* (customer selected partner and partner accepted) from *dispatch/execution readiness*. Partner acceptance should be sufficient for the booking confirmation state if legal/operational policy says so. Payment evidence, compliance, documents, customs and operational readiness should remain explicit gates for dispatch or the appropriate later state. Do not weaken all readiness controls or fabricate payment records.

## Finding 2 — partner rejection trigger does not reconcile the proposed pending quote state

Trigger `trg_krim_cancel_customer_quote_after_partner_rejection` runs when an assignment changes from `offered` to `rejected`.

It only searches for and cancels a customer quote where:
- `partner_quote_id` matches the rejected assignment; and
- customer quote status is already `accepted`.

It then cancels the latest accepted quote version and inserts a quote event.

Under the proposed state model, customer quote remains `sent` while assignment is `offered` (meaning “Awaiting partner confirmation”). If the partner rejects, this trigger does **not** cancel or expire that `sent` quote. The current partner-response RPC also withdraws the selected partner quote and reopens the opportunity, but it does not itself reconcile that pending customer quote. The UI may therefore continue to show a stale `sent` quote for an offer that has been withdrawn.

**Required correction:** rejection/expiry must reconcile the exact customer quote and any active quote version for both the legacy accepted state and the new pending/sent state, append an auditable quote event, and only reopen the opportunity after ensuring no other live assignment/selected offer conflicts. A sent quote should not be cancelled by a generic broad update; match the exact quote, shipment, partner quote and customer organization.

## Finding 3 — shipment leg creation is conditional, not guaranteed

Trigger `trg_krim_ensure_initial_shipment_leg` runs after shipment insert or updates to requested transport mode/origin/destination. It creates a first leg only when:
- requested mode maps to an active configured mode;
- origin and destination location IDs are present and differ;
- shipment status is `draft` or `quoted`;
- no leg already exists.

It intentionally does not fabricate a leg for multimodal/specialist services and returns without creating one when the transport mode is not configured. The award RPC selects the first leg and inserts an assignment with that ID, while assignment schema requires `shipment_leg_id` non-null. Therefore some otherwise valid enquiries can fail to award if a valid route leg was not created. This must be handled explicitly by the award workflow, with no inferred/fabricated route.

A separate acceptance fallback in `krim_respond_to_partner_assignment` attempts to create a leg if none exists, but it uses service-tier defaults (AIR or ROAD) and shipment origin/destination. That fallback must not be relied on to invent a transport mode or route; it should be reconciled with the verified partner quote and actual requested mode.

## Finding 4 — assignment relationship guard exists

The live BEFORE trigger `trg_krim_partner_assignment_quote_integrity` enforces:
- assignment must have a partner quote;
- partner quote exists;
- opportunity exists;
- partner quote shipment equals assignment shipment;
- opportunity shipment equals assignment shipment;
- partner quote partner organization equals assignment partner organization;
- if shipment_leg_id is non-null, it belongs to the same shipment.

This is useful defense in depth. It does not itself validate opportunity customer organization against shipment customer organization, nor quote amount/currency equality or current partner eligibility. Those checks remain transaction-level requirements.

## Finding 5 — acceptance triggers enforce capacity commitment

`trg_krim_ensure_assignment_capacity_commitment` runs after assignment transitions to `accepted`. It requires positive shipment weight, linked matching partner quote, and a current committed capacity record with sufficient quantity and matching partner. If it fails, the assignment acceptance transaction rolls back.

The atomic finalization design must account for this trigger. It must not update assignment status and then assume success without allowing this trigger to complete. Capacity commitment, quote acceptance, shipment confirmation and leg updates must remain in one transaction.

## Finding 6 — status and audit side effects

Shipment status changes emit:
- `krim_events` row `shipment.status_changed` (pending processing);
- shipment status audit event;
- shipment status history row;
- operational snapshot refresh;
- capacity release on terminal states.

Assignment changes emit assignment audit events and may create/release capacity commitments.

Shipment-leg creation currently has two AFTER INSERT triggers, `trg_krim_shipment_leg_audit` and `trg_krim_shipment_leg_creation_audit`, both calling `krim_log_shipment_leg_creation()`. This appears to create duplicate shipment-leg audit events for one insert. Verify intended history and remove only after confirming migration history and downstream consumers.

## Views and downstream consumers

The catalog query found no ordinary views in the public schema whose stored definitions directly reference the six core workflow tables. This does not exclude materialized views, functions, edge functions, queued event processors, external consumers, or application-side reads. This pass is not an exhaustive event-consumer inventory.

## Required remediation order

1. Resolve booking-confirmation vs dispatch-readiness semantics for partner-direct payments. Preserve payment/compliance/document/customs gates for the proper lifecycle stage.
2. Rewrite partner award so it creates an `offered` assignment and leaves shipment `quoted`; do not transition to `confirmed` at award time.
3. Rewrite partner acceptance as the single atomic finalizer, but only after a dedicated booking-confirmation transition path is designed that does not incorrectly require KRIM freight payment.
4. Extend rejection/expiry reconciliation to the pending `sent` customer quote and its active version.
5. Validate or safely create a real shipment leg from the selected verified quote and actual shipment mode; fail closed for unsupported/multimodal cases until route legs are configured.
6. Preserve capacity commitment trigger and ensure failure rolls back all lifecycle changes.
7. Inspect duplicate leg audit trigger history and event processors before changing triggers.
8. Build migration-parity staging and run end-to-end, concurrency, retry, expiry, rejection/re-award and direct-RPC tests.

## Safety boundary

Read-only production catalog/function inspection only. No production data writes, test bookings, assignment responses, quote acceptances, shipment transitions, trigger changes, migrations, grants, merge or deployment. Staging remains empty.

## Exit decision

**Step 8 complete; implementation remains blocked.** The payment readiness rule is a critical incompatibility with the approved partner-direct model. Do not implement the finalization migration until this semantic conflict is resolved and proven in staging.
