# KRIM Production Migration Reconciliation — Detailed Name Crosswalk
Date: 11 November 2026
Repository commit inspected: ae56bffbc08d416493db26a4eeb199271647fe89
Status: read-only metadata reconciliation; not proof of SQL equivalence and not authorization to run, mark, reset or repair migrations.

## Inventory totals
- Repository SQL migration files: 263
- Production migration history entries: 425
- Exact version matches: 64
- Repository versions absent from production history: 199
- Production versions absent from repository history: 361
- Descriptive migration suffixes present on both sides: 201

## Same-name crosswalk
| Migration suffix | Repository version(s) | Production version(s) | Metadata assessment |
|---|---|---|---|
| add_admin_pod_verification_and_delivery_authorization | 20261106010000 | 20261105060011 | same suffix only; SQL/source equivalence unverified |
| add_authenticated_driver_pod_submission | 20261106001500 | 20261105055723 | same suffix only; SQL/source equivalence unverified |
| add_authenticated_krim_ai_rate_limit | 20261104204500 | 20261104150628 | same suffix only; SQL/source equivalence unverified |
| add_evidence_backed_partner_capability_submission | 20261105153000 | 20261105151950 | same suffix only; SQL/source equivalence unverified |
| add_missing_fk_indexes_advisor_batch | 20261025073812 | 20261025073812 | exact version overlap |
| add_partner_account_mode_column | 20261020141000 | 20261020080517 | same suffix only; SQL/source equivalence unverified |
| add_quote_pricing_snapshot_column | 20261105193000 | 20261105045924 | same suffix only; SQL/source equivalence unverified |
| admin_capacity_resource_review_workflow | 20261104102003 | 20261104102003 | exact version overlap |
| admin_list_partner_capabilities | 20261104153000 | 20261104090159 | same suffix only; SQL/source equivalence unverified |
| admin_warehouse_facility_capability_queue | 20261104112808 | 20261104112808 | exact version overlap |
| admin_warehouse_operations_oversight | 20261104111804 | 20261104111804 | exact version overlap |
| align_capability_approval_status_values | 20261105153100 | 20261105152017 | same suffix only; SQL/source equivalence unverified |
| align_capacity_review_partner_organization_types | 20261105151420 | 20261105151420 | exact version overlap |
| align_partner_evidence_storage_org_types | 20261105151615 | 20261105151615 | exact version overlap |
| apply_domestic_rate_and_tax_evidence_guards | 20261105192000 | 20261105045815 | same suffix only; SQL/source equivalence unverified |
| assign_locations_to_existing_active_markets | 20261025113000 | 20261025110256 | same suffix only; SQL/source equivalence unverified |
| block_development_test_partner_awards | 20261026050100 | 20261026044300 | same suffix only; SQL/source equivalence unverified |
| block_development_test_partner_quotes | 20261026050000 | 20261026044130 | same suffix only; SQL/source equivalence unverified |
| capacity_evidence_submitter_binding | 20261104103130 | 20261104103130 | exact version overlap |
| capacity_registration_active_membership_guard | 20261104101721 | 20261104101721 | exact version overlap |
| capacity_registration_pending_review_gate | 20261104101633 | 20261104101633 | exact version overlap |
| capacity_reservation_authorization_and_idempotency_guards | 20261104102345 | 20261104102345 | exact version overlap |
| capacity_reservation_lifecycle_release_guards | 20261104102714 | 20261104102714 | exact version overlap |
| capacity_resource_approval_requires_private_evidence | 20261104102944 | 20261104102944 | exact version overlap |
| capacity_resource_expiry_aware_approval | 20261104102610 | 20261104102610 | exact version overlap |
| capacity_resource_partner_organization_type_guard | 20261104103359 | 20261104103359 | exact version overlap |
| capacity_resource_private_evidence_uploads | 20261104102936 | 20261104102936 | exact version overlap |
| capacity_resource_requires_verified_country_capability | 20261104170500 | 20261104113759 | same suffix only; SQL/source equivalence unverified |
| capacity_review_capability_effective_dates | 20261104102849 | 20261104102849 | exact version overlap |
| capacity_review_decision_validation | 20261104102013 | 20261104102013 | exact version overlap |
| close_stale_partner_opportunities | 20261025113341 | 20261025113341 | exact version overlap |
| complete_iso3166_alpha3_country_codes | 20261105170000 | 20261105042437 | same suffix only; SQL/source equivalence unverified |
| configure_finance_inr_account_mappings_and_posting_rules | 20261106055441 | 20261106055441 | exact version overlap |
| consolidate_customs_record_read_policy | 20261105102000 | 20261105082209 | same suffix only; SQL/source equivalence unverified |
| consolidate_finance_and_exception_read_policies | 20261105100500 | 20261105082138 | same suffix only; SQL/source equivalence unverified |
| consolidate_legacy_shipment_read_policies | 20261105110000 | 20261105082340 | same suffix only; SQL/source equivalence unverified |
| consolidate_marketplace_shipment_finance_read_policies | 20261105104500 | 20261105082301 | same suffix only; SQL/source equivalence unverified |
| consolidate_shipment_read_policies_without_access_change | 20261105094500 | 20261105082059 | same suffix only; SQL/source equivalence unverified |
| correct_capability_review_status_guard_replacement | 20261105153400 | 20261105152513 | same suffix only; SQL/source equivalence unverified |
| correct_pod_submission_leg_and_tracking_status | 20261105233000 | 20261105055330 | same suffix only; SQL/source equivalence unverified |
| create_customs_broker_assignment_foundation | 20261106160000 | 20261106044553 | same suffix only; SQL/source equivalence unverified |
| customer_access_verified_pod_evidence | 20261105140000 | 20261105065238 | same suffix only; SQL/source equivalence unverified |
| customs_broker_license_evidence_and_review | 20261107130000 | 20261106045100 | same suffix only; SQL/source equivalence unverified |
| deny_client_access_internal_intake_tables | 20261017140000 | 20261017081634 | same suffix only; SQL/source equivalence unverified |
| dispatch_readiness_vehicle_compatibility | 20261106230000 | 20261105075821 | same suffix only; SQL/source equivalence unverified |
| distinguish_missing_revenue_policy_from_idempotent_retry | 20261017094013 | 20261017094013 | exact version overlap |
| driver_assignment_acceptance_gate | 20261106180000 | 20261105072829 | same suffix only; SQL/source equivalence unverified |
| driver_carrier_invitation_and_membership_workflow | 20261104190000 | 20261104123850 | same suffix only; SQL/source equivalence unverified |
| driver_document_admin_review_workflow | 20261104184500 | 20261104132256 | same suffix only; SQL/source equivalence unverified |
| driver_vehicle_compatibility | 20261106220000 | 20261105075808 | same suffix only; SQL/source equivalence unverified |
| driver_vehicle_readiness_rpc | 20261106223000 | 20261105075814 | same suffix only; SQL/source equivalence unverified |
| enable_secured_customer_shipment_booking_rpc | 20261105114500 | 20261105040557 | same suffix only; SQL/source equivalence unverified |
| enforce_aal2_on_admin_inquiry_followup | 20261105062300 | 20261105062347 | same suffix only; SQL/source equivalence unverified |
| enforce_aal2_on_global_rate_card_admin_rpcs | 20261105102900 | 20261105050623 | same suffix only; SQL/source equivalence unverified |
| enforce_active_markets_for_shipment_booking | 20261025143059, 20261025143500 | 20261025143059 | exact version overlap |
| enforce_market_activation_for_tariff_quotes | 20261025193000 | 20261025154450 | same suffix only; SQL/source equivalence unverified |
| enforce_mfa_partner_capability_review | 20261104160000 | 20261104090554 | same suffix only; SQL/source equivalence unverified |
| enforce_one_current_compliance_evidence_per_check | 20261105214000 | 20261105155756 | same suffix only; SQL/source equivalence unverified |
| enforce_partner_payable_assignment_idempotency | 20261017134500 | 20261017081547 | same suffix only; SQL/source equivalence unverified |
| enforce_partner_quote_create_permission | 20261105153000 | 20261105041122 | same suffix only; SQL/source equivalence unverified |
| enforce_payment_provider_reference_idempotency | 20261017120000 | 20261017054157 | same suffix only; SQL/source equivalence unverified |
| enforce_pending_driver_profile_creation | 20261104180500 | 20261104120833 | same suffix only; SQL/source equivalence unverified |
| enforce_revenue_allocation_idempotency | 20261017133000 | 20261017081423 | same suffix only; SQL/source equivalence unverified |
| enrich_partner_capability_admin_review_context | 20261105163000 | 20261105152843 | same suffix only; SQL/source equivalence unverified |
| enrich_partner_verification_queue_account_and_compliance_state | 20261107091000 | 20261105154430 | same suffix only; SQL/source equivalence unverified |
| expand_global_currency_reference_catalogue | 20261105171000 | 20261105042503 | same suffix only; SQL/source equivalence unverified |
| expand_global_language_currency_locale_catalogues | 20261104203000 | 20261104145939 | same suffix only; SQL/source equivalence unverified |
| expand_iso639_language_catalogue | 20261105172000 | 20261105042524 | same suffix only; SQL/source equivalence unverified |
| fail_closed_partner_capacity_and_capability_approval | 20261104102452 | 20261104102452 | exact version overlap |
| fail_closed_tariff_quotes_without_approved_rate_cards | 20261019000100 | 20261018190843 | same suffix only; SQL/source equivalence unverified |
| fix_customs_license_row_scope | 20261107143000 | 20261106045345 | same suffix only; SQL/source equivalence unverified |
| fix_driver_invitation_profile_branch | 20261104192500 | 20261104125108 | same suffix only; SQL/source equivalence unverified |
| fix_revenue_allocation_idempotency_and_recognition | 20261017093454 | 20261017093454 | exact version overlap |
| gate_partner_marketplace_reads_on_current_compliance | 20261105203000 | 20261105155336 | same suffix only; SQL/source equivalence unverified |
| global_partner_onboarding_location_hardening | 20261020074510 | 20261020074510 | exact version overlap |
| global_vehicle_registry_foundation | 20261106190000 | 20261105073241 | same suffix only; SQL/source equivalence unverified |
| harden_dispute_register_access | 20261107221000 | 20261106053929 | same suffix only; SQL/source equivalence unverified |
| harden_partner_account_mode_validation | 20261020134500 | 20261020080120 | same suffix only; SQL/source equivalence unverified |
| harden_partner_compliance_review_input_validation | 20261107093100 | 20261105154704 | same suffix only; SQL/source equivalence unverified |
| harden_partner_verification_approval_evidence | 20261025143000 | 20261025112213 | same suffix only; SQL/source equivalence unverified |
| harden_warehouse_evidence_ownership_and_cleanup | 20261105063941 | 20261105063941 | exact version overlap |
| harden_warehouse_evidence_registration | 20261105123500 | 20261105063932 | same suffix only; SQL/source equivalence unverified |
| harden_warehouse_inventory_movement_chain | 20261105063808 | 20261105063808 | exact version overlap |
| harden_warehouse_task_idempotency_and_quality_gate | 20261105064221 | 20261105064221 | exact version overlap |
| implement_rate_card_backed_tariff_quotes | 20261018193607 | 20261018193607 | exact version overlap |
| index_recent_driver_vehicle_warehouse_foreign_keys | 20261105090000 | 20261105081928 | same suffix only; SQL/source equivalence unverified |
| initialize_finance_chart_of_accounts_inr | 20261107230000 | 20261106054504 | same suffix only; SQL/source equivalence unverified |
| krim_country_pack_admin_mobile_performance | 20261104223000 | 20261104154412 | same suffix only; SQL/source equivalence unverified |
| krim_country_pack_status_approval_controls | 20261104221500 | 20261104153942 | same suffix only; SQL/source equivalence unverified |
| krim_enforce_market_activation_on_shipment_creation | 20261104223000 | 20261104153026 | same suffix only; SQL/source equivalence unverified |
| krim_enforce_market_activation_shipment_trigger | 20261104231500 | 20261104153318 | same suffix only; SQL/source equivalence unverified |
| krim_ensure_initial_shipment_leg | 20261025150000 | 20261025110931, 20261025112519 | same suffix only; SQL/source equivalence unverified |
| krim_global_country_operating_pack_engine | 20261104220000 | 20261104153916 | same suffix only; SQL/source equivalence unverified |
| krim_global_market_readiness_registry | 20261104205000 | 20261104152205 | same suffix only; SQL/source equivalence unverified |
| krim_global_operations_records_backend | 20261024100000 | 20261023191959 | same suffix only; SQL/source equivalence unverified |
| krim_inquiry_followup_history | 20261025100000 | 20261024224951 | same suffix only; SQL/source equivalence unverified |
| krim_market_activation_requires_professional_opinions | 20261104224500 | 20261104153126 | same suffix only; SQL/source equivalence unverified |
| krim_regulatory_source_review_transition_guard | 20261104214500 | 20261104152655 | same suffix only; SQL/source equivalence unverified |
| krim_regulatory_source_verification_workflow | 20261104213000 | 20261104152610 | same suffix only; SQL/source equivalence unverified |
| krim_unify_market_activation_booking_gate | 20261104230000 | 20261104153210 | same suffix only; SQL/source equivalence unverified |
| krim_user_app_backend_modules | 20261016120808 | 20261016120808 | exact version overlap |
| krim_warehouse_atomic_inventory_movements | 20261024090000 | 20261024082030, 20261024082117 | same suffix only; SQL/source equivalence unverified |
| krim_warehouse_core_operations | 20261024080000 | 20261024081234 | same suffix only; SQL/source equivalence unverified |
| krim_warehouse_lock_movement_writes_to_rpc | 20261024091500 | 20261024082353 | same suffix only; SQL/source equivalence unverified |
| krim_warehouse_reject_nan_quantities | 20261024092000 | 20261024082605 | same suffix only; SQL/source equivalence unverified |
| limit_refund_requests_to_unreconciled_paid_orders | 20261107222000 | 20261106054019 | same suffix only; SQL/source equivalence unverified |
| link_driver_assignments_to_partner_legs | 20261105235000 | 20261105055543 | same suffix only; SQL/source equivalence unverified |
| linked_inbound_receiving_workflow | 20261106150000 | 20261105071020 | same suffix only; SQL/source equivalence unverified |
| lock_down_private_payment_registry_rls | 20261025073323 | 20261025073323 | exact version overlap |
| lockdown_commercial_pricing_table_writes | 20261105181000 | 20261105043634 | same suffix only; SQL/source equivalence unverified |
| lockdown_legacy_partner_fleet_and_driver_tables | 20261104173000 | 20261104114904 | same suffix only; SQL/source equivalence unverified |
| make_capability_evidence_array_validation_type_safe | 20261105164000 | 20261105152958 | same suffix only; SQL/source equivalence unverified |
| partner_account_modes_test_and_individual_interest | 20261020133000 | 20261020075927 | same suffix only; SQL/source equivalence unverified |
| partner_assignment_capacity_reservation | 20261104102236 | 20261104102236 | exact version overlap |
| partner_capability_queue_requires_private_evidence | 20261111200000 | 20261111072758 | same suffix only; SQL/source equivalence unverified |
| partner_capability_review_workflow | 20261104150000 | 20261104085938 | same suffix only; SQL/source equivalence unverified |
| partner_capacity_resource_registration | 20261104101527 | 20261104101527 | exact version overlap |
| partner_compliance_evidence_submission | 20261105210000 | 20261105155537 | same suffix only; SQL/source equivalence unverified |
| partner_compliance_review_workflow | 20261107093000 | 20261105154654 | same suffix only; SQL/source equivalence unverified |
| partner_verification_admin_review_workflow | 20261020074900 | 20261020074900 | exact version overlap |
| persist_partner_capability_submission_details | 20261105153200 | 20261105152048 | same suffix only; SQL/source equivalence unverified |
| persist_quote_expiry_on_accept_attempt | 20261105103000 | 20261105035810 | same suffix only; SQL/source equivalence unverified |
| persist_tariff_quote_price_snapshot | 20261105194000 | 20261105045951 | same suffix only; SQL/source equivalence unverified |
| populate_global_country_defaults | 20261105174000 | 20261105042823 | same suffix only; SQL/source equivalence unverified |
| prevent_customer_country_catalogue_activation | 20261105092200 | 20261105035725 | same suffix only; SQL/source equivalence unverified |
| prevent_mixed_quality_lot_receipts | 20261105133000 | 20261105064750 | same suffix only; SQL/source equivalence unverified |
| quote_capacity_check_stage_constraint_fix | 20261104103623 | 20261104103623 | exact version overlap |
| quote_capacity_matching_subtracts_active_reservations | 20261104103724 | 20261104103724 | exact version overlap |
| quote_matching_uses_reservable_capacity_only | 20261104103859 | 20261104103859 | exact version overlap |
| quote_orchestration_require_same_partner_capability_and_capacity | 20261104103557 | 20261104103557 | exact version overlap |
| quote_orchestration_verified_capacity_matching | 20261104103538 | 20261104103538 | exact version overlap |
| rate_limit_and_validate_carrier_driver_invitations | 20261104195500 | 20261104130310 | same suffix only; SQL/source equivalence unverified |
| remove_duplicate_partner_capability_read_policy | 20261105153500 | 20261105152555 | same suffix only; SQL/source equivalence unverified |
| remove_user_metadata_driver_invitation_gate | 20261104194000 | 20261104125300 | same suffix only; SQL/source equivalence unverified |
| require_active_country_for_partner_capability | 20261105153700 | 20261105152844 | same suffix only; SQL/source equivalence unverified |
| require_active_membership_for_permission_checks | 20261105084623 | 20261105084623 | exact version overlap |
| require_approved_rates_in_all_quote_paths | 20261105184500 | 20261105044458 | same suffix only; SQL/source equivalence unverified |
| require_confirmed_email_for_driver_invitation | 20261104191500 | 20261104124749 | same suffix only; SQL/source equivalence unverified |
| require_country_for_partner_capability_coverage | 20261105153600 | 20261105152706 | same suffix only; SQL/source equivalence unverified |
| require_current_partner_compliance_for_commercial_actions | 20261105200000 | 20261105155207 | same suffix only; SQL/source equivalence unverified |
| require_dispatch_proof_before_warehouse_handover | 20261111100000 | 20261111050237 | same suffix only; SQL/source equivalence unverified |
| require_evidence_and_active_coverage_for_capability_approval | 20261105162000 | 20261105152608 | same suffix only; SQL/source equivalence unverified |
| require_evidence_for_commercial_rate_activation | 20261105183000 | 20261105044223 | same suffix only; SQL/source equivalence unverified |
| require_explicit_transport_mode_for_tariff_quotes | 20261025170000 | 20261025112942 | same suffix only; SQL/source equivalence unverified |
| require_shipment_create_permission_for_global_tariff_reads | 20261105150640 | 20261105150709 | same suffix only; SQL/source equivalence unverified |
| require_shipment_update_permission_for_partner_assignment_response | 20261017093935 | 20261017093935 | exact version overlap |
| require_transport_mode_for_partner_opportunities | 20261025180000 | 20261025113146 | same suffix only; SQL/source equivalence unverified |
| require_verified_partner_for_partner_rate_card_reads | 20261105150700 | 20261105150918 | same suffix only; SQL/source equivalence unverified |
| require_verified_pod_before_driver_delivery_completion | 20261105240000 | 20261105061144 | same suffix only; SQL/source equivalence unverified |
| restore_rate_card_backed_tariff_quotes | 20261019100000 | 20261019043638 | same suffix only; SQL/source equivalence unverified |
| restrict_anonymous_customs_and_shipment_document_reads | 20261107103000 | 20261106044136 | same suffix only; SQL/source equivalence unverified |
| restrict_claims_to_confirmed_shipments | 20261107201000 | 20261106052736 | same suffix only; SQL/source equivalence unverified |
| restrict_customer_pod_reads_to_verified_evidence | 20261111130000 | 20261111052116 | same suffix only; SQL/source equivalence unverified |
| restrict_direct_finance_table_writes | 20261107210000 | 20261106053227 | same suffix only; SQL/source equivalence unverified |
| restrict_privileged_krim_rpc_to_authenticated | 20261019020919 | 20261019020919 | exact version overlap |
| retire_legacy_driver_invitation_creator | 20261104195000 | 20261104125738 | same suffix only; SQL/source equivalence unverified |
| retire_legacy_place_shipment_overloads | 20261025141756 | 20261025141756 | exact version overlap |
| retire_legacy_pod_documents_bucket_policies | 20261105071000 | 20261105062612 | same suffix only; SQL/source equivalence unverified |
| retire_legacy_shipment_pod_document_policies | 20261105072000 | 20261105062635 | same suffix only; SQL/source equivalence unverified |
| retire_legacy_shipment_rpc_and_lock_trigger_function | 20261025114802 | 20261025114802 | exact version overlap |
| retire_legacy_shipment_rpc_without_transport_mode | 20261025114551 | 20261025114551 | exact version overlap |
| reverify_driver_after_identity_changes | 20261104193000 | 20261104134336 | same suffix only; SQL/source equivalence unverified |
| revoke_anon_payment_finance_reads | 20261025073559 | 20261025073559 | exact version overlap |
| scope_cross_workspace_read_policies_to_permissions | 20261105081710 | 20261105081710 | exact version overlap |
| scope_customs_and_exception_reads_until_broker_assignment | 20261107110000 | 20261106044259 | same suffix only; SQL/source equivalence unverified |
| scope_driver_document_upload_to_pending_profile | 20261104192500 | 20261104134348 | same suffix only; SQL/source equivalence unverified |
| scope_financial_reconciliation_reads | 20261107211000 | 20261106053254 | same suffix only; SQL/source equivalence unverified |
| scope_global_rate_card_reads_to_effective_customer_tariffs | 20261105150614 | 20261105150614 | exact version overlap |
| scope_operational_milestones_to_assigned_partner_leg | 20261106013000 | 20261105060505 | same suffix only; SQL/source equivalence unverified |
| scope_partner_capability_reads_to_own_organization | 20261105153300 | 20261105152404 | same suffix only; SQL/source equivalence unverified |
| scope_partner_marketplace_reads_to_verified_capability | 20261105160000 | 20261105041425 | same suffix only; SQL/source equivalence unverified |
| secure_booking_readiness_and_anon_reads | 20261105150000 | 20261105040938 | same suffix only; SQL/source equivalence unverified |
| secure_claim_submission_evidence_and_review | 20261107200000 | 20261106052501 | same suffix only; SQL/source equivalence unverified |
| secure_driver_delivery_evidence_registration | 20261105054211 | 20261105054211 | exact version overlap |
| secure_refund_request_workflow | 20261107220000 | 20261106053726 | same suffix only; SQL/source equivalence unverified |
| secure_support_ticket_conversation_and_admin_workflow | 20261105080000 | 20261105062956 | same suffix only; SQL/source equivalence unverified |
| seed_complete_iso3166_alpha2_country_catalogue | 20261025162500 | 20261025144507 | same suffix only; SQL/source equivalence unverified |
| seed_country_localization_and_units | 20261025143459, 20261025150000 | 20261025143459 | exact version overlap |
| seed_global_primary_locale_catalogue | 20261105175000 | 20261105042912 | same suffix only; SQL/source equivalence unverified |
| seed_inactive_global_country_catalogue_baseline | 20261025161000 | 20261025144225 | same suffix only; SQL/source equivalence unverified |
| seed_supported_global_languages | 20261025142414 | 20261025142414 | exact version overlap |
| separate_partner_verification_from_compliance_activation | 20261107090000 | 20261105154408 | same suffix only; SQL/source equivalence unverified |
| shipment_capacity_release_audit_scope_fix | 20261104102731 | 20261104102731 | exact version overlap |
| shipment_capacity_vehicle_resource_guard | 20261104103423 | 20261104103423 | exact version overlap |
| support_partner_compliance_not_applicable_declarations | 20261105211000 | 20261105155604 | same suffix only; SQL/source equivalence unverified |
| support_registered_business_mode_transition | 20261020135500 | 20261020080213 | same suffix only; SQL/source equivalence unverified |
| suspend_revenue_recognition_until_tax_split_is_verified | 20261106055545 | 20261106055545 | exact version overlap |
| tighten_driver_document_organization_scope | 20261104190500 | 20261104121709 | same suffix only; SQL/source equivalence unverified |
| warehouse_capability_based_authorization | 20261104112545 | 20261104112545 | exact version overlap |
| warehouse_country_catalog_validation | 20261104112326 | 20261104112326 | exact version overlap |
| warehouse_end_to_end_task_and_evidence_runtime | 20261104111128 | 20261104111128 | exact version overlap |
| warehouse_facility_capability_eligibility | 20261104112614 | 20261104112614 | exact version overlap |
| warehouse_facility_registration_and_review | 20261104110654 | 20261104110654 | exact version overlap |
| warehouse_foreign_key_index_coverage | 20261104112216 | 20261104112216 | exact version overlap |
| warehouse_inventory_read_scope | 20261104111553 | 20261104111553 | exact version overlap |
| warehouse_maker_checker_release_gate | 20261105064301 | 20261105064301 | exact version overlap |
| warehouse_movement_permission_guard | 20261104112132 | 20261104112132 | exact version overlap |
| warehouse_prevent_direct_putaway_qty_change | 20261104111638 | 20261104111638 | exact version overlap |
| warehouse_quality_maker_checker | 20261105130000 | 20261105064220 | same suffix only; SQL/source equivalence unverified |
| warehouse_receipt_write_lockdown | 20261104111213 | 20261104111213 | exact version overlap |
| warehouse_shipment_leg_linkage | 20261106140000 | 20261105070814 | same suffix only; SQL/source equivalence unverified |

## Repository-only migration versions
| Version | Suffix |
|---|---|
| 20261017120000 | enforce_payment_provider_reference_idempotency |
| 20261017133000 | enforce_revenue_allocation_idempotency |
| 20261017134500 | enforce_partner_payable_assignment_idempotency |
| 20261017140000 | deny_client_access_internal_intake_tables |
| 20261019000100 | fail_closed_tariff_quotes_without_approved_rate_cards |
| 20261019093000 | cashfree_payment_provider |
| 20261019100000 | restore_rate_card_backed_tariff_quotes |
| 20261020133000 | partner_account_modes_test_and_individual_interest |
| 20261020134500 | harden_partner_account_mode_validation |
| 20261020135500 | support_registered_business_mode_transition |
| 20261020141000 | add_partner_account_mode_column |
| 20261022113000 | global_currency_precision_and_payment_capabilities |
| 20261023110000 | enable_authenticated_customer_coverage_requests |
| 20261024080000 | krim_warehouse_core_operations |
| 20261024090000 | krim_warehouse_atomic_inventory_movements |
| 20261024091500 | krim_warehouse_lock_movement_writes_to_rpc |
| 20261024092000 | krim_warehouse_reject_nan_quantities |
| 20261024100000 | krim_global_operations_records_backend |
| 20261025100000 | krim_inquiry_followup_history |
| 20261025113000 | assign_locations_to_existing_active_markets |
| 20261025143000 | harden_partner_verification_approval_evidence |
| 20261025143500 | enforce_active_markets_for_shipment_booking |
| 20261025150000 | krim_ensure_initial_shipment_leg |
| 20261025150000 | seed_country_localization_and_units |
| 20261025161000 | seed_inactive_global_country_catalogue_baseline |
| 20261025162500 | seed_complete_iso3166_alpha2_country_catalogue |
| 20261025170000 | require_explicit_transport_mode_for_tariff_quotes |
| 20261025180000 | require_transport_mode_for_partner_opportunities |
| 20261025193000 | enforce_market_activation_for_tariff_quotes |
| 20261026050000 | block_development_test_partner_quotes |
| 20261026050100 | block_development_test_partner_awards |
| 20261104133000 | secure_partner_business_verification |
| 20261104150000 | partner_capability_review_workflow |
| 20261104153000 | admin_list_partner_capabilities |
| 20261104153500 | require_verified_partner_capability |
| 20261104160000 | enforce_mfa_partner_capability_review |
| 20261104170000 | secure_partner_verification_document_review |
| 20261104170500 | capacity_resource_requires_verified_country_capability |
| 20261104173000 | lockdown_legacy_partner_fleet_and_driver_tables |
| 20261104180000 | guard_driver_profile_verification_updates |
| 20261104180500 | enforce_pending_driver_profile_creation |
| 20261104183500 | secure_legacy_partner_invitation_response |
| 20261104184500 | driver_document_admin_review_workflow |
| 20261104190000 | allow_driver_profile_transfer_on_valid_invitation |
| 20261104190000 | driver_carrier_invitation_and_membership_workflow |
| 20261104190000 | driver_verification_documents_and_review |
| 20261104190000 | partner_route_scope_and_driver_verification |
| 20261104190500 | tighten_driver_document_organization_scope |
| 20261104191500 | align_driver_review_with_invitation_gates |
| 20261104191500 | require_confirmed_email_for_driver_invitation |
| 20261104192000 | lock_driver_onboarding_mode |
| 20261104192500 | fix_driver_invitation_profile_branch |
| 20261104192500 | scope_driver_document_upload_to_pending_profile |
| 20261104193000 | reverify_driver_after_identity_changes |
| 20261104193000 | secure_driver_membership_invitations |
| 20261104194000 | remove_user_metadata_driver_invitation_gate |
| 20261104194500 | secure_driver_profile_transfer_on_invitation |
| 20261104195000 | retire_legacy_driver_invitation_creator |
| 20261104195500 | rate_limit_and_validate_carrier_driver_invitations |
| 20261104200000 | tighten_driver_verification_approval |
| 20261104201500 | allow_cleanup_unregistered_driver_uploads |
| 20261104203000 | expand_global_language_currency_locale_catalogues |
| 20261104204500 | add_authenticated_krim_ai_rate_limit |
| 20261104205000 | krim_global_market_readiness_registry |
| 20261104213000 | krim_regulatory_source_verification_workflow |
| 20261104214500 | krim_regulatory_source_review_transition_guard |
| 20261104220000 | krim_global_country_operating_pack_engine |
| 20261104221500 | krim_country_pack_status_approval_controls |
| 20261104223000 | krim_country_pack_admin_mobile_performance |
| 20261104223000 | krim_enforce_market_activation_on_shipment_creation |
| 20261104224500 | krim_market_activation_requires_professional_opinions |
| 20261104230000 | krim_global_corridor_compliance_engine |
| 20261104230000 | krim_unify_market_activation_booking_gate |
| 20261104231500 | krim_enforce_market_activation_shipment_trigger |
| 20261104233000 | krim_admin_corridor_catalogue_rpc |
| 20261104234500 | seed_india_domestic_pilot_corridor_candidate |
| 20261104234500 | seed_proposed_corridor_catalogue |
| 20261104235000 | add_missing_foreign_key_indexes |
| 20261104235500 | optimize_driver_document_rls_auth_calls |
| 20261105001500 | enforce_corridor_dossier_on_shipment_writes |
| 20261105062300 | enforce_aal2_on_admin_inquiry_followup |
| 20261105071000 | retire_legacy_pod_documents_bucket_policies |
| 20261105072000 | retire_legacy_shipment_pod_document_policies |
| 20261105080000 | secure_support_ticket_conversation_and_admin_workflow |
| 20261105090000 | index_recent_driver_vehicle_warehouse_foreign_keys |
| 20261105092200 | prevent_customer_country_catalogue_activation |
| 20261105094500 | consolidate_shipment_read_policies_without_access_change |
| 20261105100500 | consolidate_finance_and_exception_read_policies |
| 20261105102000 | consolidate_customs_record_read_policy |
| 20261105102900 | enforce_aal2_on_global_rate_card_admin_rpcs |
| 20261105103000 | persist_quote_expiry_on_accept_attempt |
| 20261105104500 | consolidate_marketplace_shipment_finance_read_policies |
| 20261105110000 | consolidate_legacy_shipment_read_policies |
| 20261105113000 | lock_booking_readiness_and_anon_reads |
| 20261105114500 | enable_secured_customer_shipment_booking_rpc |
| 20261105123500 | harden_warehouse_evidence_registration |
| 20261105130000 | warehouse_quality_maker_checker |
| 20261105133000 | prevent_mixed_quality_lot_receipts |
| 20261105140000 | customer_access_verified_pod_evidence |
| 20261105150000 | secure_booking_readiness_and_anon_reads |
| 20261105150640 | require_shipment_create_permission_for_global_tariff_reads |
| 20261105150700 | require_verified_partner_for_partner_rate_card_reads |
| 20261105153000 | add_evidence_backed_partner_capability_submission |
| 20261105153000 | enforce_partner_quote_create_permission |
| 20261105153100 | align_capability_approval_status_values |
| 20261105153200 | persist_partner_capability_submission_details |
| 20261105153300 | scope_partner_capability_reads_to_own_organization |
| 20261105153400 | correct_capability_review_status_guard_replacement |
| 20261105153500 | remove_duplicate_partner_capability_read_policy |
| 20261105153600 | require_country_for_partner_capability_coverage |
| 20261105153700 | require_active_country_for_partner_capability |
| 20261105160000 | scope_partner_marketplace_reads_to_verified_capability |
| 20261105162000 | require_evidence_and_active_coverage_for_capability_approval |
| 20261105163000 | enrich_partner_capability_admin_review_context |
| 20261105164000 | make_capability_evidence_array_validation_type_safe |
| 20261105170000 | complete_iso3166_alpha3_country_codes |
| 20261105171000 | expand_global_currency_reference_catalogue |
| 20261105172000 | expand_iso639_language_catalogue |
| 20261105173000 | align_currency_minor_units_with_iso4217 |
| 20261105174000 | populate_global_country_defaults |
| 20261105175000 | seed_global_primary_locale_catalogue |
| 20261105181000 | lockdown_commercial_pricing_table_writes |
| 20261105183000 | require_evidence_for_commercial_rate_activation |
| 20261105184500 | require_approved_rates_in_all_quote_paths |
| 20261105192000 | apply_domestic_rate_and_tax_evidence_guards |
| 20261105193000 | add_quote_pricing_snapshot_column |
| 20261105194000 | persist_tariff_quote_price_snapshot |
| 20261105200000 | require_current_partner_compliance_for_commercial_actions |
| 20261105203000 | gate_partner_marketplace_reads_on_current_compliance |
| 20261105210000 | partner_compliance_evidence_submission |
| 20261105211000 | support_partner_compliance_not_applicable_declarations |
| 20261105212000 | normalize_compliance_evidence_filename_validation |
| 20261105213000 | exclude_restricted_partners_from_compliance_queue |
| 20261105214000 | enforce_one_current_compliance_evidence_per_check |
| 20261105233000 | correct_pod_submission_leg_and_tracking_status |
| 20261105235000 | link_driver_assignments_to_partner_legs |
| 20261105240000 | require_verified_pod_before_driver_delivery_completion |
| 20261106001500 | add_authenticated_driver_pod_submission |
| 20261106010000 | add_admin_pod_verification_and_delivery_authorization |
| 20261106013000 | scope_operational_milestones_to_assigned_partner_leg |
| 20261106110000 | revoke_direct_execution_of_dispatch_trigger |
| 20261106140000 | warehouse_shipment_leg_linkage |
| 20261106150000 | linked_inbound_receiving_workflow |
| 20261106151000 | scope_warehouse_leg_lookup |
| 20261106152000 | expose_shipment_context_in_warehouse_queue |
| 20261106160000 | create_customs_broker_assignment_foundation |
| 20261106160000 | linked_goods_receipt_workflow |
| 20261106170000 | linked_pick_pack_and_handover |
| 20261106180000 | driver_assignment_acceptance_gate |
| 20261106180000 | operations_dispatch_readiness_register |
| 20261106181000 | fail_closed_dispatch_capability_check |
| 20261106190000 | driver_assignment_leg_integrity |
| 20261106190000 | global_vehicle_registry_foundation |
| 20261106200000 | vehicle_document_submission |
| 20261106210000 | independent_vehicle_verification |
| 20261106220000 | driver_vehicle_compatibility |
| 20261106223000 | driver_vehicle_readiness_rpc |
| 20261106230000 | dispatch_readiness_vehicle_compatibility |
| 20261107090000 | separate_partner_verification_from_compliance_activation |
| 20261107091000 | enrich_partner_verification_queue_account_and_compliance_state |
| 20261107093000 | partner_compliance_review_workflow |
| 20261107093100 | harden_partner_compliance_review_input_validation |
| 20261107103000 | restrict_anonymous_customs_and_shipment_document_reads |
| 20261107110000 | scope_customs_and_exception_reads_until_broker_assignment |
| 20261107120000 | customs_broker_assignment_workflows |
| 20261107130000 | customs_broker_license_evidence_and_review |
| 20261107140000 | enforce_customs_broker_jurisdiction_license |
| 20261107141000 | scope_customs_broker_license_evidence |
| 20261107142000 | tighten_customs_broker_assignment_reads |
| 20261107143000 | fix_customs_license_row_scope |
| 20261107144000 | tighten_customs_license_event_scope |
| 20261107150000 | customs_shipment_document_tables |
| 20261107151000 | customs_document_submission_and_review_rpcs |
| 20261107152000 | customs_document_storage_and_broker_read_policies |
| 20261107170000 | customs_jurisdiction_requirement_register |
| 20261107171000 | scope_customs_requirements_read_access |
| 20261107180000 | enforce_customs_broker_jurisdiction_licences |
| 20261107181000 | harden_customs_broker_license_review |
| 20261107182000 | harden_customs_broker_assignment_lifecycle |
| 20261107183000 | harden_customs_broker_license_submission |
| 20261107184000 | scope_customs_broker_license_storage |
| 20261107185000 | customs_broker_assignment_admin_control_desk |
| 20261107185100 | customs_broker_assignment_admin_control_desk_followup |
| 20261107190000 | harden_customs_document_evidence_controls |
| 20261107191000 | harden_customs_broker_assignment_close |
| 20261107200000 | secure_claim_submission_evidence_and_review |
| 20261107201000 | restrict_claims_to_confirmed_shipments |
| 20261107210000 | restrict_direct_finance_table_writes |
| 20261107211000 | scope_financial_reconciliation_reads |
| 20261107220000 | secure_refund_request_workflow |
| 20261107221000 | harden_dispute_register_access |
| 20261107222000 | limit_refund_requests_to_unreconciled_paid_orders |
| 20261107230000 | initialize_finance_chart_of_accounts_inr |
| 20261111100000 | require_dispatch_proof_before_warehouse_handover |
| 20261111120000 | secure_global_quote_acceptance_partner_assignment |
| 20261111130000 | restrict_customer_pod_reads_to_verified_evidence |
| 20261111160000 | record_public_inquiry_privacy_consent |
| 20261111190000 | record_customer_signup_terms_consent |
| 20261111200000 | partner_capability_queue_requires_private_evidence |

## Production-only migration versions
| Version | Suffix |
|---|---|
| 20260929043657 | add_global_partner_lifecycle |
| 20260929043720 | add_partner_verification_cases |
| 20260929043749 | add_partner_global_service_areas |
| 20260929043823 | harden_partner_capacity_and_capabilities |
| 20260929043915 | add_partner_rfq_and_quotes |
| 20260929043924 | harden_partner_rfq_rls |
| 20260929043958 | add_partner_matching_engine |
| 20260929044040 | add_shipment_partner_assignments |
| 20260929044047 | add_partner_assignment_audit_trigger |
| 20260929044110 | add_partner_execution_events |
| 20260929044134 | add_partner_pod_workflow |
| 20260929044200 | add_partner_payables |
| 20260929044229 | add_partner_performance_metrics |
| 20260929044257 | harden_partner_exception_claim_links |
| 20260929044329 | add_global_support_workflow |
| 20260929044351 | harden_global_notification_delivery |
| 20260929044417 | harden_global_workflow_automation |
| 20260929044445 | harden_global_integration_gateway |
| 20260929044513 | add_global_api_security_gateway |
| 20260929044541 | add_global_data_governance |
| 20260929044612 | harden_global_compliance_engine |
| 20260929044642 | add_global_localization_engine |
| 20260929044710 | add_global_financial_ledger_reconciliation |
| 20260929044737 | harden_global_reliability_recovery |
| 20260929044955 | add_global_developer_api_platform |
| 20260929123811 | harden_workflow_retry_dlq_runtime |
| 20260929123844 | fix_workflow_action_lease_uuid |
| 20260929123918 | fix_workflow_retry_release_reclaim |
| 20260929124044 | complete_workflow_dlq_replay_queueing |
| 20260929124117 | fix_workflow_replay_action_sequence |
| 20260929124419 | close_legacy_public_write_paths |
| 20260929124519 | tighten_api_role_table_privileges |
| 20260929124548 | remove_verified_duplicate_indexes |
| 20260929124556 | add_missing_fk_indexes |
| 20260929125946 | global_finance_payment_application_hardening |
| 20260929131810 | final_rls_auth_initplan_hardening |
| 20261011160736 | activate_krim_workflow_runtime_scheduler |
| 20261011160819 | fix_workflow_dispatch_materialization_record_shadowing |
| 20261011160857 | fix_workflow_dispatch_event_uuid_mapping |
| 20261011160928 | fix_workflow_run_step_idempotent_materialization |
| 20261011161003 | fix_workflow_action_idempotency_without_missing_constraint |
| 20261011161032 | remove_unsupported_workflow_run_conflict_target |
| 20261011161121 | repair_workflow_retry_statuses_and_timestamp_order |
| 20261011161148 | schedule_krim_workflow_runtime |
| 20261011161356 | consolidate_redundant_api_and_webhook_rls_policies |
| 20261011161431 | enable_pg_net_for_future_edge_function_integrations |
| 20261011161742 | complete_workflow_action_dead_letter_quarantine_and_retry_runtime |
| 20261011161842 | fix_workflow_dlq_event_column_mapping |
| 20261011162418 | least_privilege_krim_table_grants |
| 20261011162547 | restore_only_rls_authorized_krim_write_grants |
| 20261011162831 | harden_partner_matching_for_verified_route_coverage |
| 20261011162908 | store_krim_project_url_in_vault |
| 20261011163139 | add_platform_admin_policies_for_partner_ops_and_workflow_monitoring |
| 20261011163256 | consolidate_platform_admin_and_org_rls_policies |
| 20261011163341 | enable_platform_admin_global_growth_registry_access |
| 20261011163552 | add_global_growth_signal_processing_worker |
| 20261011163839 | enable_platform_admin_growth_signal_intake |
| 20261011164218 | implement_approved_workflow_dead_letter_replay_pipeline |
| 20261011164518 | fix_dlq_upsert_for_replayed_action_failures |
| 20261011164550 | fix_partial_unique_index_target_for_dlq_upsert |
| 20261011164952 | make_krim_authorize_invoker_only |
| 20261011182214 | tighten_legacy_payment_and_audit_grants |
| 20261011183331 | phase1_restrict_sensitive_browser_reads |
| 20261011183736 | phase1_remove_anonymous_grants_admin_observability |
| 20261011183957 | phase1_isolate_security_definer_authorization_helpers |
| 20261011184123 | phase1_harden_postgres_default_privileges |
| 20261014220717 | krim_customer_org_provisioning |
| 20261016042526 | repair_customer_org_provisioning_and_add_partner_signup |
| 20261016042645 | secure_partner_onboarding_documents_and_submission |
| 20261016042719 | restrict_partner_document_uploads_to_member_folder |
| 20261016043934 | scope_support_tickets_to_authorized_organizations |
| 20261016044251 | harden_service_role_policies_and_partner_marketplace |
| 20261016044846 | complete_customer_partner_quote_and_assignment_lifecycle |
| 20261016051620 | partner_award_customer_checkout |
| 20261016052036 | payment_order_quote_binding |
| 20261016052430 | add_secure_public_tracking_tokens |
| 20261016053738 | krim_customer_checkout_rpc_security_20261016 |
| 20261016055515 | index_payment_order_foreign_keys |
| 20261016055535 | optimize_revenue_ledger_rls_policy |
| 20261016115053 | account_security_requests_and_consent_events |
| 20261016115358 | restrict_recovery_checkpoint_api_access |
| 20261016115619 | create_public_contact_inquiries |
| 20261017054157 | enforce_payment_provider_reference_idempotency |
| 20261017081423 | enforce_revenue_allocation_idempotency |
| 20261017081547 | enforce_partner_payable_assignment_idempotency |
| 20261017081634 | deny_client_access_internal_intake_tables |
| 20261018184828 | fix_partner_onboarding_document_extension_validation |
| 20261018190843 | fail_closed_tariff_quotes_without_approved_rate_cards |
| 20261019043638 | restore_rate_card_backed_tariff_quotes |
| 20261019150820 | expand_krim_audit_source_constraint_for_valid_workflows |
| 20261019151634 | seed_global_location_catalog |
| 20261019155945 | expand_krim_audit_sources_for_workflows |
| 20261019160148 | seed_noncommercial_draft_rate_card_template |
| 20261020075927 | partner_account_modes_test_and_individual_interest |
| 20261020080120 | harden_partner_account_mode_validation |
| 20261020080213 | support_registered_business_mode_transition |
| 20261020080517 | add_partner_account_mode_column |
| 20261020192326 | provision_driver_workspace_on_first_signin |
| 20261020192401 | create_secure_driver_profile |
| 20261020192647 | driver_workspace_assignments_events_and_private_evidence |
| 20261020192711 | driver_authorized_trip_event_rpc |
| 20261020192833 | tighten_driver_assignment_membership_checks |
| 20261020195319 | secure_driver_dispatch_assignment_workflow |
| 20261020195450 | fix_driver_dispatch_legacy_shipment_link |
| 20261020195543 | require_pod_before_driver_delivery_milestone |
| 20261020210644 | allow_finance_organization_type |
| 20261020211606 | allow_operations_workspace_organization_type |
| 20261022042712 | add_global_place_shipment_intake |
| 20261022042820 | validate_global_place_coordinates |
| 20261022043334 | add_global_transport_mode_preference |
| 20261022043620 | complete_global_route_metadata_and_partner_mode |
| 20261022043739 | route_tariff_quotes_by_requested_transport_mode |
| 20261022043755 | add_global_route_type_preference |
| 20261022043805 | include_route_type_in_partner_opportunities |
| 20261022043836 | include_global_route_details_in_tariff_audit |
| 20261022043946 | validate_global_route_type_server_side |
| 20261022045656 | add_idempotent_global_shipment_booking |
| 20261022052843 | retire_cashfree_keep_razorpay_only |
| 20261022053612 | global_payment_provider_capability_registry |
| 20261022053743 | canonical_payment_transaction_ledger |
| 20261022053935 | extend_canonical_payments_for_future_adapters |
| 20261022062800 | krim_authenticated_tracking_and_operational_milestones |
| 20261022102735 | create_global_payment_capability_registry |
| 20261022102945 | deny_client_access_to_payment_capability_registry |
| 20261023191959 | krim_global_operations_records_backend |
| 20261024072613 | add_role_scoped_cross_workspace_read_policies |
| 20261024072632 | add_customs_exception_read_policy |
| 20261024081234 | krim_warehouse_core_operations |
| 20261024082030 | krim_warehouse_atomic_inventory_movements |
| 20261024082117 | krim_warehouse_atomic_inventory_movements |
| 20261024082353 | krim_warehouse_lock_movement_writes_to_rpc |
| 20261024082605 | krim_warehouse_reject_nan_quantities |
| 20261024224951 | krim_inquiry_followup_history |
| 20261025075201 | global_payment_provider_roadmap_registry |
| 20261025110256 | assign_locations_to_existing_active_markets |
| 20261025110931 | krim_ensure_initial_shipment_leg |
| 20261025112213 | harden_partner_verification_approval_evidence |
| 20261025112519 | krim_ensure_initial_shipment_leg |
| 20261025112942 | require_explicit_transport_mode_for_tariff_quotes |
| 20261025113146 | require_transport_mode_for_partner_opportunities |
| 20261025144225 | seed_inactive_global_country_catalogue_baseline |
| 20261025144507 | seed_complete_iso3166_alpha2_country_catalogue |
| 20261025154450 | enforce_market_activation_for_tariff_quotes |
| 20261026044130 | block_development_test_partner_quotes |
| 20261026044300 | block_development_test_partner_awards |
| 20261104085938 | partner_capability_review_workflow |
| 20261104090159 | admin_list_partner_capabilities |
| 20261104090554 | enforce_mfa_partner_capability_review |
| 20261104113759 | capacity_resource_requires_verified_country_capability |
| 20261104114904 | lockdown_legacy_partner_fleet_and_driver_tables |
| 20261104120817 | guard_driver_profile_verification_changes |
| 20261104120833 | enforce_pending_driver_profile_creation |
| 20261104121351 | create_driver_verification_document_registry |
| 20261104121359 | secure_driver_verification_document_policies |
| 20261104121409 | add_admin_driver_verification_queue |
| 20261104121423 | add_admin_driver_verification_review |
| 20261104121709 | tighten_driver_document_organization_scope |
| 20261104122217 | secure_driver_membership_invitation_flow |
| 20261104122233 | fix_driver_invitation_email_validation |
| 20261104122454 | harden_driver_invitation_membership_and_rate_limits |
| 20261104122737 | allow_secure_driver_profile_rehome_on_invitation |
| 20261104122916 | tighten_driver_verification_approval_requirements |
| 20261104123212 | allow_cleanup_of_unregistered_driver_uploads |
| 20261104123850 | driver_carrier_invitation_and_membership_workflow |
| 20261104124749 | require_confirmed_email_for_driver_invitation |
| 20261104125024 | lock_driver_onboarding_mode_and_invitation_acceptance |
| 20261104125108 | fix_driver_invitation_profile_branch |
| 20261104125300 | remove_user_metadata_driver_invitation_gate |
| 20261104125738 | retire_legacy_driver_invitation_creator |
| 20261104130310 | rate_limit_and_validate_carrier_driver_invitations |
| 20261104132256 | driver_document_admin_review_workflow |
| 20261104132749 | allow_driver_profile_org_change_on_valid_invitation |
| 20261104133139 | align_driver_review_with_carrier_invitation_gates |
| 20261104134336 | reverify_driver_after_identity_changes |
| 20261104134348 | scope_driver_document_upload_to_pending_profile |
| 20261104145939 | expand_global_language_currency_locale_catalogues |
| 20261104150628 | add_authenticated_krim_ai_rate_limit |
| 20261104152205 | krim_global_market_readiness_registry |
| 20261104152610 | krim_regulatory_source_verification_workflow |
| 20261104152655 | krim_regulatory_source_review_transition_guard |
| 20261104153013 | krim_fail_closed_market_activation_engine |
| 20261104153026 | krim_enforce_market_activation_on_shipment_creation |
| 20261104153126 | krim_market_activation_requires_professional_opinions |
| 20261104153210 | krim_unify_market_activation_booking_gate |
| 20261104153318 | krim_enforce_market_activation_shipment_trigger |
| 20261104153916 | krim_global_country_operating_pack_engine |
| 20261104153942 | krim_country_pack_status_approval_controls |
| 20261104154412 | krim_country_pack_admin_mobile_performance |
| 20261104155247 | 20261104230000_krim_global_corridor_compliance_engine |
| 20261104155624 | 20261104233000_krim_admin_corridor_catalogue_rpc |
| 20261104155958 | 20261104234500_seed_proposed_corridor_catalogue |
| 20261104160356 | 20261105001500_enforce_corridor_dossier_on_shipment_writes |
| 20261104163154 | 20261104234500_seed_india_domestic_pilot_corridor_candidate |
| 20261104163805 | 20261104235000_add_missing_foreign_key_indexes |
| 20261104163816 | 20261104235500_optimize_driver_document_rls_auth_calls |
| 20261105035725 | prevent_customer_country_catalogue_activation |
| 20261105035810 | persist_quote_expiry_on_accept_attempt |
| 20261105040557 | enable_secured_customer_shipment_booking_rpc |
| 20261105040938 | secure_booking_readiness_and_anon_reads |
| 20261105041122 | enforce_partner_quote_create_permission |
| 20261105041425 | scope_partner_marketplace_reads_to_verified_capability |
| 20261105042437 | complete_iso3166_alpha3_country_codes |
| 20261105042503 | expand_global_currency_reference_catalogue |
| 20261105042524 | expand_iso639_language_catalogue |
| 20261105042823 | populate_global_country_defaults |
| 20261105042912 | seed_global_primary_locale_catalogue |
| 20261105043634 | lockdown_commercial_pricing_table_writes |
| 20261105044223 | require_evidence_for_commercial_rate_activation |
| 20261105044458 | require_approved_rates_in_all_quote_paths |
| 20261105045815 | apply_domestic_rate_and_tax_evidence_guards |
| 20261105045924 | add_quote_pricing_snapshot_column |
| 20261105045951 | persist_tariff_quote_price_snapshot |
| 20261105050623 | enforce_aal2_on_global_rate_card_admin_rpcs |
| 20261105055330 | correct_pod_submission_leg_and_tracking_status |
| 20261105055543 | link_driver_assignments_to_partner_legs |
| 20261105055723 | add_authenticated_driver_pod_submission |
| 20261105060011 | add_admin_pod_verification_and_delivery_authorization |
| 20261105060505 | scope_operational_milestones_to_assigned_partner_leg |
| 20261105061144 | require_verified_pod_before_driver_delivery_completion |
| 20261105062347 | enforce_aal2_on_admin_inquiry_followup |
| 20261105062612 | retire_legacy_pod_documents_bucket_policies |
| 20261105062635 | retire_legacy_shipment_pod_document_policies |
| 20261105062956 | secure_support_ticket_conversation_and_admin_workflow |
| 20261105063932 | harden_warehouse_evidence_registration |
| 20261105064220 | warehouse_quality_maker_checker |
| 20261105064750 | prevent_mixed_quality_lot_receipts |
| 20261105065238 | customer_access_verified_pod_evidence |
| 20261105070135 | 20261106110000_revoke_direct_execution_of_dispatch_trigger |
| 20261105070814 | warehouse_shipment_leg_linkage |
| 20261105071020 | linked_inbound_receiving_workflow |
| 20261105071039 | scope_warehouse_leg_lookup_to_approved_facility |
| 20261105071132 | expose_shipment_leg_context_in_warehouse_task_queue |
| 20261105071537 | 20261106160000_linked_goods_receipt_workflow |
| 20261105071833 | 20261106170000_linked_pick_pack_and_handover |
| 20261105072311 | 20261106180000_operations_dispatch_readiness_register |
| 20261105072410 | 20261106181000_fail_closed_dispatch_capability_check |
| 20261105072546 | 20261106190000_driver_assignment_leg_integrity |
| 20261105072829 | driver_assignment_acceptance_gate |
| 20261105073241 | global_vehicle_registry_foundation |
| 20261105075808 | driver_vehicle_compatibility |
| 20261105075814 | driver_vehicle_readiness_rpc |
| 20261105075821 | dispatch_readiness_vehicle_compatibility |
| 20261105081928 | index_recent_driver_vehicle_warehouse_foreign_keys |
| 20261105082059 | consolidate_shipment_read_policies_without_access_change |
| 20261105082138 | consolidate_finance_and_exception_read_policies |
| 20261105082209 | consolidate_customs_record_read_policy |
| 20261105082301 | consolidate_marketplace_shipment_finance_read_policies |
| 20261105082340 | consolidate_legacy_shipment_read_policies |
| 20261105084920 | restrict_partner_invitation_and_capacity_commitment_writes |
| 20261105085118 | require_active_organization_for_workspace_access |
| 20261105150709 | require_shipment_create_permission_for_global_tariff_reads |
| 20261105150918 | require_verified_partner_for_partner_rate_card_reads |
| 20261105151950 | add_evidence_backed_partner_capability_submission |
| 20261105152017 | align_capability_approval_status_values |
| 20261105152048 | persist_partner_capability_submission_details |
| 20261105152404 | scope_partner_capability_reads_to_own_organization |
| 20261105152513 | correct_capability_review_status_guard_replacement |
| 20261105152555 | remove_duplicate_partner_capability_read_policy |
| 20261105152608 | require_evidence_and_active_coverage_for_capability_approval |
| 20261105152706 | require_country_for_partner_capability_coverage |
| 20261105152843 | enrich_partner_capability_admin_review_context |
| 20261105152844 | require_active_country_for_partner_capability |
| 20261105152958 | make_capability_evidence_array_validation_type_safe |
| 20261105154408 | separate_partner_verification_from_compliance_activation |
| 20261105154430 | enrich_partner_verification_queue_account_and_compliance_state |
| 20261105154654 | partner_compliance_review_workflow |
| 20261105154704 | harden_partner_compliance_review_input_validation |
| 20261105155207 | require_current_partner_compliance_for_commercial_actions |
| 20261105155336 | gate_partner_marketplace_reads_on_current_compliance |
| 20261105155537 | partner_compliance_evidence_submission |
| 20261105155604 | support_partner_compliance_not_applicable_declarations |
| 20261105155756 | enforce_one_current_compliance_evidence_per_check |
| 20261106044136 | restrict_anonymous_customs_and_shipment_document_reads |
| 20261106044259 | scope_customs_and_exception_reads_until_broker_assignment |
| 20261106044553 | create_customs_broker_assignment_foundation |
| 20261106044728 | customs_broker_assignment_rpc_lifecycle |
| 20261106044751 | harden_customs_broker_rpc_and_event_access |
| 20261106044857 | scope_customs_broker_assignment_actors_to_shipment |
| 20261106045100 | customs_broker_license_evidence_and_review |
| 20261106045239 | enforce_jurisdiction_license_on_broker_acceptance |
| 20261106045250 | scope_customs_broker_license_evidence_to_org_members |
| 20261106045316 | tighten_customs_broker_assignment_read_permissions |
| 20261106045345 | fix_customs_license_row_scope |
| 20261106045357 | tighten_customs_license_event_read_scope |
| 20261106052501 | secure_claim_submission_evidence_and_review |
| 20261106052736 | restrict_claims_to_confirmed_shipments |
| 20261106053227 | restrict_direct_finance_table_writes |
| 20261106053254 | scope_financial_reconciliation_reads |
| 20261106053726 | secure_refund_request_workflow |
| 20261106053929 | harden_dispute_register_access |
| 20261106054019 | limit_refund_requests_to_unreconciled_paid_orders |
| 20261106054504 | initialize_finance_chart_of_accounts_inr |
| 20261106061712 | align_partner_verification_approval_org_types |
| 20261106061909 | bind_partner_compliance_review_to_current_evidence |
| 20261106062238 | harden_driver_org_provisioning_context |
| 20261106062325 | prevent_driver_profile_approval_bypass |
| 20261106062414 | require_active_org_for_verification_storage |
| 20261106062511 | tighten_driver_evidence_storage_membership |
| 20261106062610 | harden_vehicle_document_registration |
| 20261106062651 | require_accepted_driver_licence_for_dispatch_listing |
| 20261106063513 | synchronize_driver_trip_events_with_shipment_tracking |
| 20261106063653 | publish_driver_trip_events_to_partner_execution_feed |
| 20261106063730 | unify_shipment_leg_status_lifecycle |
| 20261106063837 | harden_shipment_alert_audit_trigger |
| 20261106064001 | index_open_exception_escalation_queues |
| 20261106064038 | add_controlled_due_exception_escalation_processor |
| 20261106064115 | schedule_krim_exception_escalation_worker |
| 20261106064220 | add_audited_exception_acknowledgement_and_resolution |
| 20261106064434 | bridge_operational_exceptions_to_control_tower |
| 20261106064543 | create_control_tower_snapshot_refresh_function |
| 20261106064549 | attach_exception_snapshot_refresh_trigger |
| 20261106064555 | attach_alert_snapshot_refresh_trigger |
| 20261106064601 | attach_shipment_snapshot_refresh_trigger |
| 20261106064623 | seed_initial_control_tower_shipment_snapshots |
| 20261106064737 | add_authorized_operations_snapshot_read_rpc |
| 20261106064947 | harden_customs_broker_response_search_path |
| 20261106065020 | harden_customs_document_submit_active_org_and_path |
| 20261106065116 | harden_customs_document_review_search_path |
| 20261106065123 | harden_customs_license_review_search_path |
| 20261106065134 | standardize_customs_rpc_wrapper_search_paths |
| 20261106065246 | harden_customs_assignment_rpc_search_paths |
| 20261106065347 | harden_shipment_customs_audit_trigger |
| 20261106065440 | harden_customer_shipment_creation_search_paths |
| 20261106065521 | create_authorized_customer_customs_case_rpc |
| 20261106065529 | restrict_customer_customs_case_rpc_access |
| 20261106065536 | expose_customer_customs_case_rpc |
| 20261106065545 | grant_authenticated_customs_case_rpc |
| 20261106065613 | add_customs_case_update_audit_function |
| 20261106065619 | attach_customs_case_update_audit_trigger |
| 20261106065716 | add_authorized_customs_status_transition |
| 20261106065723 | expose_customs_status_transition_rpc |
| 20261106065737 | tighten_customs_transition_broker_authority |
| 20261106065856 | harden_customs_broker_license_submission_search_path |
| 20261106070132 | customs_submission_requires_approved_jurisdiction_rules |
| 20261106070621 | harden_partner_quote_award_integrity |
| 20261106072656 | ensure_capacity_commitment_on_assignment_acceptance |
| 20261106072844 | add_capacity_reservation_commitment_fk |
| 20261106073039 | sync_capacity_commitment_reservation_counters |
| 20261106073127 | attach_deterministic_capacity_commitment_to_reservations |
| 20261106073307 | add_lane_aware_partner_capacity_registration |
| 20261106073347 | add_lane_aware_capacity_admin_review_queue |
| 20261106073419 | guard_capacity_availability_lane_publication |
| 20261106073506 | enforce_independent_capacity_resource_review |
| 20261106075841 | enforce_partner_compliance_evidence_metadata |
| 20261106080114 | guard_partner_compliance_independent_review |
| 20261106080333 | harden_partner_capability_independent_review |
| 20261106080447 | enforce_independent_driver_document_review |
| 20261106080532 | enforce_independent_warehouse_facility_review |
| 20261106080632 | default_partner_service_areas_to_draft |
| 20261106080712 | add_partner_service_area_reference_integrity |
| 20261106080757 | constrain_partner_service_area_service_types |
| 20261106080912 | add_partner_service_area_submission_rpc |
| 20261106080958 | add_independent_partner_service_area_review |
| 20261106081014 | add_admin_partner_service_area_review_queue |
| 20261106081329 | restrict_service_area_admin_queue_to_pending_with_evidence |
| 20261106084043 | razorpay_captured_payment_finance_reconciliation |
| 20261106144806 | align_shipment_readiness_with_canonical_razorpay_ledger |
| 20261106191859 | add_self_scoped_ai_user_context |
| 20261111050237 | require_dispatch_proof_before_warehouse_handover |
| 20261111052116 | restrict_customer_pod_reads_to_verified_evidence |
| 20261111072758 | partner_capability_queue_requires_private_evidence |

## Important interpretation
- A matching descriptive suffix is only a search hint. It does not prove identical SQL, deployment order, object state or data effects.
- A different version with the same suffix may indicate a timestamp rewrite, manual deployment, a duplicate/equivalent migration, or a changed SQL body. Each case needs source/artifact evidence.
- Exact version overlap also needs SQL-body/hash comparison before it can be treated as fully reconciled.
- Production-only SQL must be recovered from an authoritative deployment artifact, backup or version-controlled source before claiming source parity.
- Repository-only migrations must be classified as unapplied, replaced, manually deployed under another version, or equivalent to another production migration.
- Do not use Supabase migration repair, db reset, migration up, or production DDL as a shortcut to force the histories to match.
- No production schema, data, migration history, payment settings or customer records were changed in this audit.