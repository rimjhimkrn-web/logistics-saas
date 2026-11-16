# KRIM Route-and-Action Register — Batch 03: Customer, Enterprise and Customs
**Date:** 16 November 2026  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Scope:** Static inspection of all 2 customer pages, 1 customs page and 14 enterprise pages in the repository HTML inventory. No live operations executed.

## Customer workspace
| Page | Source calls/data observed | Verification focus |
|---|---|---|
| `app/customer/index.html` | Reads `krim_organization_members`, `krim_organizations`, `krim_shipments`, `krim_quotes`; includes session and MFA/AAL2 signals | Customer visibility must be tenant-scoped. Ensure quotes are linked to the correct shipment and customer organization; customer read views must not expose partner-private or internal operational fields. |
| `app/customer/customs-documents.html` | Calls `krim_has_permission`, `krim_customs_document_submit`, `krim_customs_document_review`; reads shipment/customs/document/broker/organization/country records; uses `krim-partner-verification` storage; includes MFA/AAL2 signals | Verify customer can submit only for an authorized shipment and organization. Review must require distinct authorized reviewer, AAL2 and independent evidence checks. Storage must be private and path-bound to tenant/shipment/case. |

## Customs workspace
| Page | Source calls/data observed | Verification focus |
|---|---|---|
| `app/customs/index.html` | Calls `krim_has_permission`, `krim_customs_document_submit`, `krim_customs_document_review`, `krim_customs_broker_license_submit`, `krim_customs_broker_respond`; reads customs cases, exceptions, broker assignments/licenses, document submissions, jurisdiction requirements, organization membership, countries and partner verification storage; includes MFA/AAL2 signals | Customs actions must be scoped to jurisdiction, shipment, broker assignment and organization. Distinguish document submitted/reviewed from actual customs authority clearance. Require current broker licence and independent review. |
 
## Enterprise workspace
The following 14 HTML pages were inspected:
- `app/enterprise/ai-governance.html`
- `app/enterprise/analytics.html`
- `app/enterprise/approvals.html`
- `app/enterprise/automation.html`
- `app/enterprise/commercial.html`
- `app/enterprise/dashboard.html`
- `app/enterprise/documents.html`
- `app/enterprise/finance.html`
- `app/enterprise/index.html`
- `app/enterprise/institutional-memory.html`
- `app/enterprise/integrations.html`
- `app/enterprise/organization.html`
- `app/enterprise/risk-compliance.html`
- `app/enterprise/shipments.html`

Source scan observations:
- `app/enterprise/index.html` directly references both `krim_shipments` and legacy `shipment_requests`, alongside `krim_organization_members`. This is a compatibility and data-lineage risk: confirm which model is canonical and whether legacy reads are intentionally migrated/filtered. Do not silently merge or treat them as equivalent.
- `analytics.html`, `approvals.html`, `dashboard.html`, `integrations.html`, `organization.html`, and `shipments.html` directly reference organization membership; their other data calls may be in shared scripts or indirect handlers.
- `ai-governance.html`, `automation.html`, `commercial.html`, `documents.html`, `finance.html`, `institutional-memory.html` and `risk-compliance.html` contain session checks but no literal direct Supabase table, RPC or Edge Function invocation in the page source scan. This does not establish that the functions are wired or unwired; inspect imported/shared scripts and button handlers.
- No enterprise page is certified by the presence of a session check alone. Every enterprise action needs organization binding, role/permission scope, tenant isolation, and audit logging. Enterprise finance remains non-collecting pending the final financial phase.

## Cross-cutting risk register
1. **Legacy shipment model:** Enterprise landing page reads both `krim_shipments` and `shipment_requests`. Establish canonical source, read/write ownership, migration status and consistency rules before relying on enterprise shipment reporting.
2. **Customs authority boundary:** A KRIM document review or broker response is not equivalent to release/clearance by the competent customs authority. Status labels and customer communications must preserve this distinction.
3. **Broker authorization:** Validate current licence, jurisdiction, assigned shipment/case, organization membership and permitted action at the server boundary on every submission/review.
4. **Document security:** Private bucket access, object key tenant binding, MIME/size/content validation, malware scanning, signed URL expiry and reviewer independence require staging evidence.
5. **Enterprise indirect actions:** Pages with no literal direct call require tracing of imports/shared modules and UI handlers. Do not label as broken or functional based only on this scan.
6. **Tenant isolation:** Test two enterprise organizations with overlapping shipment IDs, analytics, approval queues, integrations, documents and organization settings.
7. **Consent and auditability:** Customer document upload, broker access, enterprise integrations and automation must have a clear purpose, authorized scope, retention and auditable actor.

## Required staging tests
- Customer A cannot read Customer B's shipments, quotes, customs cases, documents, or signed evidence links.
- Customer can create/view quote requests only for its own organization and valid shipment; conflicting retries are idempotent.
- Customer document submission rejects unassigned shipment, wrong tenant, unsupported jurisdiction/document type and invalid evidence; reviewer cannot approve own submission.
- Customs broker cannot access unassigned cases or act outside current licence/jurisdiction; revoked/expired licence blocks new actions.
- Customs case states distinguish KRIM internal review, broker submission, authority decision and final clearance; no internal action may fabricate authority release.
- Enterprise A cannot access Enterprise B's shipment records, reports, approval queues, organization settings, integrations or private documents.
- Legacy `shipment_requests` and `krim_shipments` are reconciled using documented IDs/status mapping; conflicting records are surfaced, not silently blended.
- Enterprise indirect actions are traced to actual scripts/RPCs and tested for authorization, idempotency, error states and audit events.
- Enterprise finance page does not initiate collection, invoice issuance, ledger posting or payout until the separately authorized final phase.

## Release status
**Not certified.** This is a static source register, not a staging test report. No customs submission, clearance, customer shipment, quote, document upload, enterprise integration or financial operation was executed. Production DDL remains blocked pending migration-history reconciliation. Live revenue setup remains deferred.
