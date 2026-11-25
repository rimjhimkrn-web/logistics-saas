# Phase 00 — Shared shipment API, invoice visibility and tenant-scope audit
Date: 2026-11-25
Branch: qa/phase-00-baseline-2026-11-25
Scope: Read-only Production and Staging PostgreSQL catalog, function-source and RLS-policy review. No SQL writes, function invocations, synthetic users, exports, payments, provider calls, or deployments.

## Executive result
**NOT PASS — source/catalog review only; runtime tenant-isolation is not proven.** The canonical shipment creation RPCs inspected contain organization membership/access and `shipment.create` checks. The shipment read policy is materially more nuanced than a simple organization match: customer organization access, active partner assignment, Operations permission, and tightly-qualified open partner-opportunity visibility are represented. Invoice reads are gated by `finance.view` on one of the invoice's organization relationships. However, direct table access and export behavior differ by environment, and the shipment-document read policy is customer-organization-only. These differences require explicit product/authorization decisions and runtime tests before onboarding.

## Verified positive controls
1. `public.krim_create_global_shipment` (SECURITY DEFINER; pinned empty search_path) calls organization access and `shipment.create` checks for the supplied customer organization before inserting.
2. `public.krim_create_global_shipment_idempotent` (SECURITY DEFINER; pinned empty search_path) rejects null `auth.uid()`, checks organization access, `shipment.create`, and active organization status; it uses an advisory transaction lock and compares replayed request details before returning an existing shipment.
3. `public.krim_get_shipment_tracking` requires an authenticated user and checks active customer-organization access or an active membership in an organization assigned to that shipment. Its GPS response path further requires a matching active driver assignment, partner assignment, active driver membership, active organization, verified driver profile, and recorded consent metadata.
4. Production `krim_shipments` RLS is enabled. Its SELECT policy allows customer-org access, active partner assignment, Operations membership plus `shipment.view`, or a qualified verified/compliant partner with an open matching opportunity and current capability.
5. Production `krim_invoices` RLS is enabled and SELECT is gated by `finance.view` on the finance member organization or a populated invoice organization relationship. Direct authenticated INSERT/UPDATE/DELETE are not granted.
6. Invoice items SELECT is mediated through the parent invoice's organization access; direct authenticated writes are not granted.
7. `krim_invoice_payment_applications` has deny-all authenticated/anon policies and no authenticated table privileges in the inspected catalogs.

## Findings requiring remediation or decision
### F1 — Shipment document visibility is narrower than shipment visibility
The Production `krim_shipment_documents` SELECT policy grants visibility only where the caller has organization access to the shipment's customer organization. It does not include the accepted partner-assignment branch present in the shipment table policy. If partners are intended to access operational documents for their assigned leg, this policy may block legitimate access; if documents are customer-only, that restriction should be explicit in the product contract and tested. No document data was read.

### F2 — Export-request table access differs between environments
Production `krim_data_export_requests` has RLS policies limiting SELECT and INSERT to rows whose `user_id = auth.uid()`, and authenticated SELECT/INSERT privileges are present. Staging has the same policies but no authenticated table privileges. This is an environment parity gap. The row policy proves per-user row scoping only; it does not by itself prove that an export worker validates the requested organization, export scope, fields, and requester permissions before generating or serving a file. Export worker/function source and signed-download authorization remain to be reviewed.

### F3 — Invoice policy is finance-permission-centric
The invoice SELECT policy requires `finance.view` for organization, customer, supplier, or partner organization IDs. This is a meaningful server-side permission gate, but no runtime proof yet demonstrates that customer-facing billing users receive only their own customer invoices, partner-facing users receive only partner-specific invoices, and a user with finance.view in one organization cannot cross-read another tenant's invoice. The organization relationship predicates must be exercised with two separate test tenants.

### F4 — Shipment/party/assignment read semantics need explicit least-privilege verification
Shipment SELECT includes an opportunity visibility path for open opportunities and only active, verified, compliant registered-business partners with current compliance and capability coverage. Shipment parties and partner assignments are also exposed to authenticated SELECT under organization-scoped RLS policies. Source review does not establish that every column on these rows is appropriate for every allowed organization type. Column-level minimization, partner-only assigned-leg visibility, and customer/partner PII separation need runtime and schema review.

### F5 — Staging is not an executable test environment for the inspected datasets
The inspected Staging tables have RLS enabled but no authenticated SELECT/INSERT privileges for shipments, invoices, invoice items, documents, parties, assignments, and export requests. This may be deliberate fail-closed isolation, but it prevents normal authenticated workspace tests until a controlled staging access model and synthetic fixtures are established. Do not copy Production grants into Staging without a reviewed test-sink and isolation design.

### F6 — Internal invoice generation routines must remain internal
The inspected `krim_internal_create_customer_invoice_for_delivered_shipment` and partner-payable generator are SECURITY DEFINER routines with a non-empty `search_path=public`. They validate delivered status, accepted quote/assignment, and independently verified POD before generating financial records. The customer-invoice generator's body does not itself perform a caller authorization check; this is acceptable only if its EXECUTE ACL remains restricted to trusted internal callers/triggers. Confirm exact ACL and all call sites before any change. It must not be exposed as a browser-callable RPC.

## Environment comparison
- Production: authenticated SELECT on the inspected shipment/invoice/document/party/assignment tables; no direct authenticated writes on these sampled tables. Export requests allow authenticated SELECT/INSERT subject to own-user RLS.
- Staging: RLS policies exist on the sampled tables, but authenticated CRUD privileges are absent for the sampled shipment/invoice/document/party/assignment/export tables.
- Both environments show the same core RLS expressions for the sampled shipment and invoice datasets. This is catalog parity, not proof of runtime behavior.

## Evidence limitations
- No signed-in user sessions were used.
- No cross-tenant reads, direct RPC attempts, export generation, document download, signed URL access, or role/AAL negative tests were executed.
- This review did not enumerate every Enterprise page RPC or every invoice/export worker call site.
- The initial broad catalog query returned excessive function-source output; conclusions above rely on targeted function definitions and table-policy metadata subsequently queried.
- No actual invoice, shipment-document, party, or export row content was read.

## Required verification before launch
1. Establish a disposable, isolated Staging test tenant with synthetic customer, partner, finance and Operations identities; confirm provider test-sinks and no Production credentials.
2. Run positive/negative two-tenant matrix for shipment reads, shipment parties, assigned/unassigned partner, opportunity partner, invoices and invoice items.
3. Test document access separately for customer, assigned partner, unrelated partner, Operations and Admin; verify signed URL expiry/revocation and object path ownership.
4. Trace export request creation through worker, file storage and download endpoint; assert user + organization + requested dataset authorization at each stage and prevent arbitrary organization IDs/columns.
5. Confirm invoice/payable SECURITY DEFINER EXECUTE ACLs and call sites; keep browser roles denied.
6. Resolve intended partner access to shipment documents and document that policy in product requirements.
7. Repeat same test matrix on Staging after deliberate least-privilege grants; do not mirror Production grants wholesale.

## Change record
No database changes, code changes, Auth changes, storage changes, secrets access, provider calls, merges, or deployments were performed. Report committed only to the QA branch.
