# KRIM Page 62 — Customs Dashboard
Date: 2026-11-16

## Canonical page
`app/customs/index.html` — Customs & Trade Workspace.

## Access and data
- Requires an authenticated session, active customs-organization membership and `compliance.view`.
- Licence submission controls are shown only to memberships with `compliance.manage`.
- Reads customs records, exceptions, broker assignments, broker licences, document submissions and jurisdiction requirements under current database policies.
- Queries are bounded (normally 100 rows per operational register; jurisdiction requirements 200).
- Supports controlled document submission, broker response, authorized document review, private evidence preview and CSV export of visible records.

## Changes
Commit: `f32e98317c5dfb8c4939c7f9ccb8fb4d8b41fab5`
- Added response-shape validation across all six parallel register queries.
- If any successful query returns a non-array payload, the page withholds the potentially incomplete dashboard rather than rendering misleading partial totals.

## Operational boundaries
- Upload/review/broker-response buttons are connected to server-side RPCs, but none were invoked during this audit.
- Document evidence is not a customs declaration filing; a saved review does not equal government acceptance or customs release.
- No live ICEGATE, ACE, ICS2 or other authority gateway integration was demonstrated by this page.
- The UI's visible data remains bounded and RLS-scoped; absence from the view is not proof of global absence.

## Verification
No shipment, customs, licence, broker-assignment, evidence or exception records were created or changed. No external authority was contacted. Production deployment of the related database controls remains subject to migration-history reconciliation.
