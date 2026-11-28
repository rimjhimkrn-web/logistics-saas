# KRIM Fast-Track Day 1 — Partner Onboarding Dependency Map
Date: 2026-11-28
Branch: staging/phase00-env-isolation
Environment: Staging source and Staging database inspection only

## Scope
This map consolidates the targeted partner-family caller scan (115 HTML/JS/TS/TSX/JSX files), current Staging frontend source, current Staging RPC definitions, and the relevant tracked SQL migrations. It is not a certification of every dynamic, indirect, server-side or out-of-family caller in the entire repository.

## Direct caller map

| Component | Source path | Current responsibility | RPC / DB contract |
|---|---|---|---|
| Partner onboarding UI | public/partner/partner-onboarding.html | Collects legal/business registration details, parent registration/insurance documents, 1–13 selected service categories and country/region/city coverage | Calls krim_submit_partner_onboarding_global_multi_v1 once |
| Partner capability workspace | public/partner/services-capabilities.html | Reads capability register; uploads 1–5 private capability evidence files under <org>/<user>/capability/; collects mode/service/country/region/weight and operational details | Calls krim_partner_submit_service_capability_v2; currently insert-oriented |
| Platform capability review | app/admin/staging/page-04-partner-capability-review.html | Staging preview page only; no live review RPC/evidence-storage lookup integration was found in the targeted inspection | No direct krim_admin_review_partner_capability caller found in targeted partner family |
| Admin review backend | Staging database function | Independent AAL2 platform-admin approval/rejection; validates evidence paths and Storage ownership | krim_admin_review_partner_capability(bigint,text,text) |

## Tracked SQL provenance

1. supabase/migrations/20261020074510_global_partner_onboarding_location_hardening.sql
   - Defines krim_submit_partner_onboarding_global_v2.
   - Creates/updates organization verification state and organization-level documents.
   - Only accepts the four transport categories ROAD_FTL, OCEAN_NVOCC, AIR_CHARTER, INTERMODAL_RAIL.
   - Also creates/updates a base capability as part of organization verification submission.
2. supabase/migrations/20261104133000_secure_partner_business_verification.sql
   - Does not define the original multi-category wrapper.
   - At migration time, reads pg_get_functiondef for the already-existing wrapper and applies a string replacement to harden authentication, AAL2 and registered-business membership checks.
3. supabase/migrations/20261105153000_add_evidence_backed_partner_capability_submission.sql
   - Defines insert-oriented krim_partner_submit_service_capability.
   - Requires partner.manage, active registered-business org, current compliance, valid active mode/country/service, and 1–5 owned private capability evidence files.
   - Inserts a new inactive/pending capability with evidence_paths, submitted_by and submitted_at.
   - Rejects a matching pending duplicate.
4. supabase/migrations/20261105153200_persist_partner_capability_submission_details.sql
   - Defines v2 wrapper and stores bounded equipment/operational details after the base insert.

The original CREATE migration for krim_submit_partner_onboarding_global_multi_v1 remains unrecovered. Do not label a new migration as restoration of the original.

## Confirmed contract conflict

The current multi-category onboarding wrapper creates category declaration rows as inactive/pending, with category and coverage metadata, but without submitted_by, submitted_at or evidence_paths.

The existing capability evidence page later calls an insert-oriented RPC. That RPC creates a separate row and rejects an existing pending row with the same org/mode/service/country/region. It does not attach evidence to the existing declaration.

The admin review RPC only approves pending rows with submitted_by and 1–5 correctly scoped private evidence paths owned by that submitter. Therefore the current onboarding-created declaration cannot satisfy the approval contract as-is, and the generic insert path is not a safe evidence handoff for an existing declaration.

## Proposed versioned interface boundary

Add a new authenticated RPC, for example:
public.krim_partner_attach_capability_evidence_v1(
  p_capability_id bigint,
  p_evidence_paths text[],
  p_submission_details jsonb
) RETURNS jsonb

This is a design name only; it has not been created.

Expected behaviour:
- derive actor exclusively from auth.uid();
- require active partner.manage permission for the exact organization;
- lock the exact target capability row and require pending/inactive state;
- validate current registered-business and compliance requirements;
- validate 1–5 distinct private bucket objects with exact <org>/<actor>/capability/<filename> path and actual owner;
- append a submission version/audit record rather than overwrite prior evidence;
- set server-generated submitted_by/submitted_at and evidence_paths only after all validation succeeds;
- retain inactive/pending status;
- leave final decision exclusively to the existing AAL2 admin review RPC;
- be idempotent under a client request key and safe under concurrent submissions.

Before implementing, decide where append-only evidence versions live. Prefer a dedicated capability submission/history table with FK, submitter, timestamp, evidence JSON, details, request key and audit lineage, rather than silently replacing a reviewed capability's metadata.

## Required frontend change

- Onboarding remains the organization verification + service declaration step.
- Capability workspace must display existing declarations and let the partner select one pending declaration to attach category-specific evidence.
- Keep the existing generic new-capability submission flow for genuinely new capabilities only, after verifying that the selected scope is not already represented by an onboarding declaration.
- Do not auto-create a second row for an existing pending declaration.
- Show the declaration category/coverage, evidence-submitted state and independent review state.
- Keep all admin review controls out of partner-facing UI.
- Add an explicit no-evidence / evidence-submitted / review-pending / approved / rejected state model.

## Implementation dependencies and gates

P0:
1. Recover/confirm original migration baseline or explicitly document unrecovered provenance.
2. Finish full repository-wide direct and indirect caller search for both onboarding RPCs and capability submission/review RPCs.
3. Design submission-history table, uniqueness/idempotency key and migration rollback.
4. Confirm current database constraints and RLS/grants for the new history table.
5. Write SQL unit tests for auth, tenant boundary, evidence ownership, state transition, concurrency and rollback.

P1:
6. Add versioned RPC and least-privilege EXECUTE grants.
7. Update services-capabilities.html to attach evidence to existing declaration and preserve the separate new-capability path.
8. Add automated frontend contract tests and RPC integration tests.
9. Deploy only to Staging after migration diff review and backup/rollback evidence.
10. Test all 13 categories, multi-category onboarding, resubmission, duplicate submissions, review and rejection.

## Evidence / limitations
- Onboarding page blob: af0e429e1b9780cf93feee0d6fb492d149fc159e
- Services/capabilities page blob: 12a0d32dd5e850165cf92acf252b0f75c8482156
- Base onboarding migration blob: 8adea166591ac9b6abc2062c4d3cbab2957cd5cc
- Evidence submission migration blob: b8f75e806b272d29c20fcdd76edce91a70207b88
- Submission details migration blob: 0ae8bdbe42210d16f3cd62e2e61ed64146b3497b
- Business verification hardening migration blob: b3b5088cfe08689d419b4e224c0950781300786f
- Prior targeted 115-file scan found exactly one direct onboarding RPC caller, in public/partner/partner-onboarding.html. This does not exclude dynamic/indirect/server-side callers elsewhere.
- Staging capability table currently has no unique constraint enforcing category declaration identity; any new design must not assume one exists.
- No live RPC invocation, migration execution, fixture provisioning, storage upload, external notification, deployment or Production access occurred in this checkpoint.

## Disposition
DEPENDENCY MAP COMPLETE FOR TARGETED PARTNER PATHS. Full-repository caller certification and implementation design gates remain open. No code or database changes. Phase 00 remains OPEN; Phase 01 is not authorised.
