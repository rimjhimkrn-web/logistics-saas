# Phase 00 — Gate C3.8: driver evidence, storage permissions and POD integrity audit

Date: 2026-11-25
Repository: rimjhimkrn-web/logistics-saas
Immutable source baseline: `72d75a18f985ceb09e468839435ee95700e11e46`
QA branch: `qa/phase-00-baseline-2026-11-25`
Scope: source review of driver POD evidence registration, private storage ownership/path policy, customer verified-POD access, admin preview/review, POD submission wrapper/internal creator, public driver POD route, customer ePOD vault, admin POD preview page, and prior storage/POD audit evidence. No object was uploaded, downloaded, signed, deleted or previewed. No SQL, RPC, storage policy, bucket setting, grant, data, account, provider or deployment was changed.

## 1. Executive decision

**PARTIAL PASS / BLOCKED — no certification for live POD evidence or customer downloads.**

Positive controls exist: the canonical driver evidence bucket is private; the observed production bucket configuration is 10 MiB with JPEG/PNG/WebP/PDF allowlist; metadata registration requires a current authenticated driver, own assignment, exact user/assignment path shape and an uploader-owned object; customer storage reads are gated on independently verified POD plus customer organization access; admin preview requires AAL2 and platform-admin permission.

However, two P1 integrity findings remain open and materially affect the chain of custody:
1. The authenticated driver POD wrapper does not compare the driver assignment's shipment-leg ID to the linked partner assignment's shipment-leg ID before it gathers evidence and calls the internal creator. A previously documented cross-leg binding weakness therefore remains present in the baseline source.
2. Admin POD review updates driver assignments using only `partner_assignment_id`, not the exact POD shipment/leg/organization/driver-assignment tuple. This can update an unintended or ambiguous driver assignment if relational integrity is inconsistent.

Additional gaps: internal POD creator accepts a client/wrapper-supplied evidence JSON object and checks only that it contains a driver-assignment ID and non-empty evidence array; the source does not establish that the internal routine independently resolves every evidence row/object and proves the full tuple. Signed URL issuance, expiry/revocation/cache behavior and file-content validation/malware scanning are not proven. Legacy `pod-documents` remains an unmanaged private bucket candidate.

## 2. Evidence chain reviewed

### A. Upload and metadata registration

Migration `20261105054211_secure_driver_delivery_evidence_registration.sql` defines an authenticated INSERT policy on `public.krim_driver_delivery_evidence`. The policy requires:
- `user_id = auth.uid()`;
- recipient name length 1–200 and notes <= 1,000;
- file size 1–10,485,760 bytes;
- content type JPEG, PNG, WebP or PDF;
- storage path beginning `<auth.uid>/<assignment_id>/` with exactly three path segments;
- a matching object in `storage.objects`, bucket `krim-driver-evidence`, owned by the authenticated user;
- a driver assignment owned by the user, not delivered/cancelled, and active driver membership in the assignment organization.

This is useful metadata-registration protection, but the source policy does not itself prove that the uploaded bytes match the declared MIME type or are safe to open. The table metadata is not a substitute for server-side content inspection.

### B. Private bucket and object ownership

The prior 16 November read-only storage audit recorded five private Production buckets and zero stored objects at that audit time. `krim-driver-evidence` had a 10 MB limit and JPEG/PNG/WebP/PDF allowlist. Driver evidence upload/read policies were scoped to the authenticated user's own assignment path. Customer reads were separately gated on verified POD. The legacy `pod-documents` bucket was private but had no bucket-level size/MIME limits and no bucket-specific policy; it was an unused/zero-object legacy candidate at that point.

Those are prior catalog observations, not a fresh current database query in this gate. No live bucket configuration, current object count, current effective storage ACL or current policy definition was queried here.

### C. Customer access to evidence

Migration `20261105140000_customer_access_verified_pod_evidence.sql` defines a Storage SELECT policy for `krim-driver-evidence` that requires:
- matching bucket and evidence path referenced in `krim_pod_records.evidence_metadata.driver_evidence`;
- POD status `verified` and non-null `verified_at`;
- shipment customer organization and `private.krim_has_organization_access(auth.uid(), customer_organization_id)`.

Migration `20261111130000_restrict_customer_pod_reads_to_verified_evidence.sql` separately defines customer POD-row SELECT only for verified records and authorized customer organization. Partner organization access is separately scoped.

This is the right intended distinction between submitted evidence and customer-visible verified evidence. It still depends on the evidence metadata path being a canonical, database-validated record bound to the exact driver assignment and leg. Because the POD creator accepts evidence JSON supplied by its caller and exact cross-leg binding remains unresolved, the customer read policy cannot by itself certify evidence provenance.

### D. Admin preview and review

The admin Storage SELECT policy for driver evidence requires bucket `krim-driver-evidence`, JWT AAL2 and `admin.platform` permission. Admin list/review RPCs also require authenticated user, AAL2 and platform-admin permission; review requires a reason and calls internal POD verification before delivery authorization.

**P1 reviewer assignment update:** migration `20261106010000_add_admin_pod_verification_and_delivery_authorization.sql` updates `krim_driver_assignments` with:
`WHERE partner_assignment_id = v_pod.assignment_id AND status NOT IN ('delivered','cancelled')`.
It does not constrain by `shipment_id`, `shipment_leg_id`, `organization_id`, `user_id` or an exact driver-assignment ID resolved from the POD evidence metadata. It uses scalar `RETURNING id,user_id`, which does not prove that exactly one row matched. This remains a P1 issue in the baseline.

### E. Driver submission and internal POD creator

Migration `20261106001500_add_authenticated_driver_pod_submission.sql` defines `krim_driver_submit_delivery_pod(uuid,text,text,text)`. The wrapper:
- authenticates with `auth.uid()`;
- locks a driver assignment belonging to that user;
- checks active driver membership and `in_transit` status;
- resolves a linked partner assignment with same shipment and organization and accepted/active status;
- collects registered evidence rows for that driver assignment and joins to `storage.objects` in `krim-driver-evidence` owned by the driver;
- sends JSON containing `driver_assignment_id` and evidence path/name/type/size/time to the internal POD creator.

**P1 exact-leg gap:** it does not compare `v_partner_assignment.shipment_leg_id` with `v_driver_assignment.shipment_leg_id`. The 15 November internal creator validates the commercial partner assignment's shipment/leg/partner tuple and active route-plan item, but that does not close the missing driver-assignment-to-partner-assignment leg equality in the wrapper.

The internal creator `krim_internal_submit_delivery_pod` accepts `p_evidence_metadata` and requires a driver assignment ID plus a non-empty driver evidence array. The inspected source does not establish that this internal function independently resolves every referenced evidence row and Storage object, and proves each row/object belongs to the exact driver user, driver assignment, shipment, leg, partner assignment and organization. Existing remediation note `docs/remediation-pending/2026-11-16-driver-pod-exact-leg-evidence-binding.md` explicitly calls for a canonical exact-tuple validator and evidence resolution from canonical database/storage records. No later baseline migration found in this review closes the exact wrapper leg comparison or the full internal evidence resolution requirement.

### F. Frontend surfaces

- `public/driver/pod-submission.html` is a small compatibility route, not an implementation of a full evidence capture/upload workflow.
- `app/driver/staging/page-11-proof-of-delivery.html` was previously inspected as an authenticated driver workspace page, but the page review did not establish an end-to-end binary upload, evidence registration and final POD submit flow.
- `app/admin/staging/page-06-delivery-pod-verification.html` explicitly identifies itself as a staging preview with no shipment or delivery evidence loaded. It is not proof of a live review console.
- `public/customer-os/customer-services/epod-vault.html` is informational content. It says no document, shipment record or download link is displayed on that public page and describes required secure access controls. It is not a live vault or download implementation.

## 3. Findings and required action

### P1 — exact driver-assignment ↔ partner-assignment leg binding
**Status: OPEN.** Add equality validation for driver assignment ID, driver user, partner assignment ID, shipment ID, shipment leg ID and organization before evidence collection and before internal POD creation. Revalidate under locks. Add a database-level integrity mechanism only after historical data inventory and migration reconciliation.

### P1 — reviewer must resolve exactly one driver assignment
**Status: OPEN.** Resolve exactly one driver assignment matching POD metadata and the complete POD/commercial tuple. Reject zero or multiple matches. Update only that row; insert the delivery event for the same exact assignment. Verify independent reviewer and AAL2 controls remain intact.

### P1 — canonical evidence resolution inside internal creator/reviewer
**Status: OPEN / ACL ALSO NOT TESTED.** Do not trust client JSON paths, file names, MIME, sizes or driver assignment IDs. Resolve evidence from `krim_driver_delivery_evidence` and `storage.objects`; prove bucket, object owner, path, assignment, user, shipment, exact leg, partner assignment and organization. Persist stable evidence row/object identifiers and a content hash where feasible. Review direct EXECUTE grants on every public SECURITY DEFINER entry point and private helper; prove internal functions are not callable by anon/authenticated.

### P2 — signed URL, cache and access audit
**Status: NOT TESTED.** Trace every browser/Edge Function preview/download path. Authorize each request server-side, issue short-lived signed URLs only after current membership/verified-POD checks, use private/no-store cache semantics, avoid URL persistence/logging/referrer leakage, and test expiry and membership revocation. A signed URL remains a bearer capability until expiry unless explicitly invalidated by the provider.

### P2 — content validation and malware controls
**Status: NOT TESTED.** Validate actual file signatures rather than trusting extension or client MIME; reject polyglot/malformed/oversized files; scan uploaded content before it can be reviewed or downloaded; quarantine failures. PDF and image preview must be sandboxed and avoid active content execution.

### P2 — legacy bucket `pod-documents`
**Status: RETIREMENT REVIEW.** It was private but had no bucket-level size/MIME restrictions and no bucket-specific policies in the prior audit. Keep private and unused until a repository/function/deployment dependency sweep plus migration reconciliation authorizes removal. Do not create new code against it.

## 4. Staging-only negative test matrix

Only after isolated Staging and migration parity are independently proven:
1. Anonymous upload/list/read/update/delete in driver evidence bucket.
2. Driver A uploads under Driver B path or assignment.
3. Wrong bucket, wrong owner, wrong user prefix, extra/missing path segment, path traversal and duplicate path.
4. Metadata row with forged MIME/size/name or object mismatch.
5. Declared JPEG containing non-image bytes; malformed PDF; oversized file; malware test fixture.
6. Evidence registration after assignment delivered/cancelled or membership revoked.
7. Driver assignment leg differs from linked partner assignment leg on same shipment.
8. Driver assignment shipment/org differs from partner assignment shipment/org.
9. Internal POD creator called directly by anon/authenticated; must reject.
10. Internal POD metadata references evidence row/object belonging to another driver, assignment, leg, shipment or partner.
11. Evidence object deleted/replaced after registration or after review.
12. Customer reads before submission, submitted, under_review, rejected, verified, and after organization membership revocation.
13. Customer A guesses Customer B's path, POD ID, shipment ID, filename and signed URL.
14. Admin AAL1 vs AAL2; missing permission; submitter/self-review; reviewer ambiguity; multiple driver assignments for same partner assignment.
15. Reviewer update affects exactly one matching driver assignment and cannot mutate unrelated assignment.
16. Signed URL expiry, cache headers, referrer leakage, browser history, download logging and membership revocation.
17. Duplicate exact submission, conflicting retry, concurrent submit/review and transaction rollback.
18. Retention, evidence supersession, legal hold, deletion and audit trail.

Record environment/project ref, commit, actor, payload hash, expected/actual, SQL/RLS/storage/audit evidence, timestamps and artifacts for each case. No synthetic users or objects were created in this gate.

## 5. Gate result and release decision

| Control | Result |
|---|---|
| Private canonical driver evidence bucket (prior catalog evidence) | PARTIAL PASS |
| Driver metadata registration owner/path/assignment checks | PASS at source level |
| Customer verified-POD Storage policy | PASS at source level, dependent on canonical metadata integrity |
| Admin AAL2 preview/review gate | PASS at source level |
| Exact driver-to-partner shipment-leg binding | FAIL / OPEN P1 |
| Reviewer exact driver-assignment tuple | FAIL / OPEN P1 |
| Internal creator independently resolves every evidence object | NOT PROVEN |
| Effective function EXECUTE ACLs in live projects | NOT TESTED |
| Signed URL issuance/expiry/cache/revocation | NOT TESTED |
| File byte validation/malware scan | NOT TESTED |
| Legacy `pod-documents` retirement | BLOCKED |
| End-to-end driver upload → submit → independent verify → customer download | BLOCKED |

**Gate C3.8: PARTIAL PASS / BLOCKED. NO-GO for live driver POD submission, verification and customer evidence download certification.** The exact driver-to-leg binding and reviewer assignment tuple must be fixed and staged-tested before release. The prior storage audit's zero-object snapshot and bucket settings are historical read-only evidence, not a fresh live catalog result.

No Production/Staging SQL, RPC, object, row, schema, policy, grant, bucket, account, provider or deployment was changed.
