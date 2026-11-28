# KRIM Fast-Track Day 1 — Partner Onboarding Caller Scan Completion — 2026-11-28

## Scope and method
- Staging branch: `staging/phase00-env-isolation`.
- Tree retrieved from commit `79fcda01bea5f8339c8044552d4829a43a1ae861`; tree response was not truncated.
- Identified 115 HTML/JS/TS/TSX/JSX files in the targeted partner, partner-admin, partner-auth, mobile-partner and partner-review path families.
- Retrieved and inspected all 115 file blobs for exact references to `krim_submit_partner_onboarding_global_multi_v1` and `krim_submit_partner_onboarding_global_v2`.

## Result
- Exact caller found: `public/partner/partner-onboarding.html` → `krim_submit_partner_onboarding_global_multi_v1`.
- No other exact call to either onboarding RPC was found in the remaining 114 files.
- `public/partner/services-capabilities.html` is a separate evidence-backed capability submission flow calling `krim_partner_submit_service_capability_v2`.
- `app/admin/staging/page-04-partner-capability-review.html` is a staging preview; inspected source contains no capability review RPC, storage evidence lookup, or live capability-table integration.
- This is a complete scan of the 115-file targeted partner-family set, NOT a scan of every 1,210 application HTML/JS/TS-family files. Dynamic RPC construction, indirect wrappers, server-side callers, and files outside the targeted path families remain outside this scan.

## Reconciled integration blocker
The deployed Staging onboarding multi-category RPC creates pending capability rows without the evidence metadata required by the review RPC. The separate evidence-backed submission function validates private object existence and ownership, then inserts a new row. Its duplicate-pending guard can reject a matching row already created by onboarding. The two paths therefore need a coordinated data-model/API correction before live partner onboarding is considered ready.

## Provenance status
- Historical commit `aa9e5d25a319c5d5ce638fae113bdfaa1da99b96` (2026-11-02) introduced the frontend multi-category form and switched its RPC call to the multi-category function.
- Migration `20261104133000_secure_partner_business_verification.sql` hardens an already-existing function using `pg_get_functiondef`/text replacement; it is not the original full function-creation source.
- Exact original creation source/migration is still unidentified. Do not synthesize a replacement migration until source provenance and deployment history are reconciled.

## Disposition
- Targeted caller inventory: COMPLETE (115/115 files).
- Whole-repository content scan: OPEN.
- Original RPC source provenance: OPEN.
- Coordinated evidence-handoff correction: NOT IMPLEMENTED.
- No RPC invocation, database mutation, onboarding submission, upload, deployment, external notification, email, payment or Production access occurred.
- Phase 00 remains OPEN; Phase 01 is not authorized.
