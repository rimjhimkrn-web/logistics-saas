# KRIM Fast-Track Day 01 — Partner Capability Read RPC Authorization and Catalogue ACL Recheck
Date: 2026-11-28
Target: KRIM Logistics Staging (`qrpcivhdxobiaofppbkl`)
Branch: `staging/phase00-env-isolation`
Production: not accessed or changed

## Read-only Staging recheck
Executed catalog-only SQL against Staging. No rows were created or changed.

### Organization-type allowlist
The live CHECK constraint on `public.krim_organizations.organization_type` permits exactly:
- `customer`
- `partner`
- `enterprise`
- `carrier`
- `warehouse`
- `forwarder`
- `platform`
- `customs`
- `finance`
- `operations`

The proposed partner-facing allowlist `partner`, `carrier`, `warehouse`, `forwarder` is consistent with the database enum/check constraint, but remains a product/authorization decision requiring owner review. A permitted database value alone does not prove every organization of that type should access partner capability records. The only current Staging organization is `platform`; no partner/customer test organizations exist.

### Permission catalogue
The exact permission rows exist:
- `partner.manage` — “Manage Partners”, resource type `partner`, action `manage`, system permission.
- `admin.platform` — “Platform Administration”, resource type `platform`, action `admin`, system permission.

The previously inspected `private.krim_has_permission(uuid,bigint,text)` also checks matching active role assignment, active organization membership and active organization. The proposed RPC must still explicitly validate the partner organization type before calling this helper.

### Catalogue table grants
Fresh direct privilege checks returned:
| Table | RLS enabled | authenticated SELECT | anon SELECT |
|---|---:|---:|---:|
| `public.krim_countries` | yes | no | no |
| `public.krim_transport_modes` | yes | no | no |
| `public.krim_partner_capabilities` | yes | no | no |

The existing Partner Services & Capabilities page directly queries all three tables after authentication. Consequently, the authenticated catalogue reads described in the earlier implementation design are not currently supported by direct table grants. This is a source/ACL mismatch to resolve deliberately: either grant authenticated SELECT on only the two public reference catalogues while preserving their existing read-only RLS policies, or replace the frontend reads with a narrowly scoped read RPC. Do not grant direct SELECT on `krim_partner_capabilities`.

No grant was issued. Data API exposed-schema configuration remains unverified in the Staging Dashboard, so this ACL result alone does not establish that the REST endpoint is exposed.

## Updated implementation requirements
1. Owner confirms the four-type partner organization allowlist (or supplies a narrower list).
2. Owner verifies Staging Data API exposed schemas and extra search path.
3. Choose one catalogue access design: narrow authenticated SELECT on `krim_countries` and `krim_transport_modes`, or a bounded catalogue RPC. Keep anonymous access denied.
4. Keep `krim_partner_capabilities` direct authenticated/anon SELECT denied; expose only minimized rows through the new authorization-checked RPC.
5. Add explicit tests for each allowed organization type and for customer, enterprise, platform, customs, finance, and operations denial, as well as cross-tenant denial.
6. Obtain real independent Partner A and Partner B JWT sessions before claiming tenant isolation. Do not use service-role impersonation as a substitute.

## Gate status
- Live organization type constraint: verified read-only.
- Permission codes and descriptions: verified read-only.
- Catalogue direct SELECT ACL: verified denied for authenticated and anon.
- Proposed partner type allowlist: technically valid but owner/product confirmation pending.
- New RPC, grants, fixtures, tests, and migration: not created/applied.
- Local database harness and Staging Data API exposure: still blocked.
- Phase 00: OPEN — NOT APPROVED.
- Production: NOT ACCESSED OR CHANGED.
