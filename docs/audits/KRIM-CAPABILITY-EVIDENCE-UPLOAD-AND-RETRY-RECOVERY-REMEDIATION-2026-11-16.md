# KRIM Capability Evidence Upload, Submission Retry and Orphan Recovery Remediation — 2026-11-16

## Executive result

The partner capability submission handler has been hardened in the repository to distinguish three materially different outcomes:
1. upload failed before the database submission was attempted;
2. database submission was attempted but the result was not confirmed;
3. database submission was confirmed, but the capability-register refresh failed.

Previously, all errors were reported as a generic submission failure and the UI warned that files may remain, even when the database had already created the capability. That could encourage duplicate submissions after a successful RPC followed by a failed refresh.

Application change commit: `55299bc419283f6949cf073f0941cee936c44ca1`.

No production DB, Storage, Auth, partner capability, or evidence objects were changed. No upload, delete, RPC or signed URL action was executed during this work.

## What changed

File: `public/partner/services-capabilities.html`.

### A. Partial upload failure before RPC
- Successfully uploaded paths are tracked in memory.
- If a later upload fails before the RPC is called, the page attempts to remove only those partial objects from the authenticated partner's own capability path.
- If Storage confirms removal, the user is told that no capability request was submitted and a retry is safe.
- If removal is denied or uncertain, the page does not claim cleanup; it warns that private files may remain and tells the user to contact support before retrying.

This relies on the existing category-specific cleanup policy for unlinked partner-verification evidence. That policy must still be verified in staging. A failed cleanup is treated as unresolved, not silently ignored.

### B. Ambiguous RPC response
- The handler records when the submission RPC has been attempted.
- If the RPC returns an error or malformed/unconfirmed result, it does **not** delete uploaded files. The request may have committed even if the browser did not receive a conclusive response.
- The applicant is told not to retry until the capability register or support confirms whether a pending request exists.
- This avoids destructive cleanup of evidence that may already be referenced by a committed capability.

### C. Confirmed submission and failed register refresh
- Once the RPC returns a capability ID and confirms `verification_status = pending` and `active = false`, the handler immediately treats the submission as successful.
- It resets the form and clears the local draft.
- Register refresh is handled in a separate guarded block.
- If refresh fails, the UI explicitly says the capability was submitted, remains pending/inactive, and must not be submitted again.

### D. Existing controls retained
- 1–5 evidence files.
- PDF/JPEG/PNG only.
- 10 MB maximum per file in client validation.
- Private `krim-partner-verification` bucket.
- Existing organization/uploader path structure.
- Existing `krim_partner_submit_service_capability_v2` RPC.
- Server-created capability must remain pending and inactive.
- No auto-approval, no commercial activation and no special-handling authorization.

## Important limitations

This is a safer client-side recovery path, not a complete durable upload transaction.

1. Client-side MIME/size checks are convenience checks; server-side Storage bucket limits and RPC metadata validation remain authoritative.
2. A browser crash or tab close after uploads but before RPC can still leave private orphan files. There is no durable upload-session ledger in this change.
3. If the RPC outcome is ambiguous, the applicant still needs a reliable register/support reconciliation path. The current page does not automatically search for an idempotency key because the RPC contract does not expose one.
4. The cleanup call depends on the existing RLS delete policy. Its exact capability-path behavior is not proven by source inspection alone.
5. A signed URL expiry/revocation, malware scan, file-content inspection, retention or backup/restore test was not performed.
6. A malicious user can bypass browser checks; server-side Storage restrictions and RPC checks must continue to enforce ownership, tenant, MIME and size.

## Recommended next engineering phase

After migration reconciliation and authorized staging setup:
- introduce a server-issued upload session / submission idempotency key;
- persist upload intent and object paths before or during uploads;
- make the database submission RPC idempotent for that key;
- provide an applicant-visible status lookup for pending/accepted/rejected submissions;
- reconcile expired incomplete upload sessions with a scheduled, auditable cleanup worker;
- cleanup only objects proven unreferenced by any capability, verification or other evidence record;
- test concurrent submissions, browser interruption, network timeout after server commit, partial upload, duplicate filenames and storage delete denial;
- verify every object remains private and inaccessible cross-tenant.

Do not build a broad deletion routine that removes all files under a user or organization prefix. Cleanup must be limited to exact object paths from an authenticated upload session and must check that no evidence record references them.

## Verification status

Source review confirms:
- upload paths are tracked;
- partial upload cleanup is attempted only before RPC invocation;
- ambiguous RPC outcomes do not trigger deletion;
- confirmed submission is separated from later register refresh;
- refresh failure no longer reports a false submission failure;
- success response requires a capability ID, pending status and inactive state.

Not performed:
- authenticated browser test;
- live Storage upload/delete;
- staging RPC invocation;
- cross-tenant object access test;
- concurrency/idempotency test;
- orphan sweeper test;
- full JavaScript browser execution.

## Release decision

This improves recovery messaging and best-effort partial-upload cleanup. It does not certify evidence storage or eliminate orphan objects after abrupt browser termination. KRIM remains **NO-GO for partner activation and real shipment execution** until staging tests, migration reconciliation and the remaining operational gates are complete.
