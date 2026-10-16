# KRIM Frontend Integration Contract

**Status:** Active contract; implementation must be verified against the live repository and Supabase project.  
**Scope:** Browser pages, shared frontend modules, Supabase Auth, Edge Functions, and database-backed workflows.

## 1. Integration Rules
1. Browser code may use only the Supabase project URL and publishable/anon key. Never expose the service-role key, Razorpay secret, webhook secret, or other privileged credentials.
2. Treat the browser as untrusted. Authorization, tenant membership, pricing, payment state, assignment, and lifecycle transitions must be validated server-side.
3. Use the shared configuration/client modules where available; do not create competing Supabase clients or hard-code different project credentials across pages.
4. Use Edge Functions or narrowly scoped RPCs for privileged actions. Direct table access is permitted only when RLS and grants explicitly allow the requested operation.
5. Every user-facing async action must show loading, success only after server confirmation, recoverable error, and retry states.
6. Render user-supplied data as text; do not inject untrusted content through `innerHTML`.
7. Public endpoints require input validation, rate limiting/abuse controls appropriate to risk, safe error responses, and server-side logging without secrets or unnecessary personal data.

## 2. Authentication and Tenant Context
- Resolve the current authenticated user from Supabase Auth; never trust a user ID or organization ID supplied only by the client.
- For tenant-scoped requests, derive membership and permissions server-side and enforce organization isolation in RLS/RPC/Edge Function logic.
- Sign-in state is not equivalent to permission. Check the specific action permission for privileged and financial operations.
- Handle expired sessions, revoked access, and missing organization membership without exposing other tenants' data.

## 3. API Contract
- Document each endpoint's method, authentication requirement, request schema, response schema, expected status codes, and side effects.
- Validate type, length, format, allowed enum values, ownership, and state transitions at the server boundary.
- Use idempotency keys for payment creation, webhook processing, booking/creation retries, and other operations where duplicate execution could cause financial or operational harm.
- Never report payment success based only on a redirect or client callback. Verify the authoritative server-side payment record/provider signature and final state.
- Public tracking responses must reveal only fields intended for public access and must not expose internal IDs, customer contact details, prices, or tenant data unless explicitly authorized.

## 4. Lifecycle Integration
Each UI workflow must map to a defined server-side lifecycle:
- Account: registration, verification, authentication, membership, recovery, deactivation/deletion requests.
- Shipment: draft, quote/confirmation, assignment, pickup, transit, delivery, exception, cancellation/closure as allowed by the state machine.
- Payment: order creation, provider checkout, verified webhook, ledger entry, refund/dispute and settlement states.
- Partner: application, verification, approval, capability/coverage, assignment eligibility, performance and suspension/offboarding.

The UI must not invent or independently advance lifecycle states. The backend is authoritative.

## 5. Error Handling and Observability
- Use stable machine-readable error codes and safe user-facing messages.
- Log correlation/request IDs, actor, tenant context where safe, action, outcome, and timestamp server-side.
- Do not log passwords, access tokens, payment secrets, full payment instrument data, or unnecessary personal information.
- Provide accessible labels, keyboard operation, mobile layout, and clear empty/loading/error states.

## 6. Release Gate
Before calling an integration complete, verify:
- [ ] Correct endpoint, HTTP method, headers and payload.
- [ ] Authentication and authorization enforced server-side.
- [ ] RLS/grants and tenant-isolation tests pass.
- [ ] Success state follows authoritative backend confirmation.
- [ ] Invalid, unauthorized, duplicate, timeout and provider-failure cases tested.
- [ ] No privileged secrets in frontend bundle or repository.
- [ ] Browser test on mobile and desktop, plus deployed environment check.
- [ ] Logs and rollback/recovery path reviewed.

## 7. Related Architecture
See [global system architecture](architecture/global-system-architecture.md), [application boundaries](architecture/application-boundaries.md), [tenant isolation](architecture/tenant-isolation-model.md), [trust boundaries](architecture/trust-boundaries.md), [threat model](architecture/threat-model.md), [data flow](architecture/data-flow-map.md), and [definition of done](architecture/definition-of-done.md).

**Important:** This contract defines requirements. A checked document does not prove that runtime integration or production readiness has been tested.
