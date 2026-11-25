# C3.47 — Global integration-provider, external dependency and third-party service reliability readiness
**Date:** 25 November 2026  
**Baseline:** `72d75a18f985ceb09e468839435ee95700e11e46` (immutable source snapshot)  
**Method:** Read-only inspection of the external-provider inventory audit, integration dashboard, dependency map, frontend integration contract, selected Razorpay/Cashfree/notification Edge Function source and dated merchant-readiness evidence. No provider API calls, dashboard access, credential reads, outbound messages, payment actions, webhook replay, deployment or configuration changes were performed.

## Executive verdict
**FAIL / BLOCKED — NO-GO for claiming a connected global provider ecosystem, enabling customer/partner external integrations, or accepting KRIM-collected payments.** The repository contains a useful provider-neutral architecture direction and selected server-side adapters, but the customer-facing integration dashboard materially overstates readiness. Dated provider inventory evidence says most CRM, email, WhatsApp, social, carrier, ERP/TMS/WMS and GPS connections were not verified as connected. Razorpay code exists but commercial eligibility/settlement and checkout remain gated. Cashfree source functions are retired HTTP 410 stubs despite their legacy names. Provider-specific live health, contractual eligibility, webhook lifecycle, outage behavior and complete staging end-to-end evidence are not established by this static gate.

## Evidence reviewed
1. `docs/audits/KRIM-EXTERNAL-INTEGRATION-READINESS-AND-PROVIDER-INVENTORY-AUDIT-2026-11-16.md` — dated provider inventory and readiness findings.
2. `docs/KRIM-END-TO-END-INTEGRATION-STATUS.md` — dated implementation status and historical integration gaps.
3. `docs/architecture/system-dependency-map.md` and `docs/FRONTEND-INTEGRATION-CONTRACT.md` — architecture and intended integration controls.
4. `domains/integrations.html` and `app/enterprise/integrations.html` — integration portfolio/workspace presentation.
5. `supabase/functions/create-global-razorpay-order/index.ts`, `verify-razorpay-payment/index.ts`, `razorpay-webhook/index.ts`, `krim-notification-provider-adapter/index.ts`, and retired Cashfree function source.
6. `docs/finance/KRIM-BANK-AND-RAZORPAY-MERCHANT-READINESS-BASELINE-2026-11-16.md` and `docs/global-payment-provider-expansion-plan.md` — dated merchant and global payment activation gates.

## 1. Integration dashboard truthfulness
**P0 — unsupported READY labels.** The inspected `domains/integrations.html` marks Carrier/3PL APIs, GPS/Telematics, ERP/TMS/WMS, payment providers, REST APIs, webhooks, event-driven systems, scheduled synchronization, API authentication, idempotency, rate controls, audit trail, webhook delivery/retries/dead-letter handling, credential protection, authorization/RLS/RBAC, latency/failure/retry monitoring and incident visibility as READY. It also marks global integration architecture READY. The KPI values are em dashes, and the dated provider inventory found no verified provider connections for most of these categories. These READY labels are not substantiated by provider-specific live connection, successful test, telemetry or contractual evidence and risk misleading enterprise users.

**P1:** `app/enterprise/integrations.html` is an authenticated workspace/directory; the dated Page 101 review says it does not query connector health, API/EDI delivery, webhook latency or automation execution. An authenticated directory is not an integration-health monitor.

## 2. Provider inventory — status must be scoped and evidence-dated
The 16 November 2026 provider audit records the following. These are dated observations, not independently refreshed live status on 25 November:

| Provider/category | Dated evidence | Safe status for launch decisions |
|---|---|---|
| Supabase core | Active project/database/functions in prior inventory | Connected infrastructure; individual flows still require current health and staging tests |
| GitHub / Pages | Repository and Pages workflows | Connected deployment path; not functional E2E certification |
| Telegram | Founder-only internal alert/retry path and authorized test route | Implemented path; delivery/recovery not verified here; not customer/partner messaging |
| HubSpot | No deployed adapter/sync evidence in dated inventory; earlier sample-only CRM records | Not verified / not connected |
| Resend | Adapter checks key presence but returns `sending_enabled:false` | Email sending disabled / not send-ready |
| WhatsApp Cloud API | No deployed send/webhook adapter in dated inventory | Not connected / not verified |
| Facebook / Instagram | Business assets existed; no verified publishing/inbox/lead-sync/webhook implementation | Business presence only; software integration not verified |
| LinkedIn / YouTube | No deployed path or verified integration evidence in dated inventory | Not verified |
| Carrier / ERP / TMS / WMS / GPS / telematics | Architecture/page labels only; no provider-specific credentialed E2E evidence | Architecture only; not connected |
| Port / terminal systems | Page labels connection pending | Not connected |
| Razorpay | Order, verification and webhook code paths exist | Technical code present; merchant/settlement/own-fee readiness unverified; checkout remains disabled |
| Cashfree | Legacy-named functions return HTTP 410 retired response in baseline source | Retired stub; do not route traffic or advertise support |

## 3. Payment provider boundary
**P0 — no payment activation approval.** The selected Razorpay order function explicitly requires `KRIM_FREIGHT_COLLECTION_ENABLED=true` and the matching approval version before creating an order. The verification function separately blocks unpaid freight orders when that approval is absent. The dated 16 November merchant-readiness baseline records India/INR checkout=false, merchant_eligible=false, settlement=false, refunds=false and FX=false; other currencies are planned and disabled. It also records no verified bank/merchant registry, settlement row or own-service-fee flow. These are dated findings, not current live dashboard verification.

Razorpay source includes meaningful safeguards (authenticated user, organization access, confirmed shipment, accepted partner quote, server-side order and webhook verification foundations), but code presence is not provider approval, settlement proof or safe commercial activation. The separate financial C3 findings remain controlling: the captured webhook freight-collection gate bypass identified earlier must be resolved and independently retested before any collection.

**Cashfree:** both inspected order and webhook source are explicit HTTP 410 retired stubs. Their legacy deployment/configuration presence must be reconciled with actual deployed function inventory before retirement is considered complete. Do not retry ambiguous payment states with another provider; reconcile the original provider order first.

## 4. Notification and communications providers
- Telegram adapter is platform-admin gated and has a founder-authorized test route. A successful Telegram API response means provider acceptance/message creation, not human-device delivery or read receipt.
- Resend route reports credential presence only and explicitly sets `sending_enabled:false`; key presence alone does not prove domain authentication, sender verification, deliverability, bounce/complaint handling or webhook processing.
- No customer/partner WhatsApp Cloud API, SMS, general email or social publishing integration was verified in the dated provider inventory.
- Historical notification audits found no general customer/partner outbox delivery evidence and identified delivery-state/claim-recovery defects. Those defects require current revalidation; this gate did not call providers or send messages.

**P1:** Keep all customer/partner automated messaging disabled until provider ownership, approved scopes, consent/opt-out, sender identity, signature validation, idempotency, retry leases, bounce/complaint/suppression and isolated staging delivery evidence are complete.

## 5. External dependency and supply-chain reliability
**P0/P1 gaps:** No canonical, evidence-backed provider registry was demonstrated that records provider owner, environment, exact enabled capabilities/scopes, contract/eligibility, secret reference (never secret value), endpoint/version, webhook signing mode, last successful test, last failure, health freshness, retention, revocation and fallback policy. The dependency map contains aspirational statements (including automated backups/PITR) that conflict with dated backup findings; architecture prose must not be treated as proof of managed-provider features or current service configuration.

The reviewed frontend integration contract correctly requires server-side authorization, idempotency, input validation, safe error states, correlation IDs, provider failure tests and release gates. These are normative rules, not evidence that all providers implement them. No exhaustive dependency inventory with version pinning, lifecycle ownership, outage blast radius, timeout/retry budget, circuit breaker, quota/rate-limit behavior, data portability or exit plan was proven here.

## 6. Prioritized remediation and acceptance criteria
### P0 — before claiming integrations or enabling payments
1. Replace all unsupported READY labels with an evidence-based vocabulary: Connected & tested, Implemented—not tested, Architecture only, Planned, Disabled/retired, Blocked. Display environment, capability scope and last-verified timestamp.
2. Keep Razorpay checkout and all KRIM collection disabled until merchant/KYC/legal/tax/bank settlement, refund/dispute, canonical finance and full webhook/ledger controls pass independent staging and controlled live approval.
3. Ensure Cashfree is inaccessible and reconcile deployed inventory, frontend callers, secrets references and provider configuration before a reviewed retirement deployment.
4. Establish a canonical integration registry and dependency owner map with least-privilege scopes, environment separation, secret references, contract/eligibility evidence, webhook and status lifecycle, freshness, revocation and audit trail.
5. For each enabled provider, prove isolated staging happy path plus invalid credentials, unauthorized scope, malformed/oversized request, duplicate/replay/out-of-order webhook, timeout, rate limit/quota, provider outage, retry exhaustion, dead-letter recovery and disconnect/revocation.

### P1 — reliability and scale
- Implement provider-specific health probes and timestamped status; do not infer health from configured credentials or function deployment.
- Define bounded timeout/retry/backoff, circuit breaking, idempotency and reconciliation before failover; never automatically switch payment provider on ambiguous outcomes.
- Enforce customer/partner consent and opt-out; distinguish queued, provider accepted, delivered and read where evidence exists.
- Reconcile webhook event identity/signature/raw-body verification, tenant mapping, replay windows, event retention, retries and operator escalation for every provider.
- Pin dependencies and lockfiles; review third-party scripts/CDNs, package lifecycle and provider API version compatibility.
- Define provider exit/data-export/deletion and incident communication plans.

### Required pass evidence
- Current provider/account ownership and contract eligibility confirmed in the provider's official console or documentation without exposing secrets.
- Exact capability/environment/scope recorded in the canonical registry.
- Isolated staging E2E traces with redacted correlation IDs for success and negative/failure cases.
- Verified webhook signatures, duplicate/replay/out-of-order handling, retries, dead-letter recovery and tenant isolation.
- Measured provider latency/error/quota health and outage/failover/reconciliation evidence.
- For payments: merchant approval, actual settlement/refund and bank reconciliation evidence, plus independent finance/security retest.
- Customer-facing dashboards and status claims match verified live evidence.

## Final decision
**C3.47 FAIL / BLOCKED.** NO-GO for a “fully integrated global ecosystem” claim, customer/partner external integration activation, automated customer/partner messaging, or KRIM-collected payment activation. Selected internal/core paths and source-level safeguards are PARTIAL PASS only. Most external providers remain architecture-only, planned, disabled or unverified. This is a static source and dated-evidence audit, not a live provider-health, merchant-eligibility, security certification or end-to-end integration test.

No Production/Staging provider calls, credential reads, messages, emails, social posts, payment orders, refunds, webhook replay, configuration changes, deployments, merges or external communications were performed.
