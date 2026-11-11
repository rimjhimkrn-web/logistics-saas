# KRIM Staging Schema Parity Check — Booking Lifecycle
Date: 2026-11-11
Project: KRIM Logistics Staging (`qrpcivhdxobiaofppbkl`)
Production reference: `ebltviniygljwwseplph`
Status: READ-ONLY PREFLIGHT — NO MIGRATIONS APPLIED

## Result: staging is not ready for booking lifecycle implementation

The Supabase account contains a separate project named **KRIM Logistics Staging**, status ACTIVE_HEALTHY, in ap-south-1. It is not a populated copy of production.

Read-only catalog inspection found:
- No public application tables.
- No public application functions.
- No booking lifecycle RPCs.
- No booking lifecycle triggers.
- Supabase migration history returned an empty list.

A query for the seven required lifecycle functions returned zero rows:
- `krim_award_partner_quote(bigint)`
- `krim_award_partner_quote_for_checkout(bigint,timestamptz)`
- `krim_partner_respond_to_invitation(bigint,text,numeric,text,timestamptz,text)`
- `krim_respond_to_partner_assignment(bigint,boolean,text)`
- `krim_accept_global_quote(bigint)`
- `krim_internal_finalize_partner_assignment(bigint)`
- `krim_internal_evaluate_shipment_readiness(bigint)`

The staging project is therefore a blank project, not a staging clone with production schema parity. Running the proposed booking migration there would fail or create an incomplete and misleading test environment.

## Required next step

Before implementation tests, establish a reproducible schema baseline. The production migration history and repository migration folder previously showed significant drift (425 production history records, 263 repository SQL migrations, only 64 exact version overlaps). Do not blindly replay the repository migrations or copy production data.

A safe staging bootstrap must:
1. Export a schema-only snapshot from production using an approved Supabase CLI/database workflow, excluding all production data, secrets, auth users, storage objects and payment credentials.
2. Review the snapshot for secrets, production endpoints, external webhook URLs, scheduled jobs, and any destructive or environment-specific statements.
3. Reconcile migration history without falsely marking unapplied SQL as applied.
4. Restore schema into staging and verify extension, role, grant, RLS, trigger, function, storage bucket and auth configuration dependencies.
5. Seed synthetic customer/partner/driver organisations and quote/assignment fixtures only.
6. Run lifecycle preflight and regression tests against that verified staging baseline.

## Safety
- No SQL migration, DDL, data write, edge function deployment, branch merge, or production setting change was performed.
- No production data was copied.
- No booking/payment workflow was enabled.
- Do not describe staging as ready until schema parity and synthetic fixtures are verified.
