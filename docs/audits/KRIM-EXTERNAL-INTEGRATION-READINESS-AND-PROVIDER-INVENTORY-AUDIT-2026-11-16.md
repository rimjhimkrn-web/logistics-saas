# KRIM External Integration Readiness and Provider Inventory Audit
**Date:** 16 November 2026  
**Scope:** Read-only comparison of checked-in integration pages/docs, active Supabase Edge Function inventory, and known integration setup evidence. No provider API calls, messages, emails, WhatsApp sends, CRM writes, payment actions, or configuration changes were made.

## Executive decision
**NO-GO for claiming that the external integration ecosystem is connected or production-operational.** The current codebase contains a useful integration architecture and active internal/provider functions, but the public-facing integration dashboard overstates readiness. No live HubSpot, WhatsApp Cloud API, Resend send, LinkedIn, or YouTube integration was verified in the current deployed function inventory. Telegram has an internal notification path but provider acceptance and human receipt are not equivalent. Razorpay webhook infrastructure exists, but merchant eligibility and settlement readiness remain unverified and financial collection is deferred. Cashfree functions remain deployed despite the stated decision to discontinue Cashfree.

## Evidence reviewed
- GitHub repository tree and relevant integration status/audit documents.
- `domains/integrations.html` and `app/enterprise/integrations.html`.
- Current Supabase Edge Function inventory and versions, including payment, public enquiry, notification and tracking functions.
- Prior read-only notification/consent audit and current release constraints.
- No provider credentials or secret values were read or exposed.

## Current integration inventory

| Integration | Evidence observed | Honest status |
|---|---|---|
| Supabase core | Active project, database and Edge Functions | Connected; individual flows still require staging tests |
| GitHub / Pages | Repository and Pages workflows deployed | Connected; deployment is not functional E2E certification |
| Telegram founder alerts | Public enquiry outbox and notification retry worker; provider adapter has an authorized Telegram test route | Implemented path; delivery not verified in this audit |
| HubSpot CRM | No HubSpot Edge Function, provider adapter or verified sync evidence found in deployed function inventory | Not verified / not connected |
| Resend email | Provider adapter checks key presence and reports sending disabled; no verified send/domain/delivery flow | Not send-ready |
| WhatsApp Business / Cloud API | No deployed WhatsApp provider function or verified Cloud API send path found | Not connected / not verified |
| Facebook / Instagram | Account/page assets exist from prior setup, but no verified publishing, inbox, lead-sync or webhook implementation found | Business presence only; software integration not verified |
| LinkedIn | No deployed integration path or verified business presence evidence in this audit | Not verified |
| YouTube | No deployed integration path or verified channel integration evidence in this audit | Not verified |
| Razorpay | Order/verification functions and webhook are active; freight collection is gated and own-fee flow is not implemented | Technical integration present; merchant/settlement and own-fee readiness unverified; keep collection disabled |
| Cashfree | Order, verification and webhook Edge Functions remain ACTIVE | Legacy deployment residue; do not use; requires controlled retirement after dependency review |
| Carrier / ERP / TMS / WMS / GPS APIs | Architecture and integration-page labels only; no provider-specific connection or credentialed E2E evidence found | Architecture only; not connected |
| Port / terminal systems | Page itself labels connection pending | Not connected |

## P0 — Integration dashboard contains unsupported READY claims
`domains/integrations.html` displays Carrier/3PL APIs, GPS/Telematics, ERP/TMS/WMS, payment providers, REST APIs, webhooks, event-driven systems, scheduled synchronization, API authentication, idempotency, rate controls, audit trail, webhook retries, dead-letter handling, credential protection, RLS/RBAC and monitoring as READY. It also labels global integration architecture READY. These are not supported by verified provider connections, operational telemetry, or complete E2E evidence. The page shows placeholder KPI values (—), not live measurements. These labels risk misleading customers, partners and enterprise users. Replace with explicit states such as Connected & tested, Implemented—not tested, Architecture only, Planned, Disabled, and Blocked; show evidence timestamp and scope.

## P1 — No canonical integration registry with lifecycle evidence
No verified provider registry was established in the reviewed deployment evidence that records owner, provider, environment, credential reference (never the secret), enabled state, permitted scopes, webhook endpoint, signing verification, last successful test, last failure, health timestamp, data retention and revocation state. Build a canonical registry and status contract before exposing integration health in workspaces.

## P1 — HubSpot sync is not proven
Earlier HubSpot audit found a sample-only account with two contacts, one company and no deals. No deployed HubSpot sync function or confirmed webhook/CRM reconciliation path was found in the current Edge Function inventory. Do not claim public enquiry-to-HubSpot sync. If HubSpot is retained, define consent-aware field mapping, deduplication, company/contact association, retries, deletion/withdrawal propagation and a staging sandbox test.

## P1 — WhatsApp is not Cloud API connected
Prior account evidence indicated WhatsApp Business App approval but Offline, with setup incomplete. No Cloud API send/webhook adapter appears in the current deployed function inventory. Business App presence is not a software integration. Keep WhatsApp automated messaging disabled until business verification, phone-number registration, approved templates, webhook signature verification, consent/preferences, opt-out and staging delivery tests pass.

## P1 — Email provider is deliberately disabled
The notification provider adapter does not send Resend email; it reports sending disabled after checking key availability. A key being present is not proof of verified domain, sender identity, deliverability, suppression management or bounce/complaint handling. Keep email disabled until the domain and sender are authenticated, provider webhooks are verified, consent is enforced, and staging delivery tests pass.

## P1 — Telegram is an internal notification path, not a customer communication platform
The notification outbox and worker support founder Telegram alerts. The prior CRM/notification audit identified potential duplicate dispatch races, stranded processing claims and misleading delivery-state semantics. Telegram API acceptance must not be called human delivery. Use it only for authorized founder/internal alerts until queue leases, idempotency, retry recovery and delivery-state reporting are fixed and tested.

## P1 — Cashfree remains deployed after the decision to discontinue it
The current Edge Function inventory still lists `create-global-cashfree-order`, `verify-global-cashfree-payment` and `cashfree-payment-webhook` as ACTIVE. This does not prove they are exposed in the UI or that they can complete a payment, but it is unnecessary attack surface and operational ambiguity. Keep all Cashfree routes disabled and inaccessible. After repository/DB dependency review, remove them through a reviewed change and verified deployment; do not delete blindly while production migration reconciliation is unresolved.

## P1 — Razorpay is not the same as commercial readiness
Razorpay order, verification and webhook functions are deployed. Prior audit confirms freight collection is gated by an explicit approval flag/version, legacy refund execution is separately disabled, and no KRIM own-service-fee checkout is implemented. Merchant KYC, business category approval, settlement bank and settlement test remain unverified. Do not enable freight collection or create a payment flow now; financial collection remains the final phase.

## P2 — Provider webhook governance not yet demonstrated across providers
A robust external integration requires signature validation over raw request bytes, replay protection, unique provider event IDs, durable event storage, idempotent state transitions, retry/acknowledgement policy, secret rotation, tenant mapping and monitoring. Razorpay webhook has a reviewed signature/event foundation; equivalent controls were not verified for HubSpot, WhatsApp, Resend, Meta, LinkedIn, YouTube or carrier APIs because those integrations were not found as deployed provider adapters.

## Recommended integration lifecycle
1. Establish one canonical registry and status vocabulary.
2. Keep provider secrets in Supabase secrets/Vault; never in browser bundles or repository files.
3. Connect and test one provider at a time in staging, starting with founder-only Telegram reliability.
4. Complete CRM consent semantics and HubSpot sandbox sync before CRM automation.
5. Complete Resend sender/domain and webhook controls before email activation.
6. Complete WhatsApp Cloud API business setup, templates, opt-in/opt-out and webhooks before any automated customer message.
7. Add Meta/LinkedIn/YouTube only after official account ownership and approved scopes are confirmed.
8. Integrate carrier/ERP/TMS/WMS/GPS providers only against actual partner/customer contracts, documented APIs and route-specific operating needs.
9. Retire Cashfree only after dependency review and migration-safe change control.
10. Keep payment-provider collection work for the final financial phase.

## Verification checklist
- Provider connection identity and environment confirmed without exposing credentials.
- Secret stored server-side and rotation/revocation documented.
- Least-privilege scopes and tenant ownership verified.
- Webhook signature, replay, duplicate, out-of-order, retry and dead-letter tests passed.
- Provider status distinguished from user-visible delivery.
- Consent, preferences, suppression and opt-out enforced before customer messaging.
- Synthetic staging send/read/receipt evidence retained with PII redacted.
- Live status page shows actual health and last-verified timestamp, not static READY badges.
- Failure and disconnection alerts routed to an authorized operator.
- No real customer/partner messages or financial transactions without explicit authorization.

## Change control
This audit is read-only. No external provider was contacted; no messages, emails or social posts were sent; no credentials were read; no functions were deployed or disabled. No production DDL or data changes were made. Production migration reconciliation remains a blocker for schema/function remediation. Financial collection remains deferred to the final phase.

**Release status: NO-GO** for claiming a fully integrated global logistics ecosystem. Current verified integrations are limited to KRIM's core infrastructure and selected deployed provider paths; most third-party connections remain planned, partial or unverified.
