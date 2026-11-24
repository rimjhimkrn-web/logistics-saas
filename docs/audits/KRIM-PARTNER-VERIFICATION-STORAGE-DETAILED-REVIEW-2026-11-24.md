# KRIM partner-verification Storage detailed review — 2026-11-24

## Scope and evidence
Read-only review of production and staging Supabase Storage catalog state for `krim-partner-verification`, including bucket configuration, object-policy predicates and current staging object inventory. No objects, buckets, policies, or database rows were changed.

## Bucket configuration
Both environments have the same bucket:
- ID: `krim-partner-verification`
- Private: true
- Maximum file size: 10 MiB
- Allowed MIME types: PDF, JPEG, PNG

This is a matching bucket-level configuration.

## Production policy behavior
- **Read own organization:** authenticated SELECT only when the first path segment is a numeric organization ID, the caller has active membership, the organization is active, and its organization type is in the allowed logistics-partner family.
- **Upload own organization:** authenticated INSERT only when the first path segment is a numeric organization ID, the second path segment is the caller's UID, and the caller has active membership in the active organization of an allowed logistics-partner type.
- **Admin read:** authenticated SELECT requires AAL2 and `admin.platform` permission in platform organization 1.
- Additional production policies separately scope customs licenses/documents, claim evidence, driver evidence, driver verification and warehouse evidence in their own buckets/path families.

## Staging policy behavior
- **Read own organization:** same broad organization/path/membership/active-status/type constraints as production.
- **Upload own organization:** same organization path and active membership/type constraints as production.
- **Restrictive AAL2 upload policy:** a separate RESTRICTIVE INSERT policy requires JWT AAL2 for every insert into this bucket.

The additional restrictive policy combines with the permissive upload policy. Therefore a valid organization member with AAL1 may satisfy the production upload predicate but still be denied in staging until the user completes MFA to AAL2. This is a real environment behavior difference, not merely a naming difference.

## Current staging data
The staging bucket currently contains zero objects. There is no uploaded evidence to inspect for naming conventions, ownership metadata, or linkage to onboarding/service-area/capacity records.

## Security interpretation
The organization folder and caller UID path constraints provide a meaningful tenant boundary. The AAL2 requirement is stricter than production and may be an intentional security hardening, but it must be verified against the actual onboarding user experience and MFA enrollment flow. Do not remove it just to force parity.

The catalog query cannot establish:
- which frontend forms currently upload to this bucket;
- whether all client upload paths use the exact expected `{organization_id}/{auth.uid()}/...` shape;
- whether a successful upload is subsequently linked to the correct evidence record;
- whether cleanup policies exist for unlinked objects in staging;
- whether an AAL1 user is guided through MFA before attempting an upload.

## Release gates
1. Trace every active frontend Storage upload/download call for this bucket and verify exact object path construction.
2. Verify partner onboarding and service-area/capacity evidence RPCs persist the exact object path and enforce organization ownership.
3. Add isolated positive own-org and negative foreign-org Storage authorization tests, including AAL1 denial and AAL2 success.
4. Verify cleanup behavior for unlinked uploads and prevent deletion of evidence already referenced by a verification record.
5. Do not create synthetic verified partner records or evidence in the live staging project merely to satisfy the test.

## Decision
Bucket-level settings match. The main known difference is staging's restrictive AAL2 upload requirement. Since staging has no objects and frontend callsites were not established from the available repository code-search index, no ACL or policy change is justified yet. The next required evidence is source-level upload callsite tracing and isolated Storage API tests.
