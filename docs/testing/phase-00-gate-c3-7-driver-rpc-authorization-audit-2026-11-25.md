# Phase 00 — Gate C3.7: driver workflow RPC authorization and lifecycle audit

Date: 2026-11-25
Repository: rimjhimkrn-web/logistics-saas
Immutable source baseline: `72d75a18f985ceb09e468839435ee95700e11e46`
QA branch: `qa/phase-00-baseline-2026-11-25`
Scope: source-level review of driver assignment acceptance, partner-to-driver assignment, pickup/transit/exception RPC, exact-leg dispatch authorization, POD submission, POD review/delivery authorization, evidence registration, and previously documented remediation. No SQL was executed against Production or Staging. No RPC was invoked and no data/schema/policy/grant was changed.

## 1. Executive decision

**PARTIAL PASS / BLOCKED — do not enable unrestricted driver execution or POD completion.**

The source contains substantial server-side controls: auth.uid ownership, active driver membership, accepted assignment state, shipment/leg/partner tuple checks, current multi-leg dispatch authorization, ROAD-only execution, verified licence/identity evidence, and separation of POD submission from independent verification.

However, there are still material source-level gaps and unresolved known findings:
- Driver assignment acceptance checks a live active driver/vehicle binding but does not compare the binding's `driver_profile_id` to the exact verified profile selected for that driver.
- The admin POD review function updates driver assignments by `partner_assignment_id` and does not constrain the update by the POD's full shipment/leg/organization/driver tuple.
- The internal POD submit/verify boundary requires effective database EXECUTE ACL verification and wrapper/internal tuple validation; the existing audit/remediation records a bypass risk and a known missing exact tuple/evidence binding.
- Trip-event replay accepts a repeated pickup/transit event based on status and presence of a previous event, without an idempotency key or canonical payload comparison.
- Exception workflow, tenant isolation, concurrency, revocation and evidence handling remain untested at runtime.

## 2. Positive controls found in source

### Driver acceptance — `krim_driver_accept_assignment(uuid)`
Latest relevant definition is in `20261116020000_allow_driver_acceptance_for_later_multileg_legs.sql`. It:
- requires `auth.uid()`, assignment ownership and active driver membership;
- requires a verified profile, non-empty licence, future licence expiry, accepted front/back licence evidence and accepted identity evidence;
- requires an assigned verified/active vehicle and active driver binding;
- checks mandatory vehicle document requirements and expiry;
- checks partner assignment matches the driver assignment's shipment, exact leg and organization;
- checks shipment lifecycle and exact assigned ROAD leg;
- checks positive shipment weight and vehicle payload capacity;
- only permits assigned → accepted and records accepted_by/accepted_at.

The source is stronger than the initial 6 November implementation and includes later multi-leg allowance. These checks have not been exercised against synthetic actors.

### Driver event recording — `krim_driver_record_trip_event(uuid,text,text)`
Latest logic is defined in `20261115145401_add_dispatch_revocation_and_revalidate_at_driver_execution.sql` (later grant restoration is in `20261117017000_restore_driver_trip_event_rpc_access.sql`). It:
- requires authenticated user and assignment ownership;
- checks active driver membership;
- locks the assignment, linked partner assignment, exact shipment leg and shipment;
- requires the partner assignment to be accepted/active and linked to the same shipment, leg and organization;
- rejects terminal assignment/leg/shipment states;
- for active multi-leg plans, calls the current exact-leg dispatch validator, which checks active authorization, exact plan item, accepted partner assignment, partner status/compliance/capability, confirmed capacity reservation/binding and preceding-leg custody;
- restricts pickup/transit events to ROAD legs for multi-leg plans;
- requires the driver to have accepted the assignment before pickup;
- enforces pickup before transit;
- writes driver trip event, tracking event and partner execution event;
- updates leg/shipment transit state only through the guarded transition.

Exception events require meaningful notes and an active assignment state. Delivery is intentionally excluded from this RPC and reserved for independently verified POD.

### POD evidence registration and driver submission
- Evidence INSERT policy in `20261105054211_secure_driver_delivery_evidence_registration.sql` requires the authenticated user's own assignment, active driver membership, exact user/assignment storage path, uploader-owned object in private `krim-driver-evidence`, MIME allowlist and 10 MiB maximum.
- `krim_driver_submit_delivery_pod(uuid,text,text,text)` in `20261106001500_add_authenticated_driver_pod_submission.sql` requires the driver-owned assignment, active driver membership, in-transit state, linked commercially active partner assignment and at least one evidence object owned by the driver.
- Internal POD submission checks the commercial partner assignment, shipment, exact leg, route plan item for multi-leg journeys, state and payload retry equivalence; the 15 November hardening adds deterministic assignment locking and conflicting-retry rejection.
- POD verification and final delivery authorization are separate from driver submission. This is the correct control design.

## 3. Findings requiring remediation or verification

### P1 — driver profile-to-vehicle binding does not prove exact profile identity
Latest driver acceptance checks `krim_vehicle_driver_bindings` by vehicle, driver user, organization and active status, but does not include `b.driver_profile_id = dp.id` in the join. A binding could therefore reference a different profile row while still matching the same driver user/organization/vehicle. The exact selected profile is not proven to be the profile bound to that vehicle.

**Required:** require exact profile ID equality in the acceptance and dispatch/departure validators; validate uniqueness/currentness of the profile and binding under row locks. Review all binding and assignment writer functions, not only driver acceptance.

### P1 — admin POD review does not update driver assignment by exact POD tuple
`krim_admin_review_delivery_pod(bigint,text,text)` from `20261106010000_add_admin_pod_verification_and_delivery_authorization.sql` updates `krim_driver_assignments` using only `partner_assignment_id = v_pod.assignment_id` and non-terminal status. It does not explicitly constrain by the POD's shipment ID, shipment leg ID, partner organization, driver user, or exact driver-assignment ID. The returned assignment identity is scalar.

**Required:** before verification, resolve exactly one driver assignment matching the POD's full commercial and driver tuple. Reject zero or ambiguous matches. Update only that exact assignment row and write the event against the same ID. Preserve AAL2, admin permission and independent review requirements.

### P1 — POD wrapper/internal boundary and evidence tuple still need closure
The authenticated driver wrapper resolves the driver's assignment and checks that registered evidence belongs to that driver and assignment. The internal creator accepts a partner-assignment ID and JSON evidence metadata and resolves the commercial shipment/leg. Existing 16 November audit/remediation documents identify that direct internal invocation and reviewer matching need stronger exact tuple enforcement, and that evidence should be resolved from canonical database/storage records rather than trusted from client JSON alone.

The 15 November leg-scoped creator validates shipment/leg/partner/plan relationships and conflicting retries, but the source review does not establish a single canonical private validator shared by both wrapper and internal creator that proves driver assignment ID, driver user, partner assignment ID, shipment ID, exact leg ID, partner organization and each evidence object. The reviewer query and update are not yet fully aligned to that tuple.

**Required:** harden the internal routine itself; derive all evidence from database records and `storage.objects`; validate exact driver-assignment/partner-assignment/shipment/leg/org/user tuple at every boundary; verify effective EXECUTE ACLs on public SECURITY DEFINER entry points and private helpers; reject forged direct calls and cross-leg evidence. Do not rely on frontend hiding or wrapper-only checks.

### P2 — trip-event replay semantics lack payload equivalence
The current event RPC returns the existing assignment for some repeated pickup/transit calls if a prior event exists and the assignment is already in a later state. It does not compare a stable idempotency key or canonical notes/source payload. A changed retry may be treated as a replay and silently return the existing state.

**Required:** define event identity/idempotency semantics; add stable event key and canonical payload comparison. Exact replay should be idempotent; conflicting payload should be rejected and audited. Include concurrent duplicate tests.

### P2 — exception and revocation lifecycle lacks runtime evidence
Source validates active assignment state and notes, and dispatch authorization revocation refuses revocation after pickup/transit. However, no runtime proof was obtained for exception holds, escalation, customer notification, carrier response, resolution/reopen, revocation races or atomic audit/event rollback.

**Required:** test late pickup, damage, shortage, safety incident, failed delivery, missed handover, customs hold, cancellation and recovery. Verify revoked membership, dispatch authorization, capability, capacity and custody immediately before execution.

### P2 — service-role/internal caller and ACL separation is not runtime-proven
The reviewed routines use SECURITY DEFINER in public/private schemas. Some are intended to be internal/service-role-only, while public driver-facing wrappers are authenticated. The source review cannot prove the effective Production/Staging ACLs after all historical migrations, default privileges, overloads and grants.

**Required:** read-only ACL inventory for exact signatures and overloads, including PUBLIC/anon/authenticated/service_role/postgres; prove internal functions cannot be called by anon/authenticated unless deliberately guarded. Verify no SECURITY DEFINER helper trusts a caller-supplied actor ID.

## 4. Required staged test matrix

No test identities or business records were created in this gate. Once isolated Staging and migration parity are independently proven, add synthetic-only tests:

| Test | Expected result |
|---|---|
| Anonymous calls to accept, trip event, POD submit, POD review | Rejected |
| Authenticated non-driver calls driver RPCs | Rejected |
| Driver A supplies Driver B assignment ID | Rejected |
| Driver with suspended membership | Rejected |
| Wrong partner org / shipment / leg tuple | Rejected |
| Binding references another profile row | Rejected |
| Expired/null licence, missing identity or licence evidence | Rejected |
| Unverified/expired vehicle or mandatory document | Rejected |
| Partner assignment cancelled/revoked after driver assignment | Execution rejected |
| Multi-leg missing/revoked exact-leg dispatch authorization | Pickup/transit rejected |
| Multi-leg non-ROAD leg | Driver pickup/transit rejected |
| Pickup before acceptance; transit before pickup | Rejected |
| Repeated exact pickup/transit request | Idempotent with same event identity |
| Repeated event with changed payload | Conflict rejected |
| POD without uploaded, owned, registered evidence | Rejected |
| POD evidence from another driver, assignment, leg or bucket | Rejected |
| Direct call to internal POD creator/reviewer by authenticated user | Rejected |
| POD reviewer is submitter/driver or lacks AAL2/admin permission | Rejected |
| POD reviewer sees ambiguous/mismatched driver assignment | Rejected |
| POD verification updates unrelated driver assignment | Must be impossible |
| Two concurrent POD submissions or event retries | One canonical record; conflicting payload rejected |
| Failed operation mid-transaction | No partial state/event/audit writes |
| Customer/partner/driver/operations/admin cross-tenant reads | Only authorized scoped data visible |

All tests must retain actor identity, environment/project ref, commit, request payload hash, expected/actual, SQL/audit evidence, timestamps and failure artifacts.

## 5. Release decision

**NO-GO** for unrestricted live driver assignment/execution, GPS collection, driver POD submission, POD certification or automatic delivery completion until:
1. exact driver profile ↔ vehicle binding is enforced;
2. POD creator and reviewer use one canonical exact-tuple validator and evidence object binding;
3. effective function ACLs and all direct callers are reconciled;
4. trip-event idempotency and exception/revocation semantics are implemented and verified;
5. production migration history is reconciled and isolated Staging is proven;
6. the complete synthetic staging test matrix passes, including concurrency and tenant isolation.

This gate is source-level review only. It does not certify the current live database function definitions, grants, RLS behavior, or operational execution. No Production/Staging SQL, RPC, row, schema, policy, grant, account, provider or deployment was changed.
