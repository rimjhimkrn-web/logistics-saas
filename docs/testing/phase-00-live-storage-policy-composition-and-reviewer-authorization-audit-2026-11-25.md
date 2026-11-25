# Phase 00 — Live Storage policy composition and reviewer authorization audit

**Date:** 2026-11-25  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Evidence:** Read-only catalog queries against Production project `ebltviniygljwwseplph` and Staging project `qrpcivhdxobiaofppbkl`, plus function-definition/ACL inspection.  
**No changes:** No policy, bucket, function, data, Auth, secret or deployment mutation.

## Executive result

Both Supabase projects are currently `ACTIVE_HEALTHY`. This pass found:

1. **Staging AAL2 upload policy is ineffective as a restriction.** Staging has two permissive INSERT policies on `storage.objects` for `krim-partner-verification`. One checks active organization membership and folder ownership; the other checks AAL2. PostgreSQL permissive policies combine with OR, so a caller satisfying the first policy can upload without satisfying the AAL2 policy. The policy named `krim_partner_verification_upload_require_aal2` does not enforce AAL2 while the broader policy remains permissive.
2. **Staging Storage bucket parity is incomplete.** Of the reviewed evidence buckets, Staging contains `krim-partner-verification` only. Production contains `krim-partner-verification`, `krim-driver-verification`, `krim-driver-evidence`, and `krim-warehouse-evidence`. Driver verification/POD and warehouse evidence flows cannot be meaningfully tested against Staging until bucket configuration and policy parity are deliberately established.
3. **Production partner upload policy has no AAL2 requirement.** The effective Production INSERT policy for `krim-partner-verification` checks active organization membership, active organization and supported partner/warehouse provider type, and that the object path's second segment is the caller. No AAL2 predicate is present in that upload policy. This is not automatically a defect unless step-up authentication is a product/security requirement for partner uploads; it is a divergence from Staging's attempted AAL2 policy.
4. **Reviewer RPC authorization is materially stronger than the page labels.** Capacity list/review functions and driver document review function bodies enforce authenticated caller, AAL2 and `admin.platform` permission. Capacity review also blocks self-approval, requires current partner compliance, verified transport capability, future availability, evidence existence and original submitter ownership. Driver review checks AAL2, platform-admin permission, self-review prohibition, original object ownership and required accepted documents before driver verification.
5. **Staging driver-review execution privilege differs from Production.** The driver review function is executable by `authenticated` in Production, but only `service_role` and `postgres` in Staging. Do not treat the Staging driver review UI as runtime-testable until this intentional or accidental parity difference is resolved in a reviewed change.

## Effective Storage policy details

### Production

Observed relevant policies include:

- `krim_partner_verification_upload_own_org` — INSERT; caller must own the second path segment and be an active member of an active organization whose type is one of the supported partner/provider types.
- `krim_partner_verification_read_own_org` — SELECT; active organization membership and supported organization type, with organization ID in the first path segment.
- `krim_partner_verification_admin_read` — SELECT; AAL2 and `admin.platform`.
- Additional path-specific customs, customs shipment-document, claim evidence, capacity cleanup and service-area cleanup policies.
- `krim_driver_verification_upload_own` — INSERT; caller-owned user/profile path and active driver membership in an active organization.
- `krim_driver_verification_admin_read` — SELECT; AAL2 and `admin.platform`.
- `Drivers upload evidence for own assignment` and `Drivers read evidence for own assignment` — scoped to the authenticated driver's own non-delivered/non-cancelled assignment in an active organization.
- `Platform admins preview driver POD evidence` — SELECT; AAL2 and `admin.platform`.
- `Customers read evidence for verified POD` — SELECT; only evidence paths attached to verified POD records for shipments in the customer's authorized organization.

The reviewed buckets are private, with a 10 MiB per-file limit. The partner bucket allows PDF/JPEG/PNG; driver evidence and driver verification allow PDF/JPEG/PNG/WebP; warehouse evidence allows JPEG/PNG/PDF.

### Staging

Observed relevant policies for `krim-partner-verification`:

- `krim_partner_verification_upload_own_org` — INSERT; active member and active supported organization plus caller-owned path.
- `krim_partner_verification_upload_require_aal2` — INSERT; AAL2 check only.
- `krim_partner_verification_read_own_org` — SELECT; active member and active supported organization.

Because the two INSERT policies are permissive and are OR-combined, the AAL2 policy is not a mandatory gate. It must be replaced by one combined policy or a restrictive policy design that preserves the intended predicate. Do not patch production or staging in this audit.

Only the `krim-partner-verification` bucket was present among the reviewed evidence buckets in Staging. The Production driver-verification, driver-evidence and warehouse-evidence buckets were not present in Staging at query time.

## Reviewer RPC ACL and body review

### Capacity review

Production and Staging both show:
- `krim_admin_list_capacity_resources_lane_aware()` is SECURITY DEFINER and executable by authenticated.
- It delegates to `krim_admin_list_capacity_resources()`, whose body checks non-null `auth.uid()`, JWT AAL2, and `private.krim_has_permission(...,'admin.platform')`.
- `krim_admin_review_capacity_resource(bigint,text,text)` is SECURITY DEFINER and executable by authenticated. Its body independently checks AAL2 and `admin.platform`, rejects self-approval, and validates evidence ownership/existence and current partner/capability/availability gates before approval.

The list wrapper itself does not repeat the checks, but it calls the protected base function. The authorization therefore depends on that delegation remaining intact; future refactors must preserve the gate.

### Driver document review

- Production ACL: `authenticated` EXECUTE (plus postgres/service_role).
- Staging ACL: service_role only (plus postgres).
- Both inspected function bodies require authenticated caller, AAL2 and `admin.platform`; reject reviewer self-review; require original driver object ownership before acceptance; and require licence front, licence back, identity document, current licence expiry, eligible partner organization/capability and active driver membership before setting profile verified.

This is source/catalog assurance only. No caller was authenticated and no RPC was invoked.

## Required remediation before Staging runtime tests

1. Redesign Staging partner-verification INSERT policy composition so AAL2 is truly mandatory if that is the intended control; verify effective policy semantics, not policy names.
2. Decide and document whether partner evidence uploads require AAL2 in Production. If yes, implement a single combined predicate or equivalent restrictive policy after review.
3. Provision the missing Staging evidence buckets and matching private bucket settings/policies only through an approved migration/configuration plan; do not copy Production data.
4. Reconcile Staging driver-review EXECUTE ACL and intended invocation path. Do not grant authenticated execution merely for parity without confirming the function's internal checks and frontend caller.
5. Build synthetic two-tenant tests for cross-organization read denial, wrong-owner upload, AAL1/AAL2 upload behavior, admin preview access, self-review denial, and revocation.
6. Confirm effective Storage policies after remediation by querying `pg_policies` and running isolated signed-in tests.

## Status

- Production Storage catalog: **PARTIAL PASS** for inspected scoped policies; runtime isolation remains untested.
- Staging partner-verification INSERT AAL2: **FAIL** — policy composition does not enforce the intended AAL2 condition.
- Staging evidence bucket parity: **FAIL / NOT READY** — required driver and warehouse buckets absent from reviewed bucket set.
- Reviewer RPC source checks: **PASS (static/catalog evidence only)** for the inspected function bodies.
- Reviewer runtime authorization: **NOT TESTED**.
- Cross-tenant Storage runtime tests: **NOT TESTED**.

## Safety boundary

Read-only catalog and function-definition queries only. No Storage objects were listed or accessed. No signed URLs, uploads, downloads, deletes or RPC calls were made. No database writes, policy changes, bucket changes, Auth changes, secrets, deployments or merges occurred.
