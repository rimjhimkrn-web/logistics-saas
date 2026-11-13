# Step 23 — Isolated staging readiness and migration-parity audit

Date: 2026-11-13
Production project: `ebltviniygljwwseplph`
Staging project: `qrpcivhdxobiaofppbkl`
Repository branch: `website/global-launch-readiness`
PR: #65 (draft, unmerged, undeployed)

## Verified environment state

Staging project `KRIM Logistics Staging` is reachable and reports `ACTIVE_HEALTHY` (Postgres 17.11, ap-south-1). It currently has:
- 0 applied database migrations;
- 0 public tables;
- no populated application schema to run booking/partner lifecycle tests against.

Production project `logistics-saas` is also `ACTIVE_HEALTHY` (Postgres 17.6, ap-northeast-1) and has 425 applied migrations.

The current repository branch contains 265 SQL migration files under `supabase/migrations/`. This is not a complete migration chain for the current production database. The production migration history contains timestamped entries that do not correspond one-for-one with the repository's consolidated/renamed migration files; the branch also contains newer proposal migrations not applied to production. A raw replay of the repository directory is therefore not a safe staging bootstrap.

## Decision: do not bootstrap staging by blindly replaying migrations

No migrations were applied and no staging or production data was changed. Do not:
- replay all 265 repository migrations into the empty staging project;
- copy production customer, partner, shipment, payment, identity, document, or financial data into staging;
- use live Razorpay/Telegram/Resend credentials or production webhooks in staging;
- create fake production partners or customer enquiries;
- point the production website or clients at staging.

A safe staging bootstrap needs an authoritative schema snapshot/export from the exact production schema state, reviewed migration baseline, and separate test-only secrets/configuration. The snapshot must exclude production business data and sensitive identity/document content. The baseline and any subsequent migrations must be reconciled against production's 425-entry migration history before execution.

## Required safe staging preparation sequence

1. Freeze the exact production schema/migration-history reference and branch commit used for the exercise.
2. Produce a schema-only export from production through an approved Supabase workflow; exclude all business rows, auth users, storage objects, payment identifiers, provider secrets, and private documents.
3. Reconcile the schema snapshot against the 425 production migration-history entries and the 265 repository migration files. Resolve missing, squashed, renamed, and proposal-only migrations; do not mark unapplied migrations as applied without an independently verified schema match.
4. Provision staging-only environment variables and disable external side effects: payment order creation, provider webhooks, email/SMS/Telegram sends, scheduled jobs, public intake notifications, and any outbound integrations.
5. Apply the reviewed schema baseline to staging, then apply only the verified forward migrations in order.
6. Add synthetic fixtures in staging only: customer organization, registered-business partner organization, active membership/roles, approved partner capability with evidence metadata, shipment enquiry, partner quote, assignment, capacity reservation/binding, and negative-case fixtures. Use reserved test identifiers and non-deliverable contact addresses.
7. Validate RLS, grants, function ACLs, triggers, transaction rollback, idempotency, concurrent quote acceptance, assignment rejection/expiry, partner suspension/capability withdrawal, capacity conflicts, compliance/document blocks, and legacy-payment regression behavior.
8. Run smoke and static checks against staging, then document exact tested commit, schema version, fixtures, and results. Production deployment remains a separate approval step.

## Booking lifecycle validation gate

Do not begin the partner-direct lifecycle migration until staging can prove both atomic boundaries:
- customer acceptance of an immutable partner quote creates exactly one awaiting-partner assignment while shipment remains unconfirmed;
- partner acceptance of that exact assignment revalidates eligibility and capacity, accepts the quote/assignment, and confirms the shipment in one transaction.

Booking confirmation must be separated from dispatch readiness. KRIM freight payment must not be required for partner-direct booking confirmation, while historical payment reconciliation and all applicable dispatch/compliance/document/capacity controls remain intact.

## Result

Step 23 is a staging-readiness and migration-parity audit only. Staging is healthy but empty and not yet a usable test environment. Production has 425 applied migrations while the branch contains 265 SQL migration files; no safe complete bootstrap chain has been established. No schema/data/secret/provider changes were made. The next safe task is to obtain and reconcile an authoritative schema-only baseline, not to apply migrations speculatively.
