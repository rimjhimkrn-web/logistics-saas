# Phase 00 Gate C3.22 — Driver ecosystem admission, carrier invitation, identity verification, vehicle eligibility and operational activation

**Date:** 2026-11-25  
**Source baseline:** `72d75a18f985ceb09e468839435ee95700e11e46`  
**Method:** Read-only source/migration review reconciled with prior driver/fleet audits. No driver invitation was issued or accepted, no account/profile/document/vehicle/assignment was created, no RPC or SQL was executed, and no Production/Staging state was changed.

## Executive decision

**PARTIAL PASS / BLOCKED — the driver admission and dispatch authorization design has meaningful security gates, but no operational driver/fleet network or end-to-end onboarding proof exists. Keep real driver onboarding and dispatch limited to a controlled, manually supervised pilot only after isolated Staging validation and a verified carrier is available.**

The reviewed migration design supports carrier-issued, email-bound, expiring, single-use invitations; driver membership; private identity/licence evidence; independent administrator review; verified carrier eligibility; vehicle registration and independent document approval; driver/vehicle binding; and server-side dispatch readiness. Earlier Production snapshot evidence recorded zero driver profiles, verification documents, assignments, vehicles, vehicle documents, driver/vehicle bindings, tracking sessions, dispatch authorizations, dispatches, delivery evidence and trip events. This is historical snapshot evidence, not a fresh count performed in this gate.

## Scope and evidence reviewed

- `supabase/migrations/20261104190000_driver_carrier_invitation_and_membership_workflow.sql`
- `supabase/migrations/20261104190000_driver_verification_documents_and_review.sql`
- `supabase/migrations/20261104193000_secure_driver_membership_invitations.sql`
- `supabase/migrations/20261115151000_require_all_driver_documents_for_verification.sql`
- `supabase/migrations/20261115153000_require_identity_evidence_for_driver_assignment_acceptance.sql`
- `public/driver/profile.html`, `public/driver/assignment-inbox.html`, `public/driver/safety-checklist.html`
- Prior audits: driver fleet/vehicle readiness, assignment/custody/warehouse quality, and driver dashboard.

## Positive controls

1. **Carrier invitation eligibility:** invitation creation requires authenticated partner management permission and an active registered-business carrier with verified partner status, active lifecycle, compliant state and verified active transport capability.
2. **Invitation security:** the reviewed newer invitation workflow stores a SHA-256 token hash, binds acceptance to the authenticated user's email, expires invitations after seven days, locks the invitation row, rejects replay/revoked/expired tokens and writes audit events. Development/test accounts cannot join commercial carrier operations.
3. **Driver membership:** invitation acceptance creates/updates a driver membership and links the driver's profile to the carrier. The older invitation path uses a transaction advisory lock and rejects incompatible existing membership.
4. **Private identity evidence:** driver verification bucket is private, file size is capped at 10 MB and declared MIME types are allowlisted. The later insert policy verifies the object exists and is owned by the authenticated user under the exact user/profile path.
5. **Independent evidence review:** document review requires AAL2 and platform-admin permission, rejects self-review, verifies original object ownership/path before acceptance and audits the decision.
6. **Three-document verification:** later migration requires independently accepted licence-front, licence-back and identity documents, current eligible carrier, verified transport capability and active driver membership before the profile becomes verified.
7. **Dispatch acceptance safeguards:** prior function review found exact driver ownership, active membership, verified/unexpired licence and evidence, active driver-vehicle binding, verified vehicle and mandatory current vehicle documents, exact shipment/partner/leg match, ROAD-only restriction, capacity/payload check, partner capability and approved pickup service area.
8. **Ambiguous workspace context:** driver dashboard previously changed to fail closed unless exactly one active driver membership exists.

## Findings and blockers

### P1 — Conflicting invitation generations and API signatures
The repository contains more than one invitation implementation: one uses a private invitation table, SHA-256 token hash and a seven-day expiry; another uses organization invitations and an MD5 token hash, with a separate create-function signature. Migration history and deployed function overloads must be reconciled before activation. A migration filename collision is also present in the source tree for same-timestamp driver invitation/profile workflows. Do not assume the newest source file is the deployed canonical implementation.

### P1 — Invitation token delivery and lifecycle are not proven
The invitation RPC returns a bearer invitation URL, but a complete secure delivery, resend, acknowledgement, abuse-monitoring and dead-letter workflow is not established. Token exposure in browser history, logs, support tickets or analytics must be prevented. Test email mismatch, token replay, expiry boundary, revocation race, duplicate invites, concurrent acceptance and carrier suspension between issue and acceptance.

### P1 — Driver profile creation and invitation acceptance require atomicity review
The invitation workflow updates membership and driver profile in a multi-step privileged function. Review the full function body, triggers and constraints for atomic rollback, organization transfer, pre-existing profile handling and duplicate membership/profile races. A partial signup or interrupted browser session must not create a commercially active driver without all required state.

### P1 — Profile approval and per-document approval are separate paths
The earlier profile-review function can mark a profile verified after at least one pending/accepted document, while later document-review migration implements the stricter three-document rule. Migration order, function replacement and EXECUTE grants must be confirmed in the actual deployed database. Ensure no remaining RPC or privileged path can bypass the three-document condition.

### P1 — Reviewer independence is not consistent across every approval path
The later document-review RPC blocks a driver from reviewing their own document. The earlier aggregate profile-review RPC does not visibly enforce the same reviewer separation. Ensure all active profile, document and vehicle review paths use a consistent independent reviewer policy, with auditable second-person exceptions if required.

### P1 — Driver-to-carrier association and offboarding
The newer invitation path rejects development/test accounts and checks carrier eligibility at acceptance, but complete driver transfer, carrier suspension, membership revocation, account deactivation and active-assignment stop-work behavior are not proven end to end. Revoking membership must invalidate future actions and sessions without silently abandoning in-flight cargo or custody.

### P1 — Legacy public routes redirect to staging-named pages
The inspected public driver profile, assignment inbox and safety checklist routes redirect to `app/driver/staging/*`. A folder name is not environment isolation; prior audit found GitHub Pages hostname defaults to Production Supabase while a separate preview host references Staging but deployment was unverified. Confirm canonical route and environment resolution before inviting real drivers through these entry points.

### P1 — Vehicle readiness is a separate mandatory admission gate
A verified driver alone is insufficient. Current vehicle registration, independent verification, country/category document matrix, active driver binding, payload fit and trip-specific roadworthiness must be proven before assignment acceptance and dispatch. Prior audit found no persisted canonical per-trip pre-trip inspection gate; do not claim full safety/maintenance readiness.

### P2 — Evidence integrity and privacy
Private bucket, MIME declarations and owner/path checks are positive but do not prove byte-level MIME validity, malware scanning, immutable object version/hash, retention/deletion, signed URL expiry/revocation or legal hold. Define evidence retention and privacy access before scale.

### P2 — No durable lifecycle notification assurance
Driver invitation, evidence rejection/renewal, licence expiry, vehicle suspension, assignment changes and offboarding require reliable notifications and acknowledgement. A database audit row or in-app inbox item is not proof of email/SMS delivery or driver acknowledgement.

### P1 — No live operational network or E2E evidence
Prior Production snapshot showed zero driver profiles, driver documents, driver assignments, vehicles, vehicle documents, driver/vehicle bindings, tracking sessions, dispatch authorizations, dispatches, delivery evidence or trip events. No real fleet availability, driver capacity, dispatch capability or delivery proof may be claimed from static pages or schema alone.

## Readiness matrix

| Component | Result | Evidence boundary |
|---|---|---|
| Carrier-issued invitation eligibility | PARTIAL PASS | Source reviewed; deployed canonical RPC not reconciled |
| Token/email/expiry/replay protections | PARTIAL PASS / BLOCKED | Source controls; delivery, abuse and race tests NOT TESTED |
| Driver membership and profile association | PARTIAL PASS / BLOCKED | Source reviewed; atomicity and transfer tests NOT TESTED |
| Identity/licence evidence upload | PARTIAL PASS | Private bucket and owner/path policy; byte-level integrity NOT TESTED |
| Independent driver evidence review | PARTIAL PASS / BLOCKED | Later document path self-review guard; aggregate profile path requires reconciliation |
| Three-document verification | PARTIAL PASS / BLOCKED | Later migration enforces; deployed migration order and bypass audit NOT TESTED |
| Vehicle registration and compliance | PARTIAL PASS / BLOCKED | Source design; no live fleet records in prior snapshot |
| Driver/vehicle binding and dispatch readiness | PARTIAL PASS / BLOCKED | Prior source audit; concurrency and runtime behavior NOT TESTED |
| Driver workspace routes/environment | BLOCKED | Legacy public routes target staging-named pages; deployed environment unresolved |
| Driver lifecycle notifications/offboarding | NOT TESTED / BLOCKED | End-to-end durable delivery and in-flight protection not proven |
| Live driver/fleet network | FAIL / BLOCKED | Historical Production snapshot counts all zero |
| Full driver-to-delivery E2E | NOT TESTED / BLOCKED | No synthetic staged journey executed |

## Required remediation and test order

1. Reconcile migration history and deployed RPC signatures; identify one canonical invitation implementation and remove ambiguity only through reviewed migration.
2. Confirm deployed function definitions, trigger paths, EXECUTE ACLs and all profile/document review paths; eliminate any weaker verification bypass.
3. Enforce reviewer independence consistently for profile, licence/identity documents and vehicle evidence.
4. Verify invitation/profile/membership transaction atomicity, idempotency, transfer and rollback under concurrent/replayed requests.
5. Secure invitation delivery and token handling; test email mismatch, expiry, revocation, replay, rate limits and secret leakage.
6. Resolve public-to-staging-named route redirects and prove Production/Staging Supabase URL selection before any real invitations.
7. Complete vehicle pre-trip inspection and maintenance/insurance eligibility gates before operational dispatch claims.
8. Define driver suspension/offboarding and active cargo stop-work/custody takeover with durable notification and acknowledgement.
9. In isolated Staging, use synthetic users and carrier only; test wrong email, wrong tenant, forged profile/document IDs, missing/duplicate documents, self-review, expired licence, revoked vehicle binding, inactive carrier, development-test account, race/replay and partial signup recovery.
10. Run one fully evidenced synthetic journey: verified carrier → invitation → driver signup → membership → three accepted identity/licence documents → verified vehicle and binding → exact-leg assignment → driver acceptance → dispatch authorization → controlled trip event → verified POD. Keep GPS and real customer notification disabled unless separately approved.

## Safety boundary

No Production or Staging SQL/RPC/Auth/invitation/profile/document/vehicle/assignment/dispatch/notification/provider/deployment operation was executed. No user or driver was created, invited, verified or assigned. No document was uploaded or changed. All runtime, migration-order and end-to-end tests remain NOT TESTED.

## Evidence references

- `docs/audits/KRIM-DRIVER-FLEET-AND-VEHICLE-OPERATIONAL-READINESS-AUDIT-2026-11-16.md`
- `docs/audits/KRIM-DRIVER-ASSIGNMENT-CUSTODY-AND-WAREHOUSE-QUALITY-SECURITY-REVIEW-2026-11-16.md`
- `docs/audits/KRIM-PAGE-51-DRIVER-DASHBOARD-REVIEW-2026-11-16.md`
- `supabase/migrations/20261104190000_driver_carrier_invitation_and_membership_workflow.sql`
- `supabase/migrations/20261104190000_driver_verification_documents_and_review.sql`
- `supabase/migrations/20261104193000_secure_driver_membership_invitations.sql`
- `supabase/migrations/20261115151000_require_all_driver_documents_for_verification.sql`
- `supabase/migrations/20261115153000_require_identity_evidence_for_driver_assignment_acceptance.sql`

**Gate C3.22: PARTIAL PASS / BLOCKED. No broad driver activation or dispatch readiness claim.**
