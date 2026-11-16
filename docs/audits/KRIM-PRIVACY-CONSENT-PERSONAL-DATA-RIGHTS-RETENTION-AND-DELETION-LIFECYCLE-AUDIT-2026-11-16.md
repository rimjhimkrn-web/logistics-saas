# KRIM Privacy, Consent, Personal-Data Rights, Retention and Deletion Lifecycle Audit — 2026-11-16

## Executive decision

**NO-GO for claiming a complete operational privacy-rights, consent-withdrawal, data-export, retention or account-deletion service.** KRIM has a useful preliminary privacy notice and an interim retention/deletion notice that openly disclose implementation limits. Private Storage buckets and RLS-scoped request tables also exist. But the actual lifecycle is incomplete: there are no live consent, export, deletion or retention-policy records; no retention schedule is active; no export/deletion/purge processor was found; the account deletion/deactivation request UI submits values that violate the live database CHECK constraint; the customer consent register can be directly rewritten/deleted by authenticated organization members; and the user consent UI lets a user write arbitrary event values/policy versions without connecting withdrawal to marketing suppression.

This is a read-only source/catalog review. No personal data rows, consent events, export requests, account requests, Storage objects, Auth users or files were read/exported. No account action, consent event, deletion, retention job, export or storage mutation was performed.

## 1. Evidence baseline

Repository:
- HEAD at audit start: `8ef0c580ac834f1e799fad889dfb1acc8e2f8835`.
- Prior public authentication abuse audit CI completed successfully on that exact SHA:
  - production smoke `43856552399`
  - static link audit `43856552342`
  - Pages deployment `43856551272`.

Live production Supabase read-only snapshot:
- Auth users: 9 (aggregate count only; no user records read).
- Five relevant lifecycle tables all contain **0 rows**:
  - `krim_account_action_requests`
  - `krim_customer_consents`
  - `krim_data_export_requests`
  - `krim_data_retention_policies`
  - `krim_user_consent_events`
- Five tables have RLS enabled; none has FORCE ROW LEVEL SECURITY.
- Five private Storage buckets exist; total Storage objects: **0**.
- Storage object policies: 26 in total.
- Project region reported by the live project and reflected in the current notice: `ap-northeast-1` (Tokyo, Japan).
- No matching public/private database routines were found by name for retention, purge, export, erase, delete-user or account-action processing. This is a catalog-name search, not proof that no external scheduled job exists.
- No migration, DDL, DML, user, Storage, Auth or provider configuration was changed.

## 2. P0 — Account deactivation/deletion/identity requests fail the live CHECK constraint

### Frontend path
`auth/krim-account-actions.js` handles `account-deactivation`, `account-deletion` and `identity-verification` by setting:
`const type = page;`
and inserting that exact value into `krim_account_action_requests.request_type`.

### Live database constraint
The production CHECK constraint accepts only:
- `account_deactivation`
- `account_deletion`
- `identity_verification`

The page sends hyphenated values instead:
- `account-deactivation`
- `account-deletion`
- `identity-verification`

**Result:** the INSERT violates `krim_account_action_requests_request_type_check`; all three request workflows are expected to fail. This was established by comparing the exact frontend source with the live constraint definition; no test INSERT was attempted.

The table has authenticated INSERT/SELECT privileges and RLS policies for own pending requests / own reads. It has no authenticated UPDATE/DELETE grants in the inspected grant set. That is a reasonable user-owned request boundary, but the UI currently cannot create a valid request.

Additional issue:
- The foreign key `user_id REFERENCES auth.users(id) ON DELETE CASCADE` means a later Auth-user deletion would cascade-delete the request history. A completed deletion workflow needs a legally reviewed minimal audit record or pseudonymized request evidence that survives account removal where retention is justified; do not preserve excess personal data merely to preserve the audit trail.
- The request table has no demonstrated processor, identity verification, legal-hold assessment, cross-workspace dependency review, or completion event. The UI correctly says a request does not itself delete/deactivate the account.

## 3. P1 — Consent systems are split, empty and not end-to-end

### A. Customer/profile consent ledger — `krim_customer_consents`
Live state:
- 0 rows.
- RLS enabled; one organization-scoped `ALL` policy.
- Authenticated role has direct INSERT, UPDATE and DELETE privileges.
- Policy allows organization members with access to the customer profile's organization to insert, edit and delete rows.
- `krim_grant_customer_consent(text,text,text)` exists as SECURITY DEFINER but its effective authenticated EXECUTE privilege check is **false**.

Consequences:
- The intended grant function is not currently callable by authenticated users under the inspected effective grant.
- Direct table access permits organization members to bypass the function and rewrite/delete consent rows.
- The function upserts by (customer profile, consent type, version), resets status to granted and clears withdrawn_at; it does not provide an append-only withdrawal event or a durable sequence of every consent change.
- It supports `terms`, `privacy`, `data_processing`, `communications`, and `referral`, but no tested UI-to-function lifecycle was established.

**Finding:** consent history is not tamper-resistant and the intended invocation path is not verified.

### B. User-level consent events — `krim_user_consent_events`
Live state:
- 0 rows.
- RLS enabled; authenticated users can INSERT and SELECT only rows with their own `user_id`.
- Authenticated users do not have direct UPDATE/DELETE grants in the inspected grant set.
- Current type constraint accepts `marketing_email`, `product_analytics`, `personalization`, and `terms_and_privacy`.

Frontend:
- `auth/consent-management.html` uses the shared account action JS.
- User can choose marketing email, analytics or personalization; choose grant/withdraw; supply a free-text policy version; and the browser directly inserts an event.
- The UI reports “Consent event saved to the backend” on successful insert.

Gaps:
- Client can submit any allowed type, either boolean, and arbitrary policy_version; there is no server-controlled catalogue/version allowlist or evidence of a distinct capture purpose/channel/notice hash.
- This records a user-asserted event, not proof of a verified notice presented or legally sufficient consent.
- No demonstrated event consumer translates a withdrawal into suppression of future marketing/email/Telegram campaigns.
- Notification preference rows were zero in the prior CRM/notification audit. Transactional service notices and optional marketing must remain distinct.
- The signup trigger records `terms_and_privacy` from editable `raw_user_meta_data.terms_accepted`; user metadata is mutable and cannot be the authoritative consent source. The trigger should not silently turn a client-supplied metadata flag into legal evidence without a trusted capture/validation mechanism.
- The same event table's FK to Auth users uses ON DELETE CASCADE, so the consent history is deleted with the Auth account unless a separately reviewed, minimized retention record is preserved.

### C. Public enquiry privacy acknowledgement
The public inquiry RPC records `privacy_consent=true` and notice version `2026-11-11` for new enquiries. Production inquiry rows were 0 at the time of the related audit. This is an acknowledgement to a privacy notice for the enquiry workflow; it must not be treated as optional marketing consent or blanket consent for unrelated processing.

## 4. P1 — Data export request table exists, but export service is not connected

Live state:
- `krim_data_export_requests`: 0 rows.
- RLS enabled.
- Authenticated users can INSERT and SELECT only their own requests.
- Allowed scopes: `profile_and_preferences`, `activity_history`, `privacy_consent_history`, `account_data_request`.
- Status values: `queued`, `processing`, `ready`, `failed`, `cancelled`.
- Foreign key to Auth users is ON DELETE CASCADE.

Frontend:
- `public/app/data-export.html` explicitly labels “Export service · not connected”.
- It says unsupported export buttons and claims have been removed.
- It explicitly says no verified tenant export job, download vault or audit archive service is connected.

Gaps:
- No export worker/Edge Function/job was found in the reviewed repo and function-name catalog.
- No verified scope resolver enumerates all nine workspace data domains, attached files, audit evidence, user consent, organization memberships and relevant third-party/processor copies.
- No verified export archive encryption, signed download, expiry, one-time access, access audit or deletion-after-download lifecycle.
- No verified identity/authority checks for enterprise tenant exports vs an individual's own personal data.
- No proof of portability in a usable, machine-readable format or a response deadline workflow.

**Do not promise an in-app data export yet.** Privacy requests currently route through the public Contact page, not a working self-service export facility.

## 5. P1 — No active retention schedule or automated purge evidence

Live state:
- `krim_data_retention_policies`: 0 rows.
- RLS enabled; authenticated SELECT policy is broad read-only.
- No retention period, archive period, deletion method, jurisdiction, legal-hold policy or active status is populated.
- No matching public/private purge, archive, retention or deletion routine was found in the database function-name search.
- No Storage objects currently exist, but this does not prove that future uploads will expire or be deleted automatically.

The current interim `public/legal/data-retention.html` is appropriately cautious:
- It states that a complete category-by-category statutory retention matrix is not approved.
- It says automated archival/purge jobs have not been verified.
- It explicitly warns users not to rely on old fixed GPS, 365-day or other retention claims.
- It discloses that the production Supabase database is in Tokyo and requires cross-border processing review.
- It says this notice is not legal advice or a compliance certification.

However, other product pages conflict with that accurate disclosure:
- `public/documents/document-retention.html` hard-codes 7-year bills-of-lading, 10-year customs declaration and 5-year ePOD retention claims, plus “EU / US Customs Compliant” and WORM-lock messaging. These are static UI values, not backed by any active retention-policy rows or demonstrated immutable storage.
- `public/app/privacy-controls.html` presents clickable-looking privacy settings including “Strict Data Residency Enforcement (AP-SOUTH-1)” and “Automated 90-Day Audit Log Retention”. The page has no verified persistence/processing path; AP-SOUTH-1 also conflicts with the live Tokyo project region `ap-northeast-1`.
- These pages could cause users to believe controls are active when they are only mock/static UI.

**Required:** retire or relabel unsupported claims as “planned / not active” until a jurisdiction-specific schedule and technical enforcement are approved and tested.

## 6. P1 — Storage is private, but lifecycle governance is incomplete

Live Storage inventory:
- `krim-driver-evidence`: private, 10 MB limit, JPEG/PNG/WebP/PDF.
- `krim-driver-verification`: private, 10 MB limit, JPEG/PNG/WebP/PDF.
- `krim-partner-verification`: private, 10 MB limit, PDF/JPEG/PNG.
- `krim-warehouse-evidence`: private, 10 MB limit, JPEG/PNG/PDF.
- `pod-documents`: private, but no bucket-level file-size limit or allowed MIME types configured.
- Total objects across Storage: 0.
- Storage object policies: 26.

Positive controls:
- Multiple upload/read policies scope driver, customs, claims, partner and verified-POD evidence by authenticated user, organization, assignment or claim context.
- Some private evidence paths have explicit uploader-owner checks and cleanup rules for unlinked uploads.
- Verified POD access is constrained by shipment/customer authorization and verified status in the relevant policy.

Gaps:
- A private bucket is not itself a complete retention/deletion policy.
- No object lifecycle expiration or legal-hold integration was demonstrated.
- No tested deletion cascade from an approved account/organization deletion to unlinked files, linked evidence, signed URLs, derivatives or backups.
- `pod-documents` lacks bucket-specific file-size/MIME limits and was previously identified as lacking bucket-specific policies; validate the full effective access path before enabling uploads.
- Storage object deletion, DB metadata deletion and audit preservation need one orchestrated, retryable, idempotent workflow to avoid orphaned files or dangling evidence references.
- Signed URL expiry/revocation and backup expiry must be included in the retention model; deleting a database row alone does not invalidate already-issued copies or erase backups immediately.

## 7. P1 — Privacy request workflow is contact-only and not operationally verified

The public privacy notice points people to Contact and the “Privacy or data request” category. The interim retention notice likewise directs access, correction, deletion and retention questions to Contact.

This is a defensible interim manual intake route only if KRIM has:
- a monitored and staffed privacy-request inbox;
- a documented identity/authority verification process;
- a request register with receipt date, scope, jurisdiction, response due date and responsible owner;
- a procedure for correction/access/export/deletion/withdrawal;
- a lawful exception and legal-hold decision;
- a secure response channel and evidence of fulfilment;
- an appeal/grievance/escalation route.

No such operational case records were present in the inspected tables, and no end-to-end staffed response was verified. Do not advertise automated or guaranteed privacy-rights fulfilment.

## 8. Nine-workspace personal-data and tenant-boundary implications

The privacy notice describes nine user types, but a complete rights workflow must handle personal data that may be held across multiple organizational and operational contexts:

1. **Customer/Shipper:** identity/contact, company and shipment instructions, cargo details, quotes, support, claims, payment references.
2. **Partner/Carrier:** legal/business verification, contacts, capability/service areas, commercial quotes, contracts, compliance evidence, performance.
3. **Driver:** identity, contact, licence/verification documents, carrier membership, assignments, proof of delivery and (only if enabled) location/tracking data.
4. **Warehouse:** staff identities, facility access, inventory handling, quality/inspection evidence, custody and returns.
5. **Customs:** broker identity/licence, declarations, shipment documents, compliance decisions and authority-issued evidence.
6. **Finance:** billing contacts, invoices, payment references, accounting/audit evidence and tax records.
7. **Operations Control Tower:** shipment/exception views, communications, incident and audit activity; least-privilege access is essential.
8. **Enterprise:** organization users, linked customer entities, shipment and reporting data; export authority must distinguish personal data from tenant business records and third-party personal data.
9. **Admin:** privileged access and security/audit evidence; access to personal data should be purpose-limited, step-up authenticated and auditable.

A personal data request must not grant one workspace access to another organization's or another person's information merely because a user is an active organization member. Conversely, a verified individual request may need to find their personal information across multiple workspaces without disclosing other subjects' data. This requires a central subject identity map, tenant/role-aware resource resolver and redaction rules.

## 9. International processing and public-notice consistency

- The live Supabase project region is `ap-northeast-1` (Tokyo, Japan), not India.
- The privacy and interim retention notices disclose Tokyo and explicitly say cross-border processing/processor review remains to be completed. This is preferable to falsely claiming India-only residency.
- The privacy controls mock page claims AP-SOUTH-1 residency enforcement, contradicting the live project location.
- Public privacy copy currently makes broad references to GDPR/CCPA-style rights and nine workspace types while correctly warning that the notice is not a certification and applicable law/commencement must be assessed.
- Before public commercial rollout, obtain jurisdiction-specific legal review of KRIM's role (data fiduciary/controller/processor depending on activity), partner/customer controller relationships, data processing agreements, subprocessors, international transfers, security incident obligations, grievance contact and applicable Indian DPDP Act/Rules commencement.

No legal compliance certification is made by this technical audit.

## 10. Priority remediation register

### P0 — Fix before relying on privacy requests
1. Correct the account request UI mapping from hyphenated page IDs to the database's underscore enum values, or use a strict server-side mapping; add a test for all three request types. Do not test by inserting production requests.
2. Implement an owned request workflow with verified identity/authority, explicit status transitions, reviewer assignment, audit events, legal-hold review and completion evidence. Until then, keep the pages explicit that they are request intake only.
3. Remove/disable static UI claims for active retention, WORM, regional residency and 90-day purge unless backed by verified controls.

### P1 — Consent integrity and withdrawal
4. Reconcile migrations first, then remove ordinary authenticated direct DML on `krim_customer_consents`; use append-only, narrow, server-validated grant/withdraw event functions.
5. Verify the actual grant function privilege/caller path and implement withdrawal as a new event, not an overwrite.
6. Replace free-text policy versions with a server-maintained policy catalogue/version/hash and capture exact notice, purpose, actor, time, channel and evidence.
7. Separate terms/privacy acknowledgement, service-required data processing, optional marketing, analytics and personalization.
8. Wire marketing withdrawal to campaign suppression and channel preference enforcement; test queued message cancellation and retries.
9. Stop treating editable Auth user_metadata as authoritative proof of terms/consent. Record trusted evidence at the signup boundary.
10. Define minimal, legally reviewed consent/audit retention that can survive account deletion where justified.

### P1 — Export, retention and deletion
11. Implement personal-data export with ownership/authority verification, nine-workspace resource discovery, redaction, encrypted short-lived downloads, audit and cleanup.
12. Implement account deletion/deactivation as a staged, re-authenticated workflow: active sessions, memberships, linked organizations, shipments, assignments, claims, invoices/tax records, legal holds, Storage objects, processor copies, backups and retained audit evidence.
13. Define jurisdiction-specific retention schedule per data category and purpose; populate active policies only after legal review.
14. Implement scheduled archive/purge with dry-run mode, legal-hold exclusions, idempotency, immutable job evidence, failure alerts and restore/backup expiry handling.
15. Configure MIME/size limits and verify effective Storage policies for every private bucket, especially `pod-documents`.
16. Define secure signed-download expiry/revocation and object deletion behaviour.

### P2 — Governance and operations
17. Publish a verified privacy/grievance contact and staffed response process.
18. Document processors, sub-processors, data locations, transfer mechanism and contractual roles.
19. Add a privacy request dashboard with due dates, status, reasoned exceptions and independent reviewer.
20. Run staging-only adversarial tests across all nine workspaces and cross-tenant boundaries.

## 11. Required staging verification — not executed

1. A user can create a deletion/deactivation request and sees an accurate pending state; no request is marked completed without processor evidence.
2. Each request type maps to an allowed enum; invalid type is rejected with safe feedback.
3. Another user cannot read or alter a privacy request.
4. An enterprise admin cannot export personal data outside their authorized tenant relationship.
5. A user export includes all eligible personal data from all authorized workspaces while redacting other people's and other tenants' records.
6. Export archive is encrypted, signed, expires, can be revoked and is deleted after expiry/download according to policy.
7. Consent grant and withdrawal require a valid server-maintained policy version and produce immutable events.
8. A withdrawal suppresses future marketing sends and safely cancels eligible queued messages; required transactional notices remain governed separately.
9. Ordinary organization members cannot update/delete customer consent history.
10. Deletion workflow preserves records under documented legal holds and removes/anonymizes eligible records and files.
11. Storage object and metadata deletion are idempotent, retriable and auditable.
12. Backup retention, restore copies, processor copies and signed URL lifetimes are included in the completion report.
13. Retention job dry-run shows the exact categories/record counts without exposing record contents; actual purge only runs in isolated staging.
14. Cross-tenant and cross-workspace tests cover all nine user types.
15. Privacy request response and appeal are completed by an authorized, independent reviewer with due-date tracking.

## 12. Release decision and change boundary

**NO-GO for privacy lifecycle certification, automated data export, automated erasure, active retention enforcement or complete consent withdrawal.** The public privacy and interim retention notices are more transparent than the legacy mock product pages, but the technical service is incomplete and some account request actions are broken by a confirmed enum mismatch.

- No personal data values were read or exported.
- No consent/request records or Storage objects were created, modified or deleted.
- No Auth users or sessions were modified.
- No DDL, grants, RLS policies, Edge Functions, triggers or provider settings were changed.
- Production migration-history reconciliation remains a prerequisite for schema/function/grant/RLS remediation. Do not apply corrective SQL or replay migrations before that reconciliation.
- The audit is technical, not a legal opinion or certification under India's DPDP Act, GDPR, CCPA or other jurisdictional law.
