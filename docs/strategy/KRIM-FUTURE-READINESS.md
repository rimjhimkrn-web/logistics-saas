# KRIM Future-Readiness Foundation

**Baseline date:** 2026-11-07  
**Platform:** KRIM Global Logistics OS  
**Repository:** rimjhimkrn-web/logistics-saas  
**Purpose:** Keep KRIM adaptable, reliable, commercially grounded, and capable of expanding from India to international corridors without replacing working systems unnecessarily.

## Operating principle

**Build a system that can adapt to change—not a system that assumes today's technology will never change.**

Future-readiness is not a promise that a business can never decline. It is a disciplined programme for reducing avoidable obsolescence risk through modular design, customer value, partner-network depth, operational reliability, financial discipline, and continuous learning.

## Guardrails

1. Preserve working production behaviour; make changes in small, reviewable increments.
2. Prefer configuration and adapter boundaries over hard-coded provider dependencies.
3. Do not activate a country, corridor, mode, payment method, or service based only on catalogue presence. Require verified partners, capacity, compliance evidence, pricing, operational ownership, and a tested customer journey.
4. Do not treat AI output as authority for pricing, compliance, payment, partner verification, or shipment status. Keep human approval and auditable controls where required.
5. Do not add expensive infrastructure or speculative technologies until a measurable customer or operating need justifies them.
6. Keep customer and partner data protected by least privilege, row-level security, server-side authorization, audit trails, and tested recovery procedures.
7. Every production change needs a rollback plan and verification evidence.

## Baseline audit — 2026-11-07

The connected Supabase project was reported as ACTIVE_HEALTHY, running PostgreSQL 17.6. The database inventory returned 378 public tables and 337 public functions. The following are observed counts, not a certification of production readiness.

### Operational footprint

| Area | Observed records |
|---|---:|
| Partner records | 10 |
| Partner capabilities | 1 |
| Partner verification cases | 1 |
| Network corridors | 7 |
| Network lanes | 0 |
| KRIM shipments | 18 |
| Quotes | 7 |
| Partner shipment assignments | 0 |
| Rate cards | 0 |
| Financial transactions | 1 |
| Workflows / steps / triggers / runs | 6 / 13 / 6 / 9 |

**Interpretation:** The platform has a substantial technical and data-model foundation, but live network depth and completed operating evidence are still thin. The next business priority is verified partner capability and service coverage, then controlled shipment execution and reconciliation—not broad international activation.

### Security and database findings

- All 378 inventoried public tables had RLS enabled.
- 21 public tables and 5 private tables had RLS enabled but no policies. This may be intentional for internal/server-only tables; each table's access path and intended owner must be verified. Do not add broad policies just to silence an advisor.
- 307 public functions use SECURITY DEFINER; 126 were reported executable by the authenticated role and none by anon.
- A static heuristic found 144 security-definer function bodies without obvious auth.uid(), is_admin(), or has_role() markers. This is a review queue, **not proof of a vulnerability**: trigger functions and tightly permissioned internal functions may correctly use other controls.
- Leaked-password protection is reported disabled in Supabase Auth.
- Performance advisors reported 27 foreign keys without covering indexes, 10 RLS init-plan warnings, 5 tables with multiple permissive SELECT policies, 1 duplicate index, and 671 unused-index notices. Unused-index notices are not a reason to drop indexes without workload evidence.
- The Supabase health advisor returned no lints at audit time.

### Payment and provider posture

Razorpay is the current India payment path. Keep provider-specific code behind a stable internal payment interface. Do not advertise global payment or settlement availability until each provider, country, currency, refund flow, webhook, reconciliation, and payout path has been verified. Legacy Cashfree functions remain present in the project inventory and should be assessed for references before any retirement; do not delete them blindly.

## Strategic architecture requirements

### 1. Modular provider boundaries
- Payment adapter interface: create order, verify/confirm, webhook ingest, refund, reconciliation, and settlement status.
- Notification adapter interface: email, Telegram, SMS/WhatsApp and future providers, with retries, idempotency, suppression, and delivery logs.
- AI provider boundary: model-independent prompts, structured outputs, evaluation tests, safety checks, usage limits, and a fallback/manual path.
- Logistics integration boundary: partner systems, carrier events, warehouse events, customs/document providers, and future EDI/API integrations.
- Version internal APIs and record provider capability/availability separately from country or currency catalogues.

### 2. Reliable operating core
- Treat shipment lifecycle transitions as explicit, authorized, auditable state changes.
- Require idempotency for payment, webhook, booking, assignment, and notification actions.
- Maintain event history, reconciliation, exception queues, retry/dead-letter handling, and operational ownership.
- Define measurable service levels only where partner commitments and monitoring support them.

### 3. Network and marketplace quality
- Verify legal identity, licences where applicable, service areas, modes, equipment, insurance/evidence, contacts, and operating capacity before activation.
- Keep draft, submitted, under-review, verified, suspended, and rejected states distinct.
- Match only on confirmed route, mode, cargo fit, capacity, service window, and compliance status.
- Track acceptance, on-time performance, damage/claims, cancellations, customer feedback, and partner responsiveness.

### 4. Customer value and retention
- Make quote quality, transparency, reliable status, documentation, exception handling, and support measurable.
- Capture feedback and repeat usage without dark patterns or misleading availability claims.
- Build retention from successful operations—not cosmetic features or lock-in.

### 5. Data, security, and resilience
- Maintain least-privilege RLS policies and explicit function grants.
- Review every SECURITY DEFINER function for caller authorization, search_path safety, input validation, and intended execution roles.
- Keep secrets server-side; rotate credentials and audit provider access.
- Verify backups, restore procedures, incident response, dependency updates, and observability.
- Define data retention, deletion, and export processes appropriate to applicable law.

### 6. Global readiness
- Model country, market, currency, language, time zone, business calendar, tax, customs, and documentation as separate capabilities.
- Require a country/corridor launch checklist with local legal review and operational proof.
- Treat catalogue entries as reference data, not proof of live service.
- Expand only after an India operating playbook is repeatable and financially sustainable.

## Execution roadmap and acceptance gates

### Phase A — Complete the foundation audit
- Map repository structure, build/test/deploy workflows, environment configuration, and runtime dependencies.
- Map critical database tables, RPCs, Edge Functions, triggers, RLS policies, and grants to user journeys.
- Review all externally executable SECURITY DEFINER functions and the 21 public no-policy tables.
- Verify payment and notification provider dependencies and remove only confirmed-unused legacy paths.
- Record backup/restore, monitoring, incident, and rollback evidence.

**Gate:** A reviewed system map, prioritized risk register, and reproducible baseline tests.

### Phase B — Harden the existing operating core
- Fix confirmed authorization and RLS issues only after policy intent is established.
- Add missing FK indexes only where query plans and workload justify them.
- Resolve duplicate policies/indexes with regression tests.
- Enable and test compromised-password protection where supported by the account configuration.
- Add tests for idempotency, duplicate webhooks, failed payments, refunds, retries, and reconciliation.

**Gate:** No unresolved critical/high security issue in reviewed paths; regression tests pass.

### Phase C — Prove India operations
- Verify and onboard partners with evidence.
- Configure real, approved rates and service areas.
- Test enquiry → quote → acceptance → payment → assignment → pickup → tracking → delivery proof → invoice/settlement.
- Reconcile every money movement and establish support/exception ownership.

**Gate:** At least one real route and service mode has a verified partner, confirmed commercial terms, legal/tax review, end-to-end test evidence, and reconciled funds.

### Phase D — Expand capabilities when justified
- Add partner integrations, AI assistance, automation, predictive operations, and additional payment providers behind adapters.
- Introduce enterprise plans and additional revenue models only after customer demand and unit economics are validated.
- Pilot new technologies in isolated, reversible scopes.

**Gate:** Each new capability has a named owner, customer case, cost/benefit measure, security review, rollback path, and adoption metric.

### Phase E — International corridors
- Select one corridor at a time (for example India–UAE only after India operations are proven).
- Validate local partners, customs, tax, payment, documentation, insurance, sanctions/trade restrictions, and customer support.
- Monitor service quality and contribution margin before widening coverage.

**Gate:** Country- and corridor-specific operational and legal approval with real partner capacity.

## Ongoing governance

- **Weekly:** operating incidents, failed workflows, customer/partner feedback, unresolved exceptions.
- **Monthly:** partner coverage, retention, quote conversion, shipment success, contribution margin, payment reconciliation, competitor and technology watch.
- **Quarterly:** architecture, security, dependency, cost, resilience, and country-readiness review.
- **Annually:** reassess the business model, market strategy, risk appetite, and long-term technology choices.

## Current external change watch

- Supabase CLI v3 was released in November 2026 and changes command defaults to local-first; hosted database operations now require explicit remote targeting and confirmation. Audit any CI/deployment scripts before upgrading or changing CLI versions.
- Supabase announced removal of a subset of legacy TLS 1.2 CBC cipher suites from project APIs beginning 2026-11-10. Confirm that supported client runtimes use modern TLS; do not weaken TLS to preserve obsolete clients.
- Supabase Data API table exposure defaults changed in 2026; verify explicit grants and exposure for each API-backed table rather than assuming new public tables are automatically exposed.

## Audit limitations

This baseline used connected Supabase project metadata, table inventory, advisors, read-only SQL metadata queries, Edge Function inventory, and recent GitHub commit metadata. Repository code search did not return file matches in this pass, and root README/package manifests were not retrievable by the connector. Therefore frontend code, CI workflows, dependency versions, and end-to-end browser behaviour are **not yet audited**. No production schema, data, payment setting, Edge Function, or user-facing code was changed as part of this baseline.

## Definition of success

KRIM is future-ready when it can safely add or replace providers, introduce new modes and corridors, improve AI and automation, and adapt to regulatory changes without destabilizing existing customers or compromising funds, data, partner trust, or operational evidence—and when each expansion is supported by measurable customer demand and sustainable economics.
