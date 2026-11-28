# KRIM Fast-Track Day 1 — Deployed Multi-Category RPC and Caller Reconciliation — 2026-11-28

## Staging deployed function re-read
Read-only Staging catalog query returned the deployed signature:

`public.krim_submit_partner_onboarding_global_multi_v1(text,text,text,text[],text[],text,text,text,text,text,text,text,text,text,jsonb)`

Properties:
- Owner: `postgres`
- `SECURITY DEFINER`
- Explicit empty search_path
- Requires authenticated user and JWT AAL2
- Requires active membership in a matching registered-business partner organization
- Validates 1–13 unique categories and one coverage entry per category
- Calls the base `krim_submit_partner_onboarding_global_v2` once, using the first category only when it is one of four transport categories; otherwise substitutes `ROAD_FTL`
- Then upserts category capability rows using the category-to-mode/service mapping.

## Confirmed defects / blockers in the deployed wrapper
1. **No category-specific evidence input.** The signature accepts one parent `p_document_paths text[]` only. The category coverage JSON has no evidence path field.
2. **No capability evidence lineage on category rows.** The wrapper writes category metadata, coverage and `submitted_via`, but not capability-level `submitted_by`, `submitted_at`, or `evidence_paths` required by the independent capability review flow.
3. **Resubmission can downgrade reviewed rows.** The UPDATE branch unconditionally sets `active=false` and `verification_status='pending'` for an existing category row. It does not preserve the prior approved/rejected state or evidence lineage.
4. **Fallback category creates a misleading base capability.** For category selections whose first item is not one of ROAD_FTL/OCEAN_NVOCC/AIR_CHARTER/INTERMODAL_RAIL, the base v2 call receives `ROAD_FTL` as the primary category. The wrapper later inserts/upserts the selected category rows, but the base capability's relation to the user's actual primary category needs explicit reconciliation.
5. **Evidence path validation is parent-document scoped.** The wrapper checks the first parent document path format and active organization membership. It does not validate category-specific evidence files, private bucket ownership or the required capability path convention.

These are source-level findings from the deployed function definition, not a claim that a live submission has failed. No function was invoked.

## Repository caller inventory — targeted current-branch sample
At branch commit `7b65146f302a8ffa26b3ef810e0d98af0d2bdfa0`, targeted content reads found:
- `public/partner/partner-onboarding.html`: one exact call to `krim_submit_partner_onboarding_global_multi_v1`.
- `public/partner/partner-onboarding.html`: no call to base v2.
- `public/freight/forwarder-onboarding.html`, `partner/partner-onboarding.html`, `auth/partner-signup.html`, `public/partner/services-capabilities.html`, mobile partner repository and selected partner workspace pages: no call to either onboarding RPC.

This is a targeted sample, NOT exhaustive enumeration of all 1,210 HTML/JS/TS-family files. Remaining app call-site inventory stays OPEN.

## Migration provenance — narrowed, not resolved
The tracked `20261104133000_secure_partner_business_verification.sql` migration:
- Explicitly says it was applied to project `ebltviniygljwwseplph` on 2026-11-04.
- Looks up the existing multi-category function using `pg_get_functiondef`.
- Injects authentication, active-membership and registered-business guards by replacing known code anchors.
- Does not create the wrapper from a complete source definition.

The November 2 frontend introduction commit `aa9e5d25a319c5d5ce638fae113bdfaa1da99b96` changed only `public/partner/partner-onboarding.html`; it did not include SQL. The original wrapper creation source remains unidentified in the tracked migration set examined. This suggests a missing source-of-truth/migration-history record, but does not prove how or where the original function was created.

## Safe correction requirements
Do not patch the current function in place yet. First complete all-repository caller enumeration and capture the full base v2 definition/dependencies. Then design a versioned RPC and coordinated frontend upload flow that:
- requires exactly one evidence map per selected category;
- validates all evidence paths, private bucket object existence and authenticated ownership before any parent/capability mutation;
- derives submitter identity from `auth.uid()`;
- stores server-verified `submitted_by`, `submitted_at`, `evidence_paths`, and onboarding correlation;
- validates all categories before writes and is transaction-atomic;
- preserves existing approved/rejected capability state and prior evidence history on resubmission;
- leaves new/changed capabilities pending until separate AAL2 reviewer approval;
- handles compatibility/deprecation for old callers.

## Safety and status
- Staging catalog read only; no SQL mutation, RPC invocation, upload, onboarding submission, fixture, event, notification, email/provider/payment action, or deployment.
- Production project was not queried or modified. The repository migration's comment references the Production project ID as historical metadata only.
- Phase 00 remains OPEN; Phase 01 not authorized.
- Day 1 remains PARTIAL until source provenance, full caller enumeration, and the other Day 1 acceptance criteria are complete.
