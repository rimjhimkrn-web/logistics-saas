# KRIM Master Application Journey and Functional Gap Register
**Date:** 16 November 2026  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Canonical HTML inventory:** 112 application HTML files  
**Route/action evidence:** Four static inspection batches, 63 page inspections with 2 repeated partner-admin pages (61 unique page paths represented).  
**Status:** Static source register and staging plan; not functional, security or production-readiness certification.

## 1. Executive decision
**Release remains NO-GO for unrestricted live logistics execution and commercial collection.** The repository contains broad workspace surfaces and many operational RPCs, but real-world operating authority depends on approved partners, current capacity, activated markets/corridors, customs/compliance controls, driver/vehicle readiness, custody execution and verified evidence. Those prerequisites are not established by the presence of pages or API calls.

No live shipments, quotes, assignments, capacity reservations, dispatches, customs clearances, warehouse movements, POD approvals, payments, refunds or settlements were created or executed as part of these audits.

## 2. Scope and evidence baseline
The canonical repository inventory identifies 112 HTML files under `app/`. Four route/action batches inspected source for session/MFA/permission indicators, Supabase table reads, RPC calls, Edge Function invocations and private storage references:
- Batch 01 — Driver, Warehouse and Finance (8 pages).
- Batch 02 — Partner and Operations (12 pages).
- Batch 03 — Customer, Enterprise and Customs (17 pages).
- Batch 04 — Admin, Platform Admin and Application Entry (26 pages).
- Partner verification and partner capability pages occur in both batches 02 and 04; therefore the combined count is 61 unique page paths, not 63 unique pages.

These are static source scans. Literal call absence does not prove a feature is unwired because shared scripts, imports and indirect handlers may be involved. A session check does not prove permission enforcement. An RPC name does not prove its implementation is correct. CI smoke/static-link/deployment success is not a functional user-journey test.

## 3. End-to-end operating journey and gates

| Journey stage | Required system capability | Current evidence / gap | Release gate |
|---|---|---|---|
| 1. Public discovery and account entry | Accurate service claims, registration, sign-in, recovery, consent and support | Entry pages exist; auth forms require shared-script and end-to-end flow verification. CRM consent ledger previously found empty. | P1 |
| 2. Organization and workspace onboarding | Correct org type, membership, role, permission, tenant isolation, MFA where required | Nine workspaces exist, but access consistency and AAL2 enforcement are not fully certified. | P0 |
| 3. Partner onboarding | Legal identity, independent verification, capability, service area, compliance and contracts | Admin review surfaces exist; verified operational partners and active service coverage are not established. | P0 |
| 4. Market and corridor activation | Country packs, current authoritative sources, approved corridor dossiers and controls, customs requirements | Prior baseline: 249 country packs research_pending; zero approved corridor dossiers and zero corridor controls. | P0 |
| 5. Customer enquiry and shipment request | Customer/org binding, valid locations, commodity/handling data, consent and idempotency | Customer surfaces exist; tenant isolation, legacy model lineage and full workflow need staging tests. | P0 |
| 6. Quote and commercial acceptance | Verified partner offer, approved rate basis, expiry, customer acceptance and immutable audit | Quotes table/UI exists; live partner rate/capability/contract foundation not established. | P0 |
| 7. Assignment and capacity | Partner assignment, current capacity, resource binding and atomic reservation | Capacity/resource surfaces exist; no confirmed live capacity or accepted assignments in prior baseline. | P0 |
| 8. Dispatch authorization | Shipment state, route/corridor approval, partner compliance, driver/vehicle licences, capacity and customs gates | Dispatch readiness RPC exists; it is not itself dispatch authorization. Recheck all prerequisites transactionally. | P0 |
| 9. Pickup, tracking and milestones | Authorized actor, custody, ordered milestones, privacy and location controls | Driver/partner milestone and tracking surfaces exist; out-of-order milestone and tracking ownership risks identified. | P0 |
| 10. Warehouse and transfer | Facility authorization, inventory accuracy, atomic allocation, reserved-stock protection, QC | Controlled RPC flows and independent QC exist; reservation concurrency and reserved-stock defects need staging validation. | P0 |
| 11. Customs and documents | Licensed broker, jurisdiction, correct case, validated evidence, independent review and authority decision | Customs RPCs/pages exist; KRIM review must never be represented as government clearance. | P0 |
| 12. Delivery and POD | Correct assignment, private evidence, verified recipient, independent review and customer access | POD submission/review surfaces exist; evidence ownership and reviewer independence need staging proof. | P0 |
| 13. Exceptions, claims and support | Reason-coded state transitions, evidence, owner, SLA, escalation and audit | Exception/claim/support surfaces exist; cross-tenant access, cancellation reasons and safe transitions require tests. | P1 |
| 14. Enterprise oversight and integrations | Org-level analytics, approvals, documents, automation, risk, integrations and audit | Broad enterprise surface exists; several pages need shared-handler trace and data-source certification. | P1 |
| 15. Finance and KRIM own-fee revenue | Legal/tax readiness, bank, merchant approval, own-fee checkout, invoice, ledger, reconciliation | Deliberately deferred. No assumption of GST exemption, bank setup or Razorpay merchant approval. | FINAL PHASE |

P0 means blocks any real operational execution. P1 means required before broad commercial launch and enterprise scale. FINAL PHASE follows operational verification and explicit authorization.

## 4. Consolidated critical gap register

### P0 — Identity, authorization and tenant boundaries
- Establish one canonical authorization contract across all nine workspaces.
- Verify server-side organization membership, active status, organization type, role, permission, resource ownership and AAL2 for sensitive actions.
- Test revocation during active sessions and cross-tenant object-ID guessing.
- Reconcile authenticated direct grants/policies and SECURITY DEFINER function behavior against the sanitized live schema inventory.
- Keep high-risk approvals independent from submitters and creators.

### P0 — Market and operational authority
- Do not treat country metadata, rate cards, routes, lanes or capability catalogue entries as permission to operate.
- Complete country operating packs and approved corridor dossiers/controls using current authoritative sources and independent reviewers.
- Ensure quote, assignment, capacity and dispatch all fail closed when market/corridor/customs/compliance controls are missing.
- Require current partner service scope, contracts and independently verified evidence.

### P0 — Shipment, route, dispatch and custody lifecycle
- Establish one canonical shipment model; enterprise page currently references both `krim_shipments` and legacy `shipment_requests`.
- Reconcile state transitions, actors, reason codes, event ordering, idempotency and audit history.
- Dispatch must revalidate accepted assignment, capacity binding, partner, driver, vehicle, route, market, customs and compliance prerequisites atomically.
- Tracking must expose location only to authorized, current stakeholders.
- Cancellation after dispatch requires explicit reason and controlled custody resolution.

### P0 — Warehouse, inventory and returns
- Prove concurrent reservations cannot over-allocate stock.
- Prevent legacy picking and transfer dispatch from consuming shipment-reserved inventory.
- Fix and test the known NULL-validation issue in `krim_receive_authorized_shipment_return` only after migration reconciliation and authorized change review.
- Ensure receipt, allocation, transfer and inventory updates are atomic and idempotent.
- Preserve independent QC and do not merge stock across different quality states.

### P0 — Customs, evidence and POD
- Validate broker licence, jurisdiction, case assignment, organization and expiry on every action.
- Distinguish KRIM internal review, broker submission, authority decision and final release.
- Enforce private object storage, tenant/record-bound paths, file content/size checks, malware scanning, short-lived signed access and audit.
- Require independent POD and customs-document review.

### P1 — CRM, consent, notifications and enterprise
- Make consent purpose-specific, explicit, revocable and auditable; privacy notice acknowledgement is not a substitute for consent.
- Resolve duplicate qualification cases and ensure public enquiry/profile/case linkage is consistent.
- Verify Telegram/email delivery end-to-end; accepted provider API response is not proof of human receipt.
- Make retry workers idempotent, recoverable and preference/consent-aware.
- Trace enterprise shared scripts and certify analytics, approvals, documents, integrations, automation and risk workflows.
- Establish support-desk least privilege and cross-tenant privacy.

### FINAL PHASE — KRIM own-service-fee financial ecosystem
- Reconfirm GST rejection reason and tax classification with a qualified CA; no assumption of tax exemption.
- Confirm legal entity, bank account and Razorpay merchant KYC/settlement eligibility.
- Keep freight collection/escrow/split/payout disabled; customers pay logistics partners directly under the lean non-custodial model.
- Implement only separately agreed KRIM service/referral/coordination fee collection, invoice, tax treatment, ledger posting and bank reconciliation.
- Run staging tests first; any real low-value payment test requires separate explicit authorization.
- Do not start financial collection implementation until user confirms final-phase commencement.

## 5. Staging verification plan — execution order
1. **Identity and tenant isolation:** nine workspaces, two-tenant fixtures, revoked membership, wrong org type, wrong role, missing permission, AAL1/AAL2 and forged client claims.
2. **Partner trust lifecycle:** submission, evidence review, independent approval, capability/service-area/compliance expiry and suspension.
3. **Market/corridor gate:** country pack and regulatory-source provenance, corridor dossier, control approvals, customs requirements and fail-closed behavior.
4. **Customer request and quote:** create/read/update ownership, valid locations, idempotency, quote expiry and acceptance.
5. **Capacity and dispatch:** concurrent reservation, partner/resource binding, driver/vehicle readiness, route controls and atomic dispatch preconditions.
6. **Driver and tracking:** assignment ownership, actor identity, milestone order, location privacy, exception and POD.
7. **Warehouse and returns:** stock reservation race, pick/transfer protection, receipt atomicity, return NULL validation and independent QC.
8. **Customs:** licence/jurisdiction, document submission, reviewer independence, broker response and authority clearance separation.
9. **Enterprise/admin:** analytics/document/approval/integration boundaries, support desk least privilege, admin AAL2, no self-approval and audit trails.
10. **CRM/notifications:** consent, enquiry-to-case linkage, duplicate/retry recovery and real test-recipient delivery with explicit authorization.
11. **Regression and release:** full critical journey in staging, accessibility/mobile, empty/error states, audit log, security review and independent signoff.
12. **Financial phase last:** only after preceding gates and separate approval.

All tests must use staging fixtures and non-production providers/test modes. Do not use production business RPCs as test fixtures.

## 6. Migration and production change control
Production migration history and repository migration files remain materially divergent. The previous reconciliation identified 558 production history rows, 363 repository SQL files, 348 unique repository timestamps, 13 duplicate timestamp groups, three duplicate-name groups, 75 repository migration names absent from production history and 270 production migration names absent from the repository. Metadata-only history is not enough to prove SQL equivalence.

The protected sanitized schema-manifest workflow and operator guide are available. The user must manually launch the workflow with source run `43793099331` and artifact `14198261776` using the documented GitHub Actions procedure. Until the sanitized manifest and migration crosswalk are reviewed:
- Do not replay, baseline, squash or apply repository migrations.
- Do not execute corrective production DDL or modify SECURITY DEFINER functions.
- Continue only read-only inspection, static analysis and isolated staging preparation.

## 7. Verification and evidence rules
- Record repository commit SHA and source-file SHA for every code inspection or change.
- Distinguish static source evidence, database catalog evidence, staging execution evidence and production deployment evidence.
- A green production smoke check or static link audit is not proof that a customer or partner journey works.
- Do not claim any workflow complete until actual test evidence exists for its positive, negative, authorization, concurrency and recovery paths.
- Keep all customer/partner contact, contract acceptance, real-world approvals and external commitments under explicit user authorization.

## 8. Linked batch reports and baseline
- `KRIM-ROUTE-ACTION-REGISTER-BATCH-01-DRIVER-WAREHOUSE-FINANCE-2026-11-16.md`
- `KRIM-ROUTE-ACTION-REGISTER-BATCH-02-PARTNER-OPERATIONS-2026-11-16.md`
- `KRIM-ROUTE-ACTION-REGISTER-BATCH-03-CUSTOMER-ENTERPRISE-CUSTOMS-2026-11-16.md`
- `KRIM-ROUTE-ACTION-REGISTER-BATCH-04-ADMIN-PLATFORM-AND-ENTRY-2026-11-16.md`
- `KRIM-CANONICAL-APPLICATION-HTML-INVENTORY-2026-11-16.md`
- `KRIM-CONSOLIDATED-SYSTEM-WIDE-VERIFICATION-AND-RELEASE-GATE-2026-11-16.md`
- `KRIM-NINE-WORKSPACE-AUTHORIZATION-AND-TENANT-ISOLATION-TEST-MATRIX-2026-11-16.md`
- `KRIM-SCHEMA-MANIFEST-WORKFLOW-OPERATOR-GUIDE-2026-11-16.md`

## 9. Final status
**NO-GO for unrestricted production logistics execution and financial collection.** The application has broad coverage of user journeys at the page and RPC-surface level, but it is not yet proven as a reliable, globally activated, real-world operating network. Complete migration reconciliation and staged operational verification before enabling live operations. Keep KRIM's own-fee financial work for the final phase.
