# KRIM SaaS Trial Request — Implementation Gap Audit
Date: 11 November 2026
Repository: rimjhimkrn-web/logistics-saas
Status: read-only code review; no production database or customer data changed.

## Executive finding
KRIM has a public-facing early-access enquiry path, but it does not yet have an operational SaaS trial-request system. The distinction must remain explicit in product copy and admin operations.

## What is implemented
- `plans.html` describes an invitation-only, guided 30-day evaluation, with no card collection and no automatic paid conversion.
- The evaluation CTA routes to `contact.html?type=software-evaluation`.
- The contact form classifies the request as a software-evaluation enquiry and submits it through the existing public-contact workflow.
- `admin-saas-pilots.html` filters those contact enquiries and supports authorised admin status updates and private follow-up notes.
- `global-admin-control` checks authenticated identity, AAL2 and active platform-admin/platform-superadmin role before processing its admin actions.
- Private follow-up actions use the existing `krim_inquiry_followups` table through the service-role Edge Function path; the browser does not receive direct table access.

## What is not implemented
- No dedicated SaaS trial-request record or request lifecycle exists.
- No authenticated organisation-scoped request endpoint exists.
- No server-side validation of organisation membership, plan version or one-trial eligibility exists.
- No dedicated admin queue for trial approvals/rejections exists.
- No production subscription or entitlement tables exist.
- No 30-day trial activation, expiry worker or entitlement enforcement is live.
- The current enquiry status values (new/in_review/responded/closed/spam) are contact-management statuses, not trial states.
- An enquiry marked "responded" or "converted" must never be interpreted as an approved or active trial.

## Safe current operating procedure
1. A business may submit a software-evaluation enquiry.
2. KRIM admin may review and contact the business using the existing protected enquiry workflow.
3. KRIM must separately confirm feature readiness, evaluation scope, dates and access method in writing.
4. Do not promise an active 30-day entitlement or grant software access based solely on enquiry status.
5. Do not collect a payment card or automatically convert an evaluation to paid.

## Implementation blockers
1. Reconcile production migration history (425 entries) against repository SQL migrations (263 files) at SQL-body/hash level. Filename suffix similarity is not proof of equivalence.
2. Establish a disposable/staging database and verify its schema baseline.
3. Finalise the dedicated SaaS data model, including request idempotency, one-live-subscription constraints, immutable audit records and explicit API exposure/grants.
4. Implement a dedicated server-side `krim-saas-control` Edge Function with organisation membership checks and AAL2 platform-admin decisions.
5. Add the admin approval queue and customer-facing request status view.
6. Run the security test matrix, including cross-organisation, revoked-membership, duplicate/concurrent request, self-approval, replay and expiry tests.
7. Only then consider a controlled pilot. Paid billing remains separately gated by legal/tax and provider approval.

## Release decision
**Not ready to activate real SaaS trials.** The existing contact enquiry path is ready for collecting interest, but it is not a trial engine. Keep SaaS checkout disabled and do not represent any enquiry as an approved evaluation.
