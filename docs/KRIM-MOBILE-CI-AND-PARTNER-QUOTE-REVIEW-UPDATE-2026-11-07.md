# KRIM Mobile CI and Partner Quote Review Update — 2026-11-07

## Mobile CI result
GitHub Actions run 54 for commit `97148a12e6644b25d81724eec202040d44c0b1a4` completed successfully for all three mobile apps:
- KRIM Partner: dependency install, TypeScript typecheck, Expo Android export — PASS.
- KRIM Customer: dependency install, TypeScript typecheck, Expo Android export — PASS.
- KRIM Driver: dependency install, TypeScript typecheck, Expo Android export — PASS.

Associated repository checks on the same commit:
- Static link audit run 1284 — SUCCESS.
- Production smoke checks run 2782 — SUCCESS.

These are CI/static build checks only. They do not establish physical-device usability, authenticated user authorization, live API correctness, payment processing, or production readiness.

## Additional live schema review
- Quote status constraint permits draft, submitted, under_review, shortlisted, accepted, rejected, withdrawn, expired.
- Quote amount constraint permits amount >= 0; RPC applies stricter amount > 0.
- Quote valid_until must be null or >= submitted_at; the RPC sets submitted_at and clamps validity to opportunity deadline.
- Quote number is unique. Opportunity number is unique.
- Quote table has ordinary indexes on opportunity_id, partner_organization_id, shipment_id and (status, valid_until); no unique opportunity/partner pair index was found.
- Opportunity row locking in the proposed RPC serializes submissions that use that same opportunity lock, including calls to the legacy RPC that locks the same row. This should still be stress-tested with authenticated staging clients.
- No triggers were found on krim_partner_quotes or krim_audit_events at review time.

## Remaining risks / gates
1. The new RPC remains review-only and is not deployed.
2. The read-only staging preflight script has been committed but not executed; do not run it against production as a substitute for staging.
3. Authenticated staging fixtures are still required to test organization A/B isolation, permission denial, compliance/capability rejection, expired/awarded opportunities, duplicate and concurrent submissions, and audit consistency.
4. The proposed RPC owner must retain EXECUTE on the private capability helper; validate actual owner/ACL in staging.
5. No quote submission UI is enabled in the Partner app.
6. Physical Android testing, EAS signing/release build, store review, customer/driver write workflows, and payment-to-ledger-to-settlement E2E remain outstanding.

## Decision
MOBILE SOURCE/CI BUILD: PASS for Partner, Customer and Driver on the commit above.
STATIC LINK AUDIT: PASS.
PRODUCTION SMOKE CHECKS: PASS.
PARTNER QUOTE AUTHORIZATION E2E: NOT RUN.
STAGING MIGRATION: NOT APPLIED.
PRODUCTION RELEASE: NO-GO pending the remaining gates.
