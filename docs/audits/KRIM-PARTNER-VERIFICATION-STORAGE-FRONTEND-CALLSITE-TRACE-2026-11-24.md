# KRIM partner-verification Storage frontend callsite trace — 2026-11-24

## Scope
Read-only source review on branch `feat/notification-recipient-resolver-draft-2026-11-24` at head `576507ff9945b083956f5a50a0e01d61c152f5d4`. Reviewed the active partner onboarding, service coverage, capacity resources and partner document/evidence pages. No Storage objects, policies, database rows or production/staging settings were changed.

## Confirmed upload callsites

### 1. Registered-business onboarding
File: `public/partner/partner-onboarding.html`

- `uploadPartnerDocument(file, label)` uploads to `krim-partner-verification`.
- Object path is `{onboardingOrganizationId}/{onboardingSession.user.id}/{crypto.randomUUID()}.{pdf|png|jpg}`.
- Client-side checks reject empty files, files over 10 MiB and MIME types other than PDF/JPEG/PNG.
- Registered-business submission requires a verified TOTP factor and current AAL2 before upload; the UI routes users through enrollment/challenge when needed.
- The returned object paths are passed to `krim_submit_partner_onboarding_global_multi_v1` as `p_document_paths`.
- On successful RPC response, the local temporary path list is cleared. On failure, the page attempts to remove uploaded paths; if cleanup fails it only logs a warning, so orphaned private objects can remain and require reconciliation.
- Development/Test and Individual Interest paths do not upload verification files.

**Assessment:** object path matches the bucket's expected organization/user prefix. Frontend-to-RPC path handoff is confirmed. The database function body still needs a direct live catalog review to prove it validates every path against the resolved organization and persists only those exact paths.

### 2. Service-area evidence
File: `public/partner/service-coverage.html`

- Live signed-in flow uploads 1–5 PDF/JPEG/PNG files, each at most 10 MiB, to `krim-partner-verification`.
- Object path is `{org.id}/{currentUser.id}/service-area/{Date.now()}-{Math.random suffix}-{sanitized filename}`.
- The resulting paths are passed to `krim_partner_submit_service_area` as `p_evidence_paths`, together with the organization ID, coverage scope and other request fields.
- The frontend checks the RPC response for a service-area ID and the expected `draft` / `pending_review` states.
- If upload fails before the RPC, partial objects are removed. If the RPC was attempted but the outcome is uncertain, uploaded objects are retained and the UI tells the user not to retry until the request is reconciled.
- The staging-preview branch returns before the live submission handler; in staging review mode, files are local-only and no upload or request is made.

**Assessment:** correct organization/user path prefix and explicit path handoff are present. Unlike onboarding/capacity, the object name uses `Date.now()` plus `Math.random()`, not a cryptographically strong UUID. Recommend switching to `crypto.randomUUID()` to reduce collision/predictability and avoid retaining the original filename in the object key. The live service-area page does not proactively check AAL2 or explain MFA before upload. Because staging has a restrictive AAL2 Storage INSERT policy, an AAL1 user can receive a raw Storage error rather than a guided MFA challenge.

### 3. Capacity/resource evidence
File: `public/partner/capacity-resources.html`

- Live flow uploads 1–5 PDF/PNG/JPEG files, each at most 10 MiB, to `krim-partner-verification`.
- Object path is `{org.id}/{user.id}/capacity-{crypto.randomUUID()}.{pdf|png|jpg}`.
- Paths are passed to `krim_partner_register_capacity_resource` as `p_document_paths`.
- If upload fails before the RPC, partial uploads are removed. If the RPC was attempted and the result is uncertain, objects are retained for reconciliation; the UI tells the user to check the resource register before retrying.
- The page has a local-only sample preview path; the real authenticated flow is separate.
- This page does not proactively check AAL2 or guide the user through MFA before upload. Staging's restrictive AAL2 policy therefore creates a likely generic upload failure for AAL1 sessions.

**Assessment:** path prefix and RPC handoff match the bucket policy shape. Add the same explicit MFA assurance check/challenge UX used by registered-business onboarding before beginning uploads.

### 4. Partner documents & delivery evidence
File: `public/partner/documents-delivery-evidence.html`

- This page reads document/evidence metadata from authorized database records.
- It explicitly does not expose raw Storage paths, public URLs or file contents.
- No Storage upload or download callsite was found in the inspected page. The UI directs users to the authorized document workflow for uploads/review.

## Cross-cutting findings and remaining proof

1. Three active browser upload flows use the same private bucket and expected `{organization_id}/{auth.uid()}/...` prefix.
2. Onboarding, service-area and capacity pages pass uploaded object paths into their respective RPCs. This proves frontend handoff, not server-side path ownership validation or durable linkage.
3. Registered-business onboarding handles AAL2 explicitly. Service-area and capacity pages do not; staging's additional restrictive AAL2 policy will reject AAL1 uploads without a helpful guided recovery.
4. Service-area object names should use `crypto.randomUUID()` rather than timestamp + `Math.random()`.
5. Cleanup behavior is intentionally conservative when an RPC outcome is uncertain. A failed cleanup can leave private orphan objects; do not delete objects merely by age until references are checked.
6. No bucket download callsite was identified in these inspected pages. The document/POD register deliberately withholds raw storage references. Other partner/driver/customs/warehouse evidence pages and Edge Functions still need a repository-wide inventory.
7. Live definitions of `krim_submit_partner_onboarding_global_multi_v1`, `krim_partner_submit_service_area` and `krim_partner_register_capacity_resource` must be inspected in both Supabase environments to confirm they reject foreign-organization paths, validate bucket/path prefixes, persist exact paths and enforce allowed evidence state transitions.
8. Isolated Storage API tests are still required: own-org upload allowed; foreign-org prefix denied; wrong-user second path segment denied; AAL1 denied in staging; AAL2 allowed; read denied outside authorized scope; cleanup cannot remove already-linked evidence.

## Release decision
Do not change Storage policies or production behavior based on this source trace alone. The next safe step is a read-only comparison of the three live RPC definitions and their EXECUTE grants in production and staging, followed by isolated Storage API authorization tests. Do not create fake verified partners or evidence in live staging.
