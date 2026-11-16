# KRIM Canonical Shipment Creation vs Live Corridor Gate — P0 Integrity Finding
Date: 2026-11-16

## Executive finding
**P0 — canonical shipment creation is incompatible with the active live corridor-compliance trigger.** The production canonical RPC `public.krim_create_global_shipment(bigint,bigint,bigint,text,numeric)` inserts a shipment without `requested_transport_mode`. The live `BEFORE INSERT` trigger `krim_enforce_corridor_compliance_before_shipment_write` calls `private.krim_enforce_corridor_compliance_on_shipment_write()`, which rejects any new shipment whose `requested_transport_mode` is null/blank. Therefore the canonical five-argument booking RPC cannot satisfy the trigger's required input and shipment creation is expected to fail closed.

This is a direct incompatibility between the live function body and the active trigger, not merely a missing UI field.

## Evidence collected (read-only)
Production Supabase catalog inspection:
- Function signature: `krim_create_global_shipment(bigint,bigint,bigint,text,numeric)`.
- Function inserts into `public.krim_shipments(customer_organization_id,origin_location_id,destination_location_id,goods_description,total_weight_kg,status)`.
- The insert omits `requested_transport_mode`.
- Live table includes `requested_transport_mode` (nullable, no default observed).
- Enabled trigger: `krim_enforce_corridor_compliance_before_shipment_write`.
- Trigger fires `BEFORE INSERT OR UPDATE OF origin_location_id, destination_location_id, requested_transport_mode`.
- Trigger function rejects a null/blank requested mode and then requires an exact active origin/destination corridor, approved corridor dossier, matching mode, current mandatory regulatory controls and approved country operating packs.
- Additional active shipment triggers include market activation, initial leg creation, readiness, dispatch/capacity and audit triggers.

Repository source inspection:
- `supabase/migrations/20261105114500_enable_secured_customer_shipment_booking_rpc.sql` grants authenticated execution of the five-argument canonical RPC and revokes anon.
- `supabase/migrations/20261105001500_enforce_corridor_dossier_on_shipment_writes.sql` defines the strict mode/corridor gate.
- `supabase/migrations/20261104230000_krim_global_corridor_compliance_engine.sql` defines the evidence-first corridor dossier/control model.

No shipment-creation RPC was invoked to test this. No production data, schema, permissions or business records were changed.

## Required remediation design (not applied)
1. Reconcile migration history and exact live function signatures first; do not replay or baseline migrations.
2. Introduce a canonical booking RPC version that accepts a required transport-mode code as an explicit argument, validates it against active `krim_transport_modes`, and writes it into `krim_shipments.requested_transport_mode` atomically with customer organization, origin, destination, cargo description and weight.
3. Preserve all existing authorization and activation gates: authenticated customer membership, `shipment.create`, active locations/countries, market readiness, exact approved corridor/dossier, mode match, current mandatory regulatory sources and country pack controls.
4. Retire or revoke execution from obsolete overloads only after all application callers and integrations are updated and verified.
5. Update the canonical customer booking UI to require a mode selected from the authoritative active mode catalogue; never infer a mode from free-text cargo or route.
6. Add staging tests: missing mode rejected; inactive/unknown mode rejected; wrong corridor/mode rejected; unapproved or expired corridor controls rejected; inactive market rejected; authorized valid-mode request reaches draft only when all gates pass; unauthorized tenant and missing permission rejected.
7. Verify initial shipment leg creation captures the same mode and route, and test retries/idempotency before production rollout.

## Release impact
- Shipment booking remains **NO-GO** until the RPC/trigger contract is reconciled and the above negative/positive staging tests pass.
- Do not weaken or disable the corridor trigger to make booking work. The correct repair is to make the canonical booking contract supply and validate the required mode.
- This finding also reinforces the migration-history reconciliation blocker: no production DDL or function replacement is authorized by this audit.

## Evidence boundaries
Read-only catalog inspection and source review only. Expected booking failure is inferred from the verified function body plus active trigger definition; no live booking attempt was made. This report is not an end-to-end operational certification.
