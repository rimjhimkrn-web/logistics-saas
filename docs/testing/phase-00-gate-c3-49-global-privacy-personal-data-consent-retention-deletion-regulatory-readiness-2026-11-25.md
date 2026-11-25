# C3.49 — Global privacy, personal-data protection, consent, retention, deletion and regulatory-readiness audit
**Date:** 25 November 2026  
**Immutable source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**Method:** Read-only review of privacy notice, interim retention notice, privacy/consent/account-action pages, cookie policy, retention/privacy-control UI, consent-capture migrations and dated 16 November privacy/consent lifecycle audits. Historical live database findings are explicitly dated and are not represented as a fresh live-state verification. No personal-data rows, user records, consent records, files or Storage objects were read.

## Executive verdict
**FAIL / BLOCKED — NO-GO for claiming operationally complete privacy rights, verified consent withdrawal, automated export/deletion, active retention enforcement, regional residency controls or legal compliance certification.**

Positive: the primary privacy notice and interim retention notice disclose the Tokyo database region, unfinished cross-border review, unapproved retention schedule and absence of verified automated purge; the notices avoid claiming India-only residency or legal certification. Driver location is described as off by default and subject to express session consent/technical launch gates. The retention notice explicitly withdraws unsupported historical claims about 90-day GPS purge, 365-day cold storage, WORM, custom AES-256 vault and NIST erasure.

However, the product and data lifecycle remain incomplete. A dated 16 November production audit found that all three account-action request types submitted by the UI violate the database CHECK constraint; consent history is mutable or client-authored in ways that do not prove informed consent; no connected export/deletion/purge processor or active retention policy was evidenced; and static privacy/retention pages contradict the careful legal notices. These historical live findings require fresh verification before remediation, but the source-level defects and conflicting UI remain relevant.

## Evidence reviewed
- `privacy.html` and `public/legal/data-retention.html`.
- `auth/consent-management.html`, `auth/account-deletion.html`, shared `auth/krim-account-actions.js` (as described in dated audit).
- `public/app/privacy-controls.html`, `public/documents/document-retention.html`, `public/legal/cookie-policy.html`, `public/app/data-export.html` (as described in dated audit).
- `20261111160000_record_public_inquiry_privacy_consent.sql`.
- `20261111190000_record_customer_signup_terms_consent.sql`.
- `20261115065006_driver_tracking_consent_notice_archive.sql` and `20261115070000_driver_tracking_consent_sessions.sql`.
- Dated 16 November audits: privacy/consent/personal-data rights/retention/deletion; CRM consent/notification assurance; customer tracking/privacy boundary.
- No fresh live database/catalog inspection was performed in this gate. Counts and grants below are historical snapshots only.

## 1. Privacy notice and transparency
**PARTIAL PASS.** The primary notice describes categories and purposes, partner/provider sharing, payment handling, international transfers, retention, user requests, cookies/logs, children, workspace roles and privacy contact routes. It correctly states that it is an operational notice, not legal advice or certification, and says data flows, processors, retention, privacy contact and cross-border transfers still require verification.

The interim retention notice is particularly careful: no complete category-by-category schedule is approved; automated archive/purge is unverified; Tokyo hosting is disclosed; GPS inactivity stop is not deletion; and older unsupported retention/security claims are withdrawn.

**P1:** The notices are not evidence that all live data flows, providers, subprocessors, edge execution regions, backup locations, processor contracts, transfer mechanisms, retention jobs or privacy request operations have been inventoried and verified. A notice cannot substitute for operational implementation.

## 2. P0 — Account access/deactivation/deletion request UI is incompatible with database constraint
The dated 16 November audit compared `auth/krim-account-actions.js` with the production CHECK constraint:
- UI page identifiers: `account-deactivation`, `account-deletion`, `identity-verification`.
- Accepted database values: `account_deactivation`, `account_deletion`, `identity_verification`.

The UI passes the hyphenated page ID directly as `request_type`; the insert is expected to fail the CHECK constraint for all three request categories. No insert was attempted. This is a historical live-schema comparison, not a newly executed live test; reconcile current migration/deployed state before changing it.

Even if the enum mapping is corrected, an intake row is not account deletion. No verified identity/authority, reviewer assignment, status lifecycle, legal-hold decision, cross-workspace dependency analysis, processor-copy handling or completion evidence was established.

**Required:** strict server-side mapping to allowed request types, isolated-Staging tests, verified identity and authority, audited owner/reviewer workflow, due dates, legal-hold review, secure response and completion evidence. Never represent request submission as completed deletion.

## 3. P0/P1 — Consent evidence, purpose limitation and withdrawal
### Customer/profile consent
The 16 November historical production audit found `krim_customer_consents` empty, RLS enabled, authenticated direct INSERT/UPDATE/DELETE privileges and an organization-scoped ALL policy. The intended `krim_grant_customer_consent` SECURITY DEFINER function was not effectively executable by authenticated users in that snapshot. Its upsert model can rewrite a granted state rather than preserve an immutable sequence of grant/withdraw events.

**P0/P1:** reconcile current grants and migrations; remove ordinary member direct mutation; implement narrowly scoped, server-validated append-only consent events and verified grant/withdraw paths.

### User-level consent events
The historical audit found `krim_user_consent_events` empty, with own-user INSERT/SELECT and no authenticated UPDATE/DELETE. The UI lets a user select marketing email, analytics or personalization, grant/withdraw, and supply a free-text policy version; the browser inserts directly. This is an event assertion, not proof that a specific approved notice was presented or that the chosen purpose/channel was adequately explained. No withdrawal-to-marketing-suppression consumer was evidenced.

The customer signup migration reads `terms_accepted` and `terms_version` from editable `raw_user_meta_data` inside an Auth trigger. User metadata must not be treated as authoritative legal consent evidence. The signup terms/privacy event also does not grant marketing consent.

### Public enquiry acknowledgement
The public inquiry RPC stores `privacy_consent=true` and notice version `2026-11-11`. This is notice acknowledgement for the enquiry workflow, not optional marketing opt-in or blanket permission for unrelated processing. Keep transactional service communications separate from promotional messaging.

**Required:** approved server-side purpose/channel catalogue; exact notice text/version/hash; actor, timestamp, channel, source and evidence; separate purposes for terms/privacy, required service processing, marketing, analytics and personalization; append-only withdrawal; suppression propagation to scheduled and queued campaigns; independent negative tests.

## 4. P1 — Data export request table is not a working export service
The dated audit found the export-request table empty and own-user RLS/insert/select controls, but no export worker, Edge Function or job in the reviewed repo/function-name catalogue. The public export page explicitly says “Export service · not connected” and that no verified tenant export job, download vault or audit archive is connected.

No verified resource resolver covers personal data across all nine workspaces, attached files, consent, memberships, operational records and processor copies. No encrypted archive, short-lived signed download, revocation, access audit, expiry cleanup, machine-readable format or enterprise-vs-individual authority checks were evidenced.

**Decision:** do not promise self-service export. Implement identity/authority verification, cross-workspace discovery, tenant/third-party redaction, encrypted short-lived package, download audit, expiry and cleanup before making such a claim.

## 5. P0/P1 — Retention and deletion are not technically enforced
The 16 November historical snapshot found `krim_data_retention_policies` empty and no active periods, legal-hold rules or matching database purge/archive/deletion routines by name. This is not proof that no external scheduled job exists, and no fresh live inspection was performed.

The interim retention notice accurately says no final category schedule or verified automated purge is active. It notes that stopping GPS sharing does not delete historical coordinates.

Contradictory product surfaces remain:
- `public/documents/document-retention.html` displays fixed 7-year bills-of-lading, 10-year customs declaration and 5-year ePOD retention, “EU / US Customs Compliant” and WORM-lock claims without demonstrated active policy rows or immutable storage.
- `public/app/privacy-controls.html` presents AP-SOUTH-1 residency enforcement and 90-day audit retention as if configured, conflicting with the dated live Tokyo region and cautious notice.
- Static controls are not proof of persistence or enforcement.

**P0:** remove or clearly relabel unsupported operational/compliance/residency/retention claims as planned or inactive before user onboarding.  
**P1:** approve category × purpose × jurisdiction retention schedule; legal holds; archive/purge implementation; dry-run, idempotency, retry, alerting and immutable job evidence; include backups, signed URLs, derived copies and processors. Account deletion must not erase legally required financial/audit records indiscriminately, nor preserve excess personal data without a documented basis.

## 6. P1 — Private Storage is not a complete privacy lifecycle
The dated audit recorded five private buckets and zero objects at that time, with 26 Storage policies. Private access controls are useful but do not provide retention, expiry or deletion. No tested coordinated lifecycle was evidenced for object + metadata + derivatives + signed URLs + backups. The `pod-documents` bucket was noted as lacking bucket-specific size/MIME limits and needing effective-policy review. These are historical observations, not fresh live configuration checks.

Required: bucket-by-bucket effective access review, MIME/size caps, object ownership, signed URL expiry/revocation, orphan cleanup, legal holds and coordinated retryable deletion with audit evidence.

## 7. P1 — Manual privacy request route is not operationally proven
The notices route requests through Contact. A manual route is acceptable only if a monitored inbox and staffed process exist: identity/authority verification, request register, jurisdiction and deadline tracking, scope discovery, secure response, lawful exception/legal-hold review, fulfilment evidence and escalation/appeal. The dated audit found no operational request records or verified end-to-end response. Do not claim guaranteed or automated fulfilment.

## 8. P1 — Nine-workspace data-subject and tenant boundary
Rights workflows must distinguish an individual's personal information from organization-owned business records and other people's data across Customer, Partner, Driver, Warehouse, Customs, Finance, Operations, Enterprise and Admin. Enterprise membership must not confer unrestricted export of every individual's data; a personal request must not disclose another tenant's records. A subject identity map, resource resolver, role/tenant authority checks and redaction rules are not demonstrated.

## 9. P1 — Cross-border processing and legal readiness
The dated 16 November audit reported the Production Supabase database region as `ap-northeast-1` (Tokyo, Japan), not India. The primary notice and retention notice disclose this and say provider/transfer review remains incomplete. The privacy-controls mock AP-SOUTH-1 claim contradicts it. Edge execution, backup copies, provider-managed copies and subprocessor locations were not established in this gate.

Before commercial launch, obtain qualified Indian legal review of KRIM's role for each processing activity, customer/partner controller-processor relationships, contracts, subprocessor inventory, international transfers, applicable DPDP Act/Rules commencement and obligations, grievance/privacy contact, incident response and any other relevant jurisdiction. Do not claim DPDP/GDPR/CCPA compliance or certification based on this technical audit.

## 10. Priority acceptance plan
### P0 before real privacy-request reliance or broad onboarding
1. Fix and test account-request enum mapping in isolated Staging.
2. Remove/relabel mock retention, WORM, residency and compliance claims not backed by active controls.
3. Establish accountable privacy request ownership, identity verification, due-date tracking, legal-hold and fulfilment evidence.
4. Reconcile current deployed migrations/grants before consent or deletion schema remediation.

### P1 before privacy lifecycle claims
1. Append-only consent grant/withdraw ledger and suppression integration.
2. Server-controlled policy catalogue and exact notice evidence; remove editable user_metadata as legal proof.
3. Cross-workspace export with authority, redaction, encryption, expiring download and cleanup.
4. Category-specific retention and legal-hold schedule, automated purge/archive and backup/processor handling.
5. Orchestrated account deletion/deactivation with sessions, memberships, shipments, finance/tax records, evidence, Storage and processor copies.
6. Storage effective-policy, MIME/size, signed URL and deletion lifecycle verification.
7. Cross-border/subprocessor map and counsel-approved notices/contracts.

### Mandatory isolated-Staging tests — not executed
- Valid/invalid request types, user ownership and reviewer-only transitions.
- Consent grant/withdraw, invalid policy version, duplicate/replay, queued marketing suppression and transactional-message separation.
- Export all eligible data across nine workspaces without cross-tenant/third-party disclosure.
- Legal hold and retention dry-run, purge idempotency, failure/retry and backup expiry.
- Storage object/metadata/derivative/signed-link deletion and recovery.
- International region/provider inventory and notice-to-implementation reconciliation.

## Final decision
**C3.49 FAIL / BLOCKED.** NO-GO for privacy lifecycle certification, automated export/erasure, active retention enforcement, regional-residency claims or full consent-withdrawal claims. The primary notices are comparatively transparent, but account-request enum mismatch, incomplete consent integrity, disconnected export/deletion/retention workflows and contradictory mock product claims prevent operational readiness.

This was a read-only repository and dated-evidence audit. No personal data values, Auth users, consent rows, request rows, Storage objects or secrets were read; no requests, consent changes, exports, deletions, purges, database changes, provider calls or deployments were performed.
