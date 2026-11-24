# KRIM partner capacity tenant-boundary test — 2026-11-24

## Result: blocked by empty staging reference catalog; no unsafe fixture fabrication

The staging implementation of `public.krim_partner_register_capacity_resource(bigint,text,text,bigint,bigint,numeric,text,text,timestamptz,timestamptz,text[],text)` was inspected read-only.

The function's authorization sequence is meaningful:
- Requires an authenticated actor.
- Requires active membership in the exact target organization and `partner.manage` permission.
- Requires the target organization to be an approved partner-type entity with current compliance.
- Requires an active transport mode, active location, and separately verified active capability for that mode and the location's country.
- Requires 1–5 unique private evidence paths owned by the submitting user and stored under the target organization's folder.
- Creates the resource in `pending_review` and availability as `unavailable`; it does not publish partner-reported capacity as bookable.

A two-user cross-organization negative test was prepared in a transaction using the actual registration RPC. It could not reach the authorization call because staging has no active transport mode and no active location. The test stopped at the explicit fixture guard before any RPC write. The SQL tool rolled back the transaction after the guard exception.

Post-attempt staging counts: 1 Auth user, 0 organizations, 0 capacity resources, 0 capacity availability rows. This matches the known empty staging baseline. No synthetic records remain.

## Safe next step

Do not fabricate a verified partner, approved capability, compliance status, or private evidence document merely to make this test pass. Rebuild a controlled staging reference fixture only after the canonical catalog schema/seed path is reconciled. Then run two-user tests:
1. Tenant B cannot register capacity against Tenant A's organization.
2. A legitimate registered/compliant partner can submit evidence and receives only `pending_review` / `unavailable` state.
3. A different authorized reviewer can approve only after independent compliance, capability, future availability, and private evidence checks.

No production data, schema, policy, grant, or partner status was changed.
