# Phase 00 — Gate C3.39: Global Data Integrity, Consistency, Migration & Cross-System Reconciliation

**Date:** 25 November 2026  
**Baseline:** immutable source commit `72d75a18f985ceb09e468839435ee95700e11e46`  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Method:** read-only review of immutable-baseline source and prior dated PostgreSQL/catalog audits, migration collision inventories, shipment lifecycle, commercial, warehouse, finance, customs, dispatch and enterprise findings. No live SQL, DML, RPC, migration, reconciliation job or data repair was executed.

## Executive decision

**C3.39 FAIL / BLOCKED — NO-GO for production data migration, bulk cleanup, financial reconciliation, unrestricted cross-workspace operations or live shipment execution.**

KRIM has a meaningful relational foundation: the 16 November catalog audit recorded 547 validated public foreign keys and 673 unique indexes. That is positive structural evidence, not proof of semantic business consistency. The reviewed ecosystem still has canonical/legacy data models, materially unreconciled migration history, exact-parent/tenant invariants not uniformly enforced, historical payment/ledger contradictions, missing operational evidence, and workflow-specific integrity defects. Several production snapshots are low-volume and dated; they cannot establish today's exact state or prove full lifecycle consistency.

## 1. Evidence baseline and limits

### 1.1 Relational catalog (historical 16 November read-only audit)

The prior global data-integrity audit recorded:
- 547 public foreign-key constraints; all 547 validated;
- 673 public unique indexes;
- no unvalidated public foreign-key constraints.

The same audit warned that a declared FK only proves the referenced row exists. It does not prove the shipment, leg, partner, organization, capability, capacity, evidence or business purpose is the correct one. An earlier FK-index coverage query was not sufficiently reliable for composite-key classification; no missing-index defect is asserted from that preliminary result.

Historical PostgreSQL table statistics estimated 18 shipments, one shipment leg, seven quotes, three partner opportunities, one partner capability, one partner verification case, 41 shipment status-history rows, two milestones and one tracking event. These are `pg_stat_user_tables.n_live_tup` estimates, not exact counts or current measurements. Operational warehouse and several CRM/finance/claims tables were zero or near-zero in that dated snapshot.

### 1.2 Migration history and repository identity

The 24 November migration reconciliation recorded 561 Production migration ledger versions versus 368 repository SQL files / 353 unique repository versions; 82 exact version matches; 479 Production versions without same-version repository files; 286 repository versions absent from the Production ledger; 13 duplicate-version groups; and 209 same-name/different-version mappings. The 24 November collision content review found all 13 duplicate-version groups contained distinct SQL files (26 files, all different Git blob identities). A separate duplicate timestamp review found substantive migrations in collision groups affecting driver identity/invitations, market activation, corridor compliance, partner capability, warehouse, customs, dispatch and vehicle lifecycle.

A separate 24 November migration-history reconciliation cited 561 ledger entries and 368 repository SQL files; C3.31 had an earlier report snapshot with different counts (422 ledger entries vs 257 visible files / 358 unmatched). These counts come from different dated audit runs and must not be merged as if they were one simultaneous measurement. The exact authoritative production migration state must be refreshed and reconciled before any schema action.

**P0:** migration provenance/order is unresolved. Never replay, rename, concatenate, delete, renumber or baseline colliding migrations merely to make counts align. A file's presence or matching catalog object does not prove that exact migration file ran.

## 2. Critical cross-system integrity findings

### P0 — Canonical and legacy shipment authorities coexist

The repository contains canonical `krim_shipments` and legacy `shipment_requests` references. C1 identified Enterprise mixed-model usage; C3.27 found the Enterprise canonical home can silently fall back to legacy `shipment_requests` when the canonical query errors. C3.29 confirmed the coexistence can create ambiguous authority and inconsistent workspace views.

**Risk:** the same business shipment may be read from different authorities or error paths may silently present legacy records as canonical. Status, ownership, mode, quote and event history can diverge.

**Required:** declare one canonical source of truth; define a reviewed, immutable crosswalk for legacy identifiers; make canonical query errors visible and fail closed rather than silently substituting a different dataset; establish reconciliation for duplicate, missing and conflicting records; retire legacy reads only after verified migration and consumer inventory.

### P0 — Migration collisions prevent safe schema/data reconciliation

The distinct SQL files sharing 13 timestamps create unresolved ordering and provenance. The Production ledger includes renamed/re-timestamped entries and repository-only files. Matching index/function effects cannot establish the full sequence or exact SQL body.

**Required:** build a three-way ledger ↔ repository file ↔ live catalog crosswalk using version, name, Git blob/content hash, object identity and deployment ancestry. Classify each file as applied-equivalent, applied-divergent, superseded/no-op, unapplied, production-only or unresolved. Recover historical source where possible. Build a deterministic baseline in a disposable project; do not touch Production until reviewed and explicitly authorized.

### P0 — Semantic shipment/leg/assignment/capacity consistency is not proven

The historical FK audit specifically called out shipment_id consistency across leg-specific assignment, quote, opportunity and custody rows; exact-leg capacity binding; organization type; and same-tenant evidence ownership as application-level invariants. C3.26 found a legacy privileged dispatch path that can select the first assigned leg without current exact-leg authorization and full capacity/driver readiness. C3.29 found inconsistent workspace action/role contracts. C3.36 found driver-to-partner POD exact-leg mismatch concerns.

**Required:** enforce composite parent relationships (shipment_id + leg_id + organization/partner identity) at the database boundary where appropriate; use one canonical server-side authorization helper; reconcile every quote, assignment, capacity reservation, dispatch, custody, driver and POD tuple; reject cross-leg and cross-tenant references. Do not rely on matching individual UUID foreign keys alone.

### P0 — Warehouse physical stock can diverge from reserved shipment commitments

C3.23 found transfer dispatch checks total on-hand stock without subtracting active shipment reservations; generic non-shipment-linked picking can potentially debit inventory below outstanding reservations. Return receipt/QC exact item-to-inventory mapping and replay actor binding also remain blocked.

**Required:** make every physical debit path use a single locked invariant: available = released on-hand minus active reservations and other holds. Bind picks, transfers, returns and shipment allocations to exact SKU/lot/facility/owner; require idempotent actor-bound receipts and exact line reconciliation before finalization. Verify with isolated synthetic concurrent tests before any real stock operations.

### P0 — Financial records contain unresolved cross-ledger contradictions

The historical 16 November finance audit recorded six payment orders, four legacy payment rows, ten webhook events, one company-owned financial transaction, one legacy revenue ledger row and one legacy shipment financial row marked customer paid/partner payout paid, while partner payable/settlement tables, ledger journals/entries, invoices and reconciliation runs were empty. Four captured/order-paid webhook events were unprocessed in that snapshot. The source review found the Razorpay captured webhook could bypass the freight-collection kill switch. These records do not prove actual provider settlement or partner payout.

**Required:** classify each historical payment/order/webhook/revenue/shipment-financial row as test, legacy, actual, duplicate or unresolved using authorised provider/bank evidence. Reconcile provider order/payment IDs, amount/currency, shipment/quote/assignment, company vs partner ownership, ledger journals and settlement evidence. Keep freight collection disabled; do not replay captured webhooks or create ledger corrections without explicit approval and a controlled evidence trail.

### P1 — Tenant and lifecycle invariants exceed declared foreign keys

The commercial lifecycle audit found authenticated direct DML on customer acquisition/service request lifecycle tables under organization-scoped ALL policies; this does not itself enforce the intended state machine or audit completeness. Enterprise group/legal-entity relationship and team membership authority are incomplete. Admin audit failures may be ignored after privileged mutations. Several operational relationships rely on RPC logic rather than composite constraints.

**Required:** use controlled transition RPCs for sensitive state changes; require organization membership and exact parent ownership on every mutation; make audit writes transactional or fail closed for critical actions; define one authority for role/membership and tenant scope; test cross-tenant read/write denial and state-transition invariants.

### P1 — Consent, evidence and event histories are not fully authoritative

Customer consent has historically been writable by authenticated clients under broad organization policies; signup acknowledgements can originate from editable metadata. Driver POD/evidence has unresolved exact-leg/reviewer binding and integrity requirements. Notification event creation is not proof of delivery; stale processing jobs can remain. A valid parent FK does not prove the evidence, reviewer, consent purpose/version, or event sequence is authentic and complete.

**Required:** immutable versioned consent and evidence provenance; exact organization/user/assignment/leg tuple checks; append-only event sequencing and actor attribution; verified object checksum/MIME/malware/retention; separate queued/provider-accepted/delivered/acknowledged states; reconcile missing and duplicate event sequences.

### P1 — Global market/corridor and customs controls can disagree with shipment data

C3.24 found a customs evaluator can return `clear` when zero checks exist and historical gate rows had no checker identity; C3.35 found market controls blocked, country packs pending, no approved corridor dossiers/legs and a shipment creation overload missing transport mode required by a trigger. Country/city coverage does not prove corridor authorization. These are data consistency and fail-closed problems, not merely missing catalogue rows.

**Required:** require non-empty applicable regulatory checks and authoritative release evidence; bind country pack, market, exact corridor, mode, service capability, dates and source validity to each shipment leg; reject incomplete or stale control sets. Do not manufacture approval rows or infer clearance from zero checks.

## 3. Cross-system reconciliation matrix

| Domain | Known integrity baseline | Disposition |
|---|---|---|
| Foreign keys/indexes | 547 validated FKs and 673 unique indexes in historical audit | PARTIAL PASS; semantic integrity not proven |
| Shipment authority | canonical and legacy models coexist; silent Enterprise fallback identified | FAIL / BLOCKED |
| Migration history | material ledger/repository mismatch; 13 distinct-content collision groups | FAIL / BLOCKED |
| Shipment/leg/assignment/capacity | exact tuple and legacy dispatch gaps | FAIL / BLOCKED |
| Warehouse stock | reservation bypass paths identified | FAIL / BLOCKED |
| Finance | provider/webhook/legacy ledger and payout contradictions | FAIL / BLOCKED |
| Tenant/lifecycle | direct DML and role/authority inconsistencies | FAIL / BLOCKED |
| Consent/evidence/events | provenance, immutability and delivery semantics incomplete | FAIL / BLOCKED |
| Customs/market/corridor | zero-check clear and incomplete activation/control data | FAIL / BLOCKED |
| Full synthetic reconciliation | no complete isolated cross-system suite evidenced | NOT TESTED |

## 4. Required synthetic reconciliation suite — NOT RUN

Only after a disposable isolated environment is proven, schema baseline is deterministic and synthetic identities are authorized:

1. Inventory every canonical and legacy business identifier; detect duplicate, missing and conflicting shipment/organization identities.
2. Validate every child tuple: shipment ↔ leg ↔ quote ↔ partner opportunity ↔ assignment ↔ capacity ↔ dispatch ↔ custody ↔ driver ↔ POD.
3. Validate organization/tenant ownership across memberships, roles, evidence, warehouse facilities, claims, finance and enterprise group relationships.
4. Reconcile inventory: on-hand, reserved, picked, transferred, returned, held and released quantities by SKU/lot/facility; test concurrent debits.
5. Reconcile financial records against synthetic provider events and a synthetic bank statement; test duplicate, out-of-order, conflicting and unknown outcomes without real funds.
6. Verify all migration file/ledger/catalog identities and construct a disposable deterministic schema baseline.
7. Validate market/country/corridor/mode/date/control source tuples and prove zero/missing checks fail closed.
8. Validate append-only audit/event sequences, evidence object hashes and consent versions.
9. Run negative cross-tenant and cross-leg tests; assert rejected writes create no partial downstream side effects.
10. Produce exact counts, bounded redacted samples, invariant results, orphan/duplicate/conflict reports, remediation owners and retest evidence.

All tests above remain NOT TESTED. No current production counts or live reconciliations were obtained in this gate.

## 5. Gate disposition

**Final verdict: C3.39 FAIL / BLOCKED.** No schema replay, bulk cleanup, data migration, legacy retirement, financial posting/reconciliation, inventory movement, customs clearance, dispatch or shipment execution is authorized by this audit. Limited internal development and non-binding partner discovery may continue with accurate disclosures.

## 6. Evidence references

- `docs/audits/KRIM-GLOBAL-DATA-INTEGRITY-FOREIGN-KEY-AND-CORE-RELATIONSHIP-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-PRODUCTION-FOREIGN-KEY-INDEX-COLLISION-CROSSCHECK-2026-11-16.md`
- `docs/audits/KRIM-DUPLICATE-TIMESTAMP-MIGRATION-CONTENT-REVIEW-2026-11-16.md`
- `docs/audits/KRIM-MIGRATION-COLLISION-CONTENT-REVIEW-2026-11-24.md`
- `docs/audits/KRIM-PRODUCTION-MIGRATION-HISTORY-RECONCILIATION-2026-11-24.md`
- `docs/audits/KRIM-WAREHOUSE-INVENTORY-RESERVATION-PICKING-TRANSFER-AND-RETURN-INTEGRITY-REVIEW-2026-11-16.md`
- `docs/audits/KRIM-FINANCIAL-INTEGRITY-LEDGER-INVOICING-RECONCILIATION-REFUNDS-AND-SETTLEMENT-BOUNDARY-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-SHIPMENT-LIFECYCLE-STATE-MACHINE-AND-EVENT-CONSISTENCY-P0-P1-AUDIT-2026-11-16.md`
- Prior QA gates C3.23–C3.36 and C3.37–C3.38.

## 7. Safety and evidence boundary

Read-only source and dated-evidence synthesis only. No Production/Staging SQL, DML, RPC, migrations, table counts, data export, reconciliation, cleanup, provider/bank query, payment/webhook replay, inventory movement, customer/partner communication or deployment was performed. Historical counts and status observations are not current live measurements. This gate does not certify legal, financial or operational correctness.
