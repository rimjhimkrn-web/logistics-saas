# KRIM Route-Generation Application and Edge-Function Call-Site Review — 2026-11-27

Environment: Repository rimjhimkrn-web/logistics-saas, intended branch staging/phase00-env-isolation. Review is read-only. Production untouched.

## Scope and method
- Inspected the staging branch tree and source blobs available through the GitHub repository interface.
- Reviewed the driver GPS upload function, driver tracking-session function and public shipment tracking function.
- The retrieved source tree exposed a limited set of 23 TypeScript/JavaScript/HTML source files, with no customer/partner workspace HTML/JS files in the inspected tree snapshot. This is not a complete frontend inventory.
- GitHub code-search returned no matches for the internal transit/arrival function names and route-leg table names, but that search indexes the default branch, not necessarily the target staging branch. Therefore, zero results are not proof of no callers.
- Database function-body scan previously found no direct stored-function references to internal start/arrival routines. Dynamic SQL, triggers, scheduled jobs, Edge Functions and application-side calls remain possible.

## Edge Function findings

### functions/krim-driver-gps-update/index.ts
- Contains an explicit two-part launch gate: KRIM_GPS_TRACKING_ENABLED must be true and KRIM_GPS_TRACKING_LEGAL_APPROVAL_VERSION must match the notice version.
- The notice approval constant is false and the notice itself states it is a draft; GPS uploads therefore remain paused even if an environment flag were accidentally set.
- The function has no direct references to krim_internal_start_shipment_transit, krim_internal_arrive_shipment, krim_shipment_legs, krim_shipment_leg_plan_items or krim_authorize_leg_dispatch.
- GPS upload is a separate evidence/telemetry path and does not establish route-generation lifecycle correctness.

### functions/krim-driver-tracking-session/index.ts
- References shipment_leg_id in its assignment/session data flow.
- No direct references found to the two internal transit/arrival routines, route-plan item table or dispatch authorization RPC in the inspected source.
- Session-level linkage to shipment_leg_id is not equivalent to enforcing current-generation membership; that must be validated in the authoritative database routines.

### functions/public-shipment-tracking/index.ts
- Reads shipment-level tracking and public tracking data via service-role client.
- Does not directly reference the two internal transit/arrival routines, operational leg table, route-plan item table or dispatch authorization RPC in the inspected source.
- Public tracking remains shipment-level in this function; it does not expose route-generation history in the inspected implementation.

## Call-site conclusion
- No direct caller was identified in the three inspected tracking-related Edge Functions.
- This is a bounded negative finding only. It does not close the full Edge Function inventory or frontend call-site inventory.
- The internal transit/arrival routines remain unverified for application call sites. Continue searching every deployable Edge Function and all staging-branch frontend source before editing or retiring them.

## Required next work
1. Obtain a complete staging-branch recursive tree and verify its commit SHA matches the latest staging commit before declaring frontend coverage.
2. Inspect all deployable Edge Functions, including admin, notification, provisioning and any operational workflows.
3. Search frontend workspace source for route-plan RPC names, direct .from('krim_shipment_legs') calls, shipment_leg_id writes and legacy shipment-wide status actions.
4. Inspect database triggers/jobs and all call chains that can reach the internal transit/arrival routines.
5. Keep GPS collection disabled until the consent notice, retention schedule, deletion/legal-hold controls and legal approval are complete.
6. Do not implement generation migration until the complete call-site map and generation-aware tests are ready.

## Status
- Three tracking-related Edge Functions inspected: PASS (bounded).
- No direct references in those three files: PASS (bounded negative finding).
- Full Edge Function inventory: OPEN.
- Frontend call-site inventory: OPEN.
- Database trigger/job call-site inventory: OPEN.
- Route-generation migration: NOT STARTED.
- Runtime JWT E2E: PENDING.
- Phase 00: OPEN — NOT APPROVED.
