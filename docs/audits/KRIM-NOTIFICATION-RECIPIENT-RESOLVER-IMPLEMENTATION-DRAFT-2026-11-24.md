# KRIM shipment notification recipient resolver — implementation draft

**Status: draft for review; not applied to production.**

## Scope
Adds a service-role-only database resolver that returns eligible user IDs and organization context for a shipment. It does not read or return email/phone destinations, create communication-recipient rows, enqueue notifications, or send messages.

## Resolution rules
- Customer: shipment's customer organization must be active and type customer/enterprise; identity link must be verified with a non-null verified_at; workspace and account must both be active; the same user must have active membership in that organization.
- Partner: shipment must have an offered/accepted/active assignment to an active partner/carrier/warehouse/forwarder/customs organization; organization lifecycle must be active, verification verified, and compliance compliant; only active non-driver organization members are returned.
- Invalid shipment IDs and unsupported recipient types fail closed.
- Function is in the non-exposed krim_internal schema, uses an empty search_path with schema-qualified references, and is executable only by service_role.

## Important limits / follow-up
1. This is identity resolution, not delivery readiness. No email, phone, consent, suppression, preference, or provider credential is inferred.
2. Before outbox enqueue, add a separately reviewed destination resolver that validates verified destination ownership and consent; mandatory transactional/service notices must not be suppressed by marketing preferences.
3. Enqueue must be idempotent per event + recipient + channel. Resolve active route/provider compatibility before creating an outbox row.
4. Workflow action must only be marked durably queued after successful idempotent enqueue. Provider acceptance is `sent`; a provider delivery callback is `delivered`.
5. Retry worker still needs lease fencing, expired-lease recovery, idempotent delivery-row creation, retry caps, and dead-letter handling.
6. Do not apply this SQL until production migration history is reconciled and the function is tested in a disposable database. The repository and production migration ledgers are known to diverge.

## Validation matrix (must pass before merge/apply)
- Null/zero/negative shipment ID => invalid input; no recipient rows.
- Unknown shipment => not found; no recipient rows.
- Invalid recipient type => invalid input.
- Customer identity pending/suspended/revoked or verified_at null => excluded.
- Customer workspace/account not active => excluded.
- Customer membership inactive/suspended or wrong organization => excluded.
- Valid customer identity + active workspace + same-org active membership => exactly one row per user.
- Partner assignment rejected/cancelled/failed/completed => excluded.
- Partner org inactive, lifecycle not active, verification not verified, or compliance not compliant => excluded.
- Partner membership inactive or driver role => excluded.
- Multiple assignments to same partner must not duplicate a member.
- Cross-organization identity/membership mismatch => excluded.
- Execute privilege: service_role only; anon/authenticated/PUBLIC denied.
- No test may send a real email/SMS/WhatsApp/Telegram message.

## Live-schema evidence checked 2026-11-24
- Customer identity links reference krim_customer_acquisition_profiles(id), not legacy customer_profiles.
- Customer identity statuses: pending, verified, suspended, revoked.
- Customer workspace statuses: pending, provisioning, active, restricted, closed; account statuses: pending, email_unverified, active, suspended, closed.
- Organization membership statuses: active, inactive, suspended.
- Partner assignment statuses: offered, accepted, rejected, cancelled, active, completed, failed.
- Partner lifecycle, verification and compliance constraints were checked against the live catalog.
- Live acquisition profiles, identity links, workspace profiles, partner assignments, capacity bindings, and communication recipients currently contain zero rows; production fixtures were not inserted.
