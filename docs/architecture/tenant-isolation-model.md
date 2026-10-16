# KRIM Logistics OS — Tenant Isolation Model

**Status:** Required security design; implementation must be tested against the current database and functions.

## 1. Security Objective
Every organization/customer/partner tenant must be unable to read, alter, infer, or trigger actions on another tenant's protected resources unless a documented platform-level workflow explicitly authorizes that access.

## 2. Identity and Authorization Chain
For each request, establish and validate:
1. Authenticated principal (or explicitly public/anonymous route).
2. Active user/account status.
3. Organization membership and membership status.
4. Role and permission for the requested action.
5. Resource tenant/owner and allowed lifecycle state.
6. Additional controls for sensitive actions (step-up authentication, approval, audit, or idempotency where appropriate).

Never trust a client-supplied organization ID, role, permission, payout destination, price, or status as authoritative.

## 3. Database Enforcement
- Enable RLS on every tenant-owned table exposed through the Data API.
- Revoke broad table privileges where direct client access is not required.
- Policies must check membership and action permission against trusted database records or carefully designed security-definer helpers.
- Include both row visibility and write checks; `USING` and `WITH CHECK` conditions must be appropriate.
- Keep platform-wide data in separate tables/views or expose it through narrowly authorized functions.
- Review views for invoker/definer behavior and ensure views do not bypass intended RLS.
- Security-definer functions must have a fixed safe search path, minimal grants, explicit authorization, and narrowly scoped behavior.

## 4. Edge Functions and RPCs
- Verify JWTs for authenticated endpoints; for public endpoints, validate input and restrict output/side effects.
- Resolve the caller from the verified JWT. Do not accept a user ID as proof of identity.
- Use service-role access only server-side and only after explicit authorization and validation.
- For service-role operations, independently enforce tenant/resource ownership because RLS is bypassed.
- Validate all state transitions and make duplicate requests safe where necessary.
- Apply rate limiting/abuse controls to anonymous endpoints and expensive operations.

## 5. Required Isolation Tests
Use two unrelated test organizations A and B and users A1/B1. Test:
- [ ] A1 cannot select B's shipments, quotes, invoices, attachments or partner records.
- [ ] A1 cannot insert or update a row into B's tenant by changing the submitted organization ID.
- [ ] A1 cannot invoke a privileged RPC/Edge Function to act for B.
- [ ] A1 cannot access cross-tenant storage objects or signed URLs.
- [ ] Anonymous requests cannot access private tenant data.
- [ ] Removed/suspended members lose access without relying on frontend hiding.
- [ ] Platform-admin exceptions are explicit, permission-checked and audited.
- [ ] Views, functions, triggers, realtime channels and exports preserve the same boundary.
- [ ] Tests run with realistic JWTs and database grants, not only service-role credentials.

## 6. Audit and Incident Handling
Record sensitive access and administrative actions with actor, target tenant/resource, action, result, timestamp and correlation ID. Minimize personal data and never log secrets. Define incident response, credential rotation, containment and evidence retention separately.

## 7. Release Gate
Tenant isolation is not considered proven until automated negative tests pass against the deployed schema and Edge Functions. RLS being enabled alone is insufficient.

Related: [application boundaries](application-boundaries.md), [trust boundaries](trust-boundaries.md), [threat model](threat-model.md), [data flow](data-flow-map.md), [production readiness](production-readiness-criteria.md).
