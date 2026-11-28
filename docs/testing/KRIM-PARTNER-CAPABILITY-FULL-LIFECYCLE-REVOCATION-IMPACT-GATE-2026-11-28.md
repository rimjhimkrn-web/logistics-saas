# KRIM Partner Capability Approval, Rejection, Resubmission & Revocation Lifecycle Gate

**Audit date:** 2026-11-28  
**Scope:** KRIM Logistics Staging only (`qrpcivhdxobiaofppbkl`) and repository source on `staging/phase00-env-isolation`  
**Status:** REVIEW COMPLETE — LIFECYCLE NOT APPROVED FOR LIVE USE  
**Production:** Not accessed or changed.

## Executive result

The Staging lifecycle has useful controls: AAL2 platform-admin review, pending-only decisions, approval evidence checks, non-self-approval for approvals, explicit rejection reasons, append-only audit-event inserts for decisions, and capability eligibility checks in key quote/award paths.

However, the complete lifecycle is not safe to certify. The multi-category onboarding RPC can reset an existing capability row—including a verified or suspended row—to inactive/pending without creating a matching update audit event. Capability submission history is stored in mutable JSON metadata rather than immutable submission versions. Revocation disables the capability but deliberately does not cancel existing accepted/active assignments or associated driver execution. Those require an explicit operational exception and controlled transition. There are no capability/assignment/quote fixtures in Staging to exercise any of these transitions.

## 1. Current Staging data snapshot

At the audit snapshot:
- `krim_partner_capabilities`: 0 rows.
- `krim_shipment_partner_assignments`: 0 rows.
- `krim_partner_quotes`: 0 rows.
- `krim_partner_opportunities`: 0 rows.
- `krim_partner_capacity_availability`: 0 rows.
- `krim_partner_shipment_capacity_commitments`: 0 rows.
- Capability-related `krim_audit_events`: no rows returned.

Therefore all lifecycle findings below are from deployed function/trigger definitions and repository-source review, not successful live record execution.

## 2. Approval and rejection RPC

Deployed function:
`public.krim_admin_review_partner_capability(bigint,text,text)`

Verified controls:
- SECURITY DEFINER with empty search_path.
- `anon` EXECUTE denied; `authenticated` EXECUTE granted.
- Requires `auth.uid()`, JWT AAL2, and `admin.platform` permission on platform organization 1.
- Accepts only `approved` or `rejected`.
- Requires a rejection reason of at least 5 characters; approval review note at least 10; maximum 1,000 characters.
- Locks capability and organization rows; only pending capability records can be reviewed.
- Approval rejects self-approval by comparing `submitted_by` with reviewer.
- Approval requires current partner compliance, active country and mode, one to five evidence paths in the expected private bucket/path, and object ownership by the submitting user.
- Standard approval blocks hazardous-goods and refrigerated capability claims until the relevant specialist controls exist.
- Approval validates effective dates and maximum weight.
- Decision writes previous/new state to `krim_audit_events` and records review actor, time, decision and reason in metadata.

Remaining gaps:
- Rejection does not apply the same explicit submitter-versus-reviewer comparison as approval. It is still restricted to AAL2 platform administrators, but consistent independent-review semantics should be decided and tested.
- Review decision is stored in mutable capability metadata; audit events preserve decision snapshots, but there is no first-class immutable submission version linked to the decision.
- Approval function does not visibly apply the canonical organization-type allowlist used by revocation and some partner submission functions. Confirm allowed organization types centrally before live enablement.
- Evidence owner comparison is against `storage.objects.owner`; the submission RPC validates `storage.objects.owner_id`. Both columns exist, but the empty bucket means parity has not been demonstrated with a real owned object.

## 3. Resubmission and multi-category onboarding — P0 defect

Deployed function:
`public.krim_submit_partner_onboarding_global_multi_v1(...)`

The loop updates an existing capability row matched by organization and `metadata.operational_category`. The update unconditionally sets:
- `active=false`
- `verification_status='pending'`
- new category/coverage metadata

It does not restrict the update to a draft/pending/rejected state, does not preserve a verified or suspended decision, and does not create a capability update audit event. The only capability audit trigger inspected is AFTER INSERT, not UPDATE.

**Impact:** a repeat onboarding submission can silently downgrade a previously verified capability to pending/inactive, while overwriting category metadata and without the normal review decision lineage. This is a source-level/deployed-definition defect; no live record was present and the RPC was not invoked.

Additional evidence gap:
- The multi-category wrapper creates category declaration rows without capability-level `submitted_by`, `submitted_at`, or `evidence_paths` required by the review RPC.
- The partner Services & Capabilities flow submits evidence through a separate insert-oriented RPC, which creates another capability rather than attaching evidence to the onboarding declaration.
- There is no durable append-only submission version table or idempotency key.
- Original creation migration for the multi-category wrapper remains unrecovered.

**Required correction:** create a versioned declaration/evidence contract. A repeat submission must never downgrade verified/suspended records or overwrite prior evidence/review history. Evidence must attach to the exact pending declaration, with submitter derived from `auth.uid()`, validated private object ownership, idempotency, immutable submission version, and a reviewer decision linked to that version.

## 4. Revocation and operational assignment impact

Deployed function:
`public.krim_admin_revoke_partner_capability(bigint,text)`

Verified controls:
- SECURITY DEFINER, empty search_path.
- AAL2 and platform-admin permission required.
- Requires a reason between 10 and 1,000 characters.
- Locks capability and organization; only active verified capability can be revoked.
- Sets capability inactive and suspended; records actor, timestamp and reason.
- Writes before/after state to `krim_audit_events`.
- Explicitly returns `existing_assignments_cancelled=false`.

Downstream behaviour inspected:
- New partner quote submission and quote award paths require an active, verified capability, current organization state/compliance and route/capacity checks. Revocation therefore blocks future eligible sourcing through these inspected paths.
- Partner invitation acceptance also requires an active verified capability, so an offered invitation should not be accepted after the capability is suspended.
- Existing accepted/active assignments are not automatically cancelled by the revocation RPC.
- Assignment terminal-state triggers can release capacity commitments/reservations and may invalidate pre-dispatch driver assignments, but those paths require an authorized assignment status transition.
- If driver pickup/in-transit activity exists, the pre-dispatch synchronization trigger rejects automatic cancellation and requires a manual exception/delivery lifecycle.

**Operational rule required:** revocation must create a linked operational review task for every affected offered/accepted/active assignment, driver assignment, dispatch authorization, capacity commitment/reservation and shipment leg. Do not mass-cancel or silently mutate assignments from the capability revocation RPC. Require an authorized operator decision, customer/partner communication policy, capacity release, driver safety review and audit trail. No such end-to-end orchestration was proven in this audit.

## 5. Audit and evidence lineage

- Capability creation has an AFTER INSERT audit trigger.
- No capability UPDATE audit trigger was found in the inspected trigger inventory.
- Approval, rejection and revocation RPCs explicitly insert audit events.
- Capability evidence is stored in mutable `metadata`, not a dedicated append-only submission-version table.
- Audit rows for capability lifecycle were absent in the current Staging dataset.
- Storage bucket is private and empty; no real object owner parity, upload-failure cleanup or reviewer retrieval test could be executed.

## 6. Required test matrix before enabling lifecycle

1. AAL1 reviewer denied; AAL2 authorized platform reviewer allowed.
2. Non-admin and partner reviewer denied; self-approval denied.
3. Rejection requires reason and creates immutable decision evidence.
4. Rejected submission can be resubmitted as a new version without altering the rejected version.
5. Verified and suspended capabilities cannot be silently downgraded by repeat onboarding.
6. Missing, foreign-org, wrong-owner, wrong-bucket, malformed, duplicate and deleted evidence objects rejected.
7. Partner A cannot read or modify Partner B capability or evidence.
8. Revocation blocks new quote submission, award, and offered-assignment acceptance.
9. Revocation identifies existing offered/accepted/active assignments and associated driver/dispatch/capacity records.
10. Operator cancellation before pickup releases capacity and revokes dispatch/driver authorization with complete audit.
11. In-transit assignment requires manual exception handling and does not auto-cancel.
12. All failure paths are atomic and idempotent; ambiguous browser timeout does not create duplicate submissions.

## 7. Package 1 disposition

**This lifecycle workstream is BLOCKED for live use.** The P0 multi-category downgrade and missing immutable evidence-version linkage must be corrected. Revocation requires a separate assignment-impact workflow. Runtime tests cannot proceed until the isolated database harness and four independent JWT identities are available.

No database changes, grants, fixtures, storage uploads/deletes, invitations, notifications, RPC invocations, Edge Function deployments or production operations were performed during this review.
