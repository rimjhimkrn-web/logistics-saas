# Gate C3.13 — Failed delivery, returns, reverse logistics, custody transfer and exception recovery

**Programme:** KRIM GLOBAL PLATFORM — AI QUALITY ASSURANCE, SIMULATION & RELIABILITY PROGRAMME  
**Gate:** Phase 00 / C3.13  
**Source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**QA branch:** `qa/phase-00-baseline-2026-11-25`  
**Review date:** 2026-11-25  
**Disposition:** **PARTIAL PASS / BLOCKED — NO-GO for autonomous return/redelivery, unverified custody handoff or operational exception SLA claims.**

## 1. Scope and method

Read-only review of driver failed-delivery and incident pages, customer return authorization RPCs, physical return receipt and independent QC functions, leg-to-leg custody transfer/acceptance functions and dispatch trigger, partner operational exception reporting, and Operations exception desk.

Reviewed:
- `app/driver/module-11-failed-delivery-returns.html`
- `app/driver/module-09-exceptions-incidents.html`
- `app/operations/exception-management.html`
- `app/warehouse/reverse-logistics.html`
- `public/customer-os/customer-services/returns-workflow.html`
- `public/warehouse/dispatch-handover.html`
- `supabase/migrations/20261115141945_leg_to_leg_custody_transfer_and_acceptance_gate.sql`
- `supabase/migrations/20261115151811_correct_custody_transfer_response_audit_fields.sql`
- `supabase/migrations/20261116023000_customer_shipment_return_authorisation.sql`
- `supabase/migrations/20261116024000_correct_return_final_leg_sequence_column.sql`
- `supabase/migrations/20261116025000_shipment_return_physical_receipt_and_independent_qc.sql`
- `supabase/migrations/20261124120000_krim_report_operational_exception.sql`

This is static source review only. No SQL, RPC, browser workflow, inventory mutation, custody transfer, return receipt, notification, shipment or exception record was created or changed. No Production or Staging data was accessed.

## 2. Positive source controls

1. Driver failed-delivery page explicitly does not authorize return or redelivery. It records an unsuccessful attempt as a driver exception through the driver-owned trip-event RPC and instructs drivers to follow authorized dispatch instructions.
2. Driver exception/incident reporting requires an authenticated driver, one active driver organization, real assignment selection, factual details and attestation. It does not fabricate demo assignments.
3. Partner operational exception RPC validates a fixed exception category/severity list and 20–1,000 character description, locks the shipment, resolves exactly one eligible partner assignment and rejects ambiguous assignment selection.
4. High/critical exceptions and cargo-damage/safety-security exceptions require evidence. The exception row is linked to the shipment leg, partner assignment and responsible partner organization, with audit event creation.
5. The partner exception RPC inserts in-app notifications for eligible partner, customer and operations recipients. This is evidence of this exception path only, not proof of a universal nine-workspace delivery/retry/acknowledgement pipeline.
6. Customer return request is permission-gated by customer shipment.update; it requires a reason, 1–100 structured item lines with positive quantities/units, references a completed/delivered leg or a delivered shipment, and resolves the responsible partner. It uses an advisory lock and rejects conflicting reuse of the return idempotency key for the checked request fields.
7. Partner return authorization/decline is separately permission-gated, records responder identity/time/reason and audit event, and rejects decisions after the request is no longer pending.
8. Physical return receipt requires an authorized return, an active independently approved facility, authorized partner warehouse operator, and exact reconciliation of the received item count against the authorized manifest. Received stock is created on quality hold and the return enters inspection_hold.
9. Independent QC requires a facility operator different from the receiving operator, a decision, reason, reviewer-owned private evidence object and idempotency key. It updates held inventory quality state and records an audit event.
10. Multi-partner custody transfer requires adjacent legs in the same active route plan, completed releasing leg with actual arrival, releasing-partner permission, receiving-partner accepted/active assignment, confirmed receiving-leg capacity, exact shipment cargo manifest quantity/unit reconciliation and uploader-owned private evidence.
11. Receiving partner must accept the custody transfer. A database trigger blocks a subsequent multi-leg leg from entering transit unless the immediately preceding leg's custody transfer is accepted by the correct releasing and receiving organizations.
12. Custody transfer and return receipt/QC tables are RLS-enabled, with direct table access revoked and scoped read policies/grants.

## 3. Findings and release risks

### P1 — Custody-transfer idempotency replay omits material payload fields
The custody-transfer creation function checks an existing idempotency key against shipment, from/to leg, cargo manifest, cargo condition and evidence path. It does not compare `seal_number` or `discrepancy_note`. Reusing the same key with changed seal/discrepancy details can return the original transfer as a successful replay rather than rejecting a conflicting payload.

**Impact:** Operational seal and discrepancy information may be silently lost or a caller may believe changed details were recorded. Include every semantically material request field in the idempotency comparison, normalize values consistently, and add conflicting-payload tests.

### P1 — Failed-delivery reporting is not a controlled delivery-state or recovery workflow
The driver page writes a generic `exception` trip event with a text prefix `FAILED_DELIVERY_ATTEMPT`. It expressly has no dedicated failed-delivery status transition, authorized return instruction RPC or return-leg creation contract. It does not establish a durable dispatch acknowledgement, attempt counter, retry window, recipient-contact evidence, exception owner, or escalation deadline.

**Impact:** A report may exist without a controlled operational decision or confirmed next action. Do not describe failed-delivery handling, redelivery scheduling or return-to-origin as automated/complete.

### P1 — Return request manifest is not proven against original shipped cargo/quantity
The customer return request validates each submitted item structurally and authorizes it against the shipment/partner, but the reviewed request function does not reconcile the proposed return manifest against original shipment cargo lines, delivered quantities, previously returned quantities or cumulative return limits.

**Impact:** Customer-authorized request can contain unsupported item descriptions/quantities. Add server-side linkage to original cargo IDs, enforce per-line delivered/returnable quantities, prevent over-return and duplicate returns, and preserve partial-return accounting.

### P1 — Return request idempotency comparison omits requested pickup time
On replay, the return request function compares shipment, leg, reason and item manifest but not `requested_pickup_at`. A retry with the same key and changed pickup time returns the original request as a replay without flagging the conflicting time.

**Impact:** User-visible pickup instructions may differ from persisted instructions. Include pickup timestamp and every other material request field in the replay equivalence check.

### P1 — Return physical receipt and QC evidence byte integrity is not established
Return receipt and quality-review functions check Storage owner/path, declared MIME and file size. The reviewed path does not establish byte-level file-type validation, malware scanning, content hash, immutable object version or tamper-evident evidence. A reviewer-owned path is not itself proof of the underlying evidence bytes.

**Impact:** Malformed or replaced evidence could support receipt/QC decisions. Apply quarantine, byte inspection, malware scanning, content hash and immutable version binding before allowing quality release.

### P2 — Custody handoff evidence does not prove receiving-party co-acknowledgement of physical condition
The releasing partner creates a manifest/condition/seal/discrepancy transfer with evidence; receiving partner accepts or rejects the transfer, and acceptance is required before next leg dispatch. The reviewed acceptance function records the receiving partner's decision but does not require receiving-party evidence or an independently signed condition/seal confirmation.

**Impact:** The workflow records acceptance of the transfer, but does not establish a dual-party signed handover record or independently prove physical cargo condition at the handoff point.

### P2 — Custody-transfer replay does not compare all transfer fields
In addition to seal/discrepancy omission, the replay check does not compare all request semantics and the transfer acceptance/rejection response's idempotency semantics rely on existing terminal state and actor/reason fields. Add explicit operation-level idempotency keys or full normalized payload equivalence for response decisions.

### P2 — Exception notification and escalation are incomplete
The partner exception function creates in-app notification rows for selected recipients. The broader notification system still lacks proof of generic outbox, external delivery receipt, retry/dead-letter, durable acknowledgement and fallback escalation across all nine workspaces. The Operations desk shows existing escalation records and acknowledgement UI, but its resolution path is explicitly paused pending verified closure controls. A notification row or read state is not an acknowledgement that a responder has taken ownership.

### P2 — Return lifecycle notifications and customer visibility are not proven
The reviewed return request/partner response/physical receipt/QC functions write audit events and statuses, but the reviewed migrations do not establish mandatory durable customer/partner/operations notification delivery for each lifecycle transition. Customer UI prepares a reverse shipment draft and correctly states that it does not approve a return, issue a refund or guarantee capacity. It is not a complete return lifecycle control tower.

### P2 — Warehouse return inventory and custody runtime integrity is untested
No staged negative tests verify cross-organization facility access, wrong facility, altered manifest, repeated receipt, duplicate inventory rows, receiver/reviewer identity separation, return quantity overage, custody route-plan mismatch, missing receiving capacity, stale accepted transfer, concurrent acceptance/dispatch or transaction rollback.

## 4. Required remediation before release

1. Make custody-transfer idempotency compare normalized seal number, discrepancy note, cargo manifest, condition, evidence object/version and all request fields. Reject any conflicting retry.
2. Build a dedicated failed-delivery workflow: attempt number, event time/location, reason taxonomy, recipient contact outcome, evidence, driver/assignment/leg tuple, dispatch owner, acknowledgement SLA and escalation/fallback. Keep return/redelivery as separately authorized actions.
3. Bind each return manifest line to the original shipment cargo line and enforce delivered/returnable quantity, cumulative returns, unit and partial-return constraints under row locks.
4. Include requested pickup time and every material field in return-request idempotency equivalence. Define whether pickup timestamps are advisory or partner-confirmed commitments.
5. Add private evidence quarantine, byte-level type validation, malware scanning, cryptographic content hash and immutable object-version references for custody, receipt and QC decisions.
6. Require a receiving-party handover confirmation of manifest, seal and observed condition, with discrepancy workflow and dual-party evidence/attestation where risk requires.
7. Implement mandatory lifecycle notifications for failed attempt, dispatch acknowledgement, return requested/authorized/declined, pickup scheduled, custody offered/accepted/rejected, physical receipt, inspection hold/release/reject and recovery escalation. Persist delivery attempts, acknowledgement separately from read state, retry/dead-letter and fallback owner. Keep marketing preferences separate from essential service alerts.
8. Complete the Operations exception resolution path with verified corrective action, evidence, closure permission, SLA timer, escalation owner and audit trail; no silent resolution.
9. Test tenant/role/facility isolation, exact manifest matching, idempotency, concurrency, partial return, QC independence, custody trigger enforcement, notification failure and transaction rollback in isolated Staging after environment parity/isolation gates pass.
10. Keep all live return/redelivery automation and claims about completed custody/exception recovery blocked until P1 issues are fixed and tests pass.

## 5. Verification matrix

| Check | Result | Evidence / limitation |
|---|---|---|
| Driver failed-attempt report | SOURCE PASS / PARTIAL | Authenticated driver writes exception trip event; no dedicated failure lifecycle. |
| Return/redelivery authorization separation | SOURCE PASS | Driver page explicitly disallows independent return/redelivery action. |
| Partner operational exception validation | SOURCE PASS | Category/severity/description validation; one eligible assignment; audit row. |
| High/critical/damage/safety evidence requirement | SOURCE PASS / PARTIAL | Evidence-required flag set; actual file integrity and review path not proven here. |
| Exception in-app notification creation | SOURCE PASS / PARTIAL | Recipient notification rows inserted; external delivery/ack/retry not proven. |
| Customer return authorization | SOURCE PASS / PARTIAL | Customer permission, reason, manifest structure, partner response and audit. |
| Return manifest vs original shipped cargo | BLOCKED | Original cargo/quantity reconciliation not established. |
| Return idempotency | SOURCE PARTIAL | Conflicting core fields rejected; requested pickup time omitted. |
| Physical receipt and facility authorization | SOURCE PASS | Authorized return, approved facility, partner warehouse operator and manifest count. |
| Independent return QC | SOURCE PASS / PARTIAL | Reviewer differs from receiver; private reviewer-owned evidence path; content integrity not established. |
| Custody transfer adjacency/route/capacity/manifest | SOURCE PASS | Active plan, adjacent legs, accepted receiving assignment, confirmed capacity, exact cargo quantity/unit. |
| Custody transfer idempotency | SOURCE PARTIAL | Seal/discrepancy omitted from payload comparison. |
| Receiving partner acceptance before next leg transit | SOURCE PASS | Trigger blocks transit absent accepted transfer for correct adjacent partners. |
| Dual-party physical handover proof | BLOCKED | Receiving-side evidence/condition co-acknowledgement not required. |
| Operations exception closure/SLA | BLOCKED | UI says resolution paused pending closure controls; automated SLA/fallback not proven. |
| Cross-tenant/role/facility negative tests | NOT TESTED | Requires isolated Staging parity and test identities. |
| Concurrency/retry/rollback/runtime tests | NOT TESTED | No database or browser tests run. |

## 6. Change and safety record

- No Production or Staging SQL, RPC, RLS, grant, table, row, account, secret, provider, deployment or Storage object was changed or invoked.
- No shipment, return, receipt, inventory row, QC review, custody transfer or exception was created or changed.
- No notification was sent.
- No driver/customer/partner was contacted.
- Documentation-only QA branch change.

**Gate C3.13 result: PARTIAL PASS / BLOCKED.** Keep autonomous failed-delivery recovery, redelivery/return booking, return inventory release, and unverified custody/exception closure claims on **NO-GO** until P1 manifest, idempotency, failure lifecycle and evidence-integrity issues are remediated and isolated Staging tests pass.
