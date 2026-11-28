# KRIM Migration Version-Collision Historical Commit Trace — 2026-11-24

## Scope
Read-only GitHub path-history inspection for all 13 repository migration version-collision groups. Each row below records the earliest visible commit for that exact path (and later commits where relevant). The source files remain present in repository history. Commit timestamps establish authoring chronology, not necessarily production application order. No migration file was edited, renumbered, replayed, or applied.

## Historical path chronology

| Collision version | Migration file stem | Earliest visible commit (UTC) | Commit |
|---|---|---|---|
| 20261025150000 | krim_ensure_initial_shipment_leg | 2026-10-25 11:25:10 | 9473f285 |
| 20261025150000 | seed_country_localization_and_units | 2026-10-25 14:34:37 (later neutralized 14:35:34) | 4180c293 / 9688ca6d |
| 20261104190000 | partner_route_scope_and_driver_verification | 2026-11-04 10:10:09 | 303636dd |
| 20261104190000 | driver_verification_documents_and_review | 2026-11-04 12:16:57 (aligned 12:17:45) | 8ca4ab53 / 08613542 |
| 20261104190000 | secure_driver_membership_invitations | 2026-11-04 12:26:57 | b56befaa |
| 20261104190000 | driver_carrier_invitation_and_membership_workflow | 2026-11-04 12:39:49 | 905407bc |
| 20261104190000 | allow_driver_profile_transfer_on_valid_invitation | 2026-11-04 13:28:09 | 48090cc5 |
| 20261104191500 | require_confirmed_email_for_driver_invitation | 2026-11-04 12:48:04 | 7c86a5a0 |
| 20261104191500 | fix_driver_invitation_profile_branch | 2026-11-04 12:52:03 | bbe20520 |
| 20261104191500 | align_driver_review_with_invitation_gates | 2026-11-04 13:32:51 | c5cd17dd |
| 20261104192500 | fix_driver_invitation_profile_branch | 2026-11-04 12:52:03 | bbe20520 |
| 20261104192500 | scope_driver_document_upload_to_pending_profile | 2026-11-04 13:44:37 | f196727a |
| 20261104193000 | secure_driver_membership_invitations | 2026-11-04 12:26:57 | b56befaa |
| 20261104193000 | reverify_driver_after_identity_changes | 2026-11-04 13:44:27 | 6a2b97a7 |
| 20261104223000 | krim_enforce_market_activation_on_shipment_creation | 2026-11-04 15:30:28 | 3c8f9f51 |
| 20261104223000 | krim_country_pack_admin_mobile_performance | 2026-11-04 15:44:33 | 580cfc0f |
| 20261104230000 | krim_unify_market_activation_booking_gate | 2026-11-04 15:32:14 | 32af527b |
| 20261104230000 | krim_global_corridor_compliance_engine | 2026-11-04 16:01:06 | a4ec45bc |
| 20261104234500 | seed_proposed_corridor_catalogue | 2026-11-04 16:01:19 | 0a49f596 |
| 20261104234500 | seed_india_domestic_pilot_corridor_candidate | 2026-11-04 16:31:44 (refined 16:36:42) | 79529495 / 0a2d301d |
| 20261105153000 | enforce_partner_quote_create_permission | 2026-11-05 04:11:19 | 3638f35c |
| 20261105153000 | add_evidence_backed_partner_capability_submission | 2026-11-05 15:23:14 | b5ec44b0 |
| 20261106160000 | linked_goods_receipt_workflow | 2026-11-05 07:16:27 | 5f0977e8 |
| 20261106160000 | create_customs_broker_assignment_foundation | 2026-11-06 04:46:02 | c2a73585 |
| 20261106180000 | operations_dispatch_readiness_register | 2026-11-05 07:23:25 | bf420018 |
| 20261106180000 | driver_assignment_acceptance_gate | 2026-11-05 07:28:51 | 476d5d6b |
| 20261106190000 | driver_assignment_leg_integrity | 2026-11-05 07:26:07 | 0681e782 |
| 20261106190000 | global_vehicle_registry_foundation | 2026-11-05 07:33:07 | 51d004f0 |
| 20261115151000 | schedule_private_vehicle_evidence_expiry_worker | 2026-11-15 09:34:25 | 40f640ed |
| 20261115151000 | require_all_driver_documents_for_verification | 2026-11-15 09:37:08 | 17fc7b9a |

## Findings

1. The collision groups are not just duplicate copies. The prior content review established 13/13 groups have distinct Git blob identities.
2. Git path history provides a deterministic authoring chronology for the files, but that chronology is not proof of production application order. Some migration version IDs do not match commit timestamps, and files may have been applied under different production ledger versions or consolidated into other migrations.
3. The 20261025150000 localization seed file has a historical commit explicitly neutralizing the duplicate file; its substantive peer still shares the same migration version.
4. Several collision groups mix independent business areas (driver onboarding, country-market activation, corridor governance, partner capabilities, customs/warehouse, dispatch/vehicle registry). They cannot safely be combined merely to preserve one timestamp.
5. Some later follow-up migrations have commit times earlier than peers sharing their version. Therefore, sorting only by commit date would not establish correct dependency order.

## Safe next step

Use the exact path-history commits as source references to build a per-file dependency map. For each file, compare:
- exact SQL body and blob SHA;
- production ledger rows with matching name or equivalent object/function changes;
- current staging and production object definitions, grants, policies, triggers and seed state;
- explicit dependencies on functions, types, tables and prior migration effects.

Only then produce a reviewed, forward-only, uniquely versioned reconstruction for a disposable database. Do not rewrite applied production history, mark missing files applied, or replay any collision group based only on this table.

## Release gate
This trace reduces uncertainty about repository authoring history but does not resolve the migration baseline. Production DDL and staging migration application remain NO-GO until the dependency map and disposable replay prove deterministic schema/security parity.
