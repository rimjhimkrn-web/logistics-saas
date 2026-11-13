# Step 43 — India pilot launch blocker register and execution order

Date: 2026-11-13
Scope: consolidate the completed website, security, database, payment-model and partner-workflow audits into a practical launch gate. This is a decision register, not a claim of launch approval.

## Decision

KRIM is **not yet ready for an open public commercial launch**. The safest next target is a tightly controlled India pilot using the partner-direct model, after the minimum gates below are satisfied. Do not wait for worldwide certifications or a full global rollout to validate the business, but do not bypass partner, tax, legal, payment or security gates.

## Critical launch gates (must close before accepting a real shipment)

1. **Partner provisioning and approval — BLOCKED**
   - Partner signup creates a user account but not a verified partner organization/membership.
   - Current verification form expects an already-linked active partner organization.
   - No safe, documented organization-plus-membership provisioning action has been verified.
   - Required: implement or identify an MFA-gated, audited founder/admin provisioning workflow; create the first real partner only from its genuine application and documents; independently complete identity, compliance, capability and service-area reviews. Never use manual SQL or test identities to bypass this.

2. **One real operating partner and one real supported lane — NOT PROVEN**
   - Production has no verified active partner capability or accepted assignment in the earlier audited counts.
   - Required: verify actual service, geography, capacity, authority, insurance/liability where applicable, contact and response SLA. Publish only the approved capability and service area. Do not advertise unverified routes or rates.

3. **Legal, tax and commercial disclosures — BLOCKED**
   - Confirm the exact proprietor/operator identity, principal business address, customer-care contact and grievance contact/appointment for publication.
   - Obtain CA advice on the chosen partner-direct referral/coordination fee model, GST applicability, invoicing and any e-commerce/intermediary obligations before charging fees. Partner-direct freight payment does not itself establish a GST exemption.
   - Publish accurate terms, privacy, cancellation/refund, partner responsibility, dispute and grievance disclosures. Do not show a GSTIN or charge GST while unregistered.

4. **Customer-to-partner operational rehearsal — NOT TESTED**
   - Run one authorized end-to-end test with the real partner: customer enquiry → partner quote → customer acceptance/contract with partner → partner-direct payment outside KRIM → confirmation → status updates → proof of delivery/complaint handling → KRIM's separately agreed fee record.
   - Test rejection, expiry, cancellation, duplicate submissions, unavailable route, partner non-response, evidence access, cross-organization access and support escalation.
   - No fake quotes, invented tracking, live freight checkout or unverified claims.

5. **Public website release and support readiness — PARTIAL**
   - PR #65 remains draft, open, unmerged and undeployed.
   - Static CI successes do not equal mobile, browser, form-delivery or production journey certification.
   - Verify all public legal/contact pages and live links; verify enquiry notifications reach the founder; provide a staffed support path and response commitment before promotion.
   - Confirm the deployed site is the intended GitHub Pages URL and that the changes in PR #65 are reviewed before merge/deploy.

## Important but not a reason to block a small partner-direct pilot indefinitely

6. **Migration history / staging reconstruction — HIGH RISK TECHNICAL DEBT**
   - Production has 425 applied migrations; staging has 0; current branch has 265 migration files, with major history drift and duplicate version IDs.
   - No production schema changes should be made until the canonical history is recovered or a separately designed, reviewed baseline-reconstruction process is approved.
   - This blocks safe future schema releases, not necessarily a no-schema-change pilot using already deployed and audited workflows. Keep the pilot limited and avoid DDL/Edge Function changes.

7. **Encrypted schema export — NOT EXECUTED**
   - Confirm required GitHub Actions secrets and run the manual schema export only after verifying the exact production source and artifact destination. Confirm checksum and securely retain passphrase/export. It is not a full Supabase project backup.

8. **Payments and withdrawals — PARTNER-DIRECT ONLY**
   - Keep KRIM freight checkout disabled. Customers pay their contracted logistics partner directly.
   - Do not promise KRIM payment acceptance or withdrawals until the selected provider's business eligibility, account/KYC, bank settlement and a real test settlement are confirmed.
   - KRIM's own referral/coordination fee collection method and tax treatment must be separately approved before collection.

## Fastest safe sequence from here

A. Resolve the first partner's provisioning route using an existing audited admin function/UI or build a properly gated workflow after source review.
B. Onboard one genuine partner and complete independent reviews for one actual service/lane.
C. Finalize CA-reviewed fee/tax treatment and public operator/contact/grievance disclosures.
D. Rehearse the full partner-direct journey with explicit partner/customer authorization and record every pass/fail.
E. Verify founder alerts/support, mobile usability, legal pages and public-site release checklist.
F. Only then authorize merge/deploy and a limited invitation-only pilot. Expand only after real service performance is measured.

## Current launch verdict

**Status: PRE-LAUNCH / CONTROLLED PILOT NOT YET CLEARED.**

The immediate critical path is partner provisioning → verified real partner/lane → legal/tax/contact readiness → one complete authorized rehearsal. Do not spend time adding more speculative global features while these gates remain open.

## Safety boundaries

No production records, schemas, functions, secrets, payment settings, partner approvals, merges or deployments were changed in this consolidation. This report summarizes prior audits and identifies work that requires owner/partner/CA action or separately approved implementation.
