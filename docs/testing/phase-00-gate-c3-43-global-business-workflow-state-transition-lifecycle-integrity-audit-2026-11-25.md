# C3.43 — Global business workflow, state transition and lifecycle integrity audit

Date: 2026-11-25  
Repository: rimjhimkrn-web/logistics-saas  
Environment: immutable source baseline `72d75a18f985ceb09e468839435ee95700e11e46`  
QA branch: `qa/phase-00-baseline-2026-11-25`  
Method: read-only source inspection; no deployed workflow execution.

## Scope and evidence inspected

Selected source-level lifecycle controls:
- `supabase/migrations/20261116013000_enforce_leg_sourcing_state_and_assignment_binding.sql` (blob `a96d88d8ca6f6272fe65277ff4b6c1dfac29e855`).
- `supabase/migrations/20261116014000_harden_exact_leg_partner_assignment_acceptance.sql` (blob `4806b498ed64cedf165b892d1f23c4bcf8e38fbe`).
- `supabase/migrations/20261116025000_shipment_return_physical_receipt_and_independent_qc.sql` (blob `e0bc1bd34f00b2a256d2d934b546a2db55f43053`).
- `supabase/migrations/20261116028000_require_warehouse_handover_before_leg_dispatch.sql` (blob `4027d7893a77199417549bc83ff91c8ea90b2f0d`).
- `app/enterprise/shipments.html` (blob `29d31f23869a5fd2759c7ec1490816b83741d3fd`).
- `app/driver/module-06-shipment-milestones.html` (blob `fb25e9bce53f7c1c617bbde0913fb7f772e3ba18`).
- Prior Phase 00 register sections 64–67 (C3.39–C3.42).

This is a selected-source review, not an exhaustive state machine or deployed database audit.

## Positive controls — PARTIAL PASS

1. **Leg sourcing binding:** trigger logic binds leg-scoped opportunity, quote and offered assignment to the same shipment and exact plan-linked leg; checks active plan item sequence, origin, destination and mode.
2. **Assignment acceptance:** selected acceptance function replacement validates shipment/partner equality, exact leg and awarded opportunity for multi-leg plans, and current verified/compliant registered-business partner status.
3. **Return receipt:** selected workflow uses a locked return row, authorized-only physical receipt, facility/operator checks, bounded 1–100 item payload, idempotency key, conflict replay rejection and independent quality-review records.
4. **Dispatch authorization:** selected trigger requires completed exact-leg warehouse handover, picked allocations, no remaining reserved allocations, private dispatch proof with owner/path/MIME/size checks; current authorization also binds assignment, partner, capacity reservation, active route plan and preceding-leg custody.
5. **Client surfaces:** Enterprise shipment register and driver milestone pages exist, but source presence does not prove persisted state, authorization, UI/API agreement or complete journey execution.

## P0 — Canonical lifecycle authority and transition coverage remain unresolved

C3.39 documented coexistence of canonical `krim_shipments` and legacy `shipment_requests`, including Enterprise fallback to legacy data on canonical query error. The resulting source-of-truth ambiguity can make the same business shipment appear in inconsistent states across workspaces. No complete immutable crosswalk or single-authority acceptance proof was available in this gate.

**Required:** designate one canonical shipment authority; explicit legacy read/write policy and crosswalk; fail closed on canonical query errors; reconcile all dependent shipment, quote, leg, assignment, dispatch, custody, POD and finance references before enabling live operations.

## P0 — End-to-end lifecycle state machine is not proven

Selected migrations implement meaningful guards, but no exhaustive transition matrix was found that proves every permitted and forbidden transition across:
- partner discovery → verification → compliance → capability approval → opportunity → quote → award → assignment;
- shipment request → validation → quote → acceptance → leg plan → capacity reservation → dispatch authorization;
- pickup → milestone/tracking → exception → custody handover → delivery/POD → returns;
- warehouse receipt → QC → inventory allocation/reservation/pick → dispatch handover;
- customs case/broker/document/review/clearance;
- invoice → payment confirmation → ledger posting → refund/reversal → partner settlement/reconciliation.

The source inspection cannot establish that all direct table writes, legacy RPCs, admin paths, triggers, background jobs and workspace callers obey one transition graph. Existing P0s from C3.39/C3.42 remain material: warehouse reserved-stock bypass; captured Razorpay webhook bypass of freight collection control; customs evaluator potentially returning clear with zero checks; legacy privileged dispatch path concerns; unresolved financial posting/settlement contradictions.

**Required:** authoritative state/transition catalogue with actor, permission, precondition, exact parent/tenant binding, side effects, idempotency, audit event, rollback/compensation and terminal-state rules; prove every write path is mediated by the same guard.

## P1 — Exact-leg and replay protection coverage is selective

The selected leg guard explicitly returns without further leg-plan checks when the incoming row has a null `shipment_leg_id`. Other controls may cover shipment-wide or multi-leg cases, but this source slice does not prove that null-leg paths are impossible or safely rejected in every multi-leg workflow. The trigger's strongest assignment linkage is scoped to offered assignments; subsequent acceptance relies on the separately inspected RPC. Runtime proof that direct updates cannot bypass the RPC is absent.

**Required:** negative tests for null/mismatched leg IDs, inactive/replaced route plans, stale quote/opportunity, partner substitution, direct DML, duplicate and conflicting replay, concurrent acceptance and terminal-state mutation.

## P1 — Custody, driver, POD and exception transitions not end-to-end verified

Dispatch authorization checks a preceding-leg accepted custody transfer for later legs, which is a useful source-level safeguard. However, no synthetic chain proved the complete sender handoff → receiver acceptance → driver assignment → milestone sequence → exception resolution → POD verification → final shipment completion path. A UI milestone page is not evidence of an authorized transition or trusted GPS/POD provenance.

**Required:** two-partner multi-leg synthetic journey, driver/vehicle identity and consent, monotonic event ordering, event-time vs server-time handling, proof ownership, short-lived authorized evidence access, rejected/late/duplicate milestones and exception reopen/close rules.

## P1 — Warehouse and return lifecycle needs concurrency and segregation proof

Return receipt uses a row lock and idempotency controls and creates a distinct quality-review record. Dispatch handover requires picked allocations and private evidence. Nevertheless, no concurrent reservation/receipt/pick/transfer/return test or independent reviewer identity test was executed. C3.39's reserved-stock bypass remains open and prevents relying on selected newer controls as a global inventory invariant.

**Required:** concurrent oversell/reservation tests; exact quantity/unit/lot reconciliation; receipt and return manifest mismatch; creator-versus-reviewer separation; replay with changed payload; evidence deletion/revocation; transfer and pick interactions with outstanding reservations.

## P1 — Finance and customs terminal states are not tied to independently verified outcomes

A shipment's delivery, invoice, payment, refund and partner-settlement states must not be treated as equivalent. Prior snapshots record unresolved paid-vs-empty ledger/settlement contradictions and webhook processing risk. Customs clearance must not be inferred from a UI label or an empty checklist. This gate did not inspect live provider/bank records or execute terminal transitions.

**Required:** explicit state separation for payment authorization/capture/settlement/refund/reversal and bank payout; balanced double-entry posting and idempotent compensations; customs jurisdiction/checklist completeness, reviewer authority, evidence provenance and fail-closed zero-check behavior.

## Acceptance tests required before lifecycle sign-off

- Exhaustive transition table for all nine ecosystems, every RPC/table/trigger/Edge Function/job and legacy route.
- State invariant/property tests: tenant/parent/leg/partner identity, monotonic progression, terminal-state immutability, valid predecessor, no skipped mandatory checks.
- Synthetic positive and negative tests for every transition, including stale version, replay, concurrency, timeout and partial failure.
- Two-tenant and two-partner multi-leg journey with custody, driver, warehouse, customs and POD evidence.
- Financial reconciliation against sandbox provider events and a balanced ledger; no real funds.
- Controlled notification sink and verified event/outbox lifecycle.
- Immutable audit/event trail with actor, tenant, source, correlation/idempotency IDs and server timestamps.
- Independent retest of all P0 findings from C3.25, C3.28, C3.30, C3.39 and C3.42.

## Gate disposition

| Area | Status |
|---|---|
| Selected exact-leg sourcing and assignment guards | PARTIAL PASS |
| Selected return receipt and independent QC source controls | PARTIAL PASS |
| Selected dispatch handover and custody preconditions | PARTIAL PASS |
| Complete canonical shipment lifecycle | FAIL / BLOCKED |
| Nine-ecosystem transition coverage | NOT TESTED |
| Runtime concurrency, replay and tenant-isolation transitions | NOT TESTED |
| Finance/customs terminal-state verification | FAIL / BLOCKED |
| Overall C3.43 | **FAIL / BLOCKED** |

**NO-GO:** production shipment lifecycle execution, automated dispatch, warehouse inventory movement, customs clearance, payment collection/settlement, partner payout and full operational onboarding remain blocked by the previously identified P0 risks and missing runtime evidence. Non-binding partner discovery and internal development may continue with accurate disclosure; do not promise an unverified route, service, rate, capacity or SLA.

**Safety:** No Production/Staging SQL, RPC, Auth, Storage, Edge Function, provider, webhook, bank, inventory or shipment operation was performed. No secrets were read. No deployment, merge or customer/partner communication was performed.
