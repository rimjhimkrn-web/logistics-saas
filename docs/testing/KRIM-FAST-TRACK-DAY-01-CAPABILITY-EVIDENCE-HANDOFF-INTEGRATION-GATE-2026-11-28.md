# KRIM Fast-Track Day 1 — Partner Capability Evidence Handoff Integration Gate — 2026-11-28

## Purpose
Reconcile the multi-category onboarding rows with the later evidence-backed Services & Capabilities workflow. This is a read-only Staging audit.

## Current intended frontend sequence
1. `public/partner/partner-onboarding.html` calls `krim_submit_partner_onboarding_global_multi_v1` after collecting organization-level registration documents and selected categories/coverage.
2. The multi-category RPC creates or updates category-tagged `krim_partner_capabilities` rows as inactive and pending, without `evidence_paths`, `submitted_by`, or `submitted_at`.
3. `public/partner/services-capabilities.html` separately uploads one to five files under `<org>/<user>/capability/<filename>` in private bucket `krim-partner-verification`, then calls `krim_partner_submit_service_capability_v2`.
4. That wrapper delegates to `krim_partner_submit_service_capability`, which validates AAL/permission/compliance, checks private object existence and ownership, then INSERTS a new pending capability row with evidence lineage.

## Critical integration conflict
The base evidence-backed submission function checks whether a matching capability row already exists for the same organization, transport mode, service type, country, normalized region and `verification_status='pending'`. If so, it raises SQLSTATE `23505` with “A matching capability request is already awaiting review”.

The multi-category onboarding wrapper has already inserted precisely these inactive/pending capability rows for each selected category using the category-to-mode/service mapping. The evidence-backed submission function does not attach evidence to or update that category-tagged row; it attempts a separate INSERT. Therefore, when the partner later follows the Services & Capabilities UI to submit evidence for the same mapped category/coverage, the existing pending onboarding row can block the evidence-backed submission as a duplicate.

This is a source-level workflow incompatibility confirmed by reading both deployed Staging function definitions and the tracked Services & Capabilities frontend. No RPC was invoked and no actual partner submission was attempted.

## Consequences
- Initial multi-category onboarding may create pending category records that cannot be completed through the existing evidence-backed submission path for matching coverage.
- The admin review RPC requires one to five private evidence files in `metadata.evidence_paths`, the original submitter in `metadata.submitted_by`, and validates each object exists in the private bucket and is owned by that submitter. The onboarding-created row does not carry these fields.
- The standalone evidence-backed submission function creates a new row rather than enriching the onboarding-created category row.
- The admin review page inspected in this branch is a staging preview and contains no live capability review RPC or data integration; it is not proof of an operational admin review UI.

## Required design correction
Do not simply remove the duplicate guard or bypass the evidence requirement. Select one coherent model and implement it atomically:
A. Make onboarding category rows organization-level declarations only, not reviewable capability records; then the evidence-backed workflow creates separate capability records, with explicit category linkage and a clear pending/declared status; OR
B. Add a dedicated authenticated capability-evidence submission RPC that locks and enriches the existing onboarding-created category row, verifies exact category/coverage mapping and storage ownership, records `submitted_by`, `submitted_at`, evidence paths and audit history, and leaves the row inactive/pending until independent AAL2 review.

For either model:
- preserve previous evidence and review history;
- prevent resubmission from downgrading approved/rejected rows;
- prevent duplicate parallel submissions with row/unique-key locking;
- ensure all selected categories map to their own evidence and operational mode/service;
- preserve the rule that only a separate authorized AAL2 reviewer can approve;
- test first submission, matching existing onboarding row, partial evidence failure, duplicate concurrent submission, rejected resubmission, approved resubmission, wrong owner, foreign organization, missing object, and audit lineage.

## Repository caller scan status
The current Staging branch tree contains 1,210 HTML/JS/TS-family files. A targeted 115-file partner/admin/mobile candidate set was identified. Content inspection has reached 64 of 115 candidates; no additional exact calls to either onboarding RPC were found in the first 64. The confirmed onboarding page remains the only known exact frontend caller. This is NOT an exhaustive caller result; 51 candidates remain.

## Safety and disposition
- Read-only Staging function definitions and GitHub blob inspection only.
- No SQL writes, RPC calls, file uploads, partner onboarding, fixture provisioning, event/notification/email/provider/payment calls, or deployments.
- Production untouched.
- Phase 00 remains OPEN. Day 1 remains PARTIAL.
