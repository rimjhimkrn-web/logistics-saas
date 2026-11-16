# Partner vehicle-document listing authorization and storage cleanup

**Date:** 17 November 2026  
**Scope:** Read-only review of live vehicle document registration/listing RPCs and the shared partner verification Storage bucket.  
**Status:** Remediation specification only — no production SQL or Storage policy changes.

## Findings

### P1 — Vehicle document metadata RPC is broader than its UI

Live function `public.krim_vehicle_documents_list(uuid)` is SECURITY DEFINER and EXECUTE is granted to `authenticated`, `service_role` and `postgres`.

It checks only:
- caller is authenticated;
- vehicle exists;
- caller has any active membership in the vehicle's organization.

It then returns all document rows for that vehicle, including `document_number`, original filename, content type, file size, issue/expiry dates, review status and review reason.

The Partner Vehicle Registry UI itself requires exactly one active owner/manager membership before exposing this action. That UI guard does not protect direct RPC callers. Any authenticated user with any active membership in the organization can call the RPC directly and obtain document metadata, including document numbers.

**Required remediation:** Define the intended role/permission matrix for fleet document metadata. At minimum, require an active organization membership and a dedicated least-privilege fleet/compliance permission (not membership alone); restrict document-number exposure to roles with a genuine operational need. Consider a reduced listing projection that omits document numbers for general reviewers. Revalidate organization lifecycle and vehicle ownership in the canonical helper. Add direct-RPC negative tests for driver, read-only, suspended membership, inactive organization, wrong-organization vehicle ID and unauthenticated callers.

### P2 — Failed vehicle-document registration may leave an orphan Storage object

The UI uploads to `krim-partner-verification` at:
`{organization_id}/{user_id}/vehicle/{vehicle_id}/{random_filename}`

It then calls `krim_vehicle_document_register`. The registration RPC validates:
- vehicle and active organization;
- active owner/manager membership;
- exact storage path bound to organization, uploader and vehicle;
- content type and file size;
- object existence, uploader ownership, MIME and byte-size equality;
- date ordering and basic metadata.

This is a useful server-side validation gate. However, if registration fails after upload, the UI attempts Storage removal. The inspected Storage policies include an organization-scoped INSERT policy and read policy for this bucket, but no corresponding DELETE policy for the vehicle-document path was found in the current policy inventory. The cleanup request may therefore be denied, leaving an unregistered private object. This is not proof that all orphan objects already exist; it is a failure-path risk.

**Required remediation:** Provide a tightly scoped owner-only orphan cleanup path for unregistered vehicle objects, requiring exact organization/user/vehicle path shape, object ownership and absence of a matching registered document row. Alternatively use a server-side upload/register transaction pattern with controlled cleanup. Do not grant broad bucket DELETE. Add tests for registration failure, retry, duplicate path, registered-object protection, wrong-vehicle path and cleanup denial.

### Existing positive controls

- `krim_vehicle_document_register` checks the object actually exists in the private bucket and that its MIME and size match the supplied metadata.
- It requires the exact organization/user/vehicle storage path.
- `krim_vehicle_register` requires an active owner/manager membership in an active organization.
- The vehicle–driver bind RPC revalidates vehicle document requirements and driver evidence at bind time; UI eligibility alone is not trusted.

## Release decision

**NO-GO for broad use of the vehicle-document metadata RPC until direct-call authorization is narrowed.** Keep the current UI access guard. Do not alter production functions or Storage policies until migration-history reconciliation is complete, a reviewed staging migration is tested, and security/ACL/storage-policy advisors are clean. Preserve existing private objects and document rows; do not run bulk cleanup without an audited inventory and explicit authorization.
