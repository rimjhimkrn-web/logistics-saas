# Phase 00 — Privileged partner approval and commercial rate governance review

Date: 2026-11-25  
Environment: Production and Staging Supabase catalogs; Production function source and trigger definitions  
Scope: Read-only review of privileged partner verification, capability/service-area approval, and global rate-card approval/activation RPCs. No function was invoked. No database, Storage, Auth, secret, or provider state was changed.

## Executive result

**NOT VERIFIED for operational release.** The reviewed functions have meaningful authorization and evidence controls, but this is source/catalog review only. No authenticated JWT tests, negative authorization tests, evidence-upload tests, or approval lifecycle execution were performed.

A material environment-parity issue exists: Production grants authenticated execution on the reviewed partner-review RPCs, while Staging does not consistently expose the same functions to authenticated users. Staging's stricter posture must not be weakened by copying Production grants wholesale.

## Positive controls observed

### Partner verification case review
Production `public.krim_admin_review_partner_verification(bigint,text,text)`:
- Requires a non-null authenticated user, AAL2, and `admin.platform` permission in platform organization 1.
- Restricts decisions to approved/rejected, requires a meaningful rejection reason, and caps notes at 1,000 characters.
- Locks the verification case row and accepts only open/in-review/pending-information cases.
- Approval requires registered-business mode, active logistics organization, required business/location metadata, and at least one business document.
- Checks each document path is scoped to the organization and original submitter, exists in the private `krim-partner-verification` bucket, and is owned by the original submitter.
- Updates case and organization state and writes a before/after audit event.
- A BEFORE UPDATE trigger on verification-case decision/status calls `private.krim_guard_partner_verification_independent_review()`, intended to prevent a submitter from deciding their own case.

### Capability review
Production `public.krim_admin_review_partner_capability`:
- Requires authentication, AAL2 and platform-admin permission.
- Only reviews pending capabilities; requires reason text; rejects self-approval where submitter matches reviewer.
- Requires current partner compliance, active country and transport mode, 1–5 submitter-owned evidence files in private storage.
- Blocks hazardous-goods and refrigerated capability approval through the standard flow pending specialist evidence controls.
- Validates effective dates and weight bounds; writes an audit event.

### Service-area review
Production `public.krim_admin_review_partner_service_area`:
- Requires authentication, AAL2 and platform-admin permission.
- Requires pending workflow state, reviewer distinct from submitter for approval, and a review rationale.
- Approval checks registered-business status, current compliance, active country/market/location/mode, approved country operating pack, matching verified capability and submitter-owned private evidence.
- Writes an audit event.

### Global rate-card governance
- `krim_admin_approve_global_rate_card` requires authentication, AAL2, platform-admin permission, a documented approval reference, draft/suspended state, commercial cost/tax evidence and operational market activation gates.
- `krim_admin_set_global_rate_card_status` requires the same privileged context and locks the target row. Activation rechecks effective dates, commercial evidence, approval reference, buy-rate + platform-fee reconciliation, active verified registered-business provider, provider capability in both countries, market readiness and duplicate active route/tier/priority conflicts. It writes before/after audit state.
- Draft creation is separated from activation; approval does not itself activate a rate.

## Findings and risks

1. **Staging RPC grant parity is incomplete — release blocker for Staging testability.** The catalog review shows authenticated EXECUTE on the reviewed partner verification/capability/service-area review functions in Production but not consistently in Staging. The global rate-card approval RPC is also authenticated-executable in Production but not Staging. Keep Staging restrictive until a reviewed least-privilege grant matrix and isolated synthetic test identities exist. Do not bulk-copy Production ACLs.

2. **No runtime proof of the independent-review controls.** The case trigger is present and enabled in Production, and its function checks `NEW.submitted_by` against `auth.uid()`. The case table has a `submitted_by` column. However, there has been no positive/negative JWT execution proving self-review rejection, independent reviewer success, rollback behavior, or audit completeness.

3. **Rate-card approval and activation do not visibly enforce two-person separation of duties.** The source records `approved_by` and `approved_at`, but the activation function checks that those fields exist and are well-formed; it does not visibly require the activating administrator to differ from the approver or draft creator. Consider an explicit maker-checker rule for commercial pricing before rates become customer-visible.

4. **Rate-card evidence is metadata-backed.** Approval validates references and numeric evidence fields, and activation rechecks provider status/capabilities/markets and arithmetic. The reviewed approval function does not itself verify that cost/tax evidence references resolve to independently stored, immutable evidence records. A reference string is not proof that an evidence artifact was reviewed. Require a traceable evidence record and reviewer provenance before commercial activation.

5. **Rate-card approval numeric casts need negative tests.** JSON fields are cast to numeric/UUID/timestamp during approval/activation. Malformed values should fail closed, but error handling and rollback have not been runtime-tested.

6. **SECURITY DEFINER is a high-trust boundary.** The reviewed RPCs use SECURITY DEFINER and mostly an empty search_path. `krim_admin_set_global_rate_card_status` sets `search_path=public, private, pg_temp` rather than an empty path, although its table/function references are schema-qualified in the inspected body. Standardize to an empty search_path after dependency review; do not alter Production during this audit.

7. **Approval state transitions are not runtime verified.** Row locks and state predicates are visible in source, but concurrency, replay, concurrent reviewer, rejected/resubmitted, expired evidence, and revoked-compliance scenarios remain untested.

8. **Audit evidence is sparse.** Existing Production audit rows include partner account-mode selection, partner organization registration and capability creation, but no partner verification/capability/service-area review event appeared in the inspected grouped sample. This is consistent with no completed review in that sample; it is not proof that no review ever occurred.

## Environment and permission notes

- Production reviewed admin RPCs are SECURITY DEFINER and authenticated-executable where listed in the catalog; their bodies independently check AAL2 and `admin.platform`.
- Staging does not expose the same authenticated EXECUTE surface for several of these functions. This is a functional parity gap, not a reason to grant broad access.
- No anonymous EXECUTE was observed for the reviewed functions.
- Catalog ACLs alone do not prove runtime access; function-body checks and JWT claims still matter.

## Required follow-up before approval workflows are released

1. Build a function-by-function Production/Staging permission matrix, then grant only approved test RPCs to authenticated Staging personas.
2. Create isolated synthetic admin, submitter, and independent reviewer identities only after a test sink and tenant isolation are proven.
3. Execute negative tests: anon, AAL1, non-admin AAL2, wrong platform org, submitter self-review, foreign evidence owner/path, missing/expired evidence, invalid decision, duplicate/replayed review, and concurrent reviewers.
4. Execute positive tests: independent AAL2 admin review, verified business approval, capability approval only after current compliance, service-area approval only after approved operating pack and matching capability.
5. Add maker-checker separation for rate-card creation/approval/activation and immutable evidence references.
6. Verify audit event actor, organization, before/after state, timestamps, and notification/outbox behavior without sending external messages.
7. Keep partner commercial onboarding closed until these runtime tests pass.

## Evidence limitations

This report is based on read-only SQL catalog/function definitions and trigger inspection. It does not claim that any approval was successfully executed, that Storage ownership checks work under real JWTs, that notifications are delivered, or that Production and Staging are operationally equivalent.

**Decision: NOT VERIFIED. No real partner approval, capability activation, service-area activation, or commercial rate activation should be performed based solely on this source review.**
