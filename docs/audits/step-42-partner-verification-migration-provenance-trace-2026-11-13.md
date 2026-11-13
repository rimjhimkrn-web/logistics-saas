# Step 42 — Partner verification migration provenance trace

Date: 2026-11-13
Scope: read-only reconciliation of the live partner identity-verification function with Git history and the production migration ledger.

## Provenance found

The live production migration ledger contains:

- version: `20261105154408`
- name: `separate_partner_verification_from_compliance_activation`

The repository contains the corresponding migration source:

- file: `supabase/migrations/20261107090000_separate_partner_verification_from_compliance_activation.sql`
- introducing commit: `6fcd077fb51a6293bdba77ec9ebc7dacdde09424`
- commit message: `Separate partner verification from compliance activation`
- commit author timestamp: `2026-11-05T15:44:24Z`
- file blob at audited PR head: `6b2839d2bd05db002329feeda11caac317142871`

The introducing commit's patch shows the migration was specifically written to replace the prior approval-state block that set lifecycle active, compliance compliant, onboarding completed and commercial activation timestamps. Its replacement sets lifecycle approved, identity verified, compliance pending and onboarding submitted, without marking onboarding complete or setting partner_activated_at.

The live production function definition inspected in Step 41 contains that replacement state block. The live compliance-review function independently performs the compliance decision, and capability/service-area functions independently gate those activations.

## Reconciliation result

The source intent and the current live function behavior agree. The production ledger's applied version `20261105154408` differs from the timestamp embedded in the current repository filename `20261107090000`. The migration name and introducing commit align with the function change, and the commit was authored at 15:44:24Z, shortly after the ledger version timestamp 15:44:08Z.

This is strong provenance evidence for the deployed behavior, but it is not a cryptographic proof that the exact SQL bytes applied to production equal the current file bytes: the migration ledger stores version/name, not a source checksum, and the repository filename/version mismatch remains a migration-history hygiene issue. The broader history drift from Step 36 remains unresolved.

## Decision

- Step 40's older-function concern is closed as a current production defect; Step 41's live verification stands.
- No corrective SQL migration is warranted for this function.
- Do not rename/rewrite historical migration files or edit production migration history merely to make timestamps match.
- Preserve the source file and record this mapping in the migration reconciliation ledger when the full 425-entry reconstruction is undertaken.
- Continue to prohibit production DDL until full migration provenance, safe staging reconstruction and validation are complete.

## Verification boundaries

Read-only GitHub commit/file inspection and read-only production migration-ledger/function-definition inspection. No SQL writes, RPC invocation, partner record change, migration application, secret access, merge or deployment.

## Remaining launch blockers

This closes one specific provenance question, not overall launch readiness. KRIM still needs a verified partner organization with current compliance, at least one independently approved capability and service area, authorized real-world operating coverage, completed public legal disclosures and contact/grievance details, and end-to-end customer/partner tests. The staging project remains empty and migration history is still unreconciled.
