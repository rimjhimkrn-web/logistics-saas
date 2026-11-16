# KRIM Exact-Leg Partner Sourcing — Production Readiness Check
**Date:** 16 November 2026  
**Scope:** Latest repository migrations for exact-leg partner opportunity creation, partner quote submission, customer quote award and exact-leg assignment; live production migration metadata, table counts and RPC grants.  
**Method:** Read-only GitHub source inspection and read-only production SQL. No migration, DDL, test shipment, quote, assignment, partner approval or financial operation was created.

## Executive result
The repository contains a new exact-leg partner sourcing implementation, but production migration history has not advanced to these migration versions. Production currently reports latest migration version `20261115231834` (`require_warehouse_handover_before_leg_dispatch`). The repository contains subsequent migrations beginning `20261116002000` through at least `20261116028000`. The exact-leg workflow must therefore be treated as **not proven deployed from the checked-in migration lineage**.

Production catalog inspection independently shows three SECURITY DEFINER RPCs with authenticated execution and no anon execution:
- `krim_create_leg_partner_opportunity`
- `krim_submit_leg_partner_quote`
- `krim_award_leg_partner_quote`

This is not sufficient proof that the live definitions match the repository migrations. The live migration history and repository lineage are already known to be materially divergent; do not apply or replay these migrations until the migration-recovery gate is resolved and live function definitions are compared.

## Production data snapshot
Read-only counts:
| Record | Rows |
|---|---:|
| Shipment leg plans | 0 |
| Shipment leg plan items | 0 |
| Leg-scoped partner opportunities | 0 |
| Leg-scoped partner quotes | 0 |
| Leg-scoped assignments | 0 |
| Active route plans | 0 |

Therefore, there is no real exact-leg sourcing transaction or route-plan record to demonstrate this workflow in production.

## RPC execution grants
Production catalog returned:
| RPC | SECURITY DEFINER | anon EXECUTE | authenticated EXECUTE |
|---|---:|---:|---:|
| `krim_create_leg_partner_opportunity` | yes | no | yes |
| `krim_submit_leg_partner_quote` | yes | no | yes |
| `krim_award_leg_partner_quote` | yes | no | yes |

The source files use an empty search_path and schema-qualified objects. This is a positive hardening pattern, but the actual deployed function body, dependent private helper definitions and table-level grants must be verified before production use.

## Source review — strengths
1. Leg-scoped opportunities are required to reference a plan-linked leg in the same shipment.
2. Partner quote rows inherit exact leg scope from the referenced opportunity.
3. Quote submission requires an authenticated active member of a registered-business partner organization, current compliance, active verified capability, `quote.create`, active currency and an unexpired open opportunity.
4. Quote submission rechecks the active route plan and exact leg sequence, origin, destination and mode.
5. The current implementation fails closed for any non-empty cargo requirement JSON until a verified requirement-to-capability evaluator exists.
6. Award requires customer organization access and quote/shipment update permissions; rechecks partner verification, compliance, exact-leg capability, route-plan integrity and shipment state.
7. Development/test partners cannot receive commercial assignments.
8. An active assignment unique index and row locks protect against multiple assignments to the same leg.
9. Shipment-wide dispatch is separately blocked for active multi-leg plans; dispatch must proceed per leg.

## Unresolved concerns and required verification
1. **Migration lineage mismatch:** production migration history ends at `20261115231834`, while the checked-in exact-leg migrations are dated 16 November. The live RPCs exist, but their bodies cannot be assumed to match the repository.
2. **No production route-plan evidence:** zero plans, items, leg opportunities, quotes or assignments. Do not advertise multi-leg sourcing as operational.
3. **Quote amount/currency policy:** validate currency minor-unit precision, decimal scale, rounding and amount limits per currency; current RPC accepts a generic numeric amount and active three-letter currency code.
4. **Quote idempotency/concurrency:** source updates an existing active quote for the same partner/opportunity/leg, but staging tests must cover concurrent submissions, retries, expired quotes and quote history/audit preservation.
5. **Award/assignment lifecycle:** staging must test simultaneous customer awards, existing offered/accepted/completed assignments, partner acceptance expiry, cancellation/revocation, and the consistency of quote, opportunity, assignment and leg states.
6. **Tenant isolation:** test customer A cannot award customer B's quote/opportunity; partner A cannot read or alter partner B's quote; no cross-tenant IDs or SECURITY DEFINER bypasses.
7. **Exact route/capability:** test country, origin/destination, mode, weight, effective dates, expired/revoked evidence and route-plan version changes.
8. **Special cargo:** any non-empty requirements are currently blocked by the quote RPC; this is an appropriate fail-closed control until a verified evaluator is available.
9. **Audit integrity:** confirm every state transition writes immutable actor, organization, source, timestamps and before/after context; test audit insert failure handling.
10. **Migration recovery:** recover exact production SQL/export and reconcile all missing/extra/duplicate migration versions before any migration is applied.

## Decision
**Status: Engineering source exists; production operational readiness not established.** Do not use exact-leg sourcing for a live commercial shipment until migration recovery, live function-body comparison, staging acceptance tests, a genuinely verified carrier, a verified route/capacity record and an independently reviewed partner-direct commercial agreement are complete.

The intended initial pilot remains a single simple domestic road corridor only after the provider and actual route/capacity are confirmed. Customer freight contract and payment remain directly between customer and provider; any KRIM referral/coordination fee is separate, evidenced and subject to qualified tax review.

**No production mutation was performed.**
