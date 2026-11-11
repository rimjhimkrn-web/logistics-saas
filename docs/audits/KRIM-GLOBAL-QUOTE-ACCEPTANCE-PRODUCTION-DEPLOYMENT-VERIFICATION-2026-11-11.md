# KRIM Global Quote Acceptance Migration — Production Deployment Verification
Date: 2026-11-11
Status: VERIFIED NOT DEPLOYED — READ-ONLY PRODUCTION CHECK

## Production migration history

The Supabase production migration listing returned 425 recorded migrations. The latest three are:
- `20261111050237 require_dispatch_proof_before_warehouse_handover`
- `20261111052116 restrict_customer_pod_reads_to_verified_evidence`
- `20261111072758 partner_capability_queue_requires_private_evidence`

The proposed migration `20261111120000_secure_global_quote_acceptance_partner_assignment` is not present in the production migration history. A direct read-only query against `supabase_migrations.schema_migrations` for version `20261111120000` / the matching name returned no rows.

## Live function verification

The production function `public.krim_accept_global_quote(bigint)` was read from `pg_proc`. Its deployed body is still the older implementation:
- authenticates the customer organization and `shipment.update` permission;
- requires quote status `sent`, unexpired quote and shipment status `quoted`;
- marks the customer quote `accepted`;
- transitions shipment `quoted -> confirmed`;
- does not query a linked partner quote;
- does not query an accepted shipment-partner assignment;
- does not verify partner acceptance before customer acceptance.

The deployed function therefore remains vulnerable to the premature customer-acceptance lifecycle ordering identified in the earlier audit. This is a correctness and workflow-integrity issue; it is not evidence of an observed unauthorized payment or data breach.

## Proposed migration review

Repository file:
`supabase/migrations/20261111120000_secure_global_quote_acceptance_partner_assignment.sql`

The proposed replacement adds:
- quote/shipment customer-organization consistency;
- required linked partner quote;
- partner quote/shipment linkage, eligible status and validity;
- amount and currency consistency;
- explicit matching shipment-partner assignment with status `accepted`;
- only then customer quote acceptance and shipment confirmation.

The migration does not explicitly check the confirmed capacity binding. That remains a separate server-side checkout gate in the Razorpay order-creation and verification functions. The function's existing EXECUTE grants should be preserved by CREATE OR REPLACE, but must be re-queried after any deployment.

## Staging limitation

The separate staging Supabase project currently has zero recorded migrations and no application schema/functions. It is not a usable test environment yet. No staging migration was applied and no production schema dump/restore was performed.

A migration-history row alone is not proof of correct deployment; this verification used both migration history and the live function definition. Both show the proposed correction is not deployed.

## Release recommendation

Do not enable customer booking/payment or merge a lifecycle change based only on this SQL file. Before deployment:
1. Reconcile the production migration history with the repository and determine why this migration is absent.
2. Bootstrap staging from a reviewed schema-only source; never copy production secrets, auth users, payment records or live data.
3. Test positive and negative cases: partner not accepted, rejected, expired offer, wrong shipment, wrong customer organization, amount/currency mismatch, no capacity binding, accepted assignment with confirmed capacity, expired customer quote, unauthorized user, retries and concurrent acceptance.
4. Verify existing triggers, transition guards, partner quote states, accepted assignment semantics and capacity reservation ordering.
5. Verify function owner, SECURITY DEFINER, fixed search_path, EXECUTE grants, RLS dependencies and audit events after deployment.
6. Update web and mobile callers and run the complete booking-to-test-payment lifecycle in staging with provider test mode only.
7. Deploy only after explicit approval and successful verification.

## Safety status

This was read-only. No production or staging SQL was changed. No migration was applied. No function or grant was changed. No payment, shipment, quote, assignment or capacity record was created or modified.
