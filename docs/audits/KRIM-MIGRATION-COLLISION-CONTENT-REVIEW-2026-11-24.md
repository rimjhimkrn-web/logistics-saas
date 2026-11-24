# KRIM migration collision content review — 2026-11-24

## Scope

Read-only GitHub Contents API inspection of all 26 SQL files in the 13 duplicate-version groups listed in the migration baseline reconciliation report. The GitHub blob SHA is used as the content identity signal: identical file bytes produce the same blob SHA. Every file in each collision group returned a different blob SHA.

**Result: 13/13 version groups contain distinct SQL files; none of the 26 files is an exact byte-for-byte duplicate of its version-collision peer.** This confirms these are substantive replay-order collisions, not merely duplicate copies. Blob SHA is not a semantic SQL-equivalence test.

No SQL file was edited, renumbered, deleted, replayed or applied. No production schema or migration ledger was changed.

## Per-file content inventory

| Repository version | File stem | Characters | Git blob SHA |
|---|---|---:|---|
| 20261025150000 | krim_ensure_initial_shipment_leg | 2,326 | 46dd44b2cf3060144b4921148618e92615f99b35 |
| 20261025150000 | seed_country_localization_and_units | 217 | fab909f5d1911b83cbd464bd71be96cbe1d2adb3 |
| 20261104190000 | allow_driver_profile_transfer_on_valid_invitation | 2,140 | 1f4770bd220dc1e971a1a18e0afbf14250119b7f |
| 20261104190000 | driver_carrier_invitation_and_membership_workflow | 12,471 | 4b75d50d132d9dc29847410e55bb6d15e86b874f |
| 20261104190000 | driver_verification_documents_and_review | 8,656 | 13e9f31c7f3373aa72e4e0554d445499fb48fded |
| 20261104190000 | partner_route_scope_and_driver_verification | 12,299 | 389acac9cd82d26fd2acfe03ed4cc22f22f75e1c |
| 20261104191500 | align_driver_review_with_invitation_gates | 6,758 | 3355f7e79446c5237f6073e3a0e69b4748cd6d70 |
| 20261104191500 | require_confirmed_email_for_driver_invitation | 4,723 | ef132837465bb3a5defa04af6619fd64d6f33bda |
| 20261104192500 | fix_driver_invitation_profile_branch | 5,111 | f4bfbe8d65ee8ecb1bf064fdfde7c3f4b826d078 |
| 20261104192500 | scope_driver_document_upload_to_pending_profile | 597 | 495b398633356bd3910e62fea56c6aaab51dbc4b |
| 20261104193000 | reverify_driver_after_identity_changes | 3,312 | ed2a0da3a41b949409821094fd031e3425af034f |
| 20261104193000 | secure_driver_membership_invitations | 5,307 | 10d6dbf5780ebc234beb5db8a94e6e9c8be68649 |
| 20261104223000 | krim_country_pack_admin_mobile_performance | 2,949 | 1419f7379367514fc2e77c77a081cc25c86ecbba |
| 20261104223000 | krim_enforce_market_activation_on_shipment_creation | 3,010 | 3dd59773bde1ff84a37ffd7119bd2a717c271a5f |
| 20261104230000 | krim_global_corridor_compliance_engine | 21,192 | ecb385cc67f26cf7b5ac1378d3215115c65bc7ed |
| 20261104230000 | krim_unify_market_activation_booking_gate | 2,524 | d6cb5acd2cc60622cb67b46bb88a29f66e5ed892 |
| 20261104234500 | seed_india_domestic_pilot_corridor_candidate | 1,153 | 184ff4ab2490847403ceb6de0ca96a145246552b |
| 20261104234500 | seed_proposed_corridor_catalogue | 2,610 | a0669d9f8a81b68feb15ba11b3d697d69cac8a92 |
| 20261105153000 | add_evidence_backed_partner_capability_submission | 5,932 | b8f75e806b272d29c20fcdd76edce91a70207b88 |
| 20261105153000 | enforce_partner_quote_create_permission | 2,025 | 5d3df90c94cfba602f513c60e06d40a492c2fe52 |
| 20261106160000 | create_customs_broker_assignment_foundation | 2,261 | e92a4460df40daaa2d4428a5d861306d86ea04df |
| 20261106160000 | linked_goods_receipt_workflow | 5,214 | f916a4bd1b3bdde367d21c34665258c042fdb22e |
| 20261106180000 | driver_assignment_acceptance_gate | 6,282 | dac26acbf146e36def707235124fd7936b0b2e69 |
| 20261106180000 | operations_dispatch_readiness_register | 3,566 | 484882dde82e32612bd5c3ae899ad35d1656e550 |
| 20261106190000 | driver_assignment_leg_integrity | 5,672 | 9e089ed776277267b825e225afcb9fb748ae3ec1 |
| 20261106190000 | global_vehicle_registry_foundation | 7,282 | c2e850a41fc02fb88147ee8ced82af1236b9147f |
| 20261115151000 | require_all_driver_documents_for_verification | 6,782 | e581d071639585a189f2bb65e0330af07cd08bef |
| 20261115151000 | schedule_private_vehicle_evidence_expiry_worker | 2,746 | b218180b129009991cb3fc4f9e1afafdad4763e0 |

## Findings

1. Every duplicate-version group has more than one distinct SQL body. A migration runner keyed by the 14-digit version cannot deterministically apply every file in the repository group.
2. The `20261025150000_seed_country_localization_and_units.sql` file is a documented 217-character no-op/superseded marker. Its peer `20261025150000_krim_ensure_initial_shipment_leg.sql` is substantive (2,326 characters). The no-op does not make the shared version safe: the substantive file still collides with that version.
3. Several other same-version files implement unrelated functional areas (for example driver invitations, verification documents, partner route scope, customs assignment, warehouse receipts, driver assignment integrity, vehicle registry, and dispatch readiness). Their different blob SHAs confirm distinct contents; full semantic dependency analysis is still required.
4. This review does not establish which SQL changes are already present in production. Same-name/different-version entries, renamed migrations, squashed migrations, and schema-state equivalence remain unresolved.
5. The next safe step is to trace the historical commit sequence for each file, identify any superseding or combined production migration, then construct a replay set in an isolated Supabase project and compare schema objects and security posture.

## Decision

**Production DDL remains NO-GO.** Do not renumber, merge, delete, mark-applied or replay any migration based only on filename, timestamp, or blob SHA. The repository baseline must first be made deterministic and proven against a disposable database.