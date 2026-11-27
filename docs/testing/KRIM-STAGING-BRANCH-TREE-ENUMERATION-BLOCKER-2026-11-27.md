# KRIM Staging Branch Tree Enumeration Blocker — 2026-11-27

## Attempt
Attempted to retrieve the exact `staging/phase00-env-isolation` branch tree to enumerate all tracked SQL/HTML/JS/TS references to:
- `krim_submit_partner_onboarding_global_multi_v1`
- `krim_submit_partner_onboarding_global_v2`
- `krim_partner_submit_service_capability_v2`

The available GitHub connector exposes direct file reads with an explicit ref and default-branch code search, but its repository fetch endpoint rejected branch URLs containing the slash in this branch name. Default-branch code search is not an acceptable substitute for exact Staging-branch enumeration.

## Evidence retained
- Exact Staging frontend caller was directly fetched at `public/partner/partner-onboarding.html`.
- Deployed Staging RPC definition was queried directly from project `qrpcivhdxobiaofppbkl`.
- Staging migration history was queried read-only; no obvious original multi-category onboarding migration name was identified.
- Prior caller/evidence trace: commit `a61c8e4b2bf0bafcb652bb4764b193183b1cb9b7`.
- Prior migration provenance check: commit `9ba8c553be93c7fe8e64b6ff2eb71c2cd2152df2`.

## Result
Complete caller enumeration and exact source migration provenance remain BLOCKED. No claim is made that the inspected HTML page is the only caller or that the migration history lacks the source migration.

## Required unblock
Obtain the exact branch HEAD SHA/tree through an authorized GitHub branch/tree endpoint or provide a repository archive/export of `staging/phase00-env-isolation`. Then search the complete tree, inspect all call sites and migration definitions, and compare them against the deployed Staging function before authoring a versioned RPC.

## Safety
No database mutation, RPC invocation, fixture creation, onboarding submission, Storage upload, notification/email/provider/payment action, or deployment occurred. Production was not accessed. Phase 00 remains OPEN; Phase 01 remains gated.
