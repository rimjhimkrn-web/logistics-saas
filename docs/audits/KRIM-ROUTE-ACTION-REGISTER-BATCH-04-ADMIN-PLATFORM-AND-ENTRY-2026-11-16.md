# KRIM Route-and-Action Register — Batch 04: Admin, Platform Admin and Application Entry
**Date:** 16 November 2026  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Scope:** Static inspection of 19 platform-admin pages, the admin vehicle-verification page, field entry, and five application/authentication entry pages. No live administrative or account actions executed.

## Platform administration routes

| Page | Direct source calls/data observed | Verification focus |
|---|---|---|
| `platform-admin/capacity-resources.html` | `krim_admin_list_capacity_resources_lane_aware`, `krim_admin_review_capacity_resource`; `global-admin-control`; MFA | Capacity evidence, lane/geography scope, freshness, reviewer independence; approved resource is not an actual reservation. |
| `platform-admin/claims-review.html` | `krim_has_permission`, `krim_claim_review`; reads claims/evidence/events, org membership; private verification bucket; AAL2 | Claim ownership, evidence integrity, reviewer independence, conflict handling, immutable decision history. |
| `platform-admin/commercial-pricing.html` | `krim_admin_list_global_rate_cards`; reads countries/currencies; AAL2 | Rate-card approval, currency/market applicability, effective dates, partner/customer visibility, no unapproved price promise. |
| `platform-admin/corridor-compliance.html` | Corridor catalogue/dossier list/get/create, control review and dossier status RPCs; AAL2 | Evidence provenance, competent reviewer, expiry, jurisdiction coverage and fail-closed activation. |
| `platform-admin/country-packs.html` | Country pack/regulatory source list/get/review/status RPCs; AAL2 | Country operating pack remains research-only until authoritative sources, controls and approval are complete. |
| `platform-admin/customs-broker-review.html` | Broker close/assign/licence-review RPCs; reads broker licences/events, organizations, countries, customs cases/assignments; private evidence bucket; AAL2 | Licence validity, jurisdiction, assignment scope, close/withdraw reasons and audit trail. |
| `platform-admin/delivery-pod-verification.html` | POD list/review RPCs; `global-admin-control`; private driver-evidence bucket; MFA | Independent POD reviewer, assignment/tenant binding, tamper-resistant evidence and restricted signed access. |
| `platform-admin/driver-verification.html` | Driver verification/expiry list and document review RPCs; private driver-verification bucket; AAL2 | Identity/licence expiry, evidence authenticity, reviewer independence and immediate suspension on expiry. |
| `platform-admin/global-country-market-management.html` | `krim_admin_global_country_foundation_overview`; AAL2 | Metadata listing is not market activation; enforce complete country/corridor controls before enabling operations. |
| `platform-admin/index.html` | `global-admin-control`; MFA/AAL2 | Global admin entry must enforce elevated assurance, least privilege, scoped actions and auditable navigation. |
| `platform-admin/market-activation.html` | `krim_admin_list_market_activation`; AAL2 | Readiness display must not itself enable a market; activation must require all approved operating prerequisites. |
| `platform-admin/market-readiness.html` | Market readiness list and assessment-setting RPCs; AAL2 | Assessment evidence, reviewer identity, current sources and fail-closed readiness rules. |
| `platform-admin/network-lanes.html` | Corridor catalogue, network lane list/create draft/review RPCs; reads locations/modes; `global-admin-control`; AAL2 | Draft vs approved lane distinction, endpoint validity, corridor dossier/control linkage and independent review. |
| `platform-admin/partner-compliance.html` | Partner compliance list/review RPCs; private verification bucket; AAL2 | Current compliance evidence, expiry, partner scope, suspension and review audit. |
| `platform-admin/partner-service-areas.html` | Partner service-area list/review RPCs; `global-admin-control`; private verification bucket; AAL2 | Verified partner evidence, bounded geography, transport/service scope and no implied coverage outside approved area. |
| `platform-admin/regulatory-sources.html` | Market readiness/regulatory source list/register/review RPCs; AAL2 | Source authority, publication/effective date, jurisdiction, supersession, reviewer and source refresh cadence. |
| `platform-admin/support-desk.html` | Support ticket list/thread/reply/transition RPCs; `global-admin-control`; MFA | PII minimization, tenant boundaries, role-based visibility, attachment controls, response audit and safe status transitions. |
| `platform-admin/warehouse-facilities.html` | Warehouse facility list/review RPCs; `global-admin-control`; MFA | Facility ownership, location, operating scope, safety/compliance evidence and independent approval. |
| `platform-admin/warehouse-operations.html` | Warehouse operations list RPC; `global-admin-control`; private warehouse-evidence bucket; MFA/AAL2 | Read-only oversight boundary, tenant/warehouse scope, QC evidence and private evidence access. |

## Other admin and entry pages
- `app/admin/vehicle-verification.html`: MFA/AAL2 signals and private `krim-partner-verification` storage; no literal RPC or Edge Function call found. Trace shared scripts and confirm the actual review/approval path before relying on it.
- `app/field/index.html`: minimal field entry page; no literal Supabase RPC, table, Edge Function or auth signal found in the HTML scan. Confirm whether it is a shell/redirect or an incomplete entry point.
- `app/index.html`: reads organization membership, locations and shipments with session check. Ensure initial dashboard queries are tenant-scoped and do not leak cross-org shipment or location data.
- `app/sign-in.html`, `app/register.html`, `app/forgot-password.html`, `app/reset-password.html`: lightweight authentication pages. Static scan found no direct `supabase.auth.*` method calls, suggesting shared auth script/indirect handlers; trace the complete flows, recovery-token validation, redirect allow-list, password policy and session revocation. Do not assume authentication is complete based on the forms alone.

## Critical system-level observations
1. **Administrative approval chain:** Many pages invoke high-impact admin RPCs or the `global-admin-control` Edge Function. Enforce role + permission + AAL2 server-side on every mutation, not just in the UI.
2. **No self-approval:** Partner, driver, vehicle, capability, compliance, facility, broker, customs, claim and POD evidence should require an independent reviewer for high-risk approval.
3. **Market activation is gated:** Prior production audit found 249 country operating packs in `research_pending`, no approved corridor compliance dossiers and no corridor controls. Admin pages do not change that baseline by existing.
4. **Capacity is not execution:** Resource review, partner capability, service-area approval and network lane approval are separate controls. None alone confirms capacity or dispatch readiness.
5. **Evidence storage:** Private buckets require server-side object path validation, tenant/record binding, MIME/size checks, malware/content validation, retention and short-lived signed access.
6. **Shared auth uncertainty:** The absence of literal auth/RPC calls in some HTML pages is not proof of missing functionality; imported/shared scripts and runtime handlers must be traced.
7. **Admin vehicle page:** Its storage-only literal scan is insufficient to certify document review or vehicle authorization.
8. **Field entry:** The field page needs a clear supported user journey and access model before being counted as an operational workspace.
9. **Support desk:** Support tooling must not grant broad cross-tenant data access simply because an operator can view a ticket.
10. **Authentication recovery:** Password reset and recovery must bind to a valid, unexpired recovery session, prevent open redirects and invalidate/revoke appropriate prior sessions.

## Required staging tests
- Non-admin, admin-without-specific-permission and AAL1 sessions cannot invoke elevated admin mutations.
- AAL2 admin can act only within assigned scope; all decisions record actor, reviewer, reason, evidence hashes and before/after state.
- Submitter cannot approve their own partner, driver, vehicle, capability, compliance, broker, warehouse facility, claim or POD record.
- Expired, superseded or untrusted regulatory source cannot satisfy market/corridor readiness.
- Market/corridor activation fails closed when any country pack, dossier, corridor control, customs requirement or independent approval is missing.
- Partner service-area and network-lane approvals are bounded to explicit mode, geography, effective dates and partner authorization.
- Support desk agents cannot access unrelated tenants, finance records, private evidence or secrets.
- Private evidence access rejects guessed object keys, cross-tenant paths, stale signed URLs and wrong record linkage.
- Sign-in, registration, reset and recovery are tested end-to-end for expired tokens, replay, enumeration resistance, redirect allow-list and session invalidation.
- Field entry routes only to an authorized, supported workspace and rejects anonymous or wrong-role access.
- Dashboard first paint and background queries remain tenant-scoped under two-tenant test fixtures.

## Release status
**Not certified.** This is static route/action evidence and a staging test plan, not an execution or security certification. No administrative approval, market activation, partner approval, capacity reservation, customs clearance, shipment or financial transaction was performed. Production schema changes remain blocked pending migration reconciliation. Live revenue setup remains deferred to the final phase.
