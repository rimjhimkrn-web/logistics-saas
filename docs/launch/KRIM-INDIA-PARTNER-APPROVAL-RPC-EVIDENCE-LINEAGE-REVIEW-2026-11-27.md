# KRIM India Launch — Partner Approval RPC Authorization & Evidence-Lineage Review
**Date:** 27 November 2026  
**Environment:** Staging project `qrpcivhdxobiaofppbkl` only  
**Production:** Not accessed  
**Method:** Read-only catalog privilege and full function-definition inspection. No RPC invocation.

## Scope
Reviewed the privileged partner/capacity approval and onboarding write paths:
- `krim_admin_review_capacity_resource(bigint,text,text)`
- `krim_admin_review_partner_capability(bigint,text,text)`
- `krim_admin_revoke_partner_capability(bigint,text)`
- `krim_submit_partner_onboarding_global_multi_v1(...)`
- delegated `krim_submit_partner_onboarding_global_v2(...)`
- relevant trigger guard on capacity resource approval.

## Privilege snapshot
- The three admin review/revoke RPCs are executable by authenticated and service_role, not anon.
- They use an empty search_path.
- All three require a non-null `auth.uid()`, AAL2 and `admin.platform` permission for platform organization ID 1.
- Therefore a service_role call without a user JWT is rejected by the explicit identity check; service_role EXECUTE alone does not bypass the function's in-body authorization.
- Partner onboarding multi-category and lane-capacity registration RPCs are authenticated-callable, not anon-callable in the inspected privilege snapshot.

## Admin capacity-resource review
- Locks the target resource and owning organization.
- Allows only pending-review resources and requires an attached availability row.
- Approval requires submitter identity different from the authenticated reviewer, current partner compliance, a separately verified capability for the mode, a future availability window, and one or more private evidence files owned by the original submitter in the expected organization/user path.
- The RPC sets `reviewed_by` from `auth.uid()`, updates resource and availability status, and writes an audit event with before/after state.
- The database trigger additionally rejects self-approval and missing reviewer/submitter identity.
- Assessment: strong visible AAL2/role and evidence checks in this RPC. Trigger metadata comparison is supported by this RPC's trusted identity derivation; keep other privileged writers under review.

## Admin partner-capability review and revocation
- Review requires AAL2 platform-admin authorization, a pending capability, a non-self reviewer, a sufficiently detailed decision note, current partner compliance, active country/mode, and 1–5 evidence files in private storage owned by the original submitter.
- Standard approval explicitly blocks hazardous-goods and refrigerated capabilities pending specialized safety/equipment evidence controls.
- Review sets `reviewed_by` from `auth.uid()` and records before/after audit state.
- Revocation requires AAL2 platform-admin authorization, a verified active capability, a reason, and records the revoking user and audit state.
- Revocation explicitly does not cancel existing assignments. This is an operational dependency requiring a documented manual/automated review path; revoking a capability alone is not proof that existing bookings/assignments have been safely handled.
- Assessment: the inspected admin RPCs derive reviewer identity from the authenticated principal and do not trust caller-supplied reviewer IDs.

## Confirmed onboarding defect — multi-category capability evidence lineage
**Severity: P1 functional blocker for multi-category partner capability approval.**

The multi-category onboarding RPC validates the first registration document path belongs to the authenticated user and active partner organization. It delegates base partner onboarding to `krim_submit_partner_onboarding_global_v2`, then creates or updates one `krim_partner_capabilities` row for each selected service category.

For newly inserted category rows, the function writes metadata containing:
- operational_category
- coverage_city
- coverage_country_code
- submitted_via

It does **not** populate the capability-level `submitted_by` or `evidence_paths` metadata required by `krim_admin_review_partner_capability`.

The admin review RPC requires a non-null original submitter and one to five capability evidence paths. Consequently, a newly inserted category row from the multi-category onboarding path will fail approval checks because those required lineage fields are absent, even though onboarding accepted the business registration document and the parent organization metadata contains submission details.

For updated pre-existing category rows, the function also does not explicitly refresh capability-level `submitted_by` or `evidence_paths`; behavior depends on whatever metadata already existed. This is not a safe guarantee.

### Required correction (not applied)
When creating/updating each category capability, explicitly carry forward:
- `submitted_by = auth.uid()` in trusted server-generated metadata;
- `evidence_paths = to_jsonb(p_document_paths)` (or a category-specific evidence list if the product requires it);
- submission timestamp and onboarding case lineage;
- preserve existing immutable audit/history rather than accepting these values from caller JSON.

Before implementation, confirm that the submitted registration document is an acceptable evidence type for each operational capability category. If not, add category-specific required evidence and validation rather than reusing the same generic file.

Add regression tests for all 13 category mappings, first submission, resubmission, existing-row update, missing/foreign storage ownership, self-approval, and admin review success/failure.

## Other operational follow-up
- Capability revocation does not cancel existing assignments; require a clear review/escalation workflow before live use.
- Partner multi-category onboarding is not ready for end-to-end acceptance until evidence lineage is corrected and tested.
- Do not loosen the admin review function to accept missing submitter/evidence metadata; that would weaken the approval boundary.

## Disposition
Admin RPC authorization appears appropriately derived from the authenticated AAL2 platform administrator in the inspected definitions. A confirmed multi-category onboarding-to-review evidence-lineage defect remains and blocks approval of newly inserted capability category rows through this route.

## Safety record
No SQL mutation, RPC invocation, partner onboarding, capability/resource approval, fixture provisioning, event insertion, notification/email/provider/payment call or Production access occurred.
