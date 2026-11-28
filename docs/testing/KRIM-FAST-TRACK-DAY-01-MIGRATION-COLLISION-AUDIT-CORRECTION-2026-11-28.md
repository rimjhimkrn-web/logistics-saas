# KRIM Fast-Track Day 01 — Migration Collision Audit Correction and Priority Triage
Date: 2026-11-28
Branch: `staging/phase00-env-isolation`
Inspected branch head: `f27e3f0ae804a4bbf1a5bc59c3dc775d1eb910aa`
Staging project: `qrpcivhdxobiaofppbkl`
Production: not accessed or changed

## Correction to the preceding reconciliation report
The previous report stated **28** duplicate-version groups. A fresh complete-tree recount at the branch head above finds **29** groups. The corrected arithmetic is:
- 499 SQL migration files.
- 467 unique 14-digit version prefixes.
- 32 extra files beyond one file per unique version.
- 29 duplicate-version groups (some groups have 2 files, one has 3, one has 4).
The earlier group count was an undercount. This report supersedes that figure.

## Reconfirmed Staging ledger comparison
The live Staging migration ledger still reports 163 entries. Only three ledger version prefixes have exact matches among the 467 repository version prefixes:
- `20261126091219` — `phase00_checkpoint16_permission_scope_partner_events_and_pod`
- `20261126092204` — `phase00_checkpoint16_authenticated_rls_policy_dependencies`
- `20261126115730` — `phase00_checkpoint16_lane_capacity_authentication_order`

The remaining 160 ledger versions have no exact version-prefix match in the branch. This is a version-prefix comparison only; it does not establish SQL-content equivalence or prove that the other 496 repository files are unapplied.

## Full duplicate-version inventory
Each line lists distinct SQL files sharing the same 14-digit version:
- `20261025150000`: `krim_ensure_initial_shipment_leg`; `seed_country_localization_and_units`
- `20261104190000`: `allow_driver_profile_transfer_on_valid_invitation`; `driver_carrier_invitation_and_membership_workflow`; `driver_verification_documents_and_review`; `partner_route_scope_and_driver_verification`
- `20261104191500`: `align_driver_review_with_invitation_gates`; `require_confirmed_email_for_driver_invitation`
- `20261104192500`: `fix_driver_invitation_profile_branch`; `scope_driver_document_upload_to_pending_profile`
- `20261104193000`: `reverify_driver_after_identity_changes`; `secure_driver_membership_invitations`
- `20261104223000`: `krim_country_pack_admin_mobile_performance`; `krim_enforce_market_activation_on_shipment_creation`
- `20261104230000`: `krim_global_corridor_compliance_engine`; `krim_unify_market_activation_booking_gate`
- `20261104234500`: `seed_india_domestic_pilot_corridor_candidate`; `seed_proposed_corridor_catalogue`
- `20261105153000`: `add_evidence_backed_partner_capability_submission`; `enforce_partner_quote_create_permission`
- `20261106160000`: `create_customs_broker_assignment_foundation`; `linked_goods_receipt_workflow`
- `20261106180000`: `driver_assignment_acceptance_gate`; `operations_dispatch_readiness_register`
- `20261106190000`: `driver_assignment_leg_integrity`; `global_vehicle_registry_foundation`
- `20261115151000`: `require_all_driver_documents_for_verification`; `schedule_private_vehicle_evidence_expiry_worker`
- `20261126230000`: `phase00_disable_unsafe_legacy_reconciliation`; `phase00_guard_invoice_lifecycle`
- `20261127027000`: `phase00_enforce_driver_partner_leg_identity`; `phase00_reconcile_expired_capacity_holds`
- `20261127028000`: `phase00_enforce_pod_partner_assignment_identity`; `phase00_protect_partner_assignment_history`
- `20261127029000`: `phase00_enforce_dispatch_capacity_identity`; `phase00_enforce_partner_assignment_state_transitions`
- `20261127077000`: `phase00_allow_partner_driver_notification_types`; `phase00_fail_closed_unimplemented_workflow_actions`
- `20261127084000`: `phase00_bounded_workflow_dispatch_retries`; `phase00_freeze_workflow_config_during_execution`
- `20261127090000`: `phase00_driver_status_change_notifications`; `phase00_make_partner_storage_mfa_policy_restrictive`
- `20261127123000`: `phase00_block_expired_driver_licence_assignment`; `phase00_enforce_one_active_leg_plan_per_shipment`
- `20261127150000`: `phase00_grant_scoped_quote_reads`; `phase00_require_identity_evidence_before_driver_assignment`
- `20261127160000`: `phase00_record_immutable_customer_quote_acceptance`; `phase00_serialize_driver_assignment_with_vehicle_unbind`
- `20261127162000`: `phase00_close_only_pod_driver_assignment`; `phase00_revalidate_dispatch_before_exception_recovery`
- `20261127164000`: `phase00_keep_dispatch_currentness_through_driver_trip_states`; `phase00_require_fresh_evidence_after_pod_rejection`
- `20261127168000`: `phase00_enforce_fresh_evidence_during_pod_review`; `phase00_pin_shipment_terminal_guard_search_path`
- `20261127169000`: `phase00_enforce_fresh_evidence_during_pod_review`; `phase00_require_single_leg_in_transit_for_pod`
- `20261127170000`: `phase00_record_partner_quote_response_evidence`; `phase00_require_exact_multileg_plan_completion`
- `20261127190000`: `phase00_grant_own_user_preference_access`; `phase00_preserve_capacity_event_lineage`; `phase00_scope_partner_response_evidence_reads`

## Priority source-level verification
The following collision files were fetched and inspected by blob:
- `20261127077000_phase00_allow_partner_driver_notification_types.sql` (537 bytes): changes the notifications type constraint to permit partner/driver categories.
- `20261127077000_phase00_fail_closed_unimplemented_workflow_actions.sql` (3,244 bytes): replaces a workflow queue executor and fails closed for unsupported side effects. These are separate, substantive database changes.
- `20261127190000_phase00_grant_own_user_preference_access.sql` (311 bytes): grants authenticated SELECT/INSERT/UPDATE on own preference table and revokes anon.
- `20261127190000_phase00_preserve_capacity_event_lineage.sql` (742 bytes): adds restrictive foreign keys and indexes for capacity event lineage.
- `20261127190000_phase00_scope_partner_response_evidence_reads.sql` (3,308 bytes): creates a SECURITY DEFINER, authenticated organisation-scoped evidence read RPC with explicit grants. These are three separate, substantive operations.
- `20261025150000_seed_country_localization_and_units.sql` (217 bytes): is explicitly a no-op stating it was superseded by `20261025143459_seed_country_localization_and_units.sql`; it should not be confused with the substantive initial-shipment-leg migration sharing its version.

GitHub file history shows the recent colliding files were introduced by separate commits minutes apart, rather than being one intentional atomic multi-file migration:
- Notification categories: commit `9d8977cd2aa6b165feb1366c0ce1731a40075802`, 2026-11-27 04:36:35 UTC.
- Workflow fail-closed executor: commit `a16209e1ead3f3ce051115ce07222313710e3e53`, 2026-11-27 04:39:45 UTC.
- Preference grant: commit `5b619df9c483d4c2ee933abd022368a27fbf1759`, 2026-11-27 05:43:07 UTC.
- Partner response evidence RPC: commit `4f8f883846125aea8ac1d90543dc362620f7f678`, 2026-11-27 06:28:41 UTC.
- Capacity lineage constraints: commit `47a47d3ece9fd954de2b784c3f8912f691813e7c`, 2026-11-27 07:05:42 UTC.

## Triage conclusion
- Duplicate versions are a concrete replay-order ambiguity. Supabase migration version identity is the 14-digit prefix; multiple distinct operations sharing one prefix cannot be assumed to execute as separate ordered migrations in a clean replay.
- At least the sampled late-November collisions are distinct DDL changes, not duplicate content.
- One older collision is explicitly a superseded no-op, showing the repository has attempted a partial neutralization, but that does not resolve the remaining collisions.
- Staging's applied ledger has a different version history. Similar migration names or presumed schema state must not be used to mark files as applied.

## Next safe work
1. Inventory Git history and classify each of the 29 groups: substantive operation, intentional no-op, superseded file, or unknown.
2. Reconcile all 163 Staging ledger entries to exact SQL content where archived copies exist; do not use name similarity as proof.
3. Recover an owner-approved schema-only Staging baseline and establish a deterministic replay chain in a separate recovery branch.
4. Run replay on a disposable local database before proposing any Staging action.

## Safety status
No SQL was applied, no migration file was renamed or retimestamped, no migration ledger was edited, no fixture or RPC was invoked, and no workflow/deployment was run. Production was not accessed or changed. Phase 00 remains OPEN — NOT APPROVED.
