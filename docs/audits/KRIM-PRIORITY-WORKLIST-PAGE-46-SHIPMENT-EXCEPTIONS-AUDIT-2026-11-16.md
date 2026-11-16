# KRIM Priority Worklist — Page 46: Shipment Exceptions

**Date:** 16 November 2026  
**Worklist position:** Page 46 — Shipment Exceptions (Operations Control Tower)  
**Canonical route:** `app/operations/exception-management.html`  
**Legacy route:** `public/shipments/shipment-exceptions.html`  
**Scope:** Static source review and a narrowly scoped, source-only usability correction. No production database writes, operational RPCs, shipment updates, exception acknowledgements, resolutions, or notifications were executed.

## Classification

**Status: EXISTS — partially integrated; not end-to-end verified.**

The canonical page is an authenticated operations workspace. The legacy public route is a compatibility redirect to the authenticated Operations workspace; it is not a separate functioning exception register.

## Existing functionality evidenced in source

- Loads Supabase configuration and requires an authenticated session.
- Redirects unauthenticated visitors to the login route.
- Checks active organization membership before loading records.
- Reads exception records from `krim_exceptions` and escalation records from `krim_exception_escalations`.
- Limits each read to 100 records and sorts by recorded detection/escalation time.
- Shows an explicit unavailable state when a query fails; it does not convert permission/query errors into zero counts.
- Offers escalation acknowledgement through `krim_acknowledge_exception_escalation`.
- Offers exception resolution through `krim_resolve_operational_exception`, requiring a resolution explanation of at least five characters.
- Reloads the view after successful acknowledgement/resolution.
- Backend permission checks remain authoritative; page copy identifies `compliance.manage` as required.
- The preparation form is explicitly browser-only and does not persist operational changes.
- The legacy route explains that its former fixed sample shipment was not authoritative and redirects to the authenticated workspace.

## Corrections made

Commit: `7369ca12e75349dd6ed36ac8b3de20b05578279e`

1. Added horizontal scrolling and touch scrolling to exception/escalation tables so their minimum-width columns remain usable on narrow mobile screens.
2. Added explicit field length limits and required-field validation to the non-persisting review-preparation form.
3. Added minimum/maximum note length constraints. The page continues to state clearly that this form does not save or change operational records.

## Remaining gaps / verification requirements

1. No live browser test was performed for a customer, partner, operations user, or platform admin. The page needs role-based staging tests.
2. The page reads exception/escalation rows through RLS, but the source does not present a selectable active organization context when a user belongs to multiple organizations. Confirm intended multi-organization visibility and prevent confusing cross-org presentation.
3. Acknowledge/resolve buttons are rendered based on row state; the database RPC is the final permission boundary. Add a capability-aware UI only after confirming the canonical permission RPC/helper and its current deployment.
4. Validate query column names, RLS behaviour, RPC signatures and function grants against the reconciled production schema manifest.
5. Test duplicate clicks, conflicting retries, already-resolved exceptions, unauthorized users, expired sessions, and notification/retry outcomes in staging.
6. Exception creation, policy coverage, SLA timers, owner routing, evidence attachment and escalation delivery remain unproven end-to-end. Current production exception/escalation counts were zero in the preceding live audit; that does not prove the workflow works.
7. The underlying milestone ordering and tracking capability issues remain separate control-tower release blockers documented in the physical execution audit.

## Acceptance status

| Requirement | Status |
|---|---|
| Authenticated entry | Source evidenced |
| Active membership check | Source evidenced |
| Exception register | Connected to Supabase; live E2E unverified |
| Escalation register | Connected to Supabase; live E2E unverified |
| Acknowledge action | RPC wired; staging/role test required |
| Resolve action | RPC wired; staging/role test required |
| Review preparation | Browser-only; validation improved |
| Mobile table overflow | Source corrected |
| End-to-end exception lifecycle | Not verified |
| Production release readiness | Blocked by migration reconciliation and workflow tests |

## Safety boundary

Do not use production business RPCs to test these flows. Do not create synthetic production exceptions, acknowledgements, resolutions or notifications. Production schema/migration changes remain blocked until the sanitized production schema manifest and repository migration crosswalk are reconciled.

**Conclusion:** Page 46 is present and partially connected, not missing. The source-level mobile and form-validation improvements are committed. It must not be marked fully complete until role-scoped staging tests prove the exception lifecycle.
