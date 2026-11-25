# Phase 00 — Driver reviewer RPC caller and Staging EXECUTE ACL reconciliation

**Date:** 2026-11-25  
**Branch:** `qa/phase-00-baseline-2026-11-25`  
**Projects inspected read-only:** Production `ebltviniygljwwseplph`; Staging `qrpcivhdxobiaofppbkl`.

## Confirmed caller

The canonical administrator page `app/platform-admin/driver-verification.html` contains these actual calls:

- Queue: `db.rpc("krim_admin_list_driver_verification_with_expiry")`
- Review action: `db.rpc("krim_admin_review_driver_document", { p_document_id, p_decision, p_reason })`
- Private evidence preview: `db.storage.from("krim-driver-verification").createSignedUrl(storage_path, 60)`
- Licence expiry: `db.rpc("krim_admin_update_driver_licence_expiry", ...)`

The page obtains the authenticated session before exposing the administrator UI. It does not route the review action through a server-side Edge Function. Thus the document-review RPC is called by the signed-in browser user.

## Current live function ACL comparison

Read-only checks using `has_function_privilege` returned:

| Role | Production | Staging |
|---|---:|---:|
| `authenticated` | EXECUTE = true | EXECUTE = false |
| `service_role` | EXECUTE = true | EXECUTE = true |
| `anon` | EXECUTE = false | EXECUTE = false |

The canonical UI's direct authenticated RPC call therefore cannot execute in Staging under the current ACL. This is a concrete Staging integration blocker, not merely a catalog parity difference.

## Current Staging function-body safeguards

A fresh `pg_get_functiondef` read confirms the function is `SECURITY DEFINER` with an empty search path and independently checks:

1. Authenticated `auth.uid()` exists.
2. JWT assurance level is AAL2.
3. Caller has `admin.platform` permission.
4. Decision is only accepted/rejected; rejection reason length and maximum are validated.
5. Document exists and is still pending, with row locking.
6. Submitter cannot review their own evidence.
7. Accepted evidence must match the original driver/profile path and Storage object owner.
8. Profile is locked and verification depends on required accepted documents, current licence expiry, active/verified/compliant partner organization, verified transport capability and active driver membership.
9. Review is written to `krim_audit_events`.

These controls are meaningful and are the reason not to replace the function with a weaker shortcut or to expose it to `anon`.

## Recommended resolution for review

The evidence supports the intended browser caller being an authenticated AAL2 platform administrator. The narrow candidate ACL correction is to grant EXECUTE on exactly:

`public.krim_admin_review_driver_document(uuid,text,text)`

to `authenticated` in Staging, while retaining revocation from `PUBLIC` and `anon`. The function body must remain unchanged unless a separate review finds a defect.

This is a recommendation only. No grant/revoke was executed. Before any change:
- confirm the owner intends the authenticated AAL2 platform-admin UI to invoke the RPC;
- inspect the exact current ACL and function body one more time immediately before change;
- apply only in Staging after G0 environment identity is proven;
- test unauthenticated, AAL1, authenticated non-admin, self-review and valid AAL2 admin cases with synthetic identities;
- verify audit event creation and cross-tenant denial.

## Gate result

**G3 — caller identified; current Staging ACL is a confirmed functional mismatch.** The gate remains BLOCKED until the intended invocation model is approved, the narrow Staging ACL is safely corrected, and runtime allow/deny tests pass.

No Production or Staging data, schema, policies, function definitions, privileges, Auth users, Storage objects or secrets were changed.
