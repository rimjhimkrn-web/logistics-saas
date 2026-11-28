# KRIM Fast-Track Day 1 — November 4 Hardening Migration Source Inspection — 2026-11-28

## Source inspected
`supabase/migrations/20261104133000_secure_partner_business_verification.sql` on `staging/phase00-env-isolation`.

## What the migration actually does
- Finds the already-existing `public.krim_submit_partner_onboarding_global_multi_v1` by name in `pg_proc`.
- Reads its complete deployed definition with `pg_get_functiondef`.
- Requires a specific authentication-guard text anchor to exist.
- Replaces that anchor with a longer guard that validates the first parent document path and requires an active matching organization membership plus registered-business partner mode.
- Executes the modified function definition.
- Repeats a similar text-anchor replacement against the already-existing base `krim_submit_partner_onboarding_global_v2` to require registered-business mode.
- Separately modifies the already-existing partner verification review function to prevent approval of non-registered-business accounts.

## Provenance implication
This is unequivocally a hardening/patch migration, not a complete source-of-truth creation migration for the multi-category wrapper. It assumes the wrapper already exists and assumes exact source text anchors in that deployed function. The complete original wrapper definition is not present in this file.

The file header contains a historical comment saying it was applied to project `ebltviniygljwwseplph` on 2026-11-04. This is repository text only. No connection, query, or action against that project was made.

## Safe next action
Recover the pre-hardening function definition from an authorized backup or archived deployment artifact. Compare it to the current Staging definition and the Nov 4 replacement. Do not execute the text-replacement migration against an unknown baseline and do not reconstruct the missing function from partial clues.

## Safety
Repository file read only. No database write, RPC invocation, deployment, fixture, onboarding, notification, email, payment, or Production access. Phase 00 remains OPEN.
