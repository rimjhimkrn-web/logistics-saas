# KRIM Security Findings Consolidation and Remediation Priority Register
**Date:** 16 November 2026  
**Scope:** Consolidation of read-only production catalog/function/storage/Edge Function findings and static workspace/CRM/onboarding reviews. This is a prioritization artifact, not a penetration test or security certification. No DDL, DML, function deployment, policy change, secret access, impersonation or live business operation was performed.

## Executive decision
**NO-GO for unrestricted production operations, public partner onboarding, sensitive evidence workflows, external customer messaging or financial collection.** KRIM has useful foundational controls—RLS on all 391 ordinary public tables, no anon-executable public SECURITY DEFINER functions in the reviewed catalog, private evidence buckets, AAL2 gates on multiple privileged workflows, and maker-checker controls in several domains. These controls do not yet establish consistent authorization across nine workspaces or resilience against workflow bypass, tenant confusion, failed audit persistence, and provider/worker edge cases.

This register separates confirmed code/catalog weaknesses from risks that need staging validation. It does not label every broad grant or SECURITY DEFINER function as exploitable.

## 1. Consolidated security baseline
| Control surface | Observed state | Interpretation |
|---|---|---|
| Public ordinary tables | 391; all RLS enabled | Positive baseline, not policy certification |
| RLS tables with no policies | 24; no anon/auth DML grants in inspected snapshot | Preserve restricted grants; no exposure proven |
| Public SECURITY DEFINER functions | 332 total; 150 authenticated-executable; 0 anon-executable | Elevated function surface needs systematic review |
| Authenticated all-four DML table grants | 42 | Review intended direct-write paths and RLS together |
| Functions with public-first search_path | 8 identified in first batch | Review qualification/shadowing; not proven exploitable |
| Storage buckets | 5 private; 0 objects at audit snapshot | Positive privacy default; real file tests outstanding |
| Edge Functions | 21 active; 5 JWT verification disabled | Public/worker endpoints need source parity and abuse/auth validation |
| Workspaces | 9 role categories | Entry guards and backend permissions are inconsistent |
| Organization lifecycle | 14 organizations, 13 active memberships; no generic org invitations/onboarding rows | External team onboarding lifecycle unproven |
| CRM/notification tables | Reviewed core counts zero | Delivery and consent reliability not proven by production usage |

## 2. P0 — Block before live commercial or operational launch
### P0.1 Compliance gate can fail open
The internal shipment compliance evaluator can set `clear` when there are zero configured compliance checks. Missing controls must never be interpreted as approval. Earlier production baseline found readiness-gate rows marked ready despite no configured compliance rules/checks.
**Required fix:** require an approved applicable control set; zero/missing rules or checks => `review_required` or `blocked`; persist control-set version and evidence. Test missing/expired/waived controls in staging.

### P0.2 Backup and restore protection is not verified
Supabase organization is on Free; no automatic database backups/PITR are included on that plan. Existing encrypted schema export is schema-only, not a recoverable data backup. No full restore drill was evidenced.
**Required fix:** establish encrypted off-site data backup, separate Storage-object backup, Auth/configuration recovery and isolated restore validation before accepting live shipments or fees.

### P0.3 Production migration state is not reconciled
Production migration history (558 versions) materially differs from repository SQL inventory (363 files, 348 unique timestamps). This blocks safe application of security migrations and corrective DDL.
**Required fix:** complete sanitized production schema manifest and deterministic migration crosswalk. Do not baseline, replay, squash or apply corrective schema migrations before reconciliation.

## 3. P1 — Resolve before opening the affected workflow
| ID | Area | Finding / evidence | Required remediation |
|---|---|---|---|
| SEC-01 | Workspace authorization | Legacy `app/index.html` lets any active organization member enter a customer-labelled workspace without customer-org type validation. | Enforce workspace type/permission at entry; backend RLS/RPC must independently authorize every action. |
| SEC-02 | Operations | Operations entry does not explicitly check `operations.view`; snapshot RPC filters with customer-org `shipment.view`, unlike direct operations-org reads. | Canonical operations permission scope and consistent snapshot/query authorization. |
| SEC-03 | Enterprise | Enterprise membership entry is not equivalent to customer-data relationship authorization; zero network relationships exist; canonical query fallback to legacy table can hide errors. | Explicit enterprise-to-customer relationship model; fail visibly on canonical source errors. |
| SEC-04 | Admin audit integrity | Global admin helper may report privileged mutation success even if audit insert fails; generic read helper may convert query failure to empty results. | Make privileged mutation and durable audit atomic; surface query errors distinctly; test failure injection in staging. |
| SEC-05 | SECURITY DEFINER | Eight authenticated functions use public-first search_path; 150 authenticated-executable SECURITY DEFINER functions exist. | Review exact signatures, overloads, EXECUTE grants, object qualification and nested authorization; restrict grants only after dependency review. |
| SEC-06 | Direct table writes | 42 tables grant authenticated all DML; compliance-gate, consent and finance/revenue posting/allocation tables are priority candidates. | Confirm all writes pass intended state machines/maker-checker. Finance remains deferred; do not test or enable posting paths. |
| SEC-07 | Storage | Private `pod-documents` bucket has no size/MIME restrictions and no bucket-specific policy found. | Keep unused/blocked or define explicit limits and owner/tenant policies; test signed URL expiry/revocation and cross-tenant access. |
| SEC-08 | Edge Function source parity | Some active deployed functions lack matching repository source/hash; notification retry worker is JWT-disabled and deployed source unavailable in review. | Recover exact deployed source, version/hash and deployment provenance; independently verify high-entropy worker authentication, lease recovery and batch limits. |
| SEC-09 | Public endpoint abuse | Public inquiry/tracking endpoint abuse limits and trusted-proxy IP behavior need staging validation; wildcard CORS appears on several endpoints. | Endpoint-specific CORS, body/token/IP limits, abuse telemetry, revocation tests; never trust caller-supplied forwarding headers. |
| SEC-10 | Cashfree residue | Cashfree order/verify/webhook functions remain active despite discontinuation decision. | Dependency review, confirm no live consumer, then disable safely through controlled change after migration reconciliation. |
| SEC-11 | Consent | Privacy notice acknowledgement is not marketing/channel consent; withdrawal lifecycle and immutable consent events are incomplete. | Separate acknowledgement from purpose/channel opt-in; implement withdrawal and event history before marketing messages. |
| SEC-12 | Notification reliability | Direct Telegram send races retry worker; processing claims can strand; provider acceptance is not human receipt; Resend not send-ready. | Single dispatcher with atomic claim/lease/reclaim, durable delivery semantics and verified provider setup; do not send customer messages until tested. |
| SEC-13 | Organization lifecycle | Generic organization/team invitation and onboarding workflow not evidenced; membership audit covers insert but not role change/revocation. | Canonical invite/accept/revoke/onboarding lifecycle and complete actor-attributed audit history. |
| SEC-14 | Partner evidence | Partner onboarding evidence path verifies object existence/path but explicit storage owner comparison is not visible in inspected routine. | Enforce owner_id/uploader equality and bucket policy; verify in staging. |
| SEC-15 | Customer support | Support-ticket owner INSERT policy may permit caller-supplied operational fields; no-policy authenticated UPDATE/DELETE grants are unnecessary candidates. | Restrict client-settable columns and server-authoritative status/priority/assignment fields; validate with negative tests. |
| SEC-16 | Business milestones | Operational milestone RPC lacks strict predecessor order and durable idempotency; tracking UI capability flags are broader than server write authorization. | Exact-leg finite-state transitions, actor authorization, durable idempotency and consistent UI capability projection. |
| SEC-17 | Warehouse | Transfer dispatch may consume reserved stock; generic picking movement may bypass reservation accounting; return RPC lacks explicit SQL NULL guard. | Correct reservation math and NULL validation in reconciled migration, then concurrency/negative tests in isolated staging. |
| SEC-18 | Customs | No inspected government authority-evidence workflow for `cleared`; internal broker/document review is not government clearance. | Separate authority release record with issuer, jurisdiction, reference, evidence, independent verifier, validity and revocation. |
| SEC-19 | POD | Evidence controls are strong in code, but bucket `pod-documents` is unmanaged and signed URL/expiry/cross-tenant behavior not tested. | Consolidate on governed private bucket, test upload/read/revoke/expiry and independently verified POD customer access. |

## 4. P2 — Harden and monitor
- Normalize session validation (`getUser` vs `getSession`), stale-tab/revoked-membership behavior and sign-out redirects.
- Add alerts for audit-write failure, worker lease expiry, notification backlog, webhook duplicates, endpoint abuse and cron missed runs.
- Establish storage retention, deletion/export and evidence supersession policies.
- Review all remaining authenticated SECURITY DEFINER functions in risk-ranked batches, including role/permission changes, admin approvals, onboarding, claims and financial routines.
- Establish tenant-aware security dashboards and periodic access recertification.

## 5. Safe remediation sequence
### Phase A — No-production-change prerequisites
1. Finish schema-manifest generation and migration reconciliation.
2. Recover deployed Edge Function source parity and build a version/hash inventory.
3. Produce a complete function EXECUTE-grant and authenticated direct-DML dependency map.
4. Finalize nine-workspace authorization matrix and canonical organization/role authority.
5. Define staging test identities, tenant fixtures and negative-test cases.

### Phase B — P0/P1 code and migration work
6. Fix compliance fail-closed behavior.
7. Fix admin audit atomicity and read-error reporting.
8. Fix workspace type/permission guards and enterprise/operations authorization consistency.
9. Fix warehouse reservation and return NULL defects; add milestone sequencing/idempotency.
10. Govern POD storage, support-ticket writes, partner evidence ownership and consent lifecycle.
11. Recover worker leases/atomic claims and endpoint abuse protections.
12. Retire Cashfree only after dependency and deployed-source review.

### Phase C — Isolated staging certification
13. Run cross-tenant, wrong-role, revoked-membership, AAL1/AAL2, forged-claim, wrong-object-owner, expired-signed-URL and replay tests.
14. Inject database/audit/provider/worker failures and verify atomic rollback/recovery.
15. Run full synthetic customer-to-delivery journeys and verify all audit evidence.
16. Complete backup restore drill and security regression suite.

### Phase D — Controlled launch gates
17. Enable only approved India domestic pilot routes with source-backed country/corridor controls and verified contracted partners.
18. Keep customer freight payments direct to logistics partners; do not enable KRIM freight collection or finance posting.
19. Conduct final legal/CA, backup, operational and security sign-off before any live commercial execution.

## 6. Explicitly not proven / avoid false positives
- RLS enabled does not prove every policy is correct, but the 24 no-policy tables had no anon/authenticated DML grants in the inspected snapshot.
- A SECURITY DEFINER function is not automatically vulnerable; function body, search path, grants and call chain determine risk.
- Authenticated DML grants are review candidates, not proof of exploitation.
- Private bucket configuration does not prove signed URLs are correctly scoped or revoked.
- JWT-disabled Edge Functions may be intentionally public/webhook/worker endpoints; each needs a distinct application-authentication/verification model.
- No penetration test, adversarial browser test, user impersonation, data exfiltration or live provider test was performed.

## Release decision
**NO-GO for unrestricted production logistics execution, external partner onboarding, automated customer communications, government customs-clearance claims or financial collection.** Continue read-only audits and migration-safe planning. Do not apply production DDL, deploy function changes, modify RLS/grants or disable providers until the migration crosswalk, source parity and dependency checks are complete.

## Change boundary
This consolidation changes documentation only. No production schema/data/function/policy, secret, provider, account, user, partner, shipment, payment, notification or storage object was changed.
