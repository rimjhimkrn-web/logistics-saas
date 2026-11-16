# KRIM Partner Operational Modules & Claims Audit
**Date:** 16 November 2026  
**Scope:** Partner service coverage, capabilities, capacity/resources, freight opportunities, quote submission, driver invitations and legacy finance/performance routes.  
**Method:** Read-only repository inspection. No production records, partner approvals, quotes, assignments, dispatches, payments or external contacts were created.

## Executive summary
The partner operational pages inspected generally use live organization-scoped backend data, show explicit empty/error states rather than sample data, and distinguish declared records from approved operating authority. Several legacy finance, payout, escrow and performance routes have already been retired to the authenticated partner gateway. The carrier and freight-forwarder finance cards were also changed to non-interactive disabled notices in the preceding commits.

The largest remaining operational constraint is not the user interface: production currently has no verified operating partner, no active approved capability, no approved route coverage, no capacity commitment, no open opportunity and no assignment. The matching, quote, assignment, dispatch and POD journeys therefore remain unproven in a real operating transaction.

## Module findings

### Service coverage — generally sound controls
File: `public/partner/service-coverage.html`
- Explains that only records visible under the signed-in organization’s database permissions are displayed.
- Explicitly says empty results are not replaced with sample data.
- Keeps coverage records separate from capability records.
- States that viewing/exporting a capability does not activate it.
- Submission is restricted in the UI to active, verified, compliant registered businesses and requires a matching verified capability and approved country operating pack.
- Approval is not presented as a service guarantee.
- Follow-up verification: test the corresponding server-side RPC independently against unauthorized, unverified, expired and cross-tenant organizations. UI restrictions alone are not an authorization boundary.

### Services & capabilities — pending-review model
File: `public/partner/services-capabilities.html`
- Requires authenticated organization context and supporting evidence uploads to private storage.
- Describes submitted capability records as inactive and pending review.
- Approval is reserved for an authorized KRIM reviewer.
- Refrigerated and hazardous-goods flags are declarations only; the page explicitly says specialist capabilities remain inactive until dedicated jurisdiction-specific evidence and review controls exist.
- Empty states explicitly state that no placeholder capabilities are loaded.
- Follow-up verification: inspect storage object policies, upload MIME/size enforcement, reviewer RPC grants, evidence expiry/revocation and server-side specialist-capability rejection before any activation.

### Capacity & resources — no implied dispatch authority
File: `public/partner/capacity-resources.html`
- Reads organization-authorized backend records and states that no sample vehicles, invented capacity or assumed availability are displayed.
- Resource evidence is stored privately.
- States that capacity is not a dispatch assignment.
- Documents the current reservation boundary: verified vehicle resources using vehicle counts and weight units (kg/metric tonnes); warehouse slots, volume and equipment-specific reservations are not enabled.
- Empty registers show no-record states rather than sample assets.
- Follow-up verification: test capacity race conditions, double reservation, expired availability, resource revocation, unit normalization and cross-organization access in staging.

### Freight opportunities — live records only
File: `public/partner/available-loads.html`
- Shows live backend opportunities only.
- Says organization verification and backend permissions determine visibility and bid eligibility.
- Shows read-only mode where verification is incomplete.
- Server-side quote eligibility remains authoritative.
- Error states show no sample loads.
- Production currently has zero open partner opportunities, so the marketplace is not currently a live source of available work.

### Quote submission — server-authorized bid workflow
File: `public/partner/submit-quote.html`
- Requires a real open opportunity and verified eligible partner organization.
- Does not use demo loads, localStorage offers or invented prices.
- Clearly distinguishes submitted bid from shipment award, customer acceptance and payment guarantee.
- Disables submission if secure initialization or organization verification fails.
- Existing prior audit established server-side requirements: active verified compliant partner, matching current capability/route/weight, no self-bid, open opportunity and deadline. No active partner bids exist in production.
- Follow-up verification: run concurrent duplicate submissions, stale deadline, route/weight mismatch, quote revision, self-bid and cross-tenant tests in staging.

### Driver invitations — needs separate authorization testing
File: `public/partner/driver-invitations.html`
- Current legacy route resolves toward carrier workspace.
- Do not infer that a visible invitation screen means a driver has been verified or assigned.
- Follow-up: confirm invitation creation, acceptance, identity/licence verification, expiry, revocation, organization scoping and driver assignment are separate server-authorized transitions.

### Retired legacy routes
The following sampled routes are retired/redirected rather than presented as live standalone services:
- `public/partner/finance-settlements.html`
- `public/partner/payout-history.html`
- `public/partner/escrow-ledger.html`
- `public/partner/fleet-analytics.html`
- `public/partner/performance-ratings.html`
- `public/partner/capacity-calendar.html`

These redirects must not be interpreted as proof that the underlying financial, escrow, analytics or rating features are safe or enabled. KRIM finance remains unavailable for live money movement pending the separate remediation gates.

## Production operating evidence snapshot
From the previously completed production audits:
- Verified operational partners: 0.
- Active verified capabilities: 0.
- Approved route/service-area evidence: 0.
- Partner capacity commitments: 0.
- Open partner opportunities: 0.
- Partner quotes: 0.
- Assignments: 0.
- Dispatches: 0.
- Verified POD records: 0.

Consequently, the inspected pages are workflow infrastructure, not evidence of a currently operating carrier network.

## CI status observed during this audit
For audit commit `6239214f9a4890b9b221591b0b49916d4b87dbb4`:
- Static link audit: success.
- Production smoke checks: success.
- Pages build/deployment: in progress at the time of inspection.

For the carrier and forwarder finance-card edits:
- Static link audit and production smoke checks: success.
- Pages deployment runs were cancelled after a newer deployment superseded them. The later report commit’s deployment was still in progress.

## Required next gates
1. Complete latest Pages deployment and smoke/static checks.
2. Execute authenticated multi-tenant staging tests for service coverage, capability submission/approval, private evidence access and capacity reservations.
3. Execute quote and bidding negative tests, including concurrent duplicate submissions and stale opportunities.
4. Verify driver invitation/verification/assignment state transitions independently.
5. Keep finance, escrow, payouts and settlement workflows disabled for live commercial use.
6. Obtain one genuinely verified carrier with a documented service corridor and confirmed capacity before advertising any route as available.
7. Run one controlled partner-direct pilot; customer freight contract/payment stays directly with the provider. KRIM’s separately agreed referral/coordination fee requires evidence, accounting and qualified tax review.

**No production database mutation, external partner contact or financial action was performed.**
