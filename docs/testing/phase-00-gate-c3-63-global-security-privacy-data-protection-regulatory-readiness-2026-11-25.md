# Phase 00 — Gate C3.63: Global security, privacy, data protection and regulatory readiness

**Audit date:** 25 November 2026  
**Evidence baseline:** immutable source commit `72d75a18f985ceb09e468839435ee95700e11e46`; read-only review of existing 9–24 November security/catalog audit artifacts, privacy/storage/abuse source audits and public legal-notice pages.  
**Verdict:** **FAIL / BLOCKED — NO-GO for security certification, complete privacy-rights claims, unrestricted public onboarding, or global regulatory-compliance claims.**

## Scope and method

Reviewed the prior production security triage, SECURITY DEFINER inventory, migration-history reconciliation, privacy/consent/retention/deletion audit, private Storage/evidence audit, public-auth abuse audit, privacy/cookie/terms/account-action UI and `.well-known/security.txt`. This gate consolidates and cross-checks existing evidence; it did not run new live database queries, browser probes, penetration tests, legal review or provider tests. Historical snapshots are not current state.

## Positive controls observed

1. The 24 Nov security triage reconciled the Security Advisor's 29 RLS-enabled/no-policy findings to 24 public plus five private objects. Those objects had no anon/authenticated data grants in the inspected catalog and fail closed for ordinary table access; no blanket policy creation is justified.
2. The same triage reports 333 public SECURITY DEFINER functions, zero missing search_path configuration, 188 explicit empty search_path configurations, and 151 authenticated-callable functions as an Advisor finding. It explicitly treats these as inventory requiring individual call-chain/ACL review—not proof every function is vulnerable.
3. Production security review reports zero public tables without RLS; that does not replace per-table grants/policy/tenant tests.
4. Five production Storage buckets were private and object count was zero in the 16 Nov snapshot. Several driver, partner, warehouse, customs and POD evidence flows bind paths to uploader/tenant/assignment and use independent review.
5. Public customer inquiry captures a notice acknowledgement/version; password-reset responses are designed to be neutral; canonical driver invitation uses high-entropy one-time token hashes and email/eligibility checks.
6. Public privacy, interim retention and cookie notices disclose limitations and direct privacy requests to Contact rather than falsely presenting an operational self-service export service.

## P0 — Release-blocking security/privacy findings

### SEC-01 — Security Advisor/function exposure review remains incomplete
The 24 Nov audit reports 151 authenticated-callable SECURITY DEFINER functions as an Advisor finding, and the separate inventory reports 333 public SECURITY DEFINER functions. The ten marker-free functions received only spot checks; delegated callees, dynamic SQL, schema-qualified references, EXECUTE ACLs, and transitive authorization were not exhaustively reviewed. Empty search_path is not itself a vulnerability and must not be changed to public. The 29 RLS-enabled/no-policy objects are fail-closed for ordinary roles in the inspected grant set; do not add broad policies to silence Advisor.
**Required:** complete function-by-function caller/callee/ACL/authorization review; verify default PUBLIC and inherited EXECUTE; test each exposed RPC under anon, ordinary tenant member, wrong tenant, wrong role and service role; no blanket revokes or search_path rewrites.

### SEC-02 — Production migration-history mismatch blocks safe security remediation
The 24 Nov migration reconciliation explicitly says repository migration history and Production ledger cannot be safely treated as aligned; no production migration-history repair or DDL is authorized. This prevents treating source migration hardening as deployed truth.
**Required:** reconstruct exact ledger/collision crosswalk, preserve immutable evidence, build/replay a clean baseline in a disposable isolated project, compare schema/functions/grants/RLS/triggers/indexes/extensions, and obtain an approved migration plan before any database mutation.

### SEC-03 — Account deletion/deactivation/identity request UI conflicts with database constraint
The 16 Nov privacy audit compared `auth/krim-account-actions.js` hyphenated request values (`account-deletion`, `account-deactivation`, `identity-verification`) with database CHECK values using underscores. The UI requests therefore violate the inspected live CHECK constraint; no test insert was attempted. The same audit found no verified processor or completed deletion workflow.
**Required:** reconcile the canonical enum/constraint and UI values only after migration-history resolution; build re-authenticated request processing, identity verification, legal-hold review, membership/session handling, cross-workspace dependency review, Storage/processor/backup handling and auditable completion. A request submission must never be described as deletion completion.

### SEC-04 — No operational data export, retention or deletion lifecycle
Historical 16 Nov snapshot: zero consent, export, deletion/account-action and retention-policy rows; no named database processor found for export/purge/erase/deletion. Data-export UI says service not connected. No approved category/jurisdiction retention schedule or demonstrated purge worker. A personal-data request must distinguish an individual's data from another subject's or tenant's business data across all nine workspaces.
**Required:** implement a legally reviewed subject/tenant resolver, redaction, encrypted short-lived export vault, access audit, expiry/revocation, deletion/pseudonymization, processor-copy and backup handling, legal holds, and a category/purpose/jurisdiction retention schedule. Until then do not promise self-service export, deletion or automated retention.

### SEC-05 — Consent capture and withdrawal are not tamper-resistant
The 16 Nov audit found customer consent rows directly rewritable/deletable by authenticated organization members while intended SECURITY DEFINER grant function was not effectively callable in the inspected grant set. User-level consent events were client-inserted with free-text policy versions and user-selected event types; signup terms event was derived from editable `raw_user_meta_data.terms_accepted`. Consent withdrawal was not proven to suppress marketing/communications.
**Required:** server-maintained policy versions and notice presentation evidence; append-only, authenticated grant/withdraw events; no ordinary client DML to customer consent ledger; propagate withdrawal to marketing/notification suppression and processors; retain only legally justified minimized evidence.

### SEC-06 — Public signup and tracking abuse controls are not certified
The 16 Nov abuse audit found no CAPTCHA/Turnstile in customer, partner or driver signup; contact IP throttling is skipped when trusted Cloudflare IP header is absent; public tracking had no application-level rate limit or explicit request-size cap; provider-side Auth CAPTCHA/rate limits/SMTP/security configuration remained unverified. Raw driver login error exposure and invite-token query/sessionStorage leakage risks were noted.
**Required:** enforce trusted ingress rate limits that fail safely, request-size/token-hash throttles for tracking, supported Supabase Auth CAPTCHA, consistent safe errors, verified provider limits, and token redaction/referrer/history protections. Test abuse cases in isolated Staging.

## P1 — Material privacy, storage and compliance risks

### SEC-07 — Legacy POD bucket lacks bucket-level MIME/size policy and dedicated bucket-specific object policy
Historical Storage audit: five buckets private and zero objects; `pod-documents` had no bucket-level size/MIME restrictions and no bucket-specific authenticated RLS policy found. Private-by-default is positive, but do not enable writes until the intended use and complete effective policy are proven. No blanket Storage grant revocation.
**Required:** dependency review, then either retire safely or configure a purpose-specific private bucket with size/MIME, owner, tenant, evidence state, retention and reviewer checks.

### SEC-08 — Signed URL lifecycle and revocation are unproven
No complete signed download/preview URL inventory, expiry/revocation test, cache/no-store check or cross-tenant replay test was established. A signed URL is a bearer capability until expiry; removing membership may not invalidate an already issued URL.
**Required:** enumerate every client/Edge download path, authorize immediately before issuance, shortest practical expiry, no URL in logs/analytics/notifications, private no-store responses and expiry/replay/tenant-negative tests.

### SEC-09 — Privacy notices and UI contain unsupported or inconsistent control claims
The privacy audit identifies static UI claims for WORM retention, fixed bills-of-lading/customs/ePOD periods, “EU / US Customs Compliant”, strict AP-SOUTH-1 residency and automated 90-day audit retention without active policy rows or demonstrated immutable storage. The historical Supabase project region was Tokyo `ap-northeast-1`, not AP-SOUTH-1. The interim notice correctly says statutory retention and cross-border processing review remain incomplete.
**Required:** remove or clearly label unimplemented retention, residency, WORM and compliance controls; keep privacy/cookie/terms notices consistent with actual processing, service providers, legal entity, contact and jurisdiction; obtain qualified India and relevant cross-border counsel review before making statutory compliance claims.

### SEC-10 — International transfer, processor and jurisdiction obligations are not closed
Privacy notice disclosed Tokyo hosting and pending cross-border processor review. Country/corridor customs readiness is independently blocked by C3.59. This audit is not a legal opinion and does not establish DPDP Act, GDPR, UK GDPR, ePrivacy/cookie, sectoral, customs or country-specific compliance.
**Required:** map data categories, purposes, roles (controller/processor), data-subject rights, subprocessors, transfer mechanism, residency, security safeguards, breach notification, retention and grievance/redress responsibilities by market; validate against applicable law with qualified counsel.

### SEC-11 — Incident response and breach assurance not proven
Existing customer-protection/incident audits describe support and incident surfaces, but no demonstrated end-to-end breach detection, severity classification, evidence preservation, containment, regulator/customer notification, processor coordination, recovery or post-incident review exercise was verified in this gate.
**Required:** approved incident/breach runbook, named accountable roles, contact tree, timelines by jurisdiction, evidence preservation, regulator/customer decision log, tabletop exercise and tested recovery.

### SEC-12 — No current runtime security proof
No new current Production grants/RLS/Storage/Auth configuration query, live route test, tenant-negative test, vulnerability scan, dependency scan, penetration test, signed URL test or isolated Staging privacy workflow test was performed. Dated historical evidence must not be presented as current certification.

## Required isolated Staging security/privacy acceptance matrix (not executed)

1. Role × tenant × table × operation matrix; tenant A cannot enumerate/read/write/export tenant B.
2. RPC/function matrix for anon, ordinary user, wrong role, wrong tenant, AAL1/AAL2 and service role; include transitive SECURITY DEFINER callees and EXECUTE ACL.
3. Public signup CAPTCHA, email verification, password spraying, reset throttling, trusted-IP absence, request-size and tracking-token enumeration.
4. Consent grant/withdraw/replay/policy-version tampering and proof that withdrawal stops relevant communications.
5. Account request valid/invalid enum, identity re-authentication, legal hold, multi-workspace dependency and processor completion.
6. Export subject/tenant authorization, completeness, redaction, archive encryption, signed-link expiry/revocation and cleanup.
7. Retention/purge dry-run, legal hold, backup copies, orphaned Storage object, retry/idempotency and immutable audit.
8. Storage MIME/size/path/owner/tenant mismatch, duplicate upload, replacement, signed URL expiry and post-revocation access.
9. Incident tabletop, provider outage, key compromise, breach evidence and recovery.
10. Verify actual Auth CAPTCHA/rate limits/SMTP, Storage policies, data region and subprocessor inventory through authorized configuration review.

## Evidence classification

- **Immutable source findings:** account-action UI values; consent UI; public signup pages; privacy/cookie/terms pages; security.txt; reviewed workflow and source code.
- **Historical production/catalog evidence:** 9–24 November security, migration, privacy, Storage and function audits. Counts and policies are dated snapshots—not current state.
- **Runtime status:** NOT TESTED in this gate. No live query, signup, request, export, deletion, consent event, Storage upload/download, signed URL, penetration test, incident drill or provider call was executed.
- **Legal status:** NOT CERTIFIED. This technical review is not legal advice or a regulatory attestation.

## Decision

**FAIL / BLOCKED.** Do not claim KRIM is security-certified, privacy-rights complete, deletion/export/retention operational, abuse-resistant, or globally compliant. Keep the notices candid; do not claim unimplemented residency, WORM, statutory retention or certification controls. No external user onboarding clearance is granted by this audit.

## Safety boundary

Read-only immutable-source inspection and review of existing historical audit artifacts only. No Production/Staging SQL/RPC, no personal records or secrets, no Auth/account/consent changes, no export/deletion, no Storage upload/download/signed URL, no provider communication, no security scan against live targets, no penetration test, no DDL/DML, no deployment and no legal representation.
