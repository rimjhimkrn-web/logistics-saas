# Gate C3.14 — Driver assignment lifecycle, reassignment, cancellation, suspension, revocation and access control

**Programme:** KRIM GLOBAL PLATFORM — AI QUALITY ASSURANCE, SIMULATION & RELIABILITY PROGRAMME  
**Gate:** Phase 00 / C3.14  
**Source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**QA branch:** `qa/phase-00-baseline-2026-11-25`  
**Review date:** 2026-11-25  
**Disposition:** **PARTIAL PASS / BLOCKED — NO-GO for production driver reassignment, cancellation or suspension lifecycle claims until the missing controlled workflows and notification/recovery safeguards are implemented and tested.**

## 1. Scope and method

Read-only source review of driver assignment creation/acceptance, partner invitation and membership onboarding, driver identity/profile verification guards, dispatch authorization and revocation, driver trip-event authorization, licence expiry controls, partner fleet UI, driver assignment acceptance/security pages and account deactivation route.

Files reviewed include:
- `supabase/migrations/20261106180000_driver_assignment_acceptance_gate.sql`
- `supabase/migrations/20261106190000_driver_assignment_leg_integrity.sql`
- `supabase/migrations/20261104193000_secure_driver_membership_invitations.sql`
- `supabase/migrations/20261104194500_secure_driver_profile_transfer_on_invitation.sql`
- `supabase/migrations/20261104193000_reverify_driver_after_identity_changes.sql`
- `supabase/migrations/20261104195500_rate_limit_and_validate_carrier_driver_invitations.sql`
- `supabase/migrations/20261115145401_add_dispatch_revocation_and_revalidate_at_driver_execution.sql`
- `supabase/migrations/20261115152002_reject_revoked_dispatch_authorization_replay.sql`
- `supabase/migrations/20261123100000_admin_driver_licence_expiry_control.sql`
- `supabase/migrations/20261123101000_refine_admin_driver_licence_expiry_rpc_security.sql`
- `app/driver/module-03-assignment-acceptance.html`
- `app/driver/module-17-security-audit.html`
- `app/platform-admin/driver-verification.html`
- `app/partner/driver-vehicle-assignment.html`
- `auth/account-deactivation.html`

This is static source review only. No SQL/RPC, browser workflow, invitation, membership change, driver assignment, dispatch authorization or account deactivation was executed. No Production or Staging data was accessed or changed.

## 2. Positive source controls

1. Driver assignment creation requires an accepted partner assignment, exact shipment/leg/partner linkage, an active and verified partner organization, partner route capability, active driver membership in that partner organization and a verified driver profile/licence.
2. The assignment is linked to a specific shipment leg through a composite foreign key to the shipment/leg pair. Existing assignment reuse checks driver identity and shipment/leg/organization consistency; assigning a different driver to an already-linked partner assignment is rejected rather than silently overwritten.
3. Driver acceptance is a separate authenticated RPC. It locks the driver's assignment, checks ownership and active driver membership, requires verified profile/licence, revalidates accepted partner assignment and shipment/leg state, and records `accepted_at` and `accepted_by`.
4. Driver trip-event RPC restricts events to pickup, in_transit and exception; delivery completion is excluded and requires independently verified POD. It checks authenticated assignment ownership, active driver membership, partner assignment exact linkage/status, shipment/leg non-terminal state and pickup-before-transit.
5. For active multi-leg plans, driver pickup/transit revalidates current exact-leg dispatch authorization, partner compliance/capability, confirmed capacity and accepted custody; road-driver events are limited to ROAD legs.
6. Dispatch authorization revocation requires authentication, partner `shipment.dispatch` permission and a reason; it records revoker/time/reason and a partner execution audit event. It refuses revocation after pickup or transit has been recorded, preventing silent invalidation after physical execution begins.
7. Revoked dispatch authorization cannot be replayed with its old idempotency key; fresh authorization requires readiness to be revalidated.
8. Driver invitation acceptance is email-bound to the authenticated JWT email, token-hash matched, seven-day expiry checked, single-use/pending-state checked and tied to an eligible verified/compliant carrier. Invitation creation has a per-organization rate limit and reissues revoke older pending invitation for the same email in the newer private invitation path.
9. Driver profile verification changes are guarded; identity changes and organization transfer are restricted, and identity/detail changes can reset verification and reopen evidence for review.
10. Admin licence-expiry updates are isolated behind a private SECURITY DEFINER helper, require AAL2 and platform-admin permission, require an audit reason, lock the profile, reset verification to pending on change and create an audit event.
11. Partner fleet UI describes organization-scoped driver/vehicle binding and revocation with reason. Admin verification UI uses AAL2-controlled RPCs and 60-second private document previews.

## 3. Findings and release risks

### P1 — No controlled driver reassignment lifecycle after initial assignment
The reviewed assignment-creation RPC rejects assigning a different driver when a partner assignment already has a driver assignment. It returns the existing row only when the same driver is supplied; it does not provide a complete authorized reassignment transaction that revokes the previous driver's access, handles accepted/in-progress state, verifies replacement driver/vehicle, preserves assignment history and notifies both drivers and dispatch.

**Impact:** Operators may be forced into manual/out-of-band handling or unsafe direct data changes when a driver becomes unavailable. Build an explicit reassignment RPC with state-aware safeguards, immutable history, exact driver/vehicle/leg linkage and dual-party/dispatch notifications.

### P1 — No unified cancellation/withdrawal workflow for driver assignments
The driver acceptance and trip-event flows enforce state constraints, but this review did not establish a complete driver decline/withdrawal, partner cancellation, operations cancellation and post-acceptance cancellation lifecycle with reason taxonomy, approvals, shipment/leg reconciliation, capacity release and audit. Partner assignment status checks block later execution when no longer accepted/active, but this is not itself a complete driver assignment cancellation process.

**Impact:** A commercially cancelled partner assignment can leave a driver assignment row in an accepted or assigned state with unclear ownership and next steps. Implement explicit state transitions and reconcile linked assignment, dispatch authorization, capacity and shipment/leg state atomically.

### P1 — Dispatch authorization revocation does not provide an in-progress emergency suspension path
The revocation RPC deliberately rejects revocation once pickup or transit events exist. That is a reasonable guard against retroactively erasing physical execution, but no reviewed replacement mechanism provides emergency suspension/stop-work, safe custody transfer, reassignment, operations takeover or controlled access freeze while the driver is already in possession of cargo.

**Impact:** A driver/vehicle/security incident during a live trip cannot be handled merely by revoking dispatch authorization. Introduce a separate emergency incident/suspension state machine that preserves trip history and cargo custody while blocking unsafe next actions and escalating to dispatch/control tower.

### P1 — Membership/profile suspension does not prove assignment cleanup and user notification
Driver trip events require active driver membership, and profile verification changes are guarded. However, the reviewed source does not establish one atomic suspension/revocation workflow that deactivates membership or verification, invalidates active sessions/tokens as required, stops new dispatch/acceptance, marks assigned work for dispatch intervention, rechecks vehicle bindings and sends durable notifications to the driver, partner and operations.

**Impact:** Access checks may block subsequent RPCs, but existing assignment rows and operational ownership can remain unresolved. Add a controlled offboarding/suspension orchestration with session revocation, assignment impact inventory, reassignment/return decision, audit and mandatory service notifications.

### P1 — Licence/profile status revalidation is not proven across every execution path
Admin licence-expiry updates reset verification to pending, and driver acceptance checks verified profile/licence. Multileg dispatch authorization checks current licence expiry and required documents. The reviewed trip-event code also revalidates active partner assignment and, for multi-leg plans, dispatch authorization. Full proof that every single-leg pickup/transit, vehicle binding, POD submission, return/incident action and active-session continuation rechecks current driver and vehicle eligibility is not established by this bounded source review.

**Impact:** Eligibility can change after initial assignment/acceptance. Build one canonical eligibility predicate and invoke it at every privileged execution boundary, with explicit behavior for a driver already carrying cargo.

### P2 — Vehicle binding lifecycle and driver reassignment coordination are separate
The partner fleet page exposes driver/vehicle binding creation and revocation, while shipment driver assignment is managed by another RPC. The review did not establish an atomic operation that safely updates vehicle binding for a driver with active assignments, revalidates vehicle documents/capacity, blocks conflicting active bindings, or coordinates dispatch authorization refresh/revocation.

**Impact:** A vehicle binding can change independently of active shipment work. Add cross-domain guards and dispatch impact handling before permitting a live binding change.

### P2 — Driver account deactivation UI is not evidence of complete identity/session offboarding
An account-deactivation route exists, but its backend implementation, session revocation semantics, retained audit requirements, assignment handling and connector/provider side effects were not proven by this source sample. Do not treat route presence as an effective account-wide deactivation guarantee.

### P2 — Driver notification and acknowledgement lifecycle remains incomplete
No complete evidence was found for durable, mandatory notification delivery and acknowledgement for assignment offered, accepted, declined, reassigned, cancelled, suspended, revoked, vehicle changed, licence expired, access removed and emergency stop-work. Existing notification rows or audit events do not prove successful delivery, acknowledgement, retries, dead-letter handling or fallback escalation.

### P2 — Legacy invitation workflow coexistence needs migration/runtime verification
The repository contains multiple generations of invitation workflows and tables/functions, including a public organization-invitation path and a newer private invitation path. Source review alone does not prove which workflow is exposed to all current partner UI paths, that all old tokens are invalidated consistently, or that all invitations are single-use/revocable across the migration history. Confirm effective grants, RLS, trigger behavior and current UI-to-RPC mapping in isolated Staging.

## 4. Required remediation before release

1. Implement a single assignment lifecycle state machine with explicit offered, accepted, declined, cancelled, reassignment_pending, reassigned, suspended, completed and revoked semantics, preserving immutable actor/time/reason history.
2. Implement a guarded reassignment RPC: lock assignment/partner assignment/leg; block unsafe reassignment after pickup/in-transit unless emergency custody process is completed; verify replacement driver, licence, vehicle binding/documents and organization membership; revoke old driver's access; create replacement linkage; audit and notify.
3. Implement driver decline/withdrawal and partner/operations cancellation RPCs with reason, authority, idempotency, shipment/leg/capacity/dispatch reconciliation and explicit treatment of already accepted/in-progress work.
4. Add an emergency in-progress suspension/stop-work workflow distinct from retroactive dispatch authorization revocation. Preserve cargo custody, last known execution state, emergency owner, acknowledgement and escalation.
5. Create a canonical driver/vehicle eligibility function and revalidate it at assignment acceptance, dispatch authorization, pickup, transit, POD, incident, custody/return and other consequential actions. Define safe behavior if eligibility is revoked mid-trip.
6. Build an offboarding orchestrator for membership suspension, profile verification reset, session/token revocation, outstanding assignment review, vehicle binding cleanup, dispatch control and audit. Do not silently cancel work carrying cargo.
7. Coordinate driver-vehicle binding changes with active assignments and dispatch authorization. Block unsafe detach/rebind or require authorized handover.
8. Standardize the active invitation system; retire or explicitly quarantine legacy flows after confirming every UI caller, grant and token invalidation path.
9. Deliver mandatory service notifications with durable outbox, per-recipient delivery status, retries/dead-letter, acknowledgement distinct from read state, and escalation to partner/operations when unacknowledged.
10. Run isolated Staging tests for cross-tenant assignment IDs, inactive membership, suspended/expired licence, vehicle revocation, reassignment conflicts, concurrent cancellation/acceptance, dispatch revocation before/after pickup, emergency suspension during transit, stale sessions, token replay, invitation expiry/revocation and notification failure.

## 5. Verification matrix

| Check | Result | Evidence / limitation |
|---|---|---|
| Driver assignment exact partner/shipment/leg linkage | SOURCE PASS | Assignment creation and leg FK checks. |
| Assignment creation authorization | SOURCE PASS | Partner dispatch permission, active verified partner, active driver membership, verified profile/licence. |
| Driver self-acceptance | SOURCE PASS | Authenticated owner, active membership, verified profile, accepted partner assignment, shipment/leg state. |
| Pickup-before-transit and POD-only completion | SOURCE PASS | Trip-event RPC limits event types and enforces transition sequence. |
| Multi-leg dispatch revalidation | SOURCE PASS / PARTIAL | Exact authorization, compliance, capability, capacity and custody; runtime/ACL proof absent. |
| Dispatch authorization revocation before pickup | SOURCE PASS | Partner dispatch permission, reason and audit event. |
| Revocation after pickup/in-transit | SOURCE BLOCK / SAFE GUARD | RPC refuses revocation after physical execution begins; emergency alternative not established. |
| Revoked authorization replay | SOURCE PASS | Old idempotency key rejected. |
| Driver reassignment workflow | BLOCKED | Different driver rejected; controlled replacement lifecycle not established. |
| Driver decline/withdrawal/cancellation | BLOCKED | Complete state transition and capacity/leg reconciliation not established. |
| Mid-trip suspension/emergency stop-work | BLOCKED | No separate in-progress suspension/custody workflow established. |
| Membership/profile suspension and session revocation | BLOCKED | Individual guards exist; atomic offboarding/session and assignment orchestration not proven. |
| Licence expiry admin control | SOURCE PASS | AAL2, platform permission, audit reason, pending reset. |
| Eligibility revalidation at every execution boundary | BLOCKED | Canonical cross-workflow coverage not proven. |
| Driver/vehicle binding coordination | PARTIAL / BLOCKED | UI supports binding/revocation; active shipment coordination not proven. |
| Invitation token email binding/expiry/rate limiting | SOURCE PASS / PARTIAL | Newer private flow reviewed; legacy coexistence requires runtime mapping. |
| Mandatory lifecycle notification delivery/acknowledgement | BLOCKED | Durable delivery, retry, fallback and recipient acknowledgement not established. |
| Account-wide deactivation semantics | NOT TESTED | UI route exists; complete backend/session effects not verified. |
| Tenant, concurrency, stale-token and failure recovery tests | NOT TESTED | Requires isolated Staging identities and environment proof. |

## 6. Change and safety record

- No Production or Staging SQL, RPC, RLS, grant, table, row, account, secret, provider, deployment or Storage object was changed or invoked.
- No driver, vehicle, shipment assignment, membership, invitation, dispatch authorization or session was created, modified or revoked.
- No notification was sent and no user/partner was contacted.
- Documentation-only QA branch change.

**Gate C3.14 result: PARTIAL PASS / BLOCKED.** Keep reassignment, cancellation, suspension/offboarding and emergency stop-work capabilities marked unavailable until the state machine, atomic cross-domain controls and mandatory notification safeguards are implemented and verified in isolated Staging.
