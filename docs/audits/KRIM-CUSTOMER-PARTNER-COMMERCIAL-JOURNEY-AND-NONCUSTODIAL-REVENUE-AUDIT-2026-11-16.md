# KRIM Customer–Partner Commercial Journey and Non-Custodial Revenue Audit — 2026-11-16

## 1. Scope and decision

Read-only review of public enquiry capture, customer acquisition and qualification records, partner registration and verification, partner sourcing/quotes, customer quote acceptance, assignment and revenue records, selected frontend pages, the live public-contact Edge Function and relevant database authorization.

**Decision: NO-GO for claiming a complete commercial operating journey or booking revenue.** The platform has several genuine components, including public enquiry capture, authenticated partner onboarding, verified-partner quote submission, leg-scoped quote award and customer quote listing. However, the production data and revenue records do not demonstrate a complete real customer-to-partner transaction. The non-custodial referral-fee model is not yet represented by a complete contract, attribution, invoice and collection lifecycle.

No customer/partner records were created, no quote or assignment RPC was executed, no payments or notifications were sent, and no production database changes were made.

## 2. Live production evidence (aggregate counts)

| Stage / object | Live count | What this proves |
|---|---:|---|
| Public contact enquiries | 0 | No live inbound enquiry is recorded in this table. |
| Customer acquisition profiles | 0 | No persisted customer acquisition pipeline record. |
| Customer qualification cases | 0 | No qualified demand record. |
| Customer service requests | 0 | No enquiry-to-service-request conversion. |
| Customer accounts | 0 | No activated customer account in the dedicated account table. |
| Customer consent records | 0 | The canonical consent table has no records; see public form consent evidence below. |
| Partner discovery profiles | 0 | No discovery prospect has been converted to a partner discovery profile. |
| Partner onboarding checklist items | 0 | No persisted checklist evidence. |
| Partner verification cases | 1 | One verification case exists; this does not establish approval or active capability. |
| Partner compliance reviews | 0 | No persisted current compliance review. |
| Active, verified partner capabilities | 0 | No production capability currently qualifies for real partner quote execution. |
| Partner opportunities | 3 | Three sourcing opportunities exist; statuses require operational review before any use. |
| Partner quotes | 0 | No provider price offer is recorded. |
| Partner assignments | 0 | No accepted or offered partner assignment is recorded. |
| Quote acceptances | 0 | No recorded customer quote acceptance. |
| Customer invoices | 0 | No invoice-based commercial revenue evidence. |
| Service contracts | 0 | No active customer/partner service contract evidence. |
| Customer referral records | 0 | No recorded referral attribution. |
| Revenue allocation rules / runs / allocations | 0 / 0 / 0 | No configured or executed revenue allocation policy. |
| Shipment revenue items | 0 | No shipment-level revenue item has been recorded. |
| Legacy `revenue_ledger` rows | 1 | A legacy ledger row exists, but it is not proof of current non-custodial referral revenue or collected KRIM income. |

Counts are point-in-time production evidence, not evidence of historical completeness or successful end-to-end tests.

## 3. Customer acquisition and enquiry path

### 3.1 Public contact page and Edge Function

The current root `contact.html` posts to the deployed `krim-public-contact-inquiry` Edge Function. The live function is ACTIVE (version 20) and `verify_jwt=false`, appropriate for a public contact endpoint because it performs server-side validation and uses a service-role client internally. The service-role key is not in the browser code.

Positive controls observed:
- CORS preflight and POST-only handling.
- Request-size limit, field validation, required privacy-consent boolean and honeypot.
- Per-email hourly throttling in the database RPC.
- IP throttling using the edge-provided Cloudflare client IP when present; caller-supplied forwarded IP is not trusted.
- Public table access is denied by RLS; the browser uses the Edge Function rather than direct table writes.
- Inquiry/profile/qualification/event/outbox creation is implemented in a privileged database function.
- Customer-facing response explicitly says this is an enquiry receipt, not a quote or booking.
- Telegram provider rejection/network errors are recorded as failed/queued-for-retry rather than falsely reported as a successful message.

Important gaps:
1. The contact form includes an enquiry type, phone, country/region, shipment reference and marketing attribution inside the message body, but the database RPC persists the message as a single text field. These fields are not first-class structured qualification attributes.
2. The Edge Function attempts to link the saved enquiry to a general customer service request, but logs and tolerates a linkage failure and still returns enquiry success. Thus a successful enquiry receipt does not prove the customer service request exists.
3. The database RPC records consent evidence in the inquiry and acquisition profile metadata, but the canonical `krim_customer_consents` table remains empty. This is not a substitute for a versioned, independently queryable consent ledger with withdrawal and purpose-specific consent.
4. The public form is rate-limited by email and, when available, Cloudflare IP. There is no proof of abuse, duplicate, retry or outbox-recovery testing against the live endpoint.
5. The live Edge Function and DB workflow have not been exercised with a real test enquiry in this audit. No test submission was sent.

### 3.2 Customer account creation

The customer signup page uses Supabase Auth, asks the user to accept Terms and Privacy Policy, and provisions an organization through `krim_provision_customer_organization` when a session is available. If email confirmation is required, it tells the user to confirm and continue later.

Earlier customer-protection review found the signup callback may provision an active organization membership/owner role before a separately evidenced canonical consent and MFA completion. This audit did not re-execute signup. **Required correction:** keep identity creation, legal consent, organization activation, customer qualification and commercial booking as separate states. Email verification or a checkbox must not by itself mean the customer is commercially approved or that an order exists.

## 4. Partner acquisition and verification path

### 4.1 Registration and onboarding

The partner signup page provisions a partner organization and sets a selected account mode. The canonical partner onboarding page:
- loads active country catalogue data;
- supports multiple operational categories and category-specific country/region/city coverage;
- uploads supporting documents to the private `krim-partner-verification` bucket;
- sets registered-business mode before invoking `krim_submit_partner_onboarding_global_multi_v1`;
- calls the authenticated server-side onboarding RPC.

The current multi-category onboarding RPC requires an authenticated user, matching active registered-business organization membership, valid service category and coverage data, active country catalogue entries and user-owned registration document paths. This is a useful foundation.

However, onboarding is not partner activation. Verification, compliance review, capability approval and corridor eligibility are separate gates. Current production has one verification case, no current compliance reviews and zero active verified capabilities. There is no evidence that a partner can currently be shown as bookable.

### 4.2 Partner quote submission

The deployed database function `krim_submit_leg_partner_quote` is executable by authenticated users and checks for an authenticated user, positive finite amount, valid currency code, bounded notes, an active registered-business partner organization membership, verified partner status/lifecycle/compliance and at least one active verified capability. The newer path is leg-scoped and stores the quote against an opportunity and exact shipment leg.

The older shipment-wide `krim_submit_partner_quote` function also exists. The coexistence of legacy shipment-wide and newer leg-specific sourcing paths requires an explicit deprecation decision and UI/RPC call audit. Do not assume all old pages use the new path.

### 4.3 Customer award and acceptance

The leg-scoped `krim_award_leg_partner_quote` function checks:
- customer organization access and `quote.update` plus `shipment.update`;
- open opportunity and unexpired response deadline;
- submitted/under-review/shortlisted and unexpired partner quote;
- exact opportunity, shipment and leg match;
- active registered-business verified partner and current compliance;
- exact-leg capability and plan-item matching;
- no duplicate active assignment for that leg.

This is a stronger commercial award control than merely changing a quote status. However, the previous lifecycle audit identified a legacy customer quote acceptance path with a weaker provider-assignment binding. The old and new quote acceptance routes must be reconciled so every customer acceptance is bound to the exact partner quote, assignment and terms snapshot. Do not allow a legacy acceptance endpoint to create a customer commitment without a matching provider award.

No partner quote, quote acceptance or assignment records exist in the current production evidence, so the complete path remains unproven.

## 5. Critical revenue-model mismatch

KRIM's approved lean launch model is **non-custodial referral/coordination**:
- customer contracts with and pays the logistics provider directly for freight;
- KRIM separately contracts for and invoices its own actual referral/coordination service fee;
- KRIM does not collect, hold, pool, split, settle or pay out freight funds;
- partner freight GMV and partner freight collections are not KRIM revenue.

The current production schema still contains legacy marketplace/payment concepts:
- `revenue_ledger` with `total_amount`, `platform_commission` and `partner_payout`;
- legacy partner payout and shipment financial records;
- revenue allocation rules/runs/allocations and delivered-revenue recognition functions;
- payment and payout workflows/Edge Functions already deployed.

The new revenue allocation rules, runs, allocations, service contracts, customer referral rows and shipment revenue items currently have zero rows. A delivered-revenue recognition function works from customer freight invoices and allocation policy; that is not the approved non-custodial KRIM referral-fee model.

**Do not activate the old platform commission, freight revenue allocation, payment split, partner payable or payout workflow for the lean launch.** These would contradict the intended operating model unless separately redesigned, legally reviewed and explicitly authorized.

### Required non-custodial revenue ledger

Build a separate auditable KRIM fee lifecycle, independent of partner freight settlement:

1. Signed partner referral/coordination agreement, with counterparty, scope, jurisdiction, fee basis, currency, tax responsibility, effective dates, termination and dispute terms.
2. Customer/partner referral attribution with immutable source, first-touch/last-touch rules, consent basis and conflict handling.
3. Evidence that KRIM actually performed the contracted introduction/coordination service.
4. Clear fee calculation: fixed referral fee or percentage of a defined and evidenced base; never silently treat provider freight value as KRIM revenue.
5. Approval and invoice issued by KRIM for KRIM's own service only, with correct legal entity, tax treatment and applicable GST review.
6. Customer/partner pays the KRIM invoice directly to KRIM through an approved method; store provider transaction reference and reconcile actual collection.
7. Credit note, cancellation, refund, bad debt and dispute paths for KRIM's own fee invoice.
8. Revenue recognition only under the applicable accounting policy after the service and recognition criteria are met.
9. Audit trail, access segregation, export and monthly reconciliation.
10. Explicitly no freight-fund custody, partner payout or payment split in the initial model.

GST treatment is not automatically exempt; obtain qualified CA advice before charging fees or issuing invoices.

## 6. Misleading acquisition interface found

`public/growth/customer-conversion.html` contains hard-coded performance figures (including 1,420 enquiries, 1,380 quotes and 42.8% conversion) and a button that displays a simulated successful serviceability match through a JavaScript alert. These are not live database-backed metrics and must not be presented as actual KRIM performance.

The separate `public/growth/customer-acquisition.html` page describes measured acquisition and uses database counts, which is directionally safer. The conversion page should be replaced with database-backed, empty-state metrics or clearly marked demonstration data, with no simulated verified partner/serviceability claim.

## 7. P0/P1 findings

### P0 — no evidence of live partner supply
Zero active verified capabilities, zero compliance reviews and zero partner quotes. The network cannot be marketed as bookable or serviceable until actual partners, evidence and corridor eligibility are approved.

### P0 — commercial revenue model is not implemented
No signed service contracts, referral records, fee rules, fee invoices or collected KRIM fee records. The existing freight commission/payout model must remain disabled for the non-custodial launch.

### P0 — public enquiry success is not equivalent to a complete lead record
The Edge Function may return success even if linking the enquiry to the customer service-request qualification engine fails. Add a durable retry/reconciliation queue and expose linkage status internally; do not lose the enquiry or tell the user a quote/booking exists.

### P0 — misleading simulated growth metrics
Remove or clearly label hard-coded customer conversion counts and the simulated serviceability success button. No public or internal growth dashboard should display invented activity as production evidence.

### P1 — canonical consent lifecycle incomplete
Persist purpose, notice version, affirmative action, timestamp, source, identity/anonymous reference, withdrawal and evidence in the canonical consent ledger. Distinguish service-request consent from marketing consent.

### P1 — duplicate legacy and current commercial paths
Reconcile shipment-wide and leg-specific quote/award/acceptance functions and all front-end callers. Disable obsolete routes only after migration lineage and dependencies are reconciled.

### P1 — no end-to-end operational proof
No live enquiry, qualified customer, verified capability, partner quote, acceptance, assignment or fee collection has been demonstrated. Run synthetic tests in a staging project before production.

## 8. Staging acceptance test plan

1. Submit one valid public enquiry; verify exactly one inquiry, acquisition profile, qualification case, event and outbox record.
2. Submit duplicate and rate-limited enquiries; verify idempotency/duplicate policy and safe customer messages.
3. Exercise honeypot, malformed email, oversized payload, missing consent and hostile source-page input.
4. Force service-request linkage failure; confirm enquiry remains visible and retryable until linked.
5. Test Telegram success, provider rejection, timeout, duplicate retry and outbox reconciliation without leaking PII to logs.
6. Register a partner in development/individual mode; verify it cannot submit commercial quotes or become bookable.
7. Register a real-business test partner; verify ownership and privacy of uploaded documents.
8. Reject incomplete, expired, mismatched or fraudulent partner evidence; confirm no capability activation.
9. Approve synthetic partner evidence with independent reviewer and AAL2; confirm only approved exact-country/mode capabilities become eligible.
10. Create a customer shipment in an activated, legally cleared test corridor; create exact-leg partner opportunity.
11. Submit partner quote; test cross-organization quote visibility and exact-leg isolation.
12. Award one quote; verify idempotency, single active assignment, correct partner and customer organization, terms snapshot and audit events.
13. Accept customer quote only against the same partner quote, terms version and assignment.
14. Verify customer and partner are told that freight contract/payment is directly between them; no KRIM freight custody or settlement occurs.
15. Generate a KRIM fee only from an active agreement and evidenced referral/coordination service; verify invoice, tax fields, collection and reconciliation.
16. Verify no revenue is recorded from gross freight value or uncollected partner freight.
17. Test fee dispute, credit note, cancellation, bad debt, and duplicate invoice/payment events.
18. Verify all dashboards display actual counts and explicit empty states, never hard-coded success figures.

## 9. Safe implementation order

1. Resolve migration lineage/schema-manifest blocker; do not change production grants, policies, triggers or migrations until reconciled.
2. Remove/label simulated acquisition performance and serviceability claims.
3. Make enquiry-to-service-request linkage durable and observable; complete canonical consent records.
4. Choose one canonical partner onboarding, quote, award and customer acceptance path; deprecate legacy paths after dependency review.
5. Implement the non-custodial referral/coordination agreement and fee ledger as a separate commercial subsystem.
6. Obtain CA/legal review of fee, invoice, GST and contract treatment.
7. Recruit and verify actual operating partners and capabilities; approve routes/corridors before claiming serviceability.
8. Run full synthetic staging journey and negative tests.
9. Run a tightly controlled, explicitly authorized real-world pilot; reconcile every fee and customer/partner outcome.

## 10. Verification boundary

Reviewed production aggregates, table grants/RLS policies, selected database function definitions and privileges, Edge Function deployment metadata/source, and relevant GitHub pages. No production records or schema were changed. No real enquiry was submitted, no Telegram message was sent, no quote was created or accepted, no partner was verified, no shipment was booked, and no payment was initiated.

This is a commercial journey audit, not a legal/tax opinion, security certification or proof that all deployed pages and RPC dependencies have been exhaustively reviewed.
