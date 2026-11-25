# Gate C3.12 — Driver ePOD, signatures, photographs, evidence integrity and delivery completion reliability

**Programme:** KRIM GLOBAL PLATFORM — AI QUALITY ASSURANCE, SIMULATION & RELIABILITY PROGRAMME  
**Gate:** Phase 00 / C3.12  
**Source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**QA branch:** `qa/phase-00-baseline-2026-11-25`  
**Review date:** 2026-11-25  
**Disposition:** **PARTIAL PASS / BLOCKED — NO-GO for live ePOD capture, legal digital-signature claims or unattended delivery completion.**

## 1. Scope and method

Read-only source inspection of the driver POD page, driver evidence registration policy, authenticated POD submission wrapper, internal POD submission/verification/delivery-authorization functions, admin review UI/RPC, customer POD record and storage policies, and migrations covering idempotency and multi-leg leg-scoped completion.

Key files:
- `app/driver/module-10-proof-of-delivery.html`
- `app/platform-admin/delivery-pod-verification.html`
- `public/customer-os/customer-services/epod-vault.html`
- `public/customer-os/customer-services/pod-download.html`
- `supabase/migrations/20261105054211_secure_driver_delivery_evidence_registration.sql`
- `supabase/migrations/20261105140000_customer_access_verified_pod_evidence.sql`
- `supabase/migrations/20261105233000_correct_pod_submission_leg_and_tracking_status.sql`
- `supabase/migrations/20261105240000_require_verified_pod_before_driver_delivery_completion.sql`
- `supabase/migrations/20261106001500_add_authenticated_driver_pod_submission.sql`
- `supabase/migrations/20261106010000_add_admin_pod_verification_and_delivery_authorization.sql`
- `supabase/migrations/20261111130000_restrict_customer_pod_reads_to_verified_evidence.sql`
- `supabase/migrations/20261115150904_support_leg_scoped_delivery_pod_and_completion.sql`
- `supabase/migrations/20261115210000_harden_delivery_pod_idempotency_and_search_path.sql`
- `supabase/migrations/20261115210100_correct_pod_coalesce_resolution.sql`
- `supabase/migrations/20261115210200_stabilize_driver_pod_evidence_order.sql`

This is static source review only. No SQL, RPC, Storage request, signed URL, file upload/download, signature capture, browser or mobile test was executed. No Production or Staging data was queried or changed.

## 2. Positive source controls

1. Driver evidence registration is scoped to the authenticated user, a private `krim-driver-evidence` bucket object owned by that user, the driver's assignment path, active driver membership, and a non-closed assignment.
2. Evidence metadata is constrained to a 1–10 MiB file size, JPEG/PNG/WebP/PDF MIME allowlist, recipient name/notes lengths and a three-segment user/assignment/object path.
3. Legacy `pod-documents` Storage read/upload policies were retired in a migration after the migration comment recorded zero legacy objects/document rows.
4. Authenticated driver POD submission checks `auth.uid()`, active driver membership, driver assignment ownership, in-transit state and a linked active/accepted partner assignment for the same shipment and partner organization.
5. Submission requires at least one registered evidence object owned by the driver and records a POD against the exact partner-assignment shipment leg. The current hardened internal submit function locks the assignment and rejects a retry with a different recipient/signature/evidence payload; deterministic evidence ordering includes evidence row ID.
6. A POD submission creates `pod_submitted` tracking and partner execution events, not a delivered event. Driver trip-event RPC explicitly excludes the `delivered` event; final delivery is separated from submission.
7. The admin queue and review RPC require AAL2 and `admin.platform` permission. Admin UI uses 60-second signed evidence links and requires a reason before verify/reject.
8. Customer POD row access is limited to verified records for an authorized customer organization. Customer Storage policy requires a verified POD record and a matching evidence path in its metadata.
9. Delivery authorization validates POD/assignment/shipment/leg/partner tuple, requires the POD to be verified and the exact leg to be in transit, checks active multi-leg route-plan item binding, updates the leg/assignment, and marks the shipment delivered only when all required legs are complete.
10. Customer ePOD guidance correctly distinguishes submitted from verified evidence and describes private, short-lived, authorized access. Driver POD page currently states submission is paused pending backend integrity remediation and does not claim that the page itself completed a POD.

## 3. Findings and release risks

### P1 — Driver-to-commercial assignment binding omits explicit exact-leg equality
The authenticated wrapper resolves the partner assignment by partner-assignment ID, same shipment ID and same partner organization, but the inspected wrapper does not explicitly assert that the driver's linked assignment leg equals the partner assignment's shipment leg. The internal POD function then binds to the partner assignment's leg, while evidence registration is scoped to the driver-assignment ID. A cross-leg mismatch could therefore associate driver evidence with a different leg under the same shipment/partner if upstream bindings are inconsistent.

**Impact:** Evidence may be attributed to the wrong shipment leg. Require explicit exact equality across driver assignment, partner assignment, shipment, leg, partner organization, driver and route-plan item before accepting evidence or POD.

### P1 — Admin verification updates driver assignments by partner_assignment_id only
The admin review function marks driver assignments delivered using `where partner_assignment_id = v_pod.assignment_id` and returns one row. The inspected update does not assert exactly one matching active driver assignment, nor validate its shipment, leg, organization and driver tuple against the POD before changing status. This is the known C3.8 issue and remains a release blocker in the reviewed baseline.

**Impact:** A verified POD could update an incorrectly linked or ambiguous driver assignment. Resolve and lock the exact driver-assignment tuple and require uniqueness before any state transition.

### P1 — Internal privileged function ACL and caller trust boundary require explicit verification
The internal submit, verify and authorize routines are SECURITY DEFINER functions. The reviewed migration source does not itself establish a complete deny-by-default EXECUTE ACL for every internal signature or prove that caller-supplied verifier identity cannot be supplied through a directly executable internal function. The public admin wrapper does check AAL2/platform permission, but wrapper checks are insufficient if internal functions are directly executable by authenticated/anon/PUBLIC roles.

**Impact:** A direct-call privilege path could bypass the intended admin review boundary. Explicitly revoke EXECUTE from PUBLIC/anon/authenticated for internal-only functions, grant only to the intended owner/wrapper context, and verify effective ACLs in both environments. Also derive verifier identity from trusted auth context inside the privileged boundary rather than trusting a caller-supplied UUID.

### P1 — File content authenticity, malware scanning and cryptographic integrity are not established
The evidence registration policy checks declared MIME type, file size, owner and path. The inspected flow does not establish server-side magic-byte validation, malware scanning, content sanitization, cryptographic content hash verification, immutable object version binding or tamper-evident retention. A filename/MIME declaration alone cannot prove that a file is a valid image/PDF or that its bytes remain unchanged.

**Impact:** Malicious, malformed or replaced evidence could enter the review flow. Require isolated upload/quarantine, byte-level type validation, malware scanning, SHA-256 (or stronger) content hash, immutable version reference and audit-bound verification before review.

### P1 — “Signature reference” is not proof of a cryptographic or legally qualified signature
The submission accepts a text `signature_reference` and recipient name/role. The reviewed capture path does not establish a signed payload, signer identity proof, consent/intent, signature image integrity, trusted timestamp, certificate chain, revocation check, or country-specific legal signature classification. The separate public digital-signatures page contains claims of active qualified trust services, HSM and eIDAS compliance that are not substantiated by this POD implementation.

**Impact:** Do not market this as a qualified electronic signature, eIDAS/QES, Aadhaar eSign, legally certified or cryptographically authenticated signature. Describe it only as a recipient acknowledgement/reference unless a real qualified provider and legal assessment are integrated and verified.

### P2 — Evidence review quality and completeness controls are not machine-enforced
Admin UI displays recipient, role, partner, shipment/leg, status and evidence files, but the reviewed flow does not require a structured checklist for legibility, photo context, geolocation authenticity, receiver authority, delivery exceptions, package condition, or evidence quality. A non-empty reason is required, but the system does not enforce a reason taxonomy or second reviewer for high-risk disputes.

### P2 — Signed URL expiry is short but revocation/cache behavior is unproven
Admin UI requests a 60-second signed URL. Customer download guidance calls for fresh authorization and short-lived links. Actual expiry enforcement, browser cache/download persistence, access log coverage, link revocation after role/organization change and file retention/legal hold were not runtime tested. A signed URL, once issued, may remain usable until expiry even if membership is revoked.

### P2 — Customer evidence visibility is policy-backed but not runtime tenant-tested
Customer record policy exposes verified PODs to authorized organizations and Storage policy matches paths embedded in evidence metadata. No negative tests were run for foreign tenant, same-user multi-org, partner/customer role overlap, manipulated metadata, stale membership, path traversal, expired signed URL or cross-leg evidence. Policy composition and actual query behavior must be verified in isolated Staging.

### P2 — Delivery state transitions need concurrency and failure-recovery tests
The source locks the POD, partner assignment, shipment and leg in the internal lifecycle and has idempotent submission behavior for exact retries. But simultaneous review decisions, concurrent leg completion, duplicate admin requests, partial function failures, multi-leg plan mutation, event duplication and retry after a commit/response timeout were not exercised against PostgreSQL. The migration source is not proof of production runtime behavior.

## 4. Required remediation before release

1. Add explicit exact tuple validation: driver assignment ↔ partner assignment ↔ shipment ↔ shipment leg ↔ partner organization ↔ active route-plan item. Require exactly one eligible driver assignment and lock it before final delivery updates.
2. Reconcile and prove effective EXECUTE ACLs for all internal SECURITY DEFINER POD functions in Production and Staging. Internal functions must not be directly callable by anon/authenticated/PUBLIC; only narrow authenticated wrappers should be callable. Derive reviewer identity from `auth.uid()` within the trusted wrapper.
3. Implement evidence quarantine, byte-level MIME/signature validation, malware scanning, SHA-256 hashing, immutable object version IDs and hash-bound review decisions. Reject evidence whose stored bytes no longer match the reviewed hash.
4. Clarify signature semantics. Either keep recipient acknowledgement as a non-qualified record with accurate UI wording, or integrate an actual approved signing provider with verified identity, signer intent, consent, timestamps, certificate validation/revocation and jurisdiction-specific compliance.
5. Enforce evidence review checklist and reason taxonomy; require additional independent review for disputed/high-risk cases where policy demands it.
6. Add immutable audit events for upload, hash, preview, verify/reject, customer retrieval, expiry, revocation, deletion/legal hold and replacement/version transitions.
7. Define retention, legal hold, deletion and data residency rules for recipient names, signature references, photos, PDFs and geolocation metadata.
8. Test customer access and Storage policies with synthetic tenants/roles in isolated Staging; test signed URL expiry/revocation and browser cache behavior.
9. Add transaction-level concurrency and idempotency tests for duplicate submission, conflicting payload, duplicate verify/reject, concurrent multi-leg completion, timeout after commit and event replay. Ensure failed authorization leaves all related state unchanged.
10. Keep driver POD submission and delivery completion paused until P1 remediations are implemented and independently verified. Do not use real customer evidence or send live customer notifications during tests.

## 5. Verification matrix

| Check | Result | Evidence / limitation |
|---|---|---|
| Private driver evidence bucket + owner/path binding | SOURCE PASS | Insert policy checks authenticated owner, object owner, assignment path and active driver membership. |
| File size/MIME/metadata limits | SOURCE PASS / PARTIAL | Declared size/MIME and lengths constrained; byte signature/malware/hash checks not established. |
| Authenticated driver POD wrapper | SOURCE PASS / PARTIAL | Auth, membership, assignment ownership, in-transit and shipment/partner binding present; exact leg equality is missing. |
| Exact POD shipment/leg/partner binding | SOURCE PASS | Internal submit and delivery authorization bind partner assignment to shipment and exact leg. |
| Driver assignment ↔ partner assignment exact leg binding | BLOCKED | Wrapper lacks explicit equality assertion. |
| POD idempotency/conflicting retry | SOURCE PASS | Locks assignment and compares recipient/role/signature/evidence JSON; runtime not tested. |
| POD submitted vs delivered separation | SOURCE PASS | Submission emits pending POD event; delivered event is separate authorized transition. |
| Admin AAL2 + platform permission | SOURCE PASS | Admin list/review functions enforce both checks. |
| Internal SECURITY DEFINER EXECUTE ACL | BLOCKED | Effective ACLs and direct-call negative tests not established by reviewed source. |
| Admin driver assignment update tuple | BLOCKED | Update filters by partner_assignment_id only; no exact tuple/uniqueness assertion. |
| Cryptographic signature / QES / eIDAS | FAIL / NOT IMPLEMENTED IN REVIEWED PATH | Text reference only; no qualified provider/signature chain established. |
| Malware scan / content hash / immutable bytes | BLOCKED | Not established in reviewed upload/review path. |
| Customer verified-only row/storage policies | SOURCE PASS | Policies restrict customer to verified POD and matching evidence paths; runtime isolation not tested. |
| 60-second signed evidence preview | SOURCE PARTIAL | UI requests 60-second URL; expiry/revocation/cache behavior not tested. |
| Multi-leg delivery completion | SOURCE PASS / PARTIAL | Route-plan and exact partner-leg checks present; concurrency and failure tests not run. |
| Browser/mobile upload and signature capture | NOT TESTED | No runtime or real-device test. |
| Tenant isolation, RLS and storage negative tests | NOT TESTED | Await Staging parity and isolation gates. |

## 6. Change and safety record

- No Production or Staging SQL, RPC, RLS, grant, table, row, account, secret, provider, deployment or Storage object was changed or invoked.
- No evidence file, signature, signed URL or customer record was accessed.
- No POD was submitted, verified, rejected or authorized.
- No shipment or driver assignment was modified.
- No customer notification was sent.
- This artifact is documentation-only on the isolated QA branch.

**Gate C3.12 result: PARTIAL PASS / BLOCKED.** Keep live driver ePOD capture, cryptographic/qualified-signature claims and automatic delivery completion on **NO-GO** until P1 exact-binding, ACL, evidence-integrity and signature-claims issues are remediated and isolated Staging tests pass.
