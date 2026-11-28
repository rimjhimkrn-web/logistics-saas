# Partner quote and onboarding RPC call-site trace — 2026-11-24

Scope: targeted source trace on branch `feat/notification-recipient-resolver-draft-2026-11-24`, PR #245 head `d6e0bc3eccf5b70da12568be13a038be05529e0d`. Read-only; no database grants or data changed.

## Findings

### 1. `public.krim_submit_partner_quote(...)` — confirmed active browser call
- File: `public/partner/submit-quote.html`
- Blob: `ee6822dfe35fb9892f7d471f0cac32046b8f0520`
- The submit handler directly calls `client.rpc("krim_submit_partner_quote", ...)` when a partner submits a commercial offer.
- The UI validates the returned quote ID, opportunity ID, partner organization ID and `status = submitted`; on ambiguous failure it tells the partner to refresh My Bids before retrying.
- Staging currently denies authenticated EXECUTE for this overload while production permits it. This is a confirmed staging partner-bidding blocker, not a reason to grant broadly.
- Next remediation gate: verify exact overload signature and current function body/tenant checks in staging; run positive own-organization submission and negative foreign-organization submission in a rollback-only staging transaction; reconcile migration history; then propose the exact authenticated grant with anon/PUBLIC denied. Do not expose service_role to the browser.

### 2. `public.krim_submit_partner_onboarding_global_v2(...)` — no active call found in targeted current onboarding paths
- Current public onboarding page: `public/partner/partner-onboarding.html`, blob `733ef7b8062fcadd75e1cfcb35a791a9c3385d78`.
- Its registered-business flow calls `krim_submit_partner_onboarding_global_multi_v1`, not v2.
- Its development/individual pathways call `krim_set_partner_account_mode`.
- The legacy root `partner/partner-onboarding.html` was also checked; no v2 reference was found in the inspected content.
- Therefore do not grant authenticated EXECUTE to v2 on the basis of production parity alone. Treat it as legacy/unproven until the full route inventory establishes a caller or the function is formally retired after dependency review.

### 3. `public.krim_award_leg_partner_quote(bigint)` — caller not established
- Targeted dispatch, partner load/assignment, negotiation, customer quote-operation and carrier active-shipment pages were inspected; none contained a direct reference to this RPC.
- GitHub code-search endpoint returned zero results with `incomplete_results=true`, so this is not proof that no indirect/dynamic caller exists.
- The repository migration `20261116012000_add_authorized_leg_partner_quote_award_rpc.sql` grants authenticated EXECUTE, while staging currently denies it. No grant change is recommended until the full call graph (including Edge Functions and generated/dynamic RPC wrappers) and the function's authorization boundary are verified.

## Decision
- Confirmed blocker: authenticated staging access to `krim_submit_partner_quote` does not match the active partner bid UI.
- Do not alter `krim_submit_partner_onboarding_global_v2` or `krim_award_leg_partner_quote` ACLs yet.
- This report is source-trace evidence only. No live database changes, real bids, partner onboarding submissions, quote awards, or external messages were performed.
