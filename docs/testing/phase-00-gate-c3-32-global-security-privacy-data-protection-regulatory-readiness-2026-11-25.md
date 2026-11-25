# C3.32 — Global Security, Privacy, Data Protection & Regulatory Readiness Audit

**Date:** 25 November 2026  
**Baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**QA branch:** `qa/phase-00-baseline-2026-11-25`  
**Method:** Read-only source and historical audit review. No production/staging SQL, Auth, storage, secrets, user data, consent, provider, external communication or configuration action was performed.

## Executive decision

**FAIL / BLOCKED — NO-GO for security certification, privacy-compliance certification, unrestricted personal-data collection, or global regulatory readiness.**

The platform contains meaningful controls: RLS is enabled on all public application tables in a historical production catalog snapshot; five evidence buckets were private; key authentication paths use TOTP/AAL2; some privileged functions enforce organization and permission checks; support and claims data are tenant-scoped. These are positive design signals, not proof of end-to-end security or legal compliance.

The decisive gaps are broad authenticated-callable privileged database code, unresolved authorization/tenant isolation, mutable customer consent records, incomplete purpose-specific consent and withdrawal, unverified retention/deletion and data-subject request handling, incomplete security incident/breach response, incomplete Storage/evidence governance, and absence of independent adversarial staging tests. Historical evidence is not a current live measurement.

## Evidence reviewed

- `docs/KRIM-PRODUCTION-READ-ONLY-SECURITY-REVIEW-2026-11-09.md`
- `docs/KRIM-STORAGE-AND-VIEW-SECURITY-REVIEW-2026-11-09.md`
- `docs/audits/2026-11-17-account-security-and-mfa-second-functional-pass.md`
- `docs/audits/2026-11-17-authentication-and-account-security-closure-gate.md`
- `docs/audits/2026-11-17-organization-membership-role-and-workspace-authorization-audit.md`
- `docs/audits/KRIM-NINE-WORKSPACE-AUTHORIZATION-ROLE-MAPPING-AND-TENANT-ISOLATION-DEEP-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-API-RPC-AND-EDGE-FUNCTION-INVENTORY-EXPOSURE-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-EDGE-FUNCTION-EXPOSURE-AUTHORIZATION-AND-PROVIDER-BOUNDARY-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-CUSTOMER-PROTECTION-SUPPORT-CLAIMS-CONSENT-AND-INCIDENT-RESPONSE-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-CRM-CONSENT-NOTIFICATION-AND-EXTERNAL-COMMUNICATION-ASSURANCE-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-LIVE-SECURITY-DEFINER-TRIGGER-AND-FINANCE-WRITER-AUDIT-2026-11-16.md`
- C3.10, C3.28, C3.29, C3.30 and C3.31 Phase 00 gate findings.

## Positive controls

1. Historical production catalog inspection found RLS enabled on all 378 public tables/partitioned tables. 21 policy-less tables had no direct anon/authenticated table grants in the reviewed privilege checks.
2. No reviewed SECURITY DEFINER function was executable by anon in the 9 November snapshot. Function-level search_path configuration was present in the inspected set.
3. Five evidence buckets were private. Four active evidence buckets had scoped policies reviewed at a high level for ownership, organization membership, assignment, shipment and reviewer permissions.
4. Login/MFA flows check active organization membership, map workspaces to actual membership and require AAL2 for protected admin paths. MFA callback routing was hardened to reject arbitrary return destinations.
5. Support ticket, claims and evidence workflows include owner/organization scope, AAL2 review and private evidence checks in reviewed paths.
6. Several direct table writes are intentionally withheld and sensitive workflows use dedicated RPCs rather than generic browser mutations.

## P0 — critical blockers

### P0.1 — Broad privileged database/API surface not fully authorized

Historical audits counted 126 public SECURITY DEFINER functions executable by authenticated in the 9 November snapshot; a later 16 November live catalog audit counted 150 authenticated-executable SECURITY DEFINER functions among 332 public functions. These counts are different dated snapshots and should not be conflated. SECURITY DEFINER is not automatically a vulnerability, but every callable routine must be reviewed for caller identity, role, organization, object ownership, exact shipment/leg, current membership, AAL and state-transition authorization. The prior review explicitly left a substantial function set unreviewed.

C3.28 also identified an Admin frontend auth context that derives role/tenant from editable user metadata. Client metadata must never be an authorization authority. Every sensitive action must derive authorization from trusted server-side membership and permission state.

**Impact:** tenant-boundary or privilege escalation defects may exist in unreviewed call chains. No complete adversarial negative-test evidence exists.

### P0.2 — Consent register integrity is not trustworthy

The 16 November customer-protection audit found direct authenticated INSERT/UPDATE/DELETE privileges on `krim_customer_consents` and an organization-scoped ALL policy. Ordinary organization members could mutate or delete consent records outside the intended consent function. The same audit found the inspected consent grant function's effective authenticated EXECUTE privilege was false. Signup acknowledgement was also stored in editable user metadata in a prior audit.

**Impact:** the current consent record cannot be relied upon as an immutable, legally sufficient record of who consented to which version, purpose, channel and processing operation, or when they withdrew it.

### P0.3 — No verified end-to-end security/privacy test environment

Historical Staging was an empty application database; migration history was materially inconsistent with the repository. No synthetic nine-persona cross-tenant security suite has been demonstrated against a reconciled, isolated staging system. Static source review and RLS-enabled counts do not prove effective authorization.

## P1 — major privacy and security gaps

1. **Purpose limitation and granular consent:** privacy-notice acknowledgement is not marketing, promotional messaging, partner sharing, GPS/location, analytics or other purpose-specific consent. Channel-specific opt-in/opt-out and withdrawal semantics are incomplete.
2. **Data subject rights:** no verified end-to-end workflow for access, correction, portability, objection/withdrawal, restriction, erasure where legally applicable, identity verification, response tracking and exception handling was established.
3. **Retention and deletion:** no verified data-class retention schedule, automated expiry/deletion, legal-hold exception, evidence lifecycle, backup expiry or deletion propagation across database, Storage, logs, exports and processors was demonstrated.
4. **Sensitive document governance:** private bucket configuration is a positive control but not a complete lifecycle. The legacy `pod-documents` bucket had no object policies, no size/MIME limits and zero objects in the historical review; do not use it. Signed URL expiry/revocation, malware scanning, immutable evidence integrity, access logging, retention and secure deletion remain unproven.
5. **Authentication/session lifecycle:** TOTP/AAL2 guards exist, but remote session revocation, active-session enumeration, backup-code/passkey recovery and password policy consistency were not end-to-end verified. A historical audit found the active-sessions page only signs out the current browser.
6. **Leaked password protection:** historical Supabase Auth review recorded leaked-password protection disabled. Current setting was not refreshed in this gate.
7. **Security incident and breach response:** no verified end-to-end incident command, triage, containment, forensic preservation, legal assessment, regulator/data-principal notification decision tree, timed escalation, tabletop exercise or recovery evidence was found.
8. **Processor/subprocessor governance:** no complete verified inventory of hosting, email, messaging, payment, analytics, identity and other processors; processing locations; transfer mechanisms; contractual safeguards; deletion obligations; or subprocessor change monitoring was established.
9. **International transfer/country controls:** global country packs and corridor legal requirements remain research-pending in prior audits. No country-by-country privacy/transfer approval matrix or cross-border data-flow register was proven.
10. **Encryption/key management:** transport/storage protections are not a full key-management certification. Key ownership, rotation, access review, KMS/HSM controls, backup encryption recovery and audit evidence remain unverified.
11. **Export and privileged access:** data export DLP, purpose/approval, row minimization, watermarking, download expiry, audit durability and independent review are incomplete. C3.28 also found privileged audit writes may fail silently in one admin function path.
12. **Vulnerability and supply-chain assurance:** no independent penetration test, dependency/SBOM review, vulnerability remediation SLA, secure SDLC evidence or signed release attestation was established.
13. **Claims and support privacy:** a prior review found claim-to-assignment ambiguity for multi-leg shipments; support and claim records need strict need-to-know controls, customer-visible/internal separation, retention and access audit.
14. **Data accuracy and minimization:** define mandatory vs optional fields for identity, cargo, location, contact and document data. Avoid collecting government ID or location data unless necessary for a specific verified service and legal basis.

## Regulatory readiness — India first, global by design

This audit does **not** provide legal advice or certify compliance with India's Digital Personal Data Protection Act/rules, IT Act/SPDI requirements where applicable, consumer/e-commerce obligations, sector-specific logistics/customs requirements, or foreign privacy laws such as GDPR/UK GDPR and other national regimes.

Before processing real customer/driver/partner personal data at scale, obtain qualified India privacy counsel review of the applicable commencement/rules and KRIM's actual role for each processing purpose (data fiduciary/controller, processor/service provider, or independent party). Map notices, lawful grounds/consent where required, children's data if relevant, grievance contact, security safeguards, breach process, retention, rights handling, processor contracts and cross-border transfers. Do not claim GDPR or DPDP certification from the presence of a privacy policy or checkbox.

## Required remediation sequence

1. Preserve evidence and keep production workflows read-only where security/privacy gates are not passed; do not enable GPS, broad document upload, marketing broadcasts, data exports or unrestricted onboarding.
2. Reconcile schema/migration history before any permission or consent DDL. Do not apply broad revokes or policy changes blindly.
3. Build a complete privileged-function register: effective EXECUTE grants, SECURITY DEFINER/INVOKER, search_path, caller identity, organization/role/permission/AAL checks, tenant predicates, object/leg binding, state invariants and negative tests.
4. Replace editable metadata authorization with server-verified role and tenant resolution; ensure every sensitive backend action revalidates current membership, permissions and session assurance.
5. Design append-only consent grant/withdrawal evidence with exact notice/purpose/channel/version/hash, capture context, timestamp, actor, source and revocation event. Remove direct client mutation only through a reviewed, staged, dependency-aware migration.
6. Establish a data inventory and processing register: categories, purposes, data subjects, lawful basis, recipients/processors, countries, retention, security controls and deletion paths.
7. Implement and test data-subject request, correction, withdrawal, deletion/retention exception and grievance workflows.
8. Implement data-class retention and secure deletion across database, Storage, logs, exports and processors; document backup expiry and legal hold.
9. Complete evidence bucket policies, limits, malware/content validation, signed-link lifecycle, access audit and object-level isolation; keep unused legacy bucket disabled.
10. Define incident/breach response roles, escalation, evidence preservation and legally reviewed notification timelines; conduct a tabletop exercise.
11. Complete processor agreements, transfer assessments and country/corridor legal approval before activating each market.
12. Run independent penetration testing and synthetic cross-tenant negative tests in a reconciled staging environment; remediate and retest every P0/P1 before controlled pilot.

## Gate decision

**C3.32 FAIL / BLOCKED.** Meaningful security controls exist, but there is no verified complete security, privacy, data-protection or global regulatory compliance posture. No Production/Staging changes or personal-data tests were performed. Historical findings and counts are not current live measurements. A policy page, RLS flag, MFA screen or static code review is not a compliance or security certification.
