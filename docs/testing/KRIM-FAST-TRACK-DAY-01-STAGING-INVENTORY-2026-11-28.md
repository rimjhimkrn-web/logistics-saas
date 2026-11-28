# KRIM Fast-Track Day 1 — Staging Inventory and Partner RPC Evidence — 2026-11-28

## Scope and safety
Day 1 target: establish an evidence-backed Staging inventory for the multi-category partner onboarding RPC and identify the remaining provenance/caller-enumeration blocker. All database work was read-only against Staging project `qrpcivhdxobiaofppbkl`. Production project was not accessed.

## Verified evidence

### Frontend caller
Fetched `public/partner/partner-onboarding.html` from ref `staging/phase00-env-isolation`.
- Blob SHA: `af0e429e1b9780cf93feee0d6fb492d149fc159e`
- File size: 82,158 characters.
- Exact RPC identifier occurs once in the file.
- The page submits `p_category_coverage` and `p_document_paths`.
- The page has an `uploadPartnerDocument` helper, but the existing onboarding contract remains organization-level documents plus category coverage; no category-specific evidence map is passed by this RPC caller.

### Deployed Staging RPC
Queried the deployed definitions directly from Staging:
- `public.krim_submit_partner_onboarding_global_multi_v1(text,text,text,text[],text[],text,text,text,text,text,text,text,text,text,jsonb)`
- Delegated `public.krim_submit_partner_onboarding_global_v2(...)`

The deployed multi-category wrapper:
- Requires authenticated AAL2.
- Requires one registration document path under the active user's organization/user path.
- Validates 1–13 unique supported categories and one coverage entry per category.
- Delegates parent onboarding to the v2 function.
- Inserts or updates capability rows as inactive/pending.
- Does not accept or persist per-category capability evidence paths, `submitted_by`, or capability evidence lineage needed by the independent capability review RPC.
- On resubmission, the update branch unconditionally sets existing matching capability rows to `active=false` and `verification_status='pending'`; therefore resubmitting may downgrade a previously approved capability. This needs a history-preserving, state-aware correction, not a metadata-only patch.

### Migration history
Read-only query of Staging `supabase_migrations.schema_migrations` returned partner/capability/onboarding migrations through 2026-11-27. The returned names include partner document ownership, storage MFA, evidence read hardening, capability revocation and service-area revocation. No obvious migration name identifies the original multi-category RPC definition. This does not prove that no source migration exists; it may have a generic name or older timestamp.

### Repository tree limitation
The available GitHub branch search confirms the branch name `staging/phase00-env-isolation`, but the repository tree/fetch route rejects branch paths containing the slash. Default-branch code search is not a valid substitute. Complete repository-wide caller and migration enumeration remains open.

## Day 1 result
**PARTIAL / BLOCKED — not a pass.**
- Staging frontend caller and deployed RPC behavior are revalidated.
- The evidence gap and potentially destructive resubmission behavior are reconfirmed.
- Exact source migration provenance and complete all-repository caller enumeration remain blocked pending exact branch HEAD/tree access or a branch archive/export.

## Required next actions
1. Obtain the exact Staging branch HEAD/tree or a repository archive/export.
2. Enumerate all call sites for the multi-category RPC, base RPC and related capability evidence flows.
3. Identify and compare the original migration source to the deployed Staging function.
4. Then implement a versioned, atomic category-evidence contract and coordinated frontend uploader, preserving reviewed capability history and leaving all new submissions inactive/pending until independent AAL2 review.

## Prohibited actions retained
No SQL writes, migration application, RPC invocation, onboarding submission, fixture creation, Storage upload, event insertion, queue claim, notification/email/provider/payment call, or deployment occurred. Production untouched. Phase 00 remains OPEN; Phase 01 remains gated.
