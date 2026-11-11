# KRIM Workspace Access and RLS Review — 2026-11-11

## Scope and method
Read-only review of the production PostgreSQL RLS policies for the customer, partner and driver workspace tables, compared with the repository mobile workspace repository queries. No user data was read, no test accounts were created, and no production settings or records were changed.

## Positive controls observed
- Customer organization discovery queries active memberships for the authenticated user; organization reads are RLS-scoped to active membership.
- Customer shipment and customer quote reads are RLS-scoped through `private.krim_has_organization_access(auth.uid(), customer_organization_id)`.
- Partner capability, partner quote, and partner assignment reads are scoped to the partner organization, with additional customer-side visibility for partner quotes and shipment assignments.
- Open partner opportunity visibility requires an active partner-type membership, eligible organization state, registered-business mode, verified partner status, current-enough capability dates, and a shipment coverage predicate in one policy.
- Driver assignment reads require both `user_id = auth.uid()` and an active driver membership in the same organization.
- Driver profile reads are own-user scoped; driver trip-event and delivery-evidence reads are tied to the authenticated user's own assignments. Evidence inserts additionally validate owned storage objects, path structure, file size/type, recipient name, and active driver membership.

## Release-blocking review items

### 1. Partner quote confidentiality needs an explicit field-level decision
The authenticated SELECT policy on `krim_partner_quotes` permits access either to the partner organization or to the customer organization linked to the opportunity. The mobile partner repository selects amount, currency, notes, status, and validity fields. Because table SELECT is row-level rather than column-level, customer-side access may expose partner-submitted commercial details (including internal notes) to customer users if the table's column grants permit those fields.

Required next step: decide which fields the customer is entitled to see. Prefer a customer-safe view/RPC exposing only approved customer-facing quote data; do not rely on UI hiding. Test customer A vs partner B and unrelated customer C. Check column grants and every client query before changing the policy.

### 2. Multiple permissive shipment/opportunity policies require OR-composition review
Production has multiple authenticated SELECT policies on `krim_partner_opportunities` and `krim_shipments`. PostgreSQL combines permissive policies with OR. One opportunity policy checks eligible partner status and capability coverage; another adds `private.krim_partner_compliance_is_current`. One shipment policy also checks the older status fields/capability coverage while a second policy is stricter about current compliance. The stricter policy does not narrow access if the older permissive policy independently grants it.

Required next step: consolidate or make every permissive branch independently satisfy the same current compliance, capability, route and organisation checks. First trace dependencies and preserve customer/awarded-partner access. Add tests for expired compliance, expired capability, inactive capability, wrong route, wrong mode, revoked membership, and unrelated tenant.

### 3. Platform-admin read branches in these policies need explicit MFA review
The inspected opportunity policy contains a direct `private.krim_has_permission(auth.uid(), 1, 'admin.platform')` branch without an explicit AAL2 predicate in that policy expression. Verify whether the helper itself enforces AAL2; do not assume it does. If it does not, platform-admin opportunity reads may be possible at AAL1. Review all policies and views used by admin workspaces for the same pattern.

### 4. Client-side organization filters are not authorization
Customer, partner and driver repositories filter queries using organization/user IDs supplied by the app. These filters are convenience constraints only. RLS and RPC authorization must remain the security boundary. Preserve this distinction in testing and UI messaging.

## Driver access notes
The production driver assignment policy is strongly scoped to the authenticated driver and active driver membership in the assignment's organization. Driver trip events and evidence are similarly tied to owned assignments. However, driver profile update policy should be checked for sensitive fields such as verification status, compliance state, and organization linkage: the inspected policy permits own-row UPDATE with user ID and active driver membership but does not itself show a column-level restriction.

Required next step: inspect column grants and whether sensitive profile columns can be changed directly by authenticated users. Prefer server-controlled fields to be writable only through guarded RPCs.

## No changes made
This review is read-only. No RLS policies, grants, functions, data, Edge Functions, authentication settings, or production configuration were modified.

## Required tests before workspace release
- Cross-tenant customer, partner and driver reads/writes.
- Partner quote commercial-field confidentiality.
- Expired/revoked partner compliance and capability.
- OR-composition of all permissive RLS policies.
- AAL1 vs AAL2 admin read access.
- Driver profile protected-column update attempts.
- Revoked membership and deactivated organization.
- RPC direct-call authorization independent of UI route guards.
