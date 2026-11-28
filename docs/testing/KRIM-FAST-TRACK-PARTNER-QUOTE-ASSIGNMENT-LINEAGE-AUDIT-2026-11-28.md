# KRIM Fast-Track — Partner Quote and Assignment Lineage Audit
Date: 2026-11-28
Branch: staging/phase00-env-isolation
Audited Staging project: qrpcivhdxobiaofppbkl
Scope: read-only database function-definition review. No DDL, DML, RPC invocation, notifications, or operational data changes.

## Branch and CI verification
Branch head observed: 4a7a79ca8e6cd5188bf619297afebdc0a80db266.
GitHub check-runs for this exact SHA:
- Cloudflare Pages: completed / success.
- environment-isolation: completed / success.
- audit-local-links: completed / success.
Cloudflare preview deployment reported successful for this commit. These checks do not establish database migration correctness or operational E2E readiness.

## Confirmed database function findings
Inspected live Staging definitions for:
- public.krim_accept_global_quote(bigint)
- public.krim_award_partner_quote(bigint)
- public.krim_internal_finalize_partner_assignment(bigint)
- public.krim_submit_partner_quote(bigint,numeric,text,timestamptz,text)
- public.krim_submit_leg_partner_quote(bigint,numeric,text,timestamptz,text)

### 1. Customer acceptance performs a fresh, broad capability EXISTS check
krim_accept_global_quote checks that the partner organisation remains active/verified/compliant and that at least one active, verified, currently effective capability exists, plus capability_covers_shipment and current compliance. It does not bind the check to a capability_id or immutable submission/evidence version used by matching or quote submission.

### 2. Partner quote submission independently re-selects any current capability
Both shipment-wide and leg-specific partner quote submission select the partner organisation based on existence of any active/verified/current capability. The shipment-wide path additionally invokes the capability coverage helper. Neither function persists which capability row or evidence submission version justified the quote. The leg-specific path's shown eligibility predicate does not itself bind a capability to the exact leg's mode/route/weight; this must be verified against remaining leg-specific predicates and upstream opportunity generation before concluding whether this is a bypass. Treat as a test requirement, not a proven exploitable bypass.

### 3. Quote records are mutable across resubmissions
krim_submit_partner_quote can update an existing submitted/under_review/shortlisted quote for the same opportunity and partner, replacing amount, currency, validity, notes and pricing snapshot. A quote revision therefore needs an immutable version/event record and must retain the original eligibility decision reference; mutable current quote state alone is insufficient audit evidence.

### 4. Assignment finalization validates physical capacity but not capability lineage
krim_internal_finalize_partner_assignment locks and validates assignment, shipment, capacity binding, reservation, shipment leg and committed capacity. It does not verify or persist a capability_id/submission_version reference. Capacity correctness and partner qualification are distinct controls; both must be enforced and traceable.

### 5. Quote acceptance and finalization are chained
krim_accept_global_quote locks quote and shipment, validates customer organisation access and shipment state, requires an accepted partner quote and accepted assignment, checks current partner organisation/capability/compliance, transitions shipment to confirmed, and invokes assignment finalization. The current-capability recheck is useful defence-in-depth but cannot prove that the exact capability approved at sourcing time was the one relied upon.

## Required target invariant
At the first eligibility decision, persist an immutable decision record with:
- partner_organization_id
- capability_id
- immutable capability_submission_id / submission_version
- capability status and effective interval at decision time
- service type, transport mode, origin/destination coverage, weight/capacity limits used
- evidence manifest digest and reviewer approval reference
- eligibility policy version and decision timestamp
- source matching run/opportunity and shipment/leg identifiers

Propagate a non-null eligibility_decision_id through matching result, opportunity, partner quote versions, awarded assignment and shipment/leg execution. Quote amendments must create new immutable quote versions while retaining the eligibility decision; if a new capability is needed, create a new eligibility decision rather than rewriting the old one.

At award, customer acceptance and assignment finalization:
- lock relevant decision/capability/assignment rows in a documented order;
- verify decision is approved and matches the partner, shipment/leg and required service;
- block new awards/allocations after capability suspension/revocation;
- preserve already accepted/in-progress work and create an operations exception for explicit human resolution;
- retain legacy assignments as unattributed until reviewed; do not infer lineage from today's organisation profile.

## Regression cases to add to isolated Supabase tests
1. Capability approved at match, then revoked before quote submission: new quote/award blocked.
2. Capability revoked after accepted assignment but before finalization: no silent cancellation; controlled exception and documented resolution.
3. Multiple active capabilities: exact qualifying row is deterministic and persisted.
4. Capability evidence version replaced after matching: old decision remains auditable and cannot silently inherit new evidence.
5. Quote resubmission changes amount/currency: immutable quote version created, eligibility lineage retained.
6. Multi-leg opportunity: capability covers exact leg mode, route and weight; unrelated capability cannot qualify it.
7. Assignment capacity binding valid but capability lineage missing: finalization rejects new assignment.
8. Legacy assignment without lineage: no automatic inference or destructive backfill.
9. Concurrent capability revocation and quote award: locking/order prevents a new allocation racing past revocation.
10. Customer quote acceptance idempotency does not bypass decision validation.

## Safety and blockers
- Staging operational capability/matching/quote/assignment tables were previously observed empty in the audit snapshot; no live business records were changed.
- No function was invoked during this audit.
- No migration or database change was created/applied.
- Historical migration filename/ledger reconciliation and local isolated CLI/Docker test environment remain hard blockers to safely implementing schema changes.
- Production was not accessed or modified.
