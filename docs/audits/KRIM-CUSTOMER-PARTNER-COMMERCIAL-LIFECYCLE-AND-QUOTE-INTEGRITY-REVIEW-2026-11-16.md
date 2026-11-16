# KRIM Customer–Partner Commercial Lifecycle and Quote Integrity Review
**Date:** 16 November 2026  
**Method:** Read-only inspection of live PostgreSQL RPC definitions, RLS policies and table privileges. No public inquiry, qualification case, service request, partner quote, customer quote, award or assignment was created or changed.

## Executive summary
The core commercial design is coherent: customer enquiries create acquisition records; authenticated customers qualify service requests; verified partners submit quotes against opportunities; customers can inspect partner verification/compliance/capability; quote acceptance is tied to an accepted partner quote and a matching assignment; and assignment award checks current partner eligibility and exact-leg capability.

The commercial model still requires substantial operational and legal proof before real bookings:
1. **Public inquiry consent semantics:** the public contact RPC unconditionally writes `privacy_consent=true` and labels it a consent record. It does not receive a separate explicit privacy-notice acknowledgement or marketing-contact opt-in. This must not be reused as evidence of marketing consent or as a substitute for a separately versioned privacy notice acknowledgement.
2. **Lead ownership/linkage:** public enquiries create acquisition profiles with no customer organization, while acquisition-profile RLS requires organization access. This intentionally protects unassigned leads from ordinary customer access, but founder/admin lead-review access and eventual conversion/linkage need a verified, auditable path. The public enquiry path creates a standalone qualification case; it does not itself create a linked customer service request.
3. **Quote orchestration idempotency race:** `krim_request_quote_for_service_request` locks the request and reuses an existing queued/running/completed run, but it has no explicit unique request/run key in the inspected function. Concurrent requests are serialized by the request row lock; verify unique constraints and retry behavior before relying on exactly-once orchestration.
4. **Partner opportunity/quote lifecycle:** quote submission and award are locked and check partner eligibility, current compliance and capability. But leg-specific opportunity award sets the partner quote accepted and opportunity awarded while creating the shipment assignment as `offered`, not `accepted`. Customer quote acceptance must not be mistaken for partner acceptance or final dispatch readiness.
5. **Commercial/legal contract gap:** table/RLS review shows service contracts are read-only for parties at the client level. No complete signed-contract creation, countersignature, fee schedule, scope/insurance/liability, SLA, dispute or termination workflow was verified in this review.
6. **Direct customer lifecycle table DML:** acquisition profiles, events, qualification cases and service requests have authenticated INSERT/UPDATE/DELETE grants and org-scoped ALL policies. This is tenant-scoped but does not by itself enforce the intended state machine, maker-checker or audit completeness. Prefer controlled RPC writes for sensitive lifecycle transitions.

## 1. Public customer inquiry intake
`krim_submit_public_contact_inquiry` is an invoker function, not SECURITY DEFINER. It validates name, email, organization and message lengths/format, normalizes email, limits source page values, applies an email-scoped advisory lock and limits recent inquiries to three per email per hour.

On accepted submission it transactionally creates:
- public contact inquiry;
- customer acquisition profile (status engaged, qualification pending);
- acquisition event (discovered);
- standalone qualification case (pending, missing key shipment details);
- founder notification event and Telegram outbox row.

Positive controls:
- No anonymous direct table CRUD is granted on `krim_public_contact_inquiries`; its RLS policy denies client table access.
- Input sizes are bounded and source-page values are allow-listed.
- Rate limiting serializes same-email requests.
- Founder alert is queued in the same transaction as the lead records, with an idempotency key.

Issues:
- `privacy_consent` is set to true without a dedicated input acknowledgement. The procedure stores a privacy notice version and timestamp, but a form submission alone does not establish marketing consent or any optional communication channel consent.
- Rate limiting is email-scoped; the separate IP-limit helper exists but was not called in this function. Add edge/WAF/IP controls and abuse monitoring without collecting excessive personal data.
- A public contact message can contain sensitive personal or shipment information. Minimize what is copied into Telegram messages and avoid exposing full enquiry content to broad chat recipients.
- The founder notification outbox is queued transactionally, but delivery is asynchronous and can fail. Public success means record creation, not successful human notification.
- If a later profile-to-customer-org conversion fails, the enquiry should remain safely queued for manual review; do not create a duplicate profile or qualification case on retry.

Required design:
- Distinguish privacy notice acknowledgement, service-request processing basis, and optional marketing/WhatsApp/email consent as separate versioned records.
- Use a unique source inquiry reference for profile/case creation and retry-safe conversion.
- Add explicit founder/admin scoped lead-review and assignment workflow, with audit log and restricted PII visibility.
- Add consent withdrawal and retention/deletion processes.

## 2. Acquisition profiles, qualification and service requests
RLS/privilege inspection:
- `krim_customer_acquisition_profiles`, `krim_customer_acquisition_events`, `krim_customer_qualification_cases` and `krim_customer_service_requests` each have one authenticated ALL policy and authenticated table DML grants.
- Their policy checks organization membership through the profile's `organization_id`; related rows inherit access through the parent profile.
- Public inquiries create profiles without an organization ID, so normal organization-scoped users cannot read/write those lead records through these policies.
- This is consistent with separating anonymous leads from registered customer workspaces, but a controlled platform-admin/lead-review path must be confirmed.

`krim_request_quote_for_service_request`:
- Requires verified customer identity link and active customer workspace.
- Locks the request and checks ownership through the linked customer profile.
- Requires request status qualified/matching and a linked qualification case in qualified state.
- Reuses an existing queued/running/completed orchestration run if present; otherwise creates a pricing run and changes request to matching.
- Writes an audit event.

Positive control: customer cannot request quote orchestration against another profile's service request.

Gap: the function checks verified identity link and active workspace, but the inspected code selects the organization ID from workspace profile and does not visibly verify the current user's active organization membership and `quote.create` permission in that organization. The profile-to-user identity link may be intended as the authority, but it must be reconciled with the nine-workspace authorization model. Add explicit active membership/permission checks or document why the identity link is the only authorized binding.

Concurrency: request row lock helps serialize repeated calls. Verify a database uniqueness constraint on active orchestration runs per request and test worker crash/retry between queue creation, pricing, aggregation and finalization.

## 3. Partner opportunity and quote submission
`krim_create_partner_opportunity` and `krim_create_leg_partner_opportunity`:
- Require customer org access plus `quote.create` and `shipment.update`.
- Lock shipment and, for leg opportunities, exact leg and active route plan.
- Restrict sourcing to pre-execution shipment state and planned/unassigned leg.
- Prevent an already-awarded opportunity and validate route-plan linkage.
- Create opportunities only for the shipment's customer organization.

`krim_submit_partner_quote` and `krim_submit_leg_partner_quote`:
- Require authenticated partner organization membership and quote submission permission.
- Lock opportunity and validate it remains open and within response deadline.
- Check partner is active, registered-business mode, verified, lifecycle active, compliance current and capability covers shipment/leg.
- Reject invalid amount/currency/validity and prevent duplicate active quote submission according to inspected logic.
- Leg quote submission is bound to exact shipment and leg.

Positive control: development/test partners are explicitly blocked from commercial assignment in the leg award function. A partner cannot submit a quote for an arbitrary shipment without matching open opportunity, active membership and current capability.

Required checks:
- Confirm every quote submission function enforces registered business mode and excludes development accounts, including legacy shipment-wide quote paths.
- Confirm partner legal entity, insurance, service scope, currency, tax and liability declarations are verified and current.
- Confirm partner quote validity and opportunity deadlines are compared in one consistent timezone and are rechecked at acceptance/award.
- Confirm all quote updates/counteroffers are append-only or versioned so customers can reconstruct what was offered and accepted.

## 4. Customer quote visibility and partner eligibility
`krim_customer_list_partner_quotes`:
- Requires authenticated user and 1–100 unique valid shipment IDs.
- Requires access to every requested shipment; partial mixed-tenant result is rejected.
- Returns only quotes tied to the shipment's opportunity and customer organization.
- Shows partner name, legal name, verification, current compliance, current capability and computed `eligible_now`.
- Hides quotes from closed opportunities unless already accepted.
- Uses current partner organization status, registered-business mode, verification, lifecycle, compliance and verified effective capability.

Positive control: the customer UI has an eligibility signal based on current partner evidence rather than quote price alone.

Limitation: `eligible_now` is a point-in-time display signal, not a reservation. It can become stale before award; award must and does recheck current partner eligibility, capability and compliance under locks. UI must refresh and treat server-side award response as authoritative.

## 5. Quote award, acceptance and assignment
`krim_award_leg_partner_quote`:
- Locks partner quote, opportunity, shipment, exact leg, active plan and plan item.
- Requires customer org access plus `quote.update` and `shipment.update`.
- Rechecks opportunity open/deadline, quote eligibility/validity, partner active registered-business/verified/compliant state, current compliance and exact-leg capability.
- Prevents an existing active/completed assignment for the leg.
- Marks chosen partner quote accepted, rejects competing active quotes, awards opportunity and creates shipment partner assignment in `offered` state.
- Writes audit event.

Important lifecycle distinction: quote award is a customer selection and creates an offer to the partner. It is not yet partner acceptance. Driver, capacity, dispatch and custody must remain blocked until partner accepts the assignment and all later gates pass.

`krim_accept_global_quote`:
- Locks customer quote and shipment.
- Requires customer organization access and `shipment.update`.
- Only accepts a sent quote while shipment is quoted and quote not expired.
- Requires matching accepted partner quote and accepted assignment for exact shipment, active verified partner, current compliance and current capability.
- Transitions shipment to confirmed and finalizes partner assignment.

Positive control: customer quote cannot confirm shipment based solely on a tariff/price quote without a verified partner quote and matching accepted assignment.

Staging requirements:
- Concurrent quote award for two partners; exactly one assignment may be created.
- Partner rejection/timeout after award; customer quote must not remain falsely confirmed.
- Quote expiry at boundary timestamp, duplicate retries and status changes between UI display and server acceptance.
- Multi-leg shipment with different partner per leg; shipment-wide legacy quote acceptance must not override leg-scoped award rules.
- Partner verification/compliance/capability revoked between quote submission, award, partner acceptance and dispatch.

## 6. Direct table writes and RLS posture
The following authenticated tables have ALL policies and authenticated INSERT/UPDATE/DELETE grants:
- acquisition profiles;
- acquisition events;
- qualification cases;
- customer service requests.

The policies are tenant-scoped through `private.krim_has_organization_access`, and associated rows check their parent profile. This is meaningful tenant isolation but it still allows a member with organization access to directly alter lifecycle records unless additional grants, column privileges, triggers or state constraints prevent it.

Recommendation:
- Restrict direct writes to controlled RPC/service-role pathways for state transitions and immutable event tables.
- Keep customer-editable draft fields separate from qualification/approval/status fields.
- Require `quote.create`/customer permission on quote orchestration, not just profile identity link.
- Ensure audit events cannot be edited/deleted by ordinary organization members.
- Verify all policies under real authenticated JWTs for each workspace role and cross-tenant attempt.

Read-only RLS observed for customer/partner-facing quote, opportunity, assignment and service-contract tables; no anonymous SELECT was granted on these tables.

## 7. Contract and commercial boundary
`krim_service_contracts` has authenticated read-only party access in RLS; no direct authenticated INSERT/UPDATE/DELETE grants were observed. This protects contract records from casual client mutation but does not establish a complete contract workflow.

Before live commercial matching, each partner/customer relationship needs:
- signed master/service agreement and explicit service scope;
- fee model and who pays whom;
- confirmation that customer contracts and pays carrier directly in the lean non-custodial model;
- KRIM's separate referral/coordination/platform fee agreement, invoice and tax treatment;
- insurance, cargo liability, exclusions, claims, SLA, service failures, force majeure, sanctions/export controls and dispute process;
- authorized signatories, versioned documents, effective dates, renewal, suspension and termination.

Do not treat a quote, opportunity award, platform account, or partner verification badge as a signed service contract.

## 8. Staging-only end-to-end verification
1. Public inquiry validation, rate limit, repeated email, alternate IP, duplicate retry, outbox failure and PII redaction.
2. Privacy notice acknowledgement versus marketing/WhatsApp/email opt-in, withdrawal and audit.
3. Lead review, owner assignment, conversion to customer profile/org and linked qualification/service request; test retry without duplicate records.
4. Customer identity link, inactive workspace, revoked membership and permission-negative quote request.
5. Quote orchestration concurrent request, worker crash, retry, completed run and unique active run constraint.
6. Partner quote submission by verified, pending, expired, suspended and development/test partner; wrong tenant and wrong leg.
7. Customer visibility across multiple shipments/organizations, mixed tenant IDs and stale eligibility.
8. Concurrent award, competing quotes, expired quote, rejected partner offer, partner timeout and capability/compliance revocation.
9. Customer quote acceptance only after partner accepted assignment; prove no capacity/dispatch without later operational gates.
10. Contract document signing, authorized signatory, version changes, suspension and termination.
11. Confirm customer freight payments remain direct to partner; KRIM never receives/holds/escrows/splits/settles partner freight funds. KRIM own-fee collection remains deferred to the final phase.

## 9. Release decision
**NO-GO for unrestricted commercial booking or live revenue.**
- Public inquiry and partner quote pathways are implemented with useful validation and tenant controls.
- Quote award/acceptance checks are comparatively strong and revalidate current partner eligibility.
- Consent semantics, lead ownership/conversion, quote-orchestration retry guarantees and service-request permission binding need verification or remediation.
- Authenticated direct DML on customer acquisition/qualification/service request tables should be narrowed or proven safe through column/state controls.
- A complete signed commercial contract lifecycle is not established by this review.
- No staging end-to-end commercial transaction was executed.

No production code, schema, policies, grants or business records were changed. Do not implement production fixes until migration-history collision reconciliation and sanitized schema manifest are complete. Keep finance, bank, tax and live payment collection deferred to the final phase.
