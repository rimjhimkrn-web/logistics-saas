# KRIM Global Corridor Compliance Engine

**Implementation record — 4 November 2026**

## Purpose

This engine provides an evidence-led administrative workflow for researching proposed origin → transit jurisdiction → destination corridors. A catalogue record is not a route approval, transport service promise, legal opinion or market activation.

## Production components

- Four tables: `krim_corridor_compliance_dossiers`, `krim_corridor_compliance_legs`, `krim_corridor_compliance_controls`, and `krim_corridor_compliance_events`.
- Forced row-level security on all four tables; direct anon/authenticated table access revoked.
- Six authenticated-only admin RPCs, each checking authenticated identity, AAL2 and `admin.platform` permission.
- A private workspace at `app/platform-admin/corridor-compliance.html`, linked from the Control Centre.
- Twelve mandatory review domains for each jurisdiction leg: entity eligibility, transport permits, customs/trade, cargo admissibility, sanctions/export controls, tax/payments/FX, insurance/liability, privacy/data transfers, workforce/safety, environment, border/transit and local operations.
- Control decisions require a reviewed jurisdiction-matched source, evidence reference, rationale, resolved applicability and review status. Legal/tax-sensitive domains require a qualified, legally reviewed opinion.
- Dossier approval is blocked unless all mandatory corridor controls and all mandatory country-pack controls across the route are approved, evidenced, sourced and current.

## Candidate catalogue records

Seven draft candidates are present using existing active location catalogue records: Ranchi–Kolkata, Ranchi–Jamshedpur, Ranchi–Dubai, Ranchi–Frankfurt, Ranchi–London, Ranchi–Singapore and Ranchi–New York. These are **proposed origin-destination pairs only**. No route geometry, transit jurisdictions, mode, permit, partner, serviceability or commercial availability is implied. All remain `draft` and not open for booking.

## Current verification

- Four corridor tables have RLS enabled and forced.
- Six admin RPCs deny anon execute and allow authenticated execute; each function independently checks AAL2 and platform-admin permission.
- Workspace JavaScript syntax passed.
- Seven draft catalogue candidates are present.
- No dossiers or corridor controls have been created; no corridor or country pack is approved.
- Signed-in AAL2 browser testing, source-entry/review positive testing and full transaction-level corridor enforcement tests remain outstanding.
- Security Advisor warnings for privileged SECURITY DEFINER functions require ongoing manual review.

## Not yet implemented by this engine

This dossier workflow does not itself provide live sanctions screening, customs/tariff calculation, permit issuance, route geometry/optimization, border status, cargo classification, insurance validation, verified provider capacity, driver/vehicle compliance, payment/FX authorisation, data-transfer assessment at transaction time, or a booking activation. Those require separate authoritative integrations and runtime gates. Country-pack approval and market activation remain separate.

## Repository migration history

- `supabase/migrations/20261104230000_krim_global_corridor_compliance_engine.sql`
- `supabase/migrations/20261104234500_seed_proposed_corridor_catalogue.sql
- `supabase/migrations/20261104234500_seed_india_domestic_pilot_corridor_candidate.sql``

The production changes were applied before the repository migration files were committed. On a fresh environment, apply the migration sequence in timestamp order and verify referenced base schemas and permissions first.

## Shipment write-boundary enforcement

A private database trigger now runs on shipment INSERT and on changes to origin, destination or requested transport mode. It rejects writes unless an exact active origin/destination corridor exists with an approved corridor dossier and a matching transport mode. It re-checks every mandatory corridor control, its evidence/rationale, expiry and current reviewed source, and re-checks every mandatory country-pack control for every jurisdiction leg. This gate is independent of the existing market activation trigger and partner capability checks.

A negative test updated an existing shipment's requested mode without an approved matching corridor; the database rejected the write with the expected check-violation path. No shipment data was changed. This is a negative control only; no positive route can be tested because there are no approved corridor dossiers, country packs or active providers.


## Latest performance and security-advisor follow-up

Added covering indexes for the twelve foreign keys reported by the performance advisor and changed the two driver-document RLS policies to evaluate `auth.uid()` through a scalar subquery. The subsequent performance-advisor snapshot no longer reported unindexed foreign keys or auth RLS initialization-plan findings. It still reports 16 multiple-permissive-policy warnings and many unused-index informational findings; unused indexes were not bulk-dropped because the system has not yet accumulated production workload.

The latest security-advisor snapshot reports 21 RLS-enabled/no-policy informational findings (including intentionally RPC-only tables), 73 authenticated SECURITY DEFINER function warnings requiring manual code review, and leaked-password protection disabled. The corridor and country admin RPCs perform their own identity, AAL2 and platform-permission checks, but this does not substitute for a complete review of every privileged function or enabling leaked-password protection in Supabase Auth settings.
