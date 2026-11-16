# KRIM Nine-Workspace Authorization and Tenant-Isolation Test Matrix
**Date:** 16 November 2026  
**Type:** Test specification; no production execution  
**Release status:** Required before multi-workspace production sign-off.

## Purpose
Turn the existing nine-workspace audit findings into a repeatable staging verification matrix. This document defines expected security outcomes, not evidence that tests have passed. Execute only in an isolated staging project with synthetic users, organizations, shipments and evidence. Never use production business RPCs as test fixtures.

## Security invariants
1. Supabase Auth establishes identity; the database/RPC/Edge Function establishes authorization. Client-side route guards and hidden buttons are not security controls.
2. Every read/write is scoped to authenticated user, active organization membership, permitted role, exact record/leg/assignment and current lifecycle state.
3. Client-supplied user IDs, organization IDs, role claims, permission names, assurance levels and ownership assertions are untrusted.
4. Inactive, expired, revoked, suspended or ambiguous memberships deny access by default.
5. AAL2 is enforced server-side for high-impact actions: platform approvals, partner verification, capacity approval, customs review/clearance, dispatch authorization, claims/refunds, finance posting/recovery, sensitive exports and role/permission changes.
6. Denials do not disclose whether another tenant's records exist. No cross-tenant row, count, identifier, private file or signed URL is returned.
7. Reviewer actions require independent reviewer identity; creators cannot approve their own work.
8. Repeated requests are idempotent where they create durable events; conflicting retries are rejected and audited.
9. Authorization failures are safe, observable and do not mutate business state.
10. Frontend workspace access is navigation convenience only; server-side policy remains authoritative.

## Global negative/positive test suite
Run each scenario against every workspace endpoint and every data-bearing RPC used by that workspace.

| ID | Staging setup / request | Expected result |
|---|---|---|
| AUTH-01 | Anonymous browser opens private workspace | Redirect or safe sign-in state; no private data request succeeds |
| AUTH-02 | Authenticated user with no active membership | Deny; no organization data returned |
| AUTH-03 | Membership inactive, revoked or expired | Deny immediately; no cached access |
| AUTH-04 | Tenant A user supplies tenant B ID | Deny or empty non-disclosing result; no B data |
| AUTH-05 | User has wrong workspace organization type | Deny; no fallback tenant |
| AUTH-06 | Valid membership but missing requested permission | Read/write denied as appropriate |
| AUTH-07 | Permission exists in another organization only | Deny in current organization |
| AUTH-08 | AAL1 user attempts high-impact action | Server rejects; no state mutation |
| AUTH-09 | AAL2 user has exact permission and scope | Permit only if lifecycle/evidence/business predicates also pass |
| AUTH-10 | Client forges role, permission, organization, user or AAL fields | Ignore client assertions; derive trusted state |
| AUTH-11 | User requests another tenant's private file | No object access and no signed URL |
| AUTH-12 | Same idempotency key and same payload | Return original result without duplicate side effect |
| AUTH-13 | Same idempotency key and conflicting payload | Reject and record audit/security event |
| AUTH-14 | Membership/permission revoked during active session | Next server request denied; stale grant not retained |
| AUTH-15 | RPC helper/table policy denies access | Entire operation fails atomically; no partial writes |

## Workspace-specific authorization matrix

### 1. Customer / Shipper
- Positive: active customer membership with shipment.view sees only its organization's shipments.
- Negative: customer A cannot read customer B shipment, quote, invoice, document, POD or tracking GPS.
- Negative: shipment.create/update/quote permissions are checked server-side, not inferred from dashboard visibility.
- Negative: customer cannot alter readiness/compliance gates, partner assignment, dispatch authorization, delivery verification or finance posting.
- Assurance: ordinary shipment visibility may use approved AAL1 policy; sensitive account, payment/refund or export actions require stronger configured assurance.
- Verify dashboard behavior when AAL2 is absent does not expose actions whose RPC requires AAL2.

### 2. Partner / Carrier
- Positive: active partner member sees only shipments and legs assigned to that partner organization and permitted operational role.
- Negative: partner cannot see another partner's quote, customer documents, capacity or tracking GPS.
- Negative: partner cannot self-approve verification, capability evidence or commercial agreement.
- Negative: generic shipment.assign / shipment.dispatch mappings cannot bypass exact assignment, accepted quote, confirmed capacity, corridor activation, compliance and dispatch authorization.
- Verify gateway ambiguity and account-pathway handling; gateway success does not grant action permission.

### 3. Driver
- Positive: active driver membership sees only its own profile and accepted, active driver assignments.
- Negative: driver cannot read/update another driver's assignment, evidence, vehicle or POD.
- Negative: expired/unverified licence or required document blocks assignment/dispatch server-side.
- Negative: driver cannot create out-of-order milestones, self-verify POD or mark delivery complete by submitting POD.
- Verify invitation acceptance cannot claim/transfer a profile without valid invitation, verified identity and allowed transfer state.

### 4. Warehouse
- Positive: active warehouse membership with exact facility/task permission sees only assigned facility and task records.
- Negative: warehouse A cannot read warehouse B stock, receipts, QC evidence or signed previews.
- Negative: no direct authenticated inventory mutation; all changes use controlled RPCs.
- Negative: picking/transfer cannot consume shipment-reserved stock; concurrent allocations cannot oversell.
- Negative: QC creator cannot independently approve; quantity/condition mismatch prevents handover completion.
- Verify receipt, return, cancellation and reservation release are atomic and idempotent.

### 5. Customs
- Positive: active customs organization member with exact jurisdiction and document permissions sees only assigned cases.
- Negative: broker cannot clear cargo outside approved market/corridor scope or without current required documents and evidence.
- Negative: AAL1 cannot approve/clear/release; AAL2 alone is insufficient without permission, jurisdiction, assigned case and independent review.
- Negative: submitter cannot approve own customs declaration/review.
- Verify workspace and each RPC enforce same jurisdiction and organization scope.

### 6. Finance
- Positive: finance member with finance.view can read permitted organization financial records only.
- Negative: finance.view cannot create, approve, post, refund, settle or change chart-of-account mappings.
- Negative: partner freight amounts and partner collections are not recognized as KRIM revenue or posted to KRIM cash/bank.
- Negative: authenticated users cannot directly mutate financial posting events, DLQ items, revenue allocation rules or ledger entries.
- Negative: refund requester cannot approve own refund; duplicate/conflicting requests handled safely.
- Verify canonical legal entity and finance organization binding before ledger/invoice operations. Live own-fee checkout remains disabled in this phase.

### 7. Operations Control Tower
- Positive: active operations membership with exact shipment/exception permissions sees operational records in scope.
- Negative: ordinary member cannot access platform-wide or unrelated organization records merely by opening control tower.
- Negative: tracking can_record advisory must exactly match the write RPC authorization predicate.
- Negative: manual milestones cannot be represented as verified GPS; milestone order and lifecycle state are enforced.
- Negative: post-dispatch cancellation cannot bypass disruption/recovery and resource reconciliation.
- Verify escalation acknowledgement, reassignment and resolution permission boundaries.

### 8. Enterprise
- Positive: active enterprise membership sees only contracted enterprise data and authorized subsidiaries.
- Negative: enterprise user cannot access another enterprise tenant, partner-private documents or unrelated customer records.
- Negative: membership alone does not grant every enterprise action; named permissions and delegated scope are checked.
- Verify consolidated reporting requires explicit tenant hierarchy and scope grants, not client-supplied organization lists.

### 9. Admin / Platform
- Positive: only active platform-admin/superadmin identity with exact platform permission and AAL2 can perform platform administration.
- Negative: organization_admin, organization_owner, platform_admin and platform_superadmin are not interchangeable; each action checks distinct permission and scope.
- Negative: platform operator cannot approve own verification, capability, customs, POD, finance or compliance submission.
- Negative: admin list/export functions cannot leak credentials, secrets, personal contact data or unrelated tenant data.
- Verify all admin pages and RPCs use consistent platform guard, audit reason, actor, assurance and target scope.

## Evidence required for each executed test
Record test ID, staging build SHA, database migration snapshot, synthetic actor/role/membership, organization scope, AAL, RPC/page under test, expected/observed result, database before/after state, audit event, timestamp and reviewer. Redact tokens, emails, phone numbers, personal data and secret values. A test passes only when result and side effects match expectation.

## Stop conditions
Stop and open a P0 security issue if any cross-tenant data is returned, unauthorized write succeeds, AAL2 is bypassed, reviewer separation fails, private evidence is exposed, inventory is oversold, or a denied request partially mutates state. Do not reproduce against production.

## Current status
This is a prospective staging test plan. It has not been executed and is not a security certification. Existing nine-workspace audit findings remain open, particularly inconsistent workspace entry gates, broad generic role mappings, uneven AAL2 handling, and incomplete enterprise/operations/warehouse entry-level checks.

## Dependencies
- Isolated staging project with synthetic data and known schema version.
- Sanitized production schema manifest and migration crosswalk so staging source accurately represents production.
- Inventory of every RPC and Edge Function invoked by each workspace.
- Test identities for each role, wrong-tenant membership, inactive membership, AAL1 and AAL2.
- Independent reviewer and audit evidence collection.
