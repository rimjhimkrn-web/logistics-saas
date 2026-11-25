# KRIM Phase 00 — SQL Function Security and Operational Logic Review

**Date:** 2026-11-25  
**Scope:** Read-only PostgreSQL catalog and selected function-definition review in production and staging.  
**Branch:** `qa/phase-00-baseline-2026-11-25`

## 1. Function security catalog — verified counts

The same corrected catalog query was executed independently against each environment.

| Metric | Production | Staging |
|---|---:|---:|
| Public-schema functions | 366 | 376 |
| SECURITY DEFINER functions | 333 | 344 |
| SECURITY DEFINER executable by `anon` | 0 | 0 |
| SECURITY DEFINER executable by `authenticated` | 151 | 45 |
| SECURITY DEFINER functions without explicit function-level search_path setting | 0 | 0 |
| Non-internal public-table triggers | 113 | 115 |

**Important interpretation:** 151 and 45 are counts of SECURITY DEFINER functions for which the authenticated role has EXECUTE privilege. This is not, by itself, proof of a vulnerability. The function body must enforce the intended identity, organization membership, permission, state transition and/or MFA checks. The review of the entire set is still outstanding.

The earlier Supabase advisor finding of 151 production functions aligns with the catalog count. Staging's smaller executable set is a material difference that must be explained as intentional deployment/security policy or corrected before staging can represent production behavior.

## 2. Selected high-impact function bodies reviewed

### Customer shipment creation — `krim_create_global_shipment`
Source review confirms checks for:
- Customer organization exists.
- Current user has organization access.
- Current user has `shipment.create` permission.
- Origin and destination are distinct and active.
- Both country markets pass operational activation checks.

This is source-level evidence only. Positive and negative runtime authorization tests remain NOT TESTED.

### Quote acceptance — `krim_accept_global_quote`
Source review confirms:
- Quote and shipment rows are locked for update.
- Organization access and `shipment.update` permission are checked.
- Quote status and expiry are checked.
- Accepted quote/assignment consistency is checked.

Runtime concurrency, idempotency, cross-tenant denial and failure rollback remain NOT TESTED.

### Platform rate-card approval — `krim_admin_approve_global_rate_card`
Source review confirms:
- Authentication required.
- JWT assurance level AAL2 required.
- `admin.platform` permission required.
- Commercial cost/tax evidence is required.
- Market activation gates are checked.

Runtime MFA, unauthorized-role denial and state/audit verification remain NOT TESTED.

### Partner verification review — `krim_admin_review_partner_verification`
Source review confirms:
- Authentication required.
- AAL2 required.
- `admin.platform` permission required.
- Decision and rejection-reason validation.
- Verification case state is locked and checked.

Runtime tests remain NOT TESTED.

### Global rate-card status — `krim_admin_set_global_rate_card_status`
Source review confirms authentication, AAL2 and platform-admin permission checks, plus status/effective-date/commercial evidence gates. Full body and downstream audit behavior require review.

### Driver proof of delivery — `krim_driver_submit_delivery_pod`
Source review confirms:
- Authenticated user required.
- Assignment must belong to the current user.
- Active driver organization membership required.
- Assignment must be in transit.
- Assignment must be linked to the commercial partner shipment leg.

Runtime authorization, evidence-storage, independent reviewer and final shipment-state tests remain NOT TESTED.

### Partner capability submission — `krim_partner_submit_service_capability_v2`
The wrapper validates structured details and delegates the capability write to `krim_partner_submit_service_capability`. The delegated function must be reviewed to verify organization ownership, active membership, evidence path ownership, and role authorization. No runtime test was run.

## 3. Security review priorities

| ID | Finding | Priority | Required next evidence |
|---|---|---|---|
| P00-SEC-01 | 151 production SECURITY DEFINER functions executable by authenticated users | Critical review set | Function-by-function authorization classification and negative tests |
| P00-SEC-02 | Staging exposes only 45 such functions vs 151 in production | High | Explicit allowlist/rationale and staging parity plan |
| P00-SEC-03 | Admin mutations require verified AAL2 and platform permission in sampled bodies | Positive source finding; runtime unverified | AAL1 denial, non-admin denial, AAL2 admin success tests |
| P00-SEC-04 | Partner capability wrapper delegates authorization to another routine | High | Review delegated routine and storage ownership constraints |
| P00-SEC-05 | Trigger function bodies and trigger execution context not fully classified | High | Trigger-to-function map, SECURITY DEFINER, owner and mutation effect review |

No functions or grants were modified.

## 4. Important correction to comparison method

The function and trigger catalogs were inspected separately in each environment. A prior attempted comparison query used same-database CTEs and therefore did not establish cross-environment differences. Its empty result is not valid parity evidence and is excluded from conclusions.

A true cross-environment comparison still requires exporting normalized signature/definition/grant/trigger manifests from both environments and diffing those manifests outside the database.

## 5. Phase 00 status update

| Workstream | Status |
|---|---|
| Function security counts | PASS — read-only counts captured |
| Selected critical function source review | PARTIAL — sample only |
| Full SECURITY DEFINER review | NOT COMPLETE |
| Cross-environment function signature diff | NOT COMPLETE |
| Cross-environment function body fingerprint diff | NOT COMPLETE |
| Trigger-to-function review | NOT COMPLETE |
| Runtime role/MFA/tenant tests | NOT TESTED |
| Database mutation/rollback tests | NOT TESTED |

## 6. Safety record

No production or staging schema, grants, function definitions, triggers, user accounts, rows or secrets were changed. No provider calls, payment transactions, emails, Telegram messages, webhook requests or load tests were triggered.

**Release position:** Not approved for unrestricted real-user onboarding. This report records source and catalog inspection, not runtime certification.
