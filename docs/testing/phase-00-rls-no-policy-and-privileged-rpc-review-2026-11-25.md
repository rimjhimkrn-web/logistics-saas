# Phase 00 — RLS No-Policy Table and Privileged RPC Access Review
Date: 2026-11-25
Branch: `qa/phase-00-baseline-2026-11-25`
Scope: Read-only SQL catalog inspection of RLS-enabled tables with no policies, effective table privileges, SECURITY DEFINER function references, selected RPC source, and schema CREATE grants. No rows were inserted, updated, or deleted. No policies, grants, functions, or settings were changed.

## Executive result
**No direct anon/authenticated table privilege was found on the RLS-enabled/no-policy tables inspected.** This is a positive fail-closed signal for direct Data API access. However, the advisor findings remain relevant because privileged SECURITY DEFINER functions can intentionally access these tables; those RPCs must enforce authorization internally and need negative runtime tests.

## 1. Advisor inventory
Supabase security advisor snapshot at 2026-11-25:
- Production: 29 RLS-enabled tables with no policies.
- Staging: 30 RLS-enabled tables with no policies.
- The advisor classifies this particular lint as INFO, not a confirmed exploit.

Catalog reconciliation:
| Environment | Schema | Tables | Anon any table privilege | Authenticated any table privilege | FORCE RLS |
|---|---|---:|---:|---:|---:|
| Production | public | 24 | 0 | 0 | 17 |
| Production | private | 5 | 0 | 0 | 0 |
| Staging | public | 24 | 0 | 0 | 17 |
| Staging | private | 6 | 0 | 0 | 0 |

The public list is:
- `krim_corridor_compliance_controls`
- `krim_corridor_compliance_dossiers`
- `krim_corridor_compliance_events`
- `krim_corridor_compliance_legs`
- `krim_country_operating_packs`
- `krim_country_pack_control_events`
- `krim_country_pack_controls`
- `krim_country_pack_events`
- `krim_inquiry_followups`
- `krim_market_activation_controls`
- `krim_market_activation_events`
- `krim_market_readiness_assessments`
- `krim_market_readiness_events`
- `krim_market_readiness_requirements`
- `krim_market_regulatory_source_events`
- `krim_market_regulatory_sources`
- `krim_partner_compliance_evidence`
- `krim_partner_compliance_reviews`
- `krim_partner_shipment_capacity_commitments`
- `krim_pricing_rate_cards`
- `krim_shipment_leg_custody_transfer_events`
- `krim_shipment_leg_custody_transfers`
- `krim_shipment_leg_dispatch_authorizations`
- `shipment_pod_documents`

Private tables in both environments include `krim_ai_rate_limits`, `krim_payment_capabilities`, `krim_payment_providers`, `krim_payment_transactions`, and `krim_public_inquiry_ip_limits`. Staging additionally has `krim_driver_invitations`.

All inspected tables have RLS enabled. The effective privilege query found no SELECT/INSERT/UPDATE/DELETE privilege for either `anon` or `authenticated` on these no-policy tables. The private schema itself has no USAGE grant to anon; authenticated has USAGE but no CREATE. Public schema CREATE is false for anon, authenticated, and service_role. This reduces the direct exposure and search-path object-creation risks considered in this review.

## 2. Privileged function paths still require scrutiny
Catalog source matching found SECURITY DEFINER functions that reference these tables. Examples:
- Corridor/country-pack controls and dossiers are referenced by platform-admin list/review functions.
- Partner compliance evidence/reviews are referenced by compliance submission and review functions.
- Pricing rate cards are referenced by admin rate-card functions and quote pricing functions.
- Shipment-leg custody tables are referenced by custody transfer and dispatch authorization functions.
- Private payment transaction storage is referenced by a trigger function.

Production has 151 SECURITY DEFINER functions executable by authenticated users overall; staging has 45. These totals are not vulnerability counts. The relevant question is whether each exposed function authenticates the caller, checks the correct organization/permission, validates state transitions and prevents cross-tenant access.

## 3. Selected function source review
The following source-level checks were inspected:

### Platform-admin listing RPCs
- `krim_admin_list_corridor_dossiers()`
- `krim_admin_list_country_packs()`
- `krim_admin_list_partner_compliance_reviews()`
- `krim_admin_list_global_rate_cards()`

The inspected Production definitions require a non-null authenticated user, AAL2, and `admin.platform` permission before returning privileged data. The partner compliance listing includes organization and compliance metadata plus current evidence file paths/metadata, so its runtime access must be restricted to the intended platform-admin role. No anonymous EXECUTE grant was found for these selected functions.

### Inquiry follow-up RPC
`krim_admin_schedule_inquiry_followup(...)` checks authentication, AAL2, `admin.platform`, a valid inquiry, note length, and future follow-up time. It inserts a pending follow-up and moves a new inquiry to in-review. Its return payload explicitly reports `customer_contact_sent: false`; this function alone therefore does not prove the customer notification was sent. The downstream event/notification path must be traced and tested separately to satisfy KRIM's mandatory customer-journey notification requirement.

This function's configured search_path includes `public`, `auth`, and `pg_temp`; schema CREATE is false for anon/authenticated/service_role in Production, which mitigates the common untrusted-object injection path. Still, fully schema-qualified references and a minimal trusted search_path are preferred during any future hardening review.

### Multi-partner custody transfer RPC
`krim_create_leg_custody_transfer(...)` requires an authenticated user, adjacent legs on the same active route plan, a completed releasing leg, active releasing-partner assignment, `partner.manage` permission for the releasing organization, an accepted receiving-partner assignment, confirmed capacity reservation, exact cargo manifest reconciliation, uploader-owned private evidence, and an idempotency key. This is a substantial source-level control set. It has not been executed in runtime tests, and receiving-side authorization / acceptance behavior needs separate negative and positive tests.

## 4. Production–staging function permission drift
For several inspected admin listing/follow-up functions, Production reports authenticated EXECUTE while Staging reports no authenticated EXECUTE. Examples include the country-pack, corridor-dossier, partner-compliance review, global-rate-card listing, and inquiry-follow-up paths. By contrast, the custody-transfer creation RPC is authenticated-executable in both environments.

This is a **staging parity finding**, not proof that Production is insecure or that staging is broken. It may be intentional privilege minimization, incomplete staging migrations/grants, or stale deployment state. Do not copy grants blindly. Resolve against intended role model and the exact workspace page calls before any change.

## 5. Evidence classification
| Check | Result |
|---|---|
| Advisor no-policy counts captured | PASS |
| Effective anon/authenticated table grants checked | PASS — none on listed tables |
| RLS enabled on listed tables | PASS |
| Private schema anon USAGE denied | PASS |
| Public/private schema CREATE denied to anon/authenticated | PASS |
| Selected admin RPCs contain AAL2 + platform permission checks | PASS — source review only |
| Inquiry follow-up sends customer notification | NOT PROVEN; return explicitly says false |
| Custody transfer authorization/state checks | PASS — source review only |
| Positive/negative RPC runtime tests | NOT TESTED |
| Cross-tenant isolation tests | NOT TESTED |
| Full SECURITY DEFINER function review | INCOMPLETE |
| Staging function EXECUTE parity | DRIFT — intended model not yet confirmed |

## 6. Required next work
1. Map each frontend page to the exact RPCs it invokes and confirm the expected user role.
2. Complete source review for the remaining authenticated-executable SECURITY DEFINER functions, prioritizing admin, partner, driver, finance, shipment, payment, document and notification paths.
3. Build staging-only synthetic-user tests for unauthorized user, wrong organization, missing permission, AAL1 vs AAL2, invalid state, replay/idempotency and cross-tenant object IDs.
4. Trace inquiry/booking/shipment milestone events into mandatory notification queues and delivery status. Do not send external messages during tests.
5. Resolve staging function grants only after intended role matrix is documented and tests are ready.

## Safety boundary
All SQL in this review was read-only catalog/source inspection. No production or staging data was modified. No user accounts, policies, grants, secrets, Edge Functions, payments, emails, or notifications were changed or triggered.

## Readiness decision
Direct table exposure for the RLS/no-policy set is **PASS at the inspected privilege layer**. Privileged RPC authorization and staging parity remain **INCOMPLETE**. Phase 00 is not complete; no unrestricted partner/customer onboarding readiness claim is justified. NO EVIDENCE = NO PASS.
