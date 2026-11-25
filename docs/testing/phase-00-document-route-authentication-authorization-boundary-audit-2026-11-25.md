# Phase 00 — Document Route Authentication and Authorization Boundary Audit
Date: 2026-11-25
Repository: rimjhimkrn-web/logistics-saas
Branch: qa/phase-00-baseline-2026-11-25

## Executive decision

SOURCE-LEVEL BOUNDARY REVIEW COMPLETED FOR SIX DOCUMENT ROUTES. Runtime authorization remains NOT TESTED. Partner and warehouse upload pages perform browser-side identity checks and delegate critical operations to database RPCs. Enterprise documents require active enterprise membership and rely on RLS for organization-scoped reads. Customs documents are a protected preview, not a live document workflow. Customer ePOD and POD pages are informational shells, not connected document access/capture services.

Browser checks are not security boundaries. The RPCs, Storage policies and RLS must independently enforce every rule.

## 1. Route-specific observations

| Route | Browser identity check | Organization / role boundary | Server-side enforcement indicated | Status |
|---|---|---|---|---|
| public/partner/compliance-evidence.html | Calls auth.getUser(); redirects anonymous users to partner sign-in | Loads active krim_organization_members for current user; filters to active, registered-business, verified/approved partner organizations and eligible organization types | RPC krim_partner_submit_compliance_evidence plus Storage policy; page says final permission and file ownership are database-enforced | Strong source guard; backend enforcement not runtime-proven |
| public/warehouse/warehouse-evidence.html | Calls auth.getSession(); redirects if no session | Warehouse-specific route and RPCs; detailed role/permission check is not apparent in sampled page code | krim_warehouse_list_tasks, krim_warehouse_list_evidence, krim_warehouse_register_evidence and Storage policy | Role/task authorization needs independent proof |
| app/enterprise/documents.html | Calls auth.getSession() | Queries active memberships joined to organizations; filters active enterprise organizations and queries records for those organization IDs | Page relies on document-row RLS; no file action exposed | Source filter present; RLS and cross-tenant denial untested |
| app/customs/workflows/documents.html | Gate copy says it checks session and authenticator assurance | UI describes authenticated customs organization members only; live records are not connected | No document backend calls found in sampled page | Preview only |
| public/customer-os/customer-services/epod-vault.html | No auth/client/backend check found | Describes intended authenticated organization and shipment-scoped access, but does not implement it | None in sampled route | Informational specification only; not a secure vault |
| public/customer-os/customer-services/pod-capture.html | No live capture authentication flow found | Read-only guidance; customers are not the independent source of driver POD | None in sampled route | Informational/read-only |

## 2. Source details

### Partner compliance evidence
- Retrieves the signed-in user with auth.getUser().
- Queries active krim_organization_members rows filtered by the authenticated user ID.
- Loads candidate organizations by those membership IDs.
- Client-side eligibility requires active organization status, registered_business account mode, verified partner status, approved/active lifecycle and an allowed partner organization type.
- Uploads to krim-partner-verification and registers metadata through krim_partner_submit_compliance_evidence.
- The organization selector is disabled while identity is checked and when no eligible organization exists.
- A modified browser request can bypass these filters. The RPC and Storage policy must independently verify caller identity, active membership, organization status, permitted evidence type and object ownership.

### Warehouse evidence
- Checks auth.getSession() and redirects anonymous users to warehouse login.
- Loads tasks/evidence and registers evidence through dedicated RPCs.
- The sampled page does not prove the RPC checks warehouse-specific permission, task-to-organization relationship, active assignment, facility scope or evidence type. These require direct positive and negative tests.

### Enterprise documents
- Checks for an authenticated session.
- Queries active memberships joined to organization records.
- Restricts organization IDs to active organizations of type enterprise.
- Queries document rows and related verification/requirement records only for those IDs.
- UI explicitly relies on RLS for organization scope and exposes no upload/download/preview/sign/verify action.
- The decisive security boundary is database RLS. Test direct API access with altered organization IDs.

### Customs documents
- Visible gate describes session, authenticator assurance and customs organization membership checks.
- Page says live records are not connected and does not submit declarations or documents.
- Treat assurance statements as intended design until deployed gate and backend policies are independently verified.

## 3. Required negative authorization matrix — NOT RUN

Execute only after Staging origin, schema parity, least-privilege grants, synthetic fixtures and tenant isolation are reviewed and approved. Do not use Production identities or data.

| ID | Synthetic actor / action | Expected result |
|---|---|---|
| AUTH-DOC-01 | Anonymous user opens partner compliance upload | Redirect/deny; no organization data or upload capability |
| AUTH-DOC-02 | Authenticated user with no active membership opens partner compliance | No eligible organization; direct forged RPC and Storage requests rejected |
| AUTH-DOC-03 | Customer-only member calls partner evidence RPC | Deny even with valid organization ID supplied |
| AUTH-DOC-04 | Partner member of Org A submits evidence for Org B | Deny at Storage insert and RPC registration |
| AUTH-DOC-05 | Pending/unverified partner submits evidence | Server-side deny |
| AUTH-DOC-06 | Anonymous user opens warehouse evidence or calls list/register RPC | Deny; no task/evidence metadata |
| AUTH-DOC-07 | Non-warehouse member calls warehouse RPC | Deny by role/permission and organization scope |
| AUTH-DOC-08 | Warehouse user assigned to Org A task submits against Org B task | Deny; no cross-org object or metadata |
| AUTH-DOC-09 | Warehouse user requests evidence outside assignment/facility scope | Deny unless explicit permission policy allows |
| AUTH-DOC-10 | Enterprise user queries another enterprise organization's document rows | RLS returns no unauthorized rows/API denies; no signed link |
| AUTH-DOC-11 | User without active enterprise membership calls document tables directly | Deny/no rows |
| AUTH-DOC-12 | Customs user without required assurance or membership calls backend | Deny; no data/action |
| AUTH-DOC-13 | Customer A requests ePOD for Customer B shipment | Deny; current static page must not imply capability |
| AUTH-DOC-14 | Reuse expired or revoked signed URL | Behavior matches documented guarantees; issuance/download evidence retained |
| AUTH-DOC-15 | Revoke membership during active session, then repeat request | Next protected request denies access; no stale membership bypass |

## 4. Server-side controls to prove

1. Caller-derived identity: RPCs use auth.uid() or trusted JWT claims, never a caller-supplied user ID.
2. Membership state: active membership rechecked at action time.
3. Role and permission: explicit permission for upload, list, verify, approve and download; workspace membership alone is insufficient.
4. Tenant binding: document, shipment, task, facility, evidence record and Storage object resolve to the same authorized organization.
5. Assurance: high-risk actions enforce required AAL/step-up server-side.
6. Storage policies: INSERT/SELECT/UPDATE/DELETE bind bucket, path, organization, owner, role and record relationship; no permissive OR-policy bypass.
7. Signed-link broker: issue short-lived links only after authorization; record issuance and relevant download audit; document revocation limitations.
8. Lifecycle and cleanup: atomic registration or compensating cleanup; orphan reconciliation and audit.
9. No public exposure: private buckets remain private; no unscoped download endpoint.
10. Audit integrity: actor, organization, object key, action, timestamp, result and correlation ID recorded without logging secrets or signed URL tokens.

## 5. Readiness status

| Control | Status |
|---|---|
| Partner browser session + active-membership guard | PASS — source inspection only |
| Partner eligibility filtering | PASS — source inspection only |
| Warehouse session guard | PASS — source inspection only |
| Warehouse role/task authorization | NOT TESTED |
| Enterprise active enterprise membership filter | PASS — source inspection only |
| Enterprise document RLS enforcement | NOT TESTED |
| Customs protected gate source | PARTIAL; backend route is preview only |
| Customer ePOD authorization | NOT IMPLEMENTED in sampled page |
| Customer POD capture authorization | NOT IMPLEMENTED; informational page |
| RPC direct-call negative tests | NOT TESTED |
| Storage cross-tenant negative tests | NOT TESTED |
| AAL/step-up enforcement | NOT TESTED |
| Signed URL issuance, expiry and revocation | NOT TESTED |
| Membership revocation during active session | NOT TESTED |

## 6. Release recommendation

- Keep partner compliance and warehouse uploads behind controlled access until RPC and Storage policies pass the negative matrix.
- Keep Enterprise document operations read-only until dedicated document authorization and signed-link service are proven.
- Do not advertise customs document submission or customer ePOD vault as operational from these sampled pages.
- Do not treat an authenticated session as equivalent to an authorized workspace role.
- Do not run these tests against Production.

Safety boundary: read-only QA-branch source audit. No database calls, Storage operations, signed URLs, uploads, user creation, configuration edits, deployments, merges or provider calls were performed.
