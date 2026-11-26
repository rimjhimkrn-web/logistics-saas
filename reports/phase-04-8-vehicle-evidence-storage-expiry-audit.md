# KRIM Phase 04.8 — Vehicle Evidence Lifecycle, Storage and Expiry Audit

Date: 2026-11-26
Branch: remediation/phase-03dw-isolation-2026-11-26
Scope: Static review of vehicle registration, upload, evidence registration, admin review, verification and expiry code; live read-only Production/Staging comparison of buckets, Storage policies, RLS, function ACLs, cron extension/job and country/category requirements.

## Decision

**Vehicle evidence lifecycle is not production-onboarding-ready and synthetic fleet testing remains BLOCKED.** The underlying database functions have several strong controls, but the current environment configuration is incomplete and diverges materially.

No file was uploaded, no vehicle was registered, no document or requirement was changed, no cron job was created, no permission was granted, and no database or deployment state was modified.

## 1. Partner vehicle registration and upload call path

Source: `app/partner/vehicle-registry.html`

Flow:
1. Partner page authenticates through the shared Supabase client.
2. It selects active owner/manager memberships in active organizations; it does not rely solely on client checks because the RPC repeats authorization.
3. Calls `krim_vehicle_register(...)` to create a vehicle in pending verification / pending operational state.
4. Partner chooses a vehicle, document type, document number, issuing country, issue/expiry dates and file.
5. Browser validates PDF/JPEG/PNG and a 10 MiB maximum, then uploads to private `krim-partner-verification` at:
   `{organization_id}/{user_id}/vehicle/{vehicle_uuid}/{random_filename}`
6. Browser calls `krim_vehicle_document_register(...)`.
7. If registration fails after upload, page attempts to remove the uploaded orphan object.
8. Page loads document status via `krim_vehicle_documents_list(...)`.

Live database checks in Production:
- `krim_vehicle_register` requires active owner/manager membership in an active organization; the created vehicle defaults to pending verification and pending operational status.
- `krim_vehicle_document_register` independently checks active organization membership, exact organization/user/vehicle path, permitted MIME type, 1–10 MiB size, matching Storage object owner, matching actual MIME/size metadata, valid country code, and expiry not before issue date.
- `krim_vehicle_documents_list` scopes returned records to active membership in the vehicle's organization.
- `krim_vehicle_review_document` requires AAL2 and platform-admin permission through `krim_vehicle_admin_guard()`, prevents self-review, rejects final-state re-review, rejects expired evidence, verifies the object path, original uploader ownership and stored MIME/size before approval, then audits the decision.
- `krim_vehicle_finalize_verification` requires at least one mandatory requirement, every mandatory document approved and current, and reviewer independence from the vehicle registrant and all evidence submitters before activating the vehicle.
- RLS is enabled on `krim_vehicles`, `krim_vehicle_documents`, and `krim_vehicle_document_requirements` in both environments (FORCE RLS is false).

## 2. Private Storage bucket comparison

Production:
- `krim-partner-verification`: private, 10 MiB limit, PDF/JPEG/PNG.
- `krim-driver-verification`: private, 10 MiB limit, JPEG/PNG/WebP/PDF.

Staging:
- `krim-partner-verification`: private, 10 MiB limit, PDF/JPEG/PNG.
- `krim-driver-verification`: **MISSING**.

Vehicle uploads use the partner-verification bucket, which exists in both environments. Driver evidence uploads cannot be exercised in Staging because its dedicated driver-verification bucket is missing (recorded here because this is the connected vehicle/driver readiness chain).

### Storage policy differences

Production `krim-partner-verification` vehicle evidence:
- Upload policy checks active membership in the organization encoded in the first path segment, and that the second path segment equals the authenticated user ID.
- Read policy checks active membership in the organization encoded in the first path segment and recognized partner/warehouse organization type.
- Admin evidence read policy requires AAL2 and `admin.platform`.

Staging:
- Same own-organization upload/read path constraints.
- An additional RESTRICTIVE INSERT policy requires AAL2 for all uploads to `krim-partner-verification`.
- Production has no corresponding restrictive AAL2 upload policy.

This is a real behavior difference: the vehicle registry page does not itself force AAL2 for partner uploads. An AAL1 partner session may upload in Production but be denied in Staging. Do not remove the Staging restriction without deciding the intended assurance level for every evidence category in this shared bucket; a safer long-term design may separate partner operational documents from higher-sensitivity verification evidence into purpose-specific buckets and policies.

The partner upload policy's path ownership checks are positive controls. Browser/runtime cross-tenant tests and signed-URL read tests remain NOT TESTED.

## 3. Country/category requirements are empty in both environments

Read-only count:
- Production `krim_vehicle_document_requirements`: 0 total rules, 0 mandatory.
- Staging: 0 total rules, 0 mandatory.
- No country/category requirement profiles exist in either environment.

This is currently fail-closed: `krim_vehicle_finalize_verification` refuses verification when no mandatory requirements are configured. The admin console explicitly warns that no requirement profile blocks verification.

Important risk: `krim_vehicle_set_document_requirement(...,p_is_required)` lets an authorized AAL2 platform admin create or change a requirement, including setting it optional. The finalizer does require at least one mandatory document, but there is no reviewed country/category baseline in the live data. A requirement profile must be created only from an approved jurisdiction/category checklist; do not guess legal requirements or mark a requirement optional just to make verification pass.

The UI copy includes an India goods-carriage checklist and references Jharkhand transport sources, but this is guidance text, not a populated database requirement profile and not a substitute for route/category legal review. Hazardous-goods vehicles require a distinct category profile and remain out of scope until separately designed.

## 4. Independent review and expiry behavior

Admin source: `app/admin/vehicle-verification.html`

- The page checks session AAL2 for early UX feedback.
- Database functions independently call `krim_vehicle_admin_guard()`, which verifies authenticated identity, AAL2 and `admin.platform`.
- Admin reviews document evidence through `krim_vehicle_review_document`.
- Admin finalizes only after mandatory evidence is satisfied through `krim_vehicle_finalize_verification`.
- The page invokes `krim_vehicle_refresh_expiry()` during refresh.

Production expiry:
- `pg_cron` 1.6.4 and `pg_net` 0.20.4 are installed.
- Active cron job `krim-vehicle-evidence-expiry` runs every five minutes and invokes `private.krim_internal_refresh_vehicle_expiry()`.
- The private worker function has no EXECUTE for anon, authenticated or service_role in Production; this matches the migration's intended postgres-only invocation.
- The public `krim_vehicle_refresh_expiry()` is a separate admin function and requires AAL2/platform-admin through the guard.

Staging expiry:
- `pg_cron` and `pg_net` extensions are absent.
- Querying `cron.job` fails because the cron schema/relation is absent.
- No evidence exists of a scheduled expiry worker in Staging.
- The private worker function unexpectedly grants EXECUTE to service_role in Staging, unlike Production (and unlike the canonical migration, which revokes service_role). It is not directly callable by anon/authenticated, but the ACL drift must be explained.
- Public `krim_vehicle_refresh_expiry()` is service_role-only in Staging, while the admin browser page calls it using the authenticated Supabase client. Production grants authenticated execution. Thus the Staging admin page cannot complete its refresh call even if the other admin RPC permissions are repaired.

Expiry worker logic:
- Marks approved vehicle documents expired when their expiry date passes.
- Suspends verified vehicles when any mandatory current approved document is missing.
- Writes audit events.
- It does not create a separate notification/incident event in the reviewed SQL; notification behavior needs a later notification-phase test.

## 5. Production/Staging function ACL drift

All inspected functions deny anon EXECUTE. Production grants authenticated EXECUTE on the browser-facing vehicle registry/admin routines; Staging denies authenticated and grants service_role instead.

Examples:
- register vehicle / register document / list vehicle documents;
- review queue / review document / final verification;
- requirement list / set requirement;
- vehicle list / refresh expiry.

This confirms Staging cannot execute the intended authenticated browser workflow. Function definitions for the six critical routines compared by MD5 are identical between Production and Staging; the key observed divergence is permissions/configuration, not those function bodies.

Do not bulk grant authenticated or copy Production ACLs blindly. First reconcile intended browser vs server-mediated admin architecture, and retain in-function AAL2/platform-admin guards on all admin mutations.

## 6. Required remediation

### Gate A — establish lawful evidence baselines
- Define approved country × vehicle category requirement profiles from authoritative local legal/operational review.
- For India, distinguish ordinary goods-carriage vehicles, permits/fitness/tax/PUC requirements and special categories; validate current jurisdiction and route-specific applicability.
- Keep hazardous/dangerous goods disabled until a separate control profile is approved.
- Ensure each active profile has at least one mandatory document and no optionalization that bypasses mandatory law.

### Gate B — reconcile Storage
- Decide whether partner vehicle evidence upload requires AAL1 or AAL2. Align Production and Staging intentionally.
- Consider separate buckets for ordinary partner operational documents vs sensitive verification documents.
- Verify private bucket, MIME/size restrictions, object owner, exact path, upload denial for other tenants, read denial for other tenants, and signed URL expiry.
- Provision missing driver verification bucket in Staging only after its exact canonical migration/policy source is recovered; do not improvise bucket/policy SQL.

### Gate C — reconcile expiry automation
- Recover Staging migration provenance for pg_cron, private worker ACL and public admin refresh RPC.
- Verify cron extension is available/enabled on Staging before any migration.
- Keep the private worker non-callable by authenticated/anon/service_role unless the architecture deliberately changes.
- Ensure exactly one active scheduled job; prove it suspends expired evidence/vehicles in an isolated test fixture and is idempotent.
- Reconcile the public admin refresh RPC with the actual page caller.

### Gate D — functional negative tests
- Wrong organization path, wrong user path, nonmember upload, AAL1/AAL2 behavior, unsupported MIME, oversize/zero-byte file, duplicate object, metadata mismatch, missing object, spoofed expiry, expiry-before-issue, other-user read, admin without AAL2, reviewer self-approval, unconfigured profile, optional-only profile, expired mandatory document, expiry suspension, re-upload and re-review, and stale vehicle assignment.
- Test with synthetic objects and identities in Staging only after its schema/storage/ACL baseline is reconciled.

## Status register

| Control | Status |
|---|---|
| Vehicle registration/document upload call path | VERIFIED in source |
| Registration and document RPC ownership/path/metadata checks | VERIFIED in Production definitions |
| Private partner bucket and 10 MiB MIME allowlist | VERIFIED in both |
| Vehicle evidence storage path and owner check on approval | VERIFIED in Production definition |
| Vehicle/admin RLS enabled | VERIFIED in both |
| Country/category mandatory rules configured | FAIL — zero profiles in both |
| Independent admin review AAL2/platform-admin guard | VERIFIED in Production definition |
| Self-review denial and audit event | VERIFIED in Production definition |
| Production scheduled expiry job | VERIFIED active, every 5 minutes |
| Staging scheduled expiry worker | BLOCKED — pg_cron absent |
| Private expiry worker ACL parity | FAIL — Staging service_role EXECUTE differs |
| Public expiry refresh ACL parity | FAIL — Staging service_role-only; page uses authenticated |
| Driver verification bucket in Staging | FAIL — missing |
| Partner evidence upload AAL parity | FAIL — Staging adds restrictive AAL2 |
| Browser/Storage runtime tests | NOT TESTED |
| Vehicle synthetic testing | BLOCKED |

No Production or Staging state was changed.
