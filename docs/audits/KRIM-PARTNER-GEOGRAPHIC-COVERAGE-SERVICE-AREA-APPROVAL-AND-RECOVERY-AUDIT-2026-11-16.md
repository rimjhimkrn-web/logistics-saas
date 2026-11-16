# KRIM Partner Geographic Coverage, Service-Area Approval and Submission Recovery Audit — 2026-11-16

## Executive decision

**NO-GO for partner service-area activation, commercial quoting and real shipment execution remains unchanged.**

This audit reviewed the partner service-coverage workspace, its country/market/location selectors, service-area evidence upload and submission RPC, AAL2 administrator review queue and review RPC, live country operating-pack schema/status, partner capability dependencies and production service-area records.

A low-risk frontend recovery improvement was committed. No production data, partner status, service-area record, Storage object, Auth state, RPC, policy, schema, corridor, country pack or activation control was changed. No real service-area request was submitted or approved.

## Live production snapshot

- Partner service-area records: **0**.
- Approved/active service-area records: **0**.
- Pending service-area records: **0**.
- Partner capability records: **1**, pending/inactive.
- Active verified partner capabilities: **0**.
- Country operating packs: **249**, all `research_pending`.
- Network corridors: the prior market/corridor audit found **7**, all `draft`, with no approved corridor dossier/controls.
- No approved operating country or corridor was established by this audit.

The service-area catalogue being empty is not evidence of zero partner demand; it means no approved/recorded partner geographic coverage is available to rely on.

## Positive controls confirmed

### Partner coverage submission

`public/partner/service-coverage.html`:
- verifies the signed-in user and active organization membership;
- restricts the page to an active partner-type organization;
- distinguishes development/test, individual-interest and registered-business pathways;
- displays organization-scoped service areas and capabilities separately;
- uses the KRIM country, market, location and transport-mode catalogues rather than free-text country identifiers;
- requires 1–5 PDF/JPEG/PNG evidence files, each no larger than 10 MB in the browser;
- uploads to private `krim-partner-verification` storage using organization/user/service-area paths;
- calls `krim_partner_submit_service_area`;
- expects a `draft` / `pending_review` result, not activation;
- requires active registered-business, verified and compliant organization state before enabling submission in the browser;
- server-side submission rechecks partner manager permission, organization state, current compliance, scope, active country/market/location, service type, mode, effective dates, evidence path and Storage ownership;
- duplicate matching requests awaiting review are blocked.

### Administrator review

The protected administrator list/review RPCs require an authenticated AAL2 user with platform admin permission. Approval requires:
- a registered-business organization that remains active and currently compliant;
- an active country;
- an approved country operating pack;
- an active market/location consistent with the selected country;
- an active transport mode when mode-specific;
- one to five submitted private evidence files owned by the original submitter;
- a matching active, verified capability for the same service type, country and transport mode;
- independent reviewer (the submitter cannot approve their own request);
- documented decision rationale and audit event.

The review RPC closes rejected requests and activates approved requests only after its checks pass.

## Findings

### P0 — Country operating-pack status column mismatch in approval RPC

The live table `public.krim_country_operating_packs` exposes `pack_status`; it does not expose a `status` column.

The live definition of `public.krim_admin_review_partner_service_area(bigint,text,text)` tests `cp.status = 'approved'`.

This is inconsistent with the live table schema and is expected to raise an undefined-column error when the approval branch executes. No review RPC was invoked to test this because it would be a production mutation. The function needs a carefully reconciled correction to reference the authoritative `pack_status` column, followed by staging tests. **Do not hot-patch production before migration reconciliation.**

### P1 — Approval RPC does not enforce service-area effective window

Submission validates that the start date is not backdated and that end is not earlier than start. However, the inspected approval branch does not require:
- `effective_from <= now()`;
- `effective_until IS NULL OR effective_until > now()`.

A future-dated or already-expired draft could therefore pass the service-area date-specific approval check if the other gates passed. The active status alone must not be treated as current service availability. Add server-side effective-window checks in the reconciled/staging remediation.

### P1 — Country/market/location coverage is not corridor authorization

The partner workspace records country, market or location coverage. It does not create or approve a specific transport corridor, route, schedule, cargo scope, customs permission or capacity commitment.

The service-area approval checks a country pack and a matching capability, but does not bind the approval to a corridor dossier and its current controls. This must remain a separate gate: a partner's city or country footprint does not authorize every origin/destination pair inside that geography.

### P1 — Evidence upload and RPC retry recovery was unsafe

Before this change:
- uploaded paths were not cleaned up when a later upload failed;
- an RPC timeout/error after the request might have committed was presented as a generic submission failure;
- a successful RPC followed by a failed coverage-register refresh fell into the same catch block and could incorrectly tell the applicant submission failed.

That created orphan evidence and duplicate-request risk.

**Frontend recovery hardening committed:**
- records the exact uploaded paths;
- attempts to remove partial uploads only if failure occurs before RPC invocation;
- does not delete evidence after an ambiguous RPC result;
- instructs the applicant not to retry until the coverage register/support confirms whether a request exists;
- treats a confirmed pending request as successful before refreshing the register;
- isolates register refresh failure and preserves the confirmed request ID/status;
- resets the effective-from date using the browser's local calendar date rather than UTC date slicing.

Cleanup depends on existing Storage delete policies and was not executed or tested against production.

### P2 — Geographic catalogue status can be mistaken for operational availability

Active country, market and location catalogue rows are lookup references. They do not establish that the market is operationally enabled. The prior global-market audit found all six market activation controls blocked and all country operating packs research_pending.

The partner page's copy already says catalogue entries are reference data and do not imply service availability. This distinction should be preserved in all partner/customer dashboards, matching APIs and search results.

### P2 — No corridor-specific partner coverage model yet

For a true corridor marketplace, KRIM ultimately needs a validated relationship across:
- origin and destination location IDs;
- country and market activation;
- corridor dossier and applicable regulatory controls;
- transport mode and cargo/service scope;
- partner capability and effective dates;
- confirmed service area at both endpoints or an explicitly modeled corridor capability;
- verified capacity and service dates;
- partner contract and approved commercial terms.

Do not infer a corridor from a country-level or city-level service-area row.

## Repository change

File: `public/partner/service-coverage.html`

Commits:
- Main recovery hardening: `29458384378616f8a2cd3ef075c9cc07c7841d49`
- Local-date reset correction: `af19bca989ebe5dd2ad783fcbdc00e83bb1936f7`

No backend behavior was changed.

## Required next remediation sequence

1. Reconcile migration history and the sanitized production schema manifest before backend edits.
2. Correct the country-pack column reference in the service-area approval function in a reviewed migration.
3. Add effective-window checks to the approval RPC and all downstream service-availability/matching paths.
4. Ensure active service-area display is derived from both approval status and current effective window.
5. Add explicit corridor-level coverage only when a corridor dossier and controls are approved; do not use city/country coverage as a substitute.
6. Make service-area submission durable/idempotent with an upload-session key and status lookup; current frontend handling still cannot recover a browser crash between upload and RPC.
7. Add staging-only tests for country, market and location scope; mismatched parent geography; inactive catalogue rows; expired/future service windows; missing country pack; draft corridor; unverified/mismatched capability; expired compliance; wrong-tenant evidence; upload partial failure; RPC timeout after commit; and independent reviewer enforcement.
8. Keep India first-market candidate Ranchi–Jamshedpur in draft until all legal, country-pack, corridor, partner, capability, capacity and operational gates are independently satisfied.

## Verification and change control

- Live production schema, data counts and RPC definitions inspected read-only.
- Partner coverage and administrator review pages source-reviewed.
- Service-area approval requirements compared with country-pack and capability schema.
- Frontend source change committed.
- No live upload, deletion, RPC invocation, service-area review or activation performed.
- No production SQL/DDL/migration applied.
- Authenticated browser testing and staging tests remain outstanding.

## Release gate

KRIM remains **NO-GO for live partner coverage claims, commercial quoting and shipment execution**. There are no approved service areas, no active verified capabilities, no approved country operating packs and no approved corridors evidenced in this snapshot.
