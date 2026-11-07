# KRIM Mobile Next-Gate Execution Record — 2026-11-07

## Work completed in this pass

- Rechecked the Supabase account project inventory: only the production project `logistics-saas` (`ebltviniygljwwseplph`) is currently listed.
- Rechecked development branches for that project: none exist.
- Confirmed the live production `krim_partner_quotes` schema includes the nullable `notes` text column used by the proposed organization-scoped quote RPC.
- Updated `docs/sql/krim_partner_quote_staging_preflight.review.sql` to explicitly verify `krim_partner_quotes.notes` before the RPC can be tested.
- No production SQL, grants, rows, payment configuration, or credentials were changed.

## Current environment decision

There is no isolated Supabase staging project or development branch available in the connected account. The only connected project is production. Therefore, the review-only preflight and proposed RPC must NOT be run against the live project, and no authenticated write tests can safely be performed yet.

A Supabase development branch may incur hourly compute and other charges. Do not create one without first obtaining a cost quote and explicit user approval of any non-zero cost. An independent staging project also requires an explicit organization choice and cost review.

## Required staging sequence

1. Provision an isolated staging database only after its cost is known and approved.
2. Apply the repository's existing migrations to staging; do not copy production customer, partner, shipment, identity, payment, or evidence data.
3. Run `krim_partner_quote_staging_preflight.review.sql` against staging.
4. Review the proposed `krim_submit_partner_quote_for_organization` RPC against the staging schema, including function owner privileges for the private capability helper and final ACLs.
5. Seed synthetic organizations and shipments only: two partner organizations, one customer organization, users with distinct membership/permission combinations, verified and unverified capabilities, and open/closed/expired opportunities.
6. Run positive and negative authenticated tests, including two-org selection isolation, permission denial, verification/compliance gates, route/mode/weight mismatch, self-bid rejection, deadline/award rejection, repeat submission, concurrent submission, quote/audit organization consistency, and anon/PUBLIC execute denial.
7. Verify the legacy quote RPC cannot silently reintroduce cross-organization misattribution during rollout. Do not enable the app write path until the migration and compatibility strategy pass.
8. Only after staging passes, update the partner app to call the new RPC with an explicit selected organization ID and add end-to-end tests.
9. Separately test customer booking/quote acceptance, driver accept/trip/POD, warehouse QC/inventory, operations workflows, and payment-to-ledger-to-settlement reconciliation with synthetic staging fixtures.
10. Complete physical Android testing, production signing/build, privacy/security review, and release gates before store publication or public launch.

## Release posture

- Three mobile apps: source typecheck and Android Expo export passed in the last recorded CI run.
- Customer, partner, and driver mobile workspaces remain read-only for sensitive lifecycle actions.
- Proposed partner quote RPC: review-only, not deployed.
- Authenticated staging integration tests: blocked by absence of staging.
- Production deployment / public launch: NO-GO until the remaining security, operational, payment, device, and release gates pass.
- Internal read-only testing and partner/customer onboarding preparation: GO.

## Important safeguards

- Use only the Supabase publishable key in mobile clients.
- Never place service-role keys, payment secrets, or webhook secrets in app bundles or repository files.
- Do not claim a shipment, quote, assignment, POD, payout, or payment is operationally complete unless the corresponding verified backend record and reconciliation evidence exist.
- Keep production untouched while staging is unavailable.
