# Phase 00 — Data export request, worker, storage and download authorization audit
Date: 2026-11-25
Branch: qa/phase-00-baseline-2026-11-25
Scope: Read-only Production Supabase catalog, Storage bucket metadata/policies, Edge Function inventory, and repository code search. No export was requested or generated; no objects were listed/downloaded; no signed URLs were created; no provider calls or writes.

## Executive result
**NOT PASS — export lifecycle is not evidenced end-to-end.** Production contains a user-owned export-request queue table, but the inspected database function catalog and active Edge Function inventory did not reveal a dedicated export worker, export generator, signed-download handler, or export scheduler. This is not proof that no implementation exists elsewhere, but the operational chain cannot currently be verified. Do not expose or rely on data exports for real customers until the full request-to-download lifecycle is identified and tested.

## Verified controls
1. Production `krim_data_export_requests` has RLS enabled.
2. Its SELECT policy restricts visible rows to `user_id = auth.uid()`; INSERT policy has the same own-user check.
3. Production grants authenticated SELECT and INSERT on this table; UPDATE and DELETE are not granted.
4. Staging has the same two RLS policies but no authenticated table privileges, so ordinary authenticated queue access is not available there.
5. All five Production Storage buckets are private:
   - `krim-driver-evidence` — 10 MiB limit; JPEG/PNG/WebP/PDF
   - `krim-driver-verification` — 10 MiB limit; JPEG/PNG/WebP/PDF
   - `krim-partner-verification` — 10 MiB limit; PDF/JPEG/PNG
   - `krim-warehouse-evidence` — 10 MiB limit; JPEG/PNG/PDF
   - `pod-documents` — no bucket-level size or MIME allowlist configured
6. The sampled Storage policies are object-specific and include ownership, organization, shipment, assignment, or permission predicates for the evidence buckets. No export-specific bucket or export-specific Storage policy was identified in the returned policy inventory.

## Findings
### F1 — Queue table does not establish an export pipeline
The export request schema contains: `id`, `user_id`, `export_scope`, `status`, `requested_at`, `completed_at`, `result_reference`, and `failure_code`. This is queue metadata only. The catalog search did not identify a matching export processor, generator, completion callback, scheduler, or download endpoint. A result_reference text value is not evidence of a safe file-serving mechanism.

### F2 — No dedicated export worker found in the active Edge Function inventory
Production active functions included KRIM AI, payments, tracking, notification retry/provider, admin, contact inquiry, growth operations, and related functions. No export-specific function appeared. Staging's active function inventory likewise did not show an export worker. Repository code search for the export queue and common export/download/signed-URL terms returned no matches through the connected GitHub search index. Search-index limitations mean this is a bounded discovery result, not proof of global absence.

### F3 — No export-specific download authorization demonstrated
No dedicated handler was found that re-checks the authenticated user, organization membership, export scope, allowed columns, row-level scope, file ownership, expiry, and revocation immediately before download. Do not assume that an unguessable object path or a signed URL alone is sufficient authorization.

### F4 — Export request authorization is user-scoped, not visibly organization-scoped
The queue's RLS predicate only establishes that the requester owns the request row. The table schema does not include an explicit organization_id, requested-by organization context, selected data scope/fields, or a clear audit/retention lifecycle. If export_scope embeds these values, its validation and interpretation remain unverified. The worker must independently derive allowed organization scope from current membership/permissions rather than trusting caller-supplied identifiers or arbitrary serialized scope.

### F5 — Staging cannot currently exercise normal authenticated export queue access
Staging has the RLS policies but lacks authenticated SELECT/INSERT table privileges. This is fail-closed but blocks ordinary end-to-end QA until a controlled test-only access design exists. Do not copy Production grants blindly.

### F6 — POD Storage bucket lacks bucket-level upload constraints
The private `pod-documents` bucket has no configured file-size limit or allowed MIME type list. The bucket being private is positive, but it does not prove file-type or payload safety. Before real POD uploads, enforce server-side size, extension, MIME, byte-signature/content validation, malware scanning/quarantine where feasible, and evidence ownership checks. Do not mistake client-supplied Content-Type for validation.

## Required controls before enabling exports
1. Identify or implement one explicit export worker and one authenticated download endpoint; document exact source, deployment version, and environment.
2. Validate requester's active user, active organization membership, export-specific permission, organization scope, allowed export type/columns, and row count/size limits at enqueue and again during processing.
3. Make queue transitions server-only; use atomic claim/lease, idempotency, bounded retries, stale-job recovery, and audit events.
4. Generate files into a dedicated private export bucket with strict size/MIME policy and per-object ownership metadata.
5. Use short-lived signed downloads only after a fresh authorization check; bind the object to the request/user/org, enforce expiry, and provide revocation/deletion and retention.
6. Prevent caller-controlled `result_reference` from becoming an arbitrary storage path or URL; worker must set it only after successful generation and validate it before serving.
7. Add synthetic two-tenant positive/negative tests: own export, another user's request, another organization's rows, revoked membership, expired link, tampered result reference, repeated enqueue, worker retry, and stale lease.
8. Establish equivalent isolated Staging test access and test-sink protections before any writes or exports are run.

## Evidence limitations
- No export rows were read.
- No worker/function was invoked.
- No Storage objects were listed, read, or downloaded.
- No signed URLs were created.
- No live browser request or API endpoint was exercised.
- Edge Function list and repository search are bounded to connected project/index visibility; implementation may exist outside searched source paths.
- Bucket metadata and Storage policy catalog do not prove upload bytes are safe or signed URL revocation works.

## Change record
No database, Storage, Auth, Edge Function, secrets, code, deployment, or provider changes were performed. Report committed only to the QA branch.
