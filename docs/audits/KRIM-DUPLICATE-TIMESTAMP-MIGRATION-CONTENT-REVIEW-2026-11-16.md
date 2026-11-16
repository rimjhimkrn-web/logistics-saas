# KRIM Duplicate-Timestamp Migration Content Review
**Date:** 16 November 2026  
**Scope:** Static inspection of 30 checked-in SQL migration files across duplicate-version timestamp groups. No production schema, migration history, SQL body, or data was changed.

## Executive result
The duplicate timestamps are not merely repeated copies. The inspected files contain distinct schema and function changes across driver identity/invitations, market activation, corridor compliance, partner capability, warehouse receipts, customs, dispatch, vehicle registry and expiry processing. A single timestamp cannot establish which individual files were applied when production migration history records only one version identifier per timestamp.

The content review therefore strengthens the existing reconciliation blocker: do not resolve collisions by choosing one file, renaming files, concatenating SQL or replaying migrations.

## 1. Selected file fingerprints
The table records Git blob SHA, byte count and line count as repository evidence. It intentionally omits SQL bodies.

| Version timestamp | File | Git blob SHA | Bytes | Lines |
|---|---|---|---:|---:|
| 20261025150000 | krim_ensure_initial_shipment_leg | 46dd44b2cf3060144b4921148618e92615f99b35 | 2,326 | 73 |
| 20261025150000 | seed_country_localization_and_units | fab909f5d1911b83cbd464bd71be96cbe1d2adb3 | 217 | 4 |
| 20261104190000 | allow_driver_profile_transfer_on_valid_invitation | 1f4770bd220dc1e971a1a18e0afbf14250119b7f | 2,140 | 23 |
| 20261104190000 | driver_carrier_invitation_and_membership_workflow | 4b75d50d132d9dc29847410e55bb6d15e86b874f | 12,471 | 135 |
| 20261104190000 | driver_verification_documents_and_review | 13e9f31c7f3373aa72e4e0554d445499fb48fded | 8,656 | 96 |
| 20261104190000 | partner_route_scope_and_driver_verification | 389acac9cd82d26fd2acfe03ed4cc22f22f75e1c | 12,299 | 195 |
| 20261104223000 | krim_country_pack_admin_mobile_performance | 1419f7379367514fc2e77c77a081cc25c86ecbba | 2,949 | 20 |
| 20261104223000 | krim_enforce_market_activation_on_shipment_creation | 3dd59773bde1ff84a37ffd7119bd2a717c271a5f | 3,010 | 32 |
| 20261104230000 | krim_global_corridor_compliance_engine | ecb385cc67f26cf7b5ac1378d3215115c65bc7ed | 21,192 | 187 |
| 20261104230000 | krim_unify_market_activation_booking_gate | d6cb5acd2cc60622cb67b46bb88a29f66e5ed892 | 2,524 | 40 |
| 20261105153000 | add_evidence_backed_partner_capability_submission | b8f75e806b272d29c20fcdd76edce91a70207b88 | 5,932 | 59 |
| 20261105153000 | enforce_partner_quote_create_permission | 5d3df90c94cfba602f513c60e06d40a492c2fe52 | 2,025 | 48 |
| 20261106160000 | create_customs_broker_assignment_foundation | e92a4460df40daaa2d4428a5d861306d86ea04df | 2,261 | 34 |
| 20261106160000 | linked_goods_receipt_workflow | f916a4bd1b3bdde367d21c34665258c042fdb22e | 5,214 | 76 |
| 20261106180000 | driver_assignment_acceptance_gate | dac26acbf146e36def707235124fd7936b0b2e69 | 6,282 | 132 |
| 20261106180000 | operations_dispatch_readiness_register | 484882dde82e32612bd5c3ae899ad35d1656e550 | 3,566 | 45 |
| 20261106190000 | driver_assignment_leg_integrity | 9e089ed776277267b825e225afcb9fb748ae3ec1 | 5,672 | 67 |
| 20261106190000 | global_vehicle_registry_foundation | c2e850a41fc02fb88147ee8ced82af1236b9147f | 7,282 | 72 |
| 20261115151000 | require_all_driver_documents_for_verification | e581d071639585a189f2bb65e0330af07cd08bef | 6,782 | 171 |
| 20261115151000 | schedule_private_vehicle_evidence_expiry_worker | b218180b129009991cb3fc4f9e1afafdad4763e0 | 2,746 | 69 |

The remaining three duplicate-timestamp groups (04:19:15, 04:19:25, 04:19:30 and 04:23:45) were not included in this fingerprint table; their inventory is already recorded in the collision inventory report. They still require production crosswalk.

## 2. High-impact collision groups
### 20261104190000 — four distinct driver/partner migrations
The files address:
- Driver profile transfer guard for valid invitations.
- Driver/carrier invitation and membership workflow.
- Private driver verification evidence and review.
- Route-scoped partner capability and driver verification.

These areas have dependencies and can affect profile ownership, invitation acceptance, evidence ownership, route scope and verification. Applying only one file or selecting an arbitrary order could leave an incomplete or inconsistent driver lifecycle.

### 20261104223000 and 20261104230000 — market activation and corridor compliance
The timestamp groups split country-pack admin functionality, shipment-creation market activation, corridor compliance schema and unified market activation logic across separate files. This is particularly sensitive because KRIM's operational activation controls are currently blocked and corridor dossiers/controls are not yet populated. The repository files must not be replayed against production merely to make booking gates appear present.

### 20261105153000 — partner evidence and quote authorization
The two files separately add evidence-backed capability submission and partner quote-create permission enforcement. Their effects need to be compared with live RPC definitions and grants, not inferred from timestamp or file presence.

### 20261106160000 through 20261106190000 — warehouse, customs and physical execution
The files separately establish customs broker assignment, linked goods receipt, driver assignment acceptance, operations dispatch readiness, driver-leg integrity and vehicle registry. These are distinct operational dependencies, not interchangeable migrations.

### 20261115151000 — driver verification and vehicle expiry
One file tightens driver verification document requirements; the other schedules private vehicle evidence expiry processing. Both affect safety/compliance but have separate object and scheduler implications.

## 3. A notable logical-name duplicate
The file `20261025150000_seed_country_localization_and_units.sql` is explicitly a four-line no-op stating that the applied seed migration is recorded as `20261025143459_seed_country_localization_and_units.sql`. This is useful repository intent evidence, but it is not independent proof of production state. Verify the recorded production migration version and actual seed/catalog state before classifying it as safely superseded.

## 4. Required next comparison
Once the sanitized production manifest is available:
1. Match each production migration version/name to repository files.
2. Compare manifest object identities and statement fingerprints to the SQL file fingerprints.
3. Inspect live PostgreSQL catalog definitions for every affected function, table, trigger, policy, index, constraint and scheduled job.
4. Review Git commit ancestry and historical deployment records to establish intended file application order where possible.
5. Classify each file as applied/equivalent, applied/divergent, unapplied, superseded/no-op, production-only hotfix, or unresolved.
6. Produce a reviewed forward-only migration proposal with preconditions, lock/availability assessment, backup and recovery plan, and staging verification.

## 5. Current safety decision
**Migration history remains blocked.** This static inspection cannot establish which duplicate-timestamp files ran in production. No migration files were renamed, combined, removed, replayed or applied. No production DDL, grants, policies, triggers, functions, data, or migration-history rows were changed.

**Next dependency:** complete the encrypted production export, launch the sanitized-manifest workflow, then perform the semantic crosswalk.
