# Phase 00 — Storage remediation blueprint and Staging test dependency gate

**Date:** 2026-11-25  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Evidence:** Read-only live catalog comparison of Production and Staging plus migration-source review.  
**Change status:** Report only. No database or repository application code changed.

## Executive result

This report converts the prior Storage policy findings into a safe, ordered remediation and test plan. It deliberately does **not** apply changes because Production partner-upload AAL2 intent has not been approved and Staging is not yet proven safe for synthetic writes.

The next permissible engineering step is a reviewed QA-branch migration/configuration proposal, not a live SQL mutation.

## Verified live configuration snapshot

### Buckets

| Bucket | Production | Staging | Production settings |
|---|---|---|---|
| `krim-partner-verification` | Present | Present | Private; 10 MiB; PDF/JPEG/PNG |
| `krim-driver-verification` | Present | Missing | Private; 10 MiB; PDF/JPEG/PNG/WebP |
| `krim-driver-evidence` | Present | Missing | Private; 10 MiB; PDF/JPEG/PNG/WebP |
| `krim-warehouse-evidence` | Present | Missing | Private; 10 MiB; PDF/JPEG/PNG |

Staging bucket absence is confirmed only for this reviewed evidence-bucket set, not every bucket in the project.

### Partner verification upload policy

**Production:** one effective INSERT policy named `krim_partner_verification_upload_own_org`. It binds the bucket, caller-owned second path segment, numeric organization folder, active membership, active organization and supported provider organization type. No AAL2 predicate is present.

**Staging:** two permissive INSERT policies exist:
- `krim_partner_verification_upload_own_org` — organization and uploader scope.
- `krim_partner_verification_upload_require_aal2` — AAL2 only.

PostgreSQL permissive policies combine with OR. The second policy therefore does not add an AAL2 requirement to the first. Staging's intended step-up rule is not enforced.

### Other scoped policy families

Production currently has separate path-scoped policies in the shared partner bucket for customs broker evidence, customs shipment documents, claims, capacity, service-area and partner verification. Driver evidence and warehouse evidence have their own private bucket policies. Any change must preserve these path namespaces and not broaden access across the shared bucket.

## Remediation decisions required

### Decision A — Should partner evidence upload require AAL2?

- Current Production behavior: no AAL2 requirement on the general partner verification upload policy.
- Current Staging behavior: an AAL2 policy was added, but policy composition makes it ineffective.
- Recommended security posture: if the AAL2 requirement is intentional, enforce it in the **same complete INSERT predicate** as organization membership, caller ownership, organization active state and provider-type validation. Do not keep a second AAL2-only permissive policy.
- If partner upload is intentionally AAL1-capable, remove the misleading Staging AAL2-only policy and document the intended lower assurance level. Do not silently change Production behavior.

**No policy change is authorized by this audit.**

### Decision B — Staging bucket parity

Provision only the three missing buckets in Staging, with private visibility and the exact approved size/MIME settings above. Add only the corresponding path-scoped Storage policies required by the canonical driver and warehouse workflows. Do not copy Production objects or Production data. Confirm there are no duplicate permissive policies after provisioning.

The migration/configuration plan must account for:
- `krim-driver-verification`: own driver profile evidence upload, own unregistered-object cleanup, AAL2 platform-admin preview.
- `krim-driver-evidence`: driver own-assignment upload/read, AAL2 platform-admin preview, customer read only for verified POD evidence.
- `krim-warehouse-evidence`: eligible warehouse organization upload/read, narrowly scoped cleanup of unregistered uploads, AAL2 platform-admin review if required by the canonical workflow.

Do not create broad bucket-wide authenticated read/write policies.

### Decision C — Driver reviewer RPC privilege

Production grants authenticated EXECUTE to `krim_admin_review_driver_document(uuid,text,text)`; Staging currently exposes it only to service_role/postgres. Its body independently checks authenticated identity, AAL2, `admin.platform`, self-review denial and original evidence ownership.

Before changing Staging ACL, locate the actual Staging admin review caller and decide whether the intended model is:
- authenticated AAL2 platform-admin invocation (matching Production); or
- service-role-only server invocation.

Do not grant authenticated execution just to make catalog parity look consistent. Confirm that the UI uses the correct RPC and that no browser-side service-role capability is assumed.

## Ordered remediation and verification gates

| Gate | Work | Evidence required to pass | Must remain blocked until |
|---|---|---|---|
| G0 | Freeze environment identity | Staging hostname and Supabase project ID proven together; no fallback to Production | Before any write test |
| G1 | Resolve partner AAL2 policy intent | Written decision; single effective policy predicate; catalog proves intended semantics | Before partner upload tests |
| G2 | Add missing Staging buckets/policies | Private buckets, exact MIME/size, complete policy inventory, no unintended permissive OR path | Before driver/warehouse evidence tests |
| G3 | Resolve driver review ACL | Actual caller identified; ACL and function body independently reviewed | Before driver reviewer tests |
| G4 | Establish synthetic test identities | At least two separate organizations, uploader, driver, warehouse user, AAL1 reviewer and AAL2 platform reviewer; no Production identities/data | Before cross-tenant tests |
| G5 | Establish test sink and cleanup | All provider calls disabled or routed to a controlled sink; object cleanup and row cleanup rehearsed; no real email/SMS/payment | Before full workflow tests |
| G6 | Runtime policy tests | Expected allow/deny matrix executed with real JWTs in isolated Staging | Before marking Storage controls verified |

## Required synthetic Storage test matrix

1. Partner user uploads to own organization/uploader path — expected allow only under the approved AAL policy.
2. Same user attempts another organization's folder — deny.
3. Same user attempts another user's folder — deny.
4. AAL1 and AAL2 partner upload behavior — assert the explicitly approved rule.
5. Driver uploads to own active assignment/profile — allow only for correct folder and state.
6. Driver attempts another driver's profile/assignment path — deny.
7. Driver evidence after assignment is delivered/cancelled — deny where policy requires.
8. Warehouse user uploads to own eligible organization — allow; another organization — deny.
9. Customer reads only verified POD evidence for their own shipment — allow; unverified POD or other tenant — deny.
10. Platform admin without AAL2 — deny preview and reviewer RPC.
11. AAL2 platform admin with `admin.platform` — allow permitted preview/review.
12. Submitter attempts self-approval/self-review — deny.
13. Original uploader mismatch or missing object — deny approval.
14. Unregistered upload cleanup — only original uploader and only unlinked object; registered object delete — deny.
15. Membership revocation / organization deactivation — subsequent reads and uploads — deny.
16. MIME/size spoof and malformed path — deny at backend; do not rely on browser validation.

Capture request IDs, JWT assurance level (not token values), actor/org synthetic IDs, expected outcome, actual status and relevant audit event. Never store raw access tokens in the report.

## Current gate status

- G0 Environment identity: **NOT PROVEN for runtime test host**.
- G1 Partner AAL2 intent/policy: **BLOCKED** — Staging OR composition is wrong; Production intent needs decision.
- G2 Staging bucket parity: **BLOCKED** — three reviewed buckets absent.
- G3 Driver review ACL: **BLOCKED** — Staging and Production invocation privileges differ; caller path not yet proven.
- G4 Synthetic identities: **NOT ESTABLISHED**.
- G5 Test sink and cleanup: **NOT ESTABLISHED**.
- G6 Runtime Storage tests: **NOT STARTED**.

## Safety boundary

All work was read-only. No Storage objects were accessed. No bucket, policy, function ACL, database, Auth, secret, environment or deployment settings were changed. No synthetic users or test objects were created. No migrations were applied, no real provider operations were invoked, and nothing was merged or deployed.
