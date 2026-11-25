# Phase 01 — Gate 01G: Integrations and backend surface inventory

Date: 2026-11-25
Immutable source baseline: 72d75a18f985ceb09e468839435ee95700e11e46
QA branch: qa/phase-00-baseline-2026-11-25
Scope: source-tree inventory of Supabase Edge Function directories and representative integration implementations, with web platform in scope. Native mobile source is excluded from web readiness conclusions.

## 1. Verdict

**PASS WITH LIMITATIONS for source-tree inventory; FAIL / BLOCKED for integration readiness and runtime certification.** The immutable repository contains 20 Supabase Edge Function entrypoint directories and source implementations for Razorpay, driver GPS/tracking, Telegram notifications, public inquiries, public tracking, AI and admin control. This establishes source presence only. It does not prove deployment, invocation wiring, provider credentials, provider account readiness, network reachability, successful delivery, webhook correctness or operational readiness.

The P0 Production-client bypass recorded in Gate 01F remains open. No staging runtime testing is permitted until the shared client/environment isolation remediation is verified.

## 2. Edge Function census

The immutable tree contains 20 `supabase/functions/*/index.ts` entrypoints:

- Payments: create-global-razorpay-order, create-razorpay-order, verify-razorpay-payment, razorpay-webhook, execute-razorpay-refund, krim-global-payment-options, krim-payment-capability-status, krim-payment-verification-status.
- Legacy/disabled-looking Cashfree paths: cashfree-payment-webhook, create-global-cashfree-order, verify-global-cashfree-payment.
- Driver tracking: krim-driver-gps-update, krim-driver-tracking-session.
- Notifications: krim-notification-provider-adapter, krim-notification-retry-worker.
- Public operations: krim-public-contact-inquiry, public-shipment-tracking.
- Platform: krim-ai, global-admin-control.
- Additional legacy-looking entrypoint: process-payment--.

Three Cashfree entrypoints have identical 807-byte source blob SHA `e43c5dcf1c1712cb0c92f13f12f9b61e480952a5`; this strongly suggests stub/placeholder duplication, but deployed function state was not queried. `process-payment--` is a separate short 942-byte entrypoint and needs owner disposition. Do not infer deployed status from repository directories.

## 3. Observed dependency map (static source)

| Surface | Observed backend objects / providers | Readiness limitation |
|---|---|---|
| Razorpay order creation | krim_shipments, krim_quotes, krim_shipment_partner_assignments, krim_capacity_leg_bindings, krim_capacity_reservations, krim_payment_capability_registry, payment_orders; krim_has_organization_access; Razorpay Orders API | Static source only; Gate C3.60 P0 webhook kill-switch bypass and finance model conflict remain blockers |
| Razorpay webhook | payment_webhook_events, krim_refund_requests, payment_orders, krim_refund_request_events, krim_financial_transactions; krim_internal_reconcile_razorpay_captured_payment | No provider event or database execution; must remediate and test freight-collection kill switch before any live finance |
| Razorpay verification/refund | payment_orders, shipment/quote/assignment/capacity binding; krim_has_organization_access; krim_internal_reconcile_razorpay_captured_payment; krim_claim_razorpay_refund_execution; Razorpay refund endpoint | No actual payment/refund; refund permissions, idempotency, dual control and reconciliation not runtime proven |
| Driver GPS / tracking session | krim_driver_assignments, krim_driver_tracking_sessions, krim_driver_profiles, krim_organization_members, krim_organizations, krim_shipment_partner_assignments, krim_tracking_events | Source paths exist; consent, device integrity, retention, authorization, location accuracy and legal basis not runtime verified; GPS remains disabled pending approval |
| Public tracking | krim_shipments, krim_tracking_events, krim_driver_tracking_sessions, partner assignments, driver assignments/profiles, organizations, locations | Public access/rate limiting, privacy and freshness not runtime verified |
| Notification adapter / retry | krim_has_permission RPC; Telegram Bot API sendMessage endpoint | No table literal surfaced in sampled implementation; token/provider configuration and actual send/retry/dead-letter behaviour unverified |
| Public contact inquiry | krim_notification_outbox; krim_check_public_inquiry_ip_limit, krim_submit_public_contact_inquiry, krim_internal_link_public_inquiry_to_service_request; Telegram Bot API | No actual inquiry submitted or notification sent; IP trust/proxy and abuse controls remain Phase 00 blockers |
| AI | ai_conversations, ai_messages, krim_organizations, krim_shipments, driver/warehouse/customs/finance/partner/exception/alert tables; krim_ai_current_user_context, krim_consume_ai_rate_limit; OpenAI Responses API | External AI request, data minimization, tenant scope, budget/rate limit and provider processing not tested |
| Admin control | krim_user_role_assignments, krim_audit_events, krim_public_contact_inquiries, krim_inquiry_followups, krim_security_roles | Admin function authorization and tenant isolation not runtime verified |
| Payment capability/status | krim_payment_capability_registry; payment_orders, quotes, shipments, financial transactions; krim_has_organization_access | Readiness flags do not prove provider account/country/currency capability or successful checkout |
| Shared browser app | app-store and backend-modules clients reference preferences, memberships, organizations, activity, consent, integrations, export requests, offline queue and client error reports | Hard-coded Production client bypass documented in Gate 01F; P0 |

## 4. External provider and integration inventory

Observed literal provider endpoints in sampled server source:
- Razorpay Orders API and payment refund API.
- Telegram Bot API `sendMessage`.
- OpenAI Responses API.
- Supabase JS ESM distribution and Supabase project URL.
- OpenStreetMap link in customer shipment UI.
- Public domain references for KRIM site links.

Resend/email delivery was not observed in the sampled Edge Function implementations. Prior Phase 00 source audit records Resend sending as disabled/not verified; treat email delivery as NOT PROVEN. No Stripe implementation was established in this inventory. Cashfree function directories remain in source despite the intended discontinuation; three sampled entrypoints share an identical short stub-like blob and require explicit retirement or documented disabled disposition.

## 5. Important inventory limitations

1. This is a targeted static source inventory, not an exhaustive AST call graph of every HTML inline script, dynamic import, JS/TS file, generated bundle or workflow.
2. The 20 Edge Function directories do not establish which functions are deployed to Production or Staging, which are enabled, or which routes invoke them.
3. A search that finds no literal `functions.invoke()` or `storage.from()` in sampled modules does not prove absence; wrappers, direct fetch calls, SQL triggers, database webhooks and dynamic names can hide dependencies.
4. No complete table/RPC-to-RLS/grant/permission crosswalk was performed here.
5. No Resend, WhatsApp Cloud API, Facebook, LinkedIn, HubSpot, Google Maps, carrier API or customs authority integration was live-tested.
6. Native mobile app source directories were visible in the tree but excluded from the web platform QA scope.

## 6. P0 / P1 actions

### P0
- Close Gate 01F: consolidate all browser clients behind one fail-closed environment-aware factory; prove Staging project ref on every relevant route before any test data or runtime operation.
- Remediate and independently verify C3.60 Razorpay webhook freight-collection kill-switch bypass. Keep freight collection, refunds, payouts and settlement disabled until approved.
- Preserve driver GPS and dispatch as disabled until privacy/legal/device and assignment controls are approved and tested.
- No provider send, payment, refund, webhook replay or external notification testing without explicit approval and isolated test credentials.

### P1
- Produce exhaustive route-to-function invocation graph and deploy-state inventory.
- Map every Edge Function to caller routes, authentication mode, required secrets by name only (never read values), database tables/RPCs, external providers, retry model and failure handling.
- Resolve Cashfree stubs and `process-payment--` with explicit owner disposition; remove obsolete source only under a separate approved change.
- Verify Telegram outbox/retry delivery, Resend email, WhatsApp and founder alert channels in isolated test mode after safety gates.
- Cross-reference payment and tracking functions with current grants, RLS, role permissions, tenant boundaries and kill switches.
- Inventory all Storage buckets, upload/download call sites, signed URL lifecycle and document/POD access paths.
- Establish integration health checks, provider incident handling, idempotency, dead-letter/replay controls, audit trail and cost limits.

## 7. Safety and release disposition

Read-only immutable GitHub source inspection only. No Supabase SQL/RPC, deployed function listing, Auth, Storage, secrets, provider API, payment, refund, webhook, notification, browser or deployment operation was performed. No live data was changed. Phase 01 remains IN PROGRESS. Phase 00 remains FAIL / BLOCKED. No Staging synthetic users or external operational onboarding are cleared.
