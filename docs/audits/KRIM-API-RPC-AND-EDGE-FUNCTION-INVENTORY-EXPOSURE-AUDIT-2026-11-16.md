# KRIM API, RPC and Edge Function Inventory & Exposure Audit
**Date:** 16 November 2026  
**Project:** Supabase `ebltviniygljwwseplph`; repository `rimjhimkrn-web/logistics-saas`  
**Method:** Read-only PostgreSQL function catalog/privilege inspection, deployed Edge Function inventory and repository source-tree comparison. No RPC, Edge Function, webhook or business operation was invoked. No schema or application changes made.

## Executive summary
The live database exposes a large API surface. In the reviewed snapshot, public schema contains 364 functions, of which 81 are trigger-returning functions and 283 are ordinary callable functions. Of those callable public functions, 170 are executable by authenticated users and one is executable by anon. 262 callable functions are SECURITY DEFINER. Internal/private schemas hold additional helpers. There are 21 active Edge Functions.

**Important distinction:** function count is not the same as the number of safe API endpoints. Trigger-returning functions are not ordinary PostgREST RPCs; helper functions may be called only by other routines; EXECUTE grants do not prove that a function is exposed through the Data API; and an Edge Function with JWT verification disabled may have a valid webhook/public/worker design. Each route still needs a documented caller and authorization contract.

## 1. Live database callable surface
| Scope | Count | Notes |
|---|---:|---|
| Public schema functions | 364 | Includes trigger functions |
| Public trigger-returning functions | 81 | Not ordinary client RPC endpoints |
| Public callable functions | 283 | Excludes trigger-returning functions |
| Callable public functions executable by authenticated | 170 | Must be mapped to caller, workspace and permission |
| Callable public functions executable by anon | 1 | `generate_krim_shipment_number()` |
| Callable public SECURITY DEFINER functions | 262 | High-priority review surface |
| Public SECURITY DEFINER functions overall | 332 | Includes trigger functions |
| Private schema ordinary functions | 30 | 23 authenticated-executable in catalog; not assumed Data API exposed |
| krim_internal ordinary functions | 80 | No anon/authenticated EXECUTE in inspected snapshot |

The single anon-callable ordinary RPC, `generate_krim_shipment_number()`, returns a sequential KRIM shipment number by advancing `public.krim_shipment_number_seq`. It does not create a shipment record. This may expose sequence progression/number allocation to anonymous callers and creates avoidable sequence consumption. Review whether the function needs to be callable by anon; do not revoke until trigger/function dependency and grant history are reconciled.

Earlier catalog review also identified eight authenticated SECURITY DEFINER functions with public-first search_path settings. Their exact names and initial review are recorded in the prior security-function batch report. Public callable SECURITY DEFINER routines need per-signature review of authentication, permission scope, AAL2, tenant ownership, row locks, idempotency, object qualification and nested helper calls.

## 2. Edge Function inventory (21 active)
| Edge Function | JWT verification | Intended surface / risk classification |
|---|---|---|
| `razorpay-webhook` | Off | Provider webhook; raw-body HMAC and replay/event idempotency required |
| `krim-ai` | On | Authenticated AI service; user/session, origin, rate-limit and input controls |
| `create-global-razorpay-order` | On | Payment order creation; freight collection gate currently disabled; finance deferred |
| `verify-razorpay-payment` | On | Payment verification; same explicit approval gate |
| `krim-notification-provider-adapter` | On | Privileged provider adapter; deployed source parity needs recovery |
| `global-admin-control` | On | AAL2/platform-admin privileged operations; audit atomicity gap previously identified |
| `krim-global-growth-operations` | On | Internal growth operations; deployed source parity needs recovery |
| `create-razorpay-order` | On | Legacy payment endpoint; must remain retired/410 |
| `process-payment--` | On | Legacy payment processing; inspect caller/dependency before retirement |
| `public-shipment-tracking` | Off | Public token-based tracking; abuse/rate-limit/revocation controls required |
| `krim-public-contact-inquiry` | Off | Public lead intake; throttling and privacy/consent separation required |
| `create-global-cashfree-order` | On | Discontinued provider residue; keep inaccessible until dependency review |
| `verify-global-cashfree-payment` | On | Discontinued provider residue; keep inaccessible until dependency review |
| `cashfree-payment-webhook` | Off | Legacy webhook; HMAC/disablement/dependency review required |
| `krim-payment-verification-status` | On | Authenticated payment status; finance phase only |
| `krim-payment-capability-status` | On | Authenticated payment capability; finance phase only |
| `krim-global-payment-options` | On | Payment option discovery; finance phase only |
| `krim-notification-retry-worker` | Off | Internal worker; independent high-entropy authentication and lease recovery need proof |
| `execute-razorpay-refund` | On | Refund endpoint; disabled by explicit env/version gate; do not enable |
| `krim-driver-gps-update` | On | Driver location endpoint; GPS workflow currently disabled pending consent/legal controls |
| `krim-driver-tracking-session` | On | Driver tracking session; GPS workflow currently disabled pending consent/legal controls |

Five Edge Functions have platform JWT verification disabled: Razorpay webhook, public tracking, public contact inquiry, Cashfree webhook and notification retry worker. Their security models are not interchangeable: webhook HMAC, unguessable tracking token, abuse-resistant public form and authenticated internal worker each require separate tests.

## 3. Deployed source parity
The repository currently contains source directories for 18 of the 21 active deployed Edge Function names. Matching source was not found in the inspected repository tree for:
- `krim-notification-provider-adapter`
- `krim-notification-retry-worker`
- `krim-global-growth-operations`

The live deployment inventory reports versions and deployed source hashes for these functions, but the repository source tree does not provide a matching versioned implementation to review. This is a **P0 provenance/control gap**, not proof of malicious or vulnerable code. Recover exact source from a trusted deployment artifact or owner-controlled backup, verify hashes/version, commit source and configuration history, then review before changing or redeploying.

## 4. Workspace/API ownership model
The intended caller map must cover all nine workspace types:
1. Customer/Shipper — own organization shipments, requests, quotes, documents, support and shipment visibility.
2. Partner/Carrier — own onboarding, compliance evidence, capabilities, quotes, capacity and accepted assignments.
3. Driver — own profile, accepted assignments, exact-leg milestones, evidence and consented tracking.
4. Warehouse — approved facility inventory, QC, reservation, picking, transfer, returns and custody.
5. Customs — jurisdiction-licensed broker assignments and document review; not government clearance authority.
6. Finance — read-only or controlled finance access until final phase; no live payment/posting tests now.
7. Operations Control Tower — operational visibility and controlled dispatch/exception actions under operations permission scope.
8. Enterprise — own enterprise records plus explicitly granted customer/network relationships; enterprise membership alone is insufficient.
9. Admin — platform-admin AAL2 controls, independent approvals and durable audit logging.

A workspace landing page or hidden navigation link is not an authorization boundary. Every RPC, Edge Function, table policy and Storage path must independently validate caller identity, organization membership/type, permission, record ownership, assurance level and current workflow state.

## 5. Critical API governance findings
### P0
- Three active Edge Functions lack matching repository source in the inspected tree. Source parity, exact deployed hash and reviewability are incomplete.
- Public callable SECURITY DEFINER surface is large (262 ordinary callable functions); a complete per-function authorization matrix is not yet present.
- Migration history mismatch blocks safe grant/function cleanup and prevents reliable source-to-live schema provenance.

### P1
- One anonymous callable RPC advances the shipment-number sequence. Confirm necessity and prevent unauthenticated sequence consumption if not needed.
- Worker endpoint `krim-notification-retry-worker` has JWT verification off; independent worker authentication, request replay protection, batch limits and lease recovery need explicit proof.
- Public webhook/tracking/contact endpoints require separate threat models, CORS rules, payload limits, token entropy/revocation, rate limits and abuse telemetry.
- Cashfree order/verify/webhook functions remain active despite the decision to discontinue Cashfree. Do not disable blindly; inspect all consumers, secrets, webhooks and legacy payment records first.
- Payment order, verify and refund functions must remain gated/deferred. No live freight collection or refund test was performed.
- Driver GPS update/session endpoints remain disabled at the business layer pending consent/legal readiness.
- RPC frontend call-site mapping is not yet complete. The repository-wide code search tool did not return usable call-site matches for `supabase.rpc` or `functions.invoke`; static tree review alone cannot certify that every function has a known caller.

## 6. Required API contract register
For each callable database function and Edge Function, record:
- Canonical name, overload/signature, schema, deployed/source version and source hash.
- Whether callable through PostgREST/Data API, direct client SDK, service role, cron, webhook or internal server-to-server path.
- Owning workspace and business capability.
- Required auth state, org type/membership, permission code, AAL, tenant/record predicate.
- Input schema, size/range validation, output data classification and error semantics.
- SECURITY DEFINER/INVOKER, fixed search_path, fully qualified object references and helper call chain.
- Idempotency key, locking/concurrency, retry and side-effect behavior.
- Audit event written atomically and actor attribution.
- Rate limit, CORS, secret/webhook authentication and replay controls for Edge Functions.
- Status: active, deprecated, disabled/gated, internal-only, trigger-only or orphaned.
- Positive and negative staging tests with evidence and last-reviewed date.

## 7. Safe next sequence
1. Recover and commit exact source for the three deployed Edge Functions missing from the repo; verify version/hash parity.
2. Build a machine-generated signature/privilege manifest for all 283 callable public functions and all 21 Edge Functions.
3. Trace browser/server/cron/webhook callers and classify each function as supported API, internal helper, trigger-only, legacy or unused.
4. Review all anon/authenticated callable SECURITY DEFINER functions in risk-ranked batches; test wrong-tenant, wrong-role, revoked membership, AAL1, forged claims, duplicate retries and failure atomicity in isolated staging.
5. Review the anonymous shipment-number function and sequence grants after dependency analysis.
6. Plan Cashfree retirement only after proving no production dependency; keep payment/refund endpoints gated until the final finance phase.
7. Add contract tests and API inventory drift checks to CI.

## Release decision
**NO-GO for unrestricted public/API operations, financial collection, automated external communications and full logistics execution.** This is an inventory and exposure audit, not an exhaustive code review of all 170 authenticated callable routines. Do not revoke grants, modify functions, change Edge Function JWT flags, disable providers or deploy fixes until source parity and migration history are reconciled.

## Change boundary
Read-only PostgreSQL function/privilege catalog inspection, deployed Edge Function inventory and repository tree comparison only. No function was invoked, no Edge Function endpoint was called, no secrets were read, and no production schema, data, provider or user state was changed.
