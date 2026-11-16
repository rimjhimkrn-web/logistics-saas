# KRIM Authenticated SECURITY DEFINER Function Review — Batch 01
**Date:** 16 November 2026  
**Source:** Live PostgreSQL function catalog and read-only `pg_get_functiondef` inspection  
**Scope:** Eight public-first search_path functions plus selected overload/signature checks. No functions invoked; no data or schema changed.

## 1. Summary
Eight authenticated-executable SECURITY DEFINER functions were identified with `public` first in their configured search path. All eight were inspected at definition level. Several explicitly enforce authentication, AAL2 and platform-admin permission; several operational functions use organization membership/permission checks. However, the full nine-workspace authorization posture is not proven, and nested/overloaded function call chains need further review.

## 2. Function-by-function evidence

| Function | Catalog/body observations | Assessment |
|---|---|---|
| `krim_admin_list_partner_verification_cases()` | Requires non-null `auth.uid()`, JWT AAL2 and `admin.platform` permission for platform org 1. Reads verification cases and organizations. | Positive explicit admin/AAL2 gates. Review output minimization and ensure no sensitive evidence payload is exposed beyond the queue's need. |
| `krim_admin_schedule_inquiry_followup(uuid,text,timestamptz)` | Requires auth, AAL2, `admin.platform`; validates inquiry ID/note/time; inserts follow-up and updates inquiry status. | Positive authorization and input checks. Verify follow-up insert and inquiry status update are atomic (same transaction by function execution) and repeated requests are idempotent; current body creates a new follow-up row per call. |
| `krim_admin_set_global_rate_card_status(bigint,text)` | Requires auth, AAL2 and `admin.platform`; locks rate card; validates commercial evidence, tax review, approval reference, provider verification/capability, active markets/readiness, duplicate active card; writes audit event. | Strong visible activation gates. The function still needs independent verification of reviewer identity/evidence authenticity, route corridor dossiers/controls, and nested market gate implementation. |
| `krim_create_global_shipment_from_places(7 args)` | Requires auth and validates route type/country codes; delegates to a six-argument overload, then updates route type. The 7-argument wrapper itself does not visibly check organization access or `shipment.create`. | Delegation chain unresolved. The six-argument overload and five-argument `krim_create_global_shipment` were not proven to be the exact callee path. Inspect overload resolution and confirm all caller-supplied organization IDs are checked before insert. |
| `krim_create_partner_opportunity(bigint,timestamptz,text)` | Requires auth, organization access to shipment customer organization and `quote.create`; locks shipment; limits status to draft/quoted; blocks active multi-leg plans; checks active countries/markets and valid transport mode. | Positive org/permission/state checks. The visible function checks active markets but does not visibly call the market activation readiness gate or explicit corridor dossier/control/customs gate. Confirm the complete activation prerequisite chain before partner sourcing. |
| `krim_create_tariff_quote(bigint,text,timestamptz)` | Requires auth, organization access and `quote.create`; locks shipment; validates shipment status/weight, active countries/markets, market activation settings and `krim_internal_market_activation_gate`; requires an active evidence-backed rate card and records pricing snapshot. | Positive quote controls. The visible function does not explicitly reference corridor compliance dossiers/controls; confirm whether nested market-gate implementation enforces them. No quote was created. |
| `krim_record_operational_milestone(bigint,text,text,numeric,numeric)` | Requires auth; validates event type, notes and GPS; locks shipment; resolves active partner assignment through active organization membership and driver assignment or `shipment.update`/`shipment.dispatch` permission; rejects ambiguous multi-assignment; records milestone and tracking event. | Strong assignment/actor scoping. No explicit predecessor/ordering validation is visible in this function; this matches the existing out-of-order milestone risk. The 60-second duplicate lookup is not a complete idempotency-key strategy for conflicting retries. |
| `krim_submit_customer_service_request(...)` | Requires auth and a verified customer identity link; checks customer workspace/account active; validates request type, weight, date, notes and active locations; inserts request, qualifies it, conditionally records acquisition event and audit event. | Identity/workspace gating is visible. No explicit organization permission check or idempotency key is visible in this function; verify profile-to-organization uniqueness, duplicate submission handling and downstream qualification side effects. |

## 3. Search-path review
All eight functions have a function-level search_path. The configured paths place `public` first, with `pg_temp` and sometimes `private`/`auth` afterward. This is not proof of an exploit. Review unqualified object references and temporary/public object shadowing, and prefer explicit schema qualification for all referenced relations/functions. Do not alter function configuration until migration history is reconciled.

## 4. High-priority follow-up
1. Inspect every overload of `krim_create_global_shipment_from_places` and the exact six-argument callee; verify organization membership, org type, `shipment.create` permission and tenant binding.
2. Inspect the full market activation gate and corridor compliance functions called from quote/rate-card activation; verify missing controls fail closed.
3. Add a staging-only milestone ordering matrix for all allowed milestone transitions, including concurrent writes and replay/conflicting retries.
4. Trace partner opportunity sourcing to confirm the exact market/corridor gate is repeated immediately before opportunity publication.
5. Verify customer service request profile-to-organization mapping, duplicate handling, consent purpose and abuse controls.
6. Continue function review across the remaining 142 authenticated-executable SECURITY DEFINER functions, prioritizing admin approvals, partner onboarding, capacity, dispatch, warehouse, customs, POD and finance.
7. Treat authenticated direct table grants as a separate review; function checks do not protect direct table writes.

## 5. Release status
**Not certified.** This batch is static database function-definition inspection only. No function was executed and no staging identity simulation was performed. Keep production changes blocked pending migration reconciliation and sanitized schema manifest. Financial posting/collection remains deferred to the final phase.
