# Phase 00 — Live Storage policy recheck and correction to prior finding

**Date:** 2026-11-25  
**Scope:** Read-only current catalog inspection of Production and Staging Supabase projects.  
**Projects:** Production `ebltviniygljwwseplph`; Staging `qrpcivhdxobiaofppbkl`.  
**No changes:** No SQL writes, policy changes, bucket creation, object uploads, or deployments.

## Why this recheck was necessary

The earlier Phase 00 Storage audit and remediation blueprint described both Staging partner-verification INSERT policies as permissive, which would allow the AAL2-only policy to be bypassed by the organization-scoped permissive policy under PostgreSQL's OR-composition rules.

A fresh read-only query against the current Staging `pg_policies` catalog on 2026-11-25 returned a different policy composition. The current live catalog must take precedence for current-state reporting.

## Current Staging partner-verification policy state

The live Staging catalog currently returns:

| Policy | Command | Mode | Current predicate |
|---|---|---|---|
| `krim_partner_verification_upload_own_org` | INSERT | PERMISSIVE | Bucket match, caller-owned second path segment, numeric organization path, active caller membership, active organization and allowed provider organization type |
| `krim_partner_verification_upload_require_aal2` | INSERT | **RESTRICTIVE** | Bucket match and JWT assurance claim `aal2` |
| `krim_partner_verification_read_own_org` | SELECT | PERMISSIVE | Bucket match and active organization membership/path scope |

For INSERT, at least one permissive policy must pass and every applicable restrictive policy must pass. Therefore, the current restrictive AAL2 policy is combined with the permissive organization/uploader policy as an AND condition. **The previously reported permissive-policy bypass is not present in this current catalog snapshot.**

This is a catalog-level conclusion. It does not prove the behavior with actual AAL1/AAL2 JWTs, uploads, path traversal attempts or cross-organization identities. Runtime verification remains outstanding.

## Production comparison

The current Production catalog returns the organization-scoped partner-verification INSERT policy as permissive and does not show a corresponding AAL2 restrictive INSERT policy. Production and Staging therefore have a meaningful assurance-policy difference.

Do not silently remove Staging's AAL2 restriction or add it to Production. The intended assurance requirement is an owner/security decision. Until that decision is recorded, treat Staging's catalog composition as **structurally enforced AAL2, runtime unverified**, and Production's current behavior as **no AAL2 requirement on this INSERT policy**.

## Current Staging bucket parity

The current bucket catalog query returned only:

- `krim-partner-verification` — private; 10 MiB limit; PDF/JPEG/PNG.

The reviewed buckets `krim-driver-verification`, `krim-driver-evidence` and `krim-warehouse-evidence` were not returned and remain absent in this reviewed Staging bucket set. This continues to block corresponding driver and warehouse evidence tests.

## Corrected gate status

| Gate | Updated finding |
|---|---|
| G1 — Partner upload assurance | **PARTIAL PASS:** restrictive AAL2 policy is present in current Staging catalog and composes with organization/uploader policy; owner decision for Production/Staging assurance parity and runtime JWT tests remain open |
| G2 — Staging Storage parity | **BLOCKED:** three reviewed evidence buckets remain absent |
| G3 — Driver reviewer ACL | **OPEN:** actual caller and intended execution model still need confirmation |
| G4–G6 | Unchanged: synthetic identities, safe test sink/cleanup and authenticated runtime tests are not established |

## Reconciliation note

The earlier report `phase-00-live-storage-policy-composition-and-reviewer-authorization-audit-2026-11-25.md` should be read as a historical snapshot, not the current policy composition. This recheck does not identify who changed the policy mode or when; the live catalog query alone cannot establish change provenance. Do not attribute the change to the current QA work. No database mutation was performed during this recheck.

**Decision:** Correct the current-state finding; do not apply a policy change. Proceed with a reviewed assurance decision and the remaining Storage readiness gates.
