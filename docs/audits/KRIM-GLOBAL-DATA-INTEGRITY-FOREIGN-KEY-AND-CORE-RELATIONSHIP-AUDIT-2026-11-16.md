# KRIM Global Data Integrity, Foreign-Key and Core Relationship Audit
**Date:** 16 November 2026  
**Method:** Read-only PostgreSQL catalog and statistics inspection of production; no business RPCs invoked, no DDL/DML, no records created or changed.

## Executive summary
The production schema has a substantial relational foundation: **547 public foreign-key constraints, all validated**, and **673 unique indexes**. No unvalidated public foreign-key constraints were found. This is a positive structural baseline, but it does not establish that business relationships are semantically correct, that composite tenant/parent relationships are consistently enforced, or that production data is complete.

## Catalog findings
- Public foreign-key constraints: 547.
- Unvalidated public foreign-key constraints: 0.
- Public unique indexes: 673.
- The FK catalogue includes important shipment, leg, assignment, capacity, warehouse transfer, return, custody, user and organization relationships.
- Several high-value records use ON DELETE RESTRICT, helping preserve shipment and fulfilment history.
- Composite foreign keys are present for custody transfers to ensure the referenced leg belongs to the same shipment.
- A preliminary FK-index coverage query produced candidates but its composite-key matching expression is not reliable enough to classify missing indexes. No missing-index defect is asserted; a corrected ordered-key analysis is required.

## Production data baseline (statistics estimates)
The following values are PostgreSQL pg_stat_user_tables n_live_tup estimates, not exact counts:
- Organizations: 14; active memberships: 13.
- Shipments: 18; shipment legs: 1.
- Quotes: 7; partner opportunities: 3; partner capabilities: 1; partner verification cases: 1.
- Shipment status history: 41; milestones: 2; tracking events: 1.
- Country operating packs: 249; country pack controls: 4,482; readiness assessments: 82.
- Markets: 6; network corridor candidates: 7; shipment readiness/compliance gates: 6 each.
- Warehouse operational tables and several customer/CRM/finance/claims tables have zero or near-zero estimated rows, consistent with earlier exact count audits showing no real fulfilment network and deferred financial activity.

## Integrity interpretation
1. Referential integrity is structurally strong at the declared FK level. All 547 public FKs are validated. This does not mean every logical relationship has a declared FK; application-level relationships may remain unenforced.
2. A low-volume production dataset cannot validate the full ecosystem. Eighteen estimated shipments and one shipment leg are insufficient evidence for multi-leg handoffs, quote contention, warehouse reservation races, customs cases or enterprise network sharing.
3. Parent-child semantic consistency still needs targeted checks: shipment_id consistency across leg-specific assignment/quote/opportunity/custody records, organization type consistency, exact-leg capacity binding and same-tenant evidence ownership. A simple FK to a valid parent ID does not guarantee these business invariants.
4. Canonical and legacy data coexist. Earlier source review found enterprise fallback from krim_shipments to shipment_requests, and legacy role models alongside canonical organization memberships/role assignments. This increases risk of divergent records and ambiguous authority.
5. Operational records are not evidence of an active operating network. Earlier audits show no verified partner capacity, accepted assignment, active dispatch authorization, warehouse inventory, POD or approved market/corridor.
6. Financial integrity is intentionally deferred. Do not seed financial events, create live invoices, post ledger entries, reconcile settlements or enable checkout during this phase.

## Required follow-up
- Run a deterministic FK coverage report handling ordered composite keys, partial indexes, expression indexes and included columns correctly.
- Build curated semantic integrity queries for shipment/leg/assignment/quote/capacity/custody, org membership/role and storage evidence ownership. Use exact counts and bounded samples; never infer from table statistics.
- Verify canonical-vs-legacy table authority and migration history before any data migration or cleanup.
- Test duplicate and cross-tenant identities, orphaned business references, composite shipment/leg mismatches and concurrent writes in isolated staging.
- Establish a repeatable integrity baseline and alerting for critical relationship violations.
- Review ON DELETE behavior for every business/audit/evidence table; operational and financial history should not be cascade-deleted casually.

## Critical blocker
Production migration history and repository migration files remain materially mismatched (previous reconciliation: 558 production migration versions versus 363 repository SQL files, 348 unique repository timestamps). Do not apply schema changes, recreate constraints, baseline or replay migrations until the encrypted production schema export has been converted into the sanitized manifest and the full migration crosswalk has been reconciled.

## Release decision
**NO-GO for unrestricted production logistics execution.** The FK catalogue is validated, but low live operating volume, unresolved semantic invariants, canonical/legacy overlap, unapproved market/corridor controls and outstanding workflow findings prevent operational certification.

## Change boundary
Read-only catalog and table-statistics inspection only. No production SQL mutation, RPC invocation, partner/customer communication, payment, inventory movement, shipment creation or provider request was performed.
