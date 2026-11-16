# KRIM Remaining Duplicate-Timestamp Migration Review
**Date:** 16 November 2026  
**Scope:** Static inspection of remaining duplicate timestamp groups and the duplicate foreign-key-index migration name. No production database changes.

## Executive result
A further ten migration files were inspected across six timestamp groups. They also contain distinct changes. The repository collision problem cannot be solved by arbitrarily selecting a file per timestamp.

## File fingerprints and semantic scope

| Timestamp | File | Git blob SHA | Bytes | Lines | Scope |
|---|---|---|---:|---:|---|
| 20261104191500 | align_driver_review_with_invitation_gates | 3355f7e79446c5237f6073e3a0e69b4748cd6d70 | 6,758 | 54 | Driver profile verification guard aligned with invitation acceptance |
| 20261104191500 | require_confirmed_email_for_driver_invitation | ef132837465bb3a5defa04af6619fd64d6f33bda | 4,723 | 44 | Driver invitation acceptance requires confirmed email |
| 20261104192500 | fix_driver_invitation_profile_branch | f4bfbe8d65ee8ecb1bf064fdfde7c3f4b826d078 | 5,111 | 50 | Corrected invitation acceptance profile branch |
| 20261104192500 | scope_driver_document_upload_to_pending_profile | 495b398633356bd3910e62fea56c6aaab51dbc4b | 597 | 11 | Restricts document upload to own pending profile and pending review |
| 20261104193000 | reverify_driver_after_identity_changes | ed2a0da3a41b949409821094fd031e3425af034f | 3,312 | 37 | Re-verification guard after driver identity changes |
| 20261104193000 | secure_driver_membership_invitations | 10d6dbf5780ebc234beb5db8a94e6e9c8be68649 | 5,307 | 60 | Expiring driver invitations tied to verified carrier organizations |
| 20261104234500 | seed_india_domestic_pilot_corridor_candidate | 184ff4ab2490847403ceb6de0ca96a145246552b | 1,153 | 18 | Draft Ranchi–Jamshedpur corridor candidate only |
| 20261104234500 | seed_proposed_corridor_catalogue | a0669d9f8a81b68feb15ba11b3d697d69cac8a92 | 2,610 | 17 | Proposed domestic/international corridor catalogue, draft only |
| 20261104235000 | add_missing_foreign_key_indexes | 6b37f6427ba5f38c4c89c5a2a2050fd983cf4980 | 1,561 | 13 | Indexes for corridor, country-pack and market-activation references |
| 20261115072000 | add_missing_foreign_key_indexes | a8e124bcd768d1ffd466418e7ba1b9d8ead44e3c | 2,991 | 28 | Separate indexes for capacity, claims, customs and related foreign keys |

## Findings

### 1. Driver invitation and identity controls are incremental, not interchangeable
The 04:19:15, 04:19:25 and 04:19:30 groups each contain two different changes. The functions/policies overlap the same driver onboarding lifecycle:
- invitation acceptance and confirmed email;
- invitation branch correction;
- pending-profile evidence upload;
- identity-change reverification;
- invitation expiry and verified carrier organization checks.

The correct live result depends on the combined sequence and final definitions, not one arbitrary migration selected for each timestamp. Replaying a historical definition could overwrite a stronger later guard.

### 2. Corridor seed migrations are separate catalogue data
Both 04:23:45 files insert proposed corridor records, including a domestic Ranchi–Jamshedpur candidate. Their comments and seeded statuses explicitly distinguish a draft catalogue candidate from an authorised route or live service. The existence of these seeds cannot be treated as route availability, partner coverage, legal approval or booking eligibility.

### 3. Duplicate logical index migration name is not duplicate content
The files named `add_missing_foreign_key_indexes` at 04:23:50 and 15:07:20 contain different index sets. The later file does not simply repeat the earlier list. Their timestamp and logical-name collision must be reconciled independently against `pg_indexes` and production migration history. Index equivalence should include table, indexed columns/order, predicate, uniqueness and validity; name-only comparison is insufficient.

## Updated collision assessment
This review adds evidence for:
- 6 further duplicate timestamp groups with distinct content;
- 1 repeated logical migration name with different index definitions;
- overlapping successive driver lifecycle definitions where migration order is security-relevant;
- proposed corridor seed data that must remain non-operational until separately approved.

The earlier report's overall counts remain unchanged: 363 repository migration files, 348 unique timestamps, 13 duplicate timestamp groups and 3 duplicate logical-name groups.

## Safe next action
When a sanitized production manifest is available, reconcile:
1. migration version/name rows;
2. live function definitions and trigger attachments for the driver guard/invitation functions;
3. live storage and table policies for driver evidence;
4. actual corridor catalogue rows and status;
5. exact index definitions and `indisvalid` state.

Do not rename, merge, reorder, baseline, squash or replay these migrations before this evidence is collected. No SQL was executed against production and no migration file was altered by this review.

## Export status at review time
The existing GitHub Actions export run `43793099331`, attempt 2, still reported `in_progress`; its export step had not completed and no refreshed artifact had appeared. The previous encrypted artifact remained visible with its original expiry metadata. This is not evidence that a new export was produced.
