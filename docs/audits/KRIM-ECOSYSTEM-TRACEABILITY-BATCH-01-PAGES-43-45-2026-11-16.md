# KRIM Ecosystem Traceability Audit — Batch 01: Pages 43–45

**Date:** 16 November 2026  
**Repository:** `rimjhimkrn-web/logistics-saas`  
**Production project:** `ebltviniygljwwseplph`  
**Scope:** Integrations & Automation; Partner Security & Audit Centre; API & Webhooks.  
**Method:** Repository source inspection, live read-only PostgreSQL metadata and count queries, RLS policy inspection, and Supabase Edge Function inventory. No production writes or synthetic records were created.

## 1. Outcome

This batch confirms that the three partner-facing pages are not equivalent to a fully self-service integration platform:

- **Page 43 — Integrations & Automation:** a real, organization-scoped, read-only operations console over webhook subscription and event-workflow dispatch records. It has no create/update/delete or endpoint-test action.
- **Page 44 — Security & Audit Centre:** a real, read-only view of the signed-in user's memberships, personal audit events and organization-linked API security alerts. The audit-events RLS policy is actor-only, so this is not a complete organization-wide audit register.
- **Page 45 — API & Webhooks:** an informational access page. It explicitly says external credential and webhook management is not offered as a standalone partner workflow and directs users to Page 43.

**Overall state: partially implemented; external integration lifecycle is not operationally validated.**

## 2. Page-to-backend traceability

### Page 43 — Integrations & Automation

**Canonical path:** `public/partner/integrations-automation.html`  
**Purpose:** inspect registered partner webhook subscriptions, workflow dispatch outcomes and dispatch event traces.

| UI capability | Backend mapping | Access / behavior | State |
|---|---|---|---|
| Partner identity / organization context | `krim_organization_members`, `krim_organizations` | Auth session; active membership; filters partner/carrier/forwarder; requires verified/approved, active lifecycle and compliant status | Implemented guard; real partner journey untested |
| Webhook subscription inventory | `krim_api_webhook_subscriptions` | SELECT by `organization_id`, latest updated first, limit 500 | Read-only implemented |
| Workflow dispatch monitor | `krim_event_workflow_dispatches` | SELECT by organization, newest first, limit 500 | Read-only implemented |
| Event trace | `krim_event_workflow_dispatch_events` | SELECT for visible dispatch IDs, newest first, limit 1,000 | Read-only implemented |
| CSV export | Browser-generated CSV from already loaded records | No server write | Implemented |
| Create/edit/delete/test webhook | No corresponding UI action or RPC call found in this page | Not available | Not implemented here |

The page handles auth/membership failures and separately reports unavailable source queries. The query scope is explicitly organization-bound. It is a monitoring/investigation surface, not an integration setup wizard.

### Page 44 — Security & Audit Centre

**Canonical path:** `public/partner/security-audit.html`  
**Purpose:** inspect permitted membership, organization, actor audit and API security alert records.

| UI capability | Backend mapping | Access / behavior | State |
|---|---|---|---|
| Membership register | `krim_organization_members` | Filtered to current `auth.uid()`; now selects only `id,organization_id,role,status` | Read-only implemented |
| Organization register | `krim_organizations` | IDs derived from active memberships; now selects `id,legal_name,display_name,organization_type,status` | Read-only implemented |
| Recent audit activity | `krim_audit_events` | Query filters `actor_user_id = current user`; table RLS policy also allows only `actor_user_id = auth.uid()` | Personal activity only; not org-wide audit |
| Security alerts | `krim_api_security_alerts` | Query scoped to organizations in current active memberships | Read-only implemented; policy authorization needs review |
| CSV export / refresh | Browser export of returned records; refresh repeats reads | No server write | Implemented |

**Accuracy correction committed:** the heading now says “Your recent audit activity”, and the explanatory copy states that this is not a complete organization-wide audit log. Membership and organization queries were narrowed from `select("*")` to explicit fields to reduce unnecessary data retrieval.

**Authorization review item:** the current `krim_api_security_alerts` SELECT policy checks active organization membership but does not appear to require a security/compliance permission. Review whether all active members should see API security alert details or whether a dedicated permission is required. No policy change was made in this audit.

### Page 45 — API & Webhooks

**Canonical path:** `public/partner/api-webhooks.html`  
**Behavior:** informational page only; links to Page 43 and Partner Workspace. It states that credential/webhook management is kept behind verified, database-backed controls and is not available as a standalone partner workflow.

**State:** correctly acts as an access-information boundary; it is not itself an API key or webhook management console.

## 3. Related developer pages: material product-claim risk

The deeper developer pages are separate from the Page 45 partner information page:

| Path | Source inspection | Classification |
|---|---|---|
| `public/developer/api-key-management.html` | Static UI text offers key generation/revocation and claims AES-256 encrypted / production master key; no page-specific backend script or action handler found | Design/demo surface; not a working key manager |
| `public/developer/webhooks-management.html` | Static UI shows a sample endpoint, HMAC label, success rate and test-ping action; no page-specific backend action handler found | Design/demo surface; not a live webhook console |
| `public/developer/api-docs.html` | Static examples claim OpenAPI 3.1, GraphQL, API v2.4 “Live Production”, live AIS telemetry and customs/ledger endpoints; no page-specific API test handler found | Documentation mock / unsupported live-production claims |
| `platform/krim-api.js` | Shared Supabase data-access helper with generic select/insert/update/delete/RPC wrappers | Internal frontend data abstraction; not a public logistics REST API |

These claims must not be presented as proof that external REST/GraphQL endpoints, production key generation, webhook endpoint registration, test delivery, AIS telemetry or customs filing APIs are live. Keep these developer surfaces hidden from public commercial promises or clearly label them as preview/mock until a real external API service, contracts, security controls, docs and end-to-end tests exist.

## 4. Production database evidence (read-only, 16 Nov)

### Table inventory and estimated rows

| Table | RLS enabled | Estimated / observed rows | Meaning |
|---|---:|---:|---|
| `krim_api_clients` | Yes | 0 | No API client records |
| `krim_api_keys` | Yes | 0 | No API keys |
| `krim_api_webhook_subscriptions` | Yes | 0 | No registered subscriptions |
| `krim_api_security_alerts` | Yes | 0 | No API security alerts |
| `krim_audit_events` | Yes | 203 exact count | Audit events exist, but visibility is actor-scoped |
| `krim_event_workflow_dispatches` | Yes | 9 exact count | Dispatch rows exist; not evidence of successful external webhook delivery |
| `krim_event_workflow_dispatch_events` | Yes | 0 | No dispatch event trace rows |
| `krim_webhook_deliveries` | Yes | 0 | No recorded webhook deliveries |

Counts are a point-in-time snapshot. RLS being enabled does not alone prove policy correctness. All eight inspected tables had SELECT policies; the browser pages do not write to them.

### Relevant internal database routines

The production database contains the following `krim_internal` SECURITY DEFINER routines, with inspected execute ACLs restricted to `postgres` and `service_role`:

- API: `validate_api_key`, `authorize_api_resource`, `enforce_api_version`, `consume_api_rate_limit`, `log_api_request`, `detect_api_security_anomaly`.
- Idempotency: `begin_api_idempotency`, `complete_api_idempotency`.
- Workflow/webhook: `create_event_workflow_dispatch`, `complete_webhook_delivery`, `record_webhook_endpoint_result`, `schedule_webhook_retry`.

The routines provide backend building blocks for key validation, scope/organization checks, rate limits, idempotency, request logs, anomaly detection and webhook retry/status handling. Their existence does not prove a public API gateway or worker is connected and processing real external requests.

### Edge Function inventory cross-check

The current production Edge Function inventory contains payment, notification, tracking, AI, admin and growth functions, but no dedicated public partner API gateway or webhook dispatch worker was identified by function name. This is an integration gap to resolve before promising an external API product.

## 5. Page 44 code correction

Commit: `f6066957c9d941125840d4a62b2bb3e9446a6e49`

Changes:
1. Reworded “Recent audit evidence” to “Your recent audit activity”.
2. Clarified that events are limited to the signed-in actor under the current audit-table policy and do not constitute a complete organization-wide audit log.
3. Replaced broad membership and organization `select("*")` queries with explicit fields used by the page.

No schema, RLS policy, permission, secret, Edge Function or production data was changed.

## 5A. Developer preview safety corrections

The related developer pages were corrected to remove unsupported live-production representations and false action feedback:

- `public/developer/api-key-management.html`: key issuance and revoke actions disabled; fake production/sandbox key prefixes and timestamps removed; encryption claims marked unverified; no production key is represented as issued.
- `public/developer/webhooks-management.html`: endpoint setup, secret-copy and test-ping actions disabled; sample endpoint and signing secret removed; delivery success metric removed; HMAC approach labelled unverified/not enabled.
- `public/developer/api-docs.html`: API v2.4 live-production and OpenAPI/GraphQL live-spec claims removed; endpoint base URL and bearer credential removed; request execution disabled; sample response clearly marked illustrative.

Commits:
- API key page: `85143583291038e59edbde9810fca4a78eb3337b`
- Webhook page: `61186e36baf2d4fbc7c431ba62d9d11bcbcb6812`
- API reference page: `b30a472851842bb1e59b9d2e66c1c04b59303393`
- Remaining duplicate mock revoke action disabled: `f0d9a9ba19cb4de9317948c0cee3e63361c50614`

Repository source re-check confirmed that the three pages no longer contain the former sample API key prefixes, webhook signing-secret literal, false live delivery metric, live-production label or alert-based fake success/revocation actions. Automated workflow checks for the final commit are still required.

## 6. Test and deployment status

For the prior capability-map documentation commit `c3af3cf28d2e3be4d5d23d3318a34d289473bdce`:
- Static link audit run `43776192422`: completed successfully.
- Production smoke run `43776192384`: completed successfully.
- Pages build/deployment run `43776192173`: completed successfully.

Those workflow results are for the prior commit, not the Page 44 correction commit. New checks must run against the correction commit before its deployment/test state is claimed.

No real API client, API key, webhook subscription or delivery was created. No external integration E2E test was performed.

## 7. Remediation order

1. Keep API key and webhook developer pages in preview/design status; remove unsupported “live production”, AES-256, HMAC delivery-success and sample endpoint claims unless independently verified.
2. Decide the API product contract: first supported endpoints, versioning, auth, scopes, idempotency, rate limits, tenant boundary, error schema and support commitments.
3. Implement a server-side API gateway that actually invokes the inspected internal routines; do not expose internal SECURITY DEFINER functions directly.
4. Build an authorized API-client/key lifecycle (create once, hashed secret storage, scoped reveal, rotate, revoke, expiry, audit, MFA/permission).
5. Build webhook subscription lifecycle, secret management, signed delivery, replay protection, bounded retries, dead-letter handling and delivery logs.
6. Review security-alert RLS and add dedicated security-view permission if required by the access model.
7. Run cross-organization negative tests, scope-denial, revoked/expired key, duplicate/idempotency conflict, rate-limit, signature verification, replay, retry and endpoint suspension/recovery tests.
8. Only then enable developer self-service and publish a production API specification.

## 8. Exit state

**Batch 01 status: audited; Page 44 copy/data-minimization correction committed; re-test pending for that commit.**  
Pages 43–45 remain within the 45-page audit sequence. Page 46 remains on hold. The broader four-division ecosystem capability map remains canonical and unchanged.
