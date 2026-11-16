# Customs and shipment compliance gate — production revalidation

**Date:** 2026-11-17  
**Method:** Read-only catalog/function/row-count inspection.  
**Production writes:** None.

## 1. P0: empty compliance-check set evaluates to clear

Live `public.krim_internal_evaluate_shipment_compliance_gate(bigint)` is SECURITY DEFINER with explicit EXECUTE for postgres and service_role only. Its current algorithm counts:
- blocking checks: failed/rejected/non-compliant/blocked;
- review checks: pending/in_review/review_required;
- expired checks: expired and not already blocking.

It then returns `clear` when all three counts are zero. It does not check whether any compliance checks exist, nor whether all mandatory checks for the shipment's route, mode, cargo and jurisdiction have been instantiated.

Read-only production counts:
- shipment-linked compliance checks: **0**
- compliance gate rows: **6**
- gates whose shipment has no compliance checks: **6**
- customs document submissions: **0**
- expired non-blocking compliance checks: **0**

Therefore all six existing gate rows are associated with an empty check set under the current query, and the evaluator's zero-check branch can report `clear`. This is a fail-open P0. The earlier proposal `docs/remediation-pending/2026-11-16-shipment-compliance-zero-checks-fail-closed.sql` already documents a fail-closed status proposal; it remains NOT A MIGRATION.

A correct design must derive mandatory checks from a current, approved jurisdiction/route/mode/cargo rule set, instantiate them, and return `review_required` (or a stronger block) when the applicable rule set is absent, incomplete, stale, ambiguous or yields zero required checks. Merely requiring count(*) > 0 is not enough if the mandatory check catalog itself is empty or incomplete.

## 2. Customs document workflow is not evidence of government release

Public wrappers exist for:
- `krim_customs_document_submit(...)`
- `krim_customs_document_review(...)`

Both are SECURITY INVOKER SQL wrappers with explicit authenticated/service_role/postgres EXECUTE and delegate to private implementations. The private implementation bodies were not returned by the catalog inspection, so this review does not claim their internal controls are verified.

The public submissions table contains issuer country, issue/expiry dates, storage path, MIME type, file size, submitter organization/user, status and reviewer fields. These fields represent submitted and internally reviewed evidence; they do not independently prove that a customs authority accepted a declaration, released cargo, or issued a verifiable clearance decision.

The inspected public catalog exposed no dedicated `customs_release` table among the candidate objects. Before any cross-border operational claim, identify the canonical government release evidence model (or design one through the reconciled migration process) with authority/jurisdiction, declaration or MRN reference, shipment/consignment linkage, decision status, timestamp, source verification, evidence integrity, expiry/revocation and independent reviewer/audit trail.

## 3. Gate freshness and completeness

The evaluator writes/upserts a gate row with `checked_at`, status, risk, reason and aggregate counts. The inspected algorithm does not verify:
- mandatory rule-set version and jurisdiction applicability;
- that all required check types are present exactly once;
- current evidence source and reviewer authority;
- source revocation or superseding decisions;
- check freshness when `checked_at` is null/stale;
- shipment route/mode/cargo changes since last evaluation;
- a verified external customs release for movements requiring one.

Gate status must be treated as a derived, expiring decision, not a permanent shipment attribute. Route, mode, cargo, party, document, rule version or jurisdiction changes must invalidate and recompute the gate.

## 4. Required remediation

1. Keep zero-check result fail-closed; no compliance-clearance or customs-clearance claims while no mandatory checks are instantiated.
2. Establish a versioned mandatory-control catalog by jurisdiction, route, transport mode, cargo class and shipment party.
3. Evaluate expected controls against actual current checks; missing, duplicate, stale or unverified controls must be `review_required` or blocked.
4. Separate internal document review from government customs release; require verifiable authority evidence where legally required.
5. Bind customs documents and release evidence to the exact shipment/consignment and applicable jurisdiction; validate expiry, revocation and source.
6. Enforce independent submission/review separation, role-specific permissions, audit history and immutable source references.
7. Recompute/invalidate gates when any relevant shipment or evidence input changes; prevent stale gate reuse at quote, assignment, dispatch and delivery.
8. Inspect private wrapper targets, all table DML grants/RLS, storage bucket policies, upload object ownership and service-role callers before remediation.
9. Reconcile migration history before any production SQL/DDL change; stage test missing/zero controls, incomplete control set, expired/revoked documents, invalid jurisdiction, unsupported cargo, forged/stale authority references, reviewer self-approval, source outage, concurrent route changes and rollback.

## Release decision

**NO-GO for customs clearance, compliance-clear shipment status, cross-border booking or dispatch** until mandatory control completeness is enforced and independently verifiable government release evidence is represented where required. The current read-only snapshot shows six compliance gates and zero shipment-linked checks; no production records or schema were changed.
