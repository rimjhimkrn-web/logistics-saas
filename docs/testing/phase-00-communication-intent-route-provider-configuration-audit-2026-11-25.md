# Phase 00 — Communication intent, route and provider configuration audit

Date: 2026-11-25  
Branch: `qa/phase-00-baseline-2026-11-25`  
Scope: read-only configuration row inspection in Production and Staging.

## Result

The generic communication-routing configuration is structurally present but unconfigured in both environments.

| Configuration/data | Production | Staging |
|---|---:|---:|
| Communication intents | 0 | 0 |
| Communication routes | 0 | 0 |
| Communication providers | 0 | 0 |
| Communication recipients | 0 | 0 |
| Communication suppressions | 0 | 0 |

The catalog query joined routes to intents and provider references, and separately counted recipient/suppression rows. All returned empty/zero.

## Implications

- There are no configured intent definitions specifying required channels, fallback channels, urgency, or templates.
- There are no route records selecting a channel/provider, route order, retry limit or fallback threshold.
- There are no configured provider rows in this generic communications registry.
- There are no recipient-resolution records or suppression records in this registry.
- This confirms the earlier distinction: the existence of communications tables and columns does not mean a working notification service is configured.
- Legacy in-app trigger notifications and the founder-only Telegram inquiry/follow-up worker are separate mechanisms and do not populate or prove this generic configuration.
- The Staging Resend partner-verification worker is a narrow separate implementation; its presence does not make the generic routing registry operational.

## Readiness decision

**NO-GO for claiming generic notification routing or nine-workspace communication readiness.** The schema is empty in both environments and prior source review found no universal event-to-outbox dispatcher. Essential service notifications remain a launch blocker until intent definitions, recipient resolution, route/provider configuration, durable delivery, callbacks, recovery and synthetic tests are implemented.

## Next work

1. Define and review a complete intent catalogue for all nine ecosystems, distinguishing mandatory transactional/service notices from optional marketing communications.
2. Populate route/provider configuration only after environment isolation, provider verification and secret ownership are established.
3. Implement canonical event-to-intent resolution, tenant-safe recipient resolution and idempotent outbox creation.
4. Implement a single delivery lifecycle with retries, lease recovery, provider callbacks and truthful accepted-versus-delivered states.
5. Add authenticated tenant-isolation and synthetic-recipient tests before enabling any external send.
6. Ensure the user-facing notification centre displays real state and does not imply delivery when no delivery record exists.

## Evidence boundary

Read-only SELECTs only. No intent, route, provider, recipient or suppression rows were inserted or changed. No provider was contacted. Production and Staging remained unchanged.
