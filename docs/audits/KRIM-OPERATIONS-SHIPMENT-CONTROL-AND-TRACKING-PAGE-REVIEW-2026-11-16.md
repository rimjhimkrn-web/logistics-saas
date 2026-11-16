# KRIM Operations Shipment Control and Tracking Page Review — 2026-11-16

## Scope
Static source review of:
- `app/operations/shipment-control.html`
- `app/operations/tracking-activity.html`
- `app/operations/dispatch-control.html` (read-only comparison of the adjacent dispatch readiness surface)

No production business RPCs were invoked and no operational data was changed.

## Shipment Control Tower
**Status: Connected read-only register; end-to-end role validation outstanding.**
- Requires an authenticated Supabase session and at least one active organization membership.
- Reads up to 100 shipment rows; the database RLS policy determines visible rows.
- Distinguishes query errors from an empty visible result.
- The review-preparation form is browser-only and explicitly does not save or change operations.
- It does not claim GPS, carrier connectivity, customs clearance or dispatch execution.
- Correction: added horizontal/touch scrolling to the shipment register wrapper for narrow screens.

## Tracking & Milestones
**Status: Connected read-only event register; source rendering defect corrected.**
- Requires an authenticated session and active organization membership.
- Reads up to 100 rows from `krim_tracking_events`, ordered by event time.
- Explicitly labels records as source-recorded events and does not imply live GPS/AIS/flight telemetry.
- Query failures are shown as unavailable rather than as a zero count.
- Review-preparation form is browser-only and non-persisting.
- **Defect found:** the row renderer contained an accidental nested arrow function, causing the generated row callback to return a function instead of HTML. This prevented event rows from rendering.
- **Correction:** replaced the nested callback with a normal row-to-HTML mapper.
- Added horizontal/touch scrolling to the tracking table wrapper.

## Adjacent Dispatch & Handover surface
The dispatch page reads shipment rows and calls `krim_operations_dispatch_readiness` for an assessment. It explicitly states that it does not authorise or execute dispatch. A successful readiness response is not itself dispatch authorization; the backend authorization workflow remains a separate control. No dispatch action was executed during this review.

## Changes
- `8ab4954b9ca35d3fb9c9df930c2b56d9650a4e91` — fix tracking row rendering and add mobile table overflow.
- `6260e14ae3807214ff0b1d78981d6ea5741761ae` — add mobile table overflow to shipment register.

## Verification status
- Source re-fetch confirms the tracking row renderer now uses a direct row mapper.
- Source re-fetch confirms mobile overflow wrappers exist in both pages.
- GitHub Actions production smoke, static link audit and Pages deployment were triggered for the two commits. Their final results must be checked before declaring this batch green.
- Browser interaction, real authenticated role tests, organization-boundary tests, RLS behaviour, and full shipment/exception/tracking lifecycle remain unverified.

## Release gates
Do not infer global visibility from the 100-row limit or from active membership alone. Validate exact organization scoping and least-privilege permissions in staging. Do not add tracking writes or live carrier integrations until trusted source identity, event ordering, replay handling, consent/contracts, and backend permission gates are verified. Production schema changes remain blocked by migration-history reconciliation.
