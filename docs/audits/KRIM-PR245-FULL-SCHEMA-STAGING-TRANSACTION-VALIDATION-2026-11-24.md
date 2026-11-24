# PR #245 full-schema staging transaction validation — 2026-11-24

## Result
**PASS — all three proposed migrations compiled and the integrated shipment notification workflow executed successfully against the connected KRIM staging database's real schema. All changes and test fixtures were rolled back.**

This is stronger than the synthetic PostgreSQL fixtures, but it is still a staging transaction test, not a production deployment.

## Schema parity checked before execution
Compared the production and staging catalog for the 13 tables directly used by the proposed resolver, workflow executor, and in-app handoff:
- `krim_shipments`
- `krim_organizations`
- `krim_customer_identity_links`
- `krim_customer_acquisition_profiles`
- `krim_customer_workspace_profiles`
- `krim_organization_members`
- `krim_shipment_partner_assignments`
- `krim_workflow_action_executions`
- `krim_workflow_run_steps`
- `krim_workflow_runs`
- `krim_workflows`
- `krim_events`
- `notifications`

All **209 columns** matched between production and staging by table, column, data type, and nullability. The five active workflow runtime function signatures were also present in staging. The staging fixture tables used for this test were empty before execution.

## Transactional test performed
Within one explicit SQL transaction on staging:
1. Applied the three proposed migrations in dependency order: recipient resolver/intent map, lease-fenced batch executor, then transactional in-app notification handoff.
2. Inserted synthetic auth users, customer/partner organizations, a verified customer identity/workspace, active memberships, shipments, a partner assignment, domain events, workflows, steps, runs and queued actions.
3. Temporarily disabled six existing shipment/assignment business-validation triggers only to permit synthetic fixture rows. This was confined to the transaction; the transaction was rolled back.
4. Executed the **actual proposed batch processor** against the **actual staging claim/recovery functions** and the proposed fenced executor + in-app handoff wrapper.
5. Asserted customer delivery, partner delivery, duplicate-event idempotency, explicit no-recipient outcome, successful action state and lease release.
6. Rolled back the transaction.

## Runtime result
The batch processor returned:
- `processed: 4`
- `succeeded: 4`
- `failed: 0`
- `recovered_expired: 0`

Assertions passed:
- Two customer workflow actions for the same event/user generated exactly one in-app notification.
- A partner assignment event generated exactly one partner in-app notification.
- An event with no eligible customer recipient generated no notification and stored `no_eligible_recipients` on the action response.
- All four workflow actions finished `succeeded` and their owned lease fields were cleared.
- All four actions retained a durable handoff outcome in their response snapshot.

## Rollback verification
A separate read-only query after the transaction confirmed:
- `notifications.event_id` does not exist in staging after rollback.
- The renamed legacy executor does not persist.
- Workflow action, event and notification fixture row counts are all zero.
- All six temporarily disabled shipment/assignment triggers are enabled again.

No production SQL was applied. No persistent staging schema/data changes were made. No provider configuration or external message was used.

## Remaining release gates
- Production migration history still differs materially from the repository and staging ledger; do not apply the proposed migrations to production until migration ordering and collision reconciliation are complete.
- This transaction proves the proposed SQL works against the connected staging schema for the exercised customer/partner/no-recipient paths. It does not replace a full regression of all workflow action types, concurrent lease takeover, provider delivery, RLS/API behavior or production cron operation.
- The outbox/email/SMS/WhatsApp/Telegram/push provider path remains unconfigured. This test validates durable in-app notices only.
- Production customer identity and partner assignment populations remain empty at the last live audit; real recipient readiness is not established.

## Release decision
Keep PR #245 in draft. The next safe step is a broader staging regression for failure/retry/dead-letter and migration-ledger reconciliation, followed by recipient onboarding and provider readiness. Do not merge or apply to production yet.
