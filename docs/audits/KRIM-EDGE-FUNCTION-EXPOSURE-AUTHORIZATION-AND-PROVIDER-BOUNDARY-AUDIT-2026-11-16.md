# KRIM Edge Function Exposure, Authorization and Provider Boundary Audit
**Date:** 2026-11-16  
**Scope:** Read-only review of the live Supabase Edge Function inventory and repository-tracked function source. No function was invoked, deployed, disabled, or reconfigured. No provider API, payment, webhook, notification, GPS upload, or customer operation was executed.

## Executive summary
The live project reports 21 active Edge Functions. Four have `verify_jwt=false`: `razorpay-webhook`, `public-shipment-tracking`, `krim-public-contact-inquiry`, and `krim-notification-retry-worker`; Cashfree webhook is also deployed with JWT verification disabled. JWT-disabled is not inherently wrong for provider webhooks or public token endpoints, but each must independently authenticate its protocol/token and constrain abuse. The repository source does not fully represent the deployed inventory: source for several active functions is absent from the current repository tree, so deployment/source parity is not established.

## Live inventory observations
- 21 active functions were returned by the Supabase project inventory.
- JWT verification disabled on: `razorpay-webhook`, `public-shipment-tracking`, `krim-public-contact-inquiry`, `krim-notification-retry-worker`, and `cashfree-payment-webhook`.
- The remaining listed functions have JWT verification enabled.
- The deployed inventory includes legacy Cashfree order/verification/webhook functions, despite the current decision to discontinue Cashfree.
- The inventory reports deployed versions and update timestamps, but these do not establish that the repository source inspected below is byte-for-byte the deployed code.

## Positive controls found in repository source
1. **Razorpay webhook:** POST-only handler; validates HMAC using Web Crypto and a server-side webhook secret; checks/stores provider event identity and handles duplicate/in-progress delivery. This is the correct type of independent authentication for a JWT-disabled provider webhook. Signature, retry and reconciliation behavior still require controlled staging tests.
2. **Public shipment tracking:** POST-only; requires a 32-character hexadecimal tracking token; uses a SHA-256 token lookup; response excludes raw GPS event rows and only includes live coordinates after session, driver, assignment, consent and active-status checks. Token entropy, throttling, revocation, enumeration resistance and response-field minimization still require validation.
3. **Public contact inquiry:** POST-only; delegates validation/throttling and record creation to the database RPC; founder Telegram delivery is attempted from server-side secrets. Previously audited behavior indicates privacy acknowledgement is not granular marketing consent and provider acceptance is not proof of human receipt.
4. **KRIM AI:** requires a Bearer token validated with Supabase Auth `getUser`; restricts origins to an allow-list; uses a database rate-limit RPC; bounds message length and validates conversation identifiers.
5. **Global Admin control:** requires a Bearer token and validates the user before privileged operations; existing audit identified AAL2/platform-role checks in the handler. Existing audit-log failure propagation remains a concern.
6. **Razorpay checkout and verification:** require authenticated user validation and organization/quote/assignment checks. Freight collection has an explicit environment flag plus approval-version gate and is disabled under the current non-custodial launch decision. Do not enable.
7. **Refund execution:** requires an explicit legacy-refund environment/version gate and authenticated user; it is disabled under current policy. Do not enable.
8. **Driver GPS:** both GPS endpoints require authentication, driver/session/consent checks and exact legal approval gates. The consent notice is marked unapproved and the feature remains disabled; keep it disabled.
9. **Legacy Cashfree checkout endpoints:** repository stubs return a retired-provider response rather than initiating checkout.

## Findings and priorities

### P0 — Deployed source parity is not established
The current repository tree does not contain source for several active deployed functions, including at least `krim-notification-provider-adapter`, `krim-notification-retry-worker`, and `krim-global-growth-operations`. Some other deployed functions may be represented only by historical/older repository source. Consequently, this audit cannot certify the exact deployed code for every endpoint. Obtain an authenticated, version-pinned source/deployment manifest and compare hashes before any release/security sign-off. Do not infer safety from a repository stub when the live deployment is a separate active version.

### P1 — JWT-disabled retry worker requires independent authentication proof
`krim-notification-retry-worker` is active with `verify_jwt=false`. Its deployed source is not present in the repository tree inspected. Before it is enabled for scheduled or external invocation, prove that it validates a high-entropy server-side worker secret or equivalent trusted invocation, rejects browser/user traffic, limits batch size and runtime, and uses claim leases/recovery. Prior CRM audit found possible stranded claims and overlapping retry generations. No invocation was attempted.

### P1 — Public endpoint abuse controls need staging evidence
The public tracking and inquiry endpoints are intentionally reachable without a user JWT. Confirm strict per-IP and per-token rate limits, request/body size limits, bounded response times, abuse telemetry, token revocation and safe failure behavior. Existing inquiry throttling has a known dependency on trusted proxy IP metadata; ensure absence of that header cannot collapse all callers into one identity or bypass throttling.

### P1 — CORS is broad on multiple endpoints
Several handlers return `Access-Control-Allow-Origin: *`. CORS is not authentication, and wildcard CORS does not by itself expose a secret, but authenticated endpoints should use a deliberate origin policy where browser access is intended. Webhooks and machine-to-machine endpoints generally do not need browser CORS. Align CORS behavior and preflight handling with each endpoint's actual consumer, without treating origin checks as authorization.

### P1 — Provider and financial legacy surface remains active
Cashfree order, verification and webhook functions remain ACTIVE in Supabase even though repository stubs return retired responses and the provider has been discontinued. Confirm actual deployed behavior and inbound webhook configuration. Keep these endpoints inaccessible/disabled at the provider configuration layer until a migration-safe retirement plan is approved; do not delete or disable production functions without dependency review and explicit authorization.

### P1 — Webhook and notification delivery semantics are not end-to-end certified
Razorpay HMAC and event-id handling are positive controls, but signature replay, duplicate event races, out-of-order events, provider timeouts and reconciliation need staging tests. Telegram provider acceptance is not a delivery receipt. Resend remains not send-ready. The notification adapter and retry worker deployed source must be reconciled before any external communication is enabled.

### P1 — Privileged service-role usage needs endpoint-by-endpoint proof
Several endpoints use the service-role key for privileged database access. This is expected only where the function first validates the caller or provider protocol and then enforces exact tenant, resource, action, and state checks in trusted server code/RPCs. Audit each deployed implementation for user identity validation, tenant scoping, permission checks, AAL2 where required, and non-leakage of service credentials. Never move service-role keys into client code.

### P2 — Observability and error handling
Ensure request IDs, structured security events, redacted provider errors, bounded retries, and alerts for repeated authentication failures. Do not return raw provider/database errors or secrets. Confirm audit events are durable for privileged state changes.

## Required staging test plan (not executed)
- Anonymous call to every JWT-required function -> rejected by platform/handler.
- JWT-disabled public endpoints -> only intended token/protocol paths succeed.
- Invalid/expired/revoked JWT, wrong tenant, wrong org type, missing permission and AAL1 for privileged actions -> rejected.
- Forged user metadata and stale role claims -> cannot grant authority.
- Webhook invalid HMAC, stale/replayed event, duplicate ID, concurrent duplicate, unknown event and out-of-order event -> safe, idempotent outcome.
- Tracking malformed, random, revoked, expired and high-volume tokens -> bounded, non-enumerable responses; no unauthorized coordinates or PII.
- Public inquiry oversized payload, malformed fields, missing trusted proxy IP, repeated requests and bot traffic -> bounded and throttled.
- Retry worker without trusted secret, with invalid secret, overlapping invocation and simulated worker crash -> rejected or safely recoverable.
- Provider timeouts and ambiguous outcomes -> no duplicate messages/payments and reconciliation required.
- Confirm deployed function version/hash against reviewed source for all 21 functions.

## Release decision
**NO-GO for unrestricted production operations, automated external communications, GPS tracking, freight collection, refunds, or cross-border execution.** Existing controls are promising but deployment/source parity, public abuse resistance, worker authentication, end-to-end provider behavior, market/corridor readiness and the migration-history mismatch remain unresolved.

## Change boundary
This was a read-only audit. No Edge Function deployment/configuration change, database DDL/DML, provider request, payment, refund, notification, tracking session or shipment operation was performed.
