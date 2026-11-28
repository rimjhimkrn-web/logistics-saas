# KRIM Live Partner Onboarding Audit — 2026-11-24

## Scope and method

Read-only inspection of the live production Supabase project `ebltviniygljwwseplph`. No rows, permissions, functions, secrets, or storage objects were changed. No test users, partner identities, documents, quotations, or commercial records were created.

This audit follows the current production schema and function definitions. It does not infer successful onboarding from page availability.

## Live production snapshot

| Measure | Observed |
|---|---:|
| Organizations classified as partner/carrier/forwarder/logistics provider/warehouse operator | 3 |
| `krim_organization_onboarding` rows | 0 |
| Partner verification cases | 1 |
| Partner compliance evidence rows | 0 |
| Partner compliance review rows | 0 |
| Partner capabilities | 1 |
| Verified and active capabilities | 0 |
| Approved partner service areas | 0 |
| Open partner opportunities | 0 |
| Partner quotes | 0 |

The three partner-type organizations are not three verified commercial partners:
- Organization 2: active partner-type organization, but `partner_account_mode` is null and verification/compliance are not started.
- Organization 14: active partner-type organization in `development_test` mode, with verification pending and onboarding in progress.
- Organization 18: warehouse operator organization, but partner account mode is null and partner verification/compliance are not started.

The single verification case and single capability must not be treated as verified/active commercial supply.

## Live workflow functions found

The production database exposes these relevant routines:
- `krim_submit_partner_onboarding_global_multi_v1(...)`
- `krim_submit_partner_onboarding_global_v2(...)`
- `krim_partner_submit_compliance_evidence(...)`
- `krim_partner_submit_service_capability_v2(...)`
- `krim_admin_review_partner_verification(...)`
- `krim_admin_review_partner_compliance(...)`
- `krim_admin_review_partner_capability(...)`

The inspected routines use `SECURITY DEFINER` and an empty `search_path`. The onboarding, compliance, verification and capability review routines shown in this audit grant EXECUTE to authenticated and service_role, not anon. Their bodies enforce authentication and organization membership; administrative review additionally requires AAL2 and `admin.platform`.

## Confirmed controls in the inspected definitions

1. Partner submission requires an authenticated user and an active membership in a matching partner-type organization.
2. Registered-business onboarding requires a private verification-bucket document path associated with the submitting account and a valid active organization.
3. Multi-category onboarding accepts only its enumerated service categories and requires a corresponding country/region/city coverage entry for each selected category.
4. Submitted capabilities start inactive and pending; they are not automatically made commercially eligible.
5. Verification review requires AAL2 platform-admin permission and blocks the original submitter from approving their own verification case.
6. Compliance review requires AAL2 platform-admin permission, exactly four baseline checks, evidence matching the current submitted object metadata, an independent review note, and an expiry date for approval.
7. Capability approval requires current partner compliance, active country and mode catalogue entries, privately stored evidence owned by the original submitter, valid scope/weight dates, and rejects hazardous-goods and refrigerated capabilities through the standard approval path until additional controls exist.

These are positive controls in the inspected function definitions; this audit is not a complete penetration test or a full caller-to-database trace.

## Implementation gaps and next verification work

### P0 — Resolve onboarding-mode and workflow coverage
- Production has a registered-business submission path and a multi-category registered-business path. The inspected multi-category function explicitly requires `partner_account_mode='registered_business'`.
- The current live snapshot contains a `development_test` organization, but no evidence here establishes a complete, separately tested individual/development-to-registered conversion journey.
- `krim_organization_onboarding` has zero rows despite one verification case and an in-progress development-test organization. Reconcile whether the table is legacy, optional, or an intended authoritative state machine before wiring more UI to it.
- Trace the actual partner workspace forms and their RPC arguments against the exact production function signatures. Confirm all three requested pathways (Development / Individuals / Registered) have deliberate, secure, documented semantics rather than routing into the wrong registered-business workflow.

### P0 — Complete real verification lifecycle
- There is no current compliance evidence or compliance review row.
- There are no approved service areas and no verified active capabilities.
- Test independent reviewer controls with separate isolated identities, including submitter-self-approval denial, AAL2 enforcement, missing evidence, wrong storage owner, expired evidence and rejected/on-hold decisions.

### P0 — Verify marketplace activation only after approval
- Confirm a verified, compliant registered-business partner with approved mode/category/coverage can be discovered for an exactly matching shipment leg.
- Confirm unverified, inactive, expired, wrong-country, wrong-mode, wrong-region and insufficient-capacity partners are excluded.
- Verify quote submission, award and assignment lifecycle only in isolated staging/test data.

### P1 — Browser and persistence verification
- Identify each live partner onboarding entrypoint and verify the caller uses the intended RPC and exact named parameters.
- Exercise empty, malformed, duplicate, oversized and unsupported inputs.
- Verify upload ownership, private bucket access, row ownership, audit events, idempotency, retry behavior and user-visible status transitions.
- Confirm that essential transactional notifications are generated and delivered through configured providers before claiming partner onboarding is complete.

## Safety boundary

No production data or security settings were modified. No fake commercial partner or test document was added to production. The production environment must not be used for destructive or synthetic load tests. Use isolated staging with reconciled migrations and controlled test identities; keep payments and external messaging in sandbox/test mode.

## Exit criteria for partner onboarding

Do not mark partner onboarding complete until all of the following have evidence:
- Development, individual and registered-business paths have explicit supported rules and working UI-to-RPC mappings.
- Document uploads are private, owner-bound, size/type validated and retrievable only by authorized reviewers.
- Verification and compliance reviews are independently approved with audit history.
- Capabilities and service areas become active only after all applicable approvals.
- Marketplace discovery and quote/award/assignment flows pass positive and negative tests.
- Status, audit and mandatory service-notification behavior are verified.
- Isolated integration tests pass without writing synthetic data into production.

**Current verdict: NOT PRODUCTION-READY.** The database contains the beginnings of a guarded partner onboarding workflow, but the live evidence does not demonstrate a verified commercial partner or a complete end-to-end onboarding-to-marketplace journey.
