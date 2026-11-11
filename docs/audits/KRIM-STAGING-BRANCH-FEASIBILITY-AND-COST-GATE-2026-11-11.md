# KRIM Staging Environment — Branch Option and Cost Gate
Date: 2026-11-11
Status: READ-ONLY FEASIBILITY CHECK — NO BRANCH CREATED

## Current environments

- Production project: `ebltviniygljwwseplph`, active and healthy.
- Separate staging project: `qrpcivhdxobiaofppbkl`, active and healthy, but its database currently has zero application tables, zero application functions and zero migration history.
- Production migration history: 425 records.
- Repository SQL migrations: 263; earlier comparison found only 64 exact version overlaps. The production-only/repository-only gap means repository replay is not a safe schema-cloning method without reconciliation.
- Existing Supabase branch list shows only the default `main` branch; no additional test branch exists.

## Supabase development-branch option

The Supabase branch capability can create an isolated development database associated with production. Tool documentation says the branch applies migrations from the main project and does not copy production data. This is potentially safer than trying to populate the blank staging project manually, but it is not yet approved or proven to recreate KRIM's actual live schema.

Because production and repository migration histories materially diverge, a new branch must not be assumed to be schema-identical. Before using it for lifecycle testing, compare its resulting schema/functions/policies/triggers/extensions against the production catalog. Do not use production customer, shipment, payment, auth or storage data; use synthetic fixtures only.

## Cost returned by Supabase

For the user's existing Supabase organisation, the branch quote returned:
- USD $0.01344 per hour.
- Approximate 30-day continuous cost: USD $9.68, excluding any other usage or taxes.

This is recurring hourly compute while the branch exists/runs. It is not a one-time fee. The user has not approved this cost, so no branch was created.

## Recommendation

Do not create the branch until the user explicitly approves the hourly cost. If approved, create one temporary branch, verify its schema parity, run the booking lifecycle regression suite with synthetic data and test-only payment credentials, then delete the branch when testing is complete to stop ongoing compute charges. Do not merge the branch to production.

If the user does not approve the cost, keep the current separate staging project unchanged and continue repository-only static analysis until a no-cost, trustworthy schema bootstrap path is available.

## Safety status

- No branch created.
- No project created, paused, restored or deleted.
- No production or staging SQL applied.
- No database settings, migrations, functions, secrets, auth users, payment records or operational records changed.
