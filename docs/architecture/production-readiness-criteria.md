# KRIM Logistics OS — Production Readiness Criteria

**Current release posture: IN PROGRESS — NOT APPROVED FOR UNRESTRICTED COMMERCIAL OPERATIONS.**

This file is a release-gate checklist, not a declaration that every workspace or workflow is complete. A green static audit, page deployment, database schema or successful app export does not prove a real shipment can be fulfilled.

## P0 — Production foundation
- [ ] Reconcile the repository's SQL migrations with the live production migration ledger and schema before further production DDL.
- [ ] Verify backup/restore and incident recovery.
- [ ] Complete table-by-table RLS and function-by-function SECURITY DEFINER review.
- [ ] Review leaked-password protection availability. Supabase currently documents it as Pro+; if KRIM remains on Free, defer upgrade and apply strong password policy, email verification, rate limits and MFA where available.
- [ ] Test customer/partner/driver tenant isolation and unauthorized access denial.
- [ ] Keep payment, booking, location and market activation fail-closed until their acceptance tests pass.

## P0 — Real partner supply and fulfilment
- [ ] Verify at least one real operating partner with evidence, capability, route, current capacity and operational contact.
- [ ] Approve a route-specific rate/quote and contract terms.
- [ ] Test customer enquiry → partner match → partner quote → customer acceptance → partner acceptance.
- [ ] Test dispatch → verified driver/vehicle → in-transit milestones → exceptions → POD → independent verification.
- [ ] Test customer visibility and support/escalation.
- [ ] Do not claim route coverage or confirmed service without provider acceptance.

## P0 — GPS, privacy and legal gates
- [ ] Approve exact driver location purpose, recipients, consent language and withdrawal.
- [ ] Approve retention/deletion/legal-hold policy and access audit.
- [ ] Review India DPDP transition/commencement and relevant corridor privacy laws with counsel.
- [ ] Complete Android background-location/foreground-service declarations and platform review.
- [ ] Test native app on physical Android devices and end-to-end with an authorized driver and shipment.
- [ ] Keep server and app GPS launch flags OFF until written approvals and tests are complete.

## P0 — Finance and tax
- [ ] Confirm KRIM's contractual role, fee model, GST treatment, invoicing, refund and liability with an Indian CA/lawyer.
- [ ] Test Razorpay sandbox order, webhook signature, duplicate/replay, failure, refund and reconciliation flows.
- [ ] Keep customer freight payments, KRIM referral/coordination income and future SaaS billing separate.
- [ ] Keep paid checkout disabled until merchant and tax/legal approval.

## P1 — Mobile release engineering
- [ ] Commit lockfiles for Customer, Partner and Driver apps.
- [ ] Use deterministic `npm ci` builds and pinned tool versions.
- [ ] Run typecheck, Expo compatibility/config checks and Android exports for all three apps.
- [ ] Complete synthetic account and physical-device testing.
- [ ] Separate internal APK preview from production AAB/store release and rollback.

## P1 — Operations and communications
- [ ] Verify Telegram and email delivery, retry, duplicate suppression and failure alerts.
- [ ] Establish customer/partner support, claims, disputes, escalation and incident response.
- [ ] Test offline/recovery, stale data, permission-denied and empty/error states.
- [ ] Confirm all nine user types have least-privilege access and usable workflows.

## P1 — Legal, trust and market activation
- [ ] Review privacy notice, terms, partner/customer contracts, support, refunds, insurance/liability wording and data retention.
- [ ] Confirm licenses/certificates only where actually required and held.
- [ ] Activate each market/corridor only after provider, legal, tax, customs, payment and service readiness are documented.
- [ ] Review app-store data/privacy disclosures and brand/trademark clearance.

## Verification rule

Each checkbox requires evidence: a test result, approved document, verified partner record, live deployment or signed professional review. Do not mark complete based on code presence alone.

Latest detailed baseline: `docs/audits/KRIM-PLATFORM-OPERATIONAL-READINESS-AUDIT-2026-11-15.md`.
