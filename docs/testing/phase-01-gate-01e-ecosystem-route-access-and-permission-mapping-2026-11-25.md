# Phase 01 — Gate 01E: Ecosystem route, access-level and permission mapping

Date: 2026-11-25
Immutable source baseline: 72d75a18f985ceb09e468839435ee95700e11e46
QA branch: qa/phase-00-baseline-2026-11-25
Evidence: immutable Git tree, existing 1,023-row route manifest, canonical config.js and targeted representative HTML page-source inspection.
Scope: map route candidates to ecosystem ownership, likely access class and permission domains. No runtime/browser/backend authorization was tested.

## 1. Verdict

**PASS WITH LIMITATIONS — initial ecosystem and access-class mapping established; NOT an authorization certification.** The repository contains clear route families for the nine operating ecosystems plus public, identity and support surfaces. The route manifest's workspace labels are naming/path heuristics, not access control. Every page remains runtime NOT TESTED. Actual route visibility, tenant isolation, role grants, RLS/RPC enforcement and deep-link behavior remain unproven.

## 2. Inventory baseline and classification

The immutable tree and existing manifest each contain 1,023 HTML paths. The count includes six dependency HTML pages under node_modules and some non-page/tooling paths; retain them in the baseline census but exclude from the deployable product-route denominator after artifact allowlist verification.

Existing manifest candidate labels:
- ACTIVE/OTHER CANDIDATE: 869
- STAGING-ONLY CANDIDATE: 103
- ACTIVE-ENTRY CANDIDATE: 38
- WORKFLOW ROUTE CANDIDATE: 13

These sum to 1,023 and are heuristic labels only. ACTIVE does not mean deployed or functional; STAGING-ONLY does not prove access restriction; WORKFLOW does not prove a complete workflow.

Separate mutually exclusive primary-workspace path classification (heuristic):
- Public / shared / other: 348
- Platform admin: 48
- Customer / shipper: 133
- Partner / carrier: 97
- Driver: 71
- Enterprise: 62
- Finance: 60
- Operations: 54
- Warehouse: 58
- Customs: 29
- Identity / access: 43
- Support: 20

Do not add these figures to manifest workspace-candidate counts; these are different classification schemes. Some public/shared pages serve multiple ecosystems and aliases may resolve to one destination.

## 3. Ecosystem route and permission matrix

| Ecosystem / surface | Representative route families | Intended access candidate | Permission domains to enforce |
|---|---|---|---|
| Public / marketing | root pages, public company, service, market, policy and enquiry pages | Public read; enquiry submission separately rate-limited | public content, enquiry.create, abuse/rate limits, privacy consent |
| Identity / access | auth/, login, sign-in, reset, callback, invitation acceptance | Public entry; authenticated session required after successful auth; token routes narrowly scoped | auth.sign_in, session, MFA/AAL, invite.accept, password.reset, revocation |
| Customer / shipper | app/customer/, public/customer/, public/customer-os/, public/shipper/ | Public discovery/enquiry; customer workspace requires active user + organization membership | shipment.create/read, quote.request/read/accept, documents.read, tracking.read, support.create |
| Partner / carrier | app/partner/ role variants, carrier/forwarder/multimodal/first-mile/last-mile, public/partner/ | Public discovery/application; verified partner organization + scoped member for operational workspace | partner.profile, capability, service-area, quote.submit, assignment.accept, capacity.manage, compliance.submit |
| Driver / field | app/driver/, app/field/, public/driver/ | Invite-bound driver identity + active partner assignment; no generic self-activation assumption | driver.assignment.read/accept, event.submit, custody, POD.submit, GPS consent, device/session controls |
| Warehouse | app/warehouse/, public/warehouse/, warehouse workflows | Approved facility + authorized organization membership and facility scope | facility.manage, inbound.receive, QC.review, inventory.allocate, pick, transfer, return, handover |
| Customs / trade | app/customs/, customs workflows, public/customs/ | Authorized shipper/broker/operations role with jurisdiction and case scope | broker.manage, licence.review, declaration, document, classification, sanctions, hold/release evidence |
| Finance | app/finance/, public/finance/, billing/payment/settlement | Restricted finance role; maker/checker and organization/currency/period scope | invoice.prepare, payment.verify, refund.approve, ledger.post, reconciliation, payout/settlement |
| Operations control | app/operations/, public/operations/ | Permission-scoped operations/control-tower role and assigned region/corridor | shipment.view, dispatch.authorize, tracking, exception.manage, route/capacity coordination |
| Enterprise | app/enterprise/, enterprise integrations/analytics | Enterprise organization admin/member with tenant and feature entitlements | organization.manage, users.invite, shipment.view, approvals, integrations, analytics, automation |
| Platform admin | app/platform-admin/, app/admin/, admin/control/ | Internal privileged operators only; strong MFA, least privilege, audit and dual control | platform governance, partner verification, market activation, policy, security and emergency controls |
| Support | public/support/, support/ | Public help content; ticket and account-specific case access require identity/ownership checks | support.create, case.read, attachment, escalation, data-subject request |

This is a proposed authorization map derived from route names and inspected page intent. It does not grant any role or prove any permission exists. Backend authority must be canonical and checked on every protected read/write; hiding a link or redirecting a page is insufficient.

## 4. Representative source evidence

Targeted immutable-baseline inspection included root index, app/index, customer, partner, driver, warehouse, customs, finance, operations, enterprise, platform-admin, admin staging, auth login, partner onboarding, customer ecosystem, warehouse inbound, support and field workspace entry pages.

Observed evidence:
- Root index is publicly indexable and carries public marketing description.
- Auth login declares noindex/nofollow/noarchive and describes authorized workspace sign-in.
- Partner gateway declares noindex and includes Supabase/config dependencies plus sign-in/staging/read-only indicators.
- Warehouse, customs, finance and platform-admin shells carry noindex variants and Supabase/config dependencies.
- Enterprise shell is noindex and contains preview/read-only/staging indicators.
- Admin staging page declares noindex and explicitly describes a staging preview with no privileged data loaded.
- Public partner onboarding includes Supabase/config dependencies; that is not proof of safe public writes or successful verification.
- Public support help centre is indexable, but this does not prove ticket creation or agent delivery.
- Field workspace has data-portal=field and loads shared portal JS; inspected workflow source documents local-only drafts, no connected POD upload and no live tracking.

HTML metadata, script tags and visible copy cannot establish live HTTP response, script execution, session checks or backend authorization.

## 5. P0/P1 authorization mapping gaps

### P0 — No runtime authorization proof
No isolated Staging route-by-route tests exist in this phase. Before external onboarding, prove unauthenticated denial, wrong-role denial, wrong-tenant denial, revoked/suspended member denial, MFA/AAL requirements, direct deep-link denial and protected RPC/RLS enforcement for every protected ecosystem.

### P1 — Route owner and permission registry not yet exhaustive
A page-level mapping is not yet complete for all 1,023 HTML paths. Several public/shared directories contain cross-ecosystem pages, and aliases/redirects need canonical destination resolution. A machine-readable manifest should add canonical route ID and alias target; ecosystem owner and workflow; public/authenticated/privileged class; organization/resource scope; role and permission IDs; MFA/AAL and session requirements; backend RPC/table/storage enforcement references; staging/preview/noindex state; deployment-base-resolved URL; runtime evidence and release disposition.

### P1 — Privileged and regulated routes need stronger gates
Finance, platform-admin, customs, warehouse inventory, dispatch and driver GPS/POD pages must not be made operational based on page visibility. They require server-side permission checks, audit history, maker/checker where applicable, jurisdictional controls and evidence-bound state transitions.

### P1 — Public entry does not imply public write
Partner applications, customer enquiries, quote requests, support tickets, account recovery and tracking lookups require abuse controls, data minimization, consent and privacy handling. Public write endpoints must not inherit access simply because HTML is public.

## 6. Next actions

1. Build exhaustive machine-readable route-to-permission manifest for all in-scope HTML files and dynamic route states; exclude node_modules/tooling from deployable denominator only after CI artifact allowlist is verified.
2. Resolve aliases/redirects to canonical destinations and deduplicate route states without deleting source files.
3. Cross-reference every permission ID with backend role/permission catalog, RLS policies, RPC grants and Edge Function authorization.
4. Keep synthetic users/runtime authorization tests blocked until Phase 03 proves Staging project identity, database separation, Auth/storage/provider isolation and safe deployment.
5. After that gate, execute negative tests per role/tenant and confirm denial at backend—not merely redirect or hidden UI.

## 7. Safety and release disposition

Read-only GitHub source and manifest inspection. No browser tests, Staging/Production SQL/RPC, Auth operations, synthetic users, external notifications, payments, provider calls, Storage operations, source changes or deployments were performed. Phase 01 remains IN PROGRESS. Phase 00 remains FAIL / BLOCKED; general customer signup/booking, partner activation and driver operational onboarding remain NO-GO.
