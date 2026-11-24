# KRIM notification intent-to-recipient policy decision — 2026-11-24

## Decision
Do not connect the shipment resolver to the workflow outbox until each notification intent has an explicit recipient-role policy. The live production communication-intent table currently has zero rows, so there is no configured intent catalogue from which to safely infer role scopes.

## Production evidence reviewed (read-only)
- `krim_communication_intents` has columns for intent code/name/category/urgency, required and fallback channels, localization, status and metadata; current row count is zero (prior runtime readiness audit).
- `krim_workflow_triggers` has six active triggers for `shipment.status_changed`; their workflow actions include customer notifications for confirmed/dispatched/delivered/exception and partner notification for assignment; delay-risk and exception-case actions also exist.
- `krim_organization_members` contains roles including owner, admin, operator, dispatcher, finance, manager, member and driver.
- The current resolver returns every active partner member except drivers. This is too broad for production.
- Organization contacts are not verified auth-user destinations and must not be used as a fallback identity.
- Essential in-app service notifications must remain durable and must not be suppressed by marketing preferences. External channel destinations require verified ownership and applicable channel/legal checks.

## Proposed policy matrix — pending owner/security approval
This matrix is a proposal for review, not production configuration.

| Intent family | Customer organization roles | Partner organization roles | Exclusions |
|---|---|---|---|
| Shipment confirmed / dispatched / delivered / exception | owner, admin, operator, member | — | driver and suspended/inactive members |
| Assignment offered / accepted / rejected | — | owner, admin, manager, dispatcher, operator | finance, member, driver unless a separate verified driver-assignment intent explicitly targets that driver |
| Shipment operational status | owner, admin, manager, dispatcher, operator | owner, admin, manager, dispatcher, operator | finance and driver unless the event is explicitly addressed to the assigned driver |
| Billing / payment | owner, admin, finance | owner, admin, finance | general members, dispatcher, driver |

## Required design before implementation
1. Store an explicit, versioned role policy per intent code (or a reviewed deterministic policy function with exhaustive tests); no broad default role fallback.
2. Separate driver-specific assignment/dispatch messages from organization-level partner notifications. Resolve the assigned driver only through the verified assignment-to-driver identity relation and applicable account state.
3. Require active organization membership and relevant shipment/assignment relationship for every recipient.
4. Deduplicate recipients across multiple assignments and overlapping role memberships.
5. Keep in-app service notices durable. Treat marketing preferences separately; do not apply marketing opt-outs to essential service notices.
6. For email/SMS/push/WhatsApp/Telegram, verify destination ownership and channel readiness, evaluate channel-specific suppression and legal consent requirements, and record provider acceptance separately from confirmed delivery.
7. Add tests for every intent × role × membership state × relationship state, including no-recipient outcomes.
8. Do not send any test messages or write production rows during this phase.

## Gate
**NO-GO for outbox wiring and production migration** until the intent catalogue and role matrix are approved, resolver accepts an intent code and applies the policy, isolated PostgreSQL tests pass, and delivery idempotency/lease fencing/state semantics are addressed.

## Scope
This is an evidence and design decision only. It changes no production schema, policies, rows, secrets, providers or notification delivery settings.
