# KRIM Global Logistics OS — Master Blueprint & Operational Readiness Register

Last reviewed: 4 November 2026  
Repository: rimjhimkrn-web/logistics-saas  
Initial operating focus: India  
Architecture objective: Global-ready, multi-country logistics operating system; market activation is evidence-gated.

This register is the governing checklist for platform completion. A page, table, Edge Function, catalogue record, or successful cron invocation is not by itself proof that a commercial logistics service is operational.

## 1. Platform architecture

KRIM is one connected operating system across six planes:

1. Global core: identity, organizations, membership, RBAC, audit, countries, markets, locations, routes, currencies, languages, time zones, units and regulatory configuration.
2. Logistics execution: customer requests, quotations, partner matching, capacity, bookings, multimodal legs, dispatch, warehouse handovers, customs, tracking, delivery evidence and exceptions.
3. Commercial and financial: tariffs, partner rates, customer pricing, payments, refunds, invoices, double-entry ledger, settlements, reconciliation, tax and multi-currency controls.
4. Intelligence: AI assistance, document intelligence, planning, matching, risk signals, ETA support, analytics and forecasting.
5. Automation and integrations: event workflows, queues, retries, dead letters, scheduled jobs, notifications, CRM, messaging, payment and external logistics integrations.
6. Governance and reliability: security, privacy, compliance, approval controls, monitoring, incident response, testing, backup/recovery and release management.

## 2. Nine user workspaces

| User type | Required operational scope | Current evidence-based position |
|---|---|---|
| Customer / Shipper | Registration, organization/profile, quote, booking, payment, shipment visibility, documents, support and claims | Core pages and request/tracking foundations exist; full customer lifecycle still requires end-to-end validation. |
| Partner / Carrier | Business onboarding, verification, capabilities, capacity, opportunities, quotes, assignments, fleet, dispatch, POD and settlements | Multiple partner category workspaces and verification foundations exist; no eligible verified carrier organization is currently recorded. |
| Driver | Invitation, identity/licence verification, assigned trips, milestones, POD, exceptions and safety | Invitation and document review foundations exist; zero driver profiles/approved drivers in the latest snapshot. |
| Warehouse / Fulfilment | Facility approval, inbound, receipt, putaway, inventory, pick/pack, dispatch, damage and evidence | Connected backend workflows and 12 operational pages exist; zero approved facilities and no positive transaction test. |
| Customs & Trade | Jurisdiction checks, declarations, documents, broker assignment, holds, clearance and audit | Workspace foundations exist; full jurisdiction-specific workflow and real broker validation remain. |
| Finance & Treasury | Payments, invoices, ledger, refunds, payouts, settlements, FX, reconciliation and approvals | Several financial foundations exist; real transaction, refund, payout and cross-border settlement validation remain. |
| Operations Control Tower | Network-wide shipment state, milestones, exceptions, SLA, escalation and route performance | Foundations exist; full live operations and exception ownership need completion. |
| Enterprise | Organization hierarchy, users, contracts, service scope, consolidated shipments, controls and reporting | Requires complete enterprise onboarding and end-to-end operational validation. |
| Platform Administrator | Private governance, market activation, verification, RBAC, finance controls, security, audit and incidents | Global admin control plane and several review modules exist; full governance/security audit remains. |

## 3. Globalization requirements

### Language and localization
- Maintain a language catalogue separately from languages approved for production use.
- Support locale-specific dates, times, number formats, first-day-of-week, directionality and typography.
- Translate every customer, partner, driver, warehouse, customs, finance, enterprise and admin journey—not only navigation.
- Require translation completeness, native-language review, accessibility and regression tests before activation.
- Store user and organization preferences; use deterministic fallbacks.

Database snapshot (4 Nov 2026): 27 language catalogue entries; 2 active languages (English and Hindi); 32 locale entries; 7 active locales; 0 translation rows. Catalogue presence is not proof of translated UI coverage.

### Currency and foreign exchange
- Separate currency display, quote currency, transaction currency, settlement currency and reporting currency.
- Preserve ISO currency codes and correct minor-unit precision.
- Store FX source, rate, effective timestamp, retrieval timestamp and audit provenance.
- Never estimate or fabricate exchange rates.
- FX conversion, cross-border collection, settlement and payout remain disabled unless the required provider, rate source, legal and reconciliation controls are verified.

Database snapshot: 28 currency catalogue entries; 6 active; 0 FX-rate rows. Active currency catalogue status does not mean FX or payment rails are operational.

### Country and local operating configuration
- Country, subdivision, address and telephone formats.
- IANA time zones and local business calendars.
- Metric and US customary measurements.
- Country-specific tax, customs, trade, privacy, consumer-protection and record-retention requirements.
- Market, route, mode, provider, pricing, payment and support activation must be separate gates.

The six existing country/market records are catalogue/configuration data, not evidence of six operational markets.

## 4. Workstream completion register

| # | Workstream | Required acceptance evidence | Current state |
|---|---|---|---|
| 1 | Identity, organizations and access | All nine user types can register/sign in; membership, MFA, RBAC, session and recovery tests pass | Partial; several secure auth and membership gates implemented |
| 2 | Global country/market core | Country-specific readiness workflow, local configuration and controlled activation | Partial; frontend market configuration fails closed for commercial activation |
| 3 | Languages and localization | Complete translated UI, locale formatting, RTL, persistence and QA across workspaces | Catalogue expanded; only English/Hindi active; translation table currently empty |
| 4 | Currencies and FX | Currency precision, trusted rate ingestion, stale-rate controls, multi-currency ledger and reconciliation | Catalogue expanded; no FX-rate rows; no live FX conversion |
| 5 | Customer onboarding and qualification | Real customer registration, profile, business verification where applicable and CRM handoff | Partial |
| 6 | Partner acquisition and onboarding | Real business/individual pathways, documents, eligibility, agreements, verification and audit | Foundations built; no verified commercial carrier organization |
| 7 | Provider capabilities and capacity | Verified service/mode/coverage, capacity resource review and availability tests | Foundations built; latest capability remains pending; no eligible capacity resources |
| 8 | Shipment, quote and booking lifecycle | Idempotent request, valid pricing, partner bids, customer acceptance, booking and state transitions | Backend foundations exist; no complete positive production journey verified |
| 9 | Multimodal route execution | Mode-specific legs, handoffs, route coverage, restrictions and milestones | Partial; real network coverage must be evidenced |
| 10 | Driver operations | Invitation, verification, assignment, trip events, POD and driver safety | Foundations built; zero approved drivers in latest snapshot |
| 11 | Warehouse and fulfilment | Approved facility, ASN/receipt, inventory, putaway, picking, dispatch and evidence | Workflows/pages implemented; zero approved facilities; positive transaction test pending |
| 12 | Customs and trade | Country-specific customs data, documents, broker assignment, holds and clearance | Partial |
| 13 | Tracking and visibility | Authorized tracking, real provider/device events, milestone provenance and customer visibility | Public token-based tracking function active; no claim of live GPS/AIS coverage |
| 14 | Finance and payments | Razorpay production payment verification, refunds, double-entry posting, settlements and reconciliation | Razorpay integration reported by founder; end-to-end real transaction still requires controlled test; no FX rates |
| 15 | Notifications and support | Provider credentials, consent, delivery receipts, retries, templates and escalation | Adapter and retry worker active; external delivery tests remain; workflow external sends are gated |
| 16 | AI assistant | Authenticated, rate-limited assistant, persisted conversations, role-safe context, tool authorization and evaluation | Edge Function v16 active; conversation persistence and 20 requests / 10 minutes per user added; signed-in end-to-end test pending; no AI actions recorded |
| 17 | Workflow automation | Event triggers, idempotency, leases, retries, dead-letter replay, observability and safe approvals | Six shipment lifecycle workflows active; three cron jobs active; latest cron runs succeeded; external notifications remain gated |
| 18 | Growth and CRM automation | Permitted source ingestion, provenance, qualification, CRM sync, consent-based outreach and human review | Growth worker scheduled; source ingestion not configured; outbound outreach and automatic partner activation disabled |
| 19 | Control Tower and Enterprise | Role-safe consolidated operational visibility, contracts, SLAs, reports and escalation | Partial; requires integrated live operational data |
| 20 | Platform governance | Private AAL2 admin controls, market approval, provider review, audit, incident and emergency procedures | Admin control plane and several review tools exist; full governance audit remains |
| 21 | Security, resilience and release | RLS/ACL review, function authorization, secrets, rate limits, dependency review, backups, recovery, load and E2E tests | Incomplete; see current security findings below |

## 5. Automation and AI safety boundaries

- AI assistance may explain, summarize, draft and recommend.
- AI must not invent prices, shipment events, provider status, FX rates, legal conclusions or payment status.
- AI must not approve providers, activate markets, move money, issue refunds or change permissions.
- Any future tool-using AI action requires a typed allowlist, user/role authorization, explicit confirmation for high-impact actions, idempotency and immutable audit evidence.
- External outreach requires source permission, terms review, privacy review, consent and applicable communications rules.
- Scheduled jobs must be monitored for run outcomes, retries, queue age and dead-letter growth.

## 6. Current automation evidence

- Six active shipment lifecycle workflows are registered.
- Three active pg_cron jobs run workflow processing every minute, growth signal processing every five minutes and inquiry follow-up queueing every five minutes.
- The latest inspected cron executions on 4 Nov 2026 were successful.
- Existing lifecycle steps primarily create durable checkpoints, prepare notifications and record exception/risk work. External sends are explicitly disabled until provider readiness.
- Growth operations report source ingestion unconfigured, outbound outreach disabled and automatic partner activation disabled.
- Historical automation log rows must not be mistaken for current successful customer communications.

## 7. Current security and operational caveats

- Latest Supabase Security Advisor snapshot: 53 authenticated SECURITY DEFINER function warnings, 5 RLS-enabled/no-policy informational findings, and a leaked-password protection warning. Each privileged function must be reviewed for its internal authorization checks; warnings must not be dismissed as harmless without review.
- Performance Advisor reported 16 multiple-permissive-policy warnings and unused-index informational findings. Do not bulk-remove indexes or policies without workload analysis.
- The AI rate-limit table is private, RLS-enabled and inaccessible directly to authenticated users; its public RPC checks auth.uid() and is not executable by anon.
- Legacy Cashfree Edge Functions remain deployed and must be assessed for safe retirement because KRIM's intended primary payment integration is Razorpay. Do not remove them until dependencies and live configuration are verified.
- A successful deployment, source-level check or cron return does not replace a signed-in browser test, a positive database workflow test or a controlled payment test.

## 8. Go-live gates

KRIM must not be described as fully operational until all applicable gates are evidenced:

1. A real customer can register, submit a valid shipment request, receive a genuine quote, accept it and complete a payment.
2. A real registered and verified provider with verified capability and approved capacity can accept and execute an eligible assignment.
3. A real verified driver can be invited, verified, assigned, record trip milestones and submit delivery evidence.
4. A real approved warehouse can complete receipt, inventory and handover workflows where applicable.
5. Customs and trade requirements are reviewed for the selected route and cargo.
6. Tracking data has a named source, timestamp, provenance and correct customer access.
7. Finance records reconcile from payment through invoice, ledger, partner settlement and refund handling.
8. Notifications are delivered by connected providers with consent and delivery evidence.
9. Security, privacy, legal eligibility, operational support and incident ownership are approved for the initial market.
10. Full regression, role-isolation, failure/retry, duplicate-event, mobile and recovery tests pass.

## 9. Execution discipline

For each workstream: inspect existing code and schema → identify gaps → implement the smallest safe change → commit source and migration → verify database/ACL/RLS → run negative and positive tests where test fixtures permit → record evidence and remaining blockers.

Do not fabricate test data as real network coverage. Do not activate a market, language, currency, payment rail, provider or route merely to make a dashboard appear complete.
