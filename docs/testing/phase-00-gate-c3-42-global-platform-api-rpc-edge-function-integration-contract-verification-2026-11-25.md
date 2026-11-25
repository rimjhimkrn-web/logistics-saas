# Phase 00 — Gate C3.42: Global Platform API, RPC, Edge Function & Integration Contract Verification

**Date:** 25 November 2026  
**Baseline:** immutable source commit `72d75a18f985ceb09e468839435ee95700e11e46`  
**Method:** read-only source inspection of selected high-impact Edge Functions, selected workspace frontend code, repository function/migration inventory and prior C3.25/C3.28/C3.30/C3.32/C3.39 audits. No function invocation, HTTP request to Supabase, live RPC, JWT/session, webhook, provider, database or deployment action was performed.

## Executive decision

**C3.42 FAIL / BLOCKED — NO-GO for API/RPC contract certification, provider integration sign-off or end-to-end integration readiness.**

The repository contains meaningful controls: authenticated user validation in selected functions, server-side permission checks, method validation, request validation, fail-closed freight-order creation, webhook signature/idempotency handling and server-side transactional RPC use. However, the platform does not yet have a verified, complete, versioned API contract catalogue or runtime contract/conformance suite across all nine workspaces. Static source inspection cannot establish deployed function configuration, JWT gateway settings, actual database grants, live schema compatibility, provider delivery or runtime response semantics.

## Scope and selected source evidence

Reviewed immutable baseline:
- `create-global-razorpay-order/index.ts`
- `razorpay-webhook/index.ts`
- `krim-notification-provider-adapter/index.ts`
- `krim-notification-retry-worker/index.ts`
- `public-shipment-tracking/index.ts`
- `krim-public-contact-inquiry/index.ts`
- `krim-driver-gps-update/index.ts`
- `global-admin-control/index.ts`
- `krim-payment-capability-status/index.ts`
- `krim-ai/index.ts`
- Selected Customer, Partner and Finance workspace entry code.
- Function and migration tree inventory, and prior relevant QA findings.

This is a targeted high-risk sample, not exhaustive review of every RPC/function or every frontend caller.

## Positive controls observed

1. `create-global-razorpay-order` checks POST/OPTIONS and explicitly fails closed unless `KRIM_FREIGHT_COLLECTION_ENABLED=true` and the approval version equals `2026-11-15-v1`. It authenticates the user, checks organization access and confirmed shipment/accepted quote state. This is a positive source control; the separate captured-payment webhook bypass previously recorded in C3.25 remains unresolved and is not cleared by this order guard.
2. `razorpay-webhook` validates HMAC signature, limits supported event types, checks event identity and handles duplicate/conflicting payment identifiers through server-side reconciliation RPCs. This does not resolve the previously identified freight-collection kill-switch bypass on captured-payment processing, nor prove provider retry/recovery under runtime conditions.
3. `krim-notification-provider-adapter` validates bearer session via `auth.getUser()`, calls `krim_has_permission` for `admin.platform`, and reports provider readiness separately from sending enablement.
4. `krim-notification-retry-worker` supports a dedicated cron secret or authenticated platform-admin path, uses queue claim/finish RPCs and caps each claim batch at ten. C3.30 still records stuck-processing recovery and delivery truth as unresolved.
5. `krim-public-contact-inquiry` validates JSON/body fields, requires privacy acknowledgement, handles honeypot, caps declared content length and uses server-side IP-limit and inquiry RPCs. Its IP throttle is conditional on the edge-provided Cloudflare header; the C3.40 audit records missing-IP-header throttling as a gap.
6. `public-shipment-tracking` validates a 32-hex token format, uses a service-side lookup against canonical `krim_shipments`, returns no-store responses and does not expose an authenticated general database client. C3.36/C3.40 still record no runtime abuse/rate-limit proof and no live GPS/ETA guarantee.
7. `global-admin-control` validates a user session and AAL2 before privileged control operations.
8. `krim-ai` has an explicit origin allowlist and rejects unapproved origins in source.

## P0 — No complete API/RPC contract inventory or conformance proof

No verified, versioned contract catalogue was established mapping every frontend action to:
- exact Edge Function/RPC name and deployed version;
- HTTP method, content type, request schema and maximum body;
- authentication mode, JWT gateway configuration, AAL requirement and role/tenant scope;
- required database grants and function execution ACL;
- response schema, status codes, stable error codes and retryability;
- idempotency key and replay/conflict behavior;
- timeout, rate limit, pagination and observability correlation;
- provider dependencies, secret ownership and environment-specific endpoints.

No deployed function invocation, OpenAPI/JSON Schema validation, generated-client drift check, consumer-driven contract test, RPC grant verification or negative authorization suite was run. The repository tree inspected for this baseline did not contain a Supabase `config.toml`; deployed `verify_jwt` and function gateway configuration therefore cannot be inferred from source tree presence.

**Impact:** every critical API contract remains NOT TESTED at runtime; no API compatibility guarantee can be issued.

## P0 — Payment/order/webhook contract conflict remains a release blocker

The order-creation endpoint has an explicit freight-collection kill switch, but the prior C3.25 audit found the Razorpay captured/order-paid webhook path can mark an order paid and invoke company-owned reconciliation without checking that same enable/version control. The two halves of the payment contract are therefore not consistently gated. HMAC validity and idempotency do not substitute for business authorization or legal/commercial approval.

**NO-GO:** KRIM freight collection, automated split, settlement or payment capture. Preserve partner-direct payment model and do not call the live webhook.

## P1 — Authentication and authorization contracts vary by function

Selected functions implement distinct patterns: end-user JWT + permission RPC, service-role lookup with a supplied bearer token, AAL2 admin control, cron-secret worker access, or public token access. These patterns can be appropriate, but a shared documented contract and uniform enforcement test are not established. C3.28/C3.32 already identify a large SECURITY DEFINER surface under review and frontend role/tenant derivation from editable metadata.

Required: function-by-function public/anon/authenticated/service-role classification; explicit JWT gateway behavior; verified `auth.getUser` or signed provider/cron authentication; server-derived tenant and role; exact AAL; minimal service-role scope; EXECUTE ACL verification; deny-by-default negative tests. Never rely on caller-provided user ID, workspace role, organization ID or editable user metadata as authorization proof.

## P1 — Request parsing, limits, CORS and error semantics are inconsistent

The selected sample uses different CORS policies and error formats. Some functions explicitly validate declared body length; not all inspected functions demonstrate a streaming/actual-byte limit. Some accept all origins at CORS level while others use explicit origin allowlists. CORS is not authorization, but inconsistent policies increase integration and browser-compatibility risk. Public tracking has a strict token format but no demonstrated app-level throttle; contact IP throttling is conditional on the edge header. No shared schema validation or stable machine-readable error taxonomy is demonstrated across the sampled endpoints.

Required: shared validated request schemas; actual byte-size enforcement; per-endpoint origin policy; consistent 400/401/403/404/409/413/429/500/503 semantics; no secret/PII leakage; request/correlation IDs; retryable vs terminal error classification; idempotent mutation contract.

## P1 — Provider, webhook and asynchronous API reliability remains blocked

C3.30 records Telegram API acceptance being misrepresented as confirmed delivery, notification jobs that can remain processing indefinitely, no generic delivery guarantee and incomplete retry/dead-letter/acknowledgement. The selected retry worker calls Telegram and queue RPCs, but no provider sandbox test, signed webhook replay, timeout/backoff test, duplicate delivery test, stuck-lease reclaim or human receipt was performed. Provider credentials and endpoint availability were not inspected.

Required: separate accepted/queued/sent/delivered/acknowledged states; bounded retry with exponential backoff and jitter; lease expiry/reclaim; dead-letter and operator replay; webhook signature/replay protection; provider idempotency; human escalation and fallback; redact provider payloads and secrets.

## P1 — Frontend consumer compatibility and stale contract risk

Selected Finance frontend source checks session, active finance membership and `finance.view` permission before enabling data load. This is a positive example, but no exhaustive map of UI calls to deployed RPC signatures or Edge Function response fields exists. Canonical/legacy data model coexistence and migration drift (C3.39) make stale function signatures, parameter names, enum values and response fields particularly risky. No generated type/schema drift check or backward-compatibility test was run.

Required: inventory every `.rpc()`, `.functions.invoke()`, fetch endpoint and direct REST call; match it to authoritative SQL/function signature and deployed migration version; remove obsolete/ambiguous overloads; generate typed client contracts; test old/new response compatibility and explicit deprecation windows.

## P1 — Global/multimodal and environment contract coverage incomplete

No proof that currency minor-unit rules, time zone/date handling, units, locale, country/corridor authorization, transport-mode-specific schemas or provider routing are consistently enforced end-to-end across all nine workspaces. C3.35/C3.39 already record missing corridor activation, mode omissions and source-of-truth conflicts. No isolated Staging environment/function routing proof or production-vs-staging contract test was executed.

## Required acceptance programme

1. Build exhaustive endpoint/RPC/function inventory from every frontend caller, SQL definition, grant, trigger, cron and provider integration.
2. Publish versioned request/response/error schemas and authentication/authorization contracts.
3. Reconcile function deployment inventory, `verify_jwt`, project ref, secrets and migration versions for Production and Staging without exposing secret values.
4. Run isolated Staging contract tests with synthetic identities: valid/invalid/missing/expired JWT; AAL1/AAL2; tenant mismatch; revoked membership; malformed/oversized JSON; unknown fields; duplicate idempotency; conflicting replay; timeout; rate limit; provider failure; webhook signature/replay; pagination; currency/time-zone edge cases.
5. Verify every RPC signature, EXECUTE ACL, role scope and response shape against actual schema in isolated Staging.
6. Add CI schema/client drift checks, contract tests and post-deploy function smoke tests with immutable evidence and rollback.
7. Re-test all P0 findings from C3.25/C3.28/C3.30/C3.32/C3.39 before any operational pilot.

## Gate disposition

- Selected source-level safeguards: **PARTIAL PASS**.
- Complete frontend-to-API/RPC mapping: **NOT TESTED**.
- Deployed Edge Function/JWT configuration: **NOT TESTED**.
- RPC signature/grant/runtime contract: **NOT TESTED**.
- Payment/webhook business-gate consistency: **FAIL / BLOCKED** (prior C3.25 P0 remains).
- Provider delivery/retry contract: **FAIL / BLOCKED** (C3.30 remains).
- Overall C3.42: **FAIL / BLOCKED**.

**NO-GO:** API/RPC integration certification, platform payment collection, guaranteed notifications, automated shipment/dispatch execution and full operational onboarding. Internal development and carefully disclosed non-binding partner discovery may continue; no live service should be promised from this source review.

**Safety:** No Production/Staging function calls, SQL/RPC, Auth, Storage, payment, webhook, provider request, secrets read, deployment, merge or user-facing communication was performed.
