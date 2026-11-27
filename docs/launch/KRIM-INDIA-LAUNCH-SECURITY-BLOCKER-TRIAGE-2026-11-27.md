# KRIM India Controlled Launch — Staging Security Blocker Triage
**Date:** 27 November 2026  
**Project:** Staging only (`qrpcivhdxobiaofppbkl`)  
**Production:** Not accessed  
**Disposition:** Launch gate remains BLOCKED; read-only inspection only.

## Why this pass was run
The India Controlled Launch Gate prioritizes security and tenant isolation before any real onboarding or transactions. This pass refreshed database evidence to distinguish actual Data API exposure from advisory findings that may be intentionally service-only.

## Verified Staging findings
1. A direct catalog query found **24 public-schema tables with RLS enabled and no policies** at the time of inspection.
2. For those 24 tables, a separate privilege check found **zero tables with direct anon or authenticated SELECT/INSERT/UPDATE/DELETE grants**. This means the no-policy finding is not, by itself, proof that those tables are directly exposed to browser roles. It remains a review item; do not add broad grants or generic policies to silence the advisor.
3. Supabase security advisors reported **31 RLS-enabled/no-policy findings across public and private schemas**. The advisor snapshot included service/internal tables as well as public tables. Each needs classification by schema, grants, function access paths and intended owner.
4. Supabase security advisors reported **55 SECURITY DEFINER functions callable by authenticated users**. This is a warning inventory, not proof that all 55 are exploitable. Each function must be reviewed for authorization checks, object/tenant scoping, search_path safety, and whether authenticated execution is intentional.
5. Performance advisors also reported unused indexes and one duplicate-index finding. These are not launch blockers unless they affect a critical India launch workflow or create a data-integrity/performance risk.

## Safe interpretation
- RLS enabled with no policies is default-deny for roles subject to RLS, but the table's grants and privileged function paths still matter.
- No direct anon/authenticated table grants were found for the 24 public no-policy tables in this check.
- SECURITY DEFINER requires function-by-function review. Do not revoke every authenticated grant indiscriminately: some RPCs may be required by legitimate app flows. Do not preserve them blindly either.
- Do not solve test access by granting broad table privileges or weakening RLS.
- Keep all synthetic workflow events and provider sends blocked until typed test isolation and side-effect boundaries are implemented and verified.

## Required next technical actions (Staging only)
1. Build a function-by-function SECURITY DEFINER triage: signature, grants, search_path, auth/role check, tenant boundary, data touched, launch relevance, decision.
2. Prioritize functions reachable by authenticated users that touch launch-critical data: onboarding, partner verification, quotes, shipment creation/acceptance, driver assignment, notifications, fee records and admin controls.
3. Inspect views and RPCs as alternate data access paths; table grants alone are not the full exposure model.
4. Classify each no-policy table as internal/service-only, intentionally inaccessible, or missing an intended access path. Add only narrowly scoped policies/grants where a documented user workflow requires them.
5. Re-run advisors and direct privilege checks after each approved change.
6. Continue workflow runtime and notification test-lane isolation review before creating test records or invoking workers.

## Non-goals for this pass
- No schema changes, grants, policy changes, function replacements or migrations.
- No test user invitations, fixture provisioning, event insertion, workflow execution or queue claims.
- No notification, email, Telegram or payment-provider calls.
- No Production queries or changes.

## Gate result
**Phase 00 security gate: OPEN.**  
This pass narrows the RLS finding: the 24 public no-policy tables checked had no direct anon/authenticated table grants. The remaining high-priority review is the 55 authenticated-callable SECURITY DEFINER findings and alternate view/RPC access paths, plus workflow/notification isolation. No launch clearance is granted by this inventory.
