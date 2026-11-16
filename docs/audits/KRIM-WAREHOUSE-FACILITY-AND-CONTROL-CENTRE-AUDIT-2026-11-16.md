# KRIM Warehouse Facility Management and Control Centre Audit — 2026-11-16

## Scope
Reviewed the authenticated warehouse control centre, facility registration/listing, and legacy warehouse dashboard/onboarding/profile routes. No production business RPCs or facility-registration actions were invoked.

## Facility management findings
- Facility registration requires an authenticated user, active organisation membership, eligible registered-business organisation state, warehouse organisation type or verified active warehouse capability, and a dedicated registration RPC.
- New facilities are explicitly described as inactive pending administrator review.
- Facility records are listed for the user's active organisation memberships.
- **Security issue found:** organisation legal names and facility code/name/address/timezone/country/review-status values were interpolated into `innerHTML` without escaping. These values may be partner-controlled, so stored HTML could execute in another authorised warehouse user's browser.
- **Correction:** commit `db04aa10e80aedcc8f38bc4a9017b350d906cf5f` adds HTML escaping for all dynamic organisation option and facility-list fields. User-facing errors continue to use `textContent`.

## Warehouse control centre
- Authenticates the session before loading dashboard information.
- Uses `krim_warehouse_dashboard` and `krim_warehouse_list_tasks` RPCs rather than fabricating metrics.
- Shows actual server-returned task queue and database counts.
- Links to the canonical allocation and reverse-logistics workspaces and to the existing warehouse modules.
- Found duplicate module numbering (two modules labelled 08 and subsequent sequence shifted).
- **Correction:** commit `23ba76a36cd666dd719ba763173baf03557f13fc` fixes the sequence from 09 through 14.

## Legacy routes
- `public/warehouse/warehouse-dashboard.html`, `facility-onboarding.html`, and `facility-profile.html` are noindex redirects to the authenticated warehouse control centre. They are not independent operational workflows.

## Verification and limitations
- Changes committed. Static link audit, production smoke checks and Pages deployment were triggered; poll their final results before marking this batch verified.
- No production facility was registered or activated.
- Database RPC authorization, RLS, multi-organisation isolation and facility approval remain backend-enforced concerns and were not changed here.
- The earlier warehouse blockers remain: return receipt RPC NULL-safe manifest validation; legacy picking-task reservation integrity; and safe cancellation orchestration for unpicked versus already-picked allocations.
