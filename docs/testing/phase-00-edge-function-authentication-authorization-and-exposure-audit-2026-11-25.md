# Phase 00 — Edge Function Authentication, Authorization and Exposure Source Audit
Date: 2026-11-25
Repository: rimjhimkrn-web/logistics-saas
Branch: qa/phase-00-baseline-2026-11-25

## Executive verdict

**All 21 Edge Function entrypoints were inventoried and source-sampled. This is not a deployed-function audit. Runtime JWT verification settings, deployed versions, secrets, provider behavior and negative authorization tests remain NOT VERIFIED.**

Positive controls exist in the main privileged flows: authenticated user resolution, organization access checks, selected AAL2/permission checks, signed Razorpay webhook verification, payment idempotency/reconciliation, driver assignment/membership/consent binding, and secret-gated notification workers. Several legacy payment endpoints return HTTP 410.

Critical gaps remain:
1. Public shipment tracking uses a 32-hex-character bearer tracking token but no visible per-IP/per-token rate limit or abuse telemetry in the Edge Function.
2. Global admin control uses wildcard CORS and derives platform role from active role assignments; every action and role-assignment scoping must be tested. Browser origin is not an authorization control.
3. Public inquiry limits are present, but the body-size guard trusts Content-Length and does not visibly bound the actual streamed body.
4. Edge deployment JWT verification settings and actual deployed code parity cannot be established from this source snapshot.
5. No live tests were run; no provider was called.

## 1. Inventory

The QA repository tree contains 21 `supabase/functions/*/index.ts` entrypoints:

| Function | Source SHA | Source-level classification |
|---|---|---|
| cashfree-payment-webhook | e43c5dcf1c1712cb0c92f13f12f9b61e480952a5 | Deprecated 410 response |
| create-global-cashfree-order | e43c5dcf1c1712cb0c92f13f12f9b61e480952a5 | Deprecated 410 response; same source as retired Cashfree handler |
| create-global-razorpay-order | 24050bf290c9ea8c47a0f4e62156df4f50a0dcd0 | Authenticated customer payment order; service-role DB client |
| create-razorpay-order | d35de927f4e36608a27c04c9c43278ef3fa6f20a | Deprecated 410 response |
| execute-razorpay-refund | e2229e04b8709c92759afee913e354fa41197fe4 | Feature/approval gated; finance AAL2 claim RPC |
| global-admin-control | 987378aa3ee12cc11b522f615e84ce91e21885a2 | Platform admin control plane; AAL2 |
| krim-ai | 2f25f40d270bb27453cc63e7ec8c60128e9ab97f | Authenticated AI assistant; self-scoped read context and rate limit |
| krim-driver-gps-update | 45453918a0e9b4ce95c1a1d6ebf3c2a5a79f1d9a | Authenticated driver tracking; feature/legal-consent gate |
| krim-driver-tracking-session | 488e1ebcb011f03c804cd19b1bb37d716688dba0 | Authenticated driver tracking session; consent and assignment binding |
| krim-global-payment-options | e34b630c726b0e7aebc62529f3dde1404ff1de00 | Authenticated capability listing; service-role read |
| krim-notification-provider-adapter | bed677b115b46c5036f0f33a37d91b1fe1594953 | Platform-admin-only provider test/config inspection |
| krim-notification-retry-worker | f8300d4fcb3aff58ea94d9cf0461dd13280f2cfa | Cron-secret or platform-admin gated worker |
| krim-payment-capability-status | 6d5179052acf1a9ca540a248d1ac4d9df3cf7226 | Authenticated capability status read |
| krim-payment-verification-status | bd1036e80ce8486092926b65457e999539a85138 | Authenticated organization-scoped payment status |
| krim-public-contact-inquiry | 0e362378d58b19f98566cae739d603915bb56d79 | Public submission; consent, validation, IP/email throttles |
| krim-resend-email-worker | b530cec0f436db5a85d54aecf4c1561fe4936b96 | Cron-secret-only Resend worker |
| process-payment-- | cc1e02f74689cf91dcc874f32e3c5ede4d365129 | Deprecated 410 response |
| public-shipment-tracking | a2699a475005d7081c5cebb26909de30d333c7c9 | Public tracking token endpoint; service-role read |
| razorpay-webhook | 1c19590355734d446a45c28d2bbadb68309a5efb | Provider webhook; raw-body HMAC signature verification |
| verify-global-cashfree-payment | e43c5dcf1c1712cb0c92f13f12f9b61e480952a5 | Deprecated 410 response |
| verify-razorpay-payment | bdc14ab6de7c8154ccbbe408ad9c75f7f771c4af | Authenticated payment verification; org/quote/assignment binding |

## 2. Function-level findings

### A. Global admin control — high impact, source controls present

- Requires Bearer token and validates the user with Supabase Auth.
- Checks authenticator assurance and explicitly requires currentLevel aal2; assurance lookup errors return 500.
- Uses service-role client only after user authentication.
- Resolves active role assignments and requires platform_admin or platform_superadmin.
- Role assignment, role revocation, user disable/enable and global session revocation are further restricted to platform_superadmin.
- Owner testing authorization requires the sole active platform_superadmin assignment to belong to the caller.
- Writes audit events for control-plane actions.

**Risks / tests:** CORS allows every origin. This does not bypass Bearer/AAL2 authorization, but unnecessarily permits any website to initiate authenticated browser requests if a token is available. Restrict to explicit KRIM origins. Confirm platform role assignments cannot be scoped/created in a way that grants unintended global privilege; test self-escalation, duplicate role rows, null organization scope, inactive assignments, and role removal while a session remains active. Confirm every mutation audit insert is checked: the helper currently awaits the insert but does not fail the business action if the audit insert returns an error.

### B. Public shipment tracking — critical exposure surface

- Accepts a public tracking reference consisting of exactly 32 hexadecimal characters.
- Uses a service-role client and resolves the token against the shipment row.
- Returns shipment number, status, route locations, dates, public events and GPS position only when an active driver tracking session independently satisfies linked partner assignment, driver assignment, active membership, active organization, verified driver profile, native platform and consent integrity checks.
- Terminal shipment states suppress GPS.
- GPS session and consent linkage is substantially stronger than a simple token-to-coordinate lookup.

**Gap:** no visible per-IP, per-token or global rate-limit check in this function. No request-size guard, abuse counter, lockout/backoff, or security event is apparent. A 128-bit token is not readily guessable, but leaked references can be queried at scale and endpoint resource consumption can be abused. Add distributed throttling, bounded body parsing, privacy-safe access telemetry and alerting. Do not return more event/location precision than the public tracking purpose requires.

### C. Public contact inquiry — guarded public intake, body limit needs hardening

Positive:
- POST only; requires privacy consent; validates field lengths and email syntax.
- Honeypot returns a generic success without storing.
- Uses Cloudflare-provided cf-connecting-ip rather than caller-controlled X-Forwarded-For.
- Calls IP throttle RPC and an email-based submission RPC; fails closed if IP throttle lookup fails.
- Uses service role only server-side; records enquiry/outbox and attempts founder Telegram delivery.

Risk:
- It checks declared Content-Length <= 9000, but does not visibly enforce a byte limit on the actual body stream. Requests without Content-Length or with misleading framing need bounded stream parsing.
- No CAPTCHA/bot challenge is visible in this function; rate-limit and honeypot are helpful but not equivalent.
- Source-page attribution is accepted as input but normalized for notification.
- Direct Telegram notification sends enquiry PII to the configured founder chat. Confirm access, retention and consent/privacy disclosures; no message was sent during this audit.

### D. Razorpay payment order and verification

- Order creation and verification require a valid Supabase user token.
- Service-role client is created separately and the user token is explicitly verified with Auth.
- Order creation resolves shipment's customer organization and calls krim_has_organization_access before continuing.
- It checks shipment status and accepted quote/assignment/capacity binding before collection.
- Verification validates the Razorpay payment signature and cross-checks payment order, shipment, customer organization, accepted quote and assignment.
- Freight collection remains feature/approval gated; same-payment retries have explicit idempotency/recovery handling.
- Payment status endpoint checks authenticated identity, organization access, and matching payment order, quote, shipment and completed transaction before reporting paid.
- Legacy create-razorpay-order and payment process endpoints return 410.

**Runtime gaps:** no synthetic positive/negative payment tests, signature tamper tests, replay/concurrency tests, webhook-to-ledger reconciliation, or provider sandbox evidence in this audit. Keep real money disabled during QA.

### E. Razorpay webhook

- Reads raw request body before parsing.
- Verifies HMAC signature using RAZORPAY_WEBHOOK_SECRET and constant-time byte comparison.
- Requires provider event ID and supports an explicit event allowlist.
- Uses service-role client only after signature validation.
- Source contains event idempotency and payment/refund reconciliation logic, including organization/ledger binding checks.

**Runtime gaps:** no invalid-signature, malformed-hex, duplicate event, concurrent retry, event-order inversion, refund replay or ledger consistency tests were executed. Confirm event IDs are unique in the database and webhook payload size is bounded. Provider webhook must not rely on browser JWT verification settings.

### F. Refund execution

- Explicitly disabled unless both legacy refund execution flag and approval version are set.
- Requires authenticated user.
- Calls database claim RPC; comments and prior migration audit indicate database enforces AAL2, finance permission, reviewer identity, requester/reviewer separation, full amount and payment-state checks.
- Reuses stable idempotency key and leaves uncertain provider outcomes pending for webhook reconciliation.

No refund was initiated. Do not enable this legacy route without a separate approval and end-to-end sandbox verification.

### G. Driver tracking functions

- Both functions validate Supabase user token.
- Assignment is looked up for that authenticated user.
- Requires active driver membership, active organization, verified driver profile/licence, in-transit assignment and linked accepted/active partner assignment with matching shipment leg.
- Tracking start requires exact consent version, archived notice text/hash and native Android/iOS platform.
- GPS update validates coordinate ranges, accuracy, timestamp, collection method, platform, active session and consent fields.
- GPS upload is fail-closed behind exact feature flag and legal approval version. The consent notice itself says GPS remains disabled pending approved retention/deletion/legal-hold terms.

No GPS data was created or changed. Confirm no deployment has enabled the feature without the exact legal approval and retention controls. Add a database-backed concurrency limit for active sessions and a per-user/assignment rate limit; current frequency filtering is derived from latest event and should be tested under concurrent requests.

### H. Notification workers and adapter

- Resend worker requires a dedicated cron secret and uses service-role DB access; sends with an idempotency key and bounded provider timeout.
- Telegram retry worker accepts either a dedicated cron secret or authenticated platform admin permission before using service role.
- Provider adapter requires authenticated platform-admin permission. Resend path only reports credential availability and states sending is disabled; Telegram action=test sends an actual message to configured chat.
- No worker/provider endpoint was invoked. Do not run the Telegram test action without explicit approval because it sends an external message.
- Verify cron secrets are >=32 chars, rotated, not exposed in logs, and that public JWT verification settings do not accidentally bypass handler-level checks. Confirm claim/finish RPCs are atomic and idempotent.

### I. KRIM AI

- Requires Bearer token and validates current user.
- Resolves user roles/organizations through a self-scoped RPC; consumes a database rate limit and fails closed if unavailable.
- Reads live operational context using the user's authenticated client and own organization IDs.
- Prompt tells the model role is context, not permission, and not to invent rates, tracking, payment or verification facts.
- Provider call has a 30-second timeout.

Still required: prompt-injection tests using untrusted shipment/document content, tenant-crossing attempts, oversized prompt/body, rate-limit concurrency, model-provider data handling review, and proof that no AI action path bypasses ordinary RPC permissions. Keep AI read-only for operational decisions unless a separate action authorization layer exists.

### J. Payment capability/status endpoints

- Require a valid user token and use service-role client for read queries.
- Return provider capability/configuration and operational verification flags; payment status endpoint checks organization access and shipment/quote/payment linkage.
- Confirm these endpoints disclose only non-sensitive capability metadata and do not expose merchant credentials or internal secrets. Test anonymous access and cross-tenant payment IDs.

### K. Deprecated Cashfree and legacy payment entrypoints

- cashfree-payment-webhook, create-global-cashfree-order and verify-global-cashfree-payment return HTTP 410 with Razorpay-only guidance.
- create-razorpay-order and process-payment-- also return HTTP 410.
- Their deployment must be verified to match source; do not rely on the repository alone to establish they are disabled in the live project.

## 3. Deployment configuration gap

The inspected repository tree did not contain a Supabase `config.toml` file. Therefore this audit cannot establish `verify_jwt` settings for each deployed function, whether any function is publicly invokable at the platform gateway, deployed function versions, or actual secret names/values.

Handler-level authentication is visible for most sensitive authenticated functions. Public tracking, public inquiry and provider webhooks are intentionally unauthenticated at the business layer and must use their own token/throttle/signature controls. Confirm gateway configuration and deployed source parity before testing.

## 4. Required negative tests — NOT RUN

Only in an isolated, proven Staging project with synthetic fixtures, fake payment provider/sandbox, mail sink and explicit execution approval:

| ID | Test | Expected |
|---|---|---|
| EDGE-01 | Anonymous call to every authenticated endpoint | 401/403; no privileged data or side effect |
| EDGE-02 | Expired, malformed and wrong-project JWT | Reject |
| EDGE-03 | AAL1 user invokes global-admin and refund paths | Reject server-side |
| EDGE-04 | Active user without platform role invokes admin endpoints | Reject |
| EDGE-05 | Non-superadmin attempts role/user/session mutation | Reject |
| EDGE-06 | Superadmin attempts self-escalation or unauthorized organization-scoped role assignment | Deny or require explicit policy-approved scope |
| EDGE-07 | Audit event insert fails during privileged action | Fail safely or record durable audit elsewhere |
| EDGE-08 | Public tracking token malformed, random, expired/revoked or belonging to another test tenant | Generic denial; no data leakage |
| EDGE-09 | Public tracking high-rate burst from one IP/token and distributed IPs | Bounded responses, throttle and alert |
| EDGE-10 | Public tracking oversized/chunked body | Reject before expensive DB work |
| EDGE-11 | Public contact body exceeds actual byte limit without Content-Length | Reject; no DB/provider work |
| EDGE-12 | Public contact repeated IP/email submissions and forged X-Forwarded-For | Throttle based on trusted edge IP and server-side email limit |
| EDGE-13 | Public contact privacy consent absent / honeypot filled | Reject or generic success without storing |
| EDGE-14 | Payment order for shipment in another organization | Deny |
| EDGE-15 | Payment order for unconfirmed shipment or unaccepted quote/assignment | Deny |
| EDGE-16 | Tampered Razorpay payment signature/order/amount/currency | Deny; no paid status |
| EDGE-17 | Duplicate/concurrent payment verification | One canonical payment/ledger effect |
| EDGE-18 | Webhook invalid signature, altered raw body, missing event ID | Reject |
| EDGE-19 | Duplicate/out-of-order webhook events and refund retries | Idempotent, reconciled ledger |
| EDGE-20 | Refund execution while disabled | 503; no provider call |
| EDGE-21 | GPS upload with flag off, stale consent, wrong user/assignment/org/session | Deny; no GPS row |
| EDGE-22 | Concurrent tracking session starts and GPS burst | One valid session; bounded event rate |
| EDGE-23 | Notification worker without cron secret/admin JWT | Reject; no provider call |
| EDGE-24 | Resend retry replay with same outbox/idempotency key | One provider delivery or documented provider idempotency |
| EDGE-25 | Telegram test action without explicit owner approval | Do not execute; test gate must prevent accidental external send |
| EDGE-26 | AI prompt injection in user input or retrieved content | No data exfiltration, permission bypass or unauthorized action |
| EDGE-27 | Cross-org payment capability/status and AI context requests | No unauthorized tenant data |
| EDGE-28 | Call deprecated Cashfree/legacy payment endpoints | 410; no external payment or database mutation |
| EDGE-29 | Verify deployed function code/config against this commit | Exact provenance and JWT gateway settings recorded |

## 5. Readiness status

| Control | Status |
|---|---|
| 21-entrypoint source inventory | PASS — repository tree/source only |
| Global admin user/AAL2/platform-role checks | PASS — source only |
| Razorpay order/verification user and organization checks | PASS — source only |
| Razorpay webhook raw-body signature validation | PASS — source only |
| Refund feature/approval gate | PASS — source only |
| Driver tracking assignment/membership/consent checks | PASS — source only |
| AI user scoping and rate-limit call | PASS — source only |
| Public contact consent/validation/IP-email throttles | PARTIAL — body stream bound not proven |
| Public tracking token entropy/record binding | PASS — source only |
| Public tracking rate limiting and abuse telemetry | NOT IMPLEMENTED in sampled handler |
| Global admin CORS origin restriction | REMEDIATION REQUIRED |
| Edge JWT gateway configuration | NOT VERIFIED |
| Deployed function/source parity | NOT VERIFIED |
| Effective service-role/RPC permissions | NOT TESTED |
| Provider sandbox/webhook/runtime tests | NOT TESTED |
| All 29 negative tests | NOT RUN |

## 6. Required remediation / next gates

1. Add per-IP/per-token throttling, bounded request parsing and privacy-safe abuse telemetry to public shipment tracking.
2. Enforce actual byte limits on public inquiry request streams; do not trust Content-Length alone.
3. Restrict global-admin CORS to approved KRIM origins; preserve server-side Bearer/AAL2/role checks.
4. Review role assignment scope invariants and require durable audit success for privileged changes.
5. Verify deployed Supabase Edge Function JWT settings and compare every deployed function version with reviewed source.
6. Add concurrency/idempotency tests for GPS sessions, payment verification, webhooks and notification outbox workers.
7. Keep GPS disabled, refund execution disabled, Cashfree deprecated, and external notification test routes unused until explicitly approved.
8. Run the negative test matrix only after Staging isolation and deployment parity are proven.

## 7. Safety and release decision

Read-only QA branch source review only. No Supabase connection/query, Edge Function invocation, secret read, Telegram/Resend/Razorpay call, GPS event, payment/refund, user mutation, configuration change, deployment or merge was performed.

**Phase 00 remains IN PROGRESS. Edge Function runtime security is NOT VERIFIED. Do not open unrestricted real-user or financial operations on source inspection alone. NO EVIDENCE = NO PASS.**
