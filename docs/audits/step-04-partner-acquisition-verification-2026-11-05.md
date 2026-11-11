# KRIM Step 4 — Partner Acquisition & Verification Audit
**Review date:** 5 November 2026  
**Scope:** Global partner acquisition foundations, application admission, organisation verification, service capability review, commercial activation boundaries.

## Implemented and verified
- Created a single global partner-network admission page with India-first operational positioning and country-aware future expansion.
- The page explains eligible partner categories: transport/carriers, freight forwarders, warehouses/fulfilment, customs and specialist services.
- Admission stages are explicit: application, identity/authority evidence, organisation review, capability review, then separate commercial/market activation gates.
- The existing partner application flow submits through `krim_submit_partner_onboarding_global_multi_v1`, uploads supporting documents to the private `krim-partner-verification` bucket and records a pending human review state. Submission is not treated as approval.
- Existing private administrator organisation-verification queue uses `krim_admin_list_partner_verification_cases` and audited decision RPC `krim_admin_review_partner_verification`; document previews use 60-second signed URLs.
- Existing private administrator capability queue uses `krim_admin_list_partner_capabilities` and audited decision RPC `krim_admin_review_partner_capability`.
- Both review interfaces require a signed-in platform administrator and MFA through the global admin control gateway; database RPCs also enforce AAL2 and platform permission.
- Admin navigation already links both verification and capability review.
- The capability approval RPC requires a registered-business organisation that is active, lifecycle-active, verified and compliant before a capability can be approved.
- Existing system rules prevent development/test partner pathways from receiving commercial quotes or awards.
- Removed misleading static prospect/outreach/activation dashboards that displayed invented organisations, fabricated scores, outreach metrics, serviceable PIN counts and false verification/activation claims. All three legacy routes now redirect to the truthful partner-network page.

## Current production snapshot
- Partner verification cases: 1 open.
- Partner capabilities: 1 pending.
- Partner opportunities: 1 open, 2 cancelled.
- Growth-opportunity prospect records: 0.
- No verified active partner capability was established by this audit.
- No partner was approved, activated, contacted or represented as having accepted a commercial agreement by this work.

## Pages
- Partner network admission: `public/growth/partner-network.html`.
- Applicant onboarding: `public/partner/partner-onboarding.html`.
- Private organisation verification: `app/platform-admin/partner-verification.html`.
- Private capability review: `app/platform-admin/partner-capabilities.html`.

## Acceptance boundary
The acquisition and verification workflow foundation is implemented, and misleading prospect dashboards have been retired. The actual network has not yet been acquired: the live queue contains one open verification case and one pending capability, with zero verified active capabilities. A real partner can only be marked verified after genuine documents are reviewed and an authorised administrator records the decision. Commercial activation still depends on eligible market gates, valid capabilities, genuine cost evidence, tax review and approval. No invented partner, document, service coverage, contact or verification outcome was added.


## Partner prospect research update — 5 November 2026
A source-backed India-first prospect register has been created at `docs/growth/partner-prospect-register-2026-11-05.md`.

Six priority organisations were identified through official company sources: Kiran Group (Ranchi), Deepak Roadlines (Ranchi), CJ Darcl Logistics (formal fleet-partner intake), Pranik Logistics (Eastern India), Patel Integrated Logistics (Ranchi branch), and Hyperlocal Delivery Partners / Delivery Partners (Ranchi branch). The register captures publicly published business contact channels, stated service fit, a proposed first-discussion angle, source links and an explicit uncontacted/unverified status. Lower-confidence local discovery leads are separated from priority leads.

No contact has been made, no web form submitted, no CRM lead created, no consent assumed and no partner status changed. Public directories and company marketing claims are treated as leads only, not evidence of licensing, fleet ownership, available capacity or compliance. Due diligence and authorised verification remain mandatory.


## Follow-up ecosystem accuracy check — 5 November 2026
- Re-inspected the live partner onboarding form, organisation verification queue, capability review queue, storage policies and corresponding production RPC definitions.
- Confirmed the verification and capability administrator list/review RPCs enforce AAL2 and `admin.platform`; anonymous EXECUTE is revoked; review functions lock the target row and write audit events.
- Confirmed the verification document bucket is private, capped at 10 MiB, and limited to PDF/JPEG/PNG. Applicant uploads are scoped to the active partner organisation and authenticated user; administrator reads require AAL2 and platform permission.
- Corrected an inaccurate onboarding helper message: country catalogue availability is not the same as market activation. The form now explicitly says a submitted country is proposed coverage only and that market, regulatory, partner and capacity approvals remain separate.
- Re-parsed the onboarding page inline JavaScript after the change. This is a source-level check, not a signed-in browser or upload E2E test.
- Production counts remain: 1 verification case, 1 partner capability, 3 partner opportunities, 0 growth prospect records. No records or approval states were changed.


## Legacy partner-page retirement — 5 November 2026
- Retired four stale routes that contained materially misleading or obsolete claims: an unregistered corporate legal-entity name, global regulator/certification requirements presented as universal, guaranteed freight loads, guaranteed 99.5% uptime, sub-minute telemetry commitments, binding rate filing and automated escrow settlement.
- `legal/partner-terms.html` and `public/legal/partner-terms.html` now preserve their URLs as noindex compatibility redirects to the current Partner Standards page, which expressly states it is a framework and not an executed contract.
- `public/partner/registration.html` and `public/partner/business-verification.html` now preserve their URLs as noindex compatibility redirects to the single current authenticated partner-onboarding flow.
- This removes conflicting duplicate admission and legal surfaces without creating new commercial commitments. No agreements were issued and no partner was contacted or activated.


## Handoff into Step 5 — 5 November 2026
- Step 4 digital foundations were rechecked: partner onboarding, verification, capability review, private document access, MFA and navigation. Step 4 remains an engineering foundation only; no real partner outreach, applicant approval, agreement execution or commercial activation was performed.
- Step 5 review identified that partner acceptance alone was previously sufficient to unlock customer checkout, even though the partner's separate schedule-and-reserve action could still be pending.
- The customer assignment page now keeps checkout locked until it can read a matching confirmed capacity binding. The Razorpay order Edge Function independently verifies the assignment, binding, and linked reservation against the same shipment, leg and partner before creating or reusing a payment order.
- Deployed `create-global-razorpay-order` version 15 with JWT verification still enabled. The deployed source contains the capacity-reservation gate. No payment order was created.
- Retired two misleading legacy matching routes: the static growth page that claimed an active/optimized engine and displayed a sample route, and the static carrier-assignment form with a fabricated shipment reference. They now redirect to the current authenticated operations/customer assignment workflows.
- Production currently contains 0 partner assignments, 0 capacity bindings and 0 capacity reservations. No positive commercial flow was fabricated or run. Source-level syntax and deployed-version checks passed; signed-in browser E2E remains pending.


## Digital ecosystem audit — follow-up 5 November 2026

The current scope is strictly technical readiness. No real partner outreach, application submission, approval, commercial activity or activation was performed.

### Verified backend controls
- Partner onboarding submission is authenticated and requires registered-business mode, an active matching partner organization, valid active country coverage for each selected service, and evidence paths under the signed-in user/organization folder. Submission creates a review case; it does not auto-approve the organization.
- Account-mode selection explicitly records `commercial_access=false`. Development/test mode records `sample_data_only=true` and `commercial_access=false`; the development workspace explains that no real customers, shipments, quotes, bids, assignments, invoices, payments, capacity commitments or payouts may be entered there.
- Partner quote submission is server-side restricted to an active registered-business organization with verified/approved organization status, active/verified lifecycle, acceptable compliance, active verified capability, route coverage and `quote.create` permission. The partner opportunities RLS policy independently exposes open tenders only to eligible verified organizations with a matching capability. Anonymous EXECUTE is denied.
- Capacity registration requires active membership and `partner.manage`, registered-business mode, active/verified/compliant organization, an individually verified capability for the selected mode and country, a valid future availability window and private supporting evidence. New resource records are created as `pending_review`; availability is initially `unavailable`.
- Driver invitations require verified, active, compliant registered-business transport partners with an approved transport capability. The driver remains subject to separate identity/licence review; invitation does not approve a driver or vehicle.
- Partner assignment acceptance, capacity reservation and driver assignment use authenticated, organization/permission-scoped RPCs. The driver assignment workflow requires an accepted partner assignment and a driver with active membership in the same partner organization.
- Platform verification and capability-review RPCs require authenticated AAL2 and `admin.platform`; review actions write audit events. Anonymous execution is denied.
- `krim-partner-verification` is private, 10 MB maximum, restricted to PDF/JPEG/PNG. Upload policy requires an active organization membership and a user-specific object path. Partner members can read only their own organization's objects; platform administrators require AAL2 for evidence reads.
- RLS is enabled on the audited partner opportunities, quotes, capabilities, verification cases, capacity resources/availability and shipment-partner-assignment tables. Partner-facing direct writes are not granted for these controlled records; privileged writes go through the reviewed RPCs.

### Production snapshot (read-only)
- Partner organization #14 is in `development_test` mode, with verification and compliance pending and lifecycle `verification_pending`.
- 1 partner verification case; 1 partner capability; 3 opportunities (1 open and 2 cancelled); 0 partner quotes; 0 partner assignments; 0 capacity resources; 0 capacity-availability rows; 0 driver invitations.
- No verified active commercial partner capability is currently available. The test organization is not eligible to see open opportunities or submit bids under the RLS/RPC gates.

### Legacy route consolidation
A large collection of old partner pages was found to contain static sample companies, fictitious fleet/load details, unsupported telemetry, false payout/escrow/invoice/settlement screens, or non-functional forms without a real database workflow. Those legacy URLs were replaced with noindex, path-safe redirects to the authenticated Partner Workspace. The partner directory/profile routes now point to the factual network information page. The retained functional routes are the current onboarding, partner workspace pathways, verified opportunity/quote flow, accepted-assignment/capacity flow, driver invitations, partner evidence, integration/automation, notifications/support, performance/security audit, coverage and capability modules.

### Remaining gates
- Do not conduct real partner acquisition or submit/approve a real partner application before the full ecosystem and all workspace pages have been reviewed by the user.
- Signed-in browser E2E for application upload, admin review, capability approval, partner quote, assignment, capacity reservation and driver invitation remains pending; no fake business evidence or synthetic partner has been inserted to force a pass.
- Existing open verification case and pending capability require genuine evidence and authorized human review; they were not altered.
- Step 4 is **backend-guarded and legacy-page cleanup substantially complete, but not fully acceptance-tested**. It remains open until a controlled test with an explicitly designated test account and genuine test documents can verify the complete workflow without activating a real commercial partner.

- Static JavaScript syntax checks passed for the authenticated partner gateway, development/test and business pathway workspaces, both AAL2 admin review queues, and the retained live partner opportunity, accepted-assignment, capacity, driver-invitation and dispatch-assignment pages. These are source-level checks only; they do not substitute for authenticated browser E2E.


## Evidence-backed capability review gate — 11 November 2026
- Rechecked the live partner onboarding and capability submission contracts against the production RPC signatures.
- Confirmed the private verification bucket remains non-public, capped at 10 MiB, and restricted to PDF/JPEG/PNG.
- Found that the capability review list RPC exposed every pending capability row, including legacy/onboarding declarations without capability-specific evidence. The review RPC correctly rejected approval without one to five partner-owned evidence files, which meant those rows were not actionable.
- Updated `krim_admin_list_partner_capabilities` to return only pending submissions with one to five capability evidence paths, matching organisation/user/capability path structure, and storage ownership by the original submitter. It now separately reports the count of pending declarations held for missing or invalid evidence.
- Updated the restricted capability review page to distinguish review-ready submissions from held declarations and explain that the partner must submit capability-specific evidence before review.
- Verified against production data: 1 pending capability row, 0 evidence-backed review-ready submissions, 1 held declaration. Anonymous execution of the list RPC is denied; authenticated execution remains available subject to its in-function AAL2 and platform-permission checks.
- No partner was approved, no document was created, and no operational coverage or commercial access was activated.
- Remaining real-world gate: a genuine partner must sign in, submit capability-specific evidence, and complete independent organisation/compliance review before any capability can be approved.
