# KRIM Fast-Track Day 01 — Partner Evidence Storage, Cleanup and Review-Lineage Audit
Date: 2026-11-28
Target: KRIM Logistics Staging (qrpcivhdxobiaofppbkl)
Branch: staging/phase00-env-isolation
Production: not accessed or changed

## Scope and safety
Read-only inspection of the Staging bucket configuration, storage.objects RLS policies and grants, capability submission page, deployed submission/review functions, audit-event schema and aggregate row counts. No files were uploaded, downloaded or deleted. No RPC was invoked. No database or Storage mutation occurred.

## 1. Bucket controls — verified
Bucket krim-partner-verification:
- Private (public=false).
- Maximum object size: 10 MiB.
- MIME allowlist: PDF, JPEG, PNG.
- Staging currently has 0 objects in this bucket; 0 capability-folder objects.
- Staging currently has 0 krim_partner_capabilities rows; no evidence metadata or review metadata exists to validate against live sample rows.

The frontend's 10 MiB and MIME checks match the bucket configuration.

## 2. Storage policy and cleanup gap — confirmed P1
Relevant Storage policies currently found:

### INSERT
Two authenticated INSERT policies apply:
- krim_partner_verification_upload_own_org: requires the target bucket, path shape with caller UUID in segment 2, active membership and active organization, and an organization type from the policy's six-value allowlist.
- krim_partner_verification_upload_require_aal2: requires JWT AAL2.

PostgreSQL combines permissive policies with OR semantics, so the exact combined policy behavior must be checked carefully: the membership/path policy and the AAL2 policy are separate permissive policies. As currently written, either matching INSERT policy can authorize an insert. Therefore the AAL2 requirement is not proven to be mandatory merely because the second policy exists. This is a potential security gap: AAL2 should be a condition in the same effective authorization predicate (or enforced by a restrictive policy/verified storage function), not an independent permissive policy that can be satisfied separately.

### SELECT
The authenticated SELECT policy allows the object owner in their own active organization path; a user with partner.manage for that organization; or an AAL2 platform admin. The bucket remains private, but authenticated reads are intentionally possible under this policy. This should remain limited to the evidence review workflow and should be tested with Partner A/B and platform-admin sessions.

### DELETE
- Authenticated has the underlying SQL DELETE table privilege on storage.objects.
- There is no matching DELETE policy for krim-partner-verification in the inspected policy set.
- RLS therefore prevents the authenticated browser caller from deleting these bucket objects through the normal Storage API unless another applicable policy exists outside the filtered policy set. The complete bucket-specific policy query returned only INSERT and SELECT policies; no DELETE policy was present.

The frontend attempts storage.remove(paths) when an upload fails before the RPC call. That cleanup is likely to be rejected by RLS under the current policy set. The page handles this by displaying that cleanup could not be confirmed, but the intended partial-upload cleanup path is not currently supported by the database policy. No delete was attempted.

Do not solve this by granting broad authenticated DELETE. Use a narrow server-side cleanup endpoint or a tightly scoped DELETE policy that proves caller ownership, exact bucket, exact organization path, and that no capability/submission record references the object. Prefer server-side reference checks for retained evidence.

## 3. AAL2 policy composition concern — P1 security review
The upload path is protected by two permissive INSERT policies: one validates org/path/membership; the other validates AAL2. PostgreSQL permissive policies are OR-combined, not AND-combined. A caller satisfying only the first policy may pass the policy check without satisfying the AAL2 condition. This requires a corrective policy design and authenticated test before further evidence uploads are enabled.

The policy should enforce, in one effective predicate: authenticated role and non-null auth.uid(); AAL2; private bucket exact match; path <organization_id>/<auth.uid()>/capability/<safe filename>; active organization and membership; canonical owner-approved partner organization type; preferably partner.manage permission, if upload is intended to be restricted to capability managers.

Review SELECT policies separately; do not unintentionally block the reviewer workflow.

## 4. Ownership field inconsistency — P1 correctness risk
The submission RPC validates Storage ownership using storage.objects.owner_id = auth.uid()::text. The admin review RPC validates the same object using storage.objects.owner = submitter_uuid.

Staging's storage.objects currently contains both columns: owner (uuid) and owner_id (text). The empty Staging bucket means there are no real objects with which to prove these values are consistently populated or equal. Standardize both submission and review validation on one documented canonical ownership representation, and test it with an actual owner-uploaded object in an isolated test environment. Do not assume both columns always match.

## 5. Submission and review evidence linkage
The submission RPC writes evidence paths, submitter UUID, submission timestamp, submission source, capability row ID and evidence count in the audit event.
The admin review RPC requires AAL2 and admin.platform; locks the capability and organization; only reviews pending capability rows; rejects self-approval; validates 1–5 evidence paths, expected organization/submitter path and object ownership; blocks standard approval for hazardous and refrigerated declarations; updates capability status and active state; writes reviewed_at, reviewed_by, decision and reason into the same mutable capability metadata; and writes before/after state to krim_audit_events.

The audit table has structured actor, organization, event/entity identifiers, request/event IDs, metadata and previous/new state. This gives a review event trail, but the evidence path and submission version are not represented by a dedicated immutable submission record. Later metadata updates or resubmission design can make the current capability metadata insufficient to identify exactly which evidence set was reviewed.

## 6. Required corrective architecture
1. Keep the bucket private and preserve its current file size/MIME limits unless product requirements justify a reviewed change.
2. Correct the AAL2 upload policy composition; ensure AAL2 is mandatory in the effective policy.
3. Implement a versioned capability submission record with immutable evidence path list, submitter, submitted timestamp, idempotency key and status.
4. Make review decisions reference the exact submission-version ID and preserve reviewer, AAL2 evidence, decision, reason and timestamp in append-only history.
5. Standardize Storage ownership validation to a single canonical field with a verified migration/runtime compatibility plan.
6. Implement orphan cleanup as a server-side scheduled/owner-authorized process: exact bucket and capability staging namespace; exclude objects referenced by current or historical submissions; enforce safety age and owner/org binding; log deletion attempts/results; support dry-run and bounded batches; never delete on ambiguous client timeout.
7. Add idempotent submission-intent/status recovery so clients can safely query the result after a lost RPC response.
8. Add integration tests for Storage policy OR composition, AAL1/AAL2, own-org/foreign-org paths, owner/manager/admin SELECT, DELETE denial, and cleanup reference protection.

## 7. Test status and gates
- Bucket privacy, size and MIME limits: verified from Staging catalog.
- INSERT/SELECT policy definitions and DELETE-policy absence: verified read-only.
- Underlying authenticated DELETE privilege: verified present; policy still denies row access absent another applicable policy.
- Storage AAL2 enforcement: not proven; policy composition indicates a likely bypass.
- Actual object owner/owner_id parity: unverified; bucket empty.
- Actual browser cleanup request: not invoked.
- Submission/review E2E: not run; no partner fixtures or capability rows.
- No storage files, database rows, policies, grants or functions changed.
- Phase 00: OPEN — NOT APPROVED.
- Production: NOT ACCESSED OR CHANGED.