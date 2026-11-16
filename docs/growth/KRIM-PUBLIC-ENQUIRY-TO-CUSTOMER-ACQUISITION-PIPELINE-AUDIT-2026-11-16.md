# KRIM Public Enquiry → Customer Acquisition Pipeline Audit
**Date:** 16 November 2026  
**Scope:** Read-only production review of the public contact endpoint, website contact form, inquiry submission RPC, acquisition profile/qualification records, customer service-request linkage, partner opportunity and matching hand-off, privacy controls, and founder notification enqueue path.

## Executive decision
**The intake foundation exists, but the end-to-end acquisition funnel is not production-verified. No live enquiries or customer conversion records exist in the inspected production tables. Several workflow and access-control gaps should be fixed before relying on this as the primary sales funnel.**

No test enquiry was submitted, no customer data was created, no notifications were sent, and no production records or schema were changed.

## 1. Production evidence

| Funnel stage | Table | Rows |
|---|---|---:|
| Public enquiry intake | krim_public_contact_inquiries | 0 |
| Customer accounts | krim_customer_accounts | 0 |
| Acquisition profiles | krim_customer_acquisition_profiles | 0 |
| Acquisition events | krim_customer_acquisition_events | 0 |
| Qualification cases | krim_customer_qualification_cases | 0 |
| Customer service requests | krim_customer_service_requests | 0 |
| Inquiry follow-ups | krim_inquiry_followups | 0 |
| Customer referrals | krim_customer_referrals | 0 |
| Customer consent ledger | krim_customer_consents | 0 |
| Partner opportunities | krim_partner_opportunities | 3 |
| Partner verification cases | krim_partner_verification_cases | 1 |
| Partner capability records | krim_partner_capabilities | 1 |
| Partner match runs/results | krim_partner_match_runs / krim_partner_match_results | 0 / 0 |
| Partner quotes | krim_partner_quotes | 0 |
| Shipment partner assignments | krim_shipment_partner_assignments | 0 |

The 3 partner opportunities are historical records; they do not represent qualified customer leads or available partner capacity. Prior audits identify them as expired/cancelled. No verified operational partner, match result, quote or assignment is evidenced by this funnel snapshot.

## 2. Public contact page and intake endpoint
The root `contact.html` page has a public enquiry form with:
- Enquiry category covering shipper, partner, enterprise, subscription, driver, warehouse, customs, finance, operations and privacy questions.
- Name and email, optional organisation/phone/country/reference, and a message.
- Required privacy-consent checkbox and privacy-notice link.
- Hidden honeypot field.
- UTM/referrer/landing-page attribution embedded into the message.
- Explicit receipt disclaimer: an enquiry is not a booking, quote, ticket, partner approval, or route confirmation.

The page posts to the deployed `krim-public-contact-inquiry` Edge Function. Production reports it ACTIVE at version 20 with JWT verification disabled; this is a public endpoint and relies on its own validation and rate limiting.

The endpoint:
1. Accepts POST only and rejects declared bodies over 9 KB.
2. Requires JSON object and `privacy_consent === true`.
3. Returns a generic success for a filled honeypot without creating a record.
4. Validates name, email, organisation and message.
5. Uses the Cloudflare-provided `cf-connecting-ip` header for an IP throttle; it does not trust caller-supplied `X-Forwarded-For`.
6. Calls the service-role-only database submission RPC.
7. Attempts to link the inquiry to a customer service request and qualification workflow.
8. Attempts immediate founder Telegram notification; provider failure is recorded for scheduled retry.
9. Returns an enquiry receipt/reference, not a quote or booking.

The endpoint has permissive CORS (`*`). Since this is a public form endpoint, that is not by itself a security vulnerability, but rate limits, abuse controls and response minimisation remain important.

## 3. Positive controls
- Raw `krim_public_contact_inquiries` has RLS enabled with an explicit deny policy for anon and authenticated clients.
- Submission RPC and IP-limit RPC are executable only by postgres/service_role in the inspected grants; anon/authenticated have no direct execute grant.
- Service-role credentials are read from Edge Function environment variables, not sent to the browser.
- IPs are SHA-256 hashed before storage in the private rate-limit table; old windows are pruned after 24 hours.
- IP throttle: more than 10 requests per 10-minute window is limited.
- Email throttle: 3 submissions per email per rolling hour, guarded by an advisory transaction lock.
- Input length and basic email syntax are checked at both edge and database layers.
- Honeypot and privacy-consent checks exist.
- Partner opportunity visibility is scoped to customer org, awarded partner org, verified eligible partners with capability coverage, and platform admins.
- The contact page carefully avoids promising partner coverage or automatic booking.

## 4. Critical workflow findings

### P0-A — Customer acquisition profiles are created without an organisation binding
The submission RPC inserts acquisition profiles without `organization_id`, so it remains NULL. The authenticated RLS policy on `krim_customer_acquisition_profiles` only allows rows for which `private.krim_has_organization_access(auth.uid(), organization_id)` is true. That helper requires an active membership for the exact organisation ID. A NULL organisation ID cannot satisfy that membership lookup.

**Impact:** ordinary authenticated admin/customer-acquisition screens using direct table SELECT cannot read these newly created public prospect profiles. A dedicated tightly scoped platform-admin RPC or a safe prospect-owner/org binding is needed. Do not fix this by broadening RLS or exposing prospect PII to all authenticated users.

The public inquiry table itself is also deny-by-default for authenticated users. The inspected public RPC catalogue contains no obvious admin inquiry-list/read function. Confirm the actual admin dashboard read path (for example, a separately authorised Edge Function) before claiming that founders can reliably work the enquiry queue.

### P0-B — Qualification may create duplicate cases for a single enquiry
The public submission RPC creates an initial `krim_customer_qualification_cases` row marked `pending`, with missing information. After the RPC commits, the Edge Function calls `krim_internal_link_public_inquiry_to_service_request`. That function creates a service request and calls `krim_internal_qualify_customer_request`, which inserts another qualification case and links that second case to the service request.

**Impact:** a successful public enquiry can create two qualification case records: an initial standalone pending case and a second service-request-linked case. The first may become orphaned from the service request and confuse pipeline counts, founder review queues and qualification reporting. No live rows exist to confirm the observed outcome; the duplicate creation is directly implied by the current function definitions.

**Required correction:** establish one canonical qualification case per inquiry/request. Either defer qualification-case creation until service-request linkage, or change the linkage function to reuse/update the existing case rather than insert another. Add a unique source/request relationship and staging tests before changing production.

### P0-C — Intake succeeds even if service-request linkage fails
The Edge Function logs a linkage error but still returns a successful enquiry receipt. That is reasonable for preserving an already-saved enquiry, but there is no inspected durable retry/reconciliation record for the failed linkage.

**Impact:** a lead may be saved while missing its service request/qualification workflow, with only an Edge Function log indicating failure. Add a durable linkage status, retry queue or scheduled reconciliation report. Never discard or reject the original saved enquiry because a downstream stage failed.

### P1-A — Consent evidence is not normalised in the consent ledger
The edge endpoint requires the checkbox to be true. The database RPC then unconditionally writes `privacy_consent=true`, timestamp and a fixed notice version `2026-11-11`; it also copies consent status into profile/event metadata. However, `krim_customer_consents` remains empty in production and the submission function does not insert a row there.

**Impact:** there is no row-level consent record in the dedicated consent ledger for these submissions. The inquiry row and metadata do provide evidence fields, but the consent ledger is not the source of record. Add an immutable consent evidence event/ledger entry with notice version, purpose, timestamp, source and withdrawal handling after the data model and migration history are reconciled. Do not record consent for any channel or purpose beyond the actual form statement.

### P1-B — IP throttling depends on an edge-provided IP header
If `cf-connecting-ip` is absent, the Edge Function skips IP throttling. Email-based throttling still applies. Verify this header is present in production requests and add a safe fallback or reject/limit requests when the trusted client IP cannot be established. Never trust arbitrary forwarded-IP headers.

### P1-C — Attribution is stored inside free-text message
UTM source/medium/campaign/content, referrer and landing page are appended to the customer message. This makes attribution difficult to report consistently and may mix untrusted metadata with user-supplied content.

**Required correction:** store structured attribution fields with allowlisted lengths and safe URL handling. Keep user message content separate. Ensure no script/HTML rendering of the text.

### P1-D — Category, phone, country and reference are not first-class intake fields
The page embeds enquiry type, phone, country and reference into the message body; the database stores only name, email, organisation, message and source page. This makes routing and funnel analytics dependent on parsing free text. The current database RPC requires an organisation of at least two characters, so the frontend substitutes “Individual customer” when the field is blank. That is a workaround, not a durable customer-type model.

**Required correction:** add typed, validated fields in a forward-only migration after schema recovery, including prospect type, contact phone, country/region, shipment reference and attribution. Keep fields optional where appropriate and don't force an individual to impersonate an organisation.

### P1-E — Direct notification and retry paths need one state machine
The Edge Function sends Telegram immediately after creating a pending outbox row, then updates the same row to sent or failed. A scheduled worker retries failed records. This can work, but a provider acceptance followed by a timeout or database status-update failure can result in a retry and duplicate alert. The worker and immediate sender need a shared atomic claim/lease/idempotency protocol. Telegram sendMessage does not provide a general idempotency key.

### P2 — Funnel stages are not yet evidenced
The current pipeline can capture and qualify a general enquiry, but no production evidence exists for:
- A founder/admin prospect queue with reliable visibility and ownership.
- Lead assignment, qualification decision, response SLA and contact attempt history.
- Consent-aware email/WhatsApp/Telegram follow-up.
- Customer profile conversion and organisation binding.
- Verified partner matching, quote issuance and customer acceptance.
- Referral attribution, signed fee agreement, proof of service, KRIM invoice and fee receipt.
- Funnel conversion metrics, source attribution, lost reason and repeat booking.

Do not count an inquiry as a customer, a customer profile as a booking, a partner opportunity as partner availability, or shipment GMV as KRIM revenue.

## 5. Partner matching and commercial boundary
The downstream matching tables are empty and there is no verified partner capacity evidenced by the current data. A general enquiry must not trigger automatic matching or promise service. Shipment-specific requests should proceed only after complete origin/destination, mode, cargo, date and operational requirements are collected, then be checked against current verified partner capability and capacity.

For KRIM's initial partner-direct model, the customer contracts with and pays the logistics provider directly. KRIM's referral/coordination fee must be separately agreed and earned for a real service. Do not route freight payments through KRIM or enable automatic partner payout/settlement.

## 6. Staging acceptance tests
1. Valid enquiry with consent: one enquiry, one acquisition profile, one canonical qualification case, one event, one outbox row, and one stable reference.
2. Missing/false consent: rejected and no record created.
3. Honeypot populated: generic success but no database writes.
4. Same email four times within an hour: first three allowed, fourth rate-limited.
5. More than ten requests from one trusted IP in ten minutes: rate-limited; absent/untrusted IP tested explicitly.
6. Invalid email, oversize payload, short/long fields and malformed JSON: rejected safely.
7. Duplicate submission/retry after client timeout: idempotent receipt or clearly documented duplicate handling.
8. Service-request linkage transient failure: enquiry remains saved, durable retry is recorded, reconciliation repairs it exactly once.
9. Qualification: exactly one canonical case per inquiry; no orphan duplicate.
10. Admin prospect queue: authorised platform admin can read the inquiry and profile; other tenants and unauthenticated clients cannot.
11. Null-org prospect profile: no accidental broad RLS access; explicit admin path is tested.
12. Consent ledger: exact notice version, purpose and timestamp are retained; withdrawal is represented without deleting audit evidence.
13. Attribution: UTM/referrer values are stored as structured data and cannot inject markup or overwrite user message.
14. Telegram provider timeout after accepting a message: no duplicate notification or duplicate is clearly surfaced as at-least-once.
15. Notification failure: customer receives an honest enquiry receipt while founder alert retries; no claim that notification was delivered.
16. Partner matching: no unverified or out-of-area partner appears; no quote is sent without partner-confirmed price and capacity.
17. Commercial conversion: signed fee terms and evidence of completed referral service are required before KRIM revenue is recognised.

## 7. Scope and limitations
Read-only production counts, schema, RLS policies, grants, function definitions and deployed Edge Function source were inspected. The root contact page and checked-in Edge Function source were reviewed. No enquiry was submitted; no provider message was sent; no real customer/partner contact was made; no production mutation or DDL was executed. No staging tests or founder dashboard browser session was performed. The deployed Edge Function's source parity with the repository still needs explicit verification; its production version is 20.

The migration-history reconciliation blocker remains in force. Do not add/replay migrations or modify production tables/functions until the canonical schema/migration source has been recovered and reconciled.

**Decision:** public intake is implemented with meaningful validation, privacy checkbox, anti-abuse controls and founder alerting; however, acquisition profile visibility, duplicate qualification, linkage recovery and consent-ledger completeness prevent marking the customer acquisition funnel production-ready.
