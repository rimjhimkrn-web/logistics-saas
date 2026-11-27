# KRIM Staging Tenant-Isolation Fixture Provisioning
Date: 2026-11-27
Branch: staging/phase00-env-isolation
Project: qrpcivhdxobiaofppbkl (Staging only)

## Status
Preparation specification only. No Auth users, organisations, memberships, shipments, quotes, assignments, or evidence events were created by this work.

## Verified Staging facts
- `auth.users` currently contains 1 user; no synthetic staging users were found.
- `public.krim_organizations` supports organization types including `customer` and `partner`.
- `public.krim_organization_members` references `auth.users(id)` and `krim_organizations(id)`; roles are constrained to owner/admin/operator/dispatcher/finance/manager/member/driver and status to active/inactive/suspended.
- Organisation creation and membership insertion have audit triggers. Provisioning must preserve those triggers.
- Existing `owner-testing-authorize` Edge Function validates the caller using Supabase Auth, confirmed email, AAL2, and the single active platform-superadmin assignment. It is an authorization gate, not a provisioning API.

## Required synthetic actors
Four distinct, user-controlled test email addresses are required:
1. Customer A
2. Customer B
3. Partner A
4. Partner B

Do not use the existing owner identity for any of these roles. Do not use fabricated `.invalid` addresses for tests that require email confirmation or interactive sessions. Do not commit addresses, passwords, JWTs, service-role keys, or recovery codes.

## Provisioning architecture
Implement a separate Staging Edge Function, protected by:
- valid Supabase JWT and `auth.getUser(token)` verification;
- confirmed caller email and verified JWT AAL claim `aal2`;
- same single-owner authorization check used by `owner-testing-authorize`;
- exact Staging project configuration and an explicit environment guard;
- strict request schema and exactly four unique, verified test addresses supplied by the owner;
- server-side Supabase Auth Admin API only; never expose service-role credentials to browser code.

Create or invite the four Auth users using Supabase Auth Admin APIs. Do not insert into `auth.users` directly. Return only opaque user IDs and invite status; never return secrets or tokens.

Create two customer organisations and two partner organisations with unmistakable `KRIM TEST ONLY` names. Add one corresponding active membership per identity using role `owner`. Preserve all audit triggers. Use an idempotency key stored in a dedicated fixture-run ledger so retries cannot duplicate records.

## Business fixture sequence
After identity provisioning and schema/trigger review, create fixtures through the real authorized application workflows:
1. Customer A and Customer B each create a test shipment and quote.
2. Partner A and Partner B receive only their intended opportunities.
3. Each partner submits a partner quote through the normal workflow.
4. Create assignments through the normal assignment workflow.
5. Exercise accept and reject actions through the actual partner response workflow so immutable evidence triggers fire naturally.

Never insert acceptance/rejection evidence rows directly. Never bypass assignment transition or capacity-binding guards. Do not activate payment collection, settlements, invoices, or live notifications as part of this test.

## Required negative and positive tests
- Customer A reads own quote response evidence: allow.
- Customer A reads Customer B evidence: deny / empty without metadata leakage.
- Partner A reads own response history: allow.
- Partner A reads Partner B evidence: deny / empty without metadata leakage.
- Customer caller never receives partner-private quote snapshot.
- Partner caller receives only its own partner quote snapshot.
- Revoke a membership and verify access is removed immediately.
- Unauthenticated caller and anon role are denied.
- Check IDs, counts, pagination, error messages, storage paths and signed URLs for cross-tenant leakage.

Run each test with four independent authenticated sessions. Record test ID, commit SHA, migration state, synthetic actor, organisation, AAL, RPC/action, before/after state, result, timestamp, and relevant audit event.

## Cleanup
Cleanup must be a separate owner-confirmed operation. It may delete only rows tagged with the unique fixture-run ID and only after confirming all linked test records belong to that run. Preserve immutable audit/evidence records according to retention policy; mark the run retired rather than deleting evidence. Never perform broad deletes by display name or email. Never target Production.

## Exit criteria
Provisioning is not complete until the four addresses are supplied, invites are accepted, four separate sessions are established, all six core evidence tests pass, revocation test passes, and an independent reviewer confirms the captured evidence.
