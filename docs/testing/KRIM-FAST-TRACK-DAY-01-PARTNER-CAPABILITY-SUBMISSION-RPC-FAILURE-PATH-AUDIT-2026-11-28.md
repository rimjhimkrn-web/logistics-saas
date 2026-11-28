# KRIM Fast-Track Day 01 — Partner Capability Submission RPC Contract and Failure-Path Audit
Date: 2026-11-28
Target: KRIM Logistics Staging (`qrpcivhdxobiaofppbkl`)
Branch: `staging/phase00-env-isolation`
Production: not accessed or changed

## Scope
Read-only review of the deployed Staging definitions and ACLs for:
- `public.krim_partner_submit_service_capability(...)`
- `public.krim_partner_submit_service_capability_v2(...)`
- the caller in `public/partner/services-capabilities.html`

No RPC was invoked. No evidence file was uploaded. No table, function, grant, or row was changed.

## Live RPC contract

### Base submission RPC
Signature:
`krim_partner_submit_service_capability(bigint,bigint,text,bigint,text,numeric,boolean,boolean,text[])`

Observed Staging properties:
- Owner: postgres.
- SECURITY DEFINER; empty search_path.
- anon EXECUTE: denied.
- authenticated EXECUTE: denied.
- Returns JSONB.
- Derives caller from `auth.uid()`; rejects unauthenticated calls.
- Requires `private.krim_has_permission(uid, organization_id, 'partner.manage')`.
- Requires active registered-business partner organization and current compliance.
- Requires active transport mode and active country; accepts a fixed service-type allowlist.
- Bounds maximum weight and coverage region.
- Requires 1–5 distinct evidence paths in the exact `<org>/<uid>/capability/<filename>` convention.
- Verifies each object exists in private bucket `krim-partner-verification` and its owner_id matches the caller.
- Rejects an already-pending matching organization/mode/service/country/region request.
- Inserts an inactive, pending capability with evidence paths, submitter and timestamp in metadata.
- Writes a capability-submitted audit event.
- Returns `capability_id`, `verification_status=pending`, `active=false`, and `evidence_count`.

### v2 wrapper
Signature:
`krim_partner_submit_service_capability_v2(bigint,bigint,text,bigint,text,numeric,boolean,boolean,text[],jsonb)`

Observed Staging properties:
- Owner: postgres.
- SECURITY DEFINER; empty search_path.
- anon EXECUTE: denied.
- authenticated EXECUTE: granted.
- Validates details are a JSON object and no larger than 5 KB.
- Bounds equipment_details to 300 characters and operational_constraints to 1,500.
- Calls the base RPC, then stores only those two detail fields in `metadata.submission_details`.
- Returns the base result plus `details_saved=true`.

The wrapper and base call execute within the same PostgreSQL statement transaction: a wrapper failure rolls back the base insert and audit write. This does not roll back Storage uploads, which occur earlier in the browser.

## Caller contract match
The page sends the exact v2 argument names and types expected:
- organization, transport mode, service type, country, region, maximum weight, refrigerated, hazardous flag, evidence path array, details JSON object.
- It expects a returned `capability_id`, `verification_status=pending`, and `active=false`.
- It refreshes the workspace after confirmed success.

The page's client-side validation (1–5 PDF/JPEG/PNG files, max 10 MB each; bounded text fields) is additional UX validation. Server-side RPC validation remains authoritative.

## Confirmed failure-path and design gaps

### 1. Storage orphan risk on failed/uncertain submission — P1
The browser uploads evidence objects before calling the RPC. If an upload fails partway, the page attempts to remove the uploaded paths. However, if the RPC has been attempted and returns an error or the network outcome is uncertain, the page deliberately does not remove the uploaded files. This avoids deleting evidence after a commit whose response was lost, but it can leave orphaned objects when the database transaction actually rolled back.

Required correction design:
- Introduce a durable upload/submission intent or short-lived staging prefix with owner/org binding and expiry.
- After a confirmed database commit, associate the exact objects with the resulting capability/submission record.
- Provide a safe server-side cleanup process that deletes only old unreferenced objects after checking database references and ownership.
- Never have the browser delete files merely because it did not receive a response.
- Provide a reconciliation path for the ambiguous timeout case.

### 2. No request idempotency key — P1
The current duplicate check only blocks a matching request while a pending capability row exists. There is no client-supplied request key or durable upload-intent identifier. After an ambiguous network failure, a retry may be rejected as a duplicate or, depending on row state and concurrency, create a second request. The UI correctly tells the user not to retry blindly, but there is no supported recovery lookup.

Required correction design:
- Add a server-generated or validated idempotency key tied to caller, organization and submission intent.
- Persist the key with immutable submission history and return the original result for safe retries.
- Add a narrow status lookup by that same key, authorized to the submitting organization.
- Enforce uniqueness at the database level and test concurrent duplicate requests.

### 3. Capability metadata is being used as submission history — P1
Evidence paths, submitter and timestamp are stored in the mutable capability metadata JSON. The capability row itself is updated by the v2 wrapper to attach details. This is workable for the first submission but does not provide a robust append-only history for later evidence resubmissions or review cycles. The earlier onboarding audit also found that category declarations and later evidence submission are not joined by a versioned history model.

Required correction design:
- Use a dedicated append-only submission/version table.
- Keep evidence paths, submitter, timestamp, idempotency key, details and review linkage on the submission version.
- Review decisions must target the exact submission version.
- Do not overwrite prior evidence or silently reset verified/rejected/suspended capability states.

### 4. Read and submit paths have different authorization gates — P1
The proposed workspace read RPC must independently require:
- authenticated caller;
- exact active organization;
- owner-approved partner organization-type allowlist;
- `partner.manage` permission through the existing helper;
- organization-scoped rows only.

The submission RPC also has an additional registered-business and current-compliance gate. The UI's local organization-status checks are not an authorization boundary. The read RPC should not reveal private evidence paths or sensitive metadata.

### 5. Service/category alignment requires product review — P2
The submission RPC requires an active transport mode for every service type, including warehouse, customs and other non-transport categories. This may be intentional if KRIM models all capabilities through a mode, but it needs explicit product confirmation. The multi-category onboarding wrapper's earlier fallback to ROAD_FTL for categories outside the four transport modes makes this particularly important. Do not alter the accepted contract without a reviewed migration and category mapping.

### 6. Client-side organization selection is ambiguous for multi-org users — P2
The page picks the first active membership whose organization matches a legacy frontend allowlist. It does not ask the user to choose among multiple eligible partner organizations. The RPC rechecks permission and org status, but an unintended first match can still make the UI operate on the wrong organization. Use an explicit organization selector when more than one eligible membership exists, and align the frontend allowlist to canonical database values after owner approval.

## Recommended combined workspace contract
Retain separate read and submit operations:
1. `krim_partner_get_capability_workspace(p_organization_id bigint)` — bounded, minimized read of authorized capability records plus active country and mode catalogues.
2. `krim_partner_submit_service_capability_v2(...)` — keep the existing submission contract for compatibility until a versioned replacement is implemented and tested.
3. Add future submission-intent/idempotency and append-only submission-version operations only after local integration tests exist.

Do not combine read and write into one SECURITY DEFINER function. Keep each function narrow, independently authorized, and with explicit ACLs. The read function must not grant direct table access. The write function must not gain broader read or admin authority.

## Required tests before implementation/deployment
- Authenticated partner with partner.manage: valid request produces exactly one inactive/pending row and one audit event.
- Anonymous, customer, non-partner, inactive org, non-registered-business, non-compliant, no-permission, revoked membership: denied.
- Cross-tenant org ID: denied.
- Wrong owner, foreign org path, wrong bucket, missing object, malformed path, duplicate path, 0 or 6 files: denied.
- Invalid/inactive mode/country/service type, invalid numeric/oversized region/details, malformed JSON, oversized JSON: denied.
- Existing pending duplicate and concurrent duplicate attempts: deterministic result.
- Wrapper failure after base call: database row and audit event roll back atomically.
- Simulated browser timeout after commit: status lookup returns the committed result; no blind retry.
- Simulated failure before commit: cleanup reconciles orphan objects safely.
- Verify no email, notification or workflow event is emitted by capability submission.
- Confirm returned JSON keys and types exactly; no evidence paths are returned to the partner browser.

## Gate status
- Live Staging RPC source and ACL: inspected read-only.
- Frontend argument/response contract: source-matched.
- Orphan upload and idempotency gaps: identified.
- Versioned evidence history: design required; not implemented.
- Partner A/B runtime tests: not run; no independent partner test identities exist.
- Local Supabase/Postgres harness and Data API exposure: still unresolved.
- No migration, grant, frontend change, RPC invocation, fixture, upload, notification or deployment performed.
- Phase 00: OPEN — NOT APPROVED.
- Production: NOT ACCESSED OR CHANGED.
