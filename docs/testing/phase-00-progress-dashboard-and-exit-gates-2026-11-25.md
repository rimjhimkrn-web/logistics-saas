# KRIM Phase 00 — Progress dashboard and exit-gate status

**Date:** 2026-11-25  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Working branch:** `qa/phase-00-baseline-2026-11-25`  
**Production branch:** `main`  
**Status:** Phase 00 discovery is mature; controlled Staging runtime readiness is still blocked.

## Executive progress

There are **90 Phase 00 audit/report documents** in `docs/testing/` on the QA branch. They cover infrastructure, environment separation, route inventory, nine workspaces, authentication, tenant authorization, SQL/RPC security, notifications, payment/refund flows, partner/driver/warehouse/customs/finance/operations/enterprise/admin workflows, Storage, uploads/downloads, signed URLs, CI and browser-test readiness.

The report count measures recorded audit work, not the percentage of the platform that is correct or ready.

### Newly verified CI milestone

Both CI workflows completed successfully on the same QA commit:

- Commit: `3d95d20aa75ccee0f03f7665e934f71b6a958064`
- **KRIM production smoke checks:** run `45572519857` — SUCCESS.
  - Critical workflow checks: success
  - Shared-auth syntax: success
  - Fail-closed environment isolation tests: success
  - Repository-wide static audit: success
  - Audit artifact upload: success
- **KRIM Chromium environment isolation smoke:** run `45572519927` — SUCCESS.
  - Real Chromium opened the local HTTPS fixture under the allowlisted Staging hostname.
  - Confirmed Staging project reference `qrpcivhdxobiaofppbkl`.
  - Confirmed PKCE and persistent-session configuration.
  - Confirmed Authentication remains enabled.
  - Confirmed explicit `?mode=review` behavior.
  - Confirmed stale global client replacement.
  - Confirmed unknown hostname fails closed before Supabase client initialization.

This is a genuine browser automation pass for the isolated fixture. It is **not** a live Staging deployment, real Supabase browser session, authentication journey, or end-to-end business workflow test.

## Progress by workstream

| Workstream | Evidence completed | Remaining before Phase 00 exit |
|---|---|---|
| Repository and infrastructure baseline | Extensive source, workflow, route and dependency inventory | Confirm hosting ownership and live Staging deployment provenance |
| Environment isolation | QA allowlist implementation; VM tests and Chromium fixture CI both pass | Verify actual deployed Staging hostname and project identity; test actual browser-to-Supabase identity |
| Nine-workspace workflows | Representative route-to-RPC/backend maps and authorization reviews for all nine ecosystems; canonical driver-review browser RPC caller identified | Complete safe authenticated runtime tests and resolve known page/RPC/ACL gaps |
| Authentication and tenant isolation | Source and database catalog security reviews | Synthetic multi-tenant identities; real JWT allow/deny tests; callback/MFA/session runtime tests |
| Notifications | Event producers, outbox, worker, recipient and inbox audits; remediation design documented | Implement and verify one durable, idempotent pipeline; workspace inboxes; safe provider sink; callback and retry tests |
| Storage and evidence | Bucket/policy inventory, ownership and signed-link reviews; current Staging AAL2 INSERT policy is RESTRICTIVE and composes with the organization/uploader policy | Record assurance decision; provision three missing Staging evidence buckets/policies; resolve reviewer ACL; synthetic upload/read/deny tests |
| Payments and finance | Razorpay, refunds, ledger and finance authorization source reviews | Isolated payment simulation/test-mode verification, reconciliation and tenant-safe runtime tests; no real charges |
| Browser test infrastructure | Chromium CI now green | Expand from environment fixture to public-route and signed-in synthetic-workspace suites |
| Release safety | QA-only work; no merge or deployment | Full diff review, explicit owner approval, deployment/rollback plan and post-deploy verification |

## Phase 00 runtime entry/exit gates

These gates must not be confused with audit-document completion.

| Gate | Required proof | Current state |
|---|---|---|
| G0 — Environment identity | Canonical Staging origin, actual deployed commit and Supabase project ref proven together | **BLOCKED / NOT VERIFIED** |
| G1 — Partner upload assurance | Written assurance decision plus runtime AAL1/AAL2 JWT allow/deny tests | **PARTIAL PASS:** current Staging catalog enforces AAL2 through a RESTRICTIVE policy; Production has no matching AAL2 INSERT restriction; owner decision and runtime tests remain open |
| G2 — Staging Storage parity | Required private evidence buckets and scoped policies present; no permissive-policy bypass | **OPEN — known gaps** |
| G3 — Driver reviewer authorization | Actual caller and intended EXECUTE ACL confirmed | **OPEN** |
| G4 — Synthetic identities | Isolated users and at least two separate organizations with role/assurance coverage | **NOT ESTABLISHED** |
| G5 — Safe test sink and cleanup | No real provider sends/charges; deterministic test destinations and rehearsed cleanup | **NOT ESTABLISHED** |
| G6 — Runtime verification | Authenticated allow/deny tests for workspaces, RLS, Storage, workflows and notifications | **NOT STARTED / NOT PASSED** |

**Runtime readiness: 0 of 7 gates passed.** This is a strict gate count, not a claim that 0% of engineering work is complete. G0–G6 are intentionally sequential; runtime tests cannot safely start until their prerequisites pass.

## Critical known blockers carried into remediation

1. The Staging website origin and deployed commit are not proven. Repository inspection found the GitHub Pages deployment workflow deploys `main`; it does not establish a deployment to `krim-staging.pages.dev`.
2. **Corrected live finding:** current Staging catalog shows the AAL2 INSERT policy is RESTRICTIVE, so it combines with the permissive organization/uploader policy as an AND condition. The earlier two-permissive finding is historical/stale. Production does not show the matching AAL2 INSERT restriction; the intended parity decision remains open.
3. Staging lacks the reviewed driver-verification, driver-evidence and warehouse-evidence buckets.
4. Driver-review function execution privileges differ between Production and Staging; the intended caller must be identified before changing ACLs.
5. Notifications remain a launch blocker: source audits show gaps in end-to-end recipient routing, inboxes, provider delivery evidence, callbacks, retries and safe test-send controls.
6. Several workspace routes are preview, read-only, paused or fail-closed. A source integration map is not proof that all nine ecosystems are live.
7. The customer booking route has a Production client fallback in its initializer and booking release is explicitly disabled; it must be corrected and verified before release.
8. Production hardening is not on `main`. QA branch success does not change the live site. No merge or deployment is authorized by this report.

## What is complete enough to move forward?

**The discovery/audit workstream can move from broad inventory into a controlled remediation sprint.** The new Chromium fixture and repository smoke checks are now green on the same QA commit, which closes an important test-harness foundation gap.

**Do not move into full end-to-end onboarding, live customer/partner acquisition, real payments, or revenue-generating production workflows yet.** The Staging identity and synthetic-test prerequisites are not met.

Recommended next sequence:
1. Prove the real Staging hosting origin, deployment owner and deployed commit (G0).
2. Prepare reviewed QA-only remediation proposals for G1–G3; do not mutate Production.
3. Establish synthetic identities and safe test sink/cleanup (G4–G5).
4. Expand browser tests to real Staging only after G0–G5 are approved and verified.
5. Execute the nine-workspace allow/deny and business lifecycle runtime suite (G6).
6. Only then make a Phase 00 exit recommendation and begin controlled onboarding readiness.

## Safety record

No Production or Staging schema, policies, data, Auth users, Storage objects, secrets or provider settings were changed in this progress update. No Production merge or deployment occurred. The Chromium test used a local fixture and mocked Supabase SDK; it did not access live customer or partner data and did not send communications or charges.

**Decision:** Continue Phase 00 through environment proof and remediation readiness. Audit coverage is extensive, but the platform is not yet certified for real onboarding or revenue-generating use.


## Subsequent live Storage recheck
A fresh read-only catalog query on 2026-11-25 found the Staging partner-verification AAL2 INSERT policy is currently `RESTRICTIVE`, not `PERMISSIVE`. This corrects the earlier historical finding; see `phase-00-live-storage-policy-recheck-and-prior-finding-correction-2026-11-25.md`. The current catalog composition is structurally restrictive, but runtime JWT tests and the Production/Staging assurance decision remain open.


## Additional read-only reconciliation
- Current Staging partner-verification AAL2 INSERT policy is `RESTRICTIVE` and therefore combines with the organization/uploader permissive policy; see the live Storage recheck report.
- The canonical driver-review UI caller and exact Production/Staging EXECUTE ACL mismatch are now verified; see the driver-reviewer RPC reconciliation report.
