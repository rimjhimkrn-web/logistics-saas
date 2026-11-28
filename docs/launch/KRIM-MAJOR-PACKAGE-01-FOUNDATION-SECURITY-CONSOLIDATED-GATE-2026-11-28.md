# KRIM Major Package 1 — Foundation & Security Consolidated Gate

**Audit date:** 2026-11-28  
**Repository:** rimjhimkrn-web/logistics-saas  
**Branch:** staging/phase00-env-isolation  
**Database scope:** KRIM Logistics Staging only (`qrpcivhdxobiaofppbkl`)  
**Decision:** PACKAGE 1 NOT COMPLETE — BLOCKED FROM EXIT APPROVAL  
**Production:** NOT ACCESSED OR CHANGED

## 1. Executive result

Package 1 was consolidated into one Staging-only foundation/security review. Existing individual investigations were reused rather than repeated. Current evidence confirms several good controls and successful static CI, but the package cannot be certified complete because there is no reproducible database integration harness, no independent partner/customer JWT fixtures, workflow and notification workers are not proven side-effect-isolated, and key Auth/Data API configuration checks require owner dashboard access. No risky database changes were made to create the appearance of progress.

**This is a package-level gate report, not a security certification or launch approval.**

## 2. Fresh Staging baseline — 2026-11-28

| Control | Fresh result | Interpretation |
|---|---:|---|
| Applied Staging migrations | 163 | Latest `20261127093019`; repo/deployed provenance still needs reconciliation for selected older RPCs |
| Public tables with RLS enabled but no policies | 24 | No direct anon or authenticated SELECT/INSERT/UPDATE/DELETE grants found on these 24 in the inspected snapshot; default-deny for ordinary browser roles |
| Private tables with RLS enabled but no policies | 7 | No direct anon or authenticated DML/SELECT grants found in the inspected snapshot |
| Public SECURITY DEFINER functions | 367 | 55 executable by authenticated; 0 executable by anon |
| Public SECURITY DEFINER advisor findings | 55 | Requires per-function authorization review; not proof all are vulnerabilities |
| SECURITY DEFINER functions across public/private/krim_internal | 530 | All 530 have explicit search_path configuration in the fresh aggregate query |
| Private SECURITY DEFINER functions executable by anon | 2 | `private` schema has no anon USAGE; not reachable through ordinary schema access in the current ACL snapshot, but explicit ACL cleanup/review remains advisable |
| Auth leaked-password protection | Disabled | Auth dashboard setting blocker; advisor WARN |
| Workflow runtime cron | 1 active job every minute | Shared operational workflow runtime has no certified test-lane isolation; do not inject synthetic business events |
| Capacity hold expiry cron | 1 active job every minute | Existing operational scheduler; no synthetic fixture work should use live capacity tables |
| Organizations / capability rows | 1 / 0 | Only platform org; no partner fixture data |
| Events / workflow runs | 0 / 0 | No runtime E2E proof from real workflow records |
| Notification outbox / deliveries | 0 / 0 | No delivery E2E proof |
| Test fixture ledger | 0 | No test organizations provisioned |
| Partner evidence bucket | Private; 10 MiB; PDF/JPEG/PNG | Empty at audit snapshot; no object owner parity test possible |

RLS advisor also reports 31 RLS-enabled/no-policy tables across public and private schemas. The fresh direct privilege query shows no direct browser-role grants on the 31 identified tables. Do not remove RLS or add broad grants to silence the informational finding.

## 3. Package workstream disposition

| Workstream | Result | Evidence / remaining condition |
|---|---|---|
| Environment separation | PARTIAL PASS | Dedicated Staging branch/project identified; latest environment-isolation CI passed. No production access or deployment. Need continue secrets/config/deployment provenance checks. |
| RLS and table grants | PARTIAL | 31 no-policy advisor findings; no direct browser grants on those tables in current snapshot. Full table-by-table policy/privilege certification and tenant JWT tests remain open. |
| SECURITY DEFINER | PARTIAL | 55 public authenticated-executable functions all previously reviewed for search_path/auth delegation in batches; 0 public anon EXECUTE. Runtime authorization and regression tests for all signatures/overloads remain outstanding. |
| Auth and MFA | PARTIAL | Source-level AAL2 guards exist. No real registration, TOTP, recovery, session-revocation or revoked-membership browser tests. Leaked-password protection is disabled and needs dashboard enablement. |
| Edge Functions | PARTIAL | Five active Staging functions inventoried. `krim-resend-email-worker` is JWT-disabled but has a cron-secret guard; it must not be invoked in synthetic tests. `global-admin-control` still needs exact project-guard/source-parity review. |
| Partner onboarding/capability | BLOCKED | Multi-category declaration/evidence contract mismatch; no versioned evidence submission history; read workspace ACL mismatch; no independent Partner A/B sessions. |
| Evidence Storage | PARTIAL / BLOCKED | Private bucket and size/MIME controls verified. Upload policy is PERMISSIVE org/path plus RESTRICTIVE AAL2 (correct AND composition); runtime AAL1/AAL2 test missing. No DELETE policy for the bucket, so frontend partial-upload cleanup is not supported. Submission/review compare different owner columns (`owner_id` vs `owner`); empty bucket prevents parity verification. |
| Workflow isolation | BLOCKED | Shared operational tables and runtime have no immutable test-lane/run boundary. Cron is active every minute. Alternate workflow runtime callers and external scheduler inventory are not fully closed. |
| Notification isolation | BLOCKED | Event triggers create real in-app notifications and essential email outbox rows; deployed workers can contact external providers. No isolated test lane or proven zero-side-effect path. |
| Database test harness | BLOCKED | No `supabase/config.toml` or `config.jsonc`, no root package harness, no local CLI execution environment. `pgtap` is available as an extension option but is not installed. No reproducible tenant JWT test harness. |
| Backup/restore | BLOCKED | No verified downloadable Staging backup or restore drill. Current plan tier lacks downloadable scheduled backups; schema export is not a data backup. |
| Migration discipline | PARTIAL | Staging has 163 applied migrations; repository history and original source of one partner onboarding RPC remain incomplete. Do not apply unreviewed DDL or use hosted migration calls as a shortcut. |
| CI | PASS — limited scope | Latest environment-isolation workflow run `46127830575` and static link audit `46127830556` both completed successfully on commit `b48eb14a...`. These are static/environment checks, not database E2E or security certification. |

## 4. Confirmed high-priority blockers

### P0 — Must close before Package 1 exit
1. **Reproducible Staging database test harness:** establish pinned Supabase CLI v3 workflow and config; add isolated Postgres/Supabase test suite; test SQL and migrations locally before Staging.
2. **Safe workflow test architecture:** use dedicated test schema/registry/queue or prove all shared and alternate workflow runtimes are lane-aware. Test events must never reach production event triggers, customer notification tables, email outbox, Telegram, Resend or other providers.
3. **Owner configuration checks:** confirm Staging Data API exposed schemas/extra search path and enable Auth leaked-password protection. Verify Auth redirect URLs, password policy, rate limits, session policy and MFA assurance.
4. **Independent test identities:** provision four owner-authorized identities (Customer A/B, Partner A/B) through the existing protected invitation workflow only after the test harness and no-side-effect boundary are approved. Then run cross-tenant JWT tests.
5. **Evidence lifecycle:** repair partial-upload cleanup with a narrowly authorized server-side reference-aware process; standardize object ownership checks; add immutable submission versions and review linkage; run AAL1/AAL2 and cross-tenant Storage tests.
6. **Edge Function source/guard parity:** reconcile deployed Staging versions with repository source; add exact project-ID guard where absent; confirm external schedulers/callers; never invoke real-provider workers for tests.
7. **Backup and recovery proof:** establish a permitted encrypted backup/export approach including database data, Storage objects, Auth/configuration and a successful isolated restore drill.

### P1 — Required before affected workflows can be enabled
- Resolve multi-category partner declaration/evidence attachment contract and avoid downgrading reviewed capabilities.
- Implement durable submission idempotency and safe recovery after ambiguous browser timeouts.
- Implement complete approval/rejection/resubmission/revocation lineage and assignment impact handling.
- Complete role/org authorization matrix and independent Partner A/B, Customer A/B negative tests.
- Verify notification retry, lease recovery, delivery state, consent and provider separation without sending real messages.
- Reconcile migration provenance and function overload/caller dependencies before any corrective DDL.

## 5. Changes made during this package batch

- Consolidated fresh Staging advisor/catalog/ACL/scheduler/row-count evidence.
- Verified current public SECURITY DEFINER advisor count and separate private schema ACL boundary.
- Verified latest environment-isolation CI and full static-link audit jobs succeeded.
- Reused and linked prior detailed evidence reports rather than repeating the same investigations.
- No database DDL/DML, grants, RLS policies, Auth settings, Storage mutations, invitations, test organizations, RPC calls, workflow events, notifications, emails, provider calls, Edge Function deployments or production operations were performed.

## 6. Existing supporting reports

- `docs/testing/KRIM-FAST-TRACK-DAY-01-STAGING-INVENTORY-2026-11-28.md`
- `docs/testing/KRIM-FAST-TRACK-DAY-01-PARTNER-CAPABILITY-AUTHORIZATION-ACL-RECHECK-2026-11-28.md`
- `docs/testing/KRIM-FAST-TRACK-DAY-01-PARTNER-CAPABILITY-WORKSPACE-READ-CONTRACT-2026-11-28.md`
- `docs/testing/KRIM-FAST-TRACK-DAY-01-PARTNER-CAPABILITY-SUBMISSION-RPC-FAILURE-PATH-AUDIT-2026-11-28.md`
- `docs/testing/KRIM-FAST-TRACK-DAY-01-PARTNER-EVIDENCE-STORAGE-CLEANUP-REVIEW-LINEAGE-AUDIT-2026-11-28.md`
- `docs/testing/KRIM-WORKFLOW-TEST-FIXTURE-ACCESS-GATE-2026-11-27.md`
- `docs/testing/KRIM-WORKFLOW-FIXTURE-SIDE-EFFECT-ISOLATION-GATE-2026-11-27.md`
- `docs/testing/KRIM-WORKFLOW-LANE-SCHEDULER-CLAIM-BOUNDARY-DESIGN-2026-11-27.md`
- `docs/testing/KRIM-WORKFLOW-LANE-DEPENDENCY-MIGRATION-GATE-2026-11-27.md`
- `docs/testing/KRIM-EDGE-WORKER-NOTIFICATION-SAFETY-AUDIT-2026-11-27.md`
- `docs/testing/KRIM-NOTIFICATION-OUTBOX-LIFECYCLE-AUDIT-2026-11-27.md`
- `docs/testing/KRIM-TEST-RUNTIME-STORAGE-SECURITY-GATE-2026-11-27.md`
- `docs/testing/KRIM-WORKFLOW-RUNTIME-SECURITY-HARDENING-TEST-PLAN-2026-11-27.md`
- `docs/launch/KRIM-INDIA-LAUNCH-SECURITY-BLOCKER-TRIAGE-2026-11-27.md`

## 7. Exit decision

**Package 1: NOT COMPLETE. Phase 00: OPEN — NOT APPROVED. Phase 01: NOT AUTHORIZED.**

Do not mark Package 1 complete until all P0 blockers above have reproducible evidence and all P1 issues affecting launch workflows are closed or explicitly disabled. Static CI success does not substitute for database, JWT, Storage, workflow, notification, backup/restore and recovery tests.

**Production remains untouched.**

## 8. Partner capability lifecycle — additional package review (2026-11-28)

A further deployed-function and trigger review was completed after this consolidated gate was first committed. It identified a P0 source-level defect: the multi-category onboarding RPC can reset an existing capability—including a verified/suspended row—to inactive/pending, and the capability audit trigger only fires on INSERT, not UPDATE. The declaration/evidence workflow also lacks immutable submission-version linkage.

The revocation RPC correctly disables the capability and records the reason, but explicitly does not cancel existing assignments. Key quote/award/invitation-acceptance paths require an active verified capability, so new sourcing/acceptance is blocked after revocation; already accepted/active assignments and driver execution need an explicit operational exception workflow. No current assignment data existed to test this.

Detailed evidence and required correction/test matrix:
`docs/testing/KRIM-PARTNER-CAPABILITY-FULL-LIFECYCLE-REVOCATION-IMPACT-GATE-2026-11-28.md`

**Package 1 remains NOT COMPLETE.** This additional review is not a substitute for implementing the versioned evidence lifecycle, safe downgrade protection, revocation impact handling, isolated JWT tests and database harness.
