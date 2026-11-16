# KRIM Page 64 — Customs Clearance Tasks / Broker Review Desk
Date: 2026-11-16

## Canonical page
`app/platform-admin/customs-broker-review.html` — restricted customs broker licence review and assignment control desk.

## Access and backend controls
- UI requires a valid authenticated session and AAL2 MFA.
- Repository migrations for `krim_customs_broker_license_review` additionally enforce `admin.platform`, AAL2, independent reviewer (submitter cannot review own evidence), active customs organization/jurisdiction, evidence metadata and original private object checks, and effective licence dates.
- Queue reads are bounded: licences 200, organizations 1,000, countries 500, licence events 500, customs records 500, assignments 500.
- Broker assignment source RPC requires AAL2 and an authorized actor organization, a currently approved broker licence for the exact jurisdiction, and no existing open assignment.
- The checked-in admin control desk uses platform organization ID 1 as the actor context, consistent with repository admin policies/migrations. Production deployment and the live identity behind that ID are not certified here.

## Changes
Commits:
- `58a3d02bcc8be39288bb01518061c4099d86311d` — initial hardening attempt; superseded.
- `6454f4f95a321db58e1168a12c7eb0b61b64e281` — restored authorized assignment controls with explicit canonical platform actor context.
- `16df3295d830b6b28d915a15cb4c31d4de70f79a` — fail-closed checks for country and audit-event query errors; validates all six query response shapes.

## Limits and risk boundary
- The review desk is an administrative evidence-review tool, not a customs declaration filing or government clearance console.
- Assignment creation/revocation/completion and licence decisions are real state-changing actions. They were not invoked during this audit.
- The source migrations are not proof that the same definitions are deployed in production; the repository/production migration reconciliation blocker remains.

## Verification
No licence was approved/rejected, no broker was assigned/revoked/completed, and no evidence was opened. No production data changed.
